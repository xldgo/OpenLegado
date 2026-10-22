//! JS 源执行器
//!
//! 参考 Kotlin 端 `JsSourceEngine.kt`：
//! - 纯 JS 单文件源执行器
//! - 装配书源上下文、绑定对象参数并调用主脚本函数
//! - 共享库保留在缓存层，普通声明与参数在每次独立词法作用域内执行
//! - args 以绑定进 scope，既是函数参数也是环境绑定
//!
//! 未启用 quickjs feature 时仅提供占位结构。

use std::collections::HashMap;

use legado_core::{LegadoError, LegadoResult};

#[cfg(feature = "quickjs")]
use crate::engine::QuickJsEngine;
use crate::engine::{JsEngine, JsValue, SourceCall, StubJsEngine};
#[cfg(feature = "quickjs")]
use crate::engine_pool::EnginePool;
#[cfg(feature = "quickjs")]
use crate::sandbox::SandboxConfig;
use crate::scope::SharedScopeManager;
#[cfg(feature = "quickjs")]
use std::sync::{Arc, Mutex};

/// JS 源执行器配置
#[derive(Debug, Clone)]
pub struct JsSourceConfig {
    /// 用于装配宿主上下文的完整书源，不作为脚本变量反写。
    source: legado_core::models::BookSource,
    /// JS 源的 URL（书源标识）
    pub source_url: String,
    /// 主 JS 脚本内容
    pub main_js: String,
    /// 可选的 jsLib（共享库代码）
    pub js_lib: Option<String>,
    /// 可选的 CryptoJS 注入开关
    pub inject_crypto: bool,
}

impl JsSourceConfig {
    pub fn new(source_url: String, main_js: String) -> Self {
        Self {
            source: legado_core::models::BookSource {
                book_source_url: source_url.clone(),
                main_js: Some(main_js.clone()),
                ..Default::default()
            },
            source_url,
            main_js,
            js_lib: None,
            inject_crypto: false,
        }
    }

    pub fn with_js_lib(mut self, js_lib: String) -> Self {
        self.source.js_lib = Some(js_lib.clone());
        self.js_lib = Some(js_lib);
        self
    }

    pub fn with_crypto(mut self, inject: bool) -> Self {
        self.inject_crypto = inject;
        self
    }

    /// 正式业务入口保留完整书源身份与设置，不从主脚本配置反推。
    pub fn from_source(source: &legado_core::models::BookSource) -> Self {
        Self {
            source: source.clone(),
            source_url: source.book_source_url.clone(),
            main_js: source.main_js.clone().unwrap_or_default(),
            js_lib: source.js_lib.clone(),
            inject_crypto: false,
        }
    }

    fn setup_script(&self) -> LegadoResult<String> {
        let mut source = self.source.clone();
        source.book_source_url = self.source_url.clone();
        source.main_js = Some(self.main_js.clone());
        source.js_lib = self.js_lib.clone();
        crate::source_setup::book_source_js_setup_script(&source, &HashMap::new(), None, None)
    }
}

/// 函数调用结果
#[derive(Debug, Clone)]
pub struct CallResult {
    /// 函数是否存在
    pub exists: bool,
    /// 函数返回值（null/undefined → None）
    pub value: Option<String>,
}

impl CallResult {
    pub fn not_found() -> Self {
        Self {
            exists: false,
            value: None,
        }
    }

    pub fn success(value: Option<String>) -> Self {
        Self {
            exists: true,
            value,
        }
    }
}

