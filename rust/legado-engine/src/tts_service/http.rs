//! HTTP合成操作持有入口快照，不持有根引擎或运行时。
use legado_core::LegadoResult;
use legado_fetcher::TtsSpeakContext;
use std::path::PathBuf;
/// 合成只携带本次能力快照；不反向持有引擎，也不重读宿主缓存路径。
pub struct HttpTtsOperation {
    config: legado_fetcher::HttpTtsConfig,
    cache_dir: PathBuf,
    network: std::sync::Arc<crate::NetworkContext>,
    rates: std::sync::Arc<legado_fetcher::rate_limit::RateLimiterRegistry>,
    store: std::sync::Arc<super::source::DbTtsSourceStore>,
    task: crate::TaskHandle,
    emotion_catalogs: Vec<(String, String)>,
}
impl HttpTtsOperation {
    pub(super) fn capture(
        engine: &super::TtsResources,
        id: i64,
        cancellation: &legado_fetcher::tts_control::TtsCancellation,
    ) -> LegadoResult<Self> {
        let task = engine
            .tasks
            .begin()
            .map_err(|e| legado_core::LegadoError::Ffi(e.to_string()))?;
        let config = super::source::config_for_storage(&engine.storage, id)?;
        let emotion_catalogs = engine.storage.with_database(|db| {
            legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(
                db.connection(),
            )
            .http_emotion_catalogs(id)
        })?;
        Ok(Self {
            config,
            cache_dir: engine.media.tts_directory(),
            network: engine.network.clone(),
            rates: engine.rates.clone(),
            store: std::sync::Arc::new(
                super::source::DbTtsSourceStore::for_resources(engine)
                    .with_task(task.clone(), Some(cancellation.clone())),
            ),
            task,
            emotion_catalogs,
        })
    }
    pub async fn speak(
        self,
        text: &str,
        tone_id: Option<String>,
        speaker_name: Option<String>,
        emotion_tag: Option<String>,
        cancellation: &legado_fetcher::tts_control::TtsCancellation,
    ) -> LegadoResult<legado_fetcher::tts_fetcher::TtsFetchResult> {
        let _guard = self.task.guard();
        let catalog = self
            .emotion_catalogs
            .iter()
            .filter(|(speaker, _)| Some(speaker.as_str()) == tone_id.as_deref())
            .chain(self.emotion_catalogs.iter())
            .find_map(|(_, json)| {
                serde_json::from_str::<Vec<legado_core::tts_catalog::EmotionDraft>>(json)
                    .ok()
                    .filter(|catalog| !catalog.is_empty())
            })
            .unwrap_or_default();
        let emotion =
            legado_core::tts_emotion::map_emotion(emotion_tag.as_deref().unwrap_or(""), &catalog);
        let mut context = TtsSpeakContext::new(
            text,
            self.config.effective_speed(),
            tone_id.as_deref(),
            speaker_name.as_deref(),
            (!emotion.emotion_tag.is_empty()).then_some(emotion.emotion_tag.as_str()),
        );
        context.emotion_name =
            (!emotion.emotion_name.is_empty()).then_some(emotion.emotion_name.as_str());
        let client = self.network.client()?;
        let result = async {
            tokio::select! {
                biased;
                _ = self.task.cancelled() => Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())),
                result = legado_fetcher::tts_fetcher::fetch_tts_audio_controlled(&client, &self.config, &context, &self.cache_dir, None, legado_fetcher::tts_fetcher::TtsFetchResources {store: self.store, rates: self.rates}, cancellation) => result,
            }
        }.await?;
        cancellation.check()?;
        self.task
            .with_active(|| Ok(result))
            .unwrap_or_else(|| Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())))
    }
}

#[cfg(test)]
mod tests {
    use crate::tts_service::http::HttpTtsOperation;
    fn prepare(
        engine: &crate::EngineContext,
        cancel: &legado_fetcher::tts_control::TtsCancellation,
    ) -> HttpTtsOperation {
        engine.tts_service().prepare_http(12345, cancel).unwrap()
    }
    fn block_on<F: std::future::Future>(future: F) -> F::Output {
        static RUNTIME: std::sync::OnceLock<tokio::runtime::Runtime> = std::sync::OnceLock::new();
        RUNTIME
            .get_or_init(|| {
                tokio::runtime::Builder::new_multi_thread()
                    .worker_threads(2)
                    .enable_all()
                    .build()
                    .unwrap()
            })
            .block_on(future)
    }

