//! HTTP TTS 宿主装配：数据库配置、来源变量与登录设施。
use legado_core::{LegadoError, LegadoResult};
use legado_db::{CacheRepository, HttpTtsRepository};
use legado_fetcher::{HttpTtsConfig, tts_source::TtsSourceStore};
use std::collections::BTreeMap;
use std::sync::Arc;

pub fn config_for(id: i64) -> LegadoResult<HttpTtsConfig> {
    let entity = crate::db_state::with_database(|db| {
        HttpTtsRepository::new(db.connection()).find_by_id(id)
    })?
    .ok_or_else(|| LegadoError::Database(format!("未找到 ID 为 {id} 的 HTTP TTS 引擎配置")))?;
    Ok(HttpTtsConfig {
        id: entity.id,
        name: entity.name,
        url: entity.url,
        header: entity.header,
        content_type: entity.content_type,
        js_lib: entity.js_lib,
        speed: entity.speed,
        enabled_cookie_jar: entity.enabled_cookie_jar,
        concurrent_rate: entity.concurrent_rate,
        login_url: entity.login_url,
        login_ui: entity.login_ui,
        login_check_js: entity.login_check_js,
    })
}

pub struct DbTtsSourceStore;
impl TtsSourceStore for DbTtsSourceStore {
    fn load(&self, key: &str) -> LegadoResult<BTreeMap<String, String>> {
        let mut values: BTreeMap<String, String> = crate::db_state::with_database(|db| {
            let value =
                CacheRepository::new(db.connection()).get(&format!("ttsSourceState_{key}"))?;
            Ok(match value {
                Some(json) => serde_json::from_str(&json)?,
                None => BTreeMap::new(),
            })
        })?;
        if let Some(value) = super::source_login_cache::get_login_header(key) {
            values.insert("loginHeader".into(), value);
        }
        if let Some(value) = super::source_login_cache::get_login_info(key) {
            values.insert("loginInfo".into(), value);
        }
        Ok(values)
    }
    fn apply(&self, key: &str, mut changes: BTreeMap<String, Option<String>>) -> LegadoResult<()> {
        if let Some(value) = changes.remove("loginHeader") {
            match value.filter(|v| !v.is_empty()) {
                Some(v) => super::source_login_cache::put_login_header(key, &v)?,
                None => super::source_login_cache::remove_login_header(key)?,
            }
        }
        if let Some(value) = changes.remove("loginInfo") {
            match value.filter(|v| !v.is_empty()) {
                Some(v) => super::source_login_cache::put_login_info(key, &v)?,
                None => super::source_login_cache::remove_login_info(key)?,
            }
        }
        if let Some(rate) = changes.get("concurrentRate") {
            super::source_rate_limit::registry().refresh(key, rate.as_deref().unwrap_or(""));
        }
        if !changes.is_empty() {
            crate::db_state::with_database(|db| {
                let repo = CacheRepository::new(db.connection());
                let row = format!("ttsSourceState_{key}");
                let mut data: BTreeMap<String, String> = match repo.get(&row)? {
                    Some(json) => serde_json::from_str(&json)?,
                    None => BTreeMap::new(),
                };
                for (name, value) in changes {
                    if let Some(value) = value {
                        data.insert(name, value);
                    } else {
                        data.remove(&name);
                    }
                }
                repo.put(&row, &serde_json::to_string(&data)?, 0)
            })?;
        }
        Ok(())
    }
}

