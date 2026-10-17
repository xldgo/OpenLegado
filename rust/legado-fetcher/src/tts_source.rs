//! HTTP TTS 的 BaseSource 上下文，使用独立来源身份与可注入持久化。
use super::tts_fetcher::HttpTtsConfig;
use legado_core::{LegadoError, LegadoResult};
use legado_parser::JsExecutor;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

pub trait TtsSourceStore: Send + Sync {
    fn host_resources(&self) -> Arc<legado_js::host_resources::JsHostResources>;
    /// 宿主拥有的变量能力；cache 裸键跨调用存活，临时 flow 每次合成独立。
    fn variables(&self) -> Arc<legado_js::variables::VariableStore>;
    #[cfg(feature = "quickjs")]
    fn http_resources(&self) -> Arc<legado_js::http_resources::HttpResources>;
    fn load(&self, key: &str) -> LegadoResult<BTreeMap<String, String>>;
    fn apply(&self, key: &str, changes: BTreeMap<String, Option<String>>) -> LegadoResult<()>;
    /// 宿主可把最终文件发布纳入任务门控；默认内存宿主直接执行。
    fn publish(&self, commit: &mut dyn FnMut() -> LegadoResult<()>) -> LegadoResult<()> {
        commit()
    }
}

#[derive(Default)]
pub struct MemoryTtsSourceStore {
    values: Mutex<BTreeMap<String, BTreeMap<String, String>>>,
    variables: Arc<legado_js::variables::VariableStore>,
    host: Arc<legado_js::host_resources::JsHostResources>,
    #[cfg(feature = "quickjs")]
    http: Arc<legado_js::http_resources::HttpResources>,
}

impl TtsSourceStore for MemoryTtsSourceStore {
    fn host_resources(&self) -> Arc<legado_js::host_resources::JsHostResources> {
        self.host.clone()
    }
    #[cfg(feature = "quickjs")]
    fn http_resources(&self) -> Arc<legado_js::http_resources::HttpResources> {
        self.http.clone()
    }
    fn variables(&self) -> Arc<legado_js::variables::VariableStore> {
        self.variables.clone()
    }
    fn load(&self, key: &str) -> LegadoResult<BTreeMap<String, String>> {
        Ok(self
            .values
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .get(key)
            .cloned()
            .unwrap_or_default())
    }
    fn apply(&self, key: &str, changes: BTreeMap<String, Option<String>>) -> LegadoResult<()> {
        let mut guard = self.values.lock().unwrap_or_else(|p| p.into_inner());
        let data = guard.entry(key.to_string()).or_default();
        for (key, value) in changes {
            if let Some(value) = value {
                data.insert(key, value);
            } else {
                data.remove(&key);
            }
        }
        Ok(())
    }
}

pub fn default_store() -> Arc<dyn TtsSourceStore> {
    // 便捷入口按调用创建，需跨调用状态的宿主显式注入同一存储。
    Arc::new(MemoryTtsSourceStore::default())
}

pub type TtsResponseLoader = Arc<dyn Fn(&str) -> Result<String, String> + Send + Sync>;

pub struct TtsJsExecutor {
    config: HttpTtsConfig,
    store: Arc<dyn TtsSourceStore>,
    response_loader: Option<TtsResponseLoader>,
    /// 临时 flow 属于本次合成；裸键/cache 由宿主存储跨调用复用。
    variables: legado_js::variables::VariableScope,
}

impl TtsJsExecutor {
    pub fn new(config: &HttpTtsConfig, store: Arc<dyn TtsSourceStore>) -> Self {
        let variables = store.variables().fresh_flow(&config.source_key());
        Self {
            config: config.clone(),
            store,
            response_loader: None,
            variables,
        }
    }
}

impl JsExecutor for TtsJsExecutor {
    fn read_variable(&self, key: &str) -> Option<String> {
        self.variables.get_flow_variable(key)
    }

    fn execute_js(&self, code: &str) -> Result<String, String> {
        self.eval(code).map_err(|error| error.to_string())
    }
}

impl TtsJsExecutor {
    /// 同一合成的响应校验、重试与 URL 重算沿用原句柄。
    pub fn with_variables(mut self, variables: legado_js::variables::VariableScope) -> Self {
        self.variables = variables;
        self
    }

