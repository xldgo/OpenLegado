//! 独立VM创建及值转换；各动作继续决定自身绑定内容。
use super::*;
impl SourceActionService {
    pub(super) fn fresh_engine(
        &self,
        tag: &str,
    ) -> LegadoResult<Arc<std::sync::Mutex<legado_js::QuickJsEngine>>> {
        let engine = self
            .resources
            .js
            .for_source("source", tag, "")
            .create_engine(
                legado_js::sandbox::SandboxConfig::default()
                    .with_allow_script_run(true)
                    .with_memory_limit(64 * 1024 * 1024),
            )?;
        Ok(Arc::new(std::sync::Mutex::new(engine)))
    }
}
pub(super) fn json_to_js_value(value: serde_json::Value) -> legado_js::JsValue {
    use legado_js::JsValue;
    match value {
        serde_json::Value::Null => JsValue::Null,
        serde_json::Value::Bool(b) => JsValue::Bool(b),
        serde_json::Value::Number(n) => match n.as_i64() {
            Some(i) => JsValue::Int(i),
            None => JsValue::Number(n.as_f64().unwrap_or(0.0)),
        },
        serde_json::Value::String(s) => JsValue::String(s),
        serde_json::Value::Array(items) => {
            JsValue::Array(items.into_iter().map(json_to_js_value).collect())
        }
        serde_json::Value::Object(map) => JsValue::Object(
            map.into_iter()
                .map(|(k, v)| (k, json_to_js_value(v)))
                .collect(),
        ),
    }
}
