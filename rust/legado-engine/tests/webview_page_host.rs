//! 页内宿主行为测试：真实Rust数据/网络/解析，平台页面由夹具代替。
use legado_core::webview_channel::{WebViewManager, WebViewRequest};
use legado_engine::{
    EngineContext,
    webview_page_service::{PageCall, PageTarget, WebViewPageService},
};
use serde_json::{Value, json};
use std::{sync::Arc, time::Duration};
fn service(engine: &EngineContext) -> WebViewPageService {
    WebViewPageService {
        js: engine.js_resources().clone(),
        storage: Some(engine.storage().clone()),
    }
}
fn request(
    manager: &Arc<WebViewManager>,
    source: &str,
) -> legado_core::webview_channel::WebViewHandle {
    manager.request(WebViewRequest {
        source_key: source.into(),
        html: "<html>正文</html>".into(),
        is_rule: true,
        ..Default::default()
    })
}
fn invoke(
    service: &WebViewPageService,
    key: &str,
    target: PageTarget,
    method: &str,
    args: Vec<Option<&str>>,
) -> legado_core::LegadoResult<Value> {
    service
        .js
        .host_resources()
        .webview
        .with_page_call(key, |req, lease| {
            service.call(
                req,
                lease,
                PageCall {
                    target,
                    method: method.into(),
                    args: args.into_iter().map(|a| a.map(str::to_owned)).collect(),
                },
            )
        })
}
#[test]
fn source_and_cache_share_engine_data_without_platform_snapshots() {
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    let a = service(&one);
    let b = service(&two);
    let manager = &a.js.host_resources().webview;
    let handle = request(manager, "https://one.test");
    let key = handle.key();
    assert_eq!(
        invoke(
            &a,
            key,
            PageTarget::Source,
            "put",
            vec![Some("k"), Some("value")]
        )
        .unwrap(),
        json!("value")
    );
    assert_eq!(
        a.js.variables()
            .get_variable("v_https://one.test_k")
            .unwrap()
            .as_deref(),
        Some("value")
    );
    assert_eq!(
        invoke(&a, key, PageTarget::Java, "get", vec![Some("k")]).unwrap(),
        json!("value")
    );
    invoke(
        &a,
        key,
        PageTarget::Source,
        "putVariable",
        vec![Some("变量")],
    )
    .unwrap();
    assert_eq!(
        invoke(&a, key, PageTarget::Source, "getVariable", vec![]).unwrap(),
        json!("变量")
    );
    invoke(&a, key, PageTarget::Source, "putVariable", vec![None]).unwrap();
    assert_eq!(
        invoke(&a, key, PageTarget::Source, "getVariable", vec![]).unwrap(),
        json!("")
    );
    invoke(
        &a,
        key,
        PageTarget::Cache,
        "putMemory",
        vec![Some("m"), Some("memory")],
    )
    .unwrap();
    assert_eq!(
        a.js.host_resources().cache.get_from_memory("m").as_deref(),
        Some("memory")
    );
    assert!(a.js.host_resources().cache.get("m", true).is_none());
    invoke(
        &a,
        key,
        PageTarget::Cache,
        "put",
        vec![Some("d"), Some("disk"), Some("0")],
    )
    .unwrap();
    assert_eq!(
        a.js.host_resources().cache.get("d", true).as_deref(),
        Some("disk")
    );
    let next = request(manager, "https://one.test");
    assert_eq!(
        invoke(&a, next.key(), PageTarget::Source, "get", vec![Some("k")]).unwrap(),
        json!("value")
    );
    let different = request(manager, "https://two.test");
    assert_eq!(
        invoke(
            &a,
            different.key(),
            PageTarget::Source,
            "get",
            vec![Some("k")]
        )
        .unwrap(),
        json!("")
    );
    let other = request(&b.js.host_resources().webview, "https://one.test");
    assert_eq!(
        invoke(&b, other.key(), PageTarget::Source, "get", vec![Some("k")]).unwrap(),
        json!("")
    );
    assert_eq!(
        invoke(
            &b,
            other.key(),
            PageTarget::Cache,
            "getFromMemory",
            vec![Some("m")]
        )
        .unwrap(),
        Value::Null
    );
    assert!(
        invoke(
            &b,
            key,
            PageTarget::Source,
            "put",
            vec![Some("k"), Some("wrong")]
        )
        .is_err()
    );
    invoke(
        &a,
        key,
        PageTarget::Source,
        "putLoginInfo",
        vec![Some("凭据")],
    )
    .unwrap();
    assert_eq!(
        a.js.source_login_store()
            .unwrap()
            .get(
                legado_js::source_login::SourceLoginKind::Info,
                "https://one.test"
            )
            .as_deref(),
        Some("凭据")
    );
    invoke(&a, key, PageTarget::Source, "removeLoginInfo", vec![]).unwrap();
    assert_eq!(
        invoke(&a, key, PageTarget::Source, "getLoginInfo", vec![]).unwrap(),
        Value::Null
    );
    manager.cancel(key);
    assert!(
        invoke(
            &a,
            key,
            PageTarget::Source,
            "put",
            vec![Some("k"), Some("late")]
        )
        .is_err()
    );
    assert_eq!(
        a.js.variables()
            .get_variable("v_https://one.test_k")
            .unwrap()
            .as_deref(),
        Some("value")
    );
}
#[test]
fn invalid_calls_do_not_mutate_state_and_cache_has_real_expiry() {
    let engine = EngineContext::in_memory().unwrap();
    let api = service(&engine);
    let manager = &api.js.host_resources().webview;
    let handle = request(manager, "https://source.test");
    for (target, method, args) in [
        (PageTarget::Source, "put", vec![Some("k")]),
        (
            PageTarget::Cache,
            "put",
            vec![Some("k"), Some("v"), Some("bad")],
        ),
        (
            PageTarget::Java,
            "eval",
            vec![Some("source.put('k','wrong')")],
        ),
        (PageTarget::Cache, "get", vec![Some("k"), Some("yes")]),
    ] {
        assert!(invoke(&api, handle.key(), target, method, args).is_err());
    }
    assert!(api.js.variables().list_variable_keys().unwrap().is_empty());
    assert_eq!(
        invoke(
            &api,
            handle.key(),
            PageTarget::Cache,
            "get",
            vec![Some("k")]
        )
        .unwrap(),
        Value::Null
    );
    invoke(
        &api,
        handle.key(),
        PageTarget::Cache,
        "put",
        vec![Some("ttl"), Some("short"), Some("1")],
    )
    .unwrap();
    assert!(
        api.js
            .host_resources()
            .cache
            .get_from_memory("ttl")
            .is_none()
    );
    std::thread::sleep(Duration::from_millis(1100));
    assert_eq!(
        invoke(
            &api,
            handle.key(),
            PageTarget::Cache,
            "get",
            vec![Some("ttl")]
        )
        .unwrap(),
        Value::Null
    );
}
#[cfg(feature = "quickjs")]
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn page_network_and_parser_work_while_parent_vm_is_waiting() {
    use legado_parser::JsExecutor;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let engine = EngineContext::in_memory().unwrap();
    let api = Arc::new(service(&engine));
    let manager = api.js.host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", server.local_addr().unwrap());
    let serving = tokio::spawn(async move {
        let (mut socket, _) = server.accept().await.unwrap();
        let mut bytes = Vec::new();
        while !bytes.ends_with(b"\r\n\r\n") {
            bytes.push(socket.read_u8().await.unwrap());
            assert!(bytes.len() < 65536);
        }
        socket
            .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 4\r\nConnection: close\r\n\r\npage")
            .await
            .unwrap();
    });
    let executor = legado_js::executor::QuickJsExecutor::new("https://source.test")
        .with_resources(engine.js_resources().clone());
    let parent = tokio::task::spawn_blocking(move || {
        executor
            .execute_js("java.webView('<html>body</html>','https://page.test','document.title')")
    });
    let event = tokio::time::timeout(Duration::from_secs(2), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    let key = event.key.clone();
    let child = api.clone();
    let result = tokio::task::spawn_blocking(move || {
        assert_eq!(
            invoke(&child, &key, PageTarget::Java, "ajax", vec![Some(&url)]).unwrap(),
            json!("page")
        );
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Java,
                "getString",
                vec![Some("p@text"), Some("<p>正文</p>")]
            )
            .unwrap(),
            json!("正文")
        );
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Java,
                "getStringList",
                vec![Some("p@text"), Some("<p>甲</p><p>乙</p>")]
            )
            .unwrap(),
            json!(["甲", "乙"])
        );
    });
    let outcome = tokio::time::timeout(Duration::from_secs(4), result).await;
    manager.submit(&event.key, "finished");
    outcome.unwrap().unwrap();
    serving.await.unwrap();
    assert_eq!(parent.await.unwrap().unwrap(), "finished");
}

