//! HTTP TTS 首发与登录脚本重发共用超时、限流、重试与取消策略。
use crate::rate_limit::RateLimiterRegistry;
use crate::tts_control::TtsCancellation;
use crate::tts_fetcher::HttpTtsConfig;
use crate::tts_source::TtsSourceStore;
use legado_core::{LegadoError, LegadoResult};
use legado_net::{LegadoClient, LegadoRawResponse};
use legado_parser::AnalyzeUrl;
use std::collections::HashMap;
use std::time::Duration;

pub async fn send_tts_request(
    client: &LegadoClient,
    config: &HttpTtsConfig,
    analyze_url: &AnalyzeUrl,
    headers: Option<HashMap<String, String>>,
    store: &dyn TtsSourceStore,
    rates: &RateLimiterRegistry,
    cancellation: &TtsCancellation,
) -> LegadoResult<LegadoRawResponse> {
    cancellation
        .run(async {
            let mut retries = 0;
            loop {
                let current_rate = store
                    .load(&config.source_key())?
                    .get("concurrentRate")
                    .cloned()
                    .or_else(|| config.concurrent_rate.clone())
                    .unwrap_or_default();
                rates.acquire_key(&config.source_key(), &current_rate).await;
                let sent = tokio::time::timeout(
                    Duration::from_secs(300),
                    crate::analyze_request::send_raw_with_timeout(
                        client,
                        analyze_url,
                        headers.clone(),
                        Duration::from_secs(300),
                    ),
                )
                .await
                .map_err(|_| LegadoError::Timeout("TTS 请求超时 (300s)".into()))
                .and_then(|r| r);
                match sent {
                    Ok(response) => return Ok(response),
                    Err(error) if retries < 5 && retryable_transport_error(&error) => {
                        retries += 1;
                        tokio::time::sleep(Duration::from_millis(100)).await;
                    }
                    Err(error) => return Err(error),
                }
            }
        })
        .await
}

/// 上游连接和超时错误最多重试五次；其他失败不重复发送。
fn retryable_transport_error(error: &LegadoError) -> bool {
    matches!(error, LegadoError::Timeout(_))
        || matches!(error,LegadoError::Network(message) if message.starts_with("Connection failed:"))
}
