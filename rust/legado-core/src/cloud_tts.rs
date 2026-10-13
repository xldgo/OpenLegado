//! 云端合成模型和 Provider 纯计算边界；不访问网络、数据库或 Flutter。
use crate::{LegadoError, LegadoResult};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fmt;

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum CloudTtsProviderType {
    #[serde(rename = "openai_speech")]
    OpenAiSpeech,
    #[serde(rename = "mimo")]
    Mimo,
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
    pub model: String,
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
            model: "gpt-4o-mini-tts".into(),
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
#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct CloudTtsVoiceDescriptor {
    pub id: String,
    pub display_name: String,
    pub styles: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sample_rate: Option<u32>,
}
/// 不实现 Debug/Serialize：请求体含私人正文，Authorization 含凭据。
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum CloudSpeechResponseKind {
    AudioBytes,
    EventStream,
}
pub struct PreparedCloudSpeech {
    pub endpoint: String,
    pub credential_header: &'static str,
    pub authorization: String,
    pub response_kind: CloudSpeechResponseKind,
    pub body: Value,
    pub response_format: String,
}
pub struct CloudTtsAudio {
    pub bytes: Vec<u8>,
    pub extension: &'static str,
    pub content_type: &'static str,
}
pub trait CloudTtsProvider: Send + Sync {
    fn provider_type(&self) -> CloudTtsProviderType;
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor>;
    fn prepare(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech>;
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio>;
}
/// 元数据校验、音色发现与合成执行必须走同一 Provider 分派。
pub fn cloud_tts_provider(kind: CloudTtsProviderType) -> &'static dyn CloudTtsProvider {
    match kind {
        CloudTtsProviderType::OpenAiSpeech => &crate::cloud_tts_openai::OpenAiCloudTtsProvider,
        CloudTtsProviderType::Mimo => &crate::cloud_tts_mimo::MimoCloudTtsProvider,
    }
}
pub(crate) fn invalid(message: &str) -> LegadoError {
    LegadoError::Ffi(message.into())
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
