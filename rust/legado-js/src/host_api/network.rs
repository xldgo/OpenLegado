//! JsExtensions 网络相关方法
//!
//! 书源规则中常用的网络请求方法，对应 Kotlin JsExtensions 中的 ajax/connect/get/post/head 等。
//! 使用 `legado-net::LegadoClient` 异步网络栈，通过 `runtime_bridge::block_on` 提供同步接口。
//! 请求 API 显式消费 RequestResources；池和 Cookie 能力由所属 HttpResources 提供。

#![cfg(feature = "quickjs")]

use crate::http_resources::RequestResources;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(test)]
use crate::host_api::runtime_bridge::block_on;
use legado_net::client::ClientTimeoutPolicy;
use legado_net::{COOKIE_JAR_HEADER, LegadoClient, LegadoRequest, Method};

/// 默认请求超时（毫秒），与 Kotlin 端一致
const DEFAULT_TIMEOUT_MS: u64 = 30_000;

/// body 反序列化：兼容字符串、对象/数组（书山聚合等源 `url,{json}` 的
/// body 是嵌套对象，须转 JSON 字符串，否则 serde 解析失败 → ajax 返回 [ERROR]）
fn de_body<'de, D>(de: D) -> Result<Option<String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let v = Option::<serde_json::Value>::deserialize(de)?;
    Ok(v.map(|b| match b {
        serde_json::Value::String(s) => s,
        other => other.to_string(),
    }))
}

/// HTTP 请求选项（用于 `ajax` 通用接口）
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct HttpOptions {
    /// HTTP 方法：GET / POST / HEAD / PUT / DELETE
    #[serde(default)]
    pub method: Option<String>,
    /// 请求 URL
    #[serde(default)]
    pub url: String,
    /// 请求头
    #[serde(default)]
    pub headers: Option<HashMap<String, String>>,
    /// 请求体（POST/PUT 时使用；兼容字符串或 JSON 对象/数组）
    #[serde(default, deserialize_with = "de_body")]
    pub body: Option<String>,
    /// 超时毫秒数
    #[serde(default)]
    pub timeout_ms: Option<u64>,
}

/// HTTP 响应（用于 `ajax` 通用接口返回）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpResponse {
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub raw_summary: String,
    /// HTTP 状态码
    pub status_code: u16,
    /// 响应体文本
    pub body: String,
    /// 响应头
    pub headers: HashMap<String, String>,
    /// 最终 URL（connect/StrResponse raw.request.url 兼容）
    #[serde(default)]
    pub url: String,
}

/// 从 JSON 字符串解析请求头
fn parse_headers(headers_json: Option<&str>) -> Option<HashMap<String, String>> {
    headers_json.and_then(|s| serde_json::from_str::<HashMap<String, String>>(s).ok())
}

/// 请求前规范化 URL：去掉/纠正书源 `#tag` 后缀（对齐 Jsoup 忽略 fragment，
/// 并修复 `getKey()+path` 把 path/query 拼进 fragment 的假 URL）
fn sanitize_request_url(url: &str) -> String {
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    // 复用 AnalyzeUrl 同一套规范化，避免 ajax/connectNR 与搜索主链路行为分叉
    legado_parser::AnalyzeUrl::normalize_book_source_tag_url(trimmed)
}

/// 判断 URL 是否指向本地回环地址（127.0.0.1 / ::1 / localhost，http/https）
///
/// 供 `connect_no_redirect` 决定 `no_proxy`：reqwest 默认客户端在
/// HTTP_PROXY/HTTPS_PROXY 存在时连回环地址也走代理，会把本地测试流量
/// 劫持到死代理；回环豁免对齐 legado-net 约定（cda70a0c54）。
pub(crate) fn is_loopback_url(url: &str) -> bool {
    let Ok(url) = url::Url::parse(url.trim()) else {
        return false;
    };
    if !matches!(url.scheme(), "http" | "https") {
        return false;
    }
    match url.host() {
        Some(url::Host::Domain(host)) => host.eq_ignore_ascii_case("localhost"),
        Some(url::Host::Ipv4(host)) => host.is_loopback(),
        Some(url::Host::Ipv6(host)) => host.is_loopback(),
        None => false,
    }
}

/// POST 有 body 时若缺 Content-Type，补 form-urlencoded（对齐 Jsoup.requestBody）
fn ensure_form_content_type(headers: &mut HashMap<String, String>, has_body: bool) {
    if !has_body {
        return;
    }
    let has_ct = headers
        .keys()
        .any(|k| k.eq_ignore_ascii_case("content-type"));
    if !has_ct {
        headers.insert(
            "Content-Type".to_string(),
            "application/x-www-form-urlencoded".to_string(),
        );
    }
}

/// 按当前书源开关向请求头补写侧标记（只补不覆盖：显式同名键保持原值）
pub(super) fn apply_source_cookie_jar_gate(
    request_resources: &RequestResources<'_>,
    headers: &mut HashMap<String, String>,
) {
    if !request_resources.cookie_jar_enabled {
        return;
    }
    if headers
        .keys()
        .any(|k| k.eq_ignore_ascii_case(COOKIE_JAR_HEADER))
    {
        return;
    }
    headers.insert(COOKIE_JAR_HEADER.to_string(), "1".to_string());
}

fn request_client(
    resources: &RequestResources<'_>,
    no_redirect: bool,
    url: &str,
) -> Result<LegadoClient, String> {
    resources.http.client(is_loopback_url(url), no_redirect)
}

/// 0不设置请求总期限；客户端策略另外决定连接和读取预算。
pub(super) fn request_timeout(timeout_ms: u64) -> Option<std::time::Duration> {
    (timeout_ms != 0).then(|| std::time::Duration::from_millis(timeout_ms))
}

pub(super) fn request_client_with_timeout(
    resources: &RequestResources<'_>,
    no_redirect: bool,
    url: &str,
    timeout_ms: u64,
    zero_policy: ClientTimeoutPolicy,
) -> Result<LegadoClient, String> {
    let policy = if timeout_ms == 0 {
        zero_policy
    } else {
        ClientTimeoutPolicy::Default
    };
    resources
        .http
        .client_with_timeout_policy(is_loopback_url(url), no_redirect, policy)
}

/// httpGet(url, headers?) → 同步 HTTP GET，返回响应体文本
///
/// 对应 Kotlin 端 `ajax(url)` / `get(url, headers)` 的简化版本。
pub fn http_get(
    request_resources: &RequestResources<'_>,
    url: &str,
    headers: Option<&str>,
) -> Result<String, String> {
    super::runtime_bridge::block_on_cancellable(async {
        request_resources.policy()?.acquire(false).await;
        // 回环 URL 直连豁免代理（P2-17 约定），真实主机行为不变；
        // 实例共享池（2026-09-24 性能专项：不再每调用新建连接池）
        let client = request_client(request_resources, false, url)?;
        // 写侧门控（批 2）：按当前书源开关补标记（读侧不受影响）
        let mut header_map = parse_headers(headers).unwrap_or_default();
        apply_source_cookie_jar_gate(request_resources, &mut header_map);
        let header_map = if header_map.is_empty() {
            None
        } else {
            Some(header_map)
        };
        let resp = client
            .get(url, header_map)
            .await
            .map_err(|e| format!("httpGet error: {}", e))?;
        Ok(resp.body)
    })
}

/// httpPost(url, body, headers?) → 同步 HTTP POST，返回响应体文本
///
/// 对应 Kotlin 端 `post(url, body, headers)` 的简化版本。
pub fn http_post(
    request_resources: &RequestResources<'_>,
    url: &str,
    body: &str,
    headers: Option<&str>,
) -> Result<String, String> {
    super::runtime_bridge::block_on_cancellable(async {
        request_resources.policy()?.acquire(false).await;
        // 回环 URL 直连豁免代理（P2-17 约定），真实主机行为不变；
        // 实例共享池（2026-09-24 性能专项：不再每调用新建连接池）
        let client = request_client(request_resources, false, url)?;
        // 写侧门控（批 2）：按当前书源开关补标记
        let mut header_map = parse_headers(headers).unwrap_or_default();
        apply_source_cookie_jar_gate(request_resources, &mut header_map);
        let header_map = if header_map.is_empty() {
            None
        } else {
            Some(header_map)
        };
        let resp = client
            .post(url, body, header_map)
            .await
            .map_err(|e| format!("httpPost error: {}", e))?;
        Ok(resp.body)
    })
}

/// httpHead(url) → HEAD 请求，返回响应头 JSON 字符串
///
/// 对应 Kotlin 端 `head(urlStr, headers)` 的简化版本。
pub fn http_head(request_resources: &RequestResources<'_>, url: &str) -> Result<String, String> {
    super::runtime_bridge::block_on_cancellable(async {
        request_resources.policy()?.acquire(false).await;
        // 回环 URL 直连豁免代理（P2-17 约定），真实主机行为不变；
        // 实例共享池（2026-09-24 性能专项：不再每调用新建连接池）
        let client = request_client(request_resources, false, url)?;
        // 写侧门控（批 2）：按当前书源开关补标记（上游 head 同门控）
        let mut header_map = HashMap::new();
        apply_source_cookie_jar_gate(request_resources, &mut header_map);
        let header_map = if header_map.is_empty() {
            None
        } else {
            Some(header_map)
        };
        let resp = client
            .head(url, header_map)
            .await
            .map_err(|e| format!("httpHead error: {}", e))?;
        serde_json::to_string(&resp.headers).map_err(|e| format!("httpHead serialize error: {}", e))
    })
}

/// ajax/connect的可空毫秒期限；显式0保留为关闭总期限，不与缺省混淆。
/// 负数或超过OkHttp的Int毫秒范围在发送前拒绝。
pub fn call_timeout_to_request_timeout(
    call_timeout_ms: Option<i64>,
) -> Result<Option<u64>, String> {
    match call_timeout_ms {
        None => Ok(None),
        Some(t) if t < 0 => Err(format!(
            "网络请求: callTimeout {t} 非法（原版 OkHttp checkDuration: timeout < 0）"
        )),
        Some(t) if t > i64::from(i32::MAX) => Err(format!(
            "网络请求: callTimeout {t} 超过原版 OkHttp 上限 Integer.MAX_VALUE 毫秒"
        )),
        Some(t) => Ok(Some(t as u64)),
    }
}

/// ajax(options) → 通用 AJAX 请求（无显式 callTimeout，保持既有行为）
///
/// 支持两种输入（对齐原版 JsExtensions.ajax）：
/// 1. 标准 JSON：`{"url":..., "method":..., "headers":..., "body":...}` → 返回 HttpResponse JSON
/// 2. 原版「url,{json}」格式（七猫四合一等书源）：
///    `https://api?... ,{"method":"GET","headers":{...}}` → 返回**纯响应体文本**
///    （原版 ajax 返回 StrResponse.body；七猫 qmParse 直接 JSON.parse 响应体）
pub fn ajax(request_resources: &RequestResources<'_>, input: &str) -> Result<String, String> {
    ajax_with_timeout(request_resources, input, None)
}

/// 带调用方显式超时的 ajax 入口（`java.ajax` 第二参透传路径）。
///
/// 逐请求超时语义与边界见 [`call_timeout_to_request_timeout`]；
/// `call_timeout_ms = None` 时与 [`ajax`] 完全等价。
pub fn ajax_with_timeout(
    request_resources: &RequestResources<'_>,
    input: &str,
    call_timeout_ms: Option<u64>,
) -> Result<String, String> {
    super::rule_request::ajax(request_resources, input, call_timeout_ms, None)
}

pub(super) fn ajax_with_evaluator(
    resources: &RequestResources<'_>,
    input: &str,
    timeout: Option<u64>,
    evaluator: &dyn legado_parser::analyze_url::SynchronousJsEvaluator,
) -> Result<String, String> {
    super::rule_request::ajax(resources, input, timeout, Some(evaluator))
}

