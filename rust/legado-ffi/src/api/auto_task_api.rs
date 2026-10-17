//! 自动任务 FFI API
//!
//! 复用核心算法，以完整实体保留登录配置；只在导入和执行文档处解析 JSON。
//!
//! 对应 Kotlin 原版 `AutoTask` / `AutoTaskRunner` / `AutoTaskSchedulePolicy`。

use legado_core::LegadoResult;
use legado_core::auto_task::{
    AutoTaskExporter, AutoTaskRule, AutoTaskRunner, AutoTaskSchedulePolicy, TaskAction,
    TaskProtocol, build_book_update_task as core_build_book_update_task,
    can_refresh_book_toc as core_can_refresh_book_toc,
    find_book_update_task as core_find_book_update_task, normalize_script as core_normalize_script,
    update_cron_batch as core_update_cron_batch,
};
use legado_core::models::AutoTaskRule as AutoTaskRuleModel;

use crate::db_state::with_database;
use legado_db::AutoTaskRepository;
use legado_db::repository::Repository;

/// 构建书籍更新定时任务（对应 Kotlin `AutoTask.buildBookUpdateTask`）
///
/// 返回构建好的 `AutoTaskRule`。
pub fn build_book_update_task(
    book_url: &str,
    book_name: &str,
    book_author: &str,
    name: &str,
) -> AutoTaskRule {
    core_build_book_update_task(book_url, book_name, book_author, name)
}

/// 核心算法只消费计算字段，不让其精简结构覆盖完整实体。
fn core_rule(v: &AutoTaskRuleModel) -> AutoTaskRule {
    AutoTaskRule {
        id: v.id.clone(),
        name: v.name.clone(),
        enable: v.enable,
        cron: v.cron.clone(),
        script: v.script.clone(),
        custom_order: v.custom_order,
        last_run_at: v.last_run_at,
        last_result: v.last_result.clone(),
        last_error: v.last_error.clone(),
        last_log: v.last_log.clone(),
    }
}

/// 批量 cron 复用核心算法，仅回写其改变的 cron 字段。
pub fn update_cron_batch(
    mut rules: Vec<AutoTaskRuleModel>,
    ids: &[String],
    cron: &str,
) -> Vec<AutoTaskRuleModel> {
    let mut calculation: Vec<_> = rules.iter().map(core_rule).collect();
    core_update_cron_batch(&mut calculation, ids, cron);
    for (rule, updated) in rules.iter_mut().zip(calculation) {
        rule.cron = updated.cron;
    }
    rules
}

/// 仅用户导入文档需要 JSON 解析；合并后输出完整实体。
pub fn prepare_imported_tasks(
    local_tasks: &[AutoTaskRuleModel],
    imported_json: &str,
) -> LegadoResult<Vec<AutoTaskRuleModel>> {
    let local: Vec<_> = local_tasks.iter().map(core_rule).collect();
    let imported =
        AutoTaskExporter::import_json(imported_json).map_err(legado_core::LegadoError::Parser)?;
    AutoTaskExporter::prepare_imported_tasks(&local, imported)
        .into_iter()
        .map(|value| {
            if !value.get("id").is_some_and(serde_json::Value::is_string)
                || !value.get("name").is_some_and(serde_json::Value::is_string)
            {
                return Err(legado_core::LegadoError::Parser(
                    "自动任务规则缺少有效id或name".into(),
                ));
            }
            Ok(serde_json::from_value(value)?)
        })
        .collect()
}

