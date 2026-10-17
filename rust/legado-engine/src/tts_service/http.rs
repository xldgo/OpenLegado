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
        let context = TtsSpeakContext::new(
            text,
            self.config.effective_speed(),
            tone_id.as_deref(),
            speaker_name.as_deref(),
            emotion_tag.as_deref(),
        );
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
    fn isolated_cancelled_response_script_remains_registered_until_actual_exit() {
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
        assert!(!block_on(tasks.shutdown(Duration::from_millis(20))));
        assert!(tasks.active_count() > 0);
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
        assert!(block_on(tasks.shutdown(Duration::from_secs(5))));
        assert!(std::fs::read_dir(&directory).unwrap().next().is_none());
        drop(storage);
    }
}
