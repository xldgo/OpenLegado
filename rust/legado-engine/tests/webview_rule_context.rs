//! 规则请求的来源与Cookie传递，模拟平台回传，不验证真实DOM。
use legado_engine::EngineContext;
use legado_fetcher::js_adapter::{
    build_toc_page_context, construct_analyzer_with_js_lib, construct_analyzer_with_source_context,
    construct_toc_page_analyzer,
};
use std::time::Duration;

#[test]
fn rule_callback_does_not_retain_resource_or_vm_owner() {
    let resources = std::sync::Arc::new(legado_js::JsResources::default());
    let weak = std::sync::Arc::downgrade(&resources);
    let callback = legado_js::webview::executor(&resources, "https://source.test/");
    drop(resources);
    assert!(weak.upgrade().is_none());
    drop(callback);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn analyzer_factories_preserve_source_identity() {
    let engine = EngineContext::in_memory().unwrap();
    let resources = engine.js_resources();
    let manager = resources.host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    let source = "https://source.catalog.test/";
    let page = "https://page.content.test/chapter";
    for mode in 0..3 {
        let context = build_toc_page_context(resources, source, None, None);
        let analyzer = match mode {
            0 => construct_analyzer_with_js_lib(
                resources,
                "小说正文".into(),
                page.into(),
                source,
                None,
            ),
            1 => construct_analyzer_with_source_context(
                resources,
                "小说正文".into(),
                page.into(),
                source,
                None,
                None,
            ),
            _ => construct_toc_page_analyzer(&context, "小说正文".into(), page.into()),
        };
        let worker =
            tokio::task::spawn_blocking(move || analyzer.get_string("@webjs:document.title"));
        let request = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
            .await
            .unwrap()
            .unwrap();
        // 先唤醒工作线程，断言失败时也不让阻塞线程等待默认超时。
        assert!(manager.submit(&request.key, "执行结果"));
        let result = worker.await.unwrap().unwrap();
        assert_eq!(request.source_key, source, "工厂{mode}丢失来源");
        assert_eq!(request.url, page);
        assert!(request.is_rule);
        assert_eq!(request.result, serde_json::to_string("小说正文").unwrap());
        assert_eq!(result, "执行结果");
    }
}

#[cfg(feature = "quickjs")]
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn reused_rule_reads_live_page_cookie_and_only_retains_data_resources() {
    use std::sync::Arc;
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let other = EngineContext::in_memory().unwrap();
    let weak = Arc::downgrade(&engine);
    let source = "https://source.catalog.test/";
    let pages = [
        "https://a.content.test/one",
        "https://other.content2.test/two",
    ];
    let network = engine.network().clone();
    network.set_cookie(source, "sourceSecret=hidden").unwrap();
    for page in pages {
        other
            .network()
            .set_cookie(page, "session=other-engine")
            .unwrap();
    }
    let mut analyzer = construct_analyzer_with_js_lib(
        engine.js_resources(),
        "正文".into(),
        pages[0].into(),
        source,
        None,
    );
    let manager = engine.js_resources().host_resources().webview.clone();
    let mut subscription = manager.subscribe();
    drop(engine);
    assert!(weak.upgrade().is_none(), "规则回调不可强持根Engine");
    for (page, cookie) in [
        (pages[0], "session=first"),
        (pages[0], "session=updated"),
        (pages[1], "session=second-domain"),
    ] {
        network.set_cookie(page, cookie).unwrap();
        analyzer.set_base_url(page.into());
        let worker = tokio::task::spawn_blocking(move || {
            let result = analyzer.get_string("@webjs:document.title");
            (analyzer, result)
        });
        let request = tokio::time::timeout(Duration::from_secs(3), subscription.recv_async())
            .await
            .unwrap()
            .unwrap();
        assert!(manager.submit(&request.key, "done"));
        let (next, result) = worker.await.unwrap();
        analyzer = next;
        assert_eq!(result.unwrap(), "done");
        assert_eq!(request.cookie, cookie);
        assert_eq!(request.source_key, source);
        assert_eq!(request.url, page);
    }
}

#[cfg(feature = "quickjs")]
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn headless_webjs_and_js_share_structured_result_semantics() {
    let engine = EngineContext::in_memory().unwrap();
    let mut analyzer = construct_analyzer_with_js_lib(
        engine.js_resources(),
        String::new(),
        "https://page.test/".into(),
        "https://source.test/",
        None,
    );
    analyzer.set_element_content(r#"{"title":"书名"}"#.into());
    let result = tokio::task::spawn_blocking(move || {
        let web = analyzer
            .get_string("@webjs:typeof result + ':' + result.title + ':' + typeof src")
            .unwrap();
        let ordinary = analyzer
            .get_string("@js:typeof result + ':' + result.title + ':' + typeof src")
            .unwrap();
        (web, ordinary)
    })
    .await
    .unwrap();
    assert_eq!(
        result,
        ("object:书名:string".into(), "object:书名:string".into())
    );
}
