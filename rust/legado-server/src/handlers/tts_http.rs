//! URL直连TTS只编排所属实例的网络与任务，不解释数据库书源规则。
use crate::state::AppState;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use legado_core::{LegadoError, LegadoResult};
use std::{sync::Arc, time::Duration};

pub(super) struct DirectAudio {
    pub audio_url: Option<String>,
    pub audio_data: Option<String>,
    pub content_type: String,
}
#[derive(Clone, Copy)]
struct Policy {
    bytes: usize,
    deadline: Duration,
}
impl Default for Policy {
    fn default() -> Self {
        Self {
            bytes: 32 * 1024 * 1024,
            deadline: Duration::from_secs(60),
        }
    }
}
fn http_url(raw: &str) -> LegadoResult<reqwest::Url> {
    let url =
        reqwest::Url::parse(raw).map_err(|e| LegadoError::Parser(format!("TTS地址无效: {e}")))?;
    if !matches!(url.scheme(), "http" | "https") || url.host_str().is_none() {
        return Err(LegadoError::Parser("TTS地址必须是HTTP(S)地址".into()));
    }
    Ok(url)
}
pub(super) fn append_query(raw: &str, key: &str, value: &str) -> LegadoResult<String> {
    let mut url = http_url(raw)?;
    url.query_pairs_mut().append_pair(key, value);
    Ok(url.into())
}
pub(super) async fn synthesize(
    state: &Arc<AppState>,
    template: &str,
    text: &str,
    parameters: &[(&str, String)],
) -> LegadoResult<DirectAudio> {
    synthesize_with_policy(state, template, text, parameters, Policy::default()).await
}
async fn synthesize_with_policy(
    state: &Arc<AppState>,
    template: &str,
    text: &str,
    parameters: &[(&str, String)],
    policy: Policy,
) -> LegadoResult<DirectAudio> {
    let mut url =
        http_url(&template.replace("{speakText}", &urlencoding::encode(text)))?.to_string();
    for (key, value) in parameters {
        url = append_query(&url, key, value)?;
    }
    let task = state.task()?;
    let _guard = task.guard();
    let work = async {
        let client = state.network_client().await?;
        let mut request = legado_net::request::LegadoRequest::get(url);
        request.timeout = Some(policy.deadline);
        let mut response = client.send_stream(&request).await?;
        if !response.is_success() {
            return Err(LegadoError::Network(format!(
                "TTS服务返回HTTP {}",
                response.status()
            )));
        }
        if response
            .content_length()
            .is_some_and(|n| n > policy.bytes as u64)
        {
            return Err(LegadoError::Network("TTS响应超过大小限制".into()));
        }
        let content_type = response
            .content_type()
            .cloned()
            .unwrap_or_else(|| "audio/mpeg".into());
        let mime = content_type
            .split(';')
            .next()
            .unwrap_or("")
            .trim()
            .to_ascii_lowercase();
        let mut bytes = Vec::new();
        while let Some(chunk) = response.next_chunk().await? {
            if chunk.len() > policy.bytes.saturating_sub(bytes.len()) {
                return Err(LegadoError::Network("TTS响应超过大小限制".into()));
            }
            bytes
                .try_reserve(chunk.len())
                .map_err(|e| LegadoError::Network(format!("分配TTS缓冲失败: {e}")))?;
            bytes.extend_from_slice(&chunk);
        }
        if bytes.is_empty() {
            return Err(LegadoError::Network("TTS服务返回空内容".into()));
        }
        if mime.starts_with("audio/") || mime == "application/octet-stream" {
            return Ok(DirectAudio {
                audio_url: None,
                audio_data: Some(STANDARD.encode(bytes)),
                content_type,
            });
        }
        let text = std::str::from_utf8(&bytes)
            .map_err(|e| LegadoError::Network(format!("TTS文本响应编码无效: {e}")))?;
        let candidate = if let Ok(value) = serde_json::from_str::<serde_json::Value>(text) {
            value
                .get("audio_url")
                .and_then(|v| v.as_str())
                .ok_or_else(|| LegadoError::Network("TTS响应缺少audio_url".into()))?
                .to_owned()
        } else {
            text.trim().to_owned()
        };
        let audio_url = http_url(&candidate)
            .map_err(|_| LegadoError::Network("TTS响应不是有效音频地址".into()))?;
        Ok(DirectAudio {
            audio_url: Some(audio_url.into()),
            audio_data: None,
            content_type: "audio/mpeg".into(),
        })
    };
    tokio::select! {
        biased;
        _ = task.cancelled() => Err(LegadoError::Internal("TTS请求已取消".into())),
        result = tokio::time::timeout(policy.deadline, work) => result.map_err(|_| LegadoError::Timeout("TTS请求超时".into()))?,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    fn state() -> Arc<AppState> {
        Arc::new(AppState::new(Arc::new(
            legado_engine::EngineContext::in_memory().unwrap(),
        )))
    }
    async fn fixture(raw: String) -> (String, tokio::task::JoinHandle<String>) {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}/tts", listener.local_addr().unwrap());
        let worker = tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut received = Vec::new();
            loop {
                let mut bytes = [0; 1024];
                let n = socket.read(&mut bytes).await.unwrap();
                assert!(n > 0);
                received.extend_from_slice(&bytes[..n]);
                if received.windows(4).any(|s| s == b"\r\n\r\n") {
                    break;
                }
            }
            socket.write_all(raw.as_bytes()).await.unwrap();
            String::from_utf8(received).unwrap()
        });
        (url, worker)
    }
    fn reply(status: &str, mime: &str, body: &str) -> String {
        format!(
            "HTTP/1.1 {status}\r\nContent-Type: {mime}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        )
    }
    #[tokio::test]
    async fn errors_are_not_audio_and_body_limits_cover_declared_and_actual_bytes() {
        let state = state();
        for (index, response) in [
            reply("500 Error", "audio/mpeg", "bad"),
            reply("200 OK", "application/json", "{\"error\":\"denied\"}"),
            reply("200 OK", "text/plain", "javascript:alert(1)"),
            reply("200 OK", "audio/mpeg", "12345"),
            "HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nConnection: close\r\n\r\n12345".into(),
        ]
        .into_iter()
        .enumerate()
        {
            let (url, worker) = fixture(response).await;
            assert!(
                synthesize_with_policy(
                    &state,
                    &url,
                    "x",
                    &[],
                    Policy {
                        bytes: if index < 3 { 1024 } else { 4 },
                        deadline: Duration::from_secs(3)
                    }
                )
                .await
                .is_err()
            );
            worker.await.unwrap();
        }
    }
    #[tokio::test]
    async fn client_identity_user_agent_cookies_and_valid_responses_use_engine_resources() {
        let state = state();
        state
            .engine
            .network()
            .reset_client_with_config(legado_net::LegadoClientConfig {
                user_agent: "tts-audit-agent".into(),
                ..Default::default()
            })
            .unwrap();
        state
            .engine
            .network()
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("127.0.0.1", "session=owned");
        let id = state.engine.network().client().unwrap().client_id();
        let (url, worker) = fixture(reply("200 OK", "audio/mpeg", "abc")).await;
        let audio = synthesize(
            &state,
            &(url + "?text={speakText}#fragment"),
            "中文",
            &[("voice", "a b".into())],
        )
        .await
        .unwrap();
        assert_eq!(audio.audio_data.as_deref(), Some("YWJj"));
        let request = worker.await.unwrap().to_lowercase();
        assert!(request.contains("user-agent: tts-audit-agent"));
        assert!(request.contains("cookie: session=owned"));
        assert!(request.contains("voice=a+b"));
        assert!(!request.contains("fragment"));
        assert_eq!(state.engine.network().client().unwrap().client_id(), id);
        let (url, worker) = fixture(reply(
            "200 OK",
            "application/json",
            "{\"audio_url\":\"https://example.com/a.mp3\"}",
        ))
        .await;
        assert_eq!(
            synthesize(&state, &url, "x", &[])
                .await
                .unwrap()
                .audio_url
                .as_deref(),
            Some("https://example.com/a.mp3")
        );
        worker.await.unwrap();
    }
    #[tokio::test]
    async fn configured_proxy_and_custom_hosts_are_used_by_direct_tts() {
        let state = state();
        let (url, worker) = fixture(reply("200 OK", "audio/mpeg", "abc")).await;
        state
            .engine
            .network()
            .reset_client_with_config(legado_net::LegadoClientConfig {
                proxy: Some(legado_net::proxy::ProxyConfig::from_url(
                    url.trim_end_matches("/tts"),
                )),
                ..Default::default()
            })
            .unwrap();
        assert!(
            synthesize(&state, "http://provider.invalid/tts", "x", &[])
                .await
                .is_ok()
        );
        assert!(
            worker
                .await
                .unwrap()
                .starts_with("GET http://provider.invalid/tts ")
        );
        let (url, worker) = fixture(reply(
            "200 OK",
            "text/plain",
            "https://example.com/audio.mp3",
        ))
        .await;
        state
            .engine
            .network()
            .custom_hosts()
            .apply_custom_hosts(r#"{"tts-host.invalid":"127.0.0.1"}"#)
            .unwrap();
        state
            .engine
            .network()
            .reset_client_with_config(legado_net::LegadoClientConfig {
                no_proxy: true,
                ..Default::default()
            })
            .unwrap();
        let direct = url.replacen("127.0.0.1", "tts-host.invalid", 1);
        assert_eq!(
            synthesize(&state, &direct, "x", &[])
                .await
                .unwrap()
                .audio_url
                .as_deref(),
            Some("https://example.com/audio.mp3")
        );
        worker.await.unwrap();
    }
    #[tokio::test]
    async fn deadline_and_host_cancellation_stop_pending_responses_and_release_tasks() {
        for cancel in [false, true] {
            let state = state();
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let url = format!("http://{}/pending", listener.local_addr().unwrap());
            let (entered, ready) = tokio::sync::oneshot::channel();
            let server = tokio::spawn(async move {
                let (mut socket, _) = listener.accept().await.unwrap();
                let mut buf = [0; 4096];
                let _ = socket.read(&mut buf).await;
                let _ = entered.send(());
                std::future::pending::<()>().await;
                drop(socket);
            });
            let other = state.clone();
            let work = tokio::spawn(async move {
                synthesize_with_policy(
                    &other,
                    &url,
                    "x",
                    &[],
                    Policy {
                        bytes: 4,
                        deadline: if cancel {
                            Duration::from_secs(3)
                        } else {
                            Duration::from_millis(100)
                        },
                    },
                )
                .await
            });
            if cancel {
                ready.await.unwrap();
                state.tasks.request_cancel();
            }
            let result = work.await.unwrap();
            assert!(result.is_err());
            if !cancel {
                assert!(matches!(result, Err(LegadoError::Timeout(_))));
            }
            assert!(state.tasks.shutdown(Duration::from_secs(1)).await);
            server.abort();
            let _ = server.await;
        }
    }
}
