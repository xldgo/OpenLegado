//! 同步宿主的WebView等待适配；不持有VM缓存或根引擎。
use legado_core::webview_channel::{ActiveCheck, WebViewManager, WebViewRequest};
use legado_core::{LegadoError, LegadoResult};
use std::{sync::Arc, time::Duration};
pub fn execute(
    manager: &Arc<WebViewManager>,
    control: Option<Arc<dyn crate::cancellation::JsCancellation>>,
    request: WebViewRequest,
    timeout: Duration,
) -> Option<LegadoResult<String>> {
    let control = control.or_else(crate::cancellation::current);
    if control
        .as_ref()
        .is_some_and(|control| control.is_cancelled())
    {
        return Some(Err(crate::cancellation::error()));
    }
    let active = control.map(|control| Arc::new(move || !control.is_cancelled()) as ActiveCheck);
    manager.try_request(request, timeout, active).map(|handle| {
        let result = handle.wait(timeout)?;
        // 既有平台用保留前缀传递加载/执行错误，不把它作为正文或触发无头重试。
        if result.starts_with("[ERROR]") {
            Err(LegadoError::Network(result))
        } else {
            Ok(result)
        }
    })
}
/// 规则来源固定，Cookie在每次请求时按页面URL读取；闭包不保留VM缓存。
pub fn executor(
    resources: &crate::JsResources,
    source_key: &str,
) -> legado_parser::analyze_rule::WebViewExecutor {
    let manager = resources.host_resources().webview.clone();
    let control = resources.cancellation().cloned();
    let source_key = source_key.to_owned();
    #[cfg(feature = "quickjs")]
    let http = resources.http_resources().clone();
    Arc::new(move |mut request, timeout| {
        request.source_key = source_key.clone();
        #[cfg(feature = "quickjs")]
        {
            request.cookie = http.cookies_for_url(&request.url);
        }
        execute(&manager, control.clone(), request, timeout)
    })
}
