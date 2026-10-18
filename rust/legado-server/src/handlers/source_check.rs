//! 书源有效性检查处理器
//!
//! 提供以下端点：
//! - POST /api/sources/check       — 检查单个书源有效性
//! - POST /api/sources/check-batch — 批量检查书源（并行）

use std::sync::Arc;

use axum::Json;
use axum::extract::State;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tokio::task;

use crate::error::ApiError;
use crate::state::AppState;
use legado_core::models::BookSource;
use legado_net::source_checker::{CheckResult, CheckerConfig, SourceChecker};

/// 单个书源检查请求
#[derive(Debug, Deserialize)]
pub struct CheckSourceRequest {
    /// 完整书源对象
    pub source: BookSource,
    /// 可选搜索关键词
    pub keyword: Option<String>,
}

/// 批量检查请求
#[derive(Debug, Deserialize)]
pub struct CheckBatchRequest {
    /// 书源列表
    pub sources: Vec<BookSource>,
    /// 可选搜索关键词
    pub keyword: Option<String>,
    /// 显式值按1..20夹取；省略时取引擎threadCount并保留20上限。
    pub concurrency: Option<usize>,
}

/// 批量检查响应
#[derive(Debug, Serialize)]
pub struct CheckBatchResponse {
    pub results: Vec<CheckResult>,
    pub total: usize,
    pub passed: usize,
    pub failed: usize,
}

/// 创建 SourceChecker 实例
async fn create_checker(
    state: &AppState,
    keyword: Option<&str>,
) -> Result<SourceChecker, ApiError> {
    let client = state.network_client().await?;
    let config = CheckerConfig {
        keyword: keyword.unwrap_or("我的").to_string(),
        ..CheckerConfig::default()
    };
    Ok(SourceChecker::with_config(Arc::new(client), config))
}

/// POST /api/sources/check — 检查单个书源有效性
pub async fn check_source(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CheckSourceRequest>,
) -> Result<Json<Value>, ApiError> {
    let checker = create_checker(&state, req.keyword.as_deref()).await?;
    let result = checker.check_full(&req.source).await;
    Ok(Json(json!(result)))
}

/// 独立REST入口保留既有20上限；显式参数不被配置覆盖。
async fn batch_concurrency(state: &AppState, explicit: Option<usize>) -> Result<usize, ApiError> {
    if let Some(explicit) = explicit {
        return Ok(explicit.clamp(1, 20));
    }
    Ok(state
        .with_database(legado_engine::request_settings::from_database)
        .await
        .map_err(ApiError::from)?
        .map_err(ApiError::from)?
        .get()
        .min(20))
}

