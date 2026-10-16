//! 真实内嵌 HTTP 服务与 FFI/JS 的 Cookie 双向可见及 MCP 清除。
#![cfg(feature = "quickjs")]

use std::io::{Read, Write};
use std::time::Duration;

use legado_ffi::{api::server_api, db_state, ffi::ffi::db_open, http_state, runtime};
use legado_net::LegadoClientConfig;
use serde_json::json;

struct StopServer;
impl Drop for StopServer {
    fn drop(&mut self) {
        server_api::server_stop();
    }
}

#[test]
fn web_and_ffi_share_live_cookies_and_mcp_clears_every_bound_store() {
    let path = std::env::temp_dir().join(format!(
        "legado_network_{}_{}.db",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    db_open(path.to_str().unwrap().to_owned()).unwrap();
    http_state::reset_shared_client_with_config(LegadoClientConfig {
        no_proxy: true,
        ..Default::default()
    })
    .unwrap();
    let ffi_client = http_state::shared_client().unwrap();
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let source_url = format!("http://{}", listener.local_addr().unwrap());
    let fixture = std::thread::spawn(move || {
        let mut seen = Vec::new();
        for _ in 0..3 {
            let (mut stream, _) = listener.accept().unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 1024];
            while !request.windows(4).any(|part| part == b"\r\n\r\n") {
                let count = stream.read(&mut buffer).unwrap();
                assert!(count > 0);
                request.extend_from_slice(&buffer[..count]);
            }
            seen.push(String::from_utf8(request).unwrap());
            let body = "<div class=\"result\"><span class=\"name\">共享会话</span><span class=\"author\">作者</span><a class=\"book\" href=\"/book/1\">详情</a></div>";
            let response = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nSet-Cookie: srv=1; Path=/\r\nSet-Cookie: js=server; Path=/\r\nConnection: close\r\n\r\n{body}",
                body.len()
            );
            stream.write_all(response.as_bytes()).unwrap();
        }
        seen
    });

    // 显式 JS 写入必须立即进入已经构造好的共享客户端。
    legado_ffi::js_executor::execute_auto_task_js(&format!(
        "java.setCookie({}, 'js=1')",
        serde_json::to_string(&source_url).unwrap()
    ))
    .unwrap();
    assert_eq!(
        ffi_client
            .cookie_store()
            .read()
            .unwrap()
            .get_key("127.0.0.1", "js")
            .as_deref(),
        Some("1")
    );
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    drop(listener);
    let _stop = StopServer;
    server_api::server_start(port).unwrap();

    runtime::block_on(async {
        let control = legado_net::tls::client_builder()
            .no_proxy()
            .build()
            .unwrap();
        let response = control.post(format!("http://127.0.0.1:{port}/api/webbook/search"))
            .json(&json!({"source": {
                "bookSourceUrl":source_url, "bookSourceName":"共享网络夹具",
                "searchUrl":format!("{source_url}/search?q={{key}}"),
                "ruleSearch":{"bookList":"class.result", "name":"class.name@text", "author":"class.author@text", "bookUrl":"class.book@href"}
            }, "query":"共享", "page":1})).send().await.unwrap();
        assert!(response.status().is_success());
        let result: serde_json::Value = response.json().await.unwrap();
        assert_eq!(result["total"], 1);
        assert_eq!(
            ffi_client
                .cookie_store()
                .read()
                .unwrap()
                .get_key("127.0.0.1", "srv")
                .as_deref(),
            Some("1")
        );
        // VM 改其他键不得覆盖 HTTP 已更新的 js=server。
        legado_ffi::js_executor::execute_auto_task_js(&format!(
            "java.setCookie({}, 'extra=1')",
            serde_json::to_string(&source_url).unwrap()
        ))
        .unwrap();
        ffi_client.get_raw(&source_url, None).await.unwrap();

        let response: serde_json::Value = control.post(format!("http://127.0.0.1:{port}/mcp/call"))
            .json(&json!({"jsonrpc":"2.0", "id":1, "method":"tools/call", "params":{"name":"clear_cookies", "arguments":{"url":source_url}}}))
            .send().await.unwrap().json().await.unwrap();
        assert!(
            response.get("error").is_none_or(serde_json::Value::is_null),
            "MCP 清除失败: {response}"
        );
        assert_eq!(
            legado_ffi::js_executor::execute_auto_task_js(&format!(
                "java.getCookie({})",
                serde_json::to_string(&source_url).unwrap()
            ))
            .unwrap(),
            ""
        );
        ffi_client.get_raw(&source_url, None).await.unwrap();
    });
    let seen = fixture.join().unwrap();
    assert!(seen[0].contains("js=1"), "Web 必须看到 JS 写入的登录态");
    assert!(
        seen[1].contains("js=server") && seen[1].contains("srv=1") && seen[1].contains("extra=1"),
        "FFI 必须看到 Web 收到的响应 Cookie"
    );
    assert!(
        !seen[2].to_ascii_lowercase().contains("cookie:"),
        "清除后旧客户端也不得发送旧 Cookie"
    );
    assert!(
        db_state::with_database(
            |db| legado_db::CookieRepository::new(db.connection()).get_by_tag("127.0.0.1")
        )
        .unwrap()
        .is_none()
    );
}
