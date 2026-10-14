//! 云端配置与合成薄接口；平台凭据仅在调用时临时传入。
use legado_core::{LegadoResult, cloud_tts::*};
use legado_db::repository::cloud_tts_repository::{CloudTtsMetadata, CloudTtsRepository};
pub fn list() -> LegadoResult<String> {
    crate::db_state::with_database(|db| {
        Ok(serde_json::to_string(
            &CloudTtsRepository::new(db.connection()).list()?,
        )?)
    })
}
pub fn save(json: &str) -> LegadoResult<()> {
    let metadata: CloudTtsMetadata = serde_json::from_str(json)?;
    crate::db_state::with_database(|db| CloudTtsRepository::new(db.connection()).save(&metadata))
}
pub fn delete(id: &str) -> LegadoResult<bool> {
    crate::db_state::with_database(|db| CloudTtsRepository::new(db.connection()).delete(id))
}
pub fn voices(provider: &str) -> LegadoResult<String> {
    let kind: CloudTtsProviderType = serde_json::from_value(serde_json::json!(provider))?;
    Ok(serde_json::to_string(&cloud_tts_provider(kind).voices())?)
}
pub fn speak(
    id: &str,
    api_key: String,
    json: &str,
    cancellation: &legado_fetcher::tts_control::TtsCancellation,
) -> LegadoResult<legado_fetcher::cloud_tts::CloudTtsSynthesisResult> {
    cancellation.check()?;
    let mut metadata =
        crate::db_state::with_database(|db| CloudTtsRepository::new(db.connection()).get(id))?;
    #[derive(serde::Deserialize)]
    #[serde(rename_all = "camelCase", deny_unknown_fields)]
    struct Input {
        text: String,
        credential_key: String,
        #[serde(default)]
        voice_id: Option<String>,
        #[serde(default)]
        voice_options: Option<legado_db::repository::cloud_tts_repository::CloudVoiceOptions>,
    }
    let input: Input = serde_json::from_str(json)?;
    if input.credential_key != metadata.credential_key {
        return Err(legado_core::LegadoError::Ffi(
            "云端凭据在读取期间已变更，请重试".into(),
        ));
    }
    if input.voice_id.is_some() && input.voice_options.is_some() {
        return Err(legado_core::LegadoError::Ffi(
            "不能同时指定音色记录和试听草稿".into(),
        ));
    }
    if let Some(id) = input.voice_id {
        let voice = crate::db_state::with_database(|db| {
            legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(
                db.connection(),
            )
            .get(&id)
        })?;
        if voice.engine_type != "cloud_tts"
            || voice.engine_id != metadata.id
            || !voice.enabled
            || !voice.available
            || voice.excluded
        {
            return Err(legado_core::LegadoError::Ffi(
                "音色不属于该引擎或不可用".into(),
            ));
        }
        let mut traits: serde_json::Map<String, serde_json::Value> =
            serde_json::from_str(&voice.traits_json)?;
        traits.insert("voiceId".into(), serde_json::json!(voice.speaker_id));
        metadata.options_json = serde_json::to_string(&traits)?;
    } else if let Some(options) = input.voice_options {
        metadata.options_json = serde_json::to_string(&options)?;
    }
    let request = metadata.request(input.text)?;
    let engine = metadata.engine(api_key);
    static TRANSPORT: std::sync::OnceLock<legado_fetcher::cloud_tts::CloudTtsHttpTransport> =
        std::sync::OnceLock::new();
    if TRANSPORT.get().is_none() {
        let _ = TRANSPORT.set(legado_fetcher::cloud_tts::CloudTtsHttpTransport::new()?);
    }
    crate::runtime::block_on(legado_fetcher::cloud_tts::synthesize_cloud_tts(
        cloud_tts_provider(metadata.provider),
        TRANSPORT.get().unwrap(),
        &engine,
        &request,
        &super::tts_speak_api::tts_cache_dir(),
        cancellation,
    ))
}