    pub fn variables(&self) -> legado_js::variables::VariableScope {
        self.variables.clone()
    }

    pub fn with_response_loader(mut self, callback: TtsResponseLoader) -> Self {
        self.response_loader = Some(callback);
        self
    }

    #[cfg(feature = "quickjs")]
    fn eval(&self, code: &str) -> LegadoResult<String> {
        use legado_js::JsEngine;
        let key = self.config.source_key();
        let values = self.store.load(&key)?;
        let engine = legado_js::JsResources::default()
            .with_host_resources(self.store.host_resources())
            .with_http_resources(self.store.http_resources())
            .with_variable_scope(self.variables.clone())
            .create_engine(
                legado_js::sandbox::SandboxConfig::default()
                    .with_allow_script_run(true)
                    .with_memory_limit(64 * 1024 * 1024),
            )?;
        legado_js::host_api::current_source::with_current_source_tag(
            &key,
            || -> LegadoResult<String> {
                // 上下文先于 jsLib 安装；库顶层也可以调用 source/getLoginInfo。
                engine.eval(&source_setup(&self.config, &values)?)?;
                if let Some(callback) = &self.response_loader {
                    engine.register_string_callback("__ttsReload", callback.clone())?;
                }
                if let Some(lib) = self
                    .config
                    .js_lib
                    .as_deref()
                    .filter(|s| !s.trim().is_empty())
                {
                    let is_map =
                        legado_js::host_api::jslib_loader::parse_js_lib_url_map(lib).is_some();
                    let resolved = if is_map {
                        legado_js::host_api::jslib_loader::resolve_js_lib_url_map(
                            engine.http_resources(),
                            lib,
                            &key,
                            &|url| {
                                legado_js::host_api::jslib_loader::default_js_lib_fetcher(
                                    engine.http_resources(),
                                    url,
                                )
                            },
                        )
                        .ok_or_else(|| LegadoError::JsEngine("TTS jsLib 下载失败".into()))?
                    } else {
                        lib.to_string()
                    };
                    engine.eval(&resolved)?;
                }
                let code = serde_json::to_string(code)?;
                // completion 原样保存；finally 同步源变量，脚本失败也不丢已完成的登录写入。
                let execution = engine.eval(&format!(
                    "globalThis.__ttsCompletion = eval({code}); JSON.stringify(__ttsCompletion)"
                ));
                let changes = engine.eval("JSON.stringify(__ttsChanges)")?;
                self.store.apply(&key, serde_json::from_str(&changes)?)?;
                execution?;
                engine.eval("typeof __ttsCompletion === 'string' ? __ttsCompletion : (__ttsCompletion === undefined ? 'undefined' : JSON.stringify(__ttsCompletion))")
            },
        )
    }

    #[cfg(not(feature = "quickjs"))]
    fn eval(&self, _code: &str) -> LegadoResult<String> {
        let _ = (&self.config, &self.store);
        Err(LegadoError::JsEngine(
            "此构建未启用 QuickJS，无法执行 TTS 规则".into(),
        ))
    }
}

#[cfg(feature = "quickjs")]
fn source_setup(config: &HttpTtsConfig, values: &BTreeMap<String, String>) -> LegadoResult<String> {
    let config = serde_json::to_string(config)?;
    let values = serde_json::to_string(values)?;
    Ok(format!(
        "globalThis.__ttsConfig={config};globalThis.__ttsData={values};\n{SOURCE_JS}"
    ))
}