    fn isolated_engine(url: &str) -> std::sync::Arc<crate::EngineContext> {
        let engine = std::sync::Arc::new(crate::EngineContext::in_memory().unwrap());
        engine
            .media()
            .set_tts_directory(engine.storage().data_directory("speech").unwrap());
        engine
            .storage()
            .with_database(|db| {
                legado_db::HttpTtsRepository::new(db.connection()).insert_entity(
                    &legado_db::HttpTts {
                        id: 12345,
                        name: "独立合成测试".into(),
                        url: url.into(),
                        ..Default::default()
                    },
                )
            })
            .unwrap();
        engine
    }

    #[test]
    fn voice_variables_and_emotion_catalog_snapshot_control_cache() {
        use crate::test_http_fixture::Fixture;
        let mut fixture =
            Fixture::with_content_type(3, false, "audio/mpeg", |_| "ID3-audio".into());
        let engine = isolated_engine(&format!(
            "{}/tts?tone={{{{currentToneID}}}}&speaker={{{{currentSpeakerName}}}}&emotion={{{{currentEmotionTag}}}}&name={{{{currentEmotionName}}}}",
            fixture.url
        ));
        let sync = |name: &str| {
            engine.storage().with_database(|db| {
            let draft = legado_core::tts_catalog::parse(&serde_json::json!({
                "speakersJson": r#"[{"speakerName":"Speaker","toneID":"a"},{"speakerName":"Other","toneID":"b"}]"#,
                "emotionsJson": serde_json::json!([
                    {"emotionName": name, "emotionTag": "private_happy"},
                    {"emotionName": "Sad", "emotionTag": "private_sad"},
                ]).to_string(),
            }));
            legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(db.connection()).sync_http(12345, &draft, 1)
        }).unwrap()
        };
        sync("Cheerful");
        let cancellation = legado_fetcher::tts_control::TtsCancellation::default();
        let old = prepare(&engine, &cancellation);
        sync("CheerfulB");
        let speak = |operation: HttpTtsOperation, emotion: &str| {
            block_on(operation.speak(
                "同一正文",
                Some("a".into()),
                Some("Speaker".into()),
                Some(emotion.into()),
                &cancellation,
            ))
        };
        let first = speak(old, "private_happy").unwrap();
        let changed = speak(prepare(&engine, &cancellation), "private_happy").unwrap();
        let cached = speak(prepare(&engine, &cancellation), "private_happy").unwrap();
        let sad = speak(prepare(&engine, &cancellation), "private_sad").unwrap();
        assert!(!first.from_cache && !changed.from_cache && !sad.from_cache);
        assert!(cached.from_cache);
        assert_eq!(changed.audio_path, cached.audio_path);
        assert_ne!(first.audio_path, changed.audio_path);
        assert_ne!(changed.audio_path, sad.audio_path);
        engine.storage().with_database(|db| {
            db.connection().execute("UPDATE read_aloud_voices SET emotionCatalogJson='[]' WHERE engineId='12345' AND speakerId='a'", [])
                .map_err(|e|legado_core::LegadoError::Database(e.to_string()))?;
            Ok(())
        }).unwrap();
        let fallback = speak(prepare(&engine, &cancellation), "private_sad").unwrap();
        assert!(fallback.from_cache);
        assert_eq!(fallback.audio_path, sad.audio_path);
        let requests = block_on(async {
            vec![
                fixture.request().await,
                fixture.request().await,
                fixture.request().await,
            ]
        });
        assert!(
            requests[0].contains("tone=a&speaker=Speaker&emotion=private_happy&name=Cheerful ")
        );
        assert!(requests[1].contains("name=CheerfulB "));
        assert!(requests[2].contains("emotion=private_sad&name=Sad "));
        fixture.worker.join().unwrap();
        assert_eq!(engine.tasks().active_count(), 0);
    }

