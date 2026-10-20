//! 实际 VM/HTTP/jar/数据库验证，不能由旧全局测试夹具代替。
#![cfg(feature = "quickjs")]

use legado_engine::EngineContext;
use legado_js::{JsEngine, SandboxConfig};
use std::sync::Arc;

fn fixture(count: usize) -> (String, std::thread::JoinHandle<()>) {
    use std::io::{Read, Write};
    use std::time::{Duration, Instant};
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let base = format!("http://{}", listener.local_addr().unwrap());
    let thread = std::thread::spawn(move || {
        let deadline = Instant::now() + Duration::from_secs(20);
        for _ in 0..count {
            let (mut socket, _) = loop {
                match listener.accept() {
                    Ok(value) => break value,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "网络能力夹具未收到请求");
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(error) => panic!("夹具接收失败: {error}"),
                }
            };
            socket.set_nonblocking(false).unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut bytes = Vec::new();
            let mut chunk = [0; 1024];
            while !bytes.windows(4).any(|bytes| bytes == b"\r\n\r\n") {
                let read = socket.read(&mut chunk).unwrap();
                assert!(read > 0);
                bytes.extend_from_slice(&chunk[..read]);
            }
            let request = String::from_utf8(bytes).unwrap();
            let header = |key: &str| {
                request
                    .lines()
                    .filter_map(|line| line.split_once(':'))
                    .find(|(name, _)| name.eq_ignore_ascii_case(key))
                    .map(|(_, value)| value.trim().to_string())
                    .unwrap_or_default()
            };
            let owner = header("X-Owner");
            let body = if request
                .lines()
                .next()
                .unwrap_or_default()
                .contains("/library")
            {
                format!(
                    "globalThis.fromJar={};",
                    serde_json::to_string(&header("Cookie")).unwrap()
                )
            } else {
                serde_json::json!({"cookie":header("Cookie"),"owner":owner}).to_string()
            };
            write!(socket,"HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nSet-Cookie: server={owner}; Path=/\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
        }
    });
    (base, thread)
}

fn source(engine: &EngineContext, tag: &str) {
    engine
        .storage()
        .with_database(|db| {
            legado_db::BookSourceRepository::new(db.connection()).insert_batch(&[
                legado_core::models::BookSource {
                    book_source_url: tag.into(),
                    enabled_cookie_jar: Some(true),
                    ..Default::default()
                },
            ])
        })
        .unwrap();
}

#[test]
fn js_requests_share_the_engine_source_rate_window() {
    use std::time::Duration;
    let (url, server) = fixture(7);
    let engine = EngineContext::in_memory().unwrap();
    source(&engine, &url);
    engine
        .storage()
        .with_database(|db| {
            db.connection()
                .execute(
                    "UPDATE book_sources SET concurrentRate='1/10000' WHERE bookSourceUrl=?1",
                    [&url],
                )
                .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
            Ok(())
        })
        .unwrap();
    let vm = engine
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    vm.eval(&format!(
        "globalThis.url={};java.ajax(url)",
        serde_json::to_string(&url).unwrap()
    ))
    .unwrap();
    for call in [
        "java.ajax(url)",
        "java.connect(url).body()",
        "java.get(url,{}).body()",
        "java.head(url,{}).body()",
        "java.post(url,'',{}).body()",
    ] {
        engine.rate_limiter().remove(&url);
        legado_js::host_api::current_source::with_current_source_tag(&url, || vm.eval(call))
            .unwrap();
        // JS真实请求已占用所属注册表的首个许可，抓取侧再次申请必须等待。
        // 使用长窗口+短观察期，不把客户端调度耗时误当作限流等待下限。
        let shared = legado_js::host_api::runtime_bridge::block_on(async {
            tokio::time::timeout(
                Duration::from_millis(50),
                engine.rate_limiter().acquire_key(&url, "1/10000"),
            )
            .await
        });
        let shared = shared.expect("测试宿主支持同步网络桥");
        assert!(shared.is_err(), "{call}未占用共享源限流窗口");
    }
    legado_js::host_api::current_source::with_current_source_tag(&url, || {
        vm.eval("java.ajaxAll([url],true)[0].body()")
    })
    .unwrap();
    server.join().unwrap();
}

