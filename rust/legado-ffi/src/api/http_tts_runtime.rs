//! HTTP TTS 登录宿主适配；脚本与来源状态由Engine服务处理。
use legado_core::LegadoResult;
#[cfg(test)]
pub fn config_for(id: i64) -> LegadoResult<legado_fetcher::HttpTtsConfig> {
    let engine = crate::engine_holder::current()?;
    legado_engine::tts_service::config_for_storage(engine.storage(), id)
}
pub fn login(id: i64, operation: &str, payload: &str) -> LegadoResult<String> {
    let service = crate::engine_holder::current()?.tts_service();
    service.login(id, operation, payload)
}

#[cfg(all(test, feature = "quickjs"))]
mod tests {
    use super::*;
    #[test]
    fn test_http_tts_login_v2_actions_and_source_isolation() {
        let _db_guard = crate::db_state::ensure_test_db();
        let id=super::super::http_tts_api::add_http_tts_json(r#"{
          "id":-8011,"name":"登录测试","url":"http://local/tts","loginUi":"{\"version\":2}",
          "loginUrl":"function loginUi(state){return {rows:[{name:'用户名',type:'text',key:'account'},{name:'登录',type:'button',action:'login'}]};} function loginAction(action,state,form){source.putLoginHeader(JSON.stringify({'X-Auth':form.account}));return {login:{account:form.account},close:true};}"
        }"#).unwrap();
        let ui = login(id, "ui", "{}").unwrap();
        assert!(ui.contains("account"));
        let action = login(
            id,
            "action",
            r#"{"action":"login","stateJson":{},"formJson":{"account":"账号甲"}}"#,
        )
        .unwrap();
        assert!(action.contains("close"));
        assert!(login(id, "info", "").unwrap().contains("账号甲"));
        assert!(login(id, "headers", "").unwrap().contains("账号甲"));
        let other = super::super::http_tts_api::add_http_tts_json(
            r#"{"id":-8012,"name":"同 URL","url":"http://local/tts"}"#,
        )
        .unwrap();
        assert!(login(other, "info", "").unwrap().is_empty());
        assert!(login(other, "header", "").unwrap().is_empty());
        assert!(login(id, "unknown", "").is_err());
        assert!(login(id, "putHeader", "not-json").is_err());
        login(id, "putHeader", "").unwrap();
        assert!(login(id, "header", "").unwrap().is_empty());
        super::super::http_tts_api::delete_http_tts(id).unwrap();
        super::super::http_tts_api::delete_http_tts(other).unwrap();
    }

    #[test]
    fn test_http_tts_login_classic_action_uses_real_configuration() {
        let _db_guard = crate::db_state::ensure_test_db();
        let id=super::super::http_tts_api::add_http_tts_json(r#"{
          "id":-8013,"name":"经典登录","url":"http://local/tts",
          "loginUi":[{"name":"account","type":"text","default":"默认账号"}],
          "loginUrl":"function login(){source.putLoginHeader(JSON.stringify({'X-Key':source.getKey(),'X-Account':source.getLoginInfoMap().account}));}"
        }"#).unwrap();
        assert!(login(id, "ui", "{}").unwrap().contains("默认账号"));
        login(id, "putInfo", r#"{"account":"手动账号"}"#).unwrap();
        let output = login(id, "eval", "login.apply(this)").unwrap();
        assert!(output.contains("actions"));
        let headers = login(id, "headers", "").unwrap();
        assert!(headers.contains("httpTts:-8013"));
        assert!(headers.contains("手动账号"));
        assert!(login(id, "eval", "throw new Error('错误不能吞掉')").is_err());
        super::super::http_tts_api::delete_http_tts(id).unwrap();
    }
}
