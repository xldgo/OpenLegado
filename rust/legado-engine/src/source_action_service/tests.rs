use super::*;
use crate::EngineContext;

pub(super) fn service(engine: &EngineContext) -> SourceActionService {
    let login = engine.source_login_cache().clone();
    #[cfg(feature = "quickjs")]
    let info = engine.source_info_map().clone();
    let setup_login = login.clone();
    SourceActionService::new(SourceActionResources {
        storage: Some(engine.storage().clone()),
        js: engine.js_resources().clone(),
        login,
        setup: Arc::new(move |source| {
            #[cfg(feature = "quickjs")]
            {
                legado_fetcher::source_setup::book_source_js_setup_script(
                    source,
                    &info.snapshot(&source.book_source_url),
                    setup_login
                        .get_login_header(&source.book_source_url)
                        .as_deref(),
                    setup_login
                        .get_login_info(&source.book_source_url)
                        .as_deref(),
                )
            }
            #[cfg(not(feature = "quickjs"))]
            {
                let _ = (source, &setup_login);
                Ok(String::new())
            }
        }),
    })
}

#[cfg(feature = "quickjs")]
#[test]
fn login_uses_captured_instance_and_fresh_v2_vm_without_retaining_root() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    first
        .js_resources()
        .variables()
        .set_variable("identity", "first")
        .unwrap();
    second
        .js_resources()
        .variables()
        .set_variable("identity", "second")
        .unwrap();
    let a = service(&first);
    let b = service(&second);
    let weak = Arc::downgrade(&first);
    drop(first);
    assert!(weak.upgrade().is_none());
    let source = BookSource {
        book_source_url: "https://same-login.test".into(),
        login_url: Some("@js:function login(){this.source.putLoginHeader(JSON.stringify({token:identity}));}".into()),
        js_lib: Some("var identity = java.getVariable('identity');".into()),
        main_js: Some("function loginUi(state){globalThis.oldRender=1;return {rows:[]};} function loginAction(action,state,form){put('userInfo_https://same-login.test','intermediate');return {login:{token:java.getVariable('identity'),fresh:typeof oldRender==='undefined',value:form.extra},state:state,close:true};}".into()),
        ..Default::default()
    };
    for (service, identity) in [(&a, "first"), (&b, "second")] {
        let header = service.eval_login_v1(&source, "login").unwrap();
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&header).unwrap()["token"],
            identity
        );
        // V1仍忽略执行错误，读取此前登录头；不改造成V2的错误策略。
        let failed = BookSource {
            login_url: Some("throw new Error('failed')".into()),
            ..source.clone()
        };
        assert_eq!(service.eval_login_v1(&failed, "login").unwrap(), header);
        service.eval_login_ui_v2(&source, " ").unwrap();
        let request: LoginActionV2Request = serde_json::from_value(serde_json::json!({
            "action":"submit", "stateJson":"{\"step\":2}", "formJson":{"extra":[true,null,"😀"]}
        }))
        .unwrap();
        let raw = service.eval_login_action_v2(&source, &request).unwrap();
        let command: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(command["login"]["token"], identity);
        assert_eq!(command["login"]["fresh"], true);
        assert_eq!(
            command["login"]["value"],
            serde_json::json!([true, null, "😀"])
        );
        assert_eq!(command["state"]["step"], 2);
        let stored = service
            .resources
            .login
            .get_login_info(&source.book_source_url)
            .unwrap();
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&stored).unwrap(),
            command["login"]
        );
    }
}

