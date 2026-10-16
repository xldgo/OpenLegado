//! FFI 开库前后的 mainJs VM 由同一引擎资源保存，并与 Web 连续调用共享。
#![cfg(feature = "quickjs")]

use legado_ffi::{
    api::{server_api, web_book},
    ffi::ffi::db_open,
    runtime,
};
use serde_json::{Value, json};

struct StopServer;
impl Drop for StopServer {
    fn drop(&mut self) {
        server_api::server_stop();
    }
}

#[test]
fn main_js_vm_survives_database_open_and_is_reused_by_web() {
    let source = json!({
        "bookSourceUrl": "https://local-js.test",
        "mainJs": "var calls = 0; function getBookInfo(){ calls++; return {name:'book-' + calls}; }"
    });
    let book_url = "https://local-js.test/book";
    let next_name = || {
        let info: Value =
            serde_json::from_str(&web_book::webbook_info(&source.to_string(), book_url).unwrap())
                .unwrap();
        info["name"].as_str().unwrap().to_owned()
    };
    assert_eq!(next_name(), "book-1");
    db_open(":memory:".into()).unwrap();
    assert_eq!(next_name(), "book-2");

    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    drop(listener);
    let _stop = StopServer;
    server_api::server_start(port).unwrap();
    runtime::block_on(async {
        let control = legado_net::tls::client_builder()
            .no_proxy()
            .timeout(std::time::Duration::from_secs(5))
            .build()
            .unwrap();
        let response = control
            .post(format!("http://127.0.0.1:{port}/api/webbook/info"))
            .json(&json!({"source": source, "book_url": book_url}))
            .send()
            .await
            .unwrap();
        let status = response.status();
        let body = response.text().await.unwrap();
        assert!(status.is_success(), "Web mainJs 调用失败：{status} {body}");
        let info: Value = serde_json::from_str(&body).unwrap();
        assert_eq!(info["name"], "book-3");
    });
    assert_eq!(next_name(), "book-4");
}