/// POST /api/sources/check-batch — 批量检查书源（并行）
pub async fn check_batch(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CheckBatchRequest>,
) -> Result<Json<Value>, ApiError> {
    let keyword = req.keyword.clone();
    let concurrency = batch_concurrency(&state, req.concurrency).await?;

    // 使用信号量控制并发
    let semaphore = Arc::new(tokio::sync::Semaphore::new(concurrency));
    let mut handles = Vec::with_capacity(req.sources.len());

    for source in req.sources {
        let sem = Arc::clone(&semaphore);
        let kw = keyword.clone();
        let state = state.clone();
        let task = state.task()?;
        let handle = task::spawn(async move {
            let _task = task;
            let _permit = sem.acquire().await;
            let checker = match create_checker(&state, kw.as_deref()).await {
                Ok(c) => c,
                Err(_) => {
                    return CheckResult {
                        source_url: source.book_source_url.clone(),
                        search_ok: false,
                        toc_ok: false,
                        content_ok: false,
                        search_error: Some("failed to create checker".to_string()),
                        toc_error: Some("skipped".to_string()),
                        content_error: Some("skipped".to_string()),
                        total_time_ms: 0,
                        captcha: None,
                        redirect: None,
                    };
                }
            };
            checker.check_full(&source).await
        });
        handles.push(handle);
    }

    let mut results = Vec::with_capacity(handles.len());
    for handle in handles {
        match handle.await {
            Ok(result) => results.push(result),
            Err(e) => {
                results.push(CheckResult {
                    source_url: "unknown".to_string(),
                    search_ok: false,
                    toc_ok: false,
                    content_ok: false,
                    search_error: Some(format!("task panicked: {}", e)),
                    toc_error: Some("skipped".to_string()),
                    content_error: Some("skipped".to_string()),
                    total_time_ms: 0,
                    captcha: None,
                    redirect: None,
                });
            }
        }
    }

    let total = results.len();
    let passed = results.iter().filter(|r| r.all_ok()).count();
    let failed = total - passed;

    let resp = CheckBatchResponse {
        results,
        total,
        passed,
        failed,
    };

    Ok(Json(json!(resp)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::{Method, Request, StatusCode};
    use tower::ServiceExt;

    use crate::routes::create_router;
    use crate::state::AppState;

    fn make_test_state() -> Arc<AppState> {
        let db = legado_db::init_in_memory_database().unwrap();
        Arc::new(AppState::new(Arc::new(
            legado_engine::EngineContext::from_database(db),
        )))
    }

    #[tokio::test]
    async fn batch_limit_uses_engine_config_and_preserves_explicit_cap() {
        let state = make_test_state();
        assert_eq!(batch_concurrency(&state, None).await.unwrap(), 16);
        for (stored, expected) in [("3", 3), ("256", 20)] {
            state
                .engine
                .storage()
                .with_database(|db| {
                    legado_db::CacheRepository::new(db.connection()).put(
                        "config:threadCount",
                        stored,
                        0,
                    )
                })
                .unwrap();
            assert_eq!(batch_concurrency(&state, None).await.unwrap(), expected);
        }
        for (explicit, expected) in [(0, 1), (7, 7), (256, 20)] {
            assert_eq!(
                batch_concurrency(&state, Some(explicit)).await.unwrap(),
                expected
            );
        }
        state
            .engine
            .storage()
            .with_database(|db| {
                db.connection()
                    .execute_batch("DROP TABLE caches")
                    .map_err(|error| legado_core::LegadoError::Database(error.to_string()))
            })
            .unwrap();
        assert!(batch_concurrency(&state, None).await.is_err());
        assert_eq!(batch_concurrency(&state, Some(7)).await.unwrap(), 7);
    }

    #[tokio::test]
    async fn test_check_source_endpoint() {
        let state = make_test_state();
        let app = create_router(state);

        let body = serde_json::to_string(&json!({
            "source": {
                "bookSourceUrl": "https://example.com",
                "bookSourceName": "Test",
                "searchUrl": "https://example.com/search?q={key}"
            }
        }))
        .unwrap();

        let resp = app
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/sources/check")
                    .header("Content-Type", "application/json")
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();

        // 请求应被接受处理（书源可能失败但端点本身正常）
        assert!(
            resp.status() == StatusCode::OK
                || resp.status() == StatusCode::BAD_GATEWAY
                || resp.status() == StatusCode::GATEWAY_TIMEOUT
        );
    }

    #[tokio::test]
    async fn test_check_batch_endpoint() {
        let state = make_test_state();
        let app = create_router(state);

        let body = serde_json::to_string(&json!({
            "sources": [
                {
                    "bookSourceUrl": "https://example.com",
                    "bookSourceName": "Test",
                    "searchUrl": "https://example.com/search?q={key}"
                }
            ],
            "concurrency": 2
        }))
        .unwrap();

        let resp = app
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/sources/check-batch")
                    .header("Content-Type", "application/json")
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert!(resp.status() == StatusCode::OK || resp.status() == StatusCode::BAD_GATEWAY);
    }

    #[tokio::test]
    async fn test_create_checker_default() {
        let checker = create_checker(&make_test_state(), None).await;
        assert!(checker.is_ok());
    }

    #[tokio::test]
    async fn test_create_checker_custom_keyword() {
        let checker = create_checker(&make_test_state(), Some("自定义")).await;
        assert!(checker.is_ok());
    }
}
