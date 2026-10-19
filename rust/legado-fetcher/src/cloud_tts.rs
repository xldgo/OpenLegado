//! 云端合成编排：网络通过窄接口注入，复用取消、原子音频缓存和活动租约。
use crate::tts_control::{TtsCancellation, synthesis_lock};
use futures::future::BoxFuture;
use legado_core::{
    LegadoError, LegadoResult,
    cloud_tts::*,
    tts_cache::{AudioLease, TtsCache},
    tts_speak::{SpeakCache, content_type_from_ext},
};
use std::{
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};
pub struct CloudTtsResponse {
    pub status: u16,
    pub content_type: String,
    pub bytes: Vec<u8>,
}
pub trait CloudTtsTransport: Send + Sync {
    fn catalog<'a>(
        &'a self,
        _request: &'a PreparedCloudCatalog,
    ) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>> {
        Box::pin(async { Err(LegadoError::Network("此传输不支持音色目录".into())) })
    }
    fn download_audio<'a>(
        &'a self,
        _url: &'a str,
    ) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>> {
        Box::pin(async { Err(LegadoError::Network("此传输不支持音频下载".into())) })
    }
    fn send<'a>(
        &'a self,
        request: &'a PreparedCloudSpeech,
    ) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>>;
}
/// 云请求使用独立客户端，不带入书源登录和 Cookie；默认正常校验证书。
pub struct CloudTtsHttpTransport {
    client: legado_net::LegadoClient,
}
impl CloudTtsHttpTransport {
    pub fn new() -> LegadoResult<Self> {
        Self::with_proxy_discovery(true)
    }
    pub fn with_proxy_discovery(discover: bool) -> LegadoResult<Self> {
        Self::build(discover, None)
    }
    pub fn with_custom_hosts(
        hosts: Arc<legado_net::custom_hosts::CustomHosts>,
    ) -> LegadoResult<Self> {
        Self::build(true, Some(hosts))
    }
    fn build(
        discover: bool,
        hosts: Option<Arc<legado_net::custom_hosts::CustomHosts>>,
    ) -> LegadoResult<Self> {
        Ok(Self {
            client: legado_net::LegadoClient::new(legado_net::LegadoClientConfig {
                accept_invalid_certs: false,
                follow_redirects: false,
                read_timeout: Duration::from_secs(120),
                no_proxy: !discover,
                custom_hosts: hosts,
                ..Default::default()
            })?,
        })
    }
}
impl CloudTtsTransport for CloudTtsHttpTransport {
    fn catalog<'a>(
        &'a self,
        request: &'a PreparedCloudCatalog,
    ) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>> {
        Box::pin(async move {
            let response = self
                .client
                .get_raw_with_timeout(
                    &request.endpoint,
                    Some(std::collections::HashMap::from([(
                        request.credential_header.into(),
                        request.authorization.clone(),
                    )])),
                    Some(Duration::from_secs(120)),
                )
                .await
                .map_err(|_| LegadoError::Network("云端音色目录请求失败".into()))?;
            Ok(CloudTtsResponse {
                status: response.status,
                content_type: response.content_type().cloned().unwrap_or_default(),
                bytes: response.body,
            })
        })
    }
    fn download_audio<'a>(&'a self, url: &'a str) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>> {
        Box::pin(async move {
            // 下载地址可含 OSS 签名，异常不回显地址；不带合成请求凭据。
            let response = self
                .client
                .get_raw_with_timeout(url, None, Some(Duration::from_secs(120)))
                .await
                .map_err(|_| LegadoError::Network("云端 TTS 音频下载失败".into()))?;
            Ok(CloudTtsResponse {
                status: response.status,
                content_type: response.content_type().cloned().unwrap_or_default(),
                bytes: response.body,
            })
        })
    }
    fn send<'a>(
        &'a self,
        request: &'a PreparedCloudSpeech,
    ) -> BoxFuture<'a, LegadoResult<CloudTtsResponse>> {
        Box::pin(async move {
            let mut headers = std::collections::HashMap::from([
                (
                    request.credential_header.into(),
                    request.authorization.clone(),
                ),
                ("Content-Type".into(), request.body.content_type().into()),
            ]);
            headers.extend(
                request
                    .additional_headers
                    .iter()
                    .map(|(key, value)| ((*key).into(), value.clone())),
            );
            let response = self
                .client
                .post_raw_with_timeout(
                    &request.endpoint,
                    &request.body.encode(),
                    Some(headers),
                    Some(Duration::from_secs(120)),
                )
                .await
                .map_err(|_| LegadoError::Network("云端 TTS 网络请求失败".into()))?;
            Ok(CloudTtsResponse {
                status: response.status,
                content_type: response.content_type().cloned().unwrap_or_default(),
                bytes: response.body,
            })
        })
    }
}
/// 租约随结果交给播放层；停止播放器后释放，避免缓存清理误删正在使用的文件。
pub struct CloudTtsSynthesisResult {
    pub audio_path: PathBuf,
    pub from_cache: bool,
    pub content_type: String,
    pub lease: AudioLease,
}
/// 目录发现不写音色表；取消覆盖等待与网络，请求结果由调用者持有。
pub async fn discover_cloud_voices(
    provider: &dyn CloudTtsProvider,
    transport: &dyn CloudTtsTransport,
    engine: &CloudTtsEngine,
    cancellation: &TtsCancellation,
) -> LegadoResult<Vec<CloudTtsVoiceDescriptor>> {
    cancellation.check()?;
    match provider.prepare_catalog(engine)? {
        CloudVoiceCatalog::Static(voices) => Ok(voices),
        CloudVoiceCatalog::Remote(request) => {
            let response = cancellation.run(transport.catalog(&request)).await?;
            cancellation.check()?;
            if !(200..300).contains(&response.status) {
                return Err(LegadoError::Network(format!(
                    "云端音色目录请求失败：HTTP {}",
                    response.status
                )));
            }
            let mime = response
                .content_type
                .split(';')
                .next()
                .unwrap_or_default()
                .trim();
            if !mime.eq_ignore_ascii_case("application/json") {
                return Err(LegadoError::Network("云端音色目录未返回 JSON".into()));
            }
            provider.decode_catalog(&response.bytes)
        }
    }
}
fn cache_key(engine: &CloudTtsEngine, prepared: &PreparedCloudSpeech) -> LegadoResult<String> {
    use sha2::{Digest, Sha256};
    // 只包含实际合成输入；播放器倍速、音量及书章位置由调用者另行管理。
    let input = serde_json::to_vec(&(
        "cloud",
        engine.provider,
        engine.id.as_str(),
        prepared.endpoint.as_str(),
        prepared.body.clone(),
        prepared.response_format.as_str(),
        &prepared.additional_headers,
        engine.api_key.as_str(),
    ))?;
    Ok(Sha256::digest(&input)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect())
}
fn result(
    path: PathBuf,
    hit: bool,
    content_type: String,
    cache: &Arc<TtsCache>,
) -> LegadoResult<CloudTtsSynthesisResult> {
    let lease = cache.pin(&path)?;
    Ok(CloudTtsSynthesisResult {
        audio_path: path,
        from_cache: hit,
        content_type,
        lease,
    })
}
fn validate_response(
    response: &CloudTtsResponse,
    kind: CloudSpeechResponseKind,
) -> LegadoResult<()> {
    if !(200..300).contains(&response.status) {
        return Err(LegadoError::Network(format!(
            "云端 TTS 请求失败：HTTP {}",
            response.status
        )));
    }
    let mime = response
        .content_type
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_lowercase();
    if kind == CloudSpeechResponseKind::EventStream {
        if mime != "text/event-stream" {
            return Err(LegadoError::Network(
                "云端 TTS 未返回要求的 SSE 音频流".into(),
            ));
        }
    } else {
        if mime.starts_with("text/") || mime == "application/json" || mime.ends_with("+json") {
            return Err(LegadoError::Network(
                "云端 TTS 返回错误文本，未生成音频".into(),
            ));
        }
        // 部分兼容端点给错误 JSON/HTML 标成音频；不能把报错体当音频落盘。
        let textual_error = serde_json::from_slice::<serde_json::Value>(&response.bytes)
            .is_ok_and(|v| v.is_object() || v.is_array());
        let prefix = response
            .bytes
            .iter()
            .copied()
            .skip_while(u8::is_ascii_whitespace)
            .take(16)
            .collect::<Vec<_>>();
        if textual_error || prefix.starts_with(b"<!DOCTYPE") || prefix.starts_with(b"<html") {
            return Err(LegadoError::Network(
                "云端 TTS 返回错误文本，未生成音频".into(),
            ));
        }
    }
    Ok(())
}
pub async fn synthesize_cloud_tts(
    provider: &dyn CloudTtsProvider,
    transport: &dyn CloudTtsTransport,
    engine: &CloudTtsEngine,
    request: &CloudTtsSynthesisRequest,
    directory: &Path,
    cancellation: &TtsCancellation,
) -> LegadoResult<CloudTtsSynthesisResult> {
    synthesize_cloud_tts_with_publish(
        provider,
        transport,
        engine,
        request,
        directory,
        cancellation,
        |cache, key, extension, bytes| cache.put(key, extension, bytes),
    )
    .await
}

