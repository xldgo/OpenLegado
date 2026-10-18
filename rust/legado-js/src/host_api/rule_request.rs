//! 脚本规则请求：同步复用当前VM，统一Parser解析与Net发送。
use super::network::{self, HttpOptions, HttpResponse};
use crate::http_resources::RequestResources;
use legado_net::{LegadoRawResponse, LegadoRequest, Method};
use legado_parser::analyze_url::SynchronousJsEvaluator;
use legado_parser::{AnalyzeUrl, RequestMethod};
use std::collections::HashMap;

/// 回调仅借用当前Ctx，不重新获取Runtime/引擎缓存锁，也不重置外层deadline。
pub(super) struct ContextEvaluator<'js> {
    ctx: rquickjs::Ctx<'js>,
    saved: Vec<(&'static str, Option<rquickjs::Value<'js>>)>,
}
impl<'js> ContextEvaluator<'js> {
    pub fn new(ctx: rquickjs::Ctx<'js>) -> rquickjs::Result<Self> {
        let globals = ctx.globals();
        let mut saved = Vec::new();
        for name in ["result", "baseUrl", "page"] {
            let value = if globals.contains_key(name)? {
                Some(globals.get(name)?)
            } else {
                None
            };
            saved.push((name, value));
        }
        Ok(Self { ctx, saved })
    }
}
impl Drop for ContextEvaluator<'_> {
    fn drop(&mut self) {
        let globals = self.ctx.globals();
        for (name, value) in self.saved.drain(..) {
            // 原属性可写时恢复；清理不覆盖原请求的异常返回。
            let _ = match value {
                Some(v) => globals.set(name, v),
                None => globals.remove(name),
            };
        }
    }
}
impl SynchronousJsEvaluator for ContextEvaluator<'_> {
    fn execute_js(&self, code: &str) -> Result<String, String> {
        let mut options = rquickjs::context::EvalOptions::default();
        options.strict = false;
        options.global = true;
        self.ctx
            .eval_with_options::<rquickjs::Value, _>(code, options)
            .map(|value| crate::QuickJsEngine::result_to_string(&self.ctx, &value))
            .map_err(|_| crate::QuickJsEngine::take_exception_message(&self.ctx))
    }
    fn execute_js_with_result(&self, code: &str, result_json: &str) -> Result<String, String> {
        self.execute_js(&format!("globalThis.result={result_json};\n{code}"))
    }
}

/// 请求增强参数只在边界覆盖，普通URL规则不走另一套JSON拆分算法。
#[derive(Default)]
pub(super) struct RequestOverrides<'a> {
    pub method: Option<&'a str>,
    pub headers: Option<&'a str>,
    pub body: Option<&'a str>,
    pub timeout: Option<u64>,
}

pub(super) fn ajax(
    resources: &RequestResources<'_>,
    input: &str,
    timeout: Option<u64>,
    evaluator: Option<&dyn SynchronousJsEvaluator>,
) -> Result<String, String> {
    let input = input.trim();
    let standard_json = input.starts_with('{') && !input.starts_with("{{");
    let response = if standard_json {
        let options: HttpOptions =
            serde_json::from_str(input).map_err(|e| format!("ajax parse options error: {e}"))?;
        let headers = serde_json::to_string(&options.headers.clone().unwrap_or_default())
            .map_err(|e| e.to_string())?;
        execute(
            resources,
            &options.url,
            RequestOverrides {
                method: options.method.as_deref(),
                headers: Some(&headers),
                body: options.body.as_deref(),
                timeout: timeout.or(options.timeout_ms),
            },
            evaluator,
        )
    } else {
        execute(
            resources,
            input,
            RequestOverrides {
                timeout,
                ..Default::default()
            },
            evaluator,
        )
    }?;
    if standard_json {
        serde_json::to_string(&response).map_err(|e| e.to_string())
    } else {
        Ok(response.body)
    }
}

