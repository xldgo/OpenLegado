use super::*;

#[cfg(feature = "quickjs")]
#[test]
fn dict_cached_scope_follows_rule_and_word_without_cross_engine_variables() {
    let resources = legado_js::JsResources::default();
    let a = DictScopeExecutor::with_resources(&resources, "same-rule", "甲", "body-a");
    let b = DictScopeExecutor::with_resources(&resources, "same-rule", "乙", "body-b");
    a.execute_js("globalThis.savedRead=java.__lgStoreGet; java.__lgStorePut('key','a')")
        .unwrap();
    b.execute_js("java.__lgStorePut('key','b')").unwrap();
    assert_eq!(
        a.execute_js("key + ':' + savedRead('key')").unwrap(),
        "甲:a"
    );
    assert_eq!(
        b.execute_js("key + ':' + savedRead('key')").unwrap(),
        "乙:b"
    );
    let other = DictScopeExecutor::with_resources(
        &legado_js::JsResources::default(),
        "same-rule",
        "甲",
        "other",
    );
    assert_eq!(other.execute_js("java.__lgStoreGet('key')").unwrap(), "");
    let parser = AnalyzeRule::with_js_executor(String::new(), String::new(), Arc::new(a));
    assert_eq!(parser.get_string("@get:{key}").unwrap(), "a");
}

#[test]
fn dict_reader_is_explicit_even_without_a_js_executor() {
    let store = Arc::new(legado_js::variables::VariableStore::default());
    let scope = store.fresh_flow("dict");
    scope.put_flow_variable("key", "value").unwrap();
    let executor = DictScopeExecutor {
        base: None,
        prelude: String::new(),
        variables: scope.reader(),
    };
    assert_eq!(executor.read_variable("key").as_deref(), Some("value"));
    assert!(
        executor.execute_js("1").is_err(),
        "仅注入读者不能开启 JS 执行"
    );
}

#[test]
fn test_html_to_text() {
    let html = "<h3>拼音</h3><br><p>释义一&nbsp;&amp;</p><script>x()</script>尾部";
    let text = html_to_text(html);
    assert!(text.contains("拼音"));
    assert!(text.contains("释义一 &"));
    assert!(!text.contains('<'));
    assert!(!text.contains("script"));
    assert!(text.contains("尾部"));
}

#[test]
fn test_import_parse_rules_array() {
    let json = r#"[{"name":"A","urlRule":"http://a","showRule":"sa","enabled":true,"sortNumber":0},{"name":"B","urlRule":"http://b","showRule":"sb"}]"#;
    let rules = parse_import_rules(json).unwrap();
    assert_eq!(rules.len(), 2);
    assert_eq!(rules[0].name, "A");
    assert_eq!(rules[0].url_rule, "http://a");
    assert!(rules[0].is_enabled);
    // B 缺省 enabled（GSON 默认 true）与 sortNumber（默认 0）
    assert!(rules[1].is_enabled);
    assert_eq!(rules[1].sort_order, 0);
}

#[test]
fn test_import_parse_rules_single() {
    let json = r#"{"name":"X","urlRule":"http://x","showRule":"sx"}"#;
    let rules = parse_import_rules(json).unwrap();
    assert_eq!(rules.len(), 1);
    assert_eq!(rules[0].name, "X");
    assert!(rules[0].is_enabled);
}

