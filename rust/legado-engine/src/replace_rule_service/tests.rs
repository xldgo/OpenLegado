use super::*;
use crate::EngineContext;
#[cfg(feature = "quickjs")]
use std::sync::Arc;

fn fields(name: &str) -> ReplaceRuleFields<'_> {
    ReplaceRuleFields {
        name,
        pattern: "old",
        replacement: "new",
        is_regex: false,
        group: None,
        scope_title: None,
        scope_content: None,
        exclude_scope: None,
        timeout_millisecond: None,
        scope_source: None,
    }
}

#[test]
fn rule_edits_stay_in_the_borrowed_storage_and_preserve_unexposed_fields() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let first_id = first.storage().with_database(|db| {
        let service = ReplaceRuleService::new(db);
        let id = service.add_rule("源A", ReplaceRuleFields {
            group: Some(""), exclude_scope: Some(""), ..fields("实例A")
        })?;
        let mut rule = service.list_rules()?.remove(0);
        assert_eq!(rule.group.as_deref(), Some(""));
        assert!(rule.exclude_scope.is_none());
        assert!(!rule.scope_source);
        assert!(rule.is_enabled);
        assert_eq!(rule.order, 0);
        // 模拟导入已提供的字段；当前编辑入口必须保留这些值。
        rule.order = -7;
        rule.scope_source = true;
        rule.timeout_millisecond = 4200;
        ReplaceRuleRepository::new(db.connection()).update(&rule)?;
        service.update_rule(id, false, fields("修改A"))?;
        let updated = service.list_rules()?.remove(0);
        assert_eq!(updated.scope.as_deref(), Some("源A"));
        assert_eq!(updated.order, -7);
        assert!(updated.scope_source);
        assert_eq!(updated.timeout_millisecond, 4200);
        assert!(service.enabled_rules()?.is_empty());
        service.set_enabled(id, true)?;
        assert_eq!(service.enabled_rules()?.len(), 1);
        assert!(matches!(service.update_rule(id + 1, true, fields("缺失")), Err(LegadoError::Database(e)) if e == "替换规则不存在"));
        Ok(id)
    }).unwrap();
    second
        .storage()
        .with_database(|db| {
            let service = ReplaceRuleService::new(db);
            assert_eq!(service.add_rule("", fields("实例B"))?, first_id);
            assert_eq!(service.list_rules()?[0].name, "实例B");
            Ok(())
        })
        .unwrap();
    first
        .storage()
        .with_database(|db| ReplaceRuleService::new(db).delete_rule(first_id))
        .unwrap();
    second
        .storage()
        .with_database(|db| {
            assert_eq!(ReplaceRuleService::new(db).list_rules()?[0].name, "实例B");
            Ok(())
        })
        .unwrap();
}

#[test]
fn source_execution_preserves_order_scope_and_no_js_policy() {
    let db = legado_db::init_in_memory_database().unwrap();
    let repo = ReplaceRuleRepository::new(db.connection());
    for rule in [
        ReplaceRule {
            pattern: "old".into(),
            replacement: "middle".into(),
            scope: Some("SOURCE".into()),
            order: 1,
            ..Default::default()
        },
        ReplaceRule {
            pattern: "middle".into(),
            replacement: "new".into(),
            order: 2,
            ..Default::default()
        },
        ReplaceRule {
            pattern: "new".into(),
            replacement: "wrong".into(),
            exclude_scope: Some("SOURCE".into()),
            order: 3,
            ..Default::default()
        },
        ReplaceRule {
            pattern: "new".into(),
            replacement: "@js:'wrong'".into(),
            order: 4,
            ..Default::default()
        },
        ReplaceRule {
            pattern: "[".into(),
            replacement: "wrong".into(),
            order: 5,
            ..Default::default()
        },
    ] {
        repo.insert(&ReplaceRule {
            scope_source: true,
            ..rule
        })
        .unwrap();
    }
    let service = ReplaceRuleService::new(&db);
    assert_eq!(
        service
            .apply_to_source(r#"{"value":"old"}"#, "source", "https://a.test")
            .unwrap(),
        r#"{"value":"new"}"#
    );
    assert_eq!(
        service
            .apply_to_source(r#"{"value":"old"}"#, "other", "https://b.test")
            .unwrap(),
        r#"{"value":"old"}"#
    );
}

#[cfg(feature = "quickjs")]
#[test]
fn preview_keeps_injected_resources_without_root_or_vm_state_leaks() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    first
        .js_resources()
        .variables()
        .set_variable("probe", "first")
        .unwrap();
    second
        .js_resources()
        .variables()
        .set_variable("probe", "second")
        .unwrap();
    first
        .source_login_cache()
        .put_login_info("preview", "login-first");
    second
        .source_login_cache()
        .put_login_info("preview", "login-second");
    let first_js = first.js_resources().clone();
    let weak = Arc::downgrade(&first);
    drop(first);
    assert!(weak.upgrade().is_none());
    let mut rule = ReplaceRule {
        pattern: r"\d+".into(),
        replacement: "@js:(globalThis.previewFlag ? 'stale' : (globalThis.previewFlag = true, java.getVariable('probe'))) + ':' + result".into(),
        ..Default::default()
    };
    assert_eq!(
        preview_replace_rule(&rule, "11 22", first_js.clone()),
        "first:11 first:22"
    );
    assert_eq!(
        preview_replace_rule(&rule, "33", second.js_resources().clone()),
        "second:33"
    );
    rule.replacement = "@js:java.getVariable('userInfo_preview')".into();
    assert_eq!(preview_replace_rule(&rule, "11", first_js), "login-first");
    assert_eq!(
        preview_replace_rule(&rule, "11", second.js_resources().clone()),
        "login-second"
    );
}