#[cfg(feature = "quickjs")]
const SOURCE_JS: &str = r#"
globalThis.__ttsChanges = {};
globalThis.source = Object.assign({}, __ttsConfig);
globalThis.sourceApi = source;
globalThis.baseUrl = 'httpTts:' + source.id;
globalThis.sourceUrl = baseUrl;
globalThis.cookie = {
  getCookie: function(url, key) { return key == null ? java.getCookie(String(url)) : java.getCookie(String(url), String(key)); },
  getKey: function(url, key) { return this.getCookie(url, key); },
  setCookie: function(url, value) { java.setCookie(String(url), String(value)); },
  replaceCookie: function(url, value) { java.replaceCookie(String(url), String(value)); },
  removeCookie: function(url) { java.removeCookie(String(url)); }
};
globalThis.cache = {get: function(k) {return get(String(k)) || null;}, put: function(k,v) {put(String(k),String(v));return v;}, delete: function(k) {removeVariable(String(k));}};
function __ttsRead(k) { return Object.prototype.hasOwnProperty.call(__ttsData,k) ? __ttsData[k] : null; }
function __ttsWrite(k,v) {
  v = v == null ? null : String(v);
  __ttsChanges[k]=v;
  if(v == null) delete __ttsData[k]; else __ttsData[k]=v;
  return v;
}
function __ttsMap(map) {
  Object.defineProperty(map,'get',{value:function(k){for(var key in this)if(key.toLowerCase()===String(k).toLowerCase())return this[key];return null;}});
  Object.defineProperty(map,'put',{value:function(k,v){for(var key in this)if(key.toLowerCase()===String(k).toLowerCase())delete this[key];this[k]=String(v);return v;}});
  Object.defineProperty(map,'putAll',{value:function(other){for(var key in other)this.put(key,other[key]);}});
  return map;
}
source.getHeaderMap=function(includeLogin){
  var rule=String(source.header||'').trim(), code=null, map={};
  if(rule.indexOf('@js:')===0)code=rule.substring(4);
  else if(rule.indexOf('<js>')===0)code=rule.substring(4,rule.lastIndexOf('<'));
  if(rule) {var raw=code===null?rule:eval(code);map=typeof raw==='string'?JSON.parse(raw):raw;}
  map=__ttsMap(map||{});
  if(includeLogin){var login=source.getLoginHeaderMap();if(login)map.putAll(login);}
  return map;
};
source.getKey=function(){return sourceUrl;};
source.getTag=function(){return source.name;};
source.getSource=function(){return source;};
source.get=function(k){return __ttsRead('v_'+k)||'';};
source.put=function(k,v){__ttsWrite('v_'+k,v);return v;};
source.getVariable=function(){return __ttsRead('variable')||'';};
source.setVariable=source.putVariable=function(v){return __ttsWrite('variable',v);};
source.getLoginHeader=function(){return __ttsRead('loginHeader');};
source.getLoginHeaderMap=function(){var v=source.getLoginHeader();return v ? JSON.parse(v):null;};
source.putLoginHeader=function(v){return __ttsWrite('loginHeader',v);};
source.removeLoginHeader=function(){__ttsWrite('loginHeader',null);};
source.getLoginInfo=function(){return __ttsRead('loginInfo');};
source.putLoginInfo=function(v){__ttsWrite('loginInfo',v);return true;};
source.removeLoginInfo=function(){__ttsWrite('loginInfo',null);};
source.getLoginInfoMap=function(){
  var raw=source.getLoginInfo(), data=raw?JSON.parse(raw):{};
  if(!raw && source.loginUi && source.loginUi.trim().charAt(0)==='['){
    JSON.parse(source.loginUi).forEach(function(row){if(row.type!=='button')data[row.name]=row.default||'';});
    if(Object.keys(data).length) source.putLoginInfo(JSON.stringify(data));
  }
  Object.defineProperty(data,'get',{value:function(k){return this[k] == null ? null:this[k];}});
  Object.defineProperty(data,'put',{value:function(k,v){this[k]=String(v);source.putLoginInfo(JSON.stringify(this));return v;}});
  return data;
};
source.login=function(){
  var code=String(source.loginUrl||'').trim();
  if(code.indexOf('@js:')===0)code=code.substring(4);
  if(code.indexOf('<js>')===0)code=code.substring(4,code.lastIndexOf('<'));
  return eval(code+"\nif(typeof login!=='function')throw new Error('未实现 login');login.call(globalThis)");
};
source.putConcurrent=function(v){__ttsWrite('concurrentRate',v);};
['getKey','getTag','getSource','getVariable','setVariable','putVariable','getHeaderMap','getLoginHeader','getLoginHeaderMap','putLoginHeader','removeLoginHeader','getLoginInfo','getLoginInfoMap','putLoginInfo','removeLoginInfo','login','putConcurrent'].forEach(function(k){java[k]=source[k];});
// URL 规则仍消费 parser 的当前 URL 和待提交 Header，不能用 source.url 覆盖。
java.headerMap={put:function(k,v){return java.headerMapPut(String(k),String(v));}};
java.getHeaderMap=function(){return __ttsRequestHeaders;};
java.initUrl=function(){globalThis.__ttsReinit=true;};
java.getResponse=function(){
  if(typeof __ttsReload!=='function')throw new Error('当前脚本不在 TTS 响应窗口');
  var raw=__ttsReload(JSON.stringify({headers:__ttsRequestHeaders,changes:__ttsChanges,reinit:!!globalThis.__ttsReinit}));
  __ttsChanges={};
  globalThis.__ttsReinit=false;
  return __ttsResponse(JSON.parse(raw));
};
Object.defineProperty(java,'url',{get:function(){return java.getCurrentUrl()||baseUrl;},configurable:true});
// 初始化不返回 java 宿主对象，避免结果序列化触发代理上的未知 toJSON。
void 0;
"#;

