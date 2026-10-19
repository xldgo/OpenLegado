//! 页内能力复用所属引擎数据，执行脚本不重入正在等待平台的父VM。
use legado_core::{
    LegadoError, LegadoResult,
    webview_channel::{WebViewLease, WebViewRequest},
};
use legado_js::{JsResources, source_login::SourceLoginKind};
use serde_json::Value;
use std::sync::Arc;

#[derive(Clone, Copy, Debug)]
pub enum PageTarget {
    Source,
    Cache,
    Java,
}
pub struct PageCall {
    pub target: PageTarget,
    pub method: String,
    pub args: Vec<Option<String>>,
}
pub struct WebViewPageService {
    pub js: Arc<JsResources>,
    pub storage: Option<crate::StorageContext>,
}
#[cfg(feature = "quickjs")]
struct PageCancellation(WebViewLease);
#[cfg(feature = "quickjs")]
impl legado_js::cancellation::JsCancellation for PageCancellation {
    fn is_cancelled(&self) -> bool {
        !self.0.is_active()
    }
    fn cancelled(&self) -> legado_js::cancellation::CancelWait<'_> {
        Box::pin(self.0.cancelled())
    }
}
fn bad(message: &str) -> LegadoError {
    LegadoError::JsEngine(message.into())
}
struct Args<'a>(&'a [Option<String>]);
impl Args<'_> {
    fn count(&self, min: usize, max: usize) -> LegadoResult<()> {
        if (min..=max).contains(&self.0.len()) {
            Ok(())
        } else {
            Err(bad("页内调用参数数量不正确"))
        }
    }
    fn text(&self, index: usize) -> LegadoResult<&str> {
        self.optional(index)
            .ok_or_else(|| bad("页内调用缺少字符串参数"))
    }
    fn optional(&self, index: usize) -> Option<&str> {
        self.0.get(index).and_then(Option::as_deref)
    }
    fn boolean(&self, index: usize) -> LegadoResult<bool> {
        match self.optional(index) {
            None | Some("false") => Ok(false),
            Some("true") => Ok(true),
            _ => Err(bad("页内调用布尔参数不正确")),
        }
    }
}
impl WebViewPageService {
    pub fn call(
        &self,
        request: &WebViewRequest,
        lease: WebViewLease,
        call: PageCall,
    ) -> LegadoResult<Value> {
        lease.check()?;
        let args = Args(&call.args);
        let method = call.method.as_str();
        let source = request.source_key.as_str();
        let variables = self.js.variables();
        let target = if matches!(call.target, PageTarget::Java)
            && ((method == "get" && call.args.len() == 1) || method == "put")
        {
            PageTarget::Source
        } else {
            call.target
        };
        match target {
            PageTarget::Cache => {
                let cache = &self.js.host_resources().cache;
                match method {
                    "get" => {
                        args.count(1, 2)?;
                        Ok(cache.get(args.text(0)?, args.boolean(1)?).into())
                    }
                    "getFromMemory" => {
                        args.count(1, 1)?;
                        Ok(cache.get_from_memory(args.text(0)?).into())
                    }
                    "getFile" => {
                        args.count(1, 1)?;
                        Ok(cache.get_file(args.text(0)?).into())
                    }
                    "put" => {
                        args.count(2, 3)?;
                        let ttl = args
                            .optional(2)
                            .unwrap_or("0")
                            .parse::<i32>()
                            .map_err(|_| bad("缓存期限必须是整数秒"))?;
                        lease.check()?;
                        cache.put(args.text(0)?, args.text(1)?, ttl.into());
                        Ok(Value::Null)
                    }
                    "putMemory" => {
                        args.count(2, 2)?;
                        lease.check()?;
                        cache.put_memory(args.text(0)?, args.text(1)?);
                        Ok(Value::Null)
                    }
                    "deleteMemory" => {
                        args.count(1, 1)?;
                        lease.check()?;
                        cache.delete_memory(args.text(0)?);
                        Ok(Value::Null)
                    }
                    "delete" => {
                        args.count(1, 1)?;
                        lease.check()?;
                        cache.delete(args.text(0)?);
                        Ok(Value::Null)
                    }
                    "putFile" => {
                        args.count(2, 3)?;
                        let ttl = args
                            .optional(2)
                            .unwrap_or("0")
                            .parse::<i32>()
                            .map_err(|_| bad("缓存期限必须是整数秒"))?;
                        lease.check()?;
                        cache.put_file(args.text(0)?, args.text(1)?, ttl);
                        Ok(Value::Null)
                    }
                    _ => Err(bad("未支持的后台cache方法")),
                }
            }
            PageTarget::Source => {
                if source.is_empty() {
                    return Err(bad("该WebView请求没有来源上下文"));
                }
                let key = match method {
                    "get" | "put" => {
                        args.count(
                            if method == "put" { 2 } else { 1 },
                            if method == "put" { 2 } else { 1 },
                        )?;
                        format!("v_{source}_{}", args.text(0)?)
                    }
                    "getVariable" | "putVariable" => format!("sourceVariable_{source}"),
                    _ => String::new(),
                };
                match method {
                    "getKey" => {
                        args.count(0, 0)?;
                        Ok(source.into())
                    }
                    "get" | "getVariable" => {
                        if method == "getVariable" {
                            args.count(0, 0)?;
                        }
                        Ok(variables
                            .get_variable(&key)
                            .map_err(|e| bad(&e))?
                            .unwrap_or_default()
                            .into())
                    }
                    "put" => {
                        lease.check()?;
                        let value = args.text(1)?;
                        variables.set_variable(&key, value).map_err(|e| bad(&e))?;
                        Ok(value.into())
                    }
                    "putVariable" => {
                        args.count(1, 1)?;
                        lease.check()?;
                        match args.optional(0) {
                            Some(value) => {
                                variables.set_variable(&key, value).map_err(|e| bad(&e))?
                            }
                            None => {
                                variables.remove_variable(&key).map_err(|e| bad(&e))?;
                            }
                        }
                        Ok(Value::Null)
                    }
                    "getLoginHeader" | "getLoginInfo" => {
                        args.count(0, 0)?;
                        let kind = if method == "getLoginHeader" {
                            SourceLoginKind::Header
                        } else {
                            SourceLoginKind::Info
                        };
                        let store = self
                            .js
                            .source_login_store()
                            .ok_or_else(|| bad("来源登录服务未初始化"))?;
                        Ok(store.get(kind, source).into())
                    }
                    "putLoginInfo" => {
                        args.count(1, 1)?;
                        let value = args.text(0)?;
                        let store = self
                            .js
                            .source_login_store()
                            .ok_or_else(|| bad("来源登录服务未初始化"))?;
                        lease.check()?;
                        store.put(SourceLoginKind::Info, source, value);
                        Ok(true.into())
                    }
                    "removeLoginInfo" => {
                        args.count(0, 0)?;
                        let store = self
                            .js
                            .source_login_store()
                            .ok_or_else(|| bad("来源登录服务未初始化"))?;
                        lease.check()?;
                        store.remove(SourceLoginKind::Info, source);
                        Ok(Value::Null)
                    }
                    "login" => {
                        args.count(0, 0)?;
                        self.execute(request, lease, &call)
                    }
                    _ => Err(bad("未支持的后台source方法")),
                }
            }
            PageTarget::Java => self.execute(request, lease, &call),
        }
    }
    #[cfg(not(feature = "quickjs"))]
    fn execute(
        &self,
        _request: &WebViewRequest,
        _lease: WebViewLease,
        _call: &PageCall,
    ) -> LegadoResult<Value> {
        Err(bad("当前构建未启用页内脚本执行能力"))
    }
    #[cfg(feature = "quickjs")]
    fn execute(
        &self,
        request: &WebViewRequest,
        lease: WebViewLease,
        call: &PageCall,
    ) -> LegadoResult<Value> {
        use legado_parser::JsExecutor;
        let args = Args(&call.args);
        let method = call.method.as_str();
        // 动态分派先验方法与形状；非法调用不装配来源脚本或创建VM。
        match (call.target, method) {
            (PageTarget::Source, "login") => args.count(0, 0)?,
            (PageTarget::Java, "ajax") => {
                args.count(1, 2)?;
                args.text(0)?;
            }
            (PageTarget::Java, "connect") => {
                args.count(1, 3)?;
                args.text(0)?;
            }
            (PageTarget::Java, "getString" | "getStringList") => {
                args.count(1, 3)?;
                args.boolean(2)?;
            }
            (PageTarget::Java, "get" | "head") => {
                args.count(2, 3)?;
                args.text(0)?;
                args.text(1)?;
            }
            (PageTarget::Java, "post") => {
                args.count(3, 4)?;
                args.text(0)?;
                args.text(1)?;
                args.text(2)?;
            }
            _ => return Err(bad("未支持的后台java方法")),
        }
        let resources = Arc::new(self.js.isolated_execution())
            .with_cancellation(Arc::new(PageCancellation(lease)));
        let config = if request.source_key.is_empty() {
            None
        } else {
            self.storage
                .as_ref()
                .ok_or_else(|| bad("数据库尚未初始化"))?
                .with_database(|db| {
                    legado_db::BookSourceRepository::new(db.connection())
                        .find_by_url(&request.source_key)
                })?
        };
        let source_config = config
            .as_ref()
            .map(|s| {
                legado_fetcher::source_setup::book_source_js_setup_script(
                    s,
                    &Default::default(),
                    None,
                    None,
                )
            })
            .transpose()?;
        let executor = Arc::new(
            legado_js::executor::QuickJsExecutor::new(&request.source_key)
                .with_resources(resources)
                .with_setup_script(source_config)
                .with_js_lib(config.as_ref().and_then(|c| c.js_lib.clone())),
        );
        if matches!(call.target, PageTarget::Java)
            && matches!(method, "getString" | "getStringList")
        {
            args.count(1, 3)?;
            let analyzer = legado_parser::AnalyzeRule::with_js_executor(
                args.optional(1).unwrap_or("").into(),
                request.source_key.clone(),
                executor,
            );
            return if method == "getString" {
                Ok(analyzer
                    .get_string_ex(args.optional(0).unwrap_or(""), args.boolean(2)?, true)?
                    .into())
            } else {
                Ok(serde_json::to_value(analyzer.get_strings_ex(
                    args.optional(0).unwrap_or(""),
                    args.boolean(2)?,
                )?)?)
            };
        }
        let mut values = call
            .args
            .iter()
            .map(|v| v.clone().map(Value::String).unwrap_or(Value::Null))
            .collect::<Vec<_>>();
        let timeout_index = match method {
            "ajax" => Some(1),
            "connect" => Some(2),
            _ => None,
        };
        if let Some(index) = timeout_index
            && values.len() <= index
        {
            values.resize(index + 1, Value::Null);
            values[index] = 9000.into();
        }
        if let Some(index) = timeout_index
            && let Some(Some(value)) = call.args.get(index)
        {
            values[index] = value
                .parse::<i32>()
                .map_err(|_| bad("网络期限必须是毫秒整数"))?
                .into();
        }
        let list = serde_json::to_string(&values)?;
        let expression = match (call.target, method) {
            (PageTarget::Source, "login") => {
                args.count(0, 0)?;
                let source = config.as_ref().ok_or_else(|| bad("页内调用的书源不存在"))?;
                let raw = source.login_url.as_deref().unwrap_or("");
                let js = raw
                    .strip_prefix("@js:")
                    .or_else(|| {
                        raw.strip_prefix("<js>")
                            .and_then(|v| v.strip_suffix("</js>"))
                    })
                    .unwrap_or(raw);
                format!(
                    "(function(){{{js}\nif(typeof login==='function')login.apply(source);else if({})throw new Error('Function login not implements!!!');return null;}})()",
                    !js.trim().is_empty()
                )
            }
            (PageTarget::Java, "ajax") => {
                args.count(1, 2)?;
                args.text(0)?;
                format!("java.ajax.apply(java,{list})")
            }
            (PageTarget::Java, "connect") => {
                args.count(1, 3)?;
                args.text(0)?;
                format!("java.connect.apply(java,{list}).raw().__summary")
            }
            (PageTarget::Java, "get" | "head" | "post") => {
                let post = method == "post";
                args.count(if post { 3 } else { 2 }, if post { 4 } else { 3 })?;
                args.text(0)?;
                args.text(1)?;
                if post {
                    args.text(2)?;
                }
                let a = serde_json::to_string(args.text(0)?)?;
                let headers = serde_json::to_string(args.text(if post { 2 } else { 1 })?)?;
                let body = if post {
                    serde_json::to_string(args.text(1)?)?
                } else {
                    "null".into()
                };
                let timeout = args
                    .optional(if post { 3 } else { 2 })
                    .unwrap_or("9000")
                    .parse::<i32>()
                    .map_err(|_| bad("网络期限必须是毫秒整数"))?;
                // 既有Jsoup兼容入口保留重定向和抛错语义，不受来源变量get重载影响。
                format!(
                    "(function(){{var r=JSON.parse(java.connectNR({a},'{}',{headers},{body},{timeout}));return {};}})()",
                    method.to_ascii_uppercase(),
                    if method == "head" {
                        "JSON.stringify(r.headers)"
                    } else {
                        "r.body"
                    }
                )
            }
            _ => return Err(bad("未支持的后台java方法")),
        };
        let value = executor
            .execute_js(&format!("JSON.stringify({expression})"))
            .map_err(|e| bad(&e))?;
        serde_json::from_str(&value).map_err(|e| bad(&format!("页内执行结果不是JSON值：{e}")))
    }
}
