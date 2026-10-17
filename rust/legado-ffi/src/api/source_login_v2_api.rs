//! 登录V2边界：保留文档解析与原入口，执行委托Engine。
use legado_core::{LegadoResult, models::BookSource};
pub use legado_engine::source_action_service::LoginActionV2Request;

pub fn is_login_ui_v2(source: &BookSource) -> bool {
    legado_engine::source_action_service::is_login_ui_v2(source)
}
pub fn eval_login_ui_v2(source: &BookSource, state_json: &str) -> LegadoResult<String> {
    crate::source_action_host::service().eval_login_ui_v2(source, state_json)
}
pub fn eval_login_action_v2(source: &BookSource, user_input_json: &str) -> LegadoResult<String> {
    let request: LoginActionV2Request = serde_json::from_str(user_input_json)?;
    crate::source_action_host::service().eval_login_action_v2(source, &request)
}

#[cfg(all(test, feature = "quickjs"))]
mod tests {
    use super::*;
    use legado_core::login_ui_v2;

    // 仅测试fixture保留JSON文档输入；生产入口直接接收实体。
    fn is_login_ui_v2(document: &str) -> LegadoResult<bool> {
        Ok(super::is_login_ui_v2(&serde_json::from_str(document)?))
    }
    fn eval_login_ui_v2(document: &str, state: &str) -> LegadoResult<String> {
        super::eval_login_ui_v2(&serde_json::from_str(document)?, state)
    }
    fn eval_login_action_v2(document: &str, request: &str) -> LegadoResult<String> {
        super::eval_login_action_v2(&serde_json::from_str(document)?, request)
    }

    /// 对齐 Kotlin `LoginUiV2EngineTest`：mainJs 提供 loginUi/loginAction 的 JS 单文件书源
    fn v2_source_json() -> String {
        serde_json::json!({
            "bookSourceUrl": "https://login-v2.example.com",
            "bookSourceName": "登录测试",
            "loginUi": login_ui_v2::MARKER,
            "mainJs": r#"
                function loginUi(state) {
                    if (!state.step) return { rows: [
                        { key: "phone", name: "手机号", type: "text" },
                        { name: "发送验证码", type: "button", action: "sendCode" }
                    ] };
                    return { rows: [
                        { key: "code", name: "验证码", type: "text" },
                        { name: "重新发码", type: "button", action: "sendCode", countdown: 60 }
                    ] };
                }
                function loginAction(action, state, form) {
                    if (action == "sendCode") {
                        if (!form.phone) return { error: { phone: "手机号必填" } };
                        return { state: { step: "code", phone: "+86" + form.phone } };
                    }
                    if (action == "noop") return;
                    return { login: { token: state.phone + "-tk" }, close: true };
                }
            "#
        })
        .to_string()
    }

    #[test]
    fn test_is_login_ui_v2() {
        assert!(is_login_ui_v2(&v2_source_json()).unwrap());
        let v1 = serde_json::json!({
            "bookSourceUrl": "https://v1.example.com",
            "loginUi": r#"[{"name":"账号","type":"text"}]"#
        })
        .to_string();
        assert!(!is_login_ui_v2(&v1).unwrap());
    }

