//! 自动任务FFI适配：保留原文档边界，执行与实体计算委托Engine。
use legado_core::{
    LegadoResult, auto_task::TaskProtocol, models::AutoTaskRule as AutoTaskRuleModel,
};
use legado_engine::auto_task_service::AutoTaskService;
pub use legado_engine::auto_task_service::{
    build_book_update_task, can_refresh_book_toc, find_book_update_task, next_due_at,
    normalize_script, prepare_imported_tasks, update_cron_batch,
};

fn service() -> AutoTaskService {
    AutoTaskService::new(
        crate::engine_holder::current()
            .ok()
            .map(|e| e.storage().clone()),
        crate::engine_holder::js_resources(),
    )
}
pub fn execute_task(
    protocol_json: &str,
    task_id: Option<&str>,
) -> LegadoResult<legado_core::auto_task::TaskResult> {
    let protocol =
        TaskProtocol::from_json(protocol_json).map_err(legado_core::LegadoError::Parser)?;
    service().execute_task(protocol, task_id)
}

pub fn list_rules_db() -> LegadoResult<Vec<AutoTaskRuleModel>> {
    service().list_rules_db()
}

pub fn create_rule_db(rule: &AutoTaskRuleModel) -> LegadoResult<String> {
    service().create_rule_db(rule)
}

pub fn update_rule_db(rule: &AutoTaskRuleModel) -> LegadoResult<()> {
    service().update_rule_db(rule)
}

pub fn delete_rule_db(id: &str) -> LegadoResult<()> {
    service().delete_rule_db(id)
}

pub fn find_rule_by_id_db(id: &str) -> LegadoResult<Option<AutoTaskRuleModel>> {
    service().find_rule_by_id_db(id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn full_entities_survive_calculation_and_import_merges_runtime() {
        let built = build_book_update_task("book", "书", "作者", "更新");
        let mut local: AutoTaskRuleModel =
            crate::automation_dto::AutoTaskRuleDto::from(built).into();
        local.header = Some("header".into());
        local.login_ui = Some("[]".into());
        local.js_lib = Some("lib".into());
        local.enabled_cookie_jar = false;
        local.custom_order = 7;
        local.last_run_at = 9007199254740993;
        local.last_log = Some("log".into());
        let updated =
            update_cron_batch(vec![local.clone()], std::slice::from_ref(&local.id), "new");
        let mut expected = local.clone();
        expected.cron = Some("new".into());
        assert_eq!(
            serde_json::to_value(&updated[0]).unwrap(),
            serde_json::to_value(expected).unwrap()
        );
        let found = find_book_update_task(&[local.clone()], "book", "书", "作者").unwrap();
        assert_eq!(found.header, local.header);
        assert_eq!(found.login_ui, local.login_ui);
        let document = serde_json::json!([
            {"id": local.id, "name":"替代一", "script":"x", "header":"new-header"},
            {"id": local.id, "name":"替代二", "script":"y", "header":"final-header"},
            {"id":"new", "name":"新", "script":"z"}
        ])
        .to_string();
        let merged = prepare_imported_tasks(&[local.clone()], &document).unwrap();
        assert_eq!(merged.len(), 2);
        assert_eq!(merged[0].name, "替代二");
        assert_eq!(merged[0].header.as_deref(), Some("final-header"));
        assert_eq!(merged[0].custom_order, local.custom_order);
        assert_eq!(merged[0].last_run_at, local.last_run_at);
        assert_eq!(merged[0].last_log, local.last_log);
        assert_eq!(merged[1].custom_order, 8);
        assert!(prepare_imported_tasks(&[], r#"[{"id":"x"}]"#).is_err());
        assert!(prepare_imported_tasks(&[], "not json").is_err());
    }

    #[test]
    fn test_build_book_update_task() {
        let task = build_book_update_task("http://book/1", "测试", "作者", "更新测试");
        assert!(task.id.starts_with("book_update:"));
        assert_eq!(task.name, "更新测试");
    }

    #[test]
    fn test_update_cron_batch() {
        let task = build_book_update_task("http://book/1", "测试", "作者", "更新");
        let rule: AutoTaskRuleModel =
            crate::automation_dto::AutoTaskRuleDto::from(task.clone()).into();
        let updated = update_cron_batch(vec![rule], &[task.id], "0 */6 * * *");
        assert_eq!(updated.len(), 1);
        assert_eq!(updated[0].cron, Some("0 */6 * * *".to_string()));
    }

    #[test]
    fn test_prepare_imported_tasks() {
        let local = vec![build_book_update_task(
            "http://book/1",
            "测试",
            "作者",
            "更新",
        )];
        let local: Vec<AutoTaskRuleModel> = local
            .into_iter()
            .map(|v| crate::automation_dto::AutoTaskRuleDto::from(v).into())
            .collect();
        let imported = r#"[{"id":"new1","name":"新任务","script":"x"}]"#;
        let merged = prepare_imported_tasks(&local, imported).unwrap();
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].id, "new1");
    }

    #[test]
    fn test_execute_task() {
        let protocol = TaskProtocol::refresh_toc("http://book/1");
        let json = protocol.to_json();
        let result = execute_task(&json, Some("t1")).unwrap();
        assert!(result.success);
        assert_eq!(result.task_id, "t1");
    }

    #[test]
    fn test_normalize_script() {
        assert_eq!(normalize_script("@js: var x=1;"), "var x=1;");
    }

    #[test]
    fn test_can_refresh_book_toc() {
        assert!(can_refresh_book_toc(true, true));
        assert!(!can_refresh_book_toc(false, true));
        assert!(can_refresh_book_toc(false, false));
    }

    #[test]
    fn test_find_book_update_task() {
        let task = build_book_update_task("http://book/1", "测试", "作者", "更新");
        let rule: AutoTaskRuleModel = crate::automation_dto::AutoTaskRuleDto::from(task).into();
        let found = find_book_update_task(&[rule], "http://book/1", "测试", "作者");
        assert!(found.is_some());
    }

    #[test]
    fn test_next_due_at() {
        let base: i64 = 1_000_000_000_000;
        assert_eq!(next_due_at("*/30 * * * *", base), base + 30 * 60_000);
        assert_eq!(next_due_at("invalid", base), -1);
    }

    #[test]
    fn test_auto_task_crud_db() {
        let _db_guard = crate::db_state::ensure_test_db();

        let rule = AutoTaskRuleModel {
            id: "test_crud_task_001".to_string(),
            name: "测试CRUD任务".to_string(),
            enable: true,
            cron: Some("0 */6 * * *".to_string()),
            script: "print('hello')".to_string(),
            ..AutoTaskRuleModel::default()
        };

        // Create
        create_rule_db(&rule).unwrap();

        // List
        let rules = list_rules_db().unwrap();
        assert!(rules.iter().any(|r| r.id == "test_crud_task_001"));

        // Find by ID
        let found = find_rule_by_id_db("test_crud_task_001").unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "测试CRUD任务");

        // Update
        let updated_rule = AutoTaskRuleModel {
            name: "已更新任务".to_string(),
            ..rule.clone()
        };
        update_rule_db(&updated_rule).unwrap();
        let after_update = find_rule_by_id_db("test_crud_task_001").unwrap().unwrap();
        assert_eq!(after_update.name, "已更新任务");

        // Delete
        delete_rule_db("test_crud_task_001").unwrap();

        // Verify deleted
        assert!(find_rule_by_id_db("test_crud_task_001").unwrap().is_none());
    }
}
