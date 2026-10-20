//! 通过正式Router验证低速和小数倍速，不复制生产时长公式。
use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use std::{
    io::{BufRead, BufReader, Write},
    sync::Arc,
};
use tower::ServiceExt;
fn router() -> axum::Router {
    legado_server::routes::create_router(Arc::new(legado_server::state::AppState::new(Arc::new(
        legado_engine::EngineContext::in_memory().unwrap(),
    ))))
}
async fn call(
    router: axum::Router,
    url: &str,
    speed: Option<f32>,
) -> (StatusCode, serde_json::Value) {
    let mut json = serde_json::json!({"text":"abcd","engine_url":url});
    if let Some(s) = speed {
        json["speed"] = serde_json::json!(s);
    }
    let r = router
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/audio/speak")
                .header("content-type", "application/json")
                .body(Body::from(json.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let status = r.status();
    let bytes = to_bytes(r.into_body(), 1024 * 1024).await.unwrap();
    (status, serde_json::from_slice(&bytes).unwrap())
}
#[tokio::test]
async fn low_fractional_and_default_speeds_complete_without_panicking() {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}/audio", listener.local_addr().unwrap());
    let worker = std::thread::spawn(move || {
        for _ in 0..4 {
            let (mut s, _) = listener.accept().unwrap();
            s.set_read_timeout(Some(std::time::Duration::from_secs(5)))
                .unwrap();
            let mut request = BufReader::new(&mut s);
            let mut total = 0;
            loop {
                let mut line = String::new();
                let count = request.read_line(&mut line).unwrap();
                assert!(count > 0, "请求头未完整发送");
                total += count;
                assert!(total <= 16 * 1024, "请求头超出测试预算");
                if line == "\r\n" {
                    break;
                }
            }
            s.write_all(b"HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nContent-Length: 3\r\nConnection: close\r\n\r\nabc").unwrap();
        }
    });
    let router = router();
    for (speed, expected) in [
        (Some(0.5), 1600),
        (Some(1.0), 800),
        (Some(1.5), 533),
        (None, 800),
    ] {
        let (status, json) = call(router.clone(), &url, speed).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(json["estimated_duration_ms"], expected);
    }
    worker.join().unwrap();
}
#[tokio::test]
async fn invalid_speeds_are_rejected_before_network_access() {
    let router = router();
    for speed in [0.0, -0.5, f32::MIN_POSITIVE] {
        let (status, _) = call(router.clone(), "http://127.0.0.1:1/never", Some(speed)).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }
}
