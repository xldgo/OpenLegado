//! 经真实 HTTP 服务保存书源，验证内嵌服务刷新的是 FFI 已使用的同一限流窗口。

use legado_core::models::BookSource;
use legado_ffi::{
    api::{server_api, source, source_rate_limit},
    ffi::ffi::db_open,
    runtime,
};
use std::time::Duration;

struct StopServer;
impl Drop for StopServer {
    fn drop(&mut self) {
        server_api::server_stop();
    }
}

#[test]
fn embedded_server_updates_the_existing_ffi_rate_window() {
    let path = std::env::temp_dir().join(format!(
        "legado_engine_rate_{}_{}.db",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    db_open(path.to_str().unwrap().to_owned()).unwrap();
    let key = "engine-context-rate-test";
    let original = BookSource {
        book_source_url: key.into(),
        book_source_name: "共享限流".into(),
        concurrent_rate: Some("1/10000".into()),
        ..Default::default()
    };
    source::add_source(&serde_json::to_string(&original).unwrap()).unwrap();
    runtime::block_on(source_rate_limit::acquire_source_rate_limit(&original));

    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    drop(listener);
    let _stop = StopServer;
    server_api::server_start(port).unwrap();

    runtime::block_on(async {
        let client = legado_net::tls::client_builder()
            .no_proxy()
            .build()
            .unwrap();
        let url = format!("http://127.0.0.1:{port}/api/sources/{key}");
        let response = client
            .put(&url)
            .json(&serde_json::json!({
                "book_source_url":key, "book_source_name":"REST 更新", "concurrent_rate":"3/10000"
            }))
            .send()
            .await
            .unwrap();
        assert!(
            response.status().is_success(),
            "REST 更新失败: {}",
            response.status()
        );
        assert!(
            tokio::time::timeout(
                Duration::from_secs(1),
                source_rate_limit::acquire_source_rate_limit(&original)
            )
            .await
            .is_ok(),
            "REST 保存后 FFI 的旧快照应受新窗口约束"
        );

        let smaller = BookSource {
            concurrent_rate: Some("1/10000".into()),
            ..original.clone()
        };
        source::update_source(&serde_json::to_string(&smaller).unwrap()).unwrap();
        assert!(
            tokio::time::timeout(
                Duration::from_millis(30),
                source_rate_limit::acquire_source_rate_limit(&original)
            )
            .await
            .is_err()
        );

        let response = client.put(&url).json(&serde_json::json!({
            "book_source_url":key, "book_source_name":"再次 REST 更新", "concurrent_rate":"5/10000"
        })).send().await.unwrap();
        assert!(response.status().is_success());
        assert!(
            tokio::time::timeout(
                Duration::from_secs(1),
                source_rate_limit::acquire_source_rate_limit(&original)
            )
            .await
            .is_ok()
        );
    });
}