#[test]
fn test_import_parse_rules_errors_and_filter() {
    assert!(parse_import_rules("").is_err());
    assert!(parse_import_rules("   ").is_err());
    assert!(parse_import_rules("not json").is_err());
    assert!(parse_import_rules(r#"[{"name":"A" broken"#).is_err());
    // 空 name 条目被过滤，其余保留
    let rules =
        parse_import_rules(r#"[{"name":"","urlRule":"x"},{"name":"B","urlRule":"y"}]"#).unwrap();
    assert_eq!(rules.len(), 1);
    assert_eq!(rules[0].name, "B");
}

fn service(
    engine: Option<&crate::EngineContext>,
    runtime: &tokio::runtime::Runtime,
) -> DictionaryService {
    DictionaryService::new(DictionaryResources {
        storage: engine.map(|e| e.storage().clone()),
        network: engine.map(|e| e.network().clone()).unwrap_or_default(),
        js: engine.map(|e| e.js_resources().clone()).unwrap_or_default(),
        runtime: runtime.handle().clone(),
    })
}

#[test]
fn dictionaries_keep_seed_crud_order_and_import_state_in_their_own_storage() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = Arc::new(crate::EngineContext::in_memory().unwrap());
    let second = crate::EngineContext::in_memory().unwrap();
    let a = service(Some(&first), &runtime);
    let b = service(Some(&second), &runtime);
    let unopened = service(None, &runtime);
    assert_eq!(
        unopened.dict_lookup("  Mixed Case  ").unwrap().word,
        "Mixed Case"
    );
    assert!(unopened.dict_lookup("词").unwrap().definitions.is_empty());
    assert!(
        unopened
            .dict_rule_list()
            .unwrap_err()
            .to_string()
            .contains("数据库尚未初始化")
    );
    assert_eq!(a.dict_rule_list().unwrap().len(), 5);
    assert_eq!(b.dict_rule_list().unwrap().len(), 5);
    for engine in [&*first, &second] {
        engine
            .storage()
            .with_database(|db| DictRuleRepository::new(db.connection()).delete_all())
            .unwrap();
    }
    let weak = Arc::downgrade(&first);
    drop(first);
    assert!(weak.upgrade().is_none());
    let aid = a
        .dict_rule_add("同名", "data:text/html,<p>甲&amp;{{key}}</p>", "p@html")
        .unwrap();
    let bid = b
        .dict_rule_add("同名", "data:text/plain,乙-{{key}}", "")
        .unwrap();
    let disabled = a
        .dict_rule_add("未执行", "data:text/plain,不应返回", "")
        .unwrap();
    a.dict_rule_set_enabled(disabled, false).unwrap();
    assert_eq!(
        a.dict_lookup("  AbC  ").unwrap().definitions,
        vec!["【同名】甲&AbC"]
    );
    assert_eq!(
        b.dict_lookup("  AbC  ").unwrap().definitions,
        vec!["【同名】乙-AbC"]
    );
    let imported = r#"{"name":"同名","urlRule":"data:text/plain,更新-{{key}}","showRule":"","enabled":true,"sortNumber":9}"#;
    assert_eq!(a.dict_rule_import(imported, "text").unwrap(), 1);
    let found = a
        .dict_rule_list()
        .unwrap()
        .into_iter()
        .find(|r| r.name == "同名")
        .unwrap();
    assert_eq!(found.id, aid);
    assert_eq!(found.sort_order, 9);
    assert_eq!(
        b.dict_rule_list()
            .unwrap()
            .iter()
            .find(|r| r.id == bid)
            .unwrap()
            .url_rule,
        "data:text/plain,乙-{{key}}"
    );
    assert_eq!(a.reorder_dict_rules(&[aid, disabled]).unwrap(), 2);
    assert_eq!(a.dict_rule_list().unwrap()[0].id, aid);
    assert!(
        a.dict_rule_update(aid, "改名", "data:text/plain,已更新", "")
            .unwrap()
    );
    assert_eq!(
        a.dict_lookup("词").unwrap().definitions,
        vec!["【改名】已更新"]
    );
    assert!(a.dict_rule_import("bad-json", "text").is_err());
    assert_eq!(a.dict_rule_list().unwrap().len(), 2);
    assert!(a.dict_rule_delete(disabled).unwrap());
    assert!(!a.dict_rule_delete(i64::MAX).unwrap());
    assert_eq!(b.dict_rule_list().unwrap().len(), 1);
}

#[cfg(feature = "quickjs")]
#[test]
fn dictionary_lookup_js_uses_the_selected_instance_rule_and_word_context() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    for identity in ["甲", "乙"] {
        let engine = crate::EngineContext::in_memory().unwrap();
        engine
            .network()
            .set_cookie("https://same-dict.test", &format!("identity={identity}"))
            .unwrap();
        let service = service(Some(&engine), &runtime);
        service
            .dict_rule_add(
                "同规则",
                "@js:'data:text/plain,' + key",
                "@js:java.getCookie('https://same-dict.test') + ':' + word + ':' + result",
            )
            .unwrap();
        assert_eq!(
            service.dict_lookup("  Word  ").unwrap().definitions,
            vec![format!("【同规则】identity={identity}:Word:Word")]
        );
    }
}
