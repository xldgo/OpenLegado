//! HTTP 服务启动逻辑

use std::future::IntoFuture;
use std::net::SocketAddr;
use std::sync::Arc;

use axum::body::Body;
use axum::extract::Request;
use axum::http::{StatusCode, header::HeaderName};
use axum::middleware::{Next, from_fn};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};

use crate::handlers;
use crate::routes::create_router;
use crate::state::AppState;

/// 对齐原版 `McpAccess.TOKEN_HEADER`
const MCP_TOKEN_HEADER: &str = "x-legado-token";

/// 服务器配置
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub db_path: String,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_string(),
            port: 8080,
            db_path: "legado.db".to_string(),
        }
    }
}

/// 启动 HTTP 服务器（自行打开数据库；供独立二进制/测试使用）
pub async fn start_server(config: ServerConfig) -> Result<(), Box<dyn std::error::Error>> {
    // 初始化数据库（含 schema 迁移）
    let engine =
        tokio::task::spawn_blocking(move || legado_engine::EngineContext::open(&config.db_path))
            .await??;
    let engine = Arc::new(engine);
    start_server_with_engine(&config.host, config.port, engine).await
}

/// 使用宿主注入的同一引擎启动服务，数据库和限流状态不另行创建。
/// FFI 仍在启动任务前绑定监听端口，绑定失败同步返回原错误。
pub async fn start_server_with_engine(
    host: &str,
    port: u16,
    engine: Arc<legado_engine::EngineContext>,
) -> Result<(), Box<dyn std::error::Error>> {
    let addr = format!("{host}:{port}").parse::<SocketAddr>()?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    serve_web(listener, engine).await
}

/// 在调用方预绑定的监听器上提供 Web 服务（与 [`start_server_with_engine`] 同构）
///
/// 差异仅在监听器由调用方持有：FFI 路径在 spawn 前同步
/// `TcpListener::bind`（失败即同步 Err，消除「假成功」，对齐
/// `serve_mcp` 形态），成功后把已绑定的 listener 交给本函数 serve。
pub async fn serve_web(
    listener: tokio::net::TcpListener,
    engine: Arc<legado_engine::EngineContext>,
) -> Result<(), Box<dyn std::error::Error>> {
    let scope = engine.tasks().child()?;
    serve_web_scoped(listener, engine, scope, Arc::new(Default::default())).await
}

/// 嵌入宿主把每次启停的作用域显式传入，不让两个监听器共用取消状态。
pub async fn serve_web_scoped(
    listener: tokio::net::TcpListener,
    engine: Arc<legado_engine::EngineContext>,
    scope: legado_engine::TaskGroup,
    services: Arc<crate::state::ServerServices>,
) -> Result<(), Box<dyn std::error::Error>> {
    let _closing = ServiceScope(scope.clone());
    let listener_task = scope.begin()?;
    let state = Arc::new(
        AppState::new(engine)
            .with_tasks(scope.clone())
            .with_services(services),
    );
    let router = supervise_requests(create_router(state), scope);
    let addr = listener.local_addr()?;
    tracing::info!("Legado server listening on {}", addr);
    tokio::select! {
        biased;
        _ = listener_task.cancelled() => {},
        result = axum::serve(listener, router).into_future() => { result?; },
    }
    Ok(())
}

struct ServiceScope(legado_engine::TaskGroup);
impl Drop for ServiceScope {
    fn drop(&mut self) {
        self.0.request_cancel();
    }
}

/// 请求收集者丢弃时不把仍在执行的 handler 冒充已退出。
/// 数据库和 JS 阻塞阶段另持凭据，连接关闭不丢失真实工作登记。
fn supervise_requests(router: Router, scope: legado_engine::TaskGroup) -> Router {
    router.layer(from_fn(move |request: Request<Body>, next: Next| {
        let scope = scope.clone();
        async move {
            let task = match scope.begin() {
                Ok(task) => task,
                Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, "服务正在关闭").into_response(),
            };
            match tokio::spawn(async move {
                let _task = task;
                next.run(request).await
            })
            .await
            {
                Ok(response) => response,
                Err(error) => {
                    tracing::warn!("服务请求任务异常: {error}");
                    (StatusCode::INTERNAL_SERVER_ERROR, "服务请求失败").into_response()
                }
            }
        }
    }))
}

/// 独立 MCP 服务专用路由（Task #73/76 + F5，契约 §2.22.5）
///
/// 暴露面收敛：仅挂载 MCP 端点 `/mcp/tools`（GET）/ `/mcp/call`（POST）
/// 与健康检查 `/health`，**不复用** [`create_router`] 全量路由。
/// F5：`/mcp/*` 经 `X-Legado-Token` 鉴权（对齐原版）；`/health` 免鉴权便于探测。
fn create_mcp_router(state: Arc<AppState>, expected_token: Arc<String>) -> Router {
    let token_for_layer = Arc::clone(&expected_token);
    Router::new()
        .route("/mcp/tools", get(handlers::mcp::get_tools))
        .route("/mcp/call", post(handlers::mcp::call_tool))
        .route(
            "/health",
            get(|| async { Json(serde_json::json!({"status": "ok"})) }),
        )
        .layer(from_fn(move |req: Request<Body>, next: Next| {
            let token = Arc::clone(&token_for_layer);
            async move {
                // /health 免鉴权（探测）；/mcp/* 要求 X-Legado-Token
                if req.uri().path() == "/health" {
                    return next.run(req).await;
                }
                mcp_token_middleware(token, req, next).await
            }
        }))
        .with_state(state)
}