    #[test]
    fn isolated_real_synthesis_uses_original_config_cookie_and_directory() {
        use crate::test_http_fixture::Fixture;
        let mut fixture =
            Fixture::with_content_type(2, false, "audio/mpeg", |_| "ID3-audio".into());
        let first = isolated_engine(&format!("{}/first?text={{{{speakText}}}}", fixture.url));
        let second = isolated_engine(&format!("{}/second?text={{{{speakText}}}}", fixture.url));
        first
            .source_login_cache()
            .put_login_header("httpTts:12345", r#"{"X-Instance":"first"}"#);
        second
            .source_login_cache()
            .put_login_header("httpTts:12345", r#"{"X-Instance":"second"}"#);
        let cancellation = legado_fetcher::tts_control::TtsCancellation::default();
        let before = first.media().tts_directory();
        let operation = prepare(&first, &cancellation);
        first
            .media()
            .set_tts_directory(first.storage().data_directory("next-speech").unwrap());
        let first_audio =
            block_on(operation.speak("测试", None, None, None, &cancellation)).unwrap();
        let second_audio = block_on(prepare(&second, &cancellation).speak(
            "测试",
            None,
            None,
            None,
            &cancellation,
        ))
        .unwrap();
        assert_eq!(first_audio.audio_path.as_path().parent().unwrap(), before);
        assert_ne!(first_audio.audio_path, second_audio.audio_path);
        assert_eq!(
            std::fs::read(&first_audio.audio_path).unwrap(),
            b"ID3-audio"
        );
        assert!(!first_audio.from_cache && !second_audio.from_cache);
        let requests = block_on(async { vec![fixture.request().await, fixture.request().await] });
        assert!(requests[0].starts_with("GET /first?"));
        assert!(requests[1].starts_with("GET /second?"));
        assert!(requests[0].to_lowercase().contains("x-instance: first"));
        assert!(requests[1].to_lowercase().contains("x-instance: second"));
        fixture.worker.join().unwrap();
        assert_eq!(first.tasks().active_count(), 0);
        assert_eq!(second.tasks().active_count(), 0);
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn isolated_cancelled_response_script_exits_before_server_unblocks() {
        use crate::test_http_fixture::Fixture;
        use std::sync::Arc;
        use std::time::Duration;
        let mut fixture = Fixture::with_content_type(2, true, "audio/mpeg", |_| "ID3-audio".into());
        let engine = isolated_engine(&format!("{}/speech", fixture.url));
        engine
            .storage()
            .with_database(|db| {
                db.connection()
                    .execute(
                        "UPDATE httpTTS SET loginCheckJs=? WHERE id=12345",
                        [format!("java.ajax('{}/blocked'); result", fixture.url)],
                    )
                    .unwrap();
                Ok(())
            })
            .unwrap();
        let storage = engine.storage().clone();
        let directory = engine.media().tts_directory();
        let tasks = engine.tasks().clone();
        let weak = Arc::downgrade(&engine);
        let cancellation = legado_fetcher::tts_control::TtsCancellation::default();
        let operation = prepare(&engine, &cancellation);
        fixture.release.send(()).unwrap();
        let worker = std::thread::spawn(move || {
            block_on(operation.speak("测试", None, None, None, &cancellation))
        });
        let speech = block_on(fixture.request());
        assert!(speech.starts_with("GET /speech "));
        let script = block_on(fixture.request());
        assert!(script.starts_with("GET /blocked "));
        drop(engine);
        assert!(weak.upgrade().is_none());
        let result = worker.join().unwrap();
        assert!(result.unwrap_err().to_string().contains("TTS_CANCELLED"));
        assert!(block_on(tasks.shutdown(Duration::from_secs(2))));
        assert_eq!(tasks.active_count(), 0);
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
        assert!(block_on(tasks.shutdown(Duration::from_secs(5))));
        assert!(std::fs::read_dir(&directory).unwrap().next().is_none());
        drop(storage);
    }
}