/// 宿主提供最终文件提交门控，不把引擎或运行时反向传入共享抓取层。
pub async fn synthesize_cloud_tts_with_publish(
    provider: &dyn CloudTtsProvider,
    transport: &dyn CloudTtsTransport,
    engine: &CloudTtsEngine,
    request: &CloudTtsSynthesisRequest,
    directory: &Path,
    cancellation: &TtsCancellation,
    publish: impl FnOnce(&SpeakCache, &str, &str, &[u8]) -> LegadoResult<PathBuf>,
) -> LegadoResult<CloudTtsSynthesisResult> {
    cancellation.check()?;
    // 验证必须早于缓存命中，禁用或缺凭据不能沿用旧缓存继续播放。
    let prepared = provider.prepare(engine, request)?;
    let activity_cache = TtsCache::open(directory)?;
    let _activity = activity_cache.activity();
    let directory = directory.canonicalize()?;
    let key = cache_key(engine, &prepared)?;
    let lock = synthesis_lock(directory.clone(), key.clone());
    let _guard = cancellation.run(async { Ok(lock.lock().await) }).await?;
    let cache = SpeakCache::new(directory);
    if let Some(path) = cache.get(&key) {
        cancellation.check()?;
        let content_type =
            content_type_from_ext(path.extension().and_then(|e| e.to_str()).unwrap_or(""))
                .to_owned();
        return result(path, true, content_type, &activity_cache);
    }
    let response = cancellation
        .run(async {
            tokio::time::timeout(Duration::from_secs(120), transport.send(&prepared))
                .await
                .map_err(|_| LegadoError::Timeout("云端 TTS 请求超时 (120s)".into()))?
        })
        .await?;
    cancellation.check()?;
    validate_response(&response, prepared.response_kind)?;
    let audio = match provider.decode_response(&prepared.response_format, response.bytes)? {
        DecodedCloudSpeech::Audio(audio) => audio,
        DecodedCloudSpeech::Download(url) => {
            cancellation.check()?;
            let response = cancellation
                .run(async {
                    tokio::time::timeout(Duration::from_secs(120), transport.download_audio(&url))
                        .await
                        .map_err(|_| LegadoError::Timeout("云端 TTS 音频下载超时 (120s)".into()))?
                })
                .await?;
            cancellation.check()?;
            validate_response(&response, CloudSpeechResponseKind::AudioBytes)?;
            provider.decode_audio(&prepared.response_format, response.bytes)?
        }
    };
    cancellation.check()?;
    let path = publish(&cache, &key, audio.extension, &audio.bytes)?;
    // 发布后再次检查取消；不把已取消请求交给播放层，完整缓存可供以后复用。
    cancellation.check()?;
    result(path, false, audio.content_type.into(), &activity_cache)
}
#[cfg(test)]
mod tests;
