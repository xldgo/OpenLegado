//! 实际 VM、规则执行器与 mainJs 的登录能力，不使用宿主全局根发现。
#![cfg(feature = "quickjs")]

use legado_core::models::BookSource;
use legado_engine::{EngineContext, SourceLoginCache};
use legado_js::{JsEngine, JsResources, JsSourceConfig, JsSourceEngine, SandboxConfig};
use std::sync::Arc;

fn setup(tag: &str, header: Option<&str>, info: Option<&str>) -> String {
    legado_fetcher::source_setup::book_source_js_setup_script(
        &BookSource {
            book_source_url: tag.into(),
            ..Default::default()
        },
        &Default::default(),
        header,
        info,
    )
    .unwrap()
}

fn run(
    resources: &Arc<JsResources>,
    tag: &str,
    setup: Option<String>,
    code: &str,
) -> Result<String, String> {
    legado_fetcher::js_adapter::build_toc_page_context(resources, tag, None, setup).execute_js(code)
}

#[test]
fn source_login_js_writes_deletes_and_does_not_read_old_global_values() {
    let tag = "https://explicit-login-js.test";
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    let old_key = format!("userInfo_{tag}");
    one.js_resources()
        .variables()
        .set_variable(&old_key, "old-global")
        .unwrap();
    let script = setup(tag, None, None);
    let read = || {
        run(
            one.js_resources(),
            tag,
            Some(script.clone()),
            "source.getLoginInfo()",
        )
        .unwrap()
    };
    assert_eq!(read(), "null");
    run(
        one.js_resources(),
        tag,
        Some(script.clone()),
        "source.putLoginInfo('js-user'); source.putLoginHeader('{\"X-Login\":\"one\"}')",
    )
    .unwrap();
    assert_eq!(
        one.source_login_cache().get_login_info(tag).as_deref(),
        Some("js-user")
    );
    assert_eq!(
        one.storage()
            .with_database(|db| legado_db::CacheRepository::new(db.connection()).get(&old_key))
            .unwrap()
            .as_deref(),
        Some("js-user")
    );
    assert_eq!(
        run(
            two.js_resources(),
            tag,
            Some(script.clone()),
            "source.getLoginInfo() + ':' + source.getLoginHeader()"
        )
        .unwrap(),
        "null:null"
    );
    run(
        one.js_resources(),
        tag,
        Some(script.clone()),
        "source.removeLoginInfo(); java.removeLoginHeader()",
    )
    .unwrap();
    assert_eq!(read(), "null");
    assert!(one.source_login_cache().get_login_header(tag).is_none());
    assert!(
        one.storage()
            .with_database(|db| legado_db::CacheRepository::new(db.connection()).get(&old_key))
            .unwrap()
            .is_none()
    );
    assert_eq!(
        one.js_resources()
            .variables()
            .get_variable(&old_key)
            .unwrap()
            .as_deref(),
        Some("old-global")
    );
    one.js_resources()
        .variables()
        .remove_variable(&old_key)
        .unwrap();
}

#[test]
fn stale_setup_cannot_replace_native_update_or_resurrect_deletion() {
    let tag = "https://login-snapshot.test";
    let engine = EngineContext::in_memory().unwrap();
    let stale = setup(tag, Some("{\"X-Login\":\"old\"}"), Some("old-user"));
    engine
        .source_login_cache()
        .put_login_info(tag, "native-user");
    let vm = engine
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    vm.eval(&stale).unwrap();
    assert_eq!(vm.eval("source.getLoginInfo()").unwrap(), "native-user");
    assert_eq!(vm.eval("source.getLoginHeader()").unwrap(), "null");
    engine.source_login_cache().remove_login_info(tag);
    vm.eval(&stale).unwrap();
    assert_eq!(vm.eval("source.getLoginInfo()").unwrap(), "null");
    assert!(engine.source_login_cache().get_login_info(tag).is_none());
}