/// JS 源执行引擎
///
/// 管理一个 JS 源的完整执行生命周期：
/// 1. 复用共享库与宿主资源
/// 2. 建立单次调用作用域（注入绑定 + 共享原型）
/// 3. 执行函数调用
/// 4. 归一化返回值
///
/// 支持两种引擎持有方式：
/// - 直接持有 `Box<dyn JsEngine>`（stub / with_engine）
/// - 通过 `EnginePool` 按 source_tag 共享引擎（池化模式）
pub struct JsSourceEngine {
    #[cfg(feature = "quickjs")]
    cancellation: Option<Arc<dyn crate::cancellation::JsCancellation>>,
    /// 源配置
    config: JsSourceConfig,
    #[cfg(feature = "quickjs")]
    variables: Option<crate::variables::VariableScope>,
    /// JS 引擎实例（非池化模式）
    engine: Option<Box<dyn JsEngine>>,
    /// 引擎池（池化模式，启用 quickjs 时可用）
    #[cfg(feature = "quickjs")]
    #[allow(dead_code)]
    engine_pool: Option<Arc<EnginePool>>,
    /// 池化模式下缓存的引擎引用（避免每次调用都查池）
    #[cfg(feature = "quickjs")]
    pooled_engine: Option<Arc<Mutex<QuickJsEngine>>>,
    /// 书源标识（用于 Cookie/变量隔离，后续由 HostEnv 承载）
    source_tag: Option<String>,
    /// 共享作用域管理器（外部注入，多源共享）
    scope_manager: Option<SharedScopeManager>,
}

impl JsSourceEngine {
    /// 使用占位引擎创建（未启用 quickjs 时）
    pub fn new_stub(config: JsSourceConfig) -> Self {
        let source_tag = Some(config.source_url.clone());
        Self {
            #[cfg(feature = "quickjs")]
            variables: None,
            engine: Some(Box::new(StubJsEngine::new())),
            #[cfg(feature = "quickjs")]
            engine_pool: None,
            #[cfg(feature = "quickjs")]
            pooled_engine: None,
            config,
            source_tag,
            scope_manager: None,
            #[cfg(feature = "quickjs")]
            cancellation: None,
        }
    }

    /// 使用 QuickJS 真实引擎创建（启用 quickjs feature 时）
    #[cfg(feature = "quickjs")]
    pub fn new_quickjs(config: JsSourceConfig) -> Result<Self, legado_core::LegadoError> {
        Self::new_quickjs_with_resources(config, &crate::JsResources::default())
    }

    /// 使用显式资源，供同一引擎的多个宿主与连续调用共享 VM 缓存。
    #[cfg(feature = "quickjs")]
    pub fn new_quickjs_with_resources(
        config: JsSourceConfig,
        resources: &crate::JsResources,
    ) -> Result<Self, legado_core::LegadoError> {
        let source_tag = Some(config.source_url.clone());
        let cache_key = format!("mainjs:{}:{}", config.source_url, config.main_js);
        let setup_script = config.setup_script()?;
        // 库初始化仍绑定本源身份；mainJs留到带本次参数的调用作用域执行。
        // 缓存身份包含完整setup，配置变更时沿用既有失效检查。
        let cached =
            crate::host_api::current_source::with_current_source_tag(&config.source_url, || {
                resources.engine_cache().get_or_create_with_resources(
                    &cache_key,
                    config.js_lib.as_deref(),
                    Some(&setup_script),
                    None,
                    resources,
                )
            })?;
        // 初始化错误绑定当前缓存结果；台账只用于诊断，不作为异常数据源。
        if let Some(reason) = cached.js_lib_error {
            return Err(LegadoError::JsEngine(format!("jsLib 求值失败: {reason}")));
        }
        Ok(Self {
            variables: resources.variable_scope().cloned(),
            engine: None,
            engine_pool: None,
            pooled_engine: Some(cached.engine),
            config,
            source_tag,
            scope_manager: None,
            cancellation: resources.cancellation().cloned(),
        })
    }

    /// 使用指定沙箱配置的 QuickJS 引擎创建
    #[cfg(feature = "quickjs")]
    pub fn new_quickjs_with_sandbox(
        config: JsSourceConfig,
        sandbox_config: SandboxConfig,
    ) -> Result<Self, legado_core::LegadoError> {
        let engine = QuickJsEngine::new(sandbox_config)?;
        let source_tag = Some(config.source_url.clone());
        Ok(Self {
            #[cfg(feature = "quickjs")]
            variables: None,
            engine: Some(Box::new(engine)),
            engine_pool: None,
            pooled_engine: None,
            config,
            source_tag,
            scope_manager: None,
            #[cfg(feature = "quickjs")]
            cancellation: None,
        })
    }

