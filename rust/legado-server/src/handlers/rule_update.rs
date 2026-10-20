//! 规则订阅更新处理器
//!
//! 提供规则订阅管理与更新能力：
//! - GET /api/rule-update/subs — 获取订阅列表
//! - POST /api/rule-update/check — 检查更新
//! - POST /api/rule-update/apply — 应用更新

use axum::Json;
use axum::extract::State;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::sync::Arc;

use legado_engine::rule_subscription_service::{
    self as service, PreparedUpdate, RuleSubscriptionService,
};

use crate::error::ApiError;
use crate::state::AppState;

/// 订阅信息响应
#[derive(Debug, Clone, Serialize)]
pub struct SubInfo {
    pub id: i64,
    pub url: String,
    pub name: String,
    pub sub_type: String,
    pub last_update: i64,
    pub version: String,
    pub is_enabled: bool,
}

/// 检查更新请求体
#[derive(Debug, Deserialize)]
pub struct CheckUpdateRequest {
    /// 指定订阅 URL（为空则检查所有已启用订阅）
    #[serde(default)]
    pub url: Option<String>,
}

/// 检查更新结果
#[derive(Debug, Serialize)]
pub struct CheckUpdateResult {
    pub url: String,
    pub name: String,
    pub has_update: bool,
    pub remote_version: Option<String>,
    pub error: Option<String>,
}

/// 应用更新请求体
#[derive(Debug, Deserialize)]
pub struct ApplyUpdateRequest {
    /// 订阅 URL
    pub url: String,
    /// 是否静默更新
    #[serde(default)]
    pub silent: bool,
}

/// 应用更新结果
#[derive(Debug, Serialize)]
pub struct ApplyUpdateResult {
    pub url: String,
    pub success: bool,
    pub items_added: usize,
    pub items_updated: usize,
    pub items_removed: usize,
    pub error: Option<String>,
}

/// GET /api/rule-update/subs — 获取订阅列表
pub async fn list_subs(State(state): State<Arc<AppState>>) -> Result<Json<Value>, ApiError> {
    state
        .with_database(move |db| {
            let subs = RuleSubscriptionService::new(db).list_subs()?;

            let items: Vec<SubInfo> = subs
                .iter()
                .map(|s| SubInfo {
                    id: s.id,
                    url: s.url.clone(),
                    name: s.name.clone(),
                    sub_type: s.sub_type.clone(),
                    last_update: s.last_update,
                    version: s.version.clone(),
                    is_enabled: s.is_enabled,
                })
                .collect();

            Ok(Json(json!({
                "subs": items,
                "total": items.len(),
            })))
        })
        .await?
}

/// POST /api/rule-update/check — 检查更新
///
/// 从远程拉取订阅内容，对比版本号判断是否有更新。
pub async fn check_update(
    State(state): State<Arc<AppState>>,
    Json(body): Json<CheckUpdateRequest>,
) -> Result<Json<Value>, ApiError> {
    let target = body.url.clone();
    let subs = state
        .with_database(move |db| {
            let subscriptions = RuleSubscriptionService::new(db);
            match target {
                Some(url) => {
                    Ok::<_, ApiError>(subscriptions.find_by_url(&url)?.map(|sub| vec![sub]))
                }
                None => Ok(Some(subscriptions.enabled_subs()?)),
            }
        })
        .await??;
    let Some(subs) = subs else {
        return Ok(Json(
            json!({ "results": [], "error": format!("未找到订阅: {}", body.url.unwrap_or_default()) }),
        ));
    };

    let mut results: Vec<CheckUpdateResult> = Vec::new();

    for sub in &subs {
        let result =
            service::check_update(sub, state.engine.network().custom_hosts().clone()).await;
        results.push(CheckUpdateResult {
            url: sub.url.clone(),
            name: sub.name.clone(),
            has_update: result.has_update,
            remote_version: result.remote_version,
            error: result.error,
        });
    }

    Ok(Json(json!({ "results": results })))
}

