//! 云端配置与合成薄接口；平台凭据仅在调用时临时传入。
use legado_core::{LegadoResult, cloud_tts::*};
use legado_db::repository::cloud_tts_repository::{CloudTtsMetadata, CloudTtsRepository};
pub fn list() -> LegadoResult<Vec<CloudTtsMetadata>> {
    crate::db_state::with_database(|db| CloudTtsRepository::new(db.connection()).list())
}
pub fn save(metadata: CloudTtsMetadata) -> LegadoResult<()> {
    crate::db_state::with_database(|db| CloudTtsRepository::new(db.connection()).save(&metadata))
}
pub fn delete(id: &str) -> LegadoResult<bool> {
    crate::db_state::with_database(|db| CloudTtsRepository::new(db.connection()).delete(id))
}
pub fn voices(provider: CloudTtsProviderType) -> Vec<CloudTtsVoiceDescriptor> {
    cloud_tts_provider(provider).voices()
}
pub use legado_engine::tts_service::CloudSpeechInput;
pub fn speak(
    id: &str,
    api_key: String,
    input: CloudSpeechInput,
    cancellation: &legado_fetcher::tts_control::TtsCancellation,
) -> LegadoResult<legado_fetcher::cloud_tts::CloudTtsSynthesisResult> {
    cancellation.check()?;
    let service = crate::engine_holder::current()?.tts_service();
    crate::runtime::block_on(service.cloud_speak(id, api_key, input, cancellation))
}