    /// 使用引擎池创建（池化模式）
    ///
    /// 从共享引擎池中按 source_tag 获取或创建引擎，避免每源重复创建。
    /// 引擎创建失败时返回 `Err`（遵循 FFI 禁 panic 规范）。
    #[cfg(feature = "quickjs")]
    pub fn new_with_pool(
        config: JsSourceConfig,
        pool: Arc<EnginePool>,
    ) -> Result<Self, legado_core::LegadoError> {
        let source_tag = config.source_url.clone();
        let pooled_engine = pool.get_or_create(&source_tag)?;
        Ok(Self {
            #[cfg(feature = "quickjs")]
            variables: None,
            engine: None,
            engine_pool: Some(pool),
            pooled_engine: Some(pooled_engine),
            source_tag: Some(source_tag),
            config,
            scope_manager: None,
            #[cfg(feature = "quickjs")]
            cancellation: None,
        })
    }

    /// 使用指定 JS 引擎创建
    pub fn with_engine(config: JsSourceConfig, engine: Box<dyn JsEngine>) -> Self {
        let source_tag = Some(config.source_url.clone());
        Self {
            #[cfg(feature = "quickjs")]
            variables: None,
            engine: Some(engine),
            #[cfg(feature = "quickjs")]
            engine_pool: None,
            #[cfg(feature = "quickjs")]
            pooled_engine: None,
            config,
            source_tag,
            scope_manager: None,
            #[cfg(feature = "quickjs")]
            cancellation: None,
        }
    }

    /// 设置共享作用域管理器
    pub fn set_scope_manager(&mut self, manager: SharedScopeManager) {
        self.scope_manager = Some(manager);
    }

    /// 获取源 URL
    pub fn source_url(&self) -> &str {
        &self.config.source_url
    }

    /// 获取书源标识（用于 Cookie/变量隔离）
    pub fn source_tag(&self) -> Option<&str> {
        self.source_tag.as_deref()
    }

    /// 调用 JS 函数并返回结果
    ///
    /// 参考 `JsSourceEngine.callFunction()`
    ///
    /// 流程：
    /// 1. 构建作用域（绑定参数 + 主脚本 eval）
    /// 2. 构造调用表达式 `funcName(arg1, arg2, ...)`
    /// 3. eval 调用表达式
    /// 4. 归一化返回值
    pub fn call_function(
        &mut self,
        name: &str,
        args: &[(&str, JsValue)],
    ) -> LegadoResult<Option<String>> {
        self.call(name, args, false).map(|result| result.value)
    }

    fn call(
        &mut self,
        name: &str,
        args: &[(&str, JsValue)],
        optional: bool,
    ) -> LegadoResult<CallResult> {
        #[cfg(feature = "quickjs")]
        let _execution = crate::cancellation::Scope::enter(self.cancellation.clone());
        crate::cancellation::check()?;
        // 绑定当前书源上下文（供 getVerificationCode 等宿主钩子识别书源，
        // 对齐 Kotlin JsExtensions.getSource()），结束后恢复原值
        let tag = self.config.source_url.clone();
        crate::host_api::current_source::with_current_source_tag(&tag, || {
            self.call_function_inner(name, args, optional)
        })
    }

