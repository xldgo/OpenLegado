//! 批量请求只并发网络等待；JS 准备和响应脚本始终在当前调用线程求值。
//! — Codex + Bridge
use super::network::HttpResponse;
use super::rule_request::{self, ContextEvaluator, PreparedRequest, RequestOverrides};
use crate::http_resources::RequestResources;
use futures::{StreamExt, TryStreamExt, stream};
use legado_core::LegadoError;
use legado_parser::analyze_url::SynchronousJsEvaluator;
use serde::Serialize;
use std::time::Instant;

#[derive(Serialize)]
struct BatchResponse {
    #[serde(flatten)]
    response: HttpResponse,
    call_time: i32,
}

fn evaluator<'js>(
    ctx: Option<&rquickjs::Ctx<'js>>,
) -> Result<Option<ContextEvaluator<'js>>, String> {
    ctx.cloned()
        .map(ContextEvaluator::new)
        .transpose()
        .map_err(|e| e.to_string())
}

fn prepare(
    resources: &RequestResources<'_>,
    input: &str,
    timeout: Option<u64>,
    ctx: Option<&rquickjs::Ctx<'_>>,
) -> Result<PreparedRequest, String> {
    let evaluator = evaluator(ctx)?;
    rule_request::prepare(
        resources,
        input,
        RequestOverrides {
            timeout,
            ..Default::default()
        },
        evaluator.as_ref().map(|v| v as &dyn SynchronousJsEvaluator),
    )
}

fn finish(
    prepared: PreparedRequest,
    response: legado_net::LegadoRawResponse,
    ctx: Option<&rquickjs::Ctx<'_>>,
) -> Result<HttpResponse, String> {
    let evaluator = evaluator(ctx)?;
    rule_request::finish(
        prepared,
        response,
        evaluator.as_ref().map(|v| v as &dyn SynchronousJsEvaluator),
    )
}

fn failed(url: &str, error: String, code: i32) -> BatchResponse {
    BatchResponse {
        response: HttpResponse {
            raw_summary: String::new(),
            status_code: 200,
            body: error,
            headers: Default::default(),
            url: url::Url::parse(url)
                .map(|u| u.to_string())
                .unwrap_or_else(|_| "http://localhost/".to_string()),
        },
        call_time: code,
    }
}

async fn item(
    resources: &RequestResources<'_>,
    input: &str,
    timeout: Option<u64>,
    probe: bool,
    ctx: Option<&rquickjs::Ctx<'_>>,
    policy: &crate::http_request_policy::RequestPolicySnapshot,
    skip_rate_limit: bool,
) -> Result<BatchResponse, String> {
    resources.check_active().map_err(|e| e.to_string())?;
    let prepared = match prepare(resources, input, timeout, ctx) {
        Ok(prepared) => prepared,
        Err(error) if probe => return Ok(failed(input, error, -7)),
        Err(error) => return Err(error),
    };
    prepared.wait(policy, skip_rate_limit).await;
    resources.check_active().map_err(|e| e.to_string())?;
    let start = Instant::now();
    let response = match rule_request::send(resources, &prepared).await {
        Ok(response) => response,
        Err(error) if probe => {
            // 下层已丢失 DNS/TLS 等细分类型，不根据文本猜测 Java 异常。
            let code = if matches!(error, LegadoError::Timeout(_)) {
                -1
            } else {
                -7
            };
            return Ok(failed(prepared.url(), error.to_string(), code));
        }
        Err(error) => return Err(error.to_string()),
    };
    let final_url = response.url.clone();
    resources.check_active().map_err(|e| e.to_string())?;
    match finish(prepared, response, ctx) {
        Ok(response) => Ok(BatchResponse {
            response,
            call_time: start.elapsed().as_millis().min(i32::MAX as u128) as i32,
        }),
        Err(error) if probe => Ok(failed(&final_url, error, -7)),
        Err(error) => Err(error),
    }
}

pub(super) fn run(
    resources: &RequestResources<'_>,
    urls_json: &str,
    timeout: Option<u64>,
    probe: bool,
    skip_rate_limit: bool,
    ctx: Option<&rquickjs::Ctx<'_>>,
) -> Result<String, String> {
    let urls: Vec<String> = if urls_json.trim().is_empty() {
        Vec::new()
    } else {
        serde_json::from_str(urls_json).map_err(|error| format!("批量请求 parse error: {error}"))?
    };
    let policy = &resources.policy()?;
    let mut responses = super::runtime_bridge::block_on_cancellable(async {
        stream::iter(urls.iter().enumerate())
            .map(|(index, url)| async move {
                item(resources, url, timeout, probe, ctx, policy, skip_rate_limit)
                    .await
                    .map(|response| (index, response))
                    .map_err(|error| format!("批量请求[{index}] {error}"))
            })
            .buffer_unordered(policy.concurrency.get())
            .try_collect::<Vec<_>>()
            .await
    })?;
    // 无序消费使任意失败立即取消整个批次；全部成功后才按输入索引恢复顺序。
    responses.sort_unstable_by_key(|(index, _)| *index);
    let responses: Vec<_> = responses
        .into_iter()
        .map(|(_, response)| response)
        .collect();
    serde_json::to_string(&responses).map_err(|error| error.to_string())
}
