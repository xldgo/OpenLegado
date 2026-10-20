//! 自动任务实体计算与执行服务；复用core协议与算法。
use legado_core::LegadoResult;
use legado_core::auto_task::{
    AutoTaskExporter, AutoTaskRule, AutoTaskRunner, AutoTaskSchedulePolicy, TaskAction,
    TaskProtocol, build_book_update_task as core_build_book_update_task,
    can_refresh_book_toc as core_can_refresh_book_toc,
    find_book_update_task as core_find_book_update_task, normalize_script as core_normalize_script,
    update_cron_batch as core_update_cron_batch,
};
use legado_core::models::AutoTaskRule as AutoTaskRuleModel;

use crate::StorageContext;
use legado_core::LegadoError;
use legado_db::{AutoTaskRepository, repository::Repository};
use std::sync::Arc;

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

pub struct AutoTaskService {
    storage: Option<StorageContext>,
    js: Arc<legado_js::JsResources>,
}
impl AutoTaskService {
    pub fn new(storage: Option<StorageContext>, js: Arc<legado_js::JsResources>) -> Self {
        Self { storage, js }
    }
    fn with_database<T>(
        &self,
        operation: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(operation)
    }
    /// 列出所有自动任务规则（按 customOrder 排序）
    pub fn list_rules_db(&self) -> LegadoResult<Vec<AutoTaskRuleModel>> {
        self.with_database(|db| {
            let repo = AutoTaskRepository::new(db.connection());
            repo.find_all()
        })
    }

    /// 创建自动任务规则（INSERT OR REPLACE，返回任务 ID）
    pub fn create_rule_db(&self, rule: &AutoTaskRuleModel) -> LegadoResult<String> {
        self.with_database(|db| {
            let repo = AutoTaskRepository::new(db.connection());
            repo.insert(rule)?;
            Ok(rule.id.clone())
        })
    }

    /// 更新自动任务规则（按 ID 更新）
    pub fn update_rule_db(&self, rule: &AutoTaskRuleModel) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = AutoTaskRepository::new(db.connection());
            repo.update(rule)
        })
    }

    /// 删除自动任务规则（按 ID 删除）
    pub fn delete_rule_db(&self, id: &str) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = AutoTaskRepository::new(db.connection());
            repo.delete(id)
        })
    }

    /// 根据 ID 查询自动任务规则
    pub fn find_rule_by_id_db(&self, id: &str) -> LegadoResult<Option<AutoTaskRuleModel>> {
        self.with_database(|db| {
            let repo = AutoTaskRepository::new(db.connection());
            repo.find_by_id(id)
        })
    }

    pub fn execute_task(
        &self,
        protocol: TaskProtocol,
        task_id: Option<&str>,
    ) -> LegadoResult<legado_core::auto_task::TaskResult> {
        // [体检 §二.5 | P3-6] Custom JS 真实执行:对齐原版 AutoTaskRunner
        // （AutoTask.buildSource(task) → source.evalJS(script))——经 QuickJS 引擎
        // 求值并返回真实结果/错误,不再"验证脚本非空即视为成功"。
        if matches!(protocol.action, TaskAction::Custom(_)) {
            let js = match &protocol.action {
                TaskAction::Custom(js) => js.clone(),
                _ => unreachable!(),
            };
            let started = std::time::Instant::now();
            let (success, message) = match execute_auto_task_js(&self.js, &js) {
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
}

/// 自定义任务保留每次独立flow和原executor语义，不注入源级额外配置。
#[cfg(feature = "quickjs")]
pub fn execute_auto_task_js(
    root: &Arc<legado_js::JsResources>,
    js_code: &str,
) -> Result<String, String> {
    use legado_js::executor::QuickJsExecutor;
    use legado_parser::JsExecutor;
    let resources = root.with_variable_scope(root.variables().fresh_flow("auto_task"));
    QuickJsExecutor::new("auto_task")
        .with_resources(resources)
        .execute_js(js_code)
}

#[cfg(not(feature = "quickjs"))]
pub fn execute_auto_task_js(
    _root: &Arc<legado_js::JsResources>,
    _js_code: &str,
) -> Result<String, String> {
    Err("Custom JS 执行需要 quickjs feature(当前构建未启用 JS 引擎)".to_string())
}

#[cfg(test)]
mod tests;