/// 执行任务协议（对应 Kotlin `AutoTaskRunner.execute`）
///
/// - `protocol_json`: TaskProtocol JSON
/// - `task_id`: 可选任务 ID
///
/// 返回任务执行结果 `TaskResult`。
pub fn execute_task(
    protocol_json: &str,
    task_id: Option<&str>,
) -> LegadoResult<legado_core::auto_task::TaskResult> {
    let protocol =
        TaskProtocol::from_json(protocol_json).map_err(legado_core::LegadoError::Parser)?;
    // [体检 §二.5 | P3-6] Custom JS 真实执行:对齐原版 AutoTaskRunner
    // （AutoTask.buildSource(task) → source.evalJS(script))——经 QuickJS 引擎
    // 求值并返回真实结果/错误,不再"验证脚本非空即视为成功"。
    if matches!(protocol.action, TaskAction::Custom(_)) {
        let js = match &protocol.action {
            TaskAction::Custom(js) => js.clone(),
            _ => unreachable!(),
        };
        let started = std::time::Instant::now();
        let (success, message) = match crate::js_executor::execute_auto_task_js(&js) {
            Ok(v) => (true, v),
            Err(e) => (false, e),
        };
        let duration_ms = started.elapsed().as_millis() as u64;
        let details = Some(format!(
            "[{}] Elapsed: {}ms
- {}",
            if success { "OK" } else { "FAIL" },
            duration_ms,
            message
        ));
        return Ok(legado_core::auto_task::TaskResult {
            task_id: task_id.map(|s| s.to_string()).unwrap_or_default(),
            success,
            message,
            duration_ms,
            details,
        });
    }
    Ok(match task_id {
        Some(id) => AutoTaskRunner::execute_with_id(&protocol, id),
        None => AutoTaskRunner::execute(&protocol),
    })
}

/// 规范化脚本（去除 @js: 前缀或 <js></js> 包裹）
pub fn normalize_script(script: &str) -> String {
    core_normalize_script(script)
}

/// 判断书籍是否允许刷新目录（对应 Kotlin `canRefreshBookToc`）
pub fn can_refresh_book_toc(can_update: bool, respect_can_update: bool) -> bool {
    core_can_refresh_book_toc(can_update, respect_can_update)
}

/// 查找书籍更新任务（对应 Kotlin `AutoTask.findBookUpdateTask`）
///
/// 优先按 ID 精确匹配，其次按书名 + 作者匹配。未找到返回 None。
pub fn find_book_update_task(
    tasks: &[AutoTaskRuleModel],
    book_url: &str,
    book_name: &str,
    book_author: &str,
) -> Option<AutoTaskRuleModel> {
    let calculation: Vec<_> = tasks.iter().map(core_rule).collect();
    let found = core_find_book_update_task(&calculation, book_url, book_name, book_author)?;
    tasks.iter().find(|task| task.id == found.id).cloned()
}

/// 解析 cron 表达式，计算下次执行时间（Unix 毫秒）
///
/// 无法解析时返回 -1。
pub fn next_due_at(cron: &str, from_ms: i64) -> i64 {
    AutoTaskSchedulePolicy::next_due_at(cron, from_ms).unwrap_or(-1)
}

// ─── 数据库 CRUD（通过 with_database 访问 auto_task_rules 表）───────────

/// 列出所有自动任务规则（按 customOrder 排序）
pub fn list_rules_db() -> LegadoResult<Vec<AutoTaskRuleModel>> {
    with_database(|db| {
        let repo = AutoTaskRepository::new(db.connection());
        repo.find_all()
    })
}

/// 创建自动任务规则（INSERT OR REPLACE，返回任务 ID）
pub fn create_rule_db(rule: &AutoTaskRuleModel) -> LegadoResult<String> {
    with_database(|db| {
        let repo = AutoTaskRepository::new(db.connection());
        repo.insert(rule)?;
        Ok(rule.id.clone())
    })
}

/// 更新自动任务规则（按 ID 更新）
pub fn update_rule_db(rule: &AutoTaskRuleModel) -> LegadoResult<()> {
    with_database(|db| {
        let repo = AutoTaskRepository::new(db.connection());
        repo.update(rule)
    })
}

/// 删除自动任务规则（按 ID 删除）
pub fn delete_rule_db(id: &str) -> LegadoResult<()> {
    with_database(|db| {
        let repo = AutoTaskRepository::new(db.connection());
        repo.delete(id)
    })
}

/// 根据 ID 查询自动任务规则
pub fn find_rule_by_id_db(id: &str) -> LegadoResult<Option<AutoTaskRuleModel>> {
    with_database(|db| {
        let repo = AutoTaskRepository::new(db.connection());
        repo.find_by_id(id)
    })
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
