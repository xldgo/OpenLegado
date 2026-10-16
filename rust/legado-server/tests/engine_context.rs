//! 两个路由宿主共享或隔离引擎时的数据行为，以及服务空闲时的连接归还。

use axum::{
    Router,
    body::{Body, to_bytes},
    http::Request,
};
use legado_engine::EngineContext;
use legado_server::{routes::create_router, state::AppState};
use std::sync::Arc;
use tower::ServiceExt;

async fn create_book(router: Router, name: &str) {
    let response = router
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/books")
                .header("content-type", "application/json")
                .body(Body::from(
                    serde_json::json!({"book_url":"same-book", "name":name}).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert!(response.status().is_success());
}

async fn names(router: Router) -> Vec<String> {
    let response = router
        .oneshot(
            Request::builder()
                .uri("/api/books")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert!(response.status().is_success());
    let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
    json["books"]
        .as_array()
        .unwrap()
        .iter()
        .map(|book| book["name"].as_str().unwrap().to_owned())
        .collect()
}

#[tokio::test]
async fn two_hosts_share_data_without_retaining_a_pool_connection() {
    let db = legado_db::Database::open_in_memory().unwrap();
    let pool = db.pool().clone();
    let context = Arc::new(EngineContext::from_database(db));
    let first = create_router(Arc::new(AppState::new(context.clone())));
    let second = create_router(Arc::new(AppState::new(context)));
    assert_eq!(pool.state().idle_connections, 1);
    create_book(first.clone(), "共享书架").await;
    let (one, two) = tokio::join!(names(first), names(second));
    assert_eq!(one, vec!["共享书架"]);
    assert_eq!(one, two);
    assert_eq!(pool.state().idle_connections, 1, "服务空闲时应归还唯一连接");
}

#[tokio::test]
async fn independent_hosts_do_not_share_book_data() {
    let first = create_router(Arc::new(AppState::new(Arc::new(
        EngineContext::in_memory().unwrap(),
    ))));
    let second = create_router(Arc::new(AppState::new(Arc::new(
        EngineContext::in_memory().unwrap(),
    ))));
    create_book(first.clone(), "第一实例").await;
    create_book(second.clone(), "第二实例").await;
    assert_eq!(names(first).await, vec!["第一实例"]);
    assert_eq!(names(second).await, vec!["第二实例"]);
}

#[tokio::test]
async fn idle_hosts_reuse_one_client_and_observe_cookie_updates_without_rebuild() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let first = AppState::new(engine.clone());
    let second = AppState::new(engine.clone());
    let one = first.network_client().await.unwrap();
    let two = second.network_client().await.unwrap();
    assert_eq!(one.client_id(), two.client_id());
    engine
        .network()
        .set_cookie("shared.test", "login=1")
        .unwrap();
    assert_eq!(
        two.cookie_store()
            .read()
            .unwrap()
            .get_key("shared.test", "login")
            .as_deref(),
        Some("1")
    );
    engine.network().clear_cookie_domain("shared.test").unwrap();
    assert!(
        one.cookie_store()
            .read()
            .unwrap()
            .domain_cookie_string("shared.test")
            .is_empty()
    );
}

#[cfg(feature = "quickjs")]
#[tokio::test]
async fn same_source_main_js_shares_vm_between_hosts_but_not_engines() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let first = create_router(Arc::new(AppState::new(engine.clone())));
    let same = create_router(Arc::new(AppState::new(engine)));
    let other = create_router(Arc::new(AppState::new(Arc::new(
        EngineContext::in_memory().unwrap(),
    ))));
    async fn next_name(router: Router) -> String {
        let response = router.oneshot(Request::builder()
            .method("POST")
            .uri("/api/webbook/info")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::json!({
                "source": {"bookSourceUrl": "https://same-source.test", "mainJs": "var calls = 0; function getBookInfo(){ calls++; return {name:'book-' + calls}; }"},
                "book_url": "https://same-source.test/book"
            }).to_string())).unwrap()).await.unwrap();
        let status = response.status();
        let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        assert!(
            status.is_success(),
            "mainJs 调用失败：{}",
            String::from_utf8_lossy(&bytes)
        );
        let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        value["name"].as_str().unwrap().to_owned()
    }
    assert_eq!(next_name(first.clone()).await, "book-1");
    assert_eq!(next_name(same).await, "book-2");
    assert_eq!(next_name(other).await, "book-1");
    assert_eq!(next_name(first).await, "book-3");
}
