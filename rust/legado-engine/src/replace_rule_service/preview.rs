//! 规则预览复用core超时与替换管线，不查询宿主全局资源。
use legado_core::{
    content_processor::{ReplaceJsExecutor, ReplaceRuleEntry, preview_single_rule},
    models::ReplaceRule,
};
use std::sync::Arc;

struct ReplacePreviewJsExecutor {
    js: Arc<legado_js::JsResources>,
}
impl ReplaceJsExecutor for ReplacePreviewJsExecutor {
    fn eval(&self, js_code: &str, result: &str) -> Result<String, String> {
        #[cfg(feature = "quickjs")]
        {
            // 每次匹配使用独立VM，来源变量仍归属注入的同一实例。
            let engine = self
                .js
                .for_source("source", "replace-rule-preview", "")
                .create_engine(
                    legado_js::sandbox::SandboxConfig::default()
                        .with_allow_script_run(true)
                        .with_memory_limit(64 * 1024 * 1024),
                )
                .map_err(|e| format!("JS 引擎创建失败: {e}"))?;
            let engine = Arc::new(std::sync::Mutex::new(engine));
            let engine = engine.lock().map_err(|_| "JS 引擎锁中毒".to_string())?;
            let bindings: [(&str, legado_js::JsValue); 1] =
                [("result", legado_js::JsValue::from(result))];
            legado_js::JsEngine::eval_with_bindings(&*engine, js_code, &bindings)
                .map_err(|e| e.to_string())
        }
        #[cfg(not(feature = "quickjs"))]
        {
            let _ = (&self.js, js_code, result);
            Err("QuickJS 未启用，@js: 替换预览不可用（请确认构建启用 quickjs feature）".to_string())
        }
    }
}

/// 输入文档解析由边界完成；执行失败转为原编辑器警告文本。
pub fn preview_replace_rule(
    rule: &ReplaceRule,
    sample: &str,
    js: Arc<legado_js::JsResources>,
) -> String {
    let entry = ReplaceRuleEntry::from_replace_rule(rule);
    let executor: Option<Arc<dyn ReplaceJsExecutor>> =
        Some(Arc::new(ReplacePreviewJsExecutor { js }));
    match preview_single_rule(sample, &entry, &executor) {
        Ok(text) => text,
        Err(e) => format!("⚠️ {e}"),
    }
}