#[test]
fn webview_payloads_use_the_same_vm_cookie_owner_and_keep_empty_url_empty() {
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    for (engine, owner) in [(&one, "one"), (&two, "two")] {
        let vm = engine
            .js_resources()
            .create_engine(SandboxConfig::default())
            .unwrap();
        vm.eval(&format!(
            "java.setCookie('https://browser.test','session={owner}')"
        ))
        .unwrap();
        legado_js::host_api::current_source::with_current_source_tag("https://source.test", || {
            for call in [
                "java.webView('', 'https://browser.test', '')",
                "java.webViewGetSource('', 'https://browser.test', '', '')",
                "java.webViewGetOverrideUrl('', 'https://browser.test', '', '.*')",
            ] {
                let payload: serde_json::Value =
                    serde_json::from_str(&vm.eval(call).unwrap()).unwrap();
                assert_eq!(payload["cookie"], format!("session={owner}"));
                assert_eq!(payload["sourceKey"], "https://source.test");
            }
        });
        vm.eval("java.setCookie('', 'bad=empty-domain')").unwrap();
        let payload: serde_json::Value =
            serde_json::from_str(&vm.eval("java.webView('', '', '')").unwrap()).unwrap();
        assert_eq!(payload["cookie"], "");
    }
}

#[test]
fn same_library_url_uses_own_cookie_and_own_memory_cache() {
    use legado_js::host_api::jslib_loader::{default_js_lib_fetcher, resolve_js_lib_url_map};
    let (base, fixture) = fixture(2);
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    let map = serde_json::json!({"library":format!("{base}/library.js")}).to_string();
    for (engine, owner) in [(&one, "one"), (&two, "two")] {
        let http = engine.js_resources().http_resources();
        http.set_cookie(&base, &format!("owner={owner}"));
        let fetch = |url: &str| default_js_lib_fetcher(http, url);
        let script = resolve_js_lib_url_map(http, &map, "same-source", &fetch).unwrap();
        // 第二次解析若未命中本实例缓存会额外访问夹具，从而耗尽请求数并失败。
        assert_eq!(
            resolve_js_lib_url_map(http, &map, "same-source", &fetch).unwrap(),
            script
        );
        let vm = engine
            .js_resources()
            .create_engine(SandboxConfig::default())
            .unwrap();
        vm.eval(&script).unwrap();
        assert_eq!(vm.eval("fromJar").unwrap(), format!("owner={owner}"));
    }
    fixture.join().unwrap();
}

#[test]
fn persisted_cookie_is_visible_before_first_network_request_and_failed_js_write_stays_in_memory() {
    let db = legado_db::init_in_memory_database().unwrap();
    legado_db::CookieRepository::new(db.connection())
        .upsert("cold-cookie.test", "session=stored")
        .unwrap();
    let engine = EngineContext::from_database(db);
    let vm = engine
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    assert_eq!(
        vm.eval("java.getCookie('https://cold-cookie.test/path','session')")
            .unwrap(),
        "stored"
    );
    engine.storage().with_database(|db|db.connection().execute_batch("CREATE TRIGGER reject_cookie BEFORE INSERT ON cookies BEGIN SELECT RAISE(FAIL, 'fixture'); END; CREATE TRIGGER reject_cookie_update BEFORE UPDATE ON cookies BEGIN SELECT RAISE(FAIL, 'fixture'); END;").map_err(|error|legado_core::LegadoError::Database(error.to_string()))).unwrap();
    assert_eq!(
        vm.eval("java.setCookie('https://cold-cookie.test/path','session=memory-only')")
            .unwrap(),
        "true"
    );
    assert_eq!(
        vm.eval("java.getCookie('https://cold-cookie.test/path','session')")
            .unwrap(),
        "memory-only"
    );
    assert_eq!(
        engine
            .storage()
            .with_database(|db| legado_db::CookieRepository::new(db.connection())
                .get_by_tag("cold-cookie.test"))
            .unwrap()
            .as_deref(),
        Some("session=stored")
    );
}

