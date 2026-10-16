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

use legado_db::repository::rule_sub_repository::RuleSubRepository;

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
            let subs = {
                let repo = RuleSubRepository::new(db.connection());
                repo.find_all()?
            };

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
            let repo = RuleSubRepository::new(db.connection());
            match target {
                Some(url) => Ok::<_, ApiError>(repo.find_by_url(&url)?.map(|sub| vec![sub])),
                None => Ok(Some(repo.get_enabled_subs()?)),
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
        let subscription = legado_net::RuleSubscription {
            url: sub.url.clone(),
            name: sub.name.clone(),
            sub_type: sub.sub_type.clone(),
        };

        match legado_net::rule_update_client::fetch_subscription_with_hosts(
            &subscription,
            state.engine.network().custom_hosts().clone(),
        )
        .await
        {
            Ok(remote_json) => {
                // 尝试从远程 JSON 中提取版本信息
                let remote_version = extract_version(&remote_json);
                let has_update = match &remote_version {
                    Some(rv) => rv != &sub.version,
                    None => !remote_json.is_empty(),
                };

                results.push(CheckUpdateResult {
                    url: sub.url.clone(),
                    name: sub.name.clone(),
                    has_update,
                    remote_version,
                    error: None,
                });
            }
            Err(e) => {
                results.push(CheckUpdateResult {
                    url: sub.url.clone(),
                    name: sub.name.clone(),
                    has_update: false,
                    remote_version: None,
                    error: Some(e),
                });
            }
        }
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
        .with_database(move |db| RuleSubRepository::new(db.connection()).find_by_url(&target))
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

    let subscription = legado_net::RuleSubscription {
        url: sub.url.clone(),
        name: sub.name.clone(),
        sub_type: sub.sub_type.clone(),
    };

    let remote_json = match legado_net::rule_update_client::fetch_subscription_with_hosts(
        &subscription,
        state.engine.network().custom_hosts().clone(),
    )
    .await
    {
        Ok(content) => content,
        Err(e) => {
            return Ok(Json(json!({
                "success": false,
                "error": format!("拉取订阅失败: {e}"),
            })));
        }
    };

    // 使用空本地 JSON 进行合并（简化版：全量导入）
    let merge_result = legado_net::merge_subscription("[]", &remote_json, &sub.sub_type);

    let result = match merge_result {
        Ok(mr) => {
            // 更新订阅版本和时间
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as i64;

            let new_version = extract_version(&remote_json).unwrap_or_default();
            {
                if let Err(error) = state
                    .with_database(move |db| {
                        let _ = RuleSubRepository::new(db.connection()).update_version(
                            sub.id,
                            &new_version,
                            now,
                        );
                    })
                    .await
                {
                    tracing::warn!("更新订阅版本失败（已忽略）: {error}");
                }
            }

            ApplyUpdateResult {
                url: sub.url.clone(),
                success: true,
                items_added: mr.added,
                items_updated: mr.updated,
                items_removed: mr.removed,
                error: None,
            }
        }
        Err(e) => ApplyUpdateResult {
            url: sub.url.clone(),
            success: false,
            items_added: 0,
            items_updated: 0,
            items_removed: 0,
            error: Some(e),
        },
    };

    Ok(Json(json!(result)))
}

/// 尝试从 JSON 内容中提取版本信息
fn extract_version(json_str: &str) -> Option<String> {
    // 尝试解析为对象并查找 version 字段
    if let Ok(obj) = serde_json::from_str::<Value>(json_str)
        && let Some(v) = obj.get("version").and_then(|v| v.as_str())
    {
        return Some(v.to_string());
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::Router;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use axum::routing::{get, post};
    use tower::ServiceExt;

    use legado_db::Database;
    use legado_db::repository::rule_sub_repository::RuleSubRecord;

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

    #[test]
    fn test_extract_version() {
        assert_eq!(
            extract_version(r#"{"version": "1.2.3", "data": []}"#),
            Some("1.2.3".to_string())
        );
        assert_eq!(extract_version(r#"[{"a": 1}]"#), None);
        assert_eq!(extract_version("not json"), None);
    }
}
