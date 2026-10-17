//! 字典作用域执行器：key/word/result与变量读者属于传入实例。
use super::*;

/// 引擎池缓存标签（按规则名分桶，同书源 URL 分桶模式）
pub(super) fn engine_tag(rule_name: &str) -> String {
    format!("dict:{rule_name}")
}

/// 字典规则 JS 作用域执行器
///
/// 对标 Kotlin `AnalyzeUrl.evalJS` / `AnalyzeRule.evalJS` 的脚本绑定
/// （`bindings["key"]` / `bindings["result"]` 等）：QuickJS 无等价
/// bindings 注入口，故以 `globalThis.key/word/result = <JSON 字面量>;`
/// 前置注入后再执行（同 `js_executor::execute_login_check_response` 的既有模式；
/// [能力对账批次 2] var → globalThis 属性注入，不注册全局 var 条目）。
pub(super) struct DictScopeExecutor {
    pub(super) base: Option<Arc<dyn JsExecutor>>,
    pub(super) prelude: String,
    pub(super) variables: legado_parser::VariableReader,
}

impl DictScopeExecutor {
    pub(super) fn with_resources(
        resources: &legado_js::JsResources,
        tag: &str,
        key: &str,
        result: &str,
    ) -> Self {
        // 用途、规则标签与查询词分别保存，避免拼接身份碰撞。
        let resources = resources.for_source("dictionary", tag, key);
        let variables = resources.variable_reader();
        #[cfg(feature = "quickjs")]
        let base = Some(Arc::new(
            legado_js::executor::QuickJsExecutor::new(tag).with_resources(resources),
        ) as Arc<dyn JsExecutor>);
        #[cfg(not(feature = "quickjs"))]
        let base = None;
        // [能力对账批次 2 | #702/#850] var → globalThis 属性注入（不注册全局
        // var 条目，与规则块顶层 let 声明不再冲突；读路径等价）
        let prelude = format!(
            "globalThis.key = {};\nglobalThis.word = {};\nglobalThis.result = {};\n",
            js_string_literal(key),
            js_string_literal(key),
            js_string_literal(result),
        );
        Self {
            base,
            prelude,
            variables,
        }
    }
}

impl JsExecutor for DictScopeExecutor {
    fn read_variable(&self, key: &str) -> Option<String> {
        (self.variables)(key)
    }

    fn execute_js(&self, js_code: &str) -> Result<String, String> {
        match &self.base {
            Some(base) => base.execute_js(&format!("{}{}", self.prelude, js_code)),
            None => Err("未启用 JS 引擎（quickjs 特性未编译），@js 规则不可用".to_string()),
        }
    }
}

/// 生成 JS 字符串字面量（JSON 字符串是合法的 JS 字符串字面量，
/// 天然处理引号/反斜杠/换行转义）
fn js_string_literal(s: &str) -> String {
    serde_json::to_string(s).unwrap_or_else(|_| "''".to_string())
}
