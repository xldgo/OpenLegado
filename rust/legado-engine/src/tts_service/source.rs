//! HTTP TTS 来源配置、状态写回与登录；仅持有所属实例能力。
use legado_core::{LegadoError, LegadoResult};
use legado_db::{CacheRepository, HttpTtsRepository};
use legado_fetcher::{HttpTtsConfig, tts_source::TtsSourceStore};
use std::collections::BTreeMap;
use std::sync::Arc;

pub fn config_for_storage(storage: &crate::StorageContext, id: i64) -> LegadoResult<HttpTtsConfig> {
    let entity = storage
        .with_database(|db| HttpTtsRepository::new(db.connection()).find_by_id(id))?
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

pub struct DbTtsSourceStore {
    storage: crate::StorageContext,
    media: Arc<crate::MediaState>,
    resources: Arc<legado_js::JsResources>,
    login: Arc<crate::SourceLoginCache>,
    rates: Arc<legado_fetcher::rate_limit::RateLimiterRegistry>,
    task: Option<crate::TaskHandle>,
    cancellation: Option<legado_fetcher::tts_control::TtsCancellation>,
}
impl DbTtsSourceStore {
    pub(super) fn for_resources(engine: &super::TtsResources) -> Self {
        Self {
            storage: engine.storage.clone(),
            media: engine.media.clone(),
            resources: engine.js.clone(),
            login: engine.login.clone(),
            rates: engine.rates.clone(),
            task: None,
            cancellation: None,
        }
    }
    pub(crate) fn with_task(
        mut self,
        task: crate::TaskHandle,
        cancellation: Option<legado_fetcher::tts_control::TtsCancellation>,
    ) -> Self {
        self.task = Some(task);
        self.cancellation = cancellation;
        self
    }
    fn check(&self) -> LegadoResult<()> {
        if let Some(cancellation) = &self.cancellation {
            cancellation.check()?;
        }
        if self.task.as_ref().is_some_and(|task| task.is_cancelled()) {
            return Err(LegadoError::Ffi("TTS_CANCELLED".into()));
        }
        Ok(())
    }
    fn active<T>(&self, commit: impl FnOnce() -> LegadoResult<T>) -> LegadoResult<T> {
        self.check()?;
        match &self.task {
            Some(task) => task
                .with_active(|| {
                    self.check()?;
                    commit()
                })
                .unwrap_or_else(|| Err(LegadoError::Ffi("TTS_CANCELLED".into()))),
            None => commit(),
        }
    }
}
impl TtsSourceStore for DbTtsSourceStore {
    fn host_resources(&self) -> Arc<legado_js::host_resources::JsHostResources> {
        self.resources.host_resources().clone()
    }
    #[cfg(feature = "quickjs")]
    fn http_resources(&self) -> Arc<legado_js::http_resources::HttpResources> {
        self.resources.http_resources().clone()
    }
    fn variables(&self) -> Arc<legado_js::variables::VariableStore> {
        self.resources.variables()
    }
    fn load(&self, key: &str) -> LegadoResult<BTreeMap<String, String>> {
        self.check()?;
        let mut values: BTreeMap<String, String> = self.storage.with_database(|db| {
            let value =
                CacheRepository::new(db.connection()).get(&format!("ttsSourceState_{key}"))?;
            Ok(match value {
                Some(json) => serde_json::from_str(&json)?,
                None => BTreeMap::new(),
            })
        })?;
        if let Some(value) = self.login.get_login_header(key) {
            values.insert("loginHeader".into(), value);
        }
        if let Some(value) = self.login.get_login_info(key) {
            values.insert("loginInfo".into(), value);
        }
        Ok(values)
    }
    fn publish(&self, commit: &mut dyn FnMut() -> LegadoResult<()>) -> LegadoResult<()> {
        self.active(commit)
    }
    fn apply(&self, key: &str, changes: BTreeMap<String, Option<String>>) -> LegadoResult<()> {
        self.media
            .tts_writes
            .with_domain(key, || self.active(|| self.apply_changes(key, changes)))
    }
}

impl DbTtsSourceStore {
    fn apply_changes(
        &self,
        key: &str,
        mut changes: BTreeMap<String, Option<String>>,
    ) -> LegadoResult<()> {
        if let Some(value) = changes.remove("loginHeader") {
            match value.filter(|v| !v.is_empty()) {
                Some(v) => self.login.put_login_header(key, &v),
                None => self.login.remove_login_header(key),
            }
        }
        if let Some(value) = changes.remove("loginInfo") {
            match value.filter(|v| !v.is_empty()) {
                Some(v) => self.login.put_login_info(key, &v),
                None => self.login.remove_login_info(key),
            }
        }
        if let Some(rate) = changes.get("concurrentRate") {
            self.rates.refresh(key, rate.as_deref().unwrap_or(""));
        }
        if !changes.is_empty() {
            self.storage.with_database(|db| {
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
pub(super) fn login(
    resources: &super::TtsResources,
    id: i64,
    operation: &str,
    payload: &str,
) -> LegadoResult<String> {
    let task = resources
        .tasks
        .begin()
        .map_err(|e| LegadoError::Ffi(e.to_string()))?;
    let _guard = task.guard();
    let config = config_for_storage(&resources.storage, id)?;
    let store = Arc::new(DbTtsSourceStore::for_resources(resources).with_task(task.clone(), None));
    let result = login_with_store(&config, operation, payload, store);
    task.with_active(|| result)
        .unwrap_or_else(|| Err(LegadoError::Ffi("TTS_CANCELLED".into())))
}

fn login_with_store(
    config: &HttpTtsConfig,
    operation: &str,
    payload: &str,
    store: Arc<DbTtsSourceStore>,
) -> LegadoResult<String> {
    use legado_parser::JsExecutor;
    let key = config.source_key();
    let executor = legado_fetcher::tts_source::TtsJsExecutor::new(config, store.clone());
    match operation {
        "headers" => Ok(serde_json::to_string(
            &legado_fetcher::tts_source::source_headers(config, &executor, store.as_ref())?,
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
                    legado_core::login_ui_v2::build_login_ui_v2_script(&login_script(config)?);
                executor
                    .execute_js(&format!(
                        "globalThis.__loginState={};\n{script}",
                        serde_json::to_string(if payload.is_empty() { "{}" } else { payload })?
                    ))
                    .map_err(LegadoError::JsEngine)
            } else if let Some(rule) = config.login_ui.as_deref() {
                if let Some(code) = legado_core::login_ui_v2::extract_inline_js(Some(rule)) {
                    executor
                        .execute_js(&format!("{}\n{code}", login_script(config)?))
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
                legado_core::login_ui_v2::build_login_action_v2_script(&login_script(config)?);
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
            #[cfg(feature = "quickjs")]
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

#[cfg(test)]
mod instance_tests {
    use super::*;
    #[test]
    fn source_state_and_login_commit_only_to_original_instance_and_reject_closed_task() {
        let first = crate::EngineContext::in_memory().unwrap();
        let second = crate::EngineContext::in_memory().unwrap();
        let task = first.tasks().begin().unwrap();
        let store = DbTtsSourceStore::for_resources(&first.tts_service().resources)
            .with_task(task.clone(), None);
        store
            .apply(
                "same",
                BTreeMap::from([
                    (
                        "loginHeader".into(),
                        Some(r#"{"Authorization":"first"}"#.into()),
                    ),
                    ("variable".into(), Some("first".into())),
                ]),
            )
            .unwrap();
        let other = DbTtsSourceStore::for_resources(&second.tts_service().resources);
        assert!(other.load("same").unwrap().is_empty());
        assert!(
            second
                .source_login_cache()
                .get_login_header("same")
                .is_none()
        );
        assert_eq!(store.load("same").unwrap()["variable"], "first");
        task.cancel();
        assert!(
            store
                .apply(
                    "same",
                    BTreeMap::from([("variable".into(), Some("late".into()))])
                )
                .is_err()
        );
        let original = DbTtsSourceStore::for_resources(&first.tts_service().resources);
        assert_eq!(original.load("same").unwrap()["variable"], "first");
        assert!(
            store
                .publish(&mut || panic!("关闭任务不得发布音频"))
                .is_err()
        );
    }
}
