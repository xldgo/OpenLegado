use super::*;
use crate::EngineContext;

fn service(engine: &EngineContext, runtime: &tokio::runtime::Runtime) -> ExploreService {
    let login = engine.source_login_cache().clone();
    let info = engine.source_info_map().clone();
    ExploreService::new(ExploreResources {
        js: engine.js_resources().clone(),
        info: info.clone(),
        tasks: engine.tasks().clone(),
        runtime: runtime.handle().clone(),
        setup: Arc::new(move |source| {
            let tag = &source.book_source_url;
            legado_fetcher::source_setup::book_source_js_setup_script(
                source,
                &info.snapshot(tag),
                login.get_login_header(tag).as_deref(),
                login.get_login_info(tag).as_deref(),
            )
        }),
    })
}

#[test]
fn category_defaults_and_updates_belong_to_the_selected_engine() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = service(&first, &runtime);
    let b = service(&second, &runtime);
    let source = BookSource {
        book_source_url: "https://same.test".into(),
        ..Default::default()
    };
    let categories = r#"[{"title":"模式","type":"select","chars":["小说","听书"]}]"#;
    for base in [&a, &b] {
        assert_eq!(
            base.explore_parse_url_entity(categories, Some(source.clone()))
                .unwrap()
                .len(),
            1
        );
        assert_eq!(
            base.info_map_snapshot(&source.book_source_url)
                .get("模式")
                .map(String::as_str),
            Some("小说")
        );
    }
    a.info_map_put(&source.book_source_url, "模式", "听书")
        .unwrap();
    a.explore_parse_url_entity(categories, Some(source.clone()))
        .unwrap();
    assert_eq!(a.info_map_snapshot(&source.book_source_url)["模式"], "听书");
    assert_eq!(b.info_map_snapshot(&source.book_source_url)["模式"], "小说");
    for (engine, value) in [(&first, "听书"), (&second, "小说")] {
        let json = engine
            .storage()
            .with_database(|db| {
                legado_db::CacheRepository::new(db.connection()).get("infoMap_https://same.test")
            })
            .unwrap()
            .unwrap();
        let data: HashMap<String, String> = serde_json::from_str(&json).unwrap();
        assert_eq!(data["模式"], value);
    }
}

#[cfg(feature = "quickjs")]
#[test]
fn scripts_and_category_fetch_use_the_captured_login_and_info_map() {
    use legado_core::models::rule::ExploreRule;
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = service(&first, &runtime);
    let b = service(&second, &runtime);
    let source = BookSource {
        book_source_url: "https://same.test".into(),
        rule_explore: Some(ExploreRule {
            book_list: Some(".book".into()),
            name: Some(".name".into()),
            book_url: Some(".name@href".into()),
            ..Default::default()
        }),
        ..Default::default()
    };
    let url = r#"data:text/html,<div class="book"><a class="name" href="https://same.test/book">测试书</a></div>"#;
    for (engine, base, identity) in [(&first, &a, "甲"), (&second, &b, "乙")] {
        engine
            .source_login_cache()
            .put_login_info(&source.book_source_url, identity);
        base.info_map_put(&source.book_source_url, "用户", identity)
            .unwrap();
        let categories = base
            .explore_parse_url_entity(
                "@js: [{title:infoMap['用户'] + source.getLoginInfo(),url:'/books'}]",
                Some(source.clone()),
            )
            .unwrap();
        assert_eq!(categories[0].title, identity.repeat(2));
        let result = base
            .explore_eval_action_result(
                &source,
                "infoMap['结果']=source.getLoginInfo(); java.refreshExplore(); '完成'",
            )
            .unwrap();
        assert!(result.refresh_explore);
        assert_eq!(
            base.info_map_snapshot(&source.book_source_url)["结果"],
            identity
        );
        assert_eq!(
            base.explore_eval_ui_js(&source, "infoMap['结果']").unwrap(),
            identity
        );
        let deps = legado_fetcher::deps::FetcherDeps::new(engine.network().client().unwrap())
            .with_js_resources(engine.js_resources().clone())
            .with_source_context({
                let setup = base.resources.setup.clone();
                Arc::new(move |source| setup(source).ok())
            });
        let books = base
            .explore_fetch_books_entity_with_deps(
                source.clone(),
                url,
                2,
                deps,
                base.info_map_snapshot(&source.book_source_url),
                None,
            )
            .unwrap();
        assert_eq!(books.len(), 1);
        assert_eq!(books[0].name, "测试书");
        assert_eq!(books[0].book_url, "https://same.test/book");
    }
    drop(first);
    assert!(a.explore_eval_action_result(&source, "'不应执行'").is_err());
    assert!(b.explore_eval_action_result(&source, "'仍可执行'").is_ok());
}
