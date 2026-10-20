//! V2动态登录协议与命令写回，复用core协议实现。
#[cfg(feature = "quickjs")]
use super::js::json_to_js_value;
use super::*;
use legado_core::login_ui_v2;

pub fn is_login_ui_v2(source: &BookSource) -> bool {
    login_ui_v2::is_v2(source.login_ui.as_deref())
}

/// V2 登录动作请求（`source_login_action_v2` 的 `user_input_json` 契约）
///
/// - `action` — 按钮动作名（RowUi.action）
/// - `stateJson` — 当前状态（JSON 字符串或对象均可，对象会自动序列化）
/// - `formJson` — 表单键值（JSON 对象或字符串均可）
#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LoginActionV2Request {
    pub action: String,
    #[serde(default)]
    pub state_json: serde_json::Value,
    #[serde(default)]
    pub form_json: serde_json::Value,
}

fn json_param_to_string(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::Null => "{}".to_string(),
        serde_json::Value::String(s) => {
            if s.trim().is_empty() {
                "{}".to_string()
            } else {
                s.clone()
            }
        }
        other => other.to_string(),
    }
}

impl SourceActionService {
    pub fn eval_login_ui_v2(&self, source: &BookSource, state_json: &str) -> LegadoResult<String> {
        let state = if state_json.trim().is_empty() {
            "{}"
        } else {
            state_json
        };
        let result = self.eval_with_quickjs(source, |eval_js| {
            login_ui_v2::eval_login_ui_v2(source, state, eval_js)
        })?;
        Ok(result.unwrap_or_default())
    }

    pub fn eval_login_action_v2(
        &self,
        source: &BookSource,
        request: &LoginActionV2Request,
    ) -> LegadoResult<String> {
        let state = json_param_to_string(&request.state_json);
        let form = json_param_to_string(&request.form_json);
        let result = self.eval_with_quickjs(source, |eval_js| {
            login_ui_v2::eval_login_action_v2(source, &request.action, &state, &form, eval_js)
        })?;

        // 1) login 命令 → putLoginInfo 落库（对齐 SourceLoginV2Delegate.kt:268-274）
        if let Some(json) = result.as_deref() {
            let command = login_ui_v2::parse_action_result(Some(json));
            if let Some(login_json) = command.login_json {
                self.resources
                    .login
                    .put_login_info(&source.book_source_url, &login_json);
            }
        }

        Ok(result.unwrap_or_default())
    }

    #[cfg(feature = "quickjs")]
    fn eval_with_quickjs<F>(&self, source: &BookSource, eval: F) -> LegadoResult<Option<String>>
    where
        F: for<'a> FnOnce(login_ui_v2::EvalJs<'a>) -> LegadoResult<Option<String>>,
    {
        use legado_js::{JsEngine, JsValue};

        let engine = self.fresh_engine(&source.book_source_url)?;
        let guard = engine
            .lock()
            .map_err(|e| LegadoError::JsEngine(format!("JS 引擎加锁失败: {e}")))?;

        // 对齐 Kotlin evalJS 绑定：baseUrl = getKey()；source = 书源对象
        let source_obj_json = serde_json::to_string(source)?;
        let base_url = source.book_source_url.clone();
        let mut eval_js = |code: &str, bindings: &[(&str, &str)]| -> LegadoResult<String> {
            let mut js_bindings: Vec<(&str, JsValue)> = Vec::with_capacity(bindings.len() + 2);
            js_bindings.push(("baseUrl", JsValue::String(base_url.clone())));
            if let Ok(value) = serde_json::from_str::<serde_json::Value>(&source_obj_json) {
                js_bindings.push(("source", json_to_js_value(value)));
            }
            for (name, value) in bindings {
                js_bindings.push((name, JsValue::String((*value).to_string())));
            }
            guard.eval_with_bindings(code, &js_bindings)
        };
        // P2-19：绑定当前书源 tag（对齐 explore_api / js_executor 主路径）：
        // V2 loginUi/loginAction 脚本调用 java.ajax（登录 API）时 Cookie/全局头
        // 按本源 book_source_url 过滤（而非未归属不带、更非全量合并泄漏）。
        legado_js::host_api::current_source::with_current_source_tag(
            &source.book_source_url,
            || eval(&mut eval_js),
        )
    }

    #[cfg(not(feature = "quickjs"))]
    fn eval_with_quickjs<F>(&self, _source: &BookSource, _eval: F) -> LegadoResult<Option<String>>
    where
        F: for<'a> FnOnce(login_ui_v2::EvalJs<'a>) -> LegadoResult<Option<String>>,
    {
        Err(LegadoError::JsEngine(
            "QuickJS engine not enabled. Build with --features quickjs".into(),
        ))
    }
}