/// 经典与 V2 登录共用现有脚本协议，配置以数据库当前 ID 为准。
pub fn login(id: i64, operation: &str, payload: &str) -> LegadoResult<String> {
    use legado_parser::JsExecutor;
    let config = config_for(id)?;
    let key = config.source_key();
    let store = Arc::new(DbTtsSourceStore);
    let executor = legado_fetcher::tts_source::TtsJsExecutor::new(&config, store.clone());
    match operation {
        "headers" => Ok(serde_json::to_string(
            &legado_fetcher::tts_source::source_headers(&config, &executor, store.as_ref())?,
        )?),
        "info" | "header" => Ok(store
            .load(&key)?
            .get(if operation == "info" {
                "loginInfo"
            } else {
                "loginHeader"
            })
            .cloned()
            .unwrap_or_default()),
        "putInfo" | "putHeader" => {
            if !payload.is_empty() {
                let value: serde_json::Value = serde_json::from_str(payload)?;
                if !value.is_object() {
                    return Err(LegadoError::Parser("TTS 登录数据必须为 JSON 对象".into()));
                }
                if operation == "putHeader" {
                    let _: std::collections::HashMap<String, String> =
                        serde_json::from_value(value)?;
                }
            }
            store.apply(
                &key,
                BTreeMap::from([(
                    if operation == "putInfo" {
                        "loginInfo"
                    } else {
                        "loginHeader"
                    }
                    .into(),
                    Some(payload.into()),
                )]),
            )?;
            Ok(String::new())
        }
        "ui" => {
            if legado_core::login_ui_v2::is_v2(config.login_ui.as_deref()) {
                let script =
                    legado_core::login_ui_v2::build_login_ui_v2_script(&login_script(&config)?);
                executor
                    .execute_js(&format!(
                        "globalThis.__loginState={};\n{script}",
                        serde_json::to_string(if payload.is_empty() { "{}" } else { payload })?
                    ))
                    .map_err(LegadoError::JsEngine)
            } else if let Some(rule) = config.login_ui.as_deref() {
                if let Some(code) = legado_core::login_ui_v2::extract_inline_js(Some(rule)) {
                    executor
                        .execute_js(&format!("{}\n{code}", login_script(&config)?))
                        .map_err(LegadoError::JsEngine)
                } else {
                    Ok(rule.to_string())
                }
            } else {
                Ok("[]".into())
            }
        }
        "action" => {
            let request: serde_json::Value = serde_json::from_str(payload)?;
            let action = request
                .get("action")
                .and_then(|v| v.as_str())
                .ok_or_else(|| LegadoError::Parser("TTS 登录缺少 action".into()))?;
            let parameter = |name: &str| match &request[name] {
                serde_json::Value::Null => "{}".to_string(),
                serde_json::Value::String(v) => v.clone(),
                other => other.to_string(),
            };
            let script =
                legado_core::login_ui_v2::build_login_action_v2_script(&login_script(&config)?);
            let code = format!(
                "globalThis.__loginAction={};globalThis.__loginState={};globalThis.__loginForm={};\n{script}",
                serde_json::to_string(action)?,
                serde_json::to_string(&parameter("stateJson"))?,
                serde_json::to_string(&parameter("formJson"))?
            );
            let result = executor.execute_js(&code).map_err(LegadoError::JsEngine)?;
            if let Some(info) =
                legado_core::login_ui_v2::parse_action_result(Some(&result)).login_json
            {
                store.apply(&key, BTreeMap::from([("loginInfo".into(), Some(info))]))?;
            }
            Ok(result)
        }
        "eval" => {
            let login_js = config
                .login_url
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(|rule| {
                    legado_core::login_ui_v2::extract_inline_js(Some(rule))
                        .unwrap_or_else(|| rule.to_string())
                })
                .unwrap_or_default();
            #[cfg(feature = "quickjs")]
            let (result, actions) = legado_js::host_api::ui_action_queue::collect_local(|| {
                executor.execute_js(&format!("{login_js}\n{payload}"))
            });
            #[cfg(not(feature = "quickjs"))]
            let (result, actions) = (
                executor.execute_js(payload),
                Vec::<serde_json::Value>::new(),
            );
            Ok(serde_json::json!({"result":result.map_err(LegadoError::JsEngine)?,"actions":actions}).to_string())
        }
        _ => Err(LegadoError::Parser(format!(
            "未知 HTTP TTS 登录操作：{operation}"
        ))),
    }
}

fn login_script(config: &HttpTtsConfig) -> LegadoResult<String> {
    let rule = config
        .login_url
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| LegadoError::JsEngine("TTS 缺少登录脚本".into()))?;
    Ok(legado_core::login_ui_v2::extract_inline_js(Some(rule)).unwrap_or_else(|| rule.to_string()))
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