#[cfg(feature = "quickjs")]
#[test]
fn login_and_purchase_http_follow_source_resources_and_only_clear_owned_cache() {
    use crate::test_http_fixture::Fixture;
    use legado_core::{
        cache_book::CachedChapter,
        models::{Book, BookChapter},
    };
    use legado_db::{
        BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository,
        repository::Repository,
    };
    let mut fixture = Fixture::new(4, false, |_| "true".into());
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let book_url = "https://same-book.test/book";
    let source: BookSource = serde_json::from_value(serde_json::json!({
        "bookSourceUrl":fixture.url,
        "mainJs":"function loginAction(action,state,form){return {login:{response:java.ajax(baseUrl+'/login')}};}",
        "ruleContent":{"payAction":"if(book.name!=='书'||chapter.title!=='章'||baseUrl!==chapter.url||result!==null||src!==null)throw new Error('bindings');java.ajax(baseUrl)"}
    })).unwrap();
    let chapter_url = format!("{}/pay", fixture.url);
    for (engine, identity) in [(&first, "first"), (&second, "second")] {
        engine
            .network()
            .set_cookie(
                &legado_net::cookie_store::normalize_cookie_key(&fixture.url),
                &format!("identity={identity}"),
            )
            .unwrap();
        engine.js_resources().http_resources().put_headers(
            &fixture.url,
            [("X-Identity".into(), identity.into())].into(),
        );
        engine.js_resources().http_resources().put_headers(
            "https://unrelated.test",
            [("X-Leak".into(), "no".into())].into(),
        );
        engine
            .storage()
            .with_database(|db| {
                BookSourceRepository::new(db.connection()).insert(&source)?;
                BookRepository::new(db.connection()).insert(&Book {
                    book_url: book_url.into(),
                    name: "书".into(),
                    origin: fixture.url.clone(),
                    ..Default::default()
                })?;
                BookChapterRepository::new(db.connection()).insert_batch(&[BookChapter {
                    book_url: book_url.into(),
                    title: "章".into(),
                    url: chapter_url.clone(),
                    index: 1,
                    ..Default::default()
                }])?;
                for url in [book_url, "https://other-book.test"] {
                    CacheBookRepository::new(db.connection()).insert(&CachedChapter {
                        id: 0,
                        book_url: url.into(),
                        chapter_index: 1,
                        chapter_title: "章".into(),
                        chapter_url: chapter_url.clone(),
                        content: identity.into(),
                        cached_at: 1,
                        size_bytes: 5,
                    })?;
                }
                Ok(())
            })
            .unwrap();
    }
    let runtime = tokio::runtime::Runtime::new().unwrap();
    for (engine, identity) in [(&first, "first"), (&second, "second")] {
        let service = service(engine);
        let request = LoginActionV2Request {
            action: "submit".into(),
            state_json: serde_json::Value::Null,
            form_json: serde_json::Value::Null,
        };
        assert!(
            !service
                .eval_login_action_v2(&source, &request)
                .unwrap()
                .is_empty()
        );
        assert_eq!(
            service.chapter_pay_action(book_url, 1).unwrap().kind,
            "success"
        );
        engine
            .storage()
            .with_database(|db| {
                let repo = CacheBookRepository::new(db.connection());
                assert!(repo.get_by_book(book_url)?.is_empty());
                assert_eq!(
                    repo.get_by_book("https://other-book.test")?[0].content,
                    identity
                );
                Ok(())
            })
            .unwrap();
        for path in ["/login", "/pay"] {
            let request = runtime.block_on(fixture.request()).to_ascii_lowercase();
            assert!(request.starts_with(&format!("get {path} ")));
            assert!(request.contains(&format!("identity={identity}")));
            assert!(request.contains(&format!("x-identity: {identity}")));
            assert!(!request.contains("x-leak:"));
        }
        if identity == "first" {
            second
                .storage()
                .with_database(|db| {
                    assert_eq!(
                        CacheBookRepository::new(db.connection()).get_by_book(book_url)?[0].content,
                        "second"
                    );
                    Ok(())
                })
                .unwrap();
        }
    }
    fixture.worker.join().unwrap();
}

#[cfg(not(feature = "quickjs"))]
#[test]
fn no_js_keeps_v1_header_and_v2_error_and_missing_database_error() {
    let engine = EngineContext::in_memory().unwrap();
    let mut service = service(&engine);
    service.resources.storage = None;
    let source = BookSource {
        book_source_url: "https://no-js.test".into(),
        login_url: Some("function login(){}".into()),
        ..Default::default()
    };
    service
        .resources
        .login
        .put_login_header(&source.book_source_url, "existing");
    assert_eq!(service.eval_login_v1(&source, "login").unwrap(), "existing");
    assert!(
        service
            .eval_login_ui_v2(&source, "{}")
            .unwrap_err()
            .to_string()
            .contains("QuickJS engine not enabled")
    );
    assert!(
        service
            .chapter_pay_action("book", 0)
            .unwrap_err()
            .to_string()
            .contains("数据库尚未初始化")
    );
}