    fn call_function_inner(
        &mut self,
        name: &str,
        args: &[(&str, JsValue)],
        optional: bool,
    ) -> LegadoResult<CallResult> {
        if self.config.main_js.is_empty() {
            return Err(LegadoError::JsEngine("mainJs 为空，非 JS 源".to_string()));
        }

        let setup = self.config.setup_script()?;
        let call = SourceCall {
            setup: &setup,
            main_js: &self.config.main_js,
            name,
            args,
            optional,
        };
        #[cfg(feature = "quickjs")]
        if let Some(pooled) = &self.pooled_engine {
            return crate::cancellation::lock(pooled)?.call_source(&call, self.variables.as_ref());
        }
        let engine = self
            .engine
            .as_ref()
            .ok_or_else(|| LegadoError::JsEngine("引擎未初始化".into()))?;
        #[cfg(feature = "quickjs")]
        let variables = self.variables.as_ref();
        #[cfg(not(feature = "quickjs"))]
        let variables = None;
        engine.call_source(&call, variables)
    }

    /// 调用可选函数：函数缺失时返回 CallResult::not_found() 而非报错
    ///
    /// 参考 `JsSourceEngine.callFunctionIfExists()`
    pub fn call_function_if_exists(
        &mut self,
        name: &str,
        args: &[(&str, JsValue)],
    ) -> LegadoResult<CallResult> {
        self.call(name, args, true)
    }

