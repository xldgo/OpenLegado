//! 真实 Web 抓取使用 FFI 的发现参数服务，包括未能落库的内存修改。
#![cfg(feature = "quickjs")]

use legado_ffi::{
    api::{explore_info_map, server_api},
    ffi::ffi::db_open,
};
use serde_json::json;

struct StopServer;
impl Drop for StopServer {
    fn drop(&mut self) {
        server_api::server_stop();
    }
}

#[test]
fn web_search_observes_early_and_memory_only_ffi_info_map() {
    use std::io::{Read, Write};
    use std::time::{Duration, Instant};
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let url = format!("http://{}/search", listener.local_addr().unwrap());
    let fixture = std::thread::spawn(move || {
        let deadline = Instant::now() + Duration::from_secs(20);
        for _ in 0..3 {
            let (mut stream, _) = loop {
                match listener.accept() {
                    Ok(value) => break value,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "发现参数夹具未收到请求");
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(error) => panic!("夹具失败: {error}"),
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
            let body = r#"[{"url":"https://info-map.test/book"}]"#;
            write!(stream,"HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
        }
    });
    let source = "https://info-map.test";
    explore_info_map::put(source, "mode", "early").unwrap();
    let database = std::env::temp_dir().join(format!(
        "legado-info-map-{}-{}.db",
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
    legado_ffi::runtime::block_on(async {
        let client = legado_net::tls::client_builder()
            .no_proxy()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap();
        let payload = json!({"source": {"bookSourceUrl":source,"searchUrl":url,
            "ruleSearch":{"bookList":"$[*]","name":"@js:infoMap['mode']","bookUrl":"$.url"}}, "query":"probe","page":1});
        for expected in ["early", "updated", "memory-only"] {
            if expected == "memory-only" {
                legado_ffi::db_state::with_database(|db| db.connection().execute_batch("CREATE TRIGGER reject_info BEFORE INSERT ON caches WHEN NEW.key = 'infoMap_https://info-map.test' BEGIN SELECT RAISE(FAIL, 'fixture'); END;").map_err(|error|legado_core::LegadoError::Database(error.to_string()))).unwrap();
            }
            if expected != "early" {
                explore_info_map::put(source, "mode", expected).unwrap();
            }
            let response = client
                .post(format!("http://127.0.0.1:{port}/api/webbook/search"))
                .json(&payload)
                .send()
                .await
                .unwrap();
            assert!(response.status().is_success());
            let result = response.text().await.unwrap();
            assert!(
                result.contains(&format!("\"name\":\"{expected}\"")),
                "Web 未读取同一发现服务: {result}"
            );
        }
    });
    let persisted = legado_ffi::db_state::with_database(|db| {
        legado_db::CacheRepository::new(db.connection()).get(&format!("infoMap_{source}"))
    })
    .unwrap()
    .unwrap();
    assert!(persisted.contains("updated"));
    assert!(!persisted.contains("memory-only"));
    fixture.join().unwrap();
}
