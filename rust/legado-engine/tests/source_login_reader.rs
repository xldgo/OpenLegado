//! 有无 VM 的解析适配均读取实例登录能力，缺失不能回退旧全局值。
use legado_engine::EngineContext;

#[test]
fn login_rule_reader_tracks_native_writes_and_deletes_in_both_feature_modes() {
    let tag = "https://login-rule-reader.test";
    let engine = EngineContext::in_memory().unwrap();
    let key = format!("userInfo_{tag}");
    engine
        .js_resources()
        .variables()
        .set_variable(&key, "legacy-value")
        .unwrap();
    let parser = legado_fetcher::js_adapter::construct_analyzer_with_js_lib(
        engine.js_resources(),
        String::new(),
        tag.into(),
        tag,
        None,
    );
    let rule = format!("@get:{{{key}}}");
    assert_eq!(parser.get_string(&rule).unwrap(), "");
    engine
        .source_login_cache()
        .put_login_info(tag, "current-user");
    assert_eq!(parser.get_string(&rule).unwrap(), "current-user");
    engine.source_login_cache().remove_login_info(tag);
    assert_eq!(parser.get_string(&rule).unwrap(), "");
    engine
        .js_resources()
        .variables()
        .remove_variable(&key)
        .unwrap();
}

#[test]
fn parser_reader_does_not_retain_engine_or_vm_cache() {
    let engine = std::sync::Arc::new(EngineContext::in_memory().unwrap());
    let weak = std::sync::Arc::downgrade(&engine);
    let variables = engine.js_resources().for_flow("reader");
    variables
        .variable_scope()
        .unwrap()
        .put_flow_variable("temporary", "value")
        .unwrap();
    let reader = variables.variable_reader();
    let cache_owner = std::sync::Arc::downgrade(&variables);
    drop(variables);
    drop(engine);
    assert!(weak.upgrade().is_none());
    assert!(cache_owner.upgrade().is_none());
    assert_eq!(reader("temporary").as_deref(), Some("value"));
}
