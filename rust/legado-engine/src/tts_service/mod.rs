//! 朗读应用服务：配置、登录与合成使用同一份实例资源，宿主管理运行时与播放租约。
mod cloud;
mod http;
mod source;
use crate::{MediaState, NetworkContext, SourceLoginCache, StorageContext, TaskGroup};
pub use cloud::CloudSpeechInput;
pub use http::HttpTtsOperation;
use legado_core::LegadoResult;
use legado_fetcher::tts_control::TtsCancellation;
pub use source::config_for_storage;
use std::sync::Arc;

#[derive(Clone)]
pub struct TtsResources {
    pub storage: StorageContext,
    pub media: Arc<MediaState>,
    pub network: Arc<NetworkContext>,
    pub rates: Arc<legado_fetcher::rate_limit::RateLimiterRegistry>,
    pub js: Arc<legado_js::JsResources>,
    pub login: Arc<SourceLoginCache>,
    pub tasks: TaskGroup,
}
#[derive(Clone)]
pub struct TtsService {
    resources: TtsResources,
}
impl TtsService {
    pub fn new(resources: TtsResources) -> Self {
        Self { resources }
    }
    pub fn prepare_http(
        &self,
        id: i64,
        cancellation: &TtsCancellation,
    ) -> LegadoResult<HttpTtsOperation> {
        cancellation.check()?;
        http::HttpTtsOperation::capture(&self.resources, id, cancellation)
    }
    pub fn login(&self, id: i64, operation: &str, payload: &str) -> LegadoResult<String> {
        source::login(&self.resources, id, operation, payload)
    }
    pub async fn cloud_speak(
        &self,
        id: &str,
        api_key: String,
        input: CloudSpeechInput,
        cancellation: &TtsCancellation,
    ) -> LegadoResult<legado_fetcher::cloud_tts::CloudTtsSynthesisResult> {
        cloud::speak(&self.resources, id, api_key, input, cancellation).await
    }
    pub async fn cloud_voices(
        &self,
        id: &str,
        api_key: String,
        credential_key: &str,
        cancellation: &TtsCancellation,
    ) -> LegadoResult<Vec<legado_core::cloud_tts::CloudTtsVoiceDescriptor>> {
        cloud::voices(&self.resources, id, api_key, credential_key, cancellation).await
    }
}