    #[test]
    fn test_eval_login_ui_v2_render_states() {
        let source_json = v2_source_json();
        // 首次渲染（state = {}）
        let first = eval_login_ui_v2(&source_json, "{}").unwrap();
        let rows = login_ui_v2::parse_render(Some(&first)).expect("首次渲染应合法");
        assert_eq!(rows[0].key.as_deref(), Some("phone"));

        // 进入验证码步骤
        let second = eval_login_ui_v2(&source_json, r#"{"step":"code"}"#).unwrap();
        let rows = login_ui_v2::parse_render(Some(&second)).expect("二次渲染应合法");
        assert_eq!(rows[0].key.as_deref(), Some("code"));
        assert_eq!(rows[1].countdown, Some(60));
    }

    #[test]
    fn test_eval_login_action_v2_commands() {
        let source_json = v2_source_json();

        // sendCode 成功 → state 命令
        let raw = eval_login_action_v2(
            &source_json,
            r#"{"action":"sendCode","formJson":{"phone":"13800000000"}}"#,
        )
        .unwrap();
        let command = login_ui_v2::parse_action_result(Some(&raw));
        assert!(command.state_json.unwrap().contains("+8613800000000"));
        assert!(command.error.is_none());

        // sendCode 缺手机号 → error 命令
        let raw = eval_login_action_v2(&source_json, r#"{"action":"sendCode"}"#).unwrap();
        let command = login_ui_v2::parse_action_result(Some(&raw));
        assert_eq!(command.error.unwrap().get("phone").unwrap(), "手机号必填");

        // noop → 无命令（undefined 规范化为空）
        let raw = eval_login_action_v2(&source_json, r#"{"action":"noop"}"#).unwrap();
        let command =
            login_ui_v2::parse_action_result(Some(raw.as_str()).filter(|s| !s.is_empty()));
        assert!(command.state_json.is_none());
        assert!(!command.close);
        assert!(!command.malformed);

        // submit → login + close
        let raw = eval_login_action_v2(
            &source_json,
            r#"{"action":"submit","stateJson":{"phone":"+86138"},"formJson":{}}"#,
        )
        .unwrap();
        let command = login_ui_v2::parse_action_result(Some(&raw));
        assert!(command.login_json.unwrap().contains("+86138-tk"));
        assert!(command.close);
    }

    /// login 命令应自动落库 userInfo（对齐 SourceLoginV2Delegate.putLoginInfo）
    /// — DeepSeek Harness + Bridge
    #[test]
    fn test_eval_login_action_v2_persists_login_info() {
        let source_url = "https://login-v2.example.com";
        crate::api::source_login_cache::remove_login_info(source_url).unwrap();

        let source_json = v2_source_json();
        let raw = eval_login_action_v2(
            &source_json,
            r#"{"action":"submit","stateJson":{"phone":"+86138"},"formJson":{}}"#,
        )
        .unwrap();
        let command = login_ui_v2::parse_action_result(Some(&raw));
        assert!(command.close, "submit 应返回 close");

        // login 命令应已写入 source_login_cache（userInfo_<url>）
        let info = crate::api::source_login_cache::get_login_info(source_url);
        assert!(info.is_some(), "login 命令应自动落库 userInfo_<url>");
        assert!(
            info.as_deref().unwrap().contains("+86138-tk"),
            "落库内容应为 login JSON"
        );

        crate::api::source_login_cache::remove_login_info(source_url).unwrap();
    }

    #[test]
    fn login_command_wins_over_js_intermediate_value_without_old_global_copy() {
        let _lock = crate::test_support::lock_global_store();
        let url = "https://login-v2-command-order.test";
        let key = format!("userInfo_{url}");
        crate::engine_holder::js_resources()
            .variables()
            .set_variable(&key, "old-global")
            .unwrap();
        let source = serde_json::json!({
            "bookSourceUrl": url, "loginUi": login_ui_v2::MARKER,
            "mainJs": format!("function loginAction(action,state,form) {{ put('userInfo_{url}','intermediate'); return {{login:{{token:'command'}},close:true}}; }}")
        });
        eval_login_action_v2(&source.to_string(), r#"{"action":"submit"}"#).unwrap();
        let info = crate::api::source_login_cache::get_login_info(url).unwrap();
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&info).unwrap()["token"],
            "command"
        );
        assert_eq!(
            crate::engine_holder::js_resources()
                .variables()
                .get_variable(&key)
                .unwrap()
                .as_deref(),
            Some("old-global")
        );
        crate::api::source_login_cache::remove_login_info(url).unwrap();
        crate::engine_holder::js_resources()
            .variables()
            .remove_variable(&key)
            .unwrap();
    }

    #[test]
    fn test_eval_login_ui_v2_declarative_login_url() {
        // 对齐 Kotlin：声明式脚本放 loginUrl
        let source_json = serde_json::json!({
            "bookSourceUrl": "https://declarative.example.com",
            "bookSourceName": "声明式登录测试",
            "loginUi": login_ui_v2::MARKER,
            "loginUrl": r#"
                function loginUi(state) {
                    return { rows: [{ key: "account", name: "账号", type: "text" }] };
                }
                function loginAction(action, state, form) {
                    return { login: { account: form.account }, close: true };
                }
            "#
        })
        .to_string();

        let raw = eval_login_ui_v2(&source_json, "{}").unwrap();
        let rows = login_ui_v2::parse_render(Some(&raw)).expect("声明式渲染应合法");
        assert_eq!(rows[0].key.as_deref(), Some("account"));

        let raw = eval_login_action_v2(
            &source_json,
            r#"{"action":"submit","formJson":{"account":"reader"}}"#,
        )
        .unwrap();
        let command = login_ui_v2::parse_action_result(Some(&raw));
        assert_eq!(
            command.login_json.as_deref(),
            Some(r#"{"account":"reader"}"#)
        );
        assert!(command.close);
    }

    #[test]
    fn test_eval_login_ui_v2_source_binding() {
        // JS 绑定上下文：脚本可读取 source 对象与 baseUrl
        let source_json = serde_json::json!({
            "bookSourceUrl": "https://binding.example.com",
            "bookSourceName": "绑定测试",
            "loginUi": login_ui_v2::MARKER,
            "mainJs": r#"
                function loginUi(state) {
                    return { rows: [{ key: "n", name: source.bookSourceName + "@" + baseUrl, type: "text" }] };
                }
                function loginAction(action, state, form) { return { close: true }; }
            "#
        })
        .to_string();
        let raw = eval_login_ui_v2(&source_json, "{}").unwrap();
        assert!(raw.contains("绑定测试@https://binding.example.com"));
    }

    #[test]
    fn test_eval_missing_script_error() {
        let source_json = serde_json::json!({
            "bookSourceUrl": "https://missing.example.com",
            "loginUi": login_ui_v2::MARKER
        })
        .to_string();
        let err = eval_login_ui_v2(&source_json, "{}").unwrap_err();
        assert!(err.to_string().contains("缺少 loginUi/loginAction 脚本"));
    }
}