fn merge_headers(
    target: &mut HashMap<String, String>,
    incoming: impl IntoIterator<Item = (String, String)>,
) {
    for (name, value) in incoming {
        target.retain(|key, _| !key.eq_ignore_ascii_case(&name));
        target.insert(name, value);
    }
}

/// 准备阶段结束即释放当前 VM 的临时绑定，网络等待只持有普通 Rust 数据。
pub(super) struct PreparedRequest {
    parsed: AnalyzeUrl,
    request: LegadoRequest,
    timeout: u64,
    proxy: Option<legado_net::ProxyConfig>,
}
impl PreparedRequest {
    pub fn url(&self) -> &str {
        &self.request.url
    }

    pub async fn wait(
        &self,
        policy: &crate::http_request_policy::RequestPolicySnapshot,
        skip: bool,
    ) {
        if !self.parsed.is_data_uri() {
            policy.acquire(skip).await;
        }
    }
}

pub(super) fn execute(
    resources: &RequestResources<'_>,
    input: &str,
    overrides: RequestOverrides<'_>,
    evaluator: Option<&dyn SynchronousJsEvaluator>,
) -> Result<HttpResponse, String> {
    let prepared = prepare(resources, input, overrides, evaluator)?;
    let policy = resources.policy()?;
    let response = super::runtime_bridge::block_on_cancellable(async {
        prepared.wait(&policy, false).await;
        send(resources, &prepared).await
    })
    .map_err(|error| format!("ajax request error: {error}"))?;
    finish(prepared, response, evaluator)
}

pub(super) fn prepare(
    resources: &RequestResources<'_>,
    input: &str,
    overrides: RequestOverrides<'_>,
    evaluator: Option<&dyn SynchronousJsEvaluator>,
) -> Result<PreparedRequest, String> {
    resources.check_active().map_err(|e| e.to_string())?;
    if input.trim().is_empty() {
        return Err("ajax: url is required".to_string());
    }
    let base = resources
        .source
        .clone()
        .or_else(|| {
            evaluator.and_then(|evaluator| {
                evaluator
                    .execute_js("typeof baseUrl === 'string' ? baseUrl : ''")
                    .ok()
            })
        })
        .unwrap_or_default();
    let variables = HashMap::from([("baseUrl".to_string(), base)]);
    let mut headers = resources.headers.clone();
    if let Some(explicit) = overrides.headers {
        let explicit: HashMap<String, String> = serde_json::from_str(explicit).unwrap_or_default();
        merge_headers(&mut headers, explicit);
    }
    let parsed = match evaluator {
        Some(evaluator) => {
            AnalyzeUrl::parse_with_evaluator_and_headers(input, &variables, 0, evaluator, headers)
        }
        None => AnalyzeUrl::parse_with_headers(input, &variables, 0, headers),
    }
    .map_err(|e| e.to_string())?;
    if parsed.use_web_view() {
        return Err("脚本规则请求暂不支持WebView选项".to_string());
    }
    // 解析错误不回显原配置，避免认证信息进入ajax错误正文或日志。
    let proxy = parsed
        .proxy()
        .filter(|value| !value.trim().is_empty())
        .map(legado_net::parse_proxy_config)
        .transpose()
        .map_err(|_| {
            "请求代理配置无效或协议不受支持（支持HTTP/HTTPS/SOCKS4/SOCKS5；SOCKS4不支持凭据）"
                .to_string()
        })?;
    let method = match overrides.method {
        Some(method) => match method.to_ascii_uppercase().as_str() {
            "GET" | "POST" | "HEAD" | "PUT" | "DELETE" => Method::from_str_loose(method),
            _ => return Err(format!("ajax: unsupported method '{method}'")),
        },
        None => match parsed.method() {
            RequestMethod::Get => Method::Get,
            RequestMethod::Post => Method::Post,
            RequestMethod::Head => Method::Head,
        },
    };
    let mut headers = parsed.headers().clone();
    let body = overrides
        .body
        .map(str::to_string)
        .or_else(|| parsed.body().map(|_| parsed.request_body().to_string()));
    if let Some(body) = &body {
        let has_type = headers
            .keys()
            .any(|name| name.eq_ignore_ascii_case("content-type"));
        if !has_type {
            let content_type = if body.trim_start().starts_with(['{', '[']) {
                "application/json;charset=UTF-8"
            } else {
                "application/x-www-form-urlencoded"
            };
            headers.insert("Content-Type".to_string(), content_type.to_string());
        }
    }
    let timeout = overrides.timeout.or(parsed.timeout()).unwrap_or(30_000);
    let url = parsed.url().to_string();
    headers = network::merge_global_cookie(resources, headers, &url);
    // Cookie合并会补回来源头，路由控制项须在最终发送边界再次剥离。
    headers.retain(|name, _| !name.eq_ignore_ascii_case("proxy"));
    network::apply_source_cookie_jar_gate(resources, &mut headers);
    Ok(PreparedRequest {
        parsed,
        request: LegadoRequest {
            url,
            method,
            headers,
            body,
            timeout: network::request_timeout(timeout),
        },
        timeout,
        proxy,
    })
}

