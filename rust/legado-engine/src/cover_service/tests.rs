use super::*;
use crate::{
    EngineContext,
    dictionary_service::{DictionaryResources, DictionaryService},
    test_http_fixture::Fixture,
};
const DEFAULT: &str = r#"{"enable":true,"searchUrl":"data:text/html,<img src='https://default.test/cover'>","coverRule":"img@src"}"#;
fn service(
    engine: Option<&EngineContext>,
    runtime: &tokio::runtime::Runtime,
    default: &str,
) -> CoverService {
    CoverService::new(CoverResources {
        storage: engine.map(|e| e.storage().clone()),
        network: engine.map(|e| e.network().clone()).unwrap_or_default(),
        js: engine.map(|e| e.js_resources().clone()).unwrap_or_default(),
        runtime: runtime.handle().clone(),
        default_config: default.into(),
    })
}
#[test]
fn cover_configuration_and_default_documents_are_instance_owned_and_lazy() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    let a = service(Some(&first), &runtime, DEFAULT);
    let b = service(
        Some(&second),
        &runtime,
        &DEFAULT.replace("default.test", "other.test"),
    );
    assert!(
        a.read_cover_rule()
            .unwrap()
            .search_url
            .contains("default.test")
    );
    assert!(
        b.read_cover_rule()
            .unwrap()
            .search_url
            .contains("other.test")
    );
    let unopened = service(None, &runtime, DEFAULT);
    assert!(unopened.search_cover_urls("词").unwrap().is_empty());
    assert!(unopened.delete_cover_rule().unwrap());
    assert!(unopened.read_cover_rule().is_ok());
    let weak = Arc::downgrade(&first);
    drop(first);
    assert!(weak.upgrade().is_none());
    let config = CoverRuleConfig {
        enable: true,
        search_url: "data:text/html,<img src='https://a.test/cover'>".into(),
        cover_rule: "img@src".into(),
        enabled_cookie_jar: Some(false),
    };
    assert!(
        unopened
            .write_cover_rule(config.clone())
            .unwrap_err()
            .to_string()
            .contains("数据库未初始化")
    );
    a.write_cover_rule(config.clone()).unwrap();
    assert_eq!(
        a.search_cover_urls("词").unwrap(),
        vec!["https://a.test/cover"]
    );
    assert!(b.search_cover_urls("词").unwrap().is_empty());
    assert_eq!(a.read_cover_rule().unwrap().enabled_cookie_jar, Some(false));
    a.delete_cover_rule().unwrap();
    assert!(
        a.read_cover_rule()
            .unwrap()
            .search_url
            .contains("default.test")
    );
    // 注入的坏默认文档只在真正需要回退时失败，不阻断已保存配置。
    let invalid_default = service(Some(&second), &runtime, "bad-json");
    assert!(
        invalid_default
            .read_cover_rule()
            .unwrap_err()
            .to_string()
            .contains("解析默认封面规则失败")
    );
    invalid_default.write_cover_rule(config).unwrap();
    assert!(invalid_default.read_cover_rule().is_ok());
    assert!(b.read_cover_rule().unwrap().search_url.contains("a.test"));
}

#[test]
fn shared_fetch_keeps_dictionary_import_and_cover_cookie_write_policies() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let mut fixture = Fixture::with_response_headers(
        5,
        false,
        "application/json",
        &[("Set-Cookie", "received=1; Path=/")],
        |request| {
            if request.starts_with("GET /import ") {
                r#"{"name":"导入源","urlRule":"data:text/plain,导入","showRule":""}"#.into()
            } else {
                let identity = if request.contains("identity=first") {
                    "first"
                } else {
                    "second"
                };
                serde_json::json!({"definition":identity,"cover":format!("/cover-{identity}.png")})
                    .to_string()
            }
        },
    );
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    first
        .network()
        .set_cookie("127.0.0.1", "identity=first")
        .unwrap();
    second
        .network()
        .set_cookie("127.0.0.1", "identity=second")
        .unwrap();
    let dictionary = DictionaryService::new(DictionaryResources {
        storage: Some(first.storage().clone()),
        network: first.network().clone(),
        js: first.js_resources().clone(),
        runtime: runtime.handle().clone(),
    });
    let dictionary_url = format!(
        "{}/dict?q={{{{key}}}},{{\"method\":\"POST\",\"body\":\"request-body\",\"headers\":{{\"X-Test\":\"dict\"}}}}",
        fixture.url
    );
    dictionary
        .dict_rule_add("本地", &dictionary_url, "$.definition")
        .unwrap();
    assert_eq!(
        dictionary.dict_lookup("  AbC  ").unwrap().definitions,
        vec!["【本地】first"]
    );
    assert!(
        !first
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_cookie_string(&fixture.url)
            .contains("received=1")
    );
    assert_eq!(
        dictionary
            .dict_rule_import(&format!("{}/import", fixture.url), "url")
            .unwrap(),
        1
    );
    assert!(
        !first
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_cookie_string(&fixture.url)
            .contains("received=1")
    );
    let a = service(Some(&first), &runtime, DEFAULT);
    for flag in [Some(false), Some(true)] {
        a.write_cover_rule(CoverRuleConfig {
            enable: true,
            search_url: format!("{}/cover?q={{{{key}}}}", fixture.url),
            cover_rule: "$.cover".into(),
            enabled_cookie_jar: flag,
        })
        .unwrap();
        assert_eq!(
            a.search_cover_urls("Book").unwrap(),
            vec![format!("{}/cover-first.png", fixture.url)]
        );
        assert_eq!(
            first
                .network()
                .cookie_store()
                .read()
                .unwrap()
                .get_cookie_string(&fixture.url)
                .contains("received=1"),
            flag == Some(true)
        );
    }
    let b = service(Some(&second), &runtime, DEFAULT);
    b.write_cover_rule(CoverRuleConfig {
        enable: true,
        search_url: format!("{}/cover?q={{{{key}}}}", fixture.url),
        cover_rule: "$.cover".into(),
        enabled_cookie_jar: None,
    })
    .unwrap();
    assert_eq!(
        b.search_cover_urls("Book").unwrap(),
        vec![format!("{}/cover-second.png", fixture.url)]
    );
    assert!(
        !second
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_cookie_string(&fixture.url)
            .contains("received=1")
    );
    let requests = runtime.block_on(async {
        let mut v = Vec::new();
        for _ in 0..5 {
            v.push(fixture.request().await);
        }
        v
    });
    assert!(requests[0].starts_with("POST /dict?q=AbC "));
    assert!(requests[0].ends_with("\r\n\r\nrequest-body"));
    assert!(requests[0].to_ascii_lowercase().contains("x-test: dict"));
    for (i, request) in requests.iter().enumerate() {
        let lower = request.to_ascii_lowercase();
        assert!(!lower.contains("cookiejar:"));
        assert!(lower.contains(if i == 4 {
            "identity=second"
        } else {
            "identity=first"
        }));
    }
    fixture.worker.join().unwrap();
}
