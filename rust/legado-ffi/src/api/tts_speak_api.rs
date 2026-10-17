//! HTTP TTS 语音合成管线 API（Task #113 批次 2 缺口② / T2a）
//!
//! 对照 Kotlin 原版 `HttpReadAloudService.getSpeakStream` 与 `AnalyzeUrl`：
//! 1. 以 `engine_id: i64` 为唯一主身份，查库获取完整 `HttpTts` 实体。
//! 2. 委托给 `legado_fetcher::fetch_tts_audio` 执行完整 TTS 请求管线（变量替换、内嵌 JS、@Header、@Body、POST/GET、MIME 校验与缓存落盘）。
//! 3. 保持返回值 `TtsSpeakDto`（camelCase 对齐 Dart 侧解析约定）。

use std::path::PathBuf;

use serde::Serialize;

use legado_core::LegadoResult;
use legado_fetcher::TtsSpeakContext;

/// TTS 合成结果 DTO（camelCase 对齐 Dart 侧解析约定，见 API_CONTRACT §2.42）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TtsSpeakDto {
    /// 本地音频文件绝对路径
    pub audio_path: String,
    /// 是否缓存命中（true 时未发起网络请求）
    pub from_cache: bool,
    /// 音频 MIME 类型
    pub content_type: String,
}

/// 获取当前宿主的 TTS 音频缓存目录；已开始的合成保留其入口快照。
pub fn tts_cache_dir() -> PathBuf {
    crate::engine_holder::media().tts_directory()
}

/// 设置当前宿主的 TTS 缓存目录，失败不发布新路径。
pub fn set_tts_cache_dir(path: &str) -> LegadoResult<bool> {
    let dir = PathBuf::from(path);
    std::fs::create_dir_all(&dir)?;
    crate::engine_holder::media().set_tts_directory(dir);
    Ok(true)
}

/// TTS 真实合成：返回本地音频文件路径（缓存命中时免网络请求）
///
/// - `engine_id`: 数据库 HTTP TTS 引擎 ID
/// - `text`: 朗读文本
/// - `tone_id`: 音色 ID（可选）
/// - `speaker_name`: 发音人名称（可选）
/// - `emotion_tag`: 情感标签（可选）
pub fn tts_speak(
    engine_id: i64,
    text: &str,
    tone_id: Option<String>,
    speaker_name: Option<String>,
    emotion_tag: Option<String>,
) -> LegadoResult<TtsSpeakDto> {
    tts_speak_controlled(
        engine_id,
        text,
        tone_id,
        speaker_name,
        emotion_tag,
        &legado_fetcher::tts_control::TtsCancellation::default(),
    )
}

pub fn tts_speak_controlled(
    engine_id: i64,
    text: &str,
    tone_id: Option<String>,
    speaker_name: Option<String>,
    emotion_tag: Option<String>,
    cancellation: &legado_fetcher::tts_control::TtsCancellation,
) -> LegadoResult<TtsSpeakDto> {
    cancellation.check()?;
    let engine = crate::engine_holder::current()?;
    let operation = TtsOperation::capture(&engine, engine_id, cancellation)?;
    drop(engine);
    operation.speak(text, tone_id, speaker_name, emotion_tag, cancellation)
}

