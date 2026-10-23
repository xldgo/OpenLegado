//! 云端合成模型和 Provider 纯计算边界；不访问网络、数据库或 Flutter。
use crate::{LegadoError, LegadoResult};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fmt;

pub mod capabilities;
pub(crate) mod sse;

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum CloudTtsProviderType {
    #[serde(rename = "openai_speech")]
    OpenAiSpeech,
    #[serde(rename = "mimo")]
    Mimo,
    #[serde(rename = "alibaba_cloud")]
    AlibabaCloud,
    #[serde(rename = "azure_speech")]
    AzureSpeech,
    #[serde(rename = "aws_polly")]
    AwsPolly,
    #[serde(rename = "volcengine")]
    Volcengine,
    #[serde(rename = "gemini_tts")]
    GeminiTts,
    #[serde(rename = "volcengine_v3")]
    VolcengineV3,
}
// 远端硬限制与应用保守分片阈值分开命名，避免混淆字符数和编码长度。
pub(crate) const OPENAI_MAX_CHARACTERS: usize = 4096;
pub(crate) const ALIBABA_MAX_CHARACTERS: usize = 600;
pub(crate) const POLLY_MAX_CHARACTERS: usize = 3000;
pub(crate) const DEFAULT_SPEECH_UTF16_UNITS: u32 = 4000;
pub(crate) const VOLCENGINE_MAX_UTF8_BYTES: u32 = 1024;