#[cfg(test)]
mod http_options_tests {
    use super::*;

    #[test]
    fn loopback_selection_uses_the_parsed_host() {
        for url in [
            "http://127.0.0.1:80/x",
            "http://127.0.0.2/",
            "HTTP://LOCALHOST?x=1",
            "http://user:pwd@localhost/",
            "http://[::1]:80/",
            "https://[0:0:0:0:0:0:0:1]/",
        ] {
            assert!(is_loopback_url(url), "回环地址应选择直连池：{url}");
        }
        for url in [
            "http://localhost.example/",
            "http://localhost@remote.example/",
            "http://[2001:db8::1]/",
            "ftp://localhost/",
            "不是URL",
        ] {
            assert!(!is_loopback_url(url), "非回环HTTP地址不得绕过代理：{url}");
        }
    }

    #[test]
    fn test_body_accepts_object() {
        // 书山目录：url,{"method":"POST","body":{...对象...}}
        let opts: HttpOptions = serde_json::from_str(
            r#"{"method":"POST","url":"https://v1.vossc.com/catalog","body":{"source":"书山","url":"x","name":"n","tab":"novel"}}"#,
        )
        .unwrap();
        assert!(opts.body.as_deref().unwrap().contains("source"));
        assert!(opts.body.as_deref().unwrap().contains("书山"));
    }

    #[test]
    fn test_body_accepts_string() {
        let opts: HttpOptions =
            serde_json::from_str(r#"{"method":"POST","body":"key=val"}"#).unwrap();
        assert_eq!(opts.body.as_deref(), Some("key=val"));
    }

    /// `java.ajax(url, callTimeout)` 边界映射（原版 OkHttp checkDuration 语义）
    #[test]
    fn test_call_timeout_to_request_timeout_boundaries() {
        // 缺省不覆盖默认，显式0须传到请求和客户端选择
        assert_eq!(call_timeout_to_request_timeout(None).unwrap(), None);
        assert_eq!(call_timeout_to_request_timeout(Some(0)).unwrap(), Some(0));
        // 正超时原样透传（毫秒）
        assert_eq!(
            call_timeout_to_request_timeout(Some(300)).unwrap(),
            Some(300)
        );
        // 原版 OkHttp 上限 Integer.MAX_VALUE 毫秒（含）
        assert_eq!(
            call_timeout_to_request_timeout(Some(i64::from(i32::MAX))).unwrap(),
            Some(i32::MAX as u64)
        );
        // < 0 / > Integer.MAX_VALUE：原版抛 IllegalArgumentException（错误文本）
        assert!(call_timeout_to_request_timeout(Some(-1)).is_err());
        assert!(call_timeout_to_request_timeout(Some(i64::from(i32::MAX) + 1)).is_err());
    }
}

/// 合并书源请求头与会话 Cookie（对齐 Android AnalyzeUrl(source).getHeaderMap）
///
/// - 来源请求头（请求快照）：setup 阶段执行书源 header @js 规则后经
///   java.putGlobalHeaders 写入（书山聚合固定 X-Novel-Token 等），按当前书源
///   tag 隔离；JS 显式传入的 headers 优先。
/// - 会话 Cookie（所属实例权威罐）：书山登录/`java.setCookie` 写入的
///   X-Novel-Token 等。**上游同步（2026-09-23 用户裁决）：按请求 URL 的属域
///   取**（`CookieAccess::get`，写读两侧均归一为
///   `getSubDomain(url)` 等价域名键，单一真源
///   [`legado_net::cookie_store::cookie_domain_key`]），去掉书源 tag 维度——
///   cookie 属于域名而非书源，同域 cookie 跨书源共享（对齐上游
///   `CookieManager.loadRequest` 按请求 URL 取 cookie 的语义）。
///   **按键合并**进已有 Cookie 头（已有同名键胜、非冲突 JS 键追加；
///   键查找大小写不敏感）——对齐上游 `AnalyzeUrl.setCookie` →
///   `CookieManager.mergeCookies` 语义。
///   不变式保留：**不相关域名的 cookie 绝不携带**（P2-19 核心修复，不得回退）。
pub(super) fn merge_global_cookie(
    request_resources: &RequestResources<'_>,
    mut headers: HashMap<String, String>,
    url: &str,
) -> HashMap<String, String> {
    for (key, value) in &request_resources.headers {
        if !headers.keys().any(|name| name.eq_ignore_ascii_case(key)) {
            headers.insert(key.clone(), value.clone());
        }
    }
    let cookies = request_resources.http.cookies().get(url);
    crate::host_api::cookie_store::merge_cookie_string(&mut headers, &cookies);
    headers
}

/// 旧协议测试继续走同一规则请求，不保留独立编排实现。
#[cfg(test)]
fn ajax_request_body(
    resources: &RequestResources<'_>,
    opts: &HttpOptions,
) -> Result<String, String> {
    let input = serde_json::to_string(opts).map_err(|e| e.to_string())?;
    let response = super::rule_request::ajax(resources, &input, None, None)?;
    let response: HttpResponse = serde_json::from_str(&response).map_err(|e| e.to_string())?;
    Ok(response.body)
}

/// 批量规则请求的 Rust 入口，JSON 内部表示在 JS 边界包装为 StrResponse 数组。
pub fn ajax_all(resources: &RequestResources<'_>, urls_json: &str) -> Result<String, String> {
    super::batch_request::run(resources, urls_json, None, false, false, None)
}

/// connectFull(url, method?, headers?, body?, timeoutMs?) → 完整 HTTP 响应 JSON
///
/// 对应 Kotlin: `connect(urlStr, header, callTimeout): StrResponse`
/// 增强版：支持指定 HTTP 方法（GET/POST/HEAD/PUT/DELETE），返回完整响应。
///
/// 返回 JSON：`{"statusCode":200,"body":"...","headers":{...}}`
pub fn connect_full(
    request_resources: &RequestResources<'_>,
    url: &str,
    method: Option<&str>,
    headers_json: Option<&str>,
    body: Option<&str>,
    timeout_ms: Option<u64>,
) -> Result<String, String> {
    connect_with_evaluator(
        request_resources,
        url,
        method,
        headers_json,
        body,
        timeout_ms,
        None,
    )
}

pub(super) fn connect_with_evaluator(
    resources: &RequestResources<'_>,
    url: &str,
    method: Option<&str>,
    headers: Option<&str>,
    body: Option<&str>,
    timeout: Option<u64>,
    evaluator: Option<&dyn legado_parser::analyze_url::SynchronousJsEvaluator>,
) -> Result<String, String> {
    let response = super::rule_request::execute(
        resources,
        url,
        super::rule_request::RequestOverrides {
            method,
            headers,
            body,
            timeout,
        },
        evaluator,
    )
    .map_err(|e| {
        e.replace("ajax:", "connect:")
            .replace("ajax request error", "connect request error")
    })?;
    serde_json::to_string(&response).map_err(|e| e.to_string())
}

/// connectNR(url, method?, headers?, body?) → 完整响应 JSON（不跟随重定向）
///
/// 对齐原版 JsExtensions.get/post/head 的 jsoup 语义（.followRedirects(false)）：
/// 拦截重定向场景（天悦小说 java.post(...).header("Location")）必须拿到
/// 302 响应的 Location 头；跟随重定向后头信息丢失 → header 返回 null。
/// — 2026-08-17
pub fn connect_no_redirect(
    request_resources: &RequestResources<'_>,
    url: &str,
    method: Option<&str>,
    headers_json: Option<&str>,
    body: Option<&str>,
) -> Result<String, String> {
    connect_no_redirect_with_timeout(request_resources, url, method, headers_json, body, None)
}

/// JS的get/head/post逐次超时入口；旧Rust调用保持原默认值。
pub(crate) fn connect_no_redirect_with_timeout(
    request_resources: &RequestResources<'_>,
    url: &str,
    method: Option<&str>,
    headers_json: Option<&str>,
    body: Option<&str>,
    timeout_ms: Option<u64>,
) -> Result<String, String> {
    let timeout = timeout_ms.unwrap_or(DEFAULT_TIMEOUT_MS);
    let method_str = method.unwrap_or("GET").to_uppercase();
    let method = match method_str.as_str() {
        "GET" | "POST" | "HEAD" | "PUT" | "DELETE" => Method::from_str_loose(&method_str),
        other => return Err(format!("connectNR: unsupported method '{}'", other)),
    };
    let url = sanitize_request_url(url);
    let mut headers: HashMap<String, String> = headers_json
        .and_then(|s| serde_json::from_str(s).ok())
        .unwrap_or_default();
    let body_owned = body.map(|s| s.to_string());
    ensure_form_content_type(
        &mut headers,
        body_owned.as_ref().is_some_and(|b| !b.is_empty()),
    );
    // 写侧门控（批 2）：java.get/post/head 走 connectNR；按当前书源开关补标记
    //（对齐上游 JsExtensions.kt:532-534/559-561/586-588 的 getSource 门控）
    apply_source_cookie_jar_gate(request_resources, &mut headers);
    super::runtime_bridge::block_on_cancellable(async {
        request_resources.policy()?.acquire(false).await;
        // 不跟随重定向共享池（回环/非回环分池）：
        // - `follow_redirects=false`：拦截 302 取 Location 头（jsoup 语义）
        // - 回环流量（本地测试服务/本地源）不得经系统/环境变量代理路由：
        //   reqwest 默认客户端在 HTTP_PROXY 存在时连 127.0.0.1 也走代理，
        //   死代理环境下回环用例会被劫持（cda70a0c54 约定）。仅回环 URL
        //   豁免代理；真实主机仍走用户代理配置，不改变生产行为。
        let client = request_client_with_timeout(
            request_resources,
            true,
            &url,
            timeout,
            ClientTimeoutPolicy::Unlimited,
        )
        .map_err(|e| format!("connectNR client error: {}", e))?;
        let request = LegadoRequest {
            url,
            method,
            headers,
            body: body_owned,
            timeout: request_timeout(timeout),
        };
        let resp = client
            .send(&request)
            .await
            .map_err(|e| format!("connectNR request error: {}", e))?;
        let result = HttpResponse {
            raw_summary: String::new(),
            status_code: resp.status,
            body: resp.body,
            headers: resp.headers,
            url: resp.url,
        };
        serde_json::to_string(&result).map_err(|e| format!("connectNR serialize error: {}", e))
    })
}

/// headFull(url, headers?) → HEAD 请求完整响应 JSON
///
/// 对应 Kotlin: `head(urlStr, headers): Connection.Response`
/// 返回包含 statusCode / body / headers 的完整响应 JSON。
pub fn head_full(
    request_resources: &RequestResources<'_>,
    url: &str,
    headers_json: Option<&str>,
) -> Result<String, String> {
    let mut headers: HashMap<String, String> = headers_json
        .and_then(|s| serde_json::from_str(s).ok())
        .unwrap_or_default();
    // 写侧门控（批 2）：按当前书源开关补标记（上游 head 同门控）
    apply_source_cookie_jar_gate(request_resources, &mut headers);

    super::runtime_bridge::block_on_cancellable(async {
        request_resources.policy()?.acquire(false).await;
        // 回环 URL 直连豁免代理（P2-17 约定），真实主机行为不变；
        // 实例共享池（2026-09-24 性能专项：不再每调用新建连接池）
        let client = request_client(request_resources, false, url)?;
        let request = LegadoRequest {
            url: url.to_string(),
            method: Method::Head,
            headers,
            body: None,
            timeout: Some(std::time::Duration::from_millis(DEFAULT_TIMEOUT_MS)),
        };
        let resp = client
            .send(&request)
            .await
            .map_err(|e| format!("head request error: {}", e))?;
        let result = HttpResponse {
            raw_summary: String::new(),
            status_code: resp.status,
            body: resp.body,
            headers: resp.headers,
            url: resp.url,
        };
        serde_json::to_string(&result).map_err(|e| format!("head serialize error: {}", e))
    })
}

/// postFull(url, body, headers?) → POST 请求完整响应 JSON
///
/// 对应 Kotlin: `post(urlStr, body, headers): Connection.Response`
/// 返回包含 statusCode / body / headers 的完整响应 JSON。
pub fn post_full(
    request_resources: &RequestResources<'_>,
    url: &str,
    body: &str,
    headers_json: Option<&str>,
) -> Result<String, String> {
    let mut headers: HashMap<String, String> = headers_json
        .and_then(|s| serde_json::from_str(s).ok())
        .unwrap_or_default();
    // 写侧门控（批 2）：按当前书源开关补标记（上游 post 同门控）
    apply_source_cookie_jar_gate(request_resources, &mut headers);

    super::runtime_bridge::block_on_cancellable(async {
        request_resources.policy()?.acquire(false).await;
        // 回环 URL 直连豁免代理（P2-17 约定），真实主机行为不变；
        // 实例共享池（2026-09-24 性能专项：不再每调用新建连接池）
        let client = request_client(request_resources, false, url)?;
        let request = LegadoRequest {
            url: url.to_string(),
            method: Method::Post,
            headers,
            body: Some(body.to_string()),
            timeout: Some(std::time::Duration::from_millis(DEFAULT_TIMEOUT_MS)),
        };
        let resp = client
            .send(&request)
            .await
            .map_err(|e| format!("post request error: {}", e))?;
        let result = HttpResponse {
            raw_summary: String::new(),
            status_code: resp.status,
            body: resp.body,
            headers: resp.headers,
            url: resp.url,
        };
        serde_json::to_string(&result).map_err(|e| format!("post serialize error: {}", e))
    })
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};

