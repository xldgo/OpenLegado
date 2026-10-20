use super::*;
use crate::EngineContext;

#[test]
fn tasks_keep_storage_js_and_full_entities_in_the_captured_instance() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    let a = AutoTaskService::new(Some(first.storage().clone()), first.js_resources().clone());
    let b = AutoTaskService::new(
        Some(second.storage().clone()),
        second.js_resources().clone(),
    );
    first
        .js_resources()
        .variables()
        .set_variable("task-probe", "甲")
        .unwrap();
    second
        .js_resources()
        .variables()
        .set_variable("task-probe", "乙")
        .unwrap();
    let weak = Arc::downgrade(&first);
    drop(first);
    assert!(weak.upgrade().is_none());
    let rule = AutoTaskRuleModel {
        id: "same-task".into(),
        name: "甲".into(),
        script: "java.getVariable('task-probe')".into(),
        header: Some("header".into()),
        login_ui: Some("[]".into()),
        js_lib: Some("lib".into()),
        enabled_cookie_jar: false,
        last_run_at: 9007199254740993,
        ..Default::default()
    };
    a.create_rule_db(&rule).unwrap();
    b.create_rule_db(&AutoTaskRuleModel {
        name: "乙".into(),
        ..rule.clone()
    })
    .unwrap();
    let updated = update_cron_batch(
        vec![rule.clone()],
        std::slice::from_ref(&rule.id),
        "*/30 * * * *",
    )
    .remove(0);
    a.update_rule_db(&updated).unwrap();
    assert_eq!(
        serde_json::to_value(a.find_rule_by_id_db(&rule.id).unwrap().unwrap()).unwrap(),
        serde_json::to_value(&updated).unwrap()
    );
    assert_eq!(b.find_rule_by_id_db(&rule.id).unwrap().unwrap().name, "乙");
    for (service, identity) in [(&a, "甲"), (&b, "乙")] {
        let out = service
            .execute_task(TaskProtocol::custom(&rule.script), Some(&rule.id))
            .unwrap();
        assert_eq!(out.task_id, rule.id);
        #[cfg(feature = "quickjs")]
        {
            assert!(out.success);
            assert_eq!(out.message, identity);
        }
        #[cfg(not(feature = "quickjs"))]
        {
            let _ = identity;
            assert!(!out.success);
            assert!(out.message.contains("需要 quickjs feature"));
        }
        assert!(out.details.unwrap().contains(&out.message));
    }
    a.delete_rule_db(&rule.id).unwrap();
    assert!(a.list_rules_db().unwrap().is_empty());
    assert_eq!(b.list_rules_db().unwrap().len(), 1);
    let failed = b
        .execute_task(TaskProtocol::custom("throw new Error('task-failed')"), None)
        .unwrap();
    assert!(!failed.success);
    assert!(failed.task_id.is_empty());
    assert!(
        b.execute_task(TaskProtocol::refresh_toc("book"), None)
            .unwrap()
            .success
    );
}
