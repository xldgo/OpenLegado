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
pub fn executor(resources: &crate::JsResources) -> legado_parser::analyze_rule::WebViewExecutor {
    let manager = resources.host_resources().webview.clone();
    let control = resources.cancellation().cloned();
    Arc::new(move |request, timeout| execute(&manager, control.clone(), request, timeout))
}