pub fn merge_headers(
    target: &mut std::collections::HashMap<String, String>,
    incoming: std::collections::HashMap<String, String>,
) {
    for (key, value) in incoming {
        target.retain(|old, _| !old.eq_ignore_ascii_case(&key));
        target.insert(key, value);
    }
}

pub fn source_headers(
    config: &HttpTtsConfig,
    executor: &dyn JsExecutor,
    store: &dyn TtsSourceStore,
) -> LegadoResult<std::collections::HashMap<String, String>> {
    let mut headers = std::collections::HashMap::new();
    if let Some(rule) = config
        .header
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        let json = if let Some(code) = legado_core::login_ui_v2::extract_inline_js(Some(rule)) {
            executor.execute_js(&code).map_err(LegadoError::JsEngine)?
        } else {
            rule.to_string()
        };
        merge_headers(
            &mut headers,
            serde_json::from_str(&json)
                .map_err(|_| LegadoError::Parser("TTS 请求头必须为字符串值 JSON 对象".into()))?,
        );
    }
    if let Some(login) = store.load(&config.source_key())?.get("loginHeader")
        && !login.trim().is_empty()
    {
        merge_headers(
            &mut headers,
            serde_json::from_str(login)
                .map_err(|_| LegadoError::Parser("TTS 登录请求头不是有效 JSON 对象".into()))?,
        );
    }
    Ok(headers)
}

#[cfg(all(test, feature = "quickjs"))]
mod variable_isolation_tests {
    use super::*;

    #[test]
    fn cache_survives_calls_but_temporary_flow_is_request_scoped() {
        let config = HttpTtsConfig::default();
        let store: Arc<dyn TtsSourceStore> = Arc::new(MemoryTtsSourceStore::default());
        let one = TtsJsExecutor::new(&config, store.clone());
        one.execute_js("cache.put('cached','cache-one'); java.__lgStorePut('key','request-one')")
            .unwrap();
        let next = TtsJsExecutor::new(&config, store);
        assert_eq!(next.execute_js("cache.get('cached')").unwrap(), "cache-one");
        assert_eq!(next.execute_js("java.__lgStoreGet('key')").unwrap(), "");
        let retry = TtsJsExecutor::new(&config, Arc::new(MemoryTtsSourceStore::default()))
            .with_variables(one.variables());
        assert_eq!(
            retry.execute_js("java.__lgStoreGet('key')").unwrap(),
            "request-one"
        );
        assert_eq!(one.read_variable("key").as_deref(), Some("request-one"));
        let other = TtsJsExecutor::new(&config, Arc::new(MemoryTtsSourceStore::default()));
        assert_eq!(other.execute_js("cache.get('cached')").unwrap(), "null");
    }

    #[test]
    fn same_tts_source_concurrent_synthesis_keeps_its_own_flow() {
        let barrier = Arc::new(std::sync::Barrier::new(2));
        let store: Arc<dyn TtsSourceStore> = Arc::new(MemoryTtsSourceStore::default());
        let handles: Vec<_> = ["one", "two"]
            .into_iter()
            .map(|value| {
                let barrier = barrier.clone();
                let store = store.clone();
                std::thread::spawn(move || {
                    let executor = TtsJsExecutor::new(&HttpTtsConfig::default(), store);
                    executor
                        .execute_js(&format!("java.__lgStorePut('same-key','{value}')"))
                        .unwrap();
                    barrier.wait();
                    assert_eq!(
                        executor
                            .execute_js("java.__lgStoreGet('same-key')")
                            .unwrap(),
                        value
                    );
                })
            })
            .collect();
        for handle in handles {
            handle.join().unwrap();
        }
    }
}
