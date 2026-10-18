//! 真实QuickJS、解析与正文入口复验；通道模拟平台回传，不声称DOM执行验证。
#![cfg(feature = "quickjs")]
use legado_engine::EngineContext;
use legado_js::executor::QuickJsExecutor;
use legado_parser::JsExecutor;
use std::{sync::Arc, time::Duration};
struct CancelOnDrop(Arc<legado_engine::TaskHandle>);
impl Drop for CancelOnDrop {
    fn drop(&mut self) {
        self.0.cancel();
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn cached_and_fresh_webview_waits_cancel_and_same_cache_can_run_again() {
    for lib in [
        None,
        Some(r#"{"lib":"globalThis.fromFresh=17;"}"#.to_string()),
    ] {
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        let manager = engine.js_resources().host_resources().webview.clone();
        let mut subscription = manager.subscribe();
        let task = Arc::new(engine.tasks().begin().unwrap());
        let weak = Arc::downgrade(&task);
        let cleanup = CancelOnDrop(task.clone());
        let executor = QuickJsExecutor::new("https://view.test")
            .with_resources(engine.js_resources().with_cancellation(task.clone()))
            .with_js_lib(lib.clone());
        let worker = tokio::task::spawn_blocking(move || {
            executor.execute_js(
            "globalThis.saved=7;java.webView('', 'https://view.test/', 'document.title');java.setCookie('https://view.test/','late=yes');'late'")
        });
        let event = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
            .await
            .unwrap()
            .unwrap();
        task.cancel();
        let result = tokio::time::timeout(Duration::from_secs(2), worker)
            .await
            .unwrap()
            .unwrap();
        assert!(result.unwrap_err().contains("取消"));
        assert!(manager.pending().is_empty());
        assert!(!manager.submit(&event.key, "late"));
        assert!(
            !engine
                .js_resources()
                .http_resources()
                .cookies_for_url("https://view.test/")
                .contains("late=yes")
        );
        drop(cleanup);
        drop(task);
        assert!(weak.upgrade().is_none(), "VM缓存保留旧任务");
        assert_eq!(engine.tasks().active_count(), 0);
        let fresh = lib.is_some();
        let next = QuickJsExecutor::new("https://view.test")
            .with_resources(engine.js_resources().clone())
            .with_js_lib(lib.clone());
        let value = tokio::task::spawn_blocking(move || {
            next.execute_js(if fresh { "fromFresh+1" } else { "saved+1" })
        })
        .await
        .unwrap()
        .unwrap();
        assert_eq!(value, if fresh { "18" } else { "8" });
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn webview_vms_and_results_are_isolated_by_engine() {
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    let a = one.js_resources().host_resources().webview.clone();
    let b = two.js_resources().host_resources().webview.clone();
    let mut sa = a.subscribe();
    let mut sb = b.subscribe();
    let execute = |engine: &EngineContext| {
        let executor = QuickJsExecutor::new("https://same.view.test")
            .with_resources(engine.js_resources().clone());
        tokio::task::spawn_blocking(move || {
            executor.execute_js("java.webView('', 'https://same.view.test/', 'document.title')")
        })
    };
    let wa = execute(&one);
    let wb = execute(&two);
    let ea = tokio::time::timeout(Duration::from_secs(3), sa.recv_async())
        .await
        .unwrap()
        .unwrap();
    let eb = tokio::time::timeout(Duration::from_secs(3), sb.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert_ne!(ea.key, eb.key);
    assert!(!a.submit(&eb.key, "wrong"));
    assert!(!b.submit(&ea.key, "wrong"));
    assert!(a.submit(&ea.key, "one"));
    assert!(b.submit(&eb.key, "two"));
    assert_eq!(wa.await.unwrap().unwrap(), "one");
    assert_eq!(wb.await.unwrap().unwrap(), "two");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn parser_webjs_cancels_without_headless_retry_and_owner_can_drop() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak = Arc::downgrade(&engine);
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let tasks = engine.tasks().clone();
    let task = Arc::new(tasks.begin().unwrap());
    let _cleanup = CancelOnDrop(task.clone());
    let executor = Arc::new(
        QuickJsExecutor::new("https://rule.view.test")
            .with_resources(engine.js_resources().with_cancellation(task)),
    );
    let worker = tokio::task::spawn_blocking(move || {
        let analyzer = legado_parser::AnalyzeRule::with_js_executor(
            "正文".into(),
            "https://rule.view.test/".into(),
            executor,
        );
        analyzer.get_string(
            "@webjs:java.setCookie('https://rule.view.test/','fallback=yes');'fallback'",
        )
    });
    let event = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert!(event.is_rule);
    drop(engine);
    assert!(weak.upgrade().is_none());
    assert!(
        tokio::time::timeout(Duration::from_secs(2), worker)
            .await
            .unwrap()
            .unwrap()
            .is_err()
    );
    assert!(!manager.submit(&event.key, "late"));
    assert!(manager.pending().is_empty());
    drop(_cleanup);
    assert!(tasks.shutdown(Duration::from_secs(1)).await);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn content_hooks_use_current_webview_and_cancel_without_parsing_fallback() {
    use legado_core::{
        models::{BookSource, rule::ContentRule},
        web_book::{BookSourceFetcher, WebChapter},
    };
    use legado_fetcher::{deps::FetcherDeps, web_book::RealBookSourceFetcher};
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpListener,
    };
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/chapter", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut request = Vec::new();
        while !request.ends_with(b"\r\n\r\n") {
            let mut b = [0];
            socket.read_exact(&mut b).await.unwrap();
            request.push(b[0]);
        }
        let body = "<html><body>original</body></html>";
        socket.write_all(format!("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).as_bytes()).await.unwrap();
    });
    let engine = EngineContext::in_memory().unwrap();
    let task = Arc::new(engine.tasks().begin().unwrap());
    let cleanup = CancelOnDrop(task.clone());
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let deps = FetcherDeps::new(engine.network().client().unwrap())
        .with_js_resources(engine.js_resources().with_cancellation(task.clone()));
    let source = BookSource {
        book_source_url: url.clone(),
        rule_content: Some(ContentRule {
            content: Some("body@text".into()),
            web_js: Some("document.body.innerHTML".into()),
            ..Default::default()
        }),
        ..Default::default()
    };
    let chapter = WebChapter {
        index: 0,
        title: "章节".into(),
        url,
        is_vip: false,
        is_volume: false,
        variable: None,
        word_count: None,
    };
    let worker = tokio::task::spawn_blocking(move || {
        tokio::runtime::Handle::current()
            .block_on(RealBookSourceFetcher::with_deps(deps).get_content(&source, &chapter))
    });
    let request = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
        .await
        .unwrap()
        .unwrap();
    assert_eq!(request.action, "webView");
    assert!(!request.is_rule);
    task.cancel();
    assert!(
        tokio::time::timeout(Duration::from_secs(2), worker)
            .await
            .unwrap()
            .unwrap()
            .is_err()
    );
    assert!(!manager.submit(&request.key, "late"));
    assert!(manager.pending().is_empty());
    server.await.unwrap();
    drop(cleanup);
    drop(task);
    assert_eq!(engine.tasks().active_count(), 0);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn explicit_platform_cancel_is_a_js_error_for_all_three_webview_methods() {
    for call in [
        "java.webView('', 'https://view.test/', 'document.title')",
        "java.webViewGetSource('', 'https://view.test/', '', '.*')",
        "java.webViewGetOverrideUrl('', 'https://view.test/', '', '.*')",
    ] {
        let engine = EngineContext::in_memory().unwrap();
        let manager = engine.js_resources().host_resources().webview.clone();
        let mut subscriber = manager.subscribe();
        let executor =
            QuickJsExecutor::new("https://view.test").with_resources(engine.js_resources().clone());
        let script = format!("{call};java.setCookie('https://view.test/','late=yes');'unexpected'");
        let worker = tokio::task::spawn_blocking(move || executor.execute_js(&script));
        let request = tokio::time::timeout(Duration::from_secs(3), subscriber.recv_async())
            .await
            .unwrap()
            .unwrap();
        assert!(manager.cancel(&request.key));
        let error = tokio::time::timeout(Duration::from_secs(2), worker)
            .await
            .unwrap()
            .unwrap()
            .unwrap_err();
        assert!(error.contains("取消"), "{error}");
        assert!(
            !engine
                .js_resources()
                .http_resources()
                .cookies_for_url("https://view.test/")
                .contains("late=yes")
        );
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn platform_error_payload_is_not_successful_text_or_a_headless_retry() {
    use legado_parser::analyze_rule::AnalyzeRule;
    let engine = EngineContext::in_memory().unwrap();
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscriber = manager.subscribe();
    for rule in [false, true] {
        let executor = Arc::new(
            QuickJsExecutor::new("https://view.test").with_resources(engine.js_resources().clone()),
        );
        let worker = tokio::task::spawn_blocking(move || {
            if rule {
                AnalyzeRule::with_js_executor("body".into(), "https://view.test/".into(), executor)
                    .get_string("@webjs:'headless-retry'")
                    .map_err(|e| e.to_string())
            } else {
                executor.execute_js(
                    "java.webView('', 'https://view.test/', 'document.title');'unexpected'",
                )
            }
        });
        let request = tokio::time::timeout(Duration::from_secs(3), subscriber.recv_async())
            .await
            .unwrap()
            .unwrap();
        assert!(manager.submit(&request.key, "[ERROR] WebView加载失败"));
        let error = tokio::time::timeout(Duration::from_secs(2), worker)
            .await
            .unwrap()
            .unwrap()
            .unwrap_err();
        assert!(error.contains("WebView加载失败"), "{error}");
    }
}
