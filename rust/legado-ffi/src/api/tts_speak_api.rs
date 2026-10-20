//! HTTP TTS 语音合成管线 API（Task #113 批次 2 缺口② / T2a）
//!
//! 对照 Kotlin 原版 `HttpReadAloudService.getSpeakStream` 与 `AnalyzeUrl`：
//! 1. 以 `engine_id: i64` 为唯一主身份，查库获取完整 `HttpTts` 实体。
//! 2. 委托给 `legado_fetcher::fetch_tts_audio` 执行完整 TTS 请求管线（变量替换、内嵌 JS、@Header、@Body、POST/GET、MIME 校验与缓存落盘）。
//! 3. 保持返回值 `TtsSpeakDto`（camelCase 对齐 Dart 侧解析约定）。

use std::path::PathBuf;

use legado_core::LegadoResult;

pub use crate::media_dto::TtsSpeakDto;

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
    let service = crate::engine_holder::current()?.tts_service();
    let operation = service.prepare_http(engine_id, cancellation)?;
    let result = crate::runtime::block_on(operation.speak(
        text,
        tone_id,
        speaker_name,
        emotion_tag,
        cancellation,
    ))?;
    Ok(TtsSpeakDto {
        audio_path: result.audio_path.to_string_lossy().into_owned(),
        from_cache: result.from_cache,
        content_type: result.content_type,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_fetcher::TtsSpeakContext;

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
