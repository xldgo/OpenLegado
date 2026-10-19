//! 云端合成：凭据仅参与当前调用，校验与发布门控不依赖宿主。
use legado_core::{LegadoResult, cloud_tts::*};
use legado_db::repository::cloud_tts_repository::CloudTtsRepository;
#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CloudSpeechInput {
    pub text: String,
    pub credential_key: String,
    #[serde(default)]
    pub voice_id: Option<String>,
    #[serde(default)]
    pub voice_options: Option<legado_db::repository::cloud_tts_repository::CloudVoiceOptions>,
}
pub(super) async fn speak(
    resources: &super::TtsResources,
    id: &str,
    api_key: String,
    input: CloudSpeechInput,
    cancellation: &legado_fetcher::tts_control::TtsCancellation,
) -> LegadoResult<legado_fetcher::cloud_tts::CloudTtsSynthesisResult> {
    cancellation.check()?;
    let task = resources
        .tasks
        .begin()
        .map_err(|e| legado_core::LegadoError::Ffi(e.to_string()))?;
    let _guard = task.guard();
    let storage = &resources.storage;
    let media = &resources.media;
    let hosts = resources.network.custom_hosts().clone();
    let directory = media.tts_directory();
    let mut metadata =
        storage.with_database(|db| CloudTtsRepository::new(db.connection()).get(id))?;
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
        let voice = storage.with_database(|db| {
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
        options.validate()?;
        metadata.options_json = serde_json::to_string(&options)?;
    }
    let request = metadata.request(input.text)?;
    let engine = metadata.engine(api_key);
    let transport = media.cloud_transport(hosts)?;
    let result = async {
        tokio::select! {
            biased;
            _ = task.cancelled() => Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())),
            result = legado_fetcher::cloud_tts::synthesize_cloud_tts_with_publish(
                cloud_tts_provider(metadata.provider), transport.as_ref(), &engine, &request,
                &directory, cancellation, |cache, key, extension, bytes| {
                    task.with_active(|| { cancellation.check()?; cache.put(key, extension, bytes) })
                        .unwrap_or_else(|| Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())))
                },
            ) => result,
        }
    }.await?;
    cancellation.check()?;
    task.with_active(|| Ok(result))
        .unwrap_or_else(|| Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{EngineContext, test_http_fixture::Fixture};
    use legado_db::repository::cloud_tts_repository::CloudTtsMetadata;
    use legado_fetcher::tts_control::TtsCancellation;
    use std::sync::Arc;

    fn engine(base: &str, credential: &str) -> Arc<EngineContext> {
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        engine
            .media()
            .set_tts_directory(engine.storage().data_directory("cloud-speech").unwrap());
        engine
            .storage()
            .with_database(|db| {
                CloudTtsRepository::new(db.connection()).save(&CloudTtsMetadata {
                    id: "same-cloud".into(),
                    name: "云端服务测试".into(),
                    provider: CloudTtsProviderType::OpenAiSpeech,
                    base_url: format!("{base}/v1"),
                    model: "gpt-4o-mini-tts".into(),
                    options_json: r#"{"voiceId":"coral","format":"mp3"}"#.into(),
                    region: String::new(),
                    app_id: String::new(),
                    enabled: true,
                    created_at: 0,
                    updated_at: 0,
                    credential_key: credential.into(),
                })
            })
            .unwrap();
        engine
    }
    fn input(credential: &str) -> CloudSpeechInput {
        CloudSpeechInput {
            text: "中文 😀".into(),
            credential_key: credential.into(),
            voice_id: None,
            voice_options: None,
        }
    }

    #[tokio::test]
    async fn draft_non_finite_numbers_fail_before_json_can_erase_them() {
        use legado_db::repository::cloud_tts_repository::CloudVoiceOptions;
        let engine = engine("http://127.0.0.1:1", "cloud-tts:same-cloud:finite");
        for (key, value) in [
            ("speed", f64::NAN),
            ("pitch", f64::INFINITY),
            ("volume", f64::NEG_INFINITY),
        ] {
            let mut options = CloudVoiceOptions::default();
            match key {
                "speed" => options.speed = Some(value),
                "pitch" => options.pitch = Some(value),
                _ => options.volume = Some(value),
            }
            let mut request = input("cloud-tts:same-cloud:finite");
            request.voice_options = Some(options);
            let error = engine
                .tts_service()
                .cloud_speak(
                    "same-cloud",
                    "fixture".into(),
                    request,
                    &TtsCancellation::default(),
                )
                .await
                .err()
                .unwrap();
            assert!(error.to_string().contains("数值必须为有限值"));
            assert_eq!(engine.tasks().active_count(), 0);
        }
    }

    #[tokio::test]
    async fn cloud_instances_keep_credentials_cache_and_leases_separate() {
        let mut fixture =
            Fixture::with_content_type(2, false, "audio/mpeg", |_| "ID3-cloud".into());
        let first = engine(&fixture.url, "cloud-tts:same-cloud:first");
        let second = engine(&fixture.url, "cloud-tts:same-cloud:second");
        let cancellation = TtsCancellation::default();
        let one = first
            .tts_service()
            .cloud_speak(
                "same-cloud",
                "first-secret".into(),
                input("cloud-tts:same-cloud:first"),
                &cancellation,
            )
            .await
            .unwrap();
        let two = second
            .tts_service()
            .cloud_speak(
                "same-cloud",
                "second-secret".into(),
                input("cloud-tts:same-cloud:second"),
                &cancellation,
            )
            .await
            .unwrap();
        assert_ne!(one.audio_path, two.audio_path);
        assert!(
            one.audio_path
                .starts_with(first.media().tts_directory().canonicalize().unwrap())
        );
        assert!(
            two.audio_path
                .starts_with(second.media().tts_directory().canonicalize().unwrap())
        );
        assert_eq!(std::fs::read(&one.audio_path).unwrap(), b"ID3-cloud");
        let one_request = fixture.request().await.to_lowercase();
        let two_request = fixture.request().await.to_lowercase();
        assert!(one_request.starts_with("post /v1/audio/speech "));
        assert!(one_request.contains("authorization: bearer first-secret"));
        assert!(!one_request.contains("second-secret"));
        assert!(two_request.contains("authorization: bearer second-secret"));
        let cached = first
            .tts_service()
            .cloud_speak(
                "same-cloud",
                "first-secret".into(),
                input("cloud-tts:same-cloud:first"),
                &cancellation,
            )
            .await
            .unwrap();
        assert!(cached.from_cache);
        let error = second
            .tts_service()
            .cloud_speak(
                "same-cloud",
                "unused".into(),
                input("cloud-tts:same-cloud:first"),
                &cancellation,
            )
            .await
            .err()
            .unwrap();
        assert!(error.to_string().contains("凭据在读取期间已变更"));
        fixture.worker.join().unwrap();
        assert_eq!(first.tasks().active_count(), 0);
        assert_eq!(second.tasks().active_count(), 0);
    }

    #[tokio::test]
    async fn closing_cloud_root_cancels_wait_and_never_publishes_audio() {
        let mut fixture = Fixture::with_content_type(1, true, "audio/mpeg", |_| "ID3-late".into());
        let engine = engine(&fixture.url, "cloud-tts:same-cloud:cancel");
        let storage = engine.storage().clone();
        let weak = Arc::downgrade(&engine);
        let service = engine.tts_service();
        let directory = engine.media().tts_directory();
        let tasks = engine.tasks().clone();
        let worker = tokio::spawn(async move {
            service
                .cloud_speak(
                    "same-cloud",
                    "test-secret".into(),
                    input("cloud-tts:same-cloud:cancel"),
                    &TtsCancellation::default(),
                )
                .await
        });
        assert!(
            fixture
                .request()
                .await
                .starts_with("POST /v1/audio/speech ")
        );
        drop(engine);
        assert!(weak.upgrade().is_none());
        let result = tokio::time::timeout(std::time::Duration::from_secs(3), worker)
            .await
            .unwrap()
            .unwrap();
        assert!(result.err().unwrap().to_string().contains("TTS_CANCELLED"));
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
        assert!(std::fs::read_dir(directory).unwrap().next().is_none());
        assert!(tasks.shutdown(std::time::Duration::from_secs(3)).await);
        drop(storage);
    }
}
