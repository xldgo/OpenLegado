//! 朗读与媒体边界快照；凭据、取消和缓存租约仍由原执行链负责。— Codex + Bridge
use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum CloudTtsProviderDto {
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
impl From<legado_core::cloud_tts::CloudTtsProviderType> for CloudTtsProviderDto {
    fn from(v: legado_core::cloud_tts::CloudTtsProviderType) -> Self {
        match v {
            legado_core::cloud_tts::CloudTtsProviderType::OpenAiSpeech => Self::OpenAiSpeech,
            legado_core::cloud_tts::CloudTtsProviderType::Mimo => Self::Mimo,
            legado_core::cloud_tts::CloudTtsProviderType::AlibabaCloud => Self::AlibabaCloud,
            legado_core::cloud_tts::CloudTtsProviderType::AzureSpeech => Self::AzureSpeech,
            legado_core::cloud_tts::CloudTtsProviderType::AwsPolly => Self::AwsPolly,
            legado_core::cloud_tts::CloudTtsProviderType::Volcengine => Self::Volcengine,
            legado_core::cloud_tts::CloudTtsProviderType::GeminiTts => Self::GeminiTts,
            legado_core::cloud_tts::CloudTtsProviderType::VolcengineV3 => Self::VolcengineV3,
        }
    }
}
impl From<CloudTtsProviderDto> for legado_core::cloud_tts::CloudTtsProviderType {
    fn from(v: CloudTtsProviderDto) -> Self {
        match v {
            CloudTtsProviderDto::OpenAiSpeech => Self::OpenAiSpeech,
            CloudTtsProviderDto::Mimo => Self::Mimo,
            CloudTtsProviderDto::AlibabaCloud => Self::AlibabaCloud,
            CloudTtsProviderDto::AzureSpeech => Self::AzureSpeech,
            CloudTtsProviderDto::AwsPolly => Self::AwsPolly,
            CloudTtsProviderDto::Volcengine => Self::Volcengine,
            CloudTtsProviderDto::GeminiTts => Self::GeminiTts,
            CloudTtsProviderDto::VolcengineV3 => Self::VolcengineV3,
        }
    }
}
#[derive(Debug, Clone)]
pub struct CloudTtsSpeechLimitsDto {
    pub max_utf16_units: u32,
    pub max_utf8_bytes: Option<u32>,
}
impl From<legado_core::cloud_tts::CloudTtsSpeechLimits> for CloudTtsSpeechLimitsDto {
    fn from(value: legado_core::cloud_tts::CloudTtsSpeechLimits) -> Self {
        Self {
            max_utf16_units: value.max_utf16_units,
            max_utf8_bytes: value.max_utf8_bytes,
        }
    }
}
#[derive(Debug, Clone)]
pub struct HttpTtsConfigDto {
    pub id: i64,
    pub name: String,
    pub url: String,
    pub content_type: Option<String>,
    pub pause_duration: i32,
    pub concurrent_rate: Option<String>,
    pub login_url: Option<String>,
    pub login_ui: Option<String>,
    pub header: Option<String>,
    pub js_lib: Option<String>,
    pub enabled_cookie_jar: Option<bool>,
    pub login_check_js: Option<String>,
    pub speed: Option<i32>,
    pub synthesis_thread_count: i32,
    pub last_update_time: i64,
    pub is_enabled: bool,
}
impl From<legado_db::HttpTts> for HttpTtsConfigDto {
    fn from(v: legado_db::HttpTts) -> Self {
        Self {
            id: v.id,
            name: v.name,
            url: v.url,
            content_type: v.content_type,
            pause_duration: v.pause_duration,
            concurrent_rate: v.concurrent_rate,
            login_url: v.login_url,
            login_ui: v.login_ui,
            header: v.header,
            js_lib: v.js_lib,
            enabled_cookie_jar: v.enabled_cookie_jar,
            login_check_js: v.login_check_js,
            speed: v.speed,
            synthesis_thread_count: v.synthesis_thread_count,
            last_update_time: v.last_update_time,
            is_enabled: v.is_enabled,
        }
    }
}
impl From<HttpTtsConfigDto> for legado_db::HttpTts {
    fn from(v: HttpTtsConfigDto) -> Self {
        Self {
            id: v.id,
            name: v.name,
            url: v.url,
            content_type: v.content_type,
            pause_duration: v.pause_duration,
            concurrent_rate: v.concurrent_rate,
            login_url: v.login_url,
            login_ui: v.login_ui,
            header: v.header,
            js_lib: v.js_lib,
            enabled_cookie_jar: v.enabled_cookie_jar,
            login_check_js: v.login_check_js,
            speed: v.speed,
            synthesis_thread_count: v.synthesis_thread_count.clamp(
                1,
                legado_db::repository::http_tts_repository::MAX_SYNTHESIS_THREAD_COUNT,
            ),
            last_update_time: v.last_update_time,
            is_enabled: v.is_enabled,
        }
    }
}
#[derive(Debug, Clone)]
pub struct CloudTtsMetadataDto {
    pub id: String,
    pub name: String,
    pub provider: CloudTtsProviderDto,
    pub base_url: String,
    pub model: String,
    pub options_json: String,
    pub region: String,
    pub app_id: String,
    pub enabled: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub credential_key: String,
}
impl From<legado_db::repository::cloud_tts_repository::CloudTtsMetadata> for CloudTtsMetadataDto {
    fn from(v: legado_db::repository::cloud_tts_repository::CloudTtsMetadata) -> Self {
        Self {
            id: v.id,
            name: v.name,
            provider: v.provider.into(),
            base_url: v.base_url,
            model: v.model,
            options_json: v.options_json,
            region: v.region,
            app_id: v.app_id,
            enabled: v.enabled,
            created_at: v.created_at,
            updated_at: v.updated_at,
            credential_key: v.credential_key,
        }
    }
}
impl From<CloudTtsMetadataDto> for legado_db::repository::cloud_tts_repository::CloudTtsMetadata {
    fn from(v: CloudTtsMetadataDto) -> Self {
        Self {
            id: v.id,
            name: v.name,
            provider: v.provider.into(),
            base_url: v.base_url,
            model: v.model,
            options_json: v.options_json,
            region: v.region,
            app_id: v.app_id,
            enabled: v.enabled,
            created_at: v.created_at,
            updated_at: v.updated_at,
            credential_key: v.credential_key,
        }
    }
}
#[derive(Debug, Clone)]
pub struct CloudVoiceOptionsDto {
    pub voice_id: Option<String>,
    pub locale: Option<String>,
    pub style: Option<String>,
    pub role: Option<String>,
    pub instructions: Option<String>,
    pub speed: Option<f64>,
    pub pitch: Option<f64>,
    pub volume: Option<f64>,
    pub format: Option<String>,
    pub sample_rate: Option<u32>,
}
impl From<legado_db::repository::cloud_tts_repository::CloudVoiceOptions> for CloudVoiceOptionsDto {
    fn from(v: legado_db::repository::cloud_tts_repository::CloudVoiceOptions) -> Self {
        Self {
            voice_id: v.voice_id,
            locale: v.locale,
            style: v.style,
            role: v.role,
            instructions: v.instructions,
            speed: v.speed,
            pitch: v.pitch,
            volume: v.volume,
            format: v.format,
            sample_rate: v.sample_rate,
        }
    }
}
impl From<CloudVoiceOptionsDto> for legado_db::repository::cloud_tts_repository::CloudVoiceOptions {
    fn from(v: CloudVoiceOptionsDto) -> Self {
        Self {
            voice_id: v.voice_id,
            locale: v.locale,
            style: v.style,
            role: v.role,
            instructions: v.instructions,
            speed: v.speed,
            pitch: v.pitch,
            volume: v.volume,
            format: v.format,
            sample_rate: v.sample_rate,
        }
    }
}
#[derive(Debug, Clone)]
pub struct CloudVoiceDescriptorDto {
    pub id: String,
    pub display_name: String,
    pub locale: String,
    pub gender: String,
    pub roles: Vec<String>,
    pub supported_models: Vec<String>,
    pub styles: Vec<String>,
    pub sample_rate: Option<u32>,
}
impl From<legado_core::cloud_tts::CloudTtsVoiceDescriptor> for CloudVoiceDescriptorDto {
    fn from(v: legado_core::cloud_tts::CloudTtsVoiceDescriptor) -> Self {
        Self {
            id: v.id,
            display_name: v.display_name,
            locale: v.locale,
            gender: v.gender,
            roles: v.roles,
            supported_models: v.supported_models,
            styles: v.styles,
            sample_rate: v.sample_rate,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReadAloudVoiceDto {
    pub id: String,
    pub engine_type: String,
    pub engine_id: String,
    pub speaker_id: String,
    pub display_name: String,
    pub traits_json: String,
    pub emotion_catalog_json: String,
    pub managed_by: String,
    pub enabled: bool,
    pub available: bool,
    pub excluded: bool,
    pub revision: i64,
    pub created_at: i64,
    pub updated_at: i64,
}
impl From<legado_db::repository::read_aloud_voice_repository::ReadAloudVoice>
    for ReadAloudVoiceDto
{
    fn from(v: legado_db::repository::read_aloud_voice_repository::ReadAloudVoice) -> Self {
        Self {
            id: v.id,
            engine_type: v.engine_type,
            engine_id: v.engine_id,
            speaker_id: v.speaker_id,
            display_name: v.display_name,
            traits_json: v.traits_json,
            emotion_catalog_json: v.emotion_catalog_json,
            managed_by: v.managed_by,
            enabled: v.enabled,
            available: v.available,
            excluded: v.excluded,
            revision: v.revision,
            created_at: v.created_at,
            updated_at: v.updated_at,
        }
    }
}
impl From<ReadAloudVoiceDto>
    for legado_db::repository::read_aloud_voice_repository::ReadAloudVoice
{
    fn from(v: ReadAloudVoiceDto) -> Self {
        Self {
            id: v.id,
            engine_type: v.engine_type,
            engine_id: v.engine_id,
            speaker_id: v.speaker_id,
            display_name: v.display_name,
            traits_json: v.traits_json,
            emotion_catalog_json: v.emotion_catalog_json,
            managed_by: v.managed_by,
            enabled: v.enabled,
            available: v.available,
            excluded: v.excluded,
            revision: v.revision,
            created_at: v.created_at,
            updated_at: v.updated_at,
        }
    }
}
#[derive(Debug, Clone)]
pub struct SystemVoiceEntryDto {
    pub speaker_id: String,
    pub display_name: String,
    pub traits_json: String,
}
impl From<legado_db::repository::read_aloud_voice_repository::SystemVoiceEntry>
    for SystemVoiceEntryDto
{
    fn from(v: legado_db::repository::read_aloud_voice_repository::SystemVoiceEntry) -> Self {
        Self {
            speaker_id: v.speaker_id,
            display_name: v.display_name,
            traits_json: v.traits_json,
        }
    }
}
impl From<SystemVoiceEntryDto>
    for legado_db::repository::read_aloud_voice_repository::SystemVoiceEntry
{
    fn from(v: SystemVoiceEntryDto) -> Self {
        Self {
            speaker_id: v.speaker_id,
            display_name: v.display_name,
            traits_json: v.traits_json,
        }
    }
}
#[derive(Debug, Clone)]
pub struct TtsCacheContextDto {
    pub book_url: String,
    pub book_name: String,
    pub chapter_index: u32,
    pub chapter_title: String,
    pub paragraph_index: u32,
    pub text: String,
}
impl From<legado_core::tts_cache::CacheContext> for TtsCacheContextDto {
    fn from(v: legado_core::tts_cache::CacheContext) -> Self {
        Self {
            book_url: v.book_url,
            book_name: v.book_name,
            chapter_index: v.chapter_index,
            chapter_title: v.chapter_title,
            paragraph_index: v.paragraph_index,
            text: v.text,
        }
    }
}
impl From<TtsCacheContextDto> for legado_core::tts_cache::CacheContext {
    fn from(v: TtsCacheContextDto) -> Self {
        Self {
            book_url: v.book_url,
            book_name: v.book_name,
            chapter_index: v.chapter_index,
            chapter_title: v.chapter_title,
            paragraph_index: v.paragraph_index,
            text: v.text,
        }
    }
}
#[derive(Debug, Clone)]
pub struct TtsCacheEntryDto {
    pub name: String,
    pub size_bytes: u64,
    pub modified_at_ms: u64,
    pub protected: bool,
    pub contexts: Vec<TtsCacheContextDto>,
}
impl From<legado_core::tts_cache::CacheEntry> for TtsCacheEntryDto {
    fn from(v: legado_core::tts_cache::CacheEntry) -> Self {
        Self {
            name: v.name,
            size_bytes: v.size_bytes,
            modified_at_ms: v.modified_at_ms,
            protected: v.protected,
            contexts: v.contexts.into_iter().map(Into::into).collect(),
        }
    }
}
#[derive(Debug, Clone)]
pub struct TtsCacheClearResultDto {
    pub removed_files: u64,
    pub removed_bytes: u64,
    pub skipped_files: u64,
}
impl From<legado_core::tts_cache::ClearResult> for TtsCacheClearResultDto {
    fn from(v: legado_core::tts_cache::ClearResult) -> Self {
        Self {
            removed_files: v.removed_files,
            removed_bytes: v.removed_bytes,
            skipped_files: v.skipped_files,
        }
    }
}
#[derive(Debug, Clone)]
pub struct AudioChapterMediaDto {
    pub chapter_index: i32,
    pub title: String,
    pub media_url: String,
    pub chapter_url: String,
    pub resource_url: Option<String>,
    pub is_volume: bool,
    pub from_cache: bool,
    pub lyric: Option<String>,
    pub source_url: String,
}
impl From<crate::api::audio_api::AudioChapterMedia> for AudioChapterMediaDto {
    fn from(v: crate::api::audio_api::AudioChapterMedia) -> Self {
        Self {
            chapter_index: v.chapter_index,
            title: v.title,
            media_url: v.media_url,
            chapter_url: v.chapter_url,
            resource_url: v.resource_url,
            is_volume: v.is_volume,
            from_cache: v.from_cache,
            lyric: v.lyric,
            source_url: v.source_url,
        }
    }
}
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TtsSpeakDto {
    pub audio_path: String,
    pub from_cache: bool,
    pub content_type: String,
}
#[derive(Debug, Clone)]
pub struct CloudSpeechInputDto {
    pub text: String,
    pub credential_key: String,
    pub voice_id: Option<String>,
    pub voice_options: Option<CloudVoiceOptionsDto>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AudioCacheDownloadStatusDto {
    Installed,
    AlreadyCached,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioCacheDownloadDto {
    pub status: AudioCacheDownloadStatusDto,
    pub path: String,
    pub size_bytes: u64,
    pub extension: String,
}

impl From<CloudSpeechInputDto> for legado_engine::tts_service::CloudSpeechInput {
    fn from(v: crate::media_dto::CloudSpeechInputDto) -> Self {
        Self {
            text: v.text,
            credential_key: v.credential_key,
            voice_id: v.voice_id,
            voice_options: v.voice_options.map(Into::into),
        }
    }
}

impl From<legado_engine::audio_cache_service::AudioCacheDownload> for AudioCacheDownloadDto {
    fn from(v: legado_engine::audio_cache_service::AudioCacheDownload) -> Self {
        use legado_engine::audio_cache_service::AudioCacheDownloadStatus;
        Self {
            status: match v.status {
                AudioCacheDownloadStatus::Installed => AudioCacheDownloadStatusDto::Installed,
                AudioCacheDownloadStatus::AlreadyCached => {
                    AudioCacheDownloadStatusDto::AlreadyCached
                }
            },
            path: v.path,
            size_bytes: v.size_bytes,
            extension: v.extension,
        }
    }
}