    /// 旧MCP文本入口的归一化；主脚本类型化结果不得调用此方法。
    ///
    /// 参考 `JsSourceEngine.normalizeJsResult()`：
    /// - "null" / "undefined" → None
    /// - 其他字符串 → Some(String)
    pub fn normalize_result(result: &str) -> Option<String> {
        let trimmed = result.trim();
        if trimmed.is_empty() || trimmed == "null" || trimmed == "undefined" {
            None
        } else {
            Some(trimmed.to_string())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[cfg(feature = "quickjs")]
    use std::sync::Arc;

    #[cfg(feature = "quickjs")]
    #[test]
    fn cached_main_js_uses_current_flow_for_saved_native_functions() {
        let resources = crate::JsResources::default();
        let one = resources.for_flow("one");
        let two = resources.for_flow("two");
        one.variable_scope()
            .unwrap()
            .put_flow_variable("key", "a")
            .unwrap();
        two.variable_scope()
            .unwrap()
            .put_flow_variable("key", "b")
            .unwrap();
        let config = JsSourceConfig::new("source".into(),
            "var savedRead=java.__lgStoreGet; var savedWrite=java.__lgStorePut; function step(){var value=savedRead('key');savedWrite('key',value+'!');return value;}".into());
        let mut a = JsSourceEngine::new_quickjs_with_resources(config.clone(), &one).unwrap();
        let mut b = JsSourceEngine::new_quickjs_with_resources(config, &two).unwrap();
        assert_eq!(a.call_function("step", &[]).unwrap().as_deref(), Some("a"));
        assert_eq!(b.call_function("step", &[]).unwrap().as_deref(), Some("b"));
        assert_eq!(a.call_function("step", &[]).unwrap().as_deref(), Some("a!"));
    }

    #[test]
    fn test_call_function_empty_main_js_error() {
        let config = JsSourceConfig::new("http://test.com".to_string(), "".to_string());
        let mut se = JsSourceEngine::new_stub(config);
        let result = se.call_function("foo", &[]);
        assert!(result.is_err());
    }

    /// 主脚本每次求值才发起顶层请求，使用当前资源中请求域的Cookie。
    #[cfg(feature = "quickjs")]
    #[test]
    fn main_js_top_level_request_uses_current_cookie_on_each_call() {
        use std::io::{Read, Write};
        use std::sync::Mutex;

        // 主脚本的每次执行都读取当前Cookie，不捕获构造时快照。
        let resources = crate::JsResources::default();

        // 回环 cookie 记录服务器：记录收到的 Cookie 请求头（忽略请求 body）
        let seen: Arc<Mutex<Option<String>>> = Arc::new(Mutex::new(None));
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind 127.0.0.1:0");
        let addr = listener.local_addr().expect("local_addr");
        let seen_srv = seen.clone();
        std::thread::spawn(move || {
            for stream in listener.incoming().take(2) {
                let Ok(mut sock) = stream else { continue };
                let _ = sock.set_read_timeout(Some(std::time::Duration::from_secs(10)));
                let mut head: Vec<u8> = Vec::new();
                let mut byte = [0u8; 1];
                while !head.ends_with(b"\r\n\r\n") {
                    if sock.read_exact(&mut byte).is_err() {
                        break;
                    }
                    head.push(byte[0]);
                    if head.len() > 65_536 {
                        break;
                    }
                }
                let head_str = String::from_utf8_lossy(&head);
                let cookie = head_str.lines().find_map(|line| {
                    let (name, value) = line.split_once(':')?;
                    name.trim()
                        .eq_ignore_ascii_case("cookie")
                        .then(|| value.trim().to_string())
                });
                *seen_srv.lock().unwrap() = cookie;
                let body = r#"{"ok":1}"#;
                let resp = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    body.len(),
                    body
                );
                let _ = sock.write_all(resp.as_bytes());
            }
        });

        // 书源上下文仍传入（引擎分桶 / 缓存键），cookie 取用不再按 tag
        const TAG: &str = "https://p219-mainjs.example.com/";
        // 上游同步：cookie 键 = 请求 URL 归一域名键（回环 IP 自键 127.0.0.1）
        let echo_url = format!("http://{addr}/echo");
        resources.http_resources().cookies().clear(&echo_url);
        resources
            .http_resources()
            .set_cookie(&echo_url, "p219_mainjs_token=mainjs-val-4a7b");

        // mainJs 顶层 `java.ajax`（入参为 JSON 字符串——java.ajax 桥接签名
        // 为 (options: String)，形态与 network.rs p219 用例一致）
        let main_js = format!(
            r#"java.ajax('{{"url":"{echo_url}"}}');
function search(q) {{ return q; }}"#
        );
        let config = JsSourceConfig::new(TAG.to_string(), main_js);
        let mut engine = JsSourceEngine::new_quickjs_with_resources(config, &resources)
            .expect("new_quickjs 构造");
        assert!(seen.lock().unwrap().is_none(), "构造不应执行主脚本请求");
        engine
            .call_function("search", &[("q", JsValue::from("first"))])
            .unwrap();

        let got = seen.lock().unwrap().clone();
        assert!(
            got.as_deref()
                .unwrap_or_default()
                .contains("p219_mainjs_token=mainjs-val-4a7b"),
            "mainJs 顶层ajax必须携带请求域Cookie，实际Cookie头: {got:?}"
        );
        resources
            .http_resources()
            .set_cookie(&echo_url, "p219_mainjs_token=second");
        engine
            .call_function("search", &[("q", JsValue::from("second"))])
            .unwrap();
        assert!(
            seen.lock()
                .unwrap()
                .as_deref()
                .unwrap()
                .contains("p219_mainjs_token=second")
        );
        resources.http_resources().cookies().clear(&echo_url);
    }

    /// 顶层代码必须读取本次参数，不能复用首次求值结果。
    #[cfg(feature = "quickjs")]
    #[test]
    fn main_js_top_level_can_read_current_call_arguments() {
        let config = JsSourceConfig::new(
            "w2-mainjs-retry".to_string(),
            "var __top = book.name;\nfunction search(){ return __top; }".to_string(),
        );
        let mut engine = JsSourceEngine::new_quickjs(config).expect("jsLib 为空，不受 W2 上抛影响");
        let out = engine
            .call_function(
                "search",
                &[(
                    "book",
                    JsValue::Object(vec![("name".into(), JsValue::from("w2-mainjs-retry"))]),
                )],
            )
            .expect("首次调用应带 bindings 重评 mainJs");
        assert_eq!(out.as_deref(), Some("w2-mainjs-retry"));
        assert_eq!(
            engine
                .call_function(
                    "search",
                    &[(
                        "book",
                        JsValue::Object(vec![("name".into(), JsValue::from("next-book"))])
                    )]
                )
                .unwrap()
                .as_deref(),
            Some("next-book")
        );
    }
}