#[test]
fn cached_and_lexical_fallback_login_reads_observe_current_service() {
    let tag = "https://login-lexical.test";
    let engine = EngineContext::in_memory().unwrap();
    let code = format!("let loginLexical = get('userInfo_{tag}'); loginLexical");
    for user in ["one", "two", "three"] {
        engine.source_login_cache().put_login_info(tag, user);
        assert_eq!(run(engine.js_resources(), tag, None, &code).unwrap(), user);
    }
    let setup = setup(tag, None, None);
    assert!(
        run(
            engine.js_resources(),
            tag,
            Some(setup.clone()),
            "source.putLoginInfo('written-before-error'); throw new Error('fixture')"
        )
        .is_err()
    );
    assert_eq!(
        engine.source_login_cache().get_login_info(tag).as_deref(),
        Some("written-before-error")
    );
    assert_eq!(
        run(
            engine.js_resources(),
            tag,
            Some(setup),
            "source.getLoginInfo()"
        )
        .unwrap(),
        "written-before-error"
    );
}

#[test]
fn main_js_and_per_call_flow_share_service_without_sharing_flow_values() {
    let tag = "https://login-mainjs.test";
    let engine = EngineContext::in_memory().unwrap();
    let one = engine.js_resources().for_flow("one");
    let two = engine.js_resources().for_flow("two");
    let config = JsSourceConfig::new(
        tag.into(),
        format!("function current() {{ return get('userInfo_{tag}'); }}"),
    );
    let mut a = JsSourceEngine::new_quickjs_with_resources(config.clone(), &one).unwrap();
    let mut b = JsSourceEngine::new_quickjs_with_resources(config, &two).unwrap();
    for (index, user) in ["first", "second", "third"].into_iter().enumerate() {
        let source = if index == 1 { &mut b } else { &mut a };
        engine.source_login_cache().put_login_info(tag, user);
        assert_eq!(
            source.call_function("current", &[]).unwrap().as_deref(),
            Some(user)
        );
    }
    run(
        &one,
        tag,
        None,
        "java.__lgStorePut('temporary','one'); put('userInfo_https://login-mainjs.test','shared')",
    )
    .unwrap();
    assert_eq!(
        run(
            &two,
            tag,
            None,
            "java.__lgStoreGet('temporary') + ':' + get('userInfo_https://login-mainjs.test')"
        )
        .unwrap(),
        ":shared"
    );
    run(&one, tag, None, "clearVariables()").unwrap();
    assert_eq!(
        engine.source_login_cache().get_login_info(tag).as_deref(),
        Some("shared")
    );
}

#[test]
fn cache_rejects_another_login_service_even_with_same_variable_store() {
    let engine = EngineContext::in_memory().unwrap();
    let a = engine.js_resources();
    let b = a
        .as_ref()
        .clone()
        .with_source_login_store(Arc::new(SourceLoginCache::default()));
    assert!(Arc::ptr_eq(&a.variables(), &b.variables()));
    let cache = a.engine_cache();
    let first = cache
        .get_or_create_with_resources("same-key", None, None, None, a)
        .unwrap()
        .engine;
    let second = cache
        .get_or_create_with_resources("same-key", None, None, None, &b)
        .unwrap()
        .engine;
    assert!(!Arc::ptr_eq(&first, &second));
    let again = cache
        .get_or_create_with_resources("same-key", None, None, None, &b)
        .unwrap()
        .engine;
    assert!(Arc::ptr_eq(&second, &again));
}

#[test]
fn retained_vm_keeps_only_login_capability_and_releases_it_on_drop() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak_engine = Arc::downgrade(&engine);
    let weak_login = Arc::downgrade(engine.source_login_cache());
    let vm = engine
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    drop(engine);
    assert!(weak_engine.upgrade().is_none());
    assert!(weak_login.upgrade().is_some());
    vm.eval("put('userInfo_released-engine', 'still-owned')")
        .unwrap();
    assert_eq!(
        weak_login
            .upgrade()
            .unwrap()
            .get_login_info("released-engine")
            .as_deref(),
        Some("still-owned")
    );
    drop(vm);
    assert!(weak_login.upgrade().is_none());
}
