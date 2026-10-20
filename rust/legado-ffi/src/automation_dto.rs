//! 自动任务稳定传输模型；脚本和导入文档保留原协议。— Codex + Bridge

#[derive(Debug, Clone)]
pub struct AutoTaskRuleDto {
    pub id: String,
    pub name: String,
    pub enable: bool,
    pub cron: Option<String>,
    pub login_url: Option<String>,
    pub login_ui: Option<String>,
    pub login_check_js: Option<String>,
    pub comment: Option<String>,
    pub script: String,
    pub header: Option<String>,
    pub js_lib: Option<String>,
    pub concurrent_rate: Option<String>,
    pub enabled_cookie_jar: bool,
    pub custom_order: i32,
    pub last_run_at: i64,
    pub last_result: Option<String>,
    pub last_error: Option<String>,
    pub last_log: Option<String>,
}
impl From<legado_core::models::AutoTaskRule> for AutoTaskRuleDto {
    fn from(v: legado_core::models::AutoTaskRule) -> Self {
        Self {
            id: v.id,
            name: v.name,
            enable: v.enable,
            cron: v.cron,
            login_url: v.login_url,
            login_ui: v.login_ui,
            login_check_js: v.login_check_js,
            comment: v.comment,
            script: v.script,
            header: v.header,
            js_lib: v.js_lib,
            concurrent_rate: v.concurrent_rate,
            enabled_cookie_jar: v.enabled_cookie_jar,
            custom_order: v.custom_order,
            last_run_at: v.last_run_at,
            last_result: v.last_result,
            last_error: v.last_error,
            last_log: v.last_log,
        }
    }
}
impl From<AutoTaskRuleDto> for legado_core::models::AutoTaskRule {
    fn from(v: AutoTaskRuleDto) -> Self {
        Self {
            id: v.id,
            name: v.name,
            enable: v.enable,
            cron: v.cron,
            login_url: v.login_url,
            login_ui: v.login_ui,
            login_check_js: v.login_check_js,
            comment: v.comment,
            script: v.script,
            header: v.header,
            js_lib: v.js_lib,
            concurrent_rate: v.concurrent_rate,
            enabled_cookie_jar: v.enabled_cookie_jar,
            custom_order: v.custom_order,
            last_run_at: v.last_run_at,
            last_result: v.last_result,
            last_error: v.last_error,
            last_log: v.last_log,
        }
    }
}
impl From<legado_core::auto_task::AutoTaskRule> for AutoTaskRuleDto {
    fn from(v: legado_core::auto_task::AutoTaskRule) -> Self {
        legado_core::models::AutoTaskRule {
            id: v.id,
            name: v.name,
            enable: v.enable,
            cron: v.cron,
            script: v.script,
            custom_order: v.custom_order,
            last_run_at: v.last_run_at,
            last_result: v.last_result,
            last_error: v.last_error,
            last_log: v.last_log,
            ..Default::default()
        }
        .into()
    }
}

#[derive(Debug, Clone)]
pub struct TaskResultDto {
    pub task_id: String,
    pub success: bool,
    pub message: String,
    pub duration_ms: u64,
    pub details: Option<String>,
}
impl From<legado_core::auto_task::TaskResult> for TaskResultDto {
    fn from(v: legado_core::auto_task::TaskResult) -> Self {
        Self {
            task_id: v.task_id,
            success: v.success,
            message: v.message,
            duration_ms: v.duration_ms,
            details: v.details,
        }
    }
}
