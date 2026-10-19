//! URL规则通过真实QuickJS进入平台通道，平台回传由夹具模拟。
#![cfg(feature = "quickjs")]
use legado_engine::EngineContext;
use legado_js::executor::QuickJsExecutor;
use legado_parser::JsExecutor;
use std::{sync::Arc, time::Duration};

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn ajax_webview_get_dispatches_without_an_http_preflight() {
    let engine = EngineContext::in_memory().unwrap();
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/page", listener.local_addr().unwrap());
    let rule = format!(
        r#"{url},{{"webView":true,"webJs":"document.title","webViewDelayTime":12,"headers":{{"X-Test":"source"}}}}"#
    );
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let executor =
        QuickJsExecutor::new("https://source.test/").with_resources(engine.js_resources().clone());
    let worker = tokio::task::spawn_blocking(move || {
        executor.execute_js(&format!(
            "java.ajax({})",
            serde_json::to_string(&rule).unwrap()
        ))
    });
    let request =
        match tokio::time::timeout(Duration::from_secs(2), subscription.recv_async()).await {
            Ok(Some(request)) => request,
            _ => panic!("规则未进入WebView通道：{:?}", worker.await.unwrap()),
        };
    assert!(manager.submit(&request.key, "平台正文"));
    assert_eq!(worker.await.unwrap().unwrap(), "平台正文");
    assert_eq!(request.url, url);
    assert_eq!(
        request.headers.get("X-Test").map(String::as_str),
        Some("source")
    );
    assert_eq!(request.js, "document.title");
    assert_eq!(request.delay_time, 12);
    assert_eq!(request.source_key, "https://source.test/");
    assert!(
        tokio::time::timeout(Duration::from_millis(30), listener.accept())
            .await
            .is_err()
    );
}

async fn respond_once(listener: tokio::net::TcpListener, body: &str) -> String {
    respond(&listener, body, "200 OK", "").await
}