async fn mcp_token_middleware(
    expected: Arc<String>,
    request: Request<Body>,
    next: Next,
) -> Response {
    let header_name = HeaderName::from_static(MCP_TOKEN_HEADER);
    let actual = request
        .headers()
        .get(&header_name)
        .and_then(|v| v.to_str().ok());
    if !matches_js_source_api_token(expected.as_str(), actual) {
        return (StatusCode::UNAUTHORIZED, "MCP token invalid or missing").into_response();
    }
    next.run(request).await
}

/// 对齐原版 `BookSourceController.matchesJsSourceApiToken`（字节级相等）
fn matches_js_source_api_token(expected: &str, actual: Option<&str>) -> bool {
    if expected.is_empty() {
        return false;
    }
    match actual {
        Some(a) => a.as_bytes() == expected.as_bytes(),
        None => false,
    }
}

/// 启动独立 MCP 服务（Task #73 / F5，契约 §2.22.5 `setMcpPort`）
///
/// 对齐原版 `McpService.kt`：调用方绑定 **0.0.0.0**；`expected_token` 非空
/// （由 `jsSourceApiToken` 注入）；`/mcp/*` 校验 `X-Legado-Token`。
pub async fn serve_mcp(
    listener: tokio::net::TcpListener,
    engine: Arc<legado_engine::EngineContext>,
    expected_token: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let scope = engine.tasks().child()?;
    serve_mcp_scoped(
        listener,
        engine,
        expected_token,
        scope,
        Arc::new(Default::default()),
    )
    .await
}

/// 独立 MCP 只接收自己的任务组，路由和令牌校验保持原实现。
pub async fn serve_mcp_scoped(
    listener: tokio::net::TcpListener,
    engine: Arc<legado_engine::EngineContext>,
    expected_token: String,
    scope: legado_engine::TaskGroup,
    services: Arc<crate::state::ServerServices>,
) -> Result<(), Box<dyn std::error::Error>> {
    let _closing = ServiceScope(scope.clone());
    let listener_task = scope.begin()?;
    let state = Arc::new(
        AppState::new(engine)
            .with_tasks(scope.clone())
            .with_services(services),
    );
    let router = supervise_requests(create_mcp_router(state, Arc::new(expected_token)), scope);
    let addr = listener.local_addr()?;
    tracing::info!("Legado standalone MCP service listening on {}", addr);
    tokio::select! {
        biased;
        _ = listener_task.cancelled() => {},
        result = axum::serve(listener, router).into_future() => { result?; },
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn disconnected_request_remains_registered_until_handler_returns() {
        use std::time::Duration;
        use tower::ServiceExt;
        let scope = legado_engine::TaskGroup::default();
        let entered = Arc::new(tokio::sync::Notify::new());
        let release = Arc::new(tokio::sync::Notify::new());
        let ready = entered.clone();
        let gate = release.clone();
        let router = supervise_requests(
            Router::new().route(
                "/blocked",
                get(move || {
                    let ready = ready.clone();
                    let gate = gate.clone();
                    async move {
                        ready.notify_one();
                        gate.notified().await;
                        "done"
                    }
                }),
            ),
            scope.clone(),
        );
        let request = tokio::spawn(
            router.clone().oneshot(
                Request::builder()
                    .uri("/blocked")
                    .body(Body::empty())
                    .unwrap(),
            ),
        );
        entered.notified().await;
        request.abort();
        let _ = request.await;
        assert!(!scope.shutdown(Duration::from_millis(20)).await);
        assert_eq!(scope.active_count(), 1);
        let refused = router
            .oneshot(
                Request::builder()
                    .uri("/blocked")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(refused.status(), StatusCode::SERVICE_UNAVAILABLE);
        release.notify_one();
        assert!(scope.shutdown(Duration::from_secs(2)).await);
    }

    #[test]
    fn test_matches_js_source_api_token() {
        assert!(!matches_js_source_api_token("", Some("x")));
        assert!(!matches_js_source_api_token("secret", None));
        assert!(!matches_js_source_api_token("secret", Some("wrong")));
        assert!(matches_js_source_api_token("secret", Some("secret")));
    }

    #[test]
    fn test_default_config() {
        let config = ServerConfig::default();
        assert_eq!(config.host, "127.0.0.1");
        assert_eq!(config.port, 8080);
        assert_eq!(config.db_path, "legado.db");
    }

    #[test]
    fn test_config_custom() {
        let config = ServerConfig {
            host: "0.0.0.0".to_string(),
            port: 3000,
            db_path: "/tmp/test.db".to_string(),
        };
        assert_eq!(config.host, "0.0.0.0");
        assert_eq!(config.port, 3000);
    }

    #[tokio::test]
    async fn test_server_bind_and_serve() {
        // 启动服务器后立刻关闭，验证绑定和路由构建无误
        let db = legado_db::init_in_memory_database().unwrap();
        let state = Arc::new(AppState::new(Arc::new(
            legado_engine::EngineContext::from_database(db),
        )));
        let router = create_router(state);

        // 绑定到随机可用端口
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();

        // 异步启动，然后立刻 drop 取消任务
        let handle = tokio::spawn(async move {
            let _ = axum::serve(listener, router).await;
        });

        // 验证能建立连接
        let _ = tokio::net::TcpStream::connect(addr).await.unwrap();

        handle.abort();
    }
}