/// future 可直接丢弃以停止读流，不创建脱离批次的 tokio 任务。
pub(super) async fn send(
    resources: &RequestResources<'_>,
    prepared: &PreparedRequest,
) -> legado_core::LegadoResult<LegadoRawResponse> {
    resources.check_active()?;
    let parsed = &prepared.parsed;
    let request = &prepared.request;
    if parsed.is_data_uri() {
        return Ok(LegadoRawResponse {
            status: 200,
            headers: HashMap::new(),
            url: request.url.clone(),
            body: parsed.get_byte_array_if_data_uri().ok_or_else(|| {
                legado_core::LegadoError::Parser("data: URI 内容解码失败".to_string())
            })?,
        });
    }
    let dns_addresses = legado_net::request_dns::resolve_addresses(parsed.dns_ip()).await;
    resources.check_active()?;
    let policy = if prepared.timeout == 0 {
        legado_net::client::ClientTimeoutPolicy::NoTotalTimeout
    } else {
        legado_net::client::ClientTimeoutPolicy::Default
    };
    let client = resources
        .http
        .routed_client(
            network::is_loopback_url(&request.url),
            false,
            policy,
            prepared.proxy.clone(),
            dns_addresses,
        )
        .map_err(legado_core::LegadoError::Network)?;
    // 建池可能触发同步Cookie预载，返回后再次检查，避免取消期间发出新请求。
    resources.check_active()?;
    legado_net::request::send_with_response_options(
        &client,
        parsed.follow_redirects(),
        parsed.retry(),
        |response: &LegadoRawResponse| response.status,
        |client| async move {
            resources.check_active()?;
            let mut stream = client.send_stream(request).await?;
            let (status, headers, url) = (
                stream.status(),
                stream.headers().clone(),
                stream.url().to_string(),
            );
            let mut bytes = Vec::new();
            while let Some(chunk) = stream.next_chunk().await? {
                bytes.extend_from_slice(&chunk);
            }
            Ok(LegadoRawResponse {
                status,
                headers,
                url,
                body: bytes,
            })
        },
    )
    .await
}

pub(super) fn finish(
    prepared: PreparedRequest,
    response: LegadoRawResponse,
    evaluator: Option<&dyn SynchronousJsEvaluator>,
) -> Result<HttpResponse, String> {
    let parsed = prepared.parsed;
    let mut body = if parsed.response_type().is_some() {
        hex::encode(&response.body)
    } else {
        legado_parser::response_decode::decode_web_response(
            &response.body,
            &response.headers,
            parsed.charset(),
        )
    };
    if let Some(code) = parsed.body_js() {
        let evaluator = evaluator.ok_or("bodyJs需要当前JS上下文")?;
        let result = serde_json::to_string(&body).map_err(|e| e.to_string())?;
        body = legado_parser::analyze_url::with_current_url(&response.url, || {
            evaluator.execute_js_with_result(code, &result)
        })?;
    }
    Ok(HttpResponse {
        status_code: response.status,
        body,
        headers: response.headers,
        url: response.url,
    })
}