    use super::*;

    use crate::http_resources::{CookieAccess, HttpResources};
    use legado_net::{CookiePersistence, CookieStore, LegadoClientConfig};
    use std::sync::{Arc, RwLock};

    /// 每个协议用例拥有自己的 Cookie、后端、来源开关和四池，不注册进程槽。
    struct Fixture {
        http: HttpResources,
        persistence: Arc<RecordingPersistence>,
        store: Arc<RwLock<CookieStore>>,
        gates: Arc<std::sync::Mutex<HashMap<String, bool>>>,
    }

    struct FixtureCookies(Arc<RwLock<CookieStore>>);
    impl CookieAccess for FixtureCookies {
        fn get(&self, url: &str) -> String {
            let key = legado_net::cookie_store::normalize_cookie_key(url);
            self.0.read().unwrap().domain_cookie_string(&key)
        }
        fn set(&self, url: &str, value: &str) {
            let key = legado_net::cookie_store::normalize_cookie_key(url);
            self.0.write().unwrap().set_cookies_from_string(&key, value);
        }
        fn clear(&self, url: &str) {
            let key = legado_net::cookie_store::normalize_cookie_key(url);
            self.0.write().unwrap().remove_domain(&key);
        }
        fn clear_all(&self) {
            self.0.write().unwrap().clear();
        }
    }

    impl Default for Fixture {
        fn default() -> Self {
            Self::with_persistence(Default::default())
        }
    }

    impl Fixture {
        fn with_persistence(persistence: Arc<RecordingPersistence>) -> Self {
            let store = Arc::new(RwLock::new(CookieStore::new()));
            let gates: Arc<std::sync::Mutex<HashMap<String, bool>>> = Default::default();
            let lookup = gates.clone();
            let http = HttpResources::new(
                store.clone(),
                Some(persistence.clone()),
                Arc::new(FixtureCookies(store.clone())),
                Arc::new(move |tag| lookup.lock().unwrap().get(tag).copied()),
            );
            Self {
                http,
                persistence,
                store,
                gates,
            }
        }
    }

    /// 判断响应体是否为有效 JSON 对象（httpbin 风格回显；区分 404/错误页）
    fn is_valid_response(body: &str) -> bool {
        !body.is_empty() && body.trim_start().starts_with('{')
    }

    /// 本地回环 mock 服务器读到的一个 HTTP/1.1 请求
    struct MockRequest {
        method: String,
        path: String,
        query: String,
        headers: Vec<(String, String)>,
        body: String,
    }

    impl MockRequest {
        /// 请求头 → JSON 对象（/get、/headers 回显用；键保持服务器收到时的大小写）
        fn headers_json(&self) -> serde_json::Value {
            let mut map = serde_json::Map::new();
            for (k, v) in &self.headers {
                map.insert(k.clone(), serde_json::Value::String(v.clone()));
            }
            serde_json::Value::Object(map)
        }

        /// query 串 → args 映射（httpbin /get 回显用；值保持 URL 编码原样）
        fn args_json(&self) -> serde_json::Value {
            let mut map = serde_json::Map::new();
            for kv in self.query.split('&').filter(|s| !s.is_empty()) {
                let (k, v) = kv.split_once('=').unwrap_or((kv, ""));
                map.insert(k.to_string(), serde_json::Value::String(v.to_string()));
            }
            serde_json::Value::Object(map)
        }
    }

    /// 逐字节读取一个完整 HTTP/1.1 请求（头到 `\r\n\r\n` + Content-Length body）
    fn read_mock_http_request(sock: &mut std::net::TcpStream) -> Option<MockRequest> {
        let mut head: Vec<u8> = Vec::new();
        let mut byte = [0u8; 1];
        while !head.ends_with(b"\r\n\r\n") {
            if sock.read_exact(&mut byte).is_err() {
                return None;
            }
            head.push(byte[0]);
            if head.len() > 65_536 {
                return None;
            }
        }
        let head_str = String::from_utf8_lossy(&head).into_owned();
        let mut lines = head_str.lines();
        let request_line = lines.next().unwrap_or_default();
        let mut parts = request_line.split_whitespace();
        let method = parts.next().unwrap_or("GET").to_uppercase();
        let target = parts.next().unwrap_or("/");
        let (path, query) = match target.split_once('?') {
            Some((p, q)) => (p, q),
            None => (target, ""),
        };
        let mut headers = Vec::new();
        for line in lines {
            if line.is_empty() {
                continue;
            }
            if let Some((k, v)) = line.split_once(':') {
                headers.push((k.trim().to_string(), v.trim().to_string()));
            }
        }
        let content_length = headers
            .iter()
            .find(|(k, _)| k.eq_ignore_ascii_case("content-length"))
            .and_then(|(_, v)| v.parse::<usize>().ok())
            .unwrap_or(0);
        let mut body_buf = vec![0u8; content_length];
        if content_length > 0 && sock.read_exact(&mut body_buf).is_err() {
            return None;
        }
        Some(MockRequest {
            method,
            path: path.to_string(),
            query: query.to_string(),
            headers,
            body: String::from_utf8_lossy(&body_buf).into_owned(),
        })
    }

    /// 最小本地回环 httpbin 风格 mock 服务器（本模块 10 例真联网用例的确定性替身，
    /// 替代 `https://httpbin.org/...`——外部 503/验证页/断网会让软断言用例静默通过）。
    ///
    /// 按用例实际断言逐一核对，复刻所需 httpbin 行为子集：
    /// - `GET /get`     → `{"url","args","headers","origin"}`（回显 query/请求头，httpbin 签名）
    /// - `GET /headers` → `{"headers":{...}}`（回显请求头）
    /// - `POST /post`   → `{"data","json","headers","url"}`（回显 body；body 为 JSON 时附解析结果）
    /// - HEAD 任意路由  → 200（仅响应头、无 body）
    /// - 其他路由       → 404 `{"error":"not found"}`（「故意破坏」对照用）
    ///
    /// std `TcpListener` + 单线程模式（与 `spawn_search_loopback_server` /
    /// `spawn_cookie_echo_server` 同款；legado-js 的 quickjs tokio feature 无 net）；
    /// 回环流量经 `no_proxy` 豁免系统/环境变量代理（P2-17 约定，见
    /// 回环共享池 `HttpResources::client(true, false)` / `HttpResources::client(true, true)`）。
    fn spawn_httpbin_mock(max_conns: usize) -> std::net::SocketAddr {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind 127.0.0.1:0");
        let addr = listener.local_addr().expect("local_addr");
        let origin = addr.to_string();
        std::thread::spawn(move || {
            for stream in listener.incoming().take(max_conns) {
                let Ok(mut sock) = stream else { continue };
                let _ = sock.set_read_timeout(Some(std::time::Duration::from_secs(10)));
                let Some(req) = read_mock_http_request(&mut sock) else {
                    continue;
                };
                let (status, body) = if req.method == "HEAD" {
                    ("200 OK", String::new())
                } else if req.path == "/get" {
                    // httpbin /get 回显：url 为完整请求 URL，origin 为 host（去端口）
                    let host = origin.split_once(':').map_or(origin.as_str(), |(h, _)| h);
                    (
                        "200 OK",
                        serde_json::json!({
                            "url": format!("http://{origin}{path}", path = req.path),
                            "args": req.args_json(),
                            "headers": req.headers_json(),
                            "origin": host,
                        })
                        .to_string(),
                    )
                } else if req.path == "/headers" {
                    (
                        "200 OK",
                        serde_json::json!({ "headers": req.headers_json() }).to_string(),
                    )
                } else if req.path == "/post" {
                    let mut v = serde_json::json!({
                        "data": req.body,
                        "headers": req.headers_json(),
                        "url": format!("http://{origin}{}", req.path),
                    });
                    if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&req.body) {
                        v["json"] = parsed;
                    }
                    ("200 OK", v.to_string())
                } else {
                    ("404 Not Found", r#"{"error":"not found"}"#.to_string())
                };
                let resp = format!(
                    "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {len}\r\nConnection: close\r\n\r\n{body}",
                    len = body.len()
                );
                let _ = sock.write_all(resp.as_bytes());
            }
        });
        addr
    }