/// 应用分片使用的保守上限；不替代Provider对真实请求及服务响应的校验。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CloudTtsSpeechLimits {
    pub max_utf16_units: u32,
    pub max_utf8_bytes: Option<u32>,
}
impl CloudTtsProviderType {
    pub fn speech_limits(self) -> CloudTtsSpeechLimits {
        CloudTtsSpeechLimits {
            max_utf16_units: match self {
                Self::AlibabaCloud => ALIBABA_MAX_CHARACTERS as u32,
                Self::AwsPolly => POLLY_MAX_CHARACTERS as u32,
                _ => DEFAULT_SPEECH_UTF16_UNITS,
            },
            max_utf8_bytes: match self {
                Self::Volcengine | Self::VolcengineV3 => Some(VOLCENGINE_MAX_UTF8_BYTES),
                _ => None,
            },
        }
    }
}
/// 凭据只用于调用；可导出 JSON 和调试内容始终排除明文。
#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct CloudTtsEngine {
    pub id: String,
    pub name: String,
    pub provider: CloudTtsProviderType,
    pub base_url: String,
    #[serde(skip_serializing)]
    pub api_key: String,
    #[serde(skip_serializing)]
    pub secret_key: String,
    pub model: String,
    pub region: String,
    pub app_id: String,
    pub enabled: bool,
}
impl Default for CloudTtsEngine {
    fn default() -> Self {
        Self {
            id: String::new(),
            name: String::new(),
            provider: CloudTtsProviderType::OpenAiSpeech,
            base_url: String::new(),
            api_key: String::new(),
            secret_key: String::new(),
            model: CloudTtsProviderType::OpenAiSpeech
                .capabilities()
                .default_model
                .into(),
            region: String::new(),
            app_id: String::new(),
            enabled: true,
        }
    }
}
impl fmt::Debug for CloudTtsEngine {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("CloudTtsEngine")
            .field("id", &self.id)
            .field("provider", &self.provider)
            .field("api_key", &"<已隐藏>")
            .finish_non_exhaustive()
    }
}
#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
#[serde(rename_all = "camelCase", default)]
pub struct CloudTtsSynthesisRequest {
    pub text: String,
    pub voice_id: String,
    pub locale: String,
    pub style: String,
    pub role: String,
    pub instructions: String,
    pub speed: f64,
    pub pitch: f64,
    pub volume: f64,
    pub format: String,
    pub sample_rate: Option<u32>,
}
impl Default for CloudTtsSynthesisRequest {
    fn default() -> Self {
        Self {
            text: String::new(),
            voice_id: String::new(),
            locale: String::new(),
            style: String::new(),
            role: String::new(),
            instructions: String::new(),
            speed: 1.0,
            pitch: 1.0,
            volume: 1.0,
            format: "mp3".into(),
            sample_rate: None,
        }
    }
}
#[derive(Debug, Default, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct CloudTtsVoiceDescriptor {
    pub id: String,
    pub display_name: String,
    pub locale: String,
    pub gender: String,
    pub styles: Vec<String>,
    pub roles: Vec<String>,
    pub supported_models: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sample_rate: Option<u32>,
}
/// 不实现 Debug/Serialize：请求体含私人正文，Authorization 含凭据。
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum CloudSpeechResponseKind {
    AudioBytes,
    EventStream,
    JsonAudio,
}
#[derive(Clone, Serialize)]
pub enum CloudSpeechBody {
    Json(Value),
    Ssml(String),
}
impl CloudSpeechBody {
    pub fn content_type(&self) -> &'static str {
        match self {
            Self::Json(_) => "application/json",
            Self::Ssml(_) => "application/ssml+xml",
        }
    }
    pub fn encode(&self) -> String {
        match self {
            Self::Json(value) => value.to_string(),
            Self::Ssml(text) => text.clone(),
        }
    }
}
pub struct PreparedCloudSpeech {
    pub endpoint: String,
    pub credential_header: &'static str,
    pub authorization: String,
    pub response_kind: CloudSpeechResponseKind,
    pub additional_headers: Vec<(&'static str, String)>,
    /// 瞬时认证数据不参与缓存身份。
    pub authentication_headers: Vec<(&'static str, String)>,
    pub body: CloudSpeechBody,
    pub response_format: String,
}
/// 单页候选与继续令牌；分页由抓取层推进。
pub struct CloudCatalogPage {
    pub voices: Vec<CloudTtsVoiceDescriptor>,
    pub next_token: Option<String>,
}
/// 远端目录请求不实现 Debug，避免凭据进入诊断输出。
pub struct PreparedCloudCatalog {
    pub authentication_headers: Vec<(&'static str, String)>,
    pub endpoint: String,
    pub credential_header: &'static str,
    pub authorization: String,
}
pub enum CloudVoiceCatalog {
    Static(Vec<CloudTtsVoiceDescriptor>),
    Remote(PreparedCloudCatalog),
}
pub struct CloudTtsAudio {
    pub bytes: Vec<u8>,
    pub extension: &'static str,
    pub content_type: &'static str,
}
pub enum DecodedCloudSpeech {
    Audio(CloudTtsAudio),
    Download(String),
}
pub trait CloudTtsProvider: Send + Sync {
    fn provider_type(&self) -> CloudTtsProviderType;
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor>;
    fn prepare_catalog(&self, _engine: &CloudTtsEngine) -> LegadoResult<CloudVoiceCatalog> {
        Ok(CloudVoiceCatalog::Static(self.voices()))
    }
    fn prepare_catalog_page(
        &self,
        engine: &CloudTtsEngine,
        token: Option<&str>,
    ) -> LegadoResult<CloudVoiceCatalog> {
        if token.is_some() {
            return Err(invalid("此 Provider 不支持目录分页"));
        }
        self.prepare_catalog(engine)
    }
    fn decode_catalog_page(&self, bytes: &[u8]) -> LegadoResult<CloudCatalogPage> {
        Ok(CloudCatalogPage {
            voices: self.decode_catalog(bytes)?,
            next_token: None,
        })
    }
    fn decode_catalog(&self, _bytes: &[u8]) -> LegadoResult<Vec<CloudTtsVoiceDescriptor>> {
        Err(invalid("此 Provider 不支持远端音色目录"))
    }
    fn prepare(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech>;
    /// 默认复用准备逻辑以刷新认证；Provider 可在此追加不参与缓存的请求标识。
    fn prepare_for_send(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        self.prepare(engine, request)
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio>;
    fn decode_response(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<DecodedCloudSpeech> {
        self.decode_audio(format, bytes)
            .map(DecodedCloudSpeech::Audio)
    }
}
/// 元数据校验、音色发现与合成执行必须走同一 Provider 分派。
pub fn cloud_tts_provider(kind: CloudTtsProviderType) -> &'static dyn CloudTtsProvider {
    match kind {
        CloudTtsProviderType::OpenAiSpeech => &crate::cloud_tts_openai::OpenAiCloudTtsProvider,
        CloudTtsProviderType::Mimo => &crate::cloud_tts_mimo::MimoCloudTtsProvider,
        CloudTtsProviderType::AlibabaCloud => &crate::cloud_tts_alibaba::AlibabaCloudTtsProvider,
        CloudTtsProviderType::AzureSpeech => &crate::cloud_tts_azure::AzureSpeechCloudTtsProvider,
        CloudTtsProviderType::AwsPolly => &crate::cloud_tts_polly::AwsPollyCloudTtsProvider,
        CloudTtsProviderType::Volcengine => {
            &crate::cloud_tts_volcengine::VolcengineCloudTtsProvider
        }
        CloudTtsProviderType::GeminiTts => &crate::cloud_tts_gemini::GeminiCloudTtsProvider,
        CloudTtsProviderType::VolcengineV3 => {
            &crate::cloud_tts_volcengine_v3::VolcengineV3CloudTtsProvider
        }
    }
}
pub(crate) fn invalid(message: &str) -> LegadoError {
    LegadoError::Ffi(message.into())
}

/// 合成及目录端点共用校验；签名音频下载地址允许查询参数，不走此入口。
pub(crate) fn parse_service_url(
    value: &str,
    parse_error: &str,
    policy_error: &str,
) -> LegadoResult<url::Url> {
    let url = url::Url::parse(value).map_err(|_| invalid(parse_error))?;
    if !matches!(url.scheme(), "http" | "https")
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
        || url.query().is_some()
        || url.fragment().is_some()
    {
        return Err(invalid(policy_error));
    }
    Ok(url)
}

/// 原始 PCM 到现有文件播放器的适配，单声道 16-bit LE；不重采样。
pub fn pcm16_mono_to_wav(pcm: &[u8], sample_rate: u32) -> LegadoResult<Vec<u8>> {
    if pcm.is_empty() || !pcm.len().is_multiple_of(2) || sample_rate == 0 {
        return Err(invalid("PCM 音频为空或样本/采样率无效"));
    }
    let size = u32::try_from(pcm.len()).map_err(|_| invalid("PCM 音频超过 WAV 容量"))?;
    let total = size
        .checked_add(36)
        .ok_or_else(|| invalid("PCM 音频超过 WAV 容量"))?;
    let byte_rate = sample_rate
        .checked_mul(2)
        .ok_or_else(|| invalid("PCM 采样率无效"))?;
    let mut result = Vec::with_capacity(pcm.len() + 44);
    result.extend_from_slice(b"RIFF");
    result.extend_from_slice(&total.to_le_bytes());
    result.extend_from_slice(b"WAVEfmt ");
    result.extend_from_slice(&16u32.to_le_bytes());
    result.extend_from_slice(&1u16.to_le_bytes());
    result.extend_from_slice(&1u16.to_le_bytes());
    result.extend_from_slice(&sample_rate.to_le_bytes());
    result.extend_from_slice(&byte_rate.to_le_bytes());
    result.extend_from_slice(&2u16.to_le_bytes());
    result.extend_from_slice(&16u16.to_le_bytes());
    result.extend_from_slice(b"data");
    result.extend_from_slice(&size.to_le_bytes());
    result.extend_from_slice(pcm);
    Ok(result)
}

#[cfg(test)]
mod speech_limits_tests {
    use super::*;

    #[test]
    fn advertised_byte_limit_matches_real_provider_request_validation() {
        let kind = CloudTtsProviderType::Volcengine;
        let limits = kind.speech_limits();
        let engine = CloudTtsEngine {
            id: "fixture".into(),
            provider: kind,
            api_key: "token-fixture".into(),
            app_id: "app-fixture".into(),
            ..Default::default()
        };
        let bytes = limits.max_utf8_bytes.unwrap() as usize;
        // 用多字节文本填满边界，不能以UTF-16计数替代字节数。
        let mut request = CloudTtsSynthesisRequest {
            text: format!("{}{}", "甲".repeat(bytes / 3), "a".repeat(bytes % 3)),
            voice_id: "BV001_streaming".into(),
            ..Default::default()
        };
        assert!(request.text.encode_utf16().count() < limits.max_utf16_units as usize);
        let provider = cloud_tts_provider(kind);
        assert!(provider.prepare(&engine, &request).is_ok());
        request.text.push('a');
        assert!(provider.prepare(&engine, &request).is_err());
    }
}