#[cfg(feature = "quickjs")]
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn page_network_shapes_and_source_login_reuse_existing_services() {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let engine = EngineContext::in_memory().unwrap();
    engine
        .storage()
        .with_database(|db| {
            legado_db::BookSourceRepository::new(db.connection()).insert_batch(&[
                legado_core::models::BookSource {
                    book_source_url: "https://source.test".into(),
                    login_url: Some("@js:function login(){ source.put('logged','yes'); }".into()),
                    ..Default::default()
                },
            ])
        })
        .unwrap();
    let api = Arc::new(service(&engine));
    let manager = &api.js.host_resources().webview;
    let handle = request(manager, "https://source.test");
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", server.local_addr().unwrap());
    let serving = tokio::spawn(async move {
        let mut requests = Vec::new();
        for _ in 0..5 {
            let (mut socket, _) = server.accept().await.unwrap();
            let mut bytes = Vec::new();
            while !bytes.ends_with(b"\r\n\r\n") {
                bytes.push(socket.read_u8().await.unwrap());
                assert!(bytes.len() < 65536);
            }
            let head = String::from_utf8(bytes).unwrap();
            let size = head
                .lines()
                .find_map(|l| {
                    l.to_ascii_lowercase()
                        .strip_prefix("content-length:")
                        .and_then(|v| v.trim().parse::<usize>().ok())
                })
                .unwrap_or(0);
            let mut body = vec![0; size];
            socket.read_exact(&mut body).await.unwrap();
            let response = if head.starts_with("HEAD ") {
                b"HTTP/1.0 201 Created\r\nX-Test: yes\r\nContent-Length: 4\r\nConnection: close\r\n\r\n".as_slice()
            } else {
                b"HTTP/1.0 201 Created\r\nX-Test: yes\r\nContent-Length: 4\r\nConnection: close\r\n\r\npage".as_slice()
            };
            socket.write_all(response).await.unwrap();
            requests.push((head, body));
        }
        requests
    });
    let key = handle.key().to_string();
    let child = api.clone();
    let endpoint = url.clone();
    tokio::task::spawn_blocking(move || {
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Java,
                "connect",
                vec![Some(&endpoint)]
            )
            .unwrap(),
            json!(format!(
                "Response{{protocol=http/1.0, code=201, message=Created, url={endpoint}}}"
            ))
        );
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Java,
                "get",
                vec![Some(&endpoint), Some("{}")]
            )
            .unwrap(),
            json!("page")
        );
        let head = invoke(
            &child,
            &key,
            PageTarget::Java,
            "head",
            vec![Some(&endpoint), Some("{}")],
        )
        .unwrap();
        let headers: Value = serde_json::from_str(head.as_str().unwrap()).unwrap();
        assert_eq!(headers["x-test"], "yes");
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Java,
                "post",
                vec![Some(&endpoint), Some("x=1"), Some("{}")]
            )
            .unwrap(),
            json!("page")
        );
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Java,
                "ajax",
                vec![Some(&endpoint), Some("9000")]
            )
            .unwrap(),
            json!("page")
        );
        invoke(&child, &key, PageTarget::Source, "login", vec![]).unwrap();
        assert_eq!(
            invoke(
                &child,
                &key,
                PageTarget::Source,
                "get",
                vec![Some("logged")]
            )
            .unwrap(),
            json!("yes")
        );
    })
    .await
    .unwrap();
    let requests = serving.await.unwrap();
    assert!(requests[2].0.starts_with("HEAD "));
    assert_eq!(requests[3].1, b"x=1");
}
#[cfg(feature = "quickjs")]
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn cancelling_page_call_interrupts_io_and_late_effects_are_rejected() {
    let engine = EngineContext::in_memory().unwrap();
    let api = Arc::new(service(&engine));
    let manager = api.js.host_resources().webview.clone();
    let handle = request(&manager, "https://source.test");
    let key = handle.key().to_owned();
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", server.local_addr().unwrap());
    let child = api.clone();
    let active = key.clone();
    let task = tokio::task::spawn_blocking(move || {
        invoke(&child, &active, PageTarget::Java, "ajax", vec![Some(&url)])
    });
    let (_socket, _) = tokio::time::timeout(Duration::from_secs(2), server.accept())
        .await
        .unwrap()
        .unwrap();
    manager.cancel(&key);
    assert!(
        tokio::time::timeout(Duration::from_secs(2), task)
            .await
            .unwrap()
            .unwrap()
            .is_err()
    );
    assert!(
        invoke(
            &api,
            &key,
            PageTarget::Source,
            "put",
            vec![Some("k"), Some("late")]
        )
        .is_err()
    );
    assert!(
        api.js
            .variables()
            .get_variable("v_https://source.test_k")
            .unwrap()
            .is_none()
    );
}