async fn respond(
    listener: &tokio::net::TcpListener,
    body: &str,
    status: &str,
    headers: &str,
) -> String {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    let (mut socket, _) = tokio::time::timeout(Duration::from_secs(3), listener.accept())
        .await
        .unwrap()
        .unwrap();
    let mut data = Vec::new();
    while !data.ends_with(b"\r\n\r\n") {
        data.push(socket.read_u8().await.unwrap());
        assert!(data.len() < 65536);
    }
    let head = String::from_utf8(data).unwrap();
    let size = head
        .lines()
        .find_map(|line| {
            line.to_ascii_lowercase()
                .strip_prefix("content-length:")
                .and_then(|n| n.trim().parse::<usize>().ok())
        })
        .unwrap_or(0);
    let mut request_body = vec![0; size];
    socket.read_exact(&mut request_body).await.unwrap();
    socket
        .write_all(
            format!(
                "HTTP/1.1 {status}\r\n{headers}Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            )
            .as_bytes(),
        )
        .await
        .unwrap();
    format!("{head}{}", String::from_utf8(request_body).unwrap())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn post_redirect_passes_final_http_url_and_html_to_platform() {
    let engine = EngineContext::in_memory().unwrap();
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let origin = format!("http://{}", server.local_addr().unwrap());
    let rule = format!(r#"{origin}/post,{{"method":"POST","body":"x=1","webView":true}}"#);
    let serving = tokio::spawn(async move {
        let post = respond(&server, "", "302 Found", "Location: /land\r\n").await;
        let redirected = respond(&server, "<html>landed</html>", "200 OK", "").await;
        assert!(post.starts_with("POST /post "));
        assert!(redirected.starts_with("GET /land "));
    });
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let executor =
        QuickJsExecutor::new("https://source.test/").with_resources(engine.js_resources().clone());
    let worker = tokio::task::spawn_blocking(move || {
        executor.execute_js(&format!(
            "java.ajax({})",
            serde_json::to_string(&rule).unwrap()
        ))
    });
    let request = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert!(manager.submit(&request.key, "页面结果"));
    assert_eq!(worker.await.unwrap().unwrap(), "页面结果");
    assert_eq!(request.url, format!("{origin}/land"));
    assert_eq!(request.html, "<html>landed</html>");
    serving.await.unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn post_fetches_html_once_and_connect_keeps_browser_final_url() {
    let engine = EngineContext::in_memory().unwrap();
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/post", server.local_addr().unwrap());
    let serving =
        tokio::spawn(async move { respond_once(server, "<html>prefetched</html>").await });
    let rule = format!(
        r#"{url},{{"method":"POST","body":"a=1","webView":true,"charset":"gbk","bodyJs":"throw new Error('不能执行')","headers":{{"X-Post":"yes"}}}}"#
    );
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let executor =
        QuickJsExecutor::new("https://source.test/").with_resources(engine.js_resources().clone());
    let script = format!(
        "var r=java.connect({});JSON.stringify([r.code(),r.body(),r.raw().request().url().toString()])",
        serde_json::to_string(&rule).unwrap()
    );
    let worker = tokio::task::spawn_blocking(move || executor.execute_js(&script));
    let request = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert!(manager.submit_response_with(
        &request.key,
        legado_core::webview_channel::WebViewResponse {
            result: "浏览器正文".into(),
            final_url: "https://final.test/page".into(),
            error: None
        },
        || {}
    ));
    let result: serde_json::Value = serde_json::from_str(&worker.await.unwrap().unwrap()).unwrap();
    assert_eq!(
        result,
        serde_json::json!([200, "浏览器正文", "https://final.test/page"])
    );
    let http = serving.await.unwrap();
    assert!(http.starts_with("POST /post HTTP/1.1"));
    assert!(http.ends_with("a=1"));
    assert!(http.to_ascii_lowercase().contains("x-post: yes"));
    assert_eq!(request.html, "<html>prefetched</html>");
    assert_eq!(request.url, url);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn mixed_batch_has_concurrent_platform_waits_and_preserves_input_order() {
    let engine = EngineContext::in_memory().unwrap();
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/plain", server.local_addr().unwrap());
    let serving = tokio::spawn(async move { respond_once(server, "普通响应").await });
    let rules = serde_json::json!([
        r#"https://one.test/,{"webView":true}"#,
        format!(r#"{url},{{"bodyJs":"result+'-已处理'"}}"#),
        r#"https://two.test/,{"webView":true,"bodyJs":"throw '不能执行'"}"#
    ]);
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let executor =
        QuickJsExecutor::new("https://source.test/").with_resources(engine.js_resources().clone());
    let worker = tokio::task::spawn_blocking(move || {
        executor.execute_js(&format!(
            "JSON.stringify(java.ajaxAll({rules}).map(function(r){{return r.body();}}))"
        ))
    });
    let first = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    let second = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert_ne!(first.key, second.key);
    for request in [second, first] {
        assert!(manager.submit(
            &request.key,
            if request.url.contains("one.test") {
                "第一"
            } else {
                "第三"
            }
        ));
    }
    let result: serde_json::Value = serde_json::from_str(&worker.await.unwrap().unwrap()).unwrap();
    assert_eq!(
        result,
        serde_json::json!(["第一", "普通响应-已处理", "第三"])
    );
    serving.await.unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn type_takes_priority_and_host_without_subscribers_does_not_fetch() {
    let engine = EngineContext::in_memory().unwrap();
    let executor =
        QuickJsExecutor::new("https://source.test/").with_resources(engine.js_resources().clone());
    let typed = tokio::task::spawn_blocking(move || {
        executor.execute_js(
            r#"java.ajax('data:;base64,T0s=,{"type":"bin","webView":true,"bodyJs":"throw 1"}')"#,
        )
    })
    .await
    .unwrap()
    .unwrap();
    assert_eq!(typed, "4f4b");
    let server = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", server.local_addr().unwrap());
    let rule = format!(r#"{url},{{"webView":true,"method":"POST","body":"a=1"}}"#);
    let executor =
        QuickJsExecutor::new("https://source.test/").with_resources(engine.js_resources().clone());
    let value = tokio::task::spawn_blocking(move || {
        executor.execute_js(&format!(
            "java.ajax({})",
            serde_json::to_string(&rule).unwrap()
        ))
    })
    .await
    .unwrap()
    .unwrap();
    assert!(value.contains("WebView执行订阅"));
    assert!(
        tokio::time::timeout(Duration::from_millis(30), server.accept())
            .await
            .is_err()
    );
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn task_cancel_drops_all_platform_waits_and_emits_control_events() {
    let engine = EngineContext::in_memory().unwrap();
    let task = Arc::new(engine.tasks().begin().unwrap());
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let executor = QuickJsExecutor::new("https://source.test/")
        .with_resources(engine.js_resources().with_cancellation(task.clone()));
    let worker = tokio::task::spawn_blocking(move || {
        executor.execute_js(r#"java.ajaxAll(['https://one.test/,{"webView":true}','https://two.test/,{"webView":true}'])"#)
    });
    let first = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    task.cancel();
    assert!(
        tokio::time::timeout(Duration::from_secs(2), worker)
            .await
            .unwrap()
            .unwrap()
            .is_err()
    );
    assert!(manager.pending().is_empty());
    assert!(!manager.submit(&first.key, "迟到"));
    let event = tokio::time::timeout(Duration::from_secs(1), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert_eq!(event.action, "cancel");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn probe_keeps_per_item_errors_but_normal_batch_cancels_other_waits() {
    for probe in [true, false] {
        let engine = EngineContext::in_memory().unwrap();
        let manager = engine.js_resources().host_resources().webview.clone();
        let mut subscription = manager.subscribe();
        let executor = QuickJsExecutor::new("https://source.test/")
            .with_resources(engine.js_resources().clone());
        let worker = tokio::task::spawn_blocking(move || {
            let method = if probe { "ajaxTestAll" } else { "ajaxAll" };
            executor.execute_js(&format!(
                r#"JSON.stringify(java.{method}(['https://bad.test/,{{"webView":true}}','https://ok.test/,{{"webView":true}}']).map(function(r){{return {{callTime:r.callTime(),body:r.body()}};}}))"#
            ))
        });
        let mut requests = Vec::new();
        for _ in 0..2 {
            requests.push(
                tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
                    .await
                    .unwrap()
                    .unwrap(),
            );
        }
        let bad = requests
            .iter()
            .find(|r| r.url.contains("bad.test"))
            .unwrap();
        let good = requests.iter().find(|r| r.url.contains("ok.test")).unwrap();
        assert!(manager.submit_response_with(
            &bad.key,
            legado_core::webview_channel::WebViewResponse {
                error: Some("平台失败".into()),
                ..Default::default()
            },
            || {}
        ));
        if probe {
            assert!(manager.submit(&good.key, "成功"));
        }
        let result = tokio::time::timeout(Duration::from_secs(3), worker)
            .await
            .unwrap()
            .unwrap();
        if probe {
            let value: serde_json::Value = serde_json::from_str(&result.unwrap()).unwrap();
            assert!(value[0]["callTime"].as_i64().unwrap() < 0);
            assert!(value[0]["body"].as_str().unwrap().contains("平台失败"));
            assert!(value[1]["callTime"].as_i64().unwrap() >= 0);
            assert_eq!(value[1]["body"], "成功");
        } else {
            assert!(result.unwrap_err().contains("平台失败"));
            assert!(!manager.submit(&good.key, "迟到成功"));
            let event = tokio::time::timeout(Duration::from_secs(1), subscription.recv_async())
                .await
                .unwrap()
                .unwrap();
            assert_eq!(
                (event.action.as_str(), event.key.as_str()),
                ("cancel", good.key.as_str())
            );
        }
        assert!(manager.pending().is_empty());
    }
}
