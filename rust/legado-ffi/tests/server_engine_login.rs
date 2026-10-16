//! 开库前的登录值及开库后的更新/删除，经同一服务供 Web 抓取消费。

use legado_ffi::{
    api::{server_api, source_login_cache},
    ffi::ffi::db_open,
    runtime,
};
use serde_json::json;

struct StopServer;
impl Drop for StopServer {
    fn drop(&mut self) {
        server_api::server_stop();
    }
}

#[test]
fn web_requests_observe_ffi_login_before_open_updates_and_deletion() {
    use std::io::{Read, Write};
    use std::time::{Duration, Instant};
    let fixture_listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    fixture_listener.set_nonblocking(true).unwrap();
    let search_url = format!("http://{}/search", fixture_listener.local_addr().unwrap());
    let fixture = std::thread::spawn(move || {
        let deadline = Instant::now() + Duration::from_secs(15);
        for expected in [
            Some("Bearer early"),
            Some("Bearer updated"),
            None,
            Some("Bearer memory-only"),
            None,
        ] {
            let (mut stream, _) = loop {
                match fixture_listener.accept() {
                    Ok(accepted) => break accepted,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "Web 抓取未到达登录夹具");
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(error) => panic!("登录夹具接收失败: {error}"),
                }
            };
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut request = Vec::new();
            let mut chunk = [0; 1024];
            while !request.windows(4).any(|bytes| bytes == b"\r\n\r\n") {
                let read = stream.read(&mut chunk).unwrap();
                assert!(read > 0);
                request.extend_from_slice(&chunk[..read]);
            }
            let headers = String::from_utf8(request).unwrap();
            let authorization = headers.lines().find_map(|line| {
                let (key, value) = line.split_once(':')?;
                key.eq_ignore_ascii_case("authorization")
                    .then(|| value.trim())
            });
            assert_eq!(authorization, expected);
            let body = r#"[{"name":"登录缓存测试书","url":"https://login-fixture.test/book"}]"#;
            write!(stream, "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len()).unwrap();
        }
    });
    let source_url = "https://login-fixture.test";
    #[cfg(not(feature = "quickjs"))]
    source_login_cache::put_login_header(source_url, r#"{"Authorization":"Bearer early"}"#)
        .unwrap();
    #[cfg(feature = "quickjs")]
    {
        // 实际 V1 登录脚本在开库前写入，开库后 Web 使用同一个服务。
        let source = json!({ "bookSourceUrl": source_url,
            "loginUrl": "function login(){source.putLoginHeader(JSON.stringify({Authorization:'Bearer early'}));}" });
        let result =
            legado_ffi::api::source_login_v1_api::eval_login_v1(&source.to_string(), "login")
                .unwrap();
        assert!(result.contains("Bearer early"));
    }
    // FFI 使用多连接文件池，不能用每条连接各自独立的 :memory: 充当夹具。
    let database = std::env::temp_dir().join(format!(
        "legado-engine-login-{}-{}.db",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    db_open(database.to_string_lossy().into_owned()).unwrap();
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    drop(listener);
    let _stop = StopServer;
    server_api::server_start(port).unwrap();
    runtime::block_on(async {
        let control = legado_net::tls::client_builder()
            .no_proxy()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap();
        let payload = json!({
            "source": {
                "bookSourceUrl":source_url,
                "searchUrl":search_url,
                "ruleSearch":{"bookList":"$[*]","name":"$.name","bookUrl":"$.url"}
            },
            "query":"probe", "page":1
        });
        for step in 0..5 {
            match step {
                1 => {
                    #[cfg(not(feature = "quickjs"))]
                    source_login_cache::put_login_header(
                        source_url,
                        r#"{"Authorization":"Bearer updated"}"#,
                    )
                    .unwrap();
                    #[cfg(feature = "quickjs")]
                    legado_ffi::api::explore_api::explore_eval_action(
                        &json!({"bookSourceUrl": source_url}).to_string(),
                        "source.putLoginHeader(JSON.stringify({Authorization:'Bearer updated'}))",
                    )
                    .unwrap();
                }
                2 | 4 => {
                    #[cfg(not(feature = "quickjs"))]
                    source_login_cache::remove_login_header(source_url).unwrap();
                    #[cfg(feature = "quickjs")]
                    legado_ffi::api::explore_api::explore_eval_action(
                        &json!({"bookSourceUrl": source_url}).to_string(),
                        "source.removeLoginHeader()",
                    )
                    .unwrap();
                }
                3 => {
                    // DB 写入明确失败时，Web 必须看到同一服务的内存值，不能另起 DB 读路径。
                    legado_ffi::db_state::with_database(|db| {
                        db.connection().execute_batch("CREATE TRIGGER reject_login_insert BEFORE INSERT ON caches WHEN NEW.key = 'loginHeader_https://login-fixture.test' BEGIN SELECT RAISE(FAIL, '模拟持久化失败'); END;")
                            .map_err(|error| legado_core::LegadoError::Database(error.to_string()))
                    }).unwrap();
                    source_login_cache::put_login_header(
                        source_url,
                        r#"{"Authorization":"Bearer memory-only"}"#,
                    )
                    .unwrap();
                    assert!(
                        legado_ffi::db_state::with_database(|db| {
                            legado_db::CacheRepository::new(db.connection())
                                .get(&format!("loginHeader_{source_url}"))
                        })
                        .unwrap()
                        .is_none()
                    );
                }
                _ => {}
            }
            let response = control
                .post(format!("http://127.0.0.1:{port}/api/webbook/search"))
                .json(&payload)
                .send()
                .await
                .unwrap();
            let status = response.status();
            let body = response.text().await.unwrap();
            assert!(status.is_success(), "Web 登录态抓取失败: {status} {body}");
            let result: serde_json::Value = serde_json::from_str(&body).unwrap();
            assert_eq!(result["results"][0]["name"], "登录缓存测试书");
        }
    });
    fixture.join().unwrap();
    assert!(source_login_cache::get_login_header(source_url).is_none());
}