/// 合成只携带本次能力快照；不反向持有引擎，也不重读宿主缓存路径。
struct TtsOperation {
    config: legado_fetcher::HttpTtsConfig,
    cache_dir: PathBuf,
    network: std::sync::Arc<legado_engine::NetworkContext>,
    rates: std::sync::Arc<legado_fetcher::rate_limit::RateLimiterRegistry>,
    store: std::sync::Arc<super::http_tts_runtime::DbTtsSourceStore>,
    task: legado_engine::TaskHandle,
}
impl TtsOperation {
    fn capture(
        engine: &legado_engine::EngineContext,
        id: i64,
        cancellation: &legado_fetcher::tts_control::TtsCancellation,
    ) -> LegadoResult<Self> {
        let task = engine
            .tasks()
            .begin()
            .map_err(|e| legado_core::LegadoError::Ffi(e.to_string()))?;
        let config = super::http_tts_runtime::config_for_storage(engine.storage(), id)?;
        Ok(Self {
            config,
            cache_dir: engine.media().tts_directory(),
            network: engine.network().clone(),
            rates: engine.rate_limiter(),
            store: std::sync::Arc::new(
                super::http_tts_runtime::DbTtsSourceStore::for_engine(engine)
                    .with_task(task.clone(), Some(cancellation.clone())),
            ),
            task,
        })
    }
    fn speak(
        self,
        text: &str,
        tone_id: Option<String>,
        speaker_name: Option<String>,
        emotion_tag: Option<String>,
        cancellation: &legado_fetcher::tts_control::TtsCancellation,
    ) -> LegadoResult<TtsSpeakDto> {
        let _guard = self.task.guard();
        let context = TtsSpeakContext::new(
            text,
            self.config.effective_speed(),
            tone_id.as_deref(),
            speaker_name.as_deref(),
            emotion_tag.as_deref(),
        );
        let client = self.network.client()?;
        let result = crate::runtime::block_on(async {
            tokio::select! {
                biased;
                _ = self.task.cancelled() => Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())),
                result = legado_fetcher::tts_fetcher::fetch_tts_audio_controlled(&client, &self.config, &context, &self.cache_dir, None, legado_fetcher::tts_fetcher::TtsFetchResources {store: self.store, rates: self.rates}, cancellation) => result,
            }
        })?;
        cancellation.check()?;
        self.task
            .with_active(|| {
                Ok(TtsSpeakDto {
                    audio_path: result.audio_path.to_string_lossy().to_string(),
                    from_cache: result.from_cache,
                    content_type: result.content_type,
                })
            })
            .unwrap_or_else(|| Err(legado_core::LegadoError::Ffi("TTS_CANCELLED".into())))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn isolated_engine(url: &str) -> std::sync::Arc<legado_engine::EngineContext> {
        let engine = std::sync::Arc::new(legado_engine::EngineContext::in_memory().unwrap());
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
        use super::super::source_task_fixture::Fixture;
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
        let operation = TtsOperation::capture(&first, 12345, &cancellation).unwrap();
        first
            .media()
            .set_tts_directory(first.storage().data_directory("next-speech").unwrap());
        let first_audio = operation
            .speak("测试", None, None, None, &cancellation)
            .unwrap();
        let second_audio = TtsOperation::capture(&second, 12345, &cancellation)
            .unwrap()
            .speak("测试", None, None, None, &cancellation)
            .unwrap();
        assert_eq!(
            std::path::Path::new(&first_audio.audio_path)
                .parent()
                .unwrap(),
            before
        );
        assert_ne!(first_audio.audio_path, second_audio.audio_path);
        assert_eq!(
            std::fs::read(&first_audio.audio_path).unwrap(),
            b"ID3-audio"
        );
        assert!(!first_audio.from_cache && !second_audio.from_cache);
        let requests = crate::runtime::block_on(async {
            vec![fixture.request().await, fixture.request().await]
        });
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
        use super::super::source_task_fixture::Fixture;
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
        let operation = TtsOperation::capture(&engine, 12345, &cancellation).unwrap();
        fixture.release.send(()).unwrap();
        let worker =
            std::thread::spawn(move || operation.speak("测试", None, None, None, &cancellation));
        let speech = crate::runtime::block_on(fixture.request());
        assert!(speech.starts_with("GET /speech "));
        let script = crate::runtime::block_on(fixture.request());
        assert!(script.starts_with("GET /blocked "));
        drop(engine);
        assert!(weak.upgrade().is_none());
        let result = worker.join().unwrap();
        assert!(result.unwrap_err().to_string().contains("TTS_CANCELLED"));
        assert!(!crate::runtime::block_on(
            tasks.shutdown(Duration::from_millis(20))
        ));
        assert!(tasks.active_count() > 0);
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
        assert!(crate::runtime::block_on(
            tasks.shutdown(Duration::from_secs(5))
        ));
        assert!(std::fs::read_dir(&directory).unwrap().next().is_none());
        drop(storage);
    }

    /// 测试串行锁：以下测试会改写全局 TTS 缓存目录，并行执行会互相污染
    static TTS_DIR_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    #[test]
    fn test_set_tts_cache_dir_roundtrip() {
        let _guard = TTS_DIR_TEST_LOCK.lock().unwrap_or_else(|p| p.into_inner());
        let dir =
            std::env::temp_dir().join(format!("legado_tts_api_dir_test_{}", std::process::id()));
        let dir_str = dir.to_str().unwrap().to_string();
        assert!(set_tts_cache_dir(&dir_str).unwrap());
        assert_eq!(tts_cache_dir(), dir);
        assert!(dir.exists());

        // 恢复默认，避免污染其他并行测试
        let default_dir = std::env::temp_dir().join("legado_tts_cache");
        set_tts_cache_dir(default_dir.to_str().unwrap()).unwrap();
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn test_tts_speak_cache_hit_without_network() {
        let _guard = TTS_DIR_TEST_LOCK.lock().unwrap_or_else(|p| p.into_inner());
        let _db_guard = crate::db_state::ensure_test_db();
        // 独立缓存目录：预置缓存文件后调用 tts_speak，应命中缓存且不触网
        let dir =
            std::env::temp_dir().join(format!("legado_tts_api_hit_test_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        assert!(set_tts_cache_dir(dir.to_str().unwrap()).unwrap());

        let template = "https://tts.example.com/api?text={{speakText}}";
        let engine_id = crate::db_state::with_database(|db| {
            let repo = legado_db::HttpTtsRepository::new(db.connection());
            let entity = legado_db::HttpTts {
                id: -9999,
                name: "CacheHitEngine".into(),
                url: template.into(),
                speed: Some(0), // (0) + 5 = 5
                ..Default::default()
            };
            repo.insert_entity(&entity)
        })
        .unwrap();

        let config = crate::api::http_tts_runtime::config_for(engine_id).unwrap();
        let context = TtsSpeakContext::new("缓存命中测试", 5, None, None, None);
        let key = legado_fetcher::tts_cache_key_from_context(&config, &context);
        let cache_file = dir.join(format!("tts_{}.mp3", key));
        std::fs::write(&cache_file, b"FAKE_MP3").unwrap();

        let dto = tts_speak(engine_id, "缓存命中测试", None, None, None).unwrap();
        assert!(dto.from_cache);
        assert_eq!(dto.audio_path, cache_file.to_string_lossy().to_string());
        assert_eq!(dto.content_type, "audio/mpeg");

        // 恢复默认缓存目录，避免污染其他并行测试
        let default_dir = std::env::temp_dir().join("legado_tts_cache");
        set_tts_cache_dir(default_dir.to_str().unwrap()).unwrap();
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn test_tts_speak_engine_not_found() {
        let _guard = TTS_DIR_TEST_LOCK.lock().unwrap_or_else(|p| p.into_inner());
        let _db_guard = crate::db_state::ensure_test_db();
        let err = tts_speak(99999999, "测试文本", None, None, None).unwrap_err();
        assert!(
            err.to_string()
                .contains("未找到 ID 为 99999999 的 HTTP TTS 引擎配置")
        );
    }

    #[test]
    fn test_tts_speak_empty_text_error() {
        let _guard = TTS_DIR_TEST_LOCK.lock().unwrap_or_else(|p| p.into_inner());
        let _db_guard = crate::db_state::ensure_test_db();
        let engine_id = crate::db_state::with_database(|db| {
            let repo = legado_db::HttpTtsRepository::new(db.connection());
            let entity = legado_db::HttpTts {
                id: -9998,
                name: "EmptyTextEngine".into(),
                url: "https://tts.example.com/api".into(),
                ..Default::default()
            };
            repo.insert_entity(&entity)
        })
        .unwrap();

        let err = tts_speak(engine_id, "  ", None, None, None).unwrap_err();
        assert!(err.to_string().contains("朗读文本为空"));
    }
}