/// POST /api/rule-update/apply — 应用更新
///
/// 拉取远程订阅内容并合并到本地。
pub async fn apply_update(
    State(state): State<Arc<AppState>>,
    Json(body): Json<ApplyUpdateRequest>,
) -> Result<Json<Value>, ApiError> {
    let target = body.url.clone();
    let sub = state
        .with_database(move |db| RuleSubscriptionService::new(db).find_by_url(&target))
        .await??;

    let sub = match sub {
        Some(s) => s,
        None => {
            return Ok(Json(json!({
                "success": false,
                "error": format!("未找到订阅: {}", body.url),
            })));
        }
    };

    let prepared =
        service::prepare_update(&sub, state.engine.network().custom_hosts().clone()).await;
    if let PreparedUpdate::FetchFailed(error) = prepared {
        return Ok(Json(json!({ "success": false, "error": error })));
    }
    if let Some(update) = prepared.version_update().cloned() {
        // 保留Web原策略：内部回写错误忽略，仅外层调度错误记日志。
        if let Err(error) = state
            .with_database(move |db| {
                let _ = RuleSubscriptionService::new(db).update_version(&update);
            })
            .await
        {
            tracing::warn!("更新订阅版本失败（已忽略）: {error}");
        }
    }
    let response = prepared.into_response(&sub);
    let result = ApplyUpdateResult {
        url: response.url,
        success: response.success,
        items_added: response.items_added,
        items_updated: response.items_updated,
        items_removed: response.items_removed,
        error: response.error,
    };

    Ok(Json(json!(result)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::Router;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use axum::routing::{get, post};
    use tower::ServiceExt;

    use legado_db::repository::rule_sub_repository::RuleSubRecord;
    use legado_db::{Database, RuleSubRepository};

    fn make_test_state() -> Arc<AppState> {
        let db = Database::open_in_memory().unwrap();
        Arc::new(AppState::new(Arc::new(
            legado_engine::EngineContext::from_database(db),
        )))
    }

    fn make_router(state: Arc<AppState>) -> Router {
        Router::new()
            .route("/api/rule-update/subs", get(list_subs))
            .route("/api/rule-update/check", post(check_update))
            .route("/api/rule-update/apply", post(apply_update))
            .with_state(state)
    }

    #[tokio::test]
    async fn test_list_subs_empty() {
        let state = make_test_state();
        let app = make_router(state);

        let resp = app
            .oneshot(
                Request::builder()
                    .uri("/api/rule-update/subs")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let json: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["total"], 0);
    }

    #[tokio::test]
    async fn test_list_subs_with_data() {
        let state = make_test_state();

        // 插入测试数据
        {
            let db = state.database().unwrap();
            let repo = RuleSubRepository::new(db.connection());
            repo.insert(&RuleSubRecord {
                url: "https://example.com/sub.json".to_string(),
                name: "测试订阅".to_string(),
                sub_type: "bookSource".to_string(),
                created_at: 1700000000000,
                ..RuleSubRecord::default()
            })
            .unwrap();
        }

        let app = make_router(state);
        let resp = app
            .oneshot(
                Request::builder()
                    .uri("/api/rule-update/subs")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let json: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["total"], 1);
        assert_eq!(json["subs"][0]["name"], "测试订阅");
    }

    #[tokio::test]
    async fn test_check_update_not_found() {
        let state = make_test_state();
        let app = make_router(state);

        let resp = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/rule-update/check")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_string(&json!({"url": "https://nonexist.com"})).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let json: Value = serde_json::from_slice(&body).unwrap();
        assert!(json["error"].as_str().unwrap().contains("未找到订阅"));
    }

    #[tokio::test]
    async fn test_apply_update_not_found() {
        let state = make_test_state();
        let app = make_router(state);

        let resp = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/rule-update/apply")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_string(&json!({"url": "https://nonexist.com"})).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(resp.status(), StatusCode::OK);
        let body = axum::body::to_bytes(resp.into_body(), usize::MAX)
            .await
            .unwrap();
        let json: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(json["success"], false);
    }
    #[tokio::test]
    async fn shared_update_service_preserves_web_scope_shapes_and_ignored_write_errors() {
        async fn post_json(app: Router, path: &str, value: Value) -> Value {
            let response = app
                .oneshot(
                    Request::builder()
                        .method("POST")
                        .uri(path)
                        .header("content-type", "application/json")
                        .body(Body::from(value.to_string()))
                        .unwrap(),
                )
                .await
                .unwrap();
            assert_eq!(response.status(), StatusCode::OK);
            let body = axum::body::to_bytes(response.into_body(), usize::MAX)
                .await
                .unwrap();
            serde_json::from_slice(&body).unwrap()
        }
        // 直接使用已有Axum路由机制提供本地响应，不引入独立宿主或通信协议。
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let remote = Router::new()
            .route("/valid", get(|| async { r#"[{"name":"规则"}]"# }))
            .route("/invalid", get(|| async { "not-json" }));
        let worker = tokio::spawn(async move {
            axum::serve(listener, remote).await.unwrap();
        });
        let state = make_test_state();
        let good_url = format!("{base}/valid");
        let invalid_url = format!("{base}/invalid");
        let failed_url = "unsupported-scheme://subscription";
        let id = {
            let db = state.database().unwrap();
            let repo = RuleSubRepository::new(db.connection());
            let mut id = 0;
            for (url, enabled) in [
                (good_url.clone(), true),
                (invalid_url.clone(), false),
                (failed_url.into(), false),
            ] {
                let inserted = repo
                    .insert(&RuleSubRecord {
                        url,
                        name: "订阅".into(),
                        sub_type: "replaceRule".into(),
                        is_enabled: enabled,
                        version: "before".into(),
                        // Web原来不计算间隔，指定禁用订阅检查也不能引入溢出。
                        last_update: if enabled { 7 } else { i64::MAX },
                        update_interval: if enabled { 0 } else { 12 },
                        ..Default::default()
                    })
                    .unwrap();
                if enabled {
                    id = inserted;
                }
            }
            id
        };
        let app = make_router(state.clone());
        let checked = post_json(app.clone(), "/api/rule-update/check", json!({})).await;
        assert_eq!(checked["results"].as_array().unwrap().len(), 1);
        assert_eq!(checked["results"][0]["url"], good_url);
        assert_eq!(checked["results"][0]["has_update"], true);
        assert!(checked["results"][0].get("dueForUpdate").is_none());
        let merged_error = post_json(
            app.clone(),
            "/api/rule-update/apply",
            json!({"url": invalid_url}),
        )
        .await;
        assert_eq!(merged_error.as_object().unwrap().len(), 6);
        assert_eq!(merged_error["success"], false);
        assert_eq!(merged_error["items_added"], 0);
        assert!(
            merged_error["error"]
                .as_str()
                .unwrap()
                .contains("解析远程 JSON 失败")
        );
        let fetch_error = post_json(
            app.clone(),
            "/api/rule-update/apply",
            json!({"url": failed_url}),
        )
        .await;
        assert_eq!(fetch_error.as_object().unwrap().len(), 2);
        assert_eq!(fetch_error["success"], false);
        assert!(
            fetch_error["error"]
                .as_str()
                .unwrap()
                .starts_with("拉取订阅失败:")
        );
        {
            let db = state.database().unwrap();
            db.connection().execute_batch("CREATE TRIGGER deny_web_subscription_version BEFORE UPDATE OF version ON ruleSubs BEGIN SELECT RAISE(FAIL, 'web-subscription-write'); END;").unwrap();
        }
        let applied = post_json(
            app.clone(),
            "/api/rule-update/apply",
            json!({"url": good_url, "silent": true}),
        )
        .await;
        assert_eq!(applied.as_object().unwrap().len(), 6);
        assert_eq!(applied["success"], true);
        assert_eq!(applied["items_added"], 1);
        assert!(applied["error"].is_null());
        {
            let db = state.database().unwrap();
            let saved = RuleSubRepository::new(db.connection())
                .find_by_id(id)
                .unwrap()
                .unwrap();
            assert_eq!(saved.version, "before");
            assert_eq!(saved.last_update, 7);
            db.connection()
                .execute_batch("DROP TRIGGER deny_web_subscription_version;")
                .unwrap();
        }
        // 移除故障后验证实际回写，防止跳过更新也通过失败分支断言。
        let applied = post_json(
            app.clone(),
            "/api/rule-update/apply",
            json!({"url": good_url}),
        )
        .await;
        assert_eq!(applied["success"], true);
        {
            let db = state.database().unwrap();
            let saved = RuleSubRepository::new(db.connection())
                .find_by_id(id)
                .unwrap()
                .unwrap();
            assert_eq!(saved.version, "");
            assert!(saved.last_update > 7);
        }
        let checked = post_json(app, "/api/rule-update/check", json!({"url": invalid_url})).await;
        assert_eq!(checked["results"].as_array().unwrap().len(), 1);
        assert_eq!(checked["results"][0]["url"], invalid_url);
        assert_eq!(checked["results"][0]["has_update"], true);
        worker.abort();
        let _ = worker.await;
    }
}