    /// 测试 http_get 基本请求（本地回环 mock：`/get` 回显 url/args/headers）
    #[test]
    fn test_http_get_basic() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let body = http_get(&fixture.http.request(), &format!("http://{addr}/get"), None)
            .expect("http_get 到本地回环 mock 应成功");
        assert!(is_valid_response(&body), "响应应为 JSON 对象: {body}");
        assert!(body.contains("/get"), "回显 URL 应含请求路径: {body}");
        assert!(
            body.contains("\"url\""),
            "响应应含 httpbin 风格回显 url 字段: {body}"
        );
    }

    /// 测试 http_get 带自定义 headers（本地回环 mock：`/headers` 回显请求头）
    ///
    /// 头名大小写不敏感比对：reqwest 在 wire 上把请求头名小写化发送（hyper
    /// `HeaderName` 规范），mock 忠实回显 wire 形态（`x-custom-header`）；
    /// 原 httpbin 用例的客户端保留原始大小写，此处按 HTTP 头语义等价放宽。
    #[test]
    fn test_http_get_with_headers() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let headers = r#"{"X-Custom-Header": "test-value"}"#;
        let body = http_get(
            &fixture.http.request(),
            &format!("http://{addr}/headers"),
            Some(headers),
        )
        .expect("http_get 到本地回环 mock 应成功");
        assert!(is_valid_response(&body), "响应应为 JSON 对象: {body}");
        let lower = body.to_ascii_lowercase();
        assert!(
            lower.contains("x-custom-header"),
            "响应应包含自定义请求头（大小写不敏感）: {body}"
        );
        assert!(
            lower.contains("test-value"),
            "响应应包含自定义请求头的值: {body}"
        );
    }

    /// 测试 http_post 基本请求（本地回环 mock：`/post` 回显 data/json）
    #[test]
    fn test_http_post_basic() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let body = http_post(
            &fixture.http.request(),
            &format!("http://{addr}/post"),
            r#"{"key": "value"}"#,
            Some(r#"{"Content-Type": "application/json"}"#),
        )
        .expect("http_post 到本地回环 mock 应成功");
        assert!(is_valid_response(&body), "响应应为 JSON 对象: {body}");
        assert!(!body.is_empty(), "POST 响应体不应为空");
        assert!(body.contains("key"), "响应应包含请求体中的 key: {body}");
        assert!(body.contains("value"), "响应应包含请求体中的 value: {body}");
    }

    /// 测试 http_head 返回 headers JSON（本地回环 mock：HEAD `/get`）
    #[test]
    fn test_http_head() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let headers_json = http_head(&fixture.http.request(), &format!("http://{addr}/get"))
            .expect("http_head 到本地回环 mock 应成功");
        let parsed: HashMap<String, String> =
            serde_json::from_str(&headers_json).expect("httpHead 应返回有效 JSON");
        assert!(!parsed.is_empty(), "HEAD 响应应含响应头: {parsed:?}");
        assert!(
            parsed
                .keys()
                .any(|k| k.eq_ignore_ascii_case("content-type")),
            "应含 mock 服务器返回的 Content-Type 响应头: {parsed:?}"
        );
    }

    /// 测试 ajax 通用接口（GET，本地回环 mock：`/get` 回显）
    #[test]
    fn test_ajax_get() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let opts = serde_json::json!({
            "method": "GET",
            "url": format!("http://{addr}/get"),
            "headers": {"Accept": "application/json"}
        });
        let resp_json = ajax(&fixture.http.request(), &opts.to_string())
            .expect("ajax GET 到本地回环 mock 应成功");
        let resp: HttpResponse = serde_json::from_str(&resp_json).expect("ajax 响应应可解析");
        assert_eq!(
            resp.status_code, 200,
            "mock 服务器应返回 200: {}",
            resp.body
        );
        assert!(!resp.body.is_empty(), "GET 响应体不应为空");
        assert!(
            is_valid_response(&resp.body),
            "响应应为 JSON 对象: {}",
            resp.body
        );
        assert!(
            resp.body.contains("/get"),
            "回显 URL 应含请求路径: {}",
            resp.body
        );
    }

    /// 原版「url,{json}」格式外网诊断：依赖 httpbin.org，不能作为离线 CI 门禁。
    /// URL option 解析由本地 AnalyzeUrl/JS bridge 回归覆盖。
    #[test]
    #[ignore = "依赖 httpbin.org，外部 503/验证页会改变响应体格式"]
    fn test_ajax_url_option_format_returns_body() {
        let fixture = Fixture::default();
        let input =
            r#"https://httpbin.org/get,{"method":"GET","headers":{"Accept":"application/json"}}"#;
        let result = ajax(&fixture.http.request(), input);
        if let Ok(body) = result {
            let head: String = body.chars().take(80).collect();
            assert!(
                body.trim_start().starts_with('{'),
                "应返回纯响应体文本(JSON)，而非 HttpResponse 包装: {}",
                head
            );
        }
    }

    /// 测试 ajax 通用接口（POST，本地回环 mock：`/post` 回显 data/json）
    #[test]
    fn test_ajax_post() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let opts = serde_json::json!({
            "method": "POST",
            "url": format!("http://{addr}/post"),
            "body": "{\"hello\": \"world\"}",
            "headers": {"Content-Type": "application/json"},
            "timeout_ms": 10000
        });
        let resp_json = ajax(&fixture.http.request(), &opts.to_string())
            .expect("ajax POST 到本地回环 mock 应成功");
        let resp: HttpResponse = serde_json::from_str(&resp_json).expect("ajax 响应应可解析");
        assert_eq!(
            resp.status_code, 200,
            "mock 服务器应返回 200: {}",
            resp.body
        );
        assert!(
            resp.body.contains("hello"),
            "回显体应含请求字段 hello: {}",
            resp.body
        );
        assert!(
            resp.body.contains("world"),
            "回显体应含请求值 world: {}",
            resp.body
        );
    }

    /// 测试 ajax 空 URL 应报错
    #[test]
    fn test_ajax_empty_url() {
        let fixture = Fixture::default();
        let opts = r#"{"method": "GET", "url": ""}"#;
        let result = ajax(&fixture.http.request(), opts);
        assert!(result.is_err(), "空 URL 应返回错误");
        assert!(result.unwrap_err().contains("url is required"));
    }

    /// 测试 ajax 不支持的 HTTP 方法
    #[test]
    fn test_ajax_unsupported_method() {
        let fixture = Fixture::default();
        let opts = r#"{"method": "PATCH", "url": "https://httpbin.org/patch"}"#;
        let result = ajax(&fixture.http.request(), opts);
        assert!(result.is_err(), "PATCH 方法应返回错误");
        assert!(result.unwrap_err().contains("unsupported method"));
    }

    /// 测试 ajaxAll 批量并发请求（本地回环 mock：3 个并发 `/get` 回显）
    #[test]
    fn test_ajax_all() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(8);
        let urls = serde_json::json!([
            format!("http://{addr}/get"),
            format!("http://{addr}/get"),
            format!("http://{addr}/get")
        ]);
        let results_json = ajax_all(&fixture.http.request(), &urls.to_string())
            .expect("ajaxAll 到本地回环 mock 应成功");
        let results: Vec<HttpResponse> = serde_json::from_str(&results_json).expect("结果应可解析");
        assert_eq!(results.len(), 3, "应返回 3 个结果");
        for response in &results {
            assert_eq!(response.status_code, 200);
            let body = &response.body;
            assert!(
                is_valid_response(body),
                "每个响应体都应为 JSON 对象: {body}"
            );
            assert!(
                body.contains("/get"),
                "回显 URL 应含请求路径（httpbin 标识的本地等价物）: {body}"
            );
        }
    }

    /// 测试 ajaxAll 无效 JSON 输入
    #[test]
    fn test_ajax_all_invalid_json() {
        let fixture = Fixture::default();
        let result = ajax_all(&fixture.http.request(), "not a json array");
        assert!(result.is_err(), "无效 JSON 应返回错误");
        assert!(result.unwrap_err().contains("parse error"));
    }

    /// 测试 parse_headers 解析正确 / 异常输入
    #[test]
    fn test_parse_headers() {
        let valid = r#"{"Authorization": "Bearer token123"}"#;
        let map = parse_headers(Some(valid));
        assert!(map.is_some());
        assert_eq!(
            map.unwrap().get("Authorization").unwrap(),
            "Bearer token123"
        );

        // 无效 JSON 返回 None
        let map = parse_headers(Some("not json"));
        assert!(map.is_none());

        // None 返回 None
        let map = parse_headers(None);
        assert!(map.is_none());
    }

    /// 四个进程级共享池均可构建，且重复取回同一实例（槽位注册表幂等，
    /// 2026-09-24 性能专项：不再每调用新建客户端/连接池）；注册共享
    /// store 钩子后四池共用同一 CookieStore（脑裂修复），reset 后四池
    /// 全部可重建且 store 内容不丢（设计项 A + 脑裂修复）
    #[test]
    fn test_shared_client_pools() {
        let fixture = Fixture::default();
        fixture.http.reset_clients();
        for (loopback, no_redirect) in [(false, false), (true, false), (false, true), (true, true)]
        {
            assert!(
                fixture.http.client(loopback, no_redirect).is_ok(),
                "共享池 (loopback={loopback}, no_redirect={no_redirect}) 应构建成功"
            );
        }
        // 幂等：两次取回共享同一实例（cookie_store 内部分配指针一致）
        let a = fixture.http.client(false, false).expect("默认池");
        let b = fixture.http.client(false, false).expect("默认池");
        assert!(
            std::ptr::eq(
                std::sync::Arc::as_ptr(a.cookie_store()),
                std::sync::Arc::as_ptr(b.cookie_store())
            ),
            "同一池两次取回应为同一实例（连接池复用前提）"
        );
        // 脑裂修复：注册共享 store 后不同池共用同一 CookieStore
        // （FFI 主链路与 JS 桥池同罐，上游单客户端单 CookieStore 语义）
        let c = fixture.http.client(true, false).expect("回环池");
        assert!(
            std::ptr::eq(
                std::sync::Arc::as_ptr(a.cookie_store()),
                std::sync::Arc::as_ptr(c.cookie_store())
            ),
            "注册共享 store 后回环池与默认池应共用同一 CookieStore（脑裂修复）"
        );
        // reset 后四池全部可重建（重建走当前持久化钩子 + 共享 store；
        // store 指针不变、客户端实例必变）
        let before_reset = fixture
            .http
            .client(true, false)
            .expect("回环池（reset 前）");
        fixture.http.reset_clients();
        for (loopback, no_redirect) in [(false, false), (true, false), (false, true), (true, true)]
        {
            let rebuilt = fixture
                .http
                .client(loopback, no_redirect)
                .expect("reset 后共享池应重建成功");
            assert!(
                std::sync::Arc::ptr_eq(before_reset.cookie_store(), rebuilt.cookie_store()),
                "reset 后共享池应复用同一 CookieStore（内容不丢）"
            );
        }
        let after_reset = fixture
            .http
            .client(true, false)
            .expect("回环池（reset 后）");
        assert_ne!(
            before_reset.client_id(),
            after_reset.client_id(),
            "reset 后应重建底层客户端实例"
        );
    }

    /// 共享池 keep-alive 复用证明（2026-09-24 性能专项）：
    /// 同一共享客户端连发 N 次 → 服务端仅 1 次 accept（池内 keep-alive 复用）；
    /// 每请求新建 LegadoClient → N 次 accept（修复前行为，回归对照）。
    /// HTTP 层计数等价反映 TLS 层成本：每新建连接 = 1 次 TCP + 1 次 TLS 握手。
    ///
    /// # 偶发失败加固（2026-10-07）
    ///
    /// **偶发证据**：`b7ffa8365f` 轮 Rust CI（job 112368502807 首次尝试）红于
    /// ①断言（实测 2 次 accept）；同作业重跑绿、最新轮绿、本地连跑 10 次全绿。
    /// CI 日志可读出测试体耗时 ≈10.08s（共享池锁释放 16:08:10.2768 → panic
    /// 16:08:20.3559），与 mock 服务器 10s 读超时吻合。
    ///
    /// **机理**（本地实测复现；产品代码无缺陷）：
    /// - 触发源（客户端连接池，良性）：reqwest/hyper-util `one_connection_for`
    ///   固定让 `checkout` 与 `connect_to` 赛跑；若上一响应连接的异步归还
    ///   （`try_send_request` 的 `on_idle` 任务落池）尚未完成，checkout 为
    ///   Pending，客户端会额外开一条 TCP 连接（该连接照常入池复用）。本地
    ///   20 万次无间隔连续请求实测 6 次幻影连接（≈3e-5/请求，逐连接请求数
    ///   如 [11304, 8696]、[20000, 0]）——CI 每轮 4 次请求转换，量级相符。
    /// - 放大器（测试夹具）：原夹具单线程串行 accept，第二条连接要等第一条
    ///   连接读超时（10s `SO_RCVTIMEO`）才被 accept → 落在新连接上的请求被
    ///   卡 ≈10s（仍成功：客户端读超时 60s）。确定性演示：第二条连接发起
    ///   请求后 9.9986s 收到响应、accept=2——与 CI 的「2 次 accept + 测试体
    ///   ~10s」签名一致。
    ///
    /// **加固**（回归区分度不退让：修复前「每请求新建客户端」= 5 次 accept 必红）：
    /// - ① 请求间插入 `POOL_RETURN_GAP`（10ms）：等上一响应连接归还连接池后
    ///   再发下一请求 ⇒ checkout 首轮即 Ready ⇒ hyper-util 不启动 `connect_to`。
    ///   实测：无间隔 6 幻影/20 万请求 → 1ms 间隔 0 幻影/20 万请求；加固后
    ///   形状回放 1000 轮（5 请求/轮 + 10ms 间隔）0 失败。
    /// - ② 夹具改并发 accept（每连接独立线程）：残余竞争即时呈现为
    ///   「accept=2 断言失败」，不再被 10s 读超时放大成停顿/掩盖失败时序。
    /// - 断言口径不变：①恰 1 次 accept；②恰 N 次新增 accept（1+N 总数）。
    #[test]
    fn test_shared_pool_reuses_keep_alive() {
        let fixture = Fixture::default();
        const N: usize = 5;
        let (addr, accepts) = spawn_counting_keep_alive_server(N + N + 2);
        let base = format!("http://{addr}/");

        // ① 共享客户端（回环池）连发 N 次：应仅 1 次 accept
        let client = fixture.http.client_for_url(&base, false).expect("共享池");
        block_on(async {
            for i in 0..N {
                if i > 0 {
                    // 见上方加固①②：留给上一响应连接归还连接池的时间窗
                    tokio::time::sleep(POOL_RETURN_GAP).await;
                }
                let resp = client.get(&base, None).await.expect("共享池 GET 应成功");
                assert!(resp.status == 200, "状态码应为 200: {}", resp.status);
            }
        });
        let shared_accepts = accepts.load(std::sync::atomic::Ordering::SeqCst);
        assert_eq!(
            shared_accepts, 1,
            "共享池 {N} 次请求应复用同一连接（1 次 accept），实测 {shared_accepts}"
        );

        // ② 每请求新建客户端（修复前行为）连发 N 次：应 N 次 accept
        block_on(async {
            for _ in 0..N {
                let fresh = LegadoClient::new(LegadoClientConfig {
                    no_proxy: true,
                    ..Default::default()
                })
                .expect("新建客户端");
                let resp = fresh.get(&base, None).await.expect("新建客户端 GET 应成功");
                assert!(resp.status == 200, "状态码应为 200: {}", resp.status);
            }
        });
        let total_accepts = accepts.load(std::sync::atomic::Ordering::SeqCst);
        assert_eq!(
            total_accepts,
            1 + N,
            "新建客户端 {N} 次请求应新建 {N} 连接（共 {N}+1 次 accept）"
        );
    }

    /// 共享池连续请求的最小间隔（加固①②：等上一响应连接归还连接池再发
    /// 下一请求，规避 hyper-util checkout/connect 竞争产生的幻影连接；
    /// 实测 1ms 已 0/20 万，取 10 倍余量）
    const POOL_RETURN_GAP: std::time::Duration = std::time::Duration::from_millis(10);

    /// 最小 keep-alive 计数服务器：统计 accept 次数（连接数证据），
    /// 同一连接循环处理多个请求（HTTP/1.1 keep-alive）
    ///
    /// **并发 accept（2026-10-07 加固②）**：每连接独立线程处理；原串行
    /// 版本中第二条连接会滞留内核 backlog，直到第一条连接读超时（10s）
    /// 才被 accept，把客户端侧良性的一次性重连放大成「10s 停顿 + accept
    /// 计数 2」（`test_shared_pool_reuses_keep_alive` 偶发失败根因）。
    /// 并发版让 accept 计数只反映「客户端是否真的开了第二条连接」。
    fn spawn_counting_keep_alive_server(
        max_conns: usize,
    ) -> (
        std::net::SocketAddr,
        std::sync::Arc<std::sync::atomic::AtomicUsize>,
    ) {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind 127.0.0.1:0");
        let addr = listener.local_addr().expect("local_addr");
        let accepts = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let counter = std::sync::Arc::clone(&accepts);
        std::thread::spawn(move || {
            for stream in listener.incoming().take(max_conns) {
                let Ok(mut sock) = stream else { continue };
                counter.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                std::thread::spawn(move || {
                    let _ = sock.set_read_timeout(Some(std::time::Duration::from_secs(10)));
                    // keep-alive：同一连接循环处理请求，直到客户端关闭
                    while let Some(req) = read_mock_http_request(&mut sock) {
                        let _body = if req.method == "HEAD" {
                            String::new()
                        } else {
                            "ok".to_string()
                        };
                        let resp = format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {}\r\nConnection: keep-alive\r\n\r\n{}",
                            _body.len(),
                            _body
                        );
                        if sock.write_all(resp.as_bytes()).is_err() {
                            break;
                        }
                    }
                });
            }
        });
        (addr, accepts)
    }

    // 以下协议用例分别持有自己的四池、后端和 jar，可并行运行。

    /// 内存版 CookiePersistence 测试替身（模拟 `legado-ffi::http_state::DbCookiePersistence`
    /// 的 DB 写回，不涉真实数据库）
    #[derive(Default)]
    struct RecordingPersistence {
        rows: std::sync::Mutex<HashMap<String, String>>,
    }

    impl RecordingPersistence {
        /// 预置一条持久化行（域键 → cookie 串）
        fn seed(&self, domain: &str, cookie: &str) {
            self.rows
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .insert(domain.to_string(), cookie.to_string());
        }

        /// 读一条持久化行
        fn get(&self, domain: &str) -> Option<String> {
            self.rows
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .get(domain)
                .cloned()
        }

        /// 清空全部持久化行
        fn clear(&self) {
            self.rows.lock().unwrap_or_else(|p| p.into_inner()).clear();
        }
    }

    impl CookiePersistence for RecordingPersistence {
        fn load_all(&self) -> Vec<(String, String)> {
            self.rows
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .clone()
                .into_iter()
                .collect()
        }

        fn save(&self, tag: &str, cookie: &str) {
            self.rows
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .insert(tag.to_string(), cookie.to_string());
        }
    }

    /// 写侧门控标记头（批 2）：客户端级用例显式模拟生产注入口
    ///
    /// 生产环境标记由主链路（fetch_page/search）或 JS 桥（按当前书源开关）
    /// 注入；本 helper 仅供直接驱动 `LegadoClient` 的池/冷启动/脑裂机制用例
    /// 显式开启写回。
    fn cookie_jar_marker_headers() -> Option<HashMap<String, String>> {
        let mut headers = HashMap::new();
        headers.insert(COOKIE_JAR_HEADER.to_string(), "1".to_string());
        Some(headers)
    }

    /// 最小 WAF 403 状态机 mock（设计项 A：模拟 x81zws 的 403+Set-Cookie
    /// 挑战；与 `spawn_cookie_echo_on` 同款 std `TcpListener` 模式）
    ///
    /// 行为：请求**不含** `p219_cold=WAF-VAL-7f3b` Cookie 时判为 WAF
    /// 挑战 → 403 + `Set-Cookie: p219_cold=WAF-VAL-7f3b; Path=/`（种下
    /// 状态机会话键，会话 cookie 无 Expires，照常被持久化）；含该
    /// Cookie 时判为状态机通过 → 200，并把 Cookie 请求头原样回显到
    /// `{"cookie":"<原值>"}`。
    fn spawn_waf_403_echo_server(max_conns: usize) -> std::net::SocketAddr {
        const WAF_COOKIE: &str = "p219_cold=WAF-VAL-7f3b";
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind 127.0.0.1:0");
        let addr = listener.local_addr().expect("local_addr");
        std::thread::spawn(move || {
            for stream in listener.incoming().take(max_conns) {
                let Ok(mut sock) = stream else { continue };
                let _ = sock.set_read_timeout(Some(std::time::Duration::from_secs(10)));
                // GET 请求无 body：读到 \r\n\r\n 即请求头结束
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
                let cookie_value = head_str.lines().find_map(|line| {
                    let (name, value) = line.split_once(':')?;
                    name.trim()
                        .eq_ignore_ascii_case("cookie")
                        .then(|| value.trim().to_string())
                });
                let (status, set_cookie_line, body) = match cookie_value {
                    Some(v) if v.contains(WAF_COOKIE) => (
                        "200 OK",
                        String::new(),
                        format!(
                            r#"{{"cookie":{}}}"#,
                            serde_json::to_string(&v).expect("cookie value 序列化")
                        ),
                    ),
                    _ => (
                        "403 Forbidden",
                        format!("Set-Cookie: {WAF_COOKIE}; Path=/\r\n"),
                        r#"{"error":"waf"}"#.to_string(),
                    ),
                };
                let resp = format!(
                    "HTTP/1.1 {status}\r\nContent-Type: application/json\r\n{set_cookie_line}Content-Length: {}\r\nConnection: close\r\n\r\n{}",
                    body.len(),
                    body
                );
                let _ = sock.write_all(resp.as_bytes());
            }
        });
        addr
    }

    #[test]
    fn test_independent_resources_keep_distinct_clients_and_backends() {
        let one = Fixture::default();
        let two = Fixture::default();
        for (loopback, no_redirect) in [(false, false), (true, false), (false, true), (true, true)]
        {
            let a = one.http.client(loopback, no_redirect).unwrap();
            let b = two.http.client(loopback, no_redirect).unwrap();
            assert!(!Arc::ptr_eq(a.cookie_store(), b.cookie_store()));
            let persistence: Arc<dyn CookiePersistence> = one.persistence.clone();
            assert!(Arc::ptr_eq(a.cookie_persistence().unwrap(), &persistence));
        }
        one.http.reset_clients();
        assert!(Arc::ptr_eq(
            two.http.client(true, false).unwrap().cookie_store(),
            &two.store
        ));
    }

    /// 设计项 A 冷启动恢复：403+Set-Cookie 种下状态机 cookie → 写回持久化
    /// 后端 → reset 重建（冷启动模拟）→ 新客户端同域请求携带该 cookie
    /// 通过状态机（200）；P2-19 反例：不相关域（::1 自键 ≠ 127.0.0.1）
    /// 请求头绝不携带
    #[test]
    fn test_persistence_cold_start_same_domain_carried_foreign_never() {
        let fixture = Fixture::default();
        let fake = fixture.persistence.clone();
        fake.clear();
        fixture.http.reset_clients();

        let addr = spawn_waf_403_echo_server(4);
        let url = format!("http://{addr}/waf");

        // ① 初始态（无 cookie）：WAF 挑战 403 + Set-Cookie 种状态机
        //（批 2 写侧门控：本用例直接驱动客户端机制，显式携带标记头模拟生产
        //  注入；无标记 = 不写回为现行不变式，由 net/fetcher 套件钉死）
        let client1 = fixture
            .http
            .client(true, false)
            .expect("回环池（首次构建）");
        let resp1 = block_on(async { client1.get(&url, cookie_jar_marker_headers()).await })
            .expect("首请求应成功（403 非错误）");
        assert_eq!(
            resp1.status, 403,
            "无状态机 cookie 时 WAF 应回 403 挑战: {}",
            resp1.status
        );

        // 写回证据：持久化后端必须持有该域 cookie 行（含会话 cookie）
        let row = fake
            .get("127.0.0.1")
            .expect("Set-Cookie 写回必须进持久化后端（会话 cookie 也持久化）");
        assert!(
            row.contains("p219_cold=WAF-VAL-7f3b"),
            "持久化行必须含 WAF 状态机键: {row}"
        );

        // ② 冷启动模拟：重置池 → 重建（新客户端 jar 从持久化后端预载）
        fixture.http.reset_clients();
        let restarted = Fixture::with_persistence(fake.clone());
        let client2 = restarted
            .http
            .client(true, false)
            .expect("回环池（冷启动重建）");

        // 同域（127.0.0.1）请求必须携带重载的 cookie → 状态机通过 200
        let resp2 =
            block_on(async { client2.get(&url, None).await }).expect("第二请求（冷启动后）应成功");
        assert_eq!(
            resp2.status, 200,
            "冷启动重建后应携带重载 cookie 通过状态机（200）: {}",
            resp2.status
        );
        assert!(
            resp2.body.contains("p219_cold=WAF-VAL-7f3b"),
            "回显 Cookie 头必须含 WAF 状态机键（同域携带证据）: {}",
            resp2.body
        );

        // P2-19 反例（真实请求）：不相关域 ::1（IP 字面量自键 ≠ 127.0.0.1）
        // 请求头不携带该域 cookie
        let foreign_addr = spawn_ipv6_cookie_echo_server(1);
        let foreign_url = format!("http://{foreign_addr}/echo");
        let resp_foreign =
            block_on(async { client2.get(&foreign_url, None).await }).expect("不相关域请求应成功");
        let echoed: serde_json::Value =
            serde_json::from_str(&resp_foreign.body).expect("回显体 JSON");
        let foreign_cookie = echoed
            .get("cookie")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        assert!(
            !foreign_cookie.contains("p219_cold"),
            "不相关域（::1）请求头不携带 127.0.0.1 域 cookie（P2-19 不变式：\
             cookie 持久化与取用一律走 ETLD+1 归一域键，禁止整包跨域注入）: {foreign_cookie}"
        );

        // P2-19 反例（jar 层）：重建后客户端 jar 在不相关域不可见该 cookie
        let foreign_view = client2
            .cookie_store()
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .get_cookie_string("http://[::1]:1/");
        assert!(
            !foreign_view.contains("p219_cold"),
            "重建 jar 的不相关域 cookie 应为空（IP 字面量自键 ::1 ≠ 127.0.0.1）: {foreign_view}"
        );

        // 收尾：清共享实例并重置池（不留残留给后续用例）
        fake.clear();
        fixture.http.reset_clients();
    }

    /// 脑裂回归（x81zws 根因，2026-09-26）：两客户端（回环池 ≙ FFI 主
    /// 链路对回环请求的等价 / 不跟随重定向回环池 ≙ JS 桥 connectNR）
    /// 共享同一内存 CookieStore 后——
    ///
    /// 两池均取 `no_proxy` 直连回环池（P2-17 约定：127.0.0.1 等回环
    /// URL 必须绕过系统/环境变量代理；若走默认池，代理接管时 403
    /// 挑战可能来自代理而非 WAF mock，Set-Cookie 不下发，重种断言
    /// 失去归因性）。
    ///
    /// ① client1 请求吃 403 + Set-Cookie（重种落共享 store）→
    ///    **client2 的下一个请求头必须携带该 cookie**（200 过状态机；
    ///    修复前各池独立 jar，此场景必败——App 内搜索确定性失败的
    ///    复现）；
    /// ② `clear_cookie` 的 J 层清除（清共享 store 域）→ 403 重种 →
    ///    同轮另一客户端可见（上游同款闭环：清与重种同一 store）。
    ///
    /// 修复前红态：`build_pool_client_with(kind, p, None)` 各池独立建
    /// 罐，client1 的重种只进 client1 自身 jar + 持久化后端；已构建且
    /// 不 reset 的 client2 下一请求仍用旧 jar → WAF 状态机再挑战 403。
    /// 绿态：池复用同一 `Arc<RwLock<CookieStore>>`，重种同轮跨池可见。
    #[test]
    fn test_split_brain_shared_store_cross_pool_same_round() {
        let fixture = Fixture::default();
        let fake = fixture.persistence.clone();
        fake.clear();
        // 清共享 store 残留 WAF 键（防跨用例污染，保证以下断言可
        // 归因于本用例的 403 重种）
        fixture
            .store
            .clone()
            .write()
            .unwrap_or_else(|p| p.into_inner())
            .remove_domain("127.0.0.1");
        fixture.http.reset_clients();

        let addr = spawn_waf_403_echo_server(4);
        let url = format!("http://{addr}/waf");

        // 双客户端预建（模拟 App 内搜索主链路与 JS 桥同时存活），
        // 且必须同罐（脑裂修复前提）；均为 no_proxy 直连回环池
        // （P2-17：回环 URL 不经过系统/环境变量代理）
        let client1 = fixture
            .http
            .client(true, false)
            .expect("回环池（client1，FFI 主链路对回环请求的等价）");
        let client2 = fixture
            .http
            .client(true, true)
            .expect("不跟随重定向回环池（client2，JS 桥 connectNR 等价）");
        assert!(
            std::sync::Arc::ptr_eq(client1.cookie_store(), client2.cookie_store()),
            "两池必须共享同一 CookieStore（脑裂修复前提）"
        );

        // ① client1 首请求：无 WAF cookie → 403 挑战 + Set-Cookie 重种
        //（批 2 写侧门控：显式携带标记头模拟生产注入口，同冷启动用例）
        let resp1 = block_on(async { client1.get(&url, cookie_jar_marker_headers()).await })
            .expect("client1 首请求应成功（403 非错误）");
        assert_eq!(
            resp1.status, 403,
            "无状态机 cookie 时 WAF 应回 403 挑战: {}",
            resp1.status
        );
        // 重种证据：共享 store 域键已含 WAF 键（用真实 `url` 解析域键；
        // 勿写字面量模板——`assert!` 无参时不做字符串插值）
        {
            let shared = fixture.store.clone();
            let store = shared.read().unwrap_or_else(|p| p.into_inner());
            assert!(
                store
                    .get_cookie_string(&url)
                    .contains("p219_cold=WAF-VAL-7f3b"),
                "403 Set-Cookie 重种必须落共享 store"
            );
        }

        // ② client2 下一请求（中间无池 reset，与预建同一实例）：
        // 请求头必须携带该 cookie → 200 过状态机（修复前必败场景）
        let resp2 = block_on(async { client2.get(&url, None).await })
            .expect("client2 请求应成功（同轮重种应过状态机）");
        assert_eq!(
            resp2.status, 200,
            "client1 403 重种后 client2 下一请求必须携带该 cookie（共享 store 同轮可见）: {}",
            resp2.status
        );
        assert!(
            resp2.body.contains("p219_cold=WAF-VAL-7f3b"),
            "client2 回显 Cookie 头必须含 WAF 状态机键: {}",
            resp2.body
        );

        // ③ clear_cookie 的 J 层清除（清共享 store 域）→ 403 重种 →
        //    同轮另一客户端可见（清与重种同一 store，上游同款闭环）
        fixture
            .store
            .clone()
            .write()
            .unwrap_or_else(|p| p.into_inner())
            .remove_domain("127.0.0.1");
        // 批 2 写侧门控：清除后的 403 重种请求同样显式携带标记头
        let resp3 = block_on(async { client2.get(&url, cookie_jar_marker_headers()).await })
            .expect("清除后 client2 再挑战请求应成功");
        assert_eq!(
            resp3.status, 403,
            "J 层清除后下一请求应再被 WAF 挑战（重种闭环前提）: {}",
            resp3.status
        );
        let resp4 = block_on(async { client1.get(&url, None).await })
            .expect("同轮重种后 client1 请求应成功");
        assert_eq!(
            resp4.status, 200,
            "清除后 403 重种必须同轮对 client1 可见（清/重种同一共享 store）: {}",
            resp4.status
        );

        // 收尾：清共享实例并重置池（不留残留给后续用例）
        fake.clear();
        fixture
            .store
            .clone()
            .write()
            .unwrap_or_else(|p| p.into_inner())
            .remove_domain("127.0.0.1");
        fixture.http.reset_clients();
    }

    /// 批 2 门控用例服务器：记录每个请求头全文，响应 200 +
    /// `Set-Cookie: p219_jsgate=GATE-VAL; Path=/` + JSON 体
    ///
    /// POST/PUT 入口（表驱动用例）按 `Content-Length` 读尽请求体后再响应，
    /// 避免服务端未读 body 即关闭连接触发 RST 吞掉响应；HEAD 入口响应体为空。
    fn spawn_gate_recording_server(
        max_conns: usize,
    ) -> (std::net::SocketAddr, Arc<std::sync::Mutex<Vec<String>>>) {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind 127.0.0.1:0");
        let addr = listener.local_addr().expect("local_addr");
        let seen = Arc::new(std::sync::Mutex::new(Vec::new()));
        let seen_srv = Arc::clone(&seen);
        std::thread::spawn(move || {
            for stream in listener.incoming().take(max_conns) {
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
                let head_str = String::from_utf8_lossy(&head).into_owned();
                // POST/PUT 请求体读尽（GET/HEAD Content-Length 缺省 0）
                let content_length = head_str
                    .lines()
                    .find_map(|line| {
                        let (k, v) = line.split_once(':')?;
                        k.eq_ignore_ascii_case("content-length")
                            .then(|| v.trim().parse::<usize>().ok())
                            .flatten()
                    })
                    .unwrap_or(0);
                if content_length > 0 {
                    let mut body_buf = vec![0u8; content_length];
                    if sock.read_exact(&mut body_buf).is_err() {
                        continue;
                    }
                }
                let is_head = head_str
                    .lines()
                    .next()
                    .is_some_and(|l| l.to_ascii_uppercase().starts_with("HEAD "));
                if let Ok(mut guard) = seen_srv.lock() {
                    guard.push(head_str);
                }
                let body = if is_head { "" } else { r#"{"ok":true}"# };
                let resp = format!(
                    "HTTP/1.1 200 OK\r\nSet-Cookie: p219_jsgate=GATE-VAL; Path=/\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = sock.write_all(resp.as_bytes());
            }
        });
        (addr, seen)
    }

    /// 批 2：JS 桥（`ajax` 路径）写侧门控开/关/未绑定三态
    ///
    /// - 开（tag 对应源 `enabledCookieJar=true`）→ 响应 `Set-Cookie` 落库，
    ///   且标记头发送前剥离（服务器收到的请求头不含 `CookieJar`）；
    /// - 关（false）→ 不落库；
    /// - 未绑定 tag → 查不到 → 不落库。
    #[test]
    fn test_ajax_cookie_jar_gate_by_current_source() {
        let fixture = Fixture::default();
        use crate::host_api::current_source;

        let fake = fixture.persistence.clone();
        fake.clear();
        fixture.http.reset_clients();

        const TAG_ON: &str = "https://jsgate-on.example.com/";
        const TAG_OFF: &str = "https://jsgate-off.example.com/";
        {
            let mut gates = fixture.gates.lock().unwrap_or_else(|p| p.into_inner());
            gates.insert(TAG_ON.to_string(), true);
            gates.insert(TAG_OFF.to_string(), false);
        }

        // ① 开：响应 Set-Cookie 落库 + 标记头剥离
        let (addr_on, seen_on) = spawn_gate_recording_server(2);
        current_source::with_current_source_tag(TAG_ON, || {
            ajax(
                &fixture.http.request(),
                &format!(r#"{{"url":"http://{addr_on}/echo"}}"#),
            )
            .expect("开态 ajax 应成功")
        });
        let saved_on = fake.get("127.0.0.1").unwrap_or_default();
        assert!(
            saved_on.contains("p219_jsgate=GATE-VAL"),
            "开态（书源 enabledCookieJar=true）ajax 响应 Set-Cookie 必须落库: {saved_on:?}"
        );
        let head_on = seen_on
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .join("\n")
            .to_ascii_lowercase();
        assert!(
            !head_on.contains("cookiejar:"),
            "内部标记头必须发送前剥离（不得出网）: {head_on}"
        );

        // ② 关：tag → false → 不落库
        fake.clear();
        let (addr_off, _seen_off) = spawn_gate_recording_server(2);
        current_source::with_current_source_tag(TAG_OFF, || {
            ajax(
                &fixture.http.request(),
                &format!(r#"{{"url":"http://{addr_off}/echo"}}"#),
            )
            .expect("关态 ajax 应成功")
        });
        assert_eq!(
            fake.get("127.0.0.1"),
            None,
            "关态（enabledCookieJar=false）ajax 响应 Set-Cookie 不得落库"
        );

        // ③ 未绑定 tag（None）→ 不落库
        fake.clear();
        let (addr_unbound, _seen_unbound) = spawn_gate_recording_server(2);
        current_source::clear_current_source_tag();
        ajax(
            &fixture.http.request(),
            &format!(r#"{{"url":"http://{addr_unbound}/echo"}}"#),
        )
        .expect("未绑定 ajax 应成功");
        assert_eq!(
            fake.get("127.0.0.1"),
            None,
            "未绑定书源 ajax 响应 Set-Cookie 不得落库（未注册/查不到按关）"
        );

        // 收尾：清共享实例并重置池（不留残留给后续用例）
        fake.clear();
        fixture.http.reset_clients();
    }

    /// 批 2 收尾：JS 桥其余 9 个网络入口的表驱动写侧门控三态用例
    ///
    /// 入口：`http_get` / `http_post` / `http_head` / `ajax_request_body` /
    /// `ajax_all` / `connect_full` / `connect_no_redirect` / `head_full` /
    /// `post_full`（`ajax` 标准 JSON 路径已有深度用例；其 "url,{json}" 分支
    /// 由本表的 `ajax_request_body` 直调覆盖）。每个入口断言三态：
    /// - 开（tag → enabledCookieJar=true）→ 响应 Set-Cookie 落库，
    ///   且内部标记头 wire 上不存在（发送前剥离）；
    /// - 关（false）→ 不落库；
    /// - 未绑定 tag → 不落库。
    ///
    /// 本用例只钉「接线存在性 + 门控行为」，不做入口各自的深度行为断言。
    #[test]
    fn test_js_network_entrypoints_cookie_jar_gate_three_states_table() {
        let fixture = Fixture::default();
        use crate::host_api::current_source;

        let fake = fixture.persistence.clone();

        const TAG_ON: &str = "https://jsgate-table-on.example.com/";
        const TAG_OFF: &str = "https://jsgate-table-off.example.com/";
        {
            let mut gates = fixture.gates.lock().unwrap_or_else(|p| p.into_inner());
            gates.insert(TAG_ON.to_string(), true);
            gates.insert(TAG_OFF.to_string(), false);
        }

        /// 入口调用表：名称 +（url → Result）；闭包内只做一行调用，
        /// 钉各入口到 `apply_source_cookie_jar_gate` 的接线存在性。
        type EntryCall = fn(&HttpResources, &str) -> Result<String, String>;
        let entries: &[(&str, EntryCall)] = &[
            ("http_get", |http, url| http_get(&http.request(), url, None)),
            ("http_post", |http, url| {
                http_post(&http.request(), url, "a=1", None)
            }),
            ("http_head", |http, url| http_head(&http.request(), url)),
            ("ajax_request_body", |http, url| {
                ajax_request_body(
                    &http.request(),
                    &HttpOptions {
                        url: url.to_string(),
                        ..Default::default()
                    },
                )
            }),
            ("ajax_all", |http, url| {
                ajax_all(&http.request(), &serde_json::json!([url]).to_string())
            }),
            ("connect_full", |http, url| {
                connect_full(&http.request(), url, Some("GET"), None, None, Some(10_000))
            }),
            ("connect_no_redirect", |http, url| {
                connect_no_redirect(&http.request(), url, Some("GET"), None, None)
            }),
            ("head_full", |http, url| {
                head_full(&http.request(), url, None)
            }),
            ("post_full", |http, url| {
                post_full(&http.request(), url, "a=1", None)
            }),
        ];

        for (name, call) in entries {
            // ① 开（enabledCookieJar=true）：Set-Cookie 落库 + 标记不出网
            fake.clear();
            fixture.http.reset_clients();
            let (addr_on, seen_on) = spawn_gate_recording_server(2);
            let url_on = format!("http://{addr_on}/echo");
            current_source::with_current_source_tag(TAG_ON, || {
                call(&fixture.http, &url_on).unwrap_or_else(|e| panic!("{name} 开态调用失败: {e}"));
            });
            assert!(
                fake.get("127.0.0.1")
                    .unwrap_or_default()
                    .contains("p219_jsgate=GATE-VAL"),
                "{name} 开态（enabledCookieJar=true）响应 Set-Cookie 必须落库"
            );
            let head_on = seen_on
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .join("\n")
                .to_ascii_lowercase();
            assert!(
                !head_on.contains("cookiejar:"),
                "{name} 内部标记头必须发送前剥离（不得出网）: {head_on}"
            );

            // ② 关（false）：不落库
            fake.clear();
            fixture.http.reset_clients();
            let (addr_off, _seen_off) = spawn_gate_recording_server(2);
            let url_off = format!("http://{addr_off}/echo");
            current_source::with_current_source_tag(TAG_OFF, || {
                call(&fixture.http, &url_off)
                    .unwrap_or_else(|e| panic!("{name} 关态调用失败: {e}"));
            });
            assert_eq!(
                fake.get("127.0.0.1"),
                None,
                "{name} 关态（enabledCookieJar=false）响应 Set-Cookie 不得落库"
            );

            // ③ 未绑定 tag：不落库
            fake.clear();
            fixture.http.reset_clients();
            let (addr_unbound, _seen_unbound) = spawn_gate_recording_server(2);
            let url_unbound = format!("http://{addr_unbound}/echo");
            current_source::clear_current_source_tag();
            call(&fixture.http, &url_unbound)
                .unwrap_or_else(|e| panic!("{name} 未绑定态调用失败: {e}"));
            assert_eq!(
                fake.get("127.0.0.1"),
                None,
                "{name} 未绑定书源响应 Set-Cookie 不得落库（查不到按关）"
            );
        }

        // 收尾：清共享实例并重置池（不留残留给后续用例）
        fake.clear();
        fixture.http.reset_clients();
    }

    #[test]
    fn test_explicit_backend_preloads_without_overwriting_live_cookie() {
        let plain = HttpResources::default();
        assert!(
            plain
                .client(true, false)
                .unwrap()
                .cookie_persistence()
                .is_none()
        );
        assert_eq!(plain.cookies_for_url("http://127.0.0.1:1/"), "");
        let fixture = Fixture::default();
        fixture.persistence.seed("127.0.0.1", "loaded=old");
        let first = fixture.http.client(true, false).unwrap();
        assert_eq!(
            fixture.http.cookies_for_url("http://127.0.0.1:1/"),
            "loaded=old"
        );
        fixture.http.set_cookie("127.0.0.1", "loaded=new");
        fixture.http.reset_clients();
        let rebuilt = fixture.http.client(true, false).unwrap();
        assert_ne!(first.client_id(), rebuilt.client_id());
        assert!(Arc::ptr_eq(first.cookie_store(), rebuilt.cookie_store()));
        assert_eq!(
            fixture.http.cookies_for_url("http://127.0.0.1:1/"),
            "loaded=new"
        );
    }

    /// 测试 connect_full 不支持的 HTTP 方法
    #[test]
    fn test_connect_full_unsupported_method() {
        let fixture = Fixture::default();
        let result = connect_full(
            &fixture.http.request(),
            "https://httpbin.org/get",
            Some("PATCH"),
            None,
            None,
            None,
        );
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("unsupported method"));
    }

    /// 测试 connect_full GET 请求（返回完整响应 JSON，本地回环 mock：`/get` 回显）
    #[test]
    fn test_connect_full_get() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let resp_json = connect_full(
            &fixture.http.request(),
            &format!("http://{addr}/get"),
            Some("GET"),
            None,
            None,
            Some(10000),
        )
        .expect("connect_full GET 到本地回环 mock 应成功");
        let resp: HttpResponse = serde_json::from_str(&resp_json).expect("响应应可解析");
        assert_eq!(
            resp.status_code, 200,
            "mock 服务器应返回 200: {}",
            resp.body
        );
        assert!(!resp.body.is_empty(), "GET 响应体不应为空");
        assert!(
            is_valid_response(&resp.body),
            "响应应为 JSON 对象: {}",
            resp.body
        );
    }

    /// 测试 head_full 返回完整响应 JSON（本地回环 mock：HEAD `/get`）
    #[test]
    fn test_head_full() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let resp_json = head_full(&fixture.http.request(), &format!("http://{addr}/get"), None)
            .expect("head_full 到本地回环 mock 应成功");
        let resp: HttpResponse = serde_json::from_str(&resp_json).expect("响应应可解析");
        assert_eq!(
            resp.status_code, 200,
            "HEAD 请求应得到 200 状态码（mock 服务器行为）"
        );
    }

    /// 测试 post_full 返回完整响应 JSON
    ///
    /// 目标必须是 httpbin `/post`（POST `/get` 返回 405，200 守卫恒不成立，
    /// 断言空转——P2-19 审查发现）；本地 mock 同样只对 `/post` 回显。
    #[test]
    fn test_post_full() {
        let fixture = Fixture::default();
        let addr = spawn_httpbin_mock(4);
        let resp_json = post_full(
            &fixture.http.request(),
            &format!("http://{addr}/post"),
            r#"{"key":"value"}"#,
            Some(r#"{"Content-Type":"application/json"}"#),
        )
        .expect("post_full 到本地回环 mock 应成功");
        let resp: HttpResponse = serde_json::from_str(&resp_json).expect("响应应可解析");
        assert_eq!(
            resp.status_code, 200,
            "mock 服务器应返回 200: {}",
            resp.body
        );
        // mock /post 回显请求 JSON（`data`/`json` 字段），`key` 必须出现
        assert!(
            resp.body.contains("key"),
            "回显体应含请求字段 key: {}",
            resp.body
        );
    }

    /// 最小本地回环 Cookie 回显服务器（P2-19 泄漏复现的确定性替身）
    ///
    /// 行为：把收到的 `Cookie` **请求头**原样回显到 200 响应体的
    /// `{"cookie":"<原值>"}`；请求不带 Cookie 头时回显 `{"cookie":null}`。
    ///
    /// 与 P2-17 的 `spawn_search_loopback_server` 同款 std `TcpListener` 模式
    /// （legado-js 的 quickjs tokio feature 无 net）；回环流量经 `no_proxy`
    /// 豁免系统/环境变量代理（见回环共享池 `PoolKind::Loopback` /
    /// connectNR 约定）。
    fn spawn_cookie_echo_server(max_conns: usize) -> std::net::SocketAddr {
        spawn_cookie_echo_on("127.0.0.1:0", max_conns)
    }

    /// IPv6 回环 `[::1]` 版 Cookie 回显服务器（设计项 A 的 P2-19 反例
    /// 用：`::1` 的 IP 字面量自键 ≠ `127.0.0.1`，为真正的不相关域）
    fn spawn_ipv6_cookie_echo_server(max_conns: usize) -> std::net::SocketAddr {
        spawn_cookie_echo_on("[::1]:0", max_conns)
    }

    /// 回显服务器通用实现（绑定地址参数化：`127.0.0.1:0` / `[::1]:0`）
    fn spawn_cookie_echo_on(bind_addr: &str, max_conns: usize) -> std::net::SocketAddr {
        let listener = std::net::TcpListener::bind(bind_addr)
            .unwrap_or_else(|_| panic!("bind {bind_addr} 失败"));
        let addr = listener.local_addr().expect("local_addr");
        std::thread::spawn(move || {
            for stream in listener.incoming().take(max_conns) {
                let Ok(mut sock) = stream else { continue };
                let _ = sock.set_read_timeout(Some(std::time::Duration::from_secs(10)));
                // GET 请求无 body：读到 \r\n\r\n 即请求头结束
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
                // 头名忽略大小写匹配，但**保留 Cookie 值原样**（回显必须逐字节忠实，
                // 否则断言会因大小写失真误判）
                let cookie_value = head_str.lines().find_map(|line| {
                    let (name, value) = line.split_once(':')?;
                    name.trim()
                        .eq_ignore_ascii_case("cookie")
                        .then(|| value.trim().to_string())
                });
                let body = match cookie_value {
                    Some(value) => format!(
                        r#"{{"cookie":{}}}"#,
                        serde_json::to_string(&value).expect("cookie value 序列化")
                    ),
                    None => r#"{"cookie":null}"#.to_string(),
                };
                let resp = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    body.len(),
                    body
                );
                let _ = sock.write_all(resp.as_bytes());
            }
        });
        addr
    }

    /// P2-19「跨源不泄漏」用例**改写为上游语义**（2026-09-23 用户裁决：同步上游
    /// 「cookie 属于域名，不属于书源」）：
    /// - 同域共享：向回环域（IP 字面量自键 `127.0.0.1`）写一次 cookie，
    ///   在**不同书源上下文**（TAG_A / TAG_B）发同一回环请求，均必须携带——
    ///   cookie 取用口径是「请求 URL 属域」，与书源 tag 无关（原「tag 维度」
    ///   语义已废）；
    /// - P2-19 不变式保留：异域（`f.book.com.cn`）写入的 cookie **绝不携带**
    ///   进回环请求。
    ///
    /// 原用例断言「源 B 的 cookie 不得出现在源 A 的请求头」；新口径下源 A/B 的
    /// book.com.cn 域 cookie 本就不属回环域，故改写为「异域不携带」+「同域共享」。
    #[test]
    fn test_p219_ajax_cookie_same_domain_shared_foreign_never_carried() {
        let fixture = Fixture::default();
        use crate::host_api::current_source;

        const TAG_A: &str = "https://www.a.book.com.cn/";
        const TAG_B: &str = "https://www.b.book.com.cn/";
        const FOREIGN_URL: &str = "https://www.f.book.com.cn/";
        const FOREIGN_KEY: &str = "f.book.com.cn"; // com.cn 多段 TLD → 末三段

        let addr = spawn_cookie_echo_server(4);
        let loopback_key = format!("http://{addr}/"); // 归一后域名键 = "127.0.0.1"
        fixture.http.cookies().clear(&loopback_key);
        fixture.http.cookies().clear(FOREIGN_URL);
        fixture.http.cookies().clear(FOREIGN_KEY);
        fixture
            .http
            .set_cookie(&loopback_key, "p219_sync=SYNC-VAL-1f8a");
        // 异域 cookie：绝不泄漏进回环请求（P2-19 不变式）
        fixture
            .http
            .set_cookie(FOREIGN_URL, "p219_foreign=F-VAL-6c2e");

        // 书源 A 上下文
        let resp_a = current_source::with_current_source_tag(TAG_A, || {
            ajax(
                &fixture.http.request(),
                &format!(r#"{{"url":"http://{addr}/echo"}}"#),
            )
            .expect("ajax to loopback cookie-echo server (tag A)")
        });
        // 书源 B 上下文：同一请求 URL → 同域 cookie 跨书源共享
        let resp_b = current_source::with_current_source_tag(TAG_B, || {
            ajax(
                &fixture.http.request(),
                &format!(r#"{{"url":"http://{addr}/echo"}}"#),
            )
            .expect("ajax to loopback cookie-echo server (tag B)")
        });

        fixture.http.cookies().clear(&loopback_key);
        fixture.http.cookies().clear(FOREIGN_URL);
        fixture.http.cookies().clear(FOREIGN_KEY);

        for (ctx, resp_json) in [("A", resp_a), ("B", resp_b)] {
            let resp: HttpResponse = serde_json::from_str(&resp_json).expect("ajax 响应 JSON");
            assert_eq!(resp.status_code, 200, "回显服务器应返回 200: {}", resp.body);
            let echoed: serde_json::Value = serde_json::from_str(&resp.body).expect("回显体 JSON");
            let cookie_str = echoed
                .get("cookie")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            assert!(
                cookie_str.contains("p219_sync=SYNC-VAL-1f8a"),
                "同域（回环）cookie 必须跨书源共享（上游语义：cookie 属于域名），\
                 书源 {ctx} 上下文实际 Cookie 为: {cookie_str}"
            );
            assert!(
                !cookie_str.contains("p219_foreign"),
                "异域 cookie 绝不携带（P2-19 不变式），书源 {ctx} 上下文实际 Cookie 为: {cookie_str}"
            );
        }
    }

    /// P2-19「未归属不携带」用例**改写为上游语义**（2026-09-23 用户裁决：同步上游，
    /// 本批取消 P2-19 的「未归属不携带」收紧）：未归属上下文（字典规则/自动任务
    /// 等无书源绑定的 JS 执行路径）向某域发请求时，**仍必须携带该域 cookie**——
    /// 上游 `CookieManager.loadRequest` 按**请求 URL** 取 cookie，与书源上下文无关。
    /// 异域（x/y.book.com.cn）cookie 依旧绝不携带（P2-19 不变式保留）。
    #[test]
    fn test_p219_ajax_cookie_unowned_carries_request_domain_cookie() {
        let fixture = Fixture::default();
        use crate::host_api::current_source;

        const TAG_X: &str = "https://www.x.book.com.cn/";
        const TAG_Y: &str = "https://www.y.book.com.cn/";
        const DK_X: &str = "x.book.com.cn"; // com.cn 多段 TLD → 末三段
        const DK_Y: &str = "y.book.com.cn";

        let addr = spawn_cookie_echo_server(2);
        let loopback_key = format!("http://{addr}/"); // 归一后域名键 = "127.0.0.1"
        fixture.http.cookies().clear(&loopback_key);
        fixture.http.cookies().clear(TAG_X);
        fixture.http.cookies().clear(TAG_Y);
        fixture.http.cookies().clear(DK_X);
        fixture.http.cookies().clear(DK_Y);
        fixture
            .http
            .set_cookie(&loopback_key, "p219_unowned=UN-VAL-3d9e");
        // 异域 cookie：未归属请求异域时依旧绝不携带
        fixture.http.set_cookie(TAG_X, "p219_tokenX=X-VAL-5e2b");
        fixture.http.set_cookie(TAG_Y, "p219_tokenY=Y-VAL-c44a");

        current_source::clear_current_source_tag(); // 确保未归属
        let resp_json = ajax(
            &fixture.http.request(),
            &format!(r#"{{"url":"http://{addr}/echo"}}"#),
        )
        .expect("ajax to loopback cookie-echo server");

        fixture.http.cookies().clear(&loopback_key);
        fixture.http.cookies().clear(TAG_X);
        fixture.http.cookies().clear(TAG_Y);
        fixture.http.cookies().clear(DK_X);
        fixture.http.cookies().clear(DK_Y);

        let resp: HttpResponse = serde_json::from_str(&resp_json).expect("ajax 响应 JSON");
        assert_eq!(resp.status_code, 200, "回显服务器应返回 200: {}", resp.body);
        let echoed: serde_json::Value = serde_json::from_str(&resp.body).expect("回显体 JSON");
        let cookie_str = echoed
            .get("cookie")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        assert!(
            cookie_str.contains("p219_unowned=UN-VAL-3d9e"),
            "未归属上下文请求回环域时必须携带该域 cookie（上游语义，本批取消收紧），实际: {cookie_str}"
        );
        assert!(
            !cookie_str.contains("p219_tokenX") && !cookie_str.contains("p219_tokenY"),
            "异域 cookie 绝不携带（P2-19 不变式），实际: {cookie_str}"
        );
    }

    /// `merge_global_cookie` 单元口径（上游同步改写）：Cookie 头按**请求 URL** 的
    /// 属域取（不再按当前书源 tag）——请求 URL 属域写过的 cookie 必须携带，
    /// 不相关域名的 cookie 绝不注入（P2-19 不变式）。不走真实网络，确定性快。
    #[test]
    fn test_merge_global_cookie_keyed_by_request_url() {
        let fixture = Fixture::default();
        use crate::host_api::current_source;

        // book.com.cn（com.cn 多段 TLD → 末三段）与 other-site.com（.com 末两段）
        const REQ_URL: &str = "https://unit-a.book.com.cn/page";
        const OTHER_URL: &str = "https://unit-b.other-site.com/page";
        const DK_A: &str = "book.com.cn";
        const DK_B: &str = "other-site.com";

        fixture.http.cookies().clear(REQ_URL);
        fixture.http.cookies().clear(OTHER_URL);
        fixture.http.cookies().clear(DK_A);
        fixture.http.cookies().clear(DK_B);
        fixture.http.set_cookie(REQ_URL, "p219_uA=uA-val");
        fixture.http.set_cookie(OTHER_URL, "p219_uB=uB-val");

        current_source::clear_current_source_tag();
        let headers_a = merge_global_cookie(&fixture.http.request(), HashMap::new(), REQ_URL);
        let headers_b = merge_global_cookie(&fixture.http.request(), HashMap::new(), OTHER_URL);

        fixture.http.cookies().clear(REQ_URL);
        fixture.http.cookies().clear(OTHER_URL);
        fixture.http.cookies().clear(DK_A);
        fixture.http.cookies().clear(DK_B);

        let cookie_a = headers_a.get("Cookie").cloned().unwrap_or_default();
        assert!(
            cookie_a.contains("p219_uA=uA-val"),
            "请求 URL 属域写过的 cookie 必须携带: {cookie_a}"
        );
        assert!(
            !cookie_a.contains("p219_uB"),
            "不相关域名的 cookie 绝不携带（P2-19 不变式）: {cookie_a}"
        );
        let cookie_b = headers_b.get("Cookie").cloned().unwrap_or_default();
        assert!(
            cookie_b.contains("p219_uB=uB-val"),
            "请求 URL 属域写过的 cookie 必须携带: {cookie_b}"
        );
        assert!(
            !cookie_b.contains("p219_uA"),
            "不相关域名的 cookie 绝不携带（P2-19 不变式）: {cookie_b}"
        );
    }

    /// 未归属上下文单元口径（上游同步改写）：Cookie 头按**请求 URL** 属域取——
    /// 请求 URL 属域未写过 cookie 时不注入 Cookie 头（异域已写入的 cookie
    /// 绝不注入，P2-19 不变式）。用例域为独有域名，避免与并行用例共享键。
    #[test]
    fn test_merge_global_cookie_unowned_no_cookie_for_unwritten_domain() {
        let fixture = Fixture::default();
        use crate::host_api::current_source;

        // 独有域名（本用例专用，不与其它并行用例共享键）
        const WRITE_URL: &str = "https://unitz.unitzeta.com/"; // → 域名键 unitzeta.com
        const REQ_URL: &str = "https://unitq.uniteta.com/x"; // → 域名键 uniteta.com
        const DK_WRITE: &str = "unitzeta.com";
        const DK_REQ: &str = "uniteta.com";

        fixture.http.cookies().clear(WRITE_URL);
        fixture.http.cookies().clear(DK_WRITE);
        fixture.http.cookies().clear(DK_REQ);
        fixture.http.set_cookie(WRITE_URL, "p219_uZ=uZ-val");

        current_source::clear_current_source_tag(); // 确保未归属
        let headers = merge_global_cookie(&fixture.http.request(), HashMap::new(), REQ_URL);
        fixture.http.cookies().clear(WRITE_URL);
        fixture.http.cookies().clear(DK_WRITE);
        fixture.http.cookies().clear(DK_REQ);

        assert!(
            !headers.contains_key("Cookie"),
            "请求 URL 属域未写过 cookie 时不得注入 Cookie 头（异域 cookie 绝不注入）: {:?}",
            headers.get("Cookie")
        );
    }
}