#[test]
fn actual_vms_share_their_own_http_jar_and_database_but_not_another_engine() {
    let (base, fixture) = fixture(5);
    let tag = "https://same-source.test";
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    source(&one, tag);
    source(&two, tag);
    let a = one
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    let b = two
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    let eval = |vm: &legado_js::QuickJsEngine, code: &str| {
        legado_js::host_api::current_source::with_current_source_tag(tag, || vm.eval(code).unwrap())
    };
    for (vm, owner) in [(&a, "one"), (&b, "two")] {
        eval(
            vm,
            &format!(
                "java.setCookie('{base}/seed','manual={owner}');java.putGlobalHeaders('{{\"X-Owner\":\"{owner}\"}}')"
            ),
        );
    }
    // 第三个引擎写同域不能影响前两个引擎的权威罐。
    let unrelated = EngineContext::in_memory().unwrap();
    unrelated
        .js_resources()
        .http_resources()
        .set_cookie(&base, "unrelated=wrong");
    for (vm, engine, owner) in [(&a, &one, "one"), (&b, &two, "two"), (&a, &one, "one")] {
        let response: serde_json::Value =
            serde_json::from_str(&eval(vm, &format!("java.ajax('{base}/echo')"))).unwrap();
        assert_eq!(response["owner"], owner);
        let cookie = response["cookie"].as_str().unwrap();
        assert!(cookie.contains(&format!("manual={owner}")));
        assert!(!cookie.contains("wrong"));
        let read = eval(vm, &format!("java.getCookie('{base}/read')"));
        assert!(read.contains(&format!("server={owner}")));
        let persisted = engine
            .storage()
            .with_database(|db| {
                legado_db::CookieRepository::new(db.connection()).get_by_tag("127.0.0.1")
            })
            .unwrap()
            .unwrap();
        assert!(persisted.contains(&format!("server={owner}")));
        assert_eq!(
            eval(vm, "java.getCookie('https://foreign-domain.test')"),
            ""
        );
    }
    // 原生 HTTP 客户端读同一罐；重建 JS 连接池仍不丢 Cookie。
    one.js_resources().http_resources().reset_clients();
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let response = runtime
        .block_on(
            one.network()
                .client()
                .unwrap()
                .get(&format!("{base}/native"), None),
        )
        .unwrap();
    assert!(response.body.contains("manual=one"));
    assert!(response.body.contains("server=one"));
    assert!(eval(&a, &format!("java.ajax('{base}/again')")).contains("manual=one"));
    eval(&a, &format!("java.clearCookies('{base}/read')"));
    assert!(
        one.network()
            .cookie_store()
            .read()
            .unwrap()
            .domain_cookie_string("127.0.0.1")
            .is_empty()
    );
    assert!(
        one.storage()
            .with_database(
                |db| legado_db::CookieRepository::new(db.connection()).get_by_tag("127.0.0.1")
            )
            .unwrap()
            .is_none()
    );
    assert!(eval(&b, &format!("java.getCookie('{base}/read')")).contains("manual=two"));
    fixture.join().unwrap();
}

#[test]
fn request_snapshot_survives_changed_source_headers_and_batch_async_execution() {
    let (base, fixture) = fixture(3);
    let engine = EngineContext::in_memory().unwrap();
    let tag = "https://snapshot-source.test";
    source(&engine, tag);
    let http = engine.js_resources().http_resources();
    http.put_headers(
        tag,
        std::collections::HashMap::from([("X-Owner".into(), "before".into())]),
    );
    let request = http.request_for(Some(tag));
    http.put_headers(
        tag,
        std::collections::HashMap::from([("X-Owner".into(), "after".into())]),
    );
    legado_js::host_api::current_source::with_current_source_tag(
        "https://disabled-source.test",
        || {
            let response =
                legado_js::host_api::network::ajax(&request, &format!("{base}/echo")).unwrap();
            assert!(response.contains("before"));
            assert!(!response.contains("after"));
            let urls =
                serde_json::json!([format!("{base}/batch1"), format!("{base}/batch2")]).to_string();
            let response = legado_js::host_api::network::ajax_all(&request, &urls).unwrap();
            let rows: Vec<legado_js::host_api::network::HttpResponse> =
                serde_json::from_str(&response).unwrap();
            assert_eq!(rows.len(), 2);
            for row in rows {
                let body: serde_json::Value = serde_json::from_str(&row.body).unwrap();
                assert_eq!(
                    body["owner"], "before",
                    "每个批量请求都必须携带原快照，不能读已修改的来源头"
                );
            }
        },
    );
    // 批量请求现在携带原 owner，响应 Cookie 也必须按原开启快照写回。
    assert_eq!(
        engine
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_key("127.0.0.1", "server")
            .as_deref(),
        Some("before")
    );
    fixture.join().unwrap();
}

#[test]
fn cached_and_fresh_callbacks_do_not_keep_root_alive_and_network_releases_after_vm() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let resources = engine.js_resources().clone();
    let weak_root = Arc::downgrade(&engine);
    let weak_http = Arc::downgrade(resources.http_resources());
    let fresh = resources.create_engine(SandboxConfig::default()).unwrap();
    let cached = resources
        .engine_cache()
        .get_or_create_with_resources("source", None, None, None, &resources)
        .unwrap()
        .engine;
    drop(engine);
    drop(resources);
    assert!(weak_root.upgrade().is_none());
    assert!(weak_http.upgrade().is_some());
    assert_eq!(
        fresh.eval("java.getCookie('https://empty.test')").unwrap(),
        ""
    );
    drop(fresh);
    drop(cached);
    assert!(weak_http.upgrade().is_none());
}
