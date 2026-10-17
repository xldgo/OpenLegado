//! 音频进度薄仓储与章节取址宿主适配。
use crate::db_state::with_database;
use legado_core::{LegadoResult, audio::with_audio_play_mode as core_with_audio_play_mode};
#[cfg(test)]
use legado_core::{
    cache_book::CachedChapter,
    models::{Book, BookChapter},
};
use legado_db::CacheRepository;
#[cfg(test)]
use legado_db::{
    BookChapterRepository, BookRepository, CacheBookRepository, repository::Repository,
};
pub use legado_engine::audio_book_service::AudioChapterMedia;
#[cfg(test)]
use legado_engine::audio_book_service::lyric_from_variable;
const AUDIO_PROGRESS_PREFIX: &str = "audio_progress:";
/// 获取音频播放进度（毫秒），无记录返回 0
pub fn get_audio_progress(book_url: &str, chapter_index: i32) -> LegadoResult<i64> {
    with_database(|db| {
        let repo = CacheRepository::new(db.connection());
        let key = format!("{}{}:{}", AUDIO_PROGRESS_PREFIX, book_url, chapter_index);
        match repo.get(&key)? {
            Some(val) => Ok(val.parse::<i64>().unwrap_or(0)),
            None => Ok(0),
        }
    })
}

/// 保存音频播放进度（毫秒）
pub fn save_audio_progress(
    book_url: &str,
    chapter_index: i32,
    position: i64,
) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = CacheRepository::new(db.connection());
        let key = format!("{}{}:{}", AUDIO_PROGRESS_PREFIX, book_url, chapter_index);
        repo.put(&key, &position.to_string(), 0)?; // 永不过期
        Ok(true)
    })
}

/// 将播放模式写入 readConfig JSON（对应 Kotlin `String?.withAudioPlayMode`）
///
/// 读取现有 readConfig JSON，设置 playMode 字段，返回更新后的 JSON 字符串。
/// `read_config` 为空或非法 JSON 时返回仅含 playMode 的新对象。
pub fn with_audio_play_mode(read_config: Option<&str>, play_mode: i32) -> String {
    core_with_audio_play_mode(read_config, play_mode)
}

pub fn get_audio_chapter_media(
    book_url: &str,
    chapter_index: i32,
) -> LegadoResult<AudioChapterMedia> {
    let engine = crate::engine_holder::current()?;
    let service = legado_engine::audio_book_service::AudioBookService {
        storage: engine.storage().clone(),
        factory: super::web_book::deps_for_engine(&engine),
        runtime: crate::runtime::get_runtime().handle().clone(),
        tasks: engine.tasks().clone(),
        rule_data_directory: super::video_api::rule_data_dir_override().unwrap_or_else(|| {
            engine
                .storage()
                .data_directory(super::video_api::RULE_DATA_DIR_NAME)
                .unwrap_or_else(|_| std::env::temp_dir().join("legado-rule-data"))
        }),
    };
    drop(engine);
    service.get_audio_chapter_media(book_url, chapter_index)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audio_progress() {
        let _db_guard = crate::db_state::ensure_test_db();

        let pos = get_audio_progress("http://book.com/audio", 0).unwrap();
        assert_eq!(pos, 0);

        assert!(save_audio_progress("http://book.com/audio", 0, 12345).unwrap());
        assert!(save_audio_progress("http://book.com/audio", 1, 67890).unwrap());

        assert_eq!(
            get_audio_progress("http://book.com/audio", 0).unwrap(),
            12345
        );
        assert_eq!(
            get_audio_progress("http://book.com/audio", 1).unwrap(),
            67890
        );

        assert!(save_audio_progress("http://book.com/audio", 0, 99999).unwrap());
        assert_eq!(
            get_audio_progress("http://book.com/audio", 0).unwrap(),
            99999
        );
    }

    #[test]
    fn test_get_audio_chapter_media_missing_chapter() {
        let _db_guard = crate::db_state::ensure_test_db();
        let err = get_audio_chapter_media("http://no-such-book", 0).unwrap_err();
        assert!(err.to_string().contains("不存在"));
    }

    #[test]
    fn test_get_audio_chapter_media_volume_short_circuit() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "http://test.audio/volume-book";

        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = Book {
                book_url: book_url.to_string(),
                name: "听书卷测".into(),
                origin: String::new(),
                ..Default::default()
            };
            book_repo.insert(&book)?;

            let ch_repo = BookChapterRepository::new(db.connection());
            let ch = BookChapter {
                book_url: book_url.to_string(),
                index: 0,
                title: "第一卷".into(),
                url: "volume://1".into(),
                is_volume: true,
                ..Default::default()
            };
            ch_repo.insert(&ch)?;
            Ok(())
        })
        .unwrap();

        let media = get_audio_chapter_media(book_url, 0).unwrap();
        assert!(media.is_volume);
        assert!(media.media_url.is_empty());
        assert_eq!(media.title, "第一卷");
    }

    #[test]
    fn test_get_audio_chapter_media_cache_hit() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "http://test.audio/cache-book";
        let chapter_url = "http://test.audio/ch/0";
        let play_url = "https://cdn.example.com/ep0.mp3";

        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = Book {
                book_url: book_url.to_string(),
                name: "听书缓存".into(),
                origin: "http://source.example/audio".into(),
                ..Default::default()
            };
            book_repo.insert(&book)?;

            let ch_repo = BookChapterRepository::new(db.connection());
            let ch = BookChapter {
                book_url: book_url.to_string(),
                index: 0,
                title: "第1集".into(),
                url: chapter_url.to_string(),
                variable: Some(r#"{"lyric":"歌词A"}"#.into()),
                ..Default::default()
            };
            ch_repo.insert(&ch)?;

            let cache_repo = CacheBookRepository::new(db.connection());
            cache_repo.insert(&CachedChapter {
                id: 0,
                book_url: book_url.to_string(),
                chapter_index: 0,
                chapter_title: "第1集".into(),
                chapter_url: chapter_url.to_string(),
                content: play_url.to_string(),
                cached_at: 1,
                size_bytes: play_url.len() as i64,
            })?;
            Ok(())
        })
        .unwrap();

        let media = get_audio_chapter_media(book_url, 0).unwrap();
        assert!(media.from_cache);
        assert_eq!(media.media_url, play_url);
        assert_eq!(media.lyric.as_deref(), Some("歌词A"));
        assert!(!media.is_volume);
    }

    #[test]
    fn test_get_audio_chapter_media_no_origin_falls_back_to_chapter_url() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "http://test.audio/local-fallback";
        let chapter_url = "https://cdn.example.com/direct.m4a";

        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = Book {
                book_url: book_url.to_string(),
                name: "无源听书".into(),
                origin: String::new(),
                ..Default::default()
            };
            book_repo.insert(&book)?;

            let ch_repo = BookChapterRepository::new(db.connection());
            let ch = BookChapter {
                book_url: book_url.to_string(),
                index: 0,
                title: "直链".into(),
                url: chapter_url.to_string(),
                ..Default::default()
            };
            ch_repo.insert(&ch)?;
            Ok(())
        })
        .unwrap();

        let media = get_audio_chapter_media(book_url, 0).unwrap();
        assert_eq!(media.media_url, chapter_url);
        assert!(!media.from_cache);
    }

    #[test]
    fn test_lyric_from_variable() {
        assert_eq!(
            lyric_from_variable(&Some(r#"{"lyric":"L1"}"#.into())).as_deref(),
            Some("L1")
        );
        assert!(lyric_from_variable(&None).is_none());
        assert!(lyric_from_variable(&Some("{}".into())).is_none());
    }

    /// 临时规则数据目录的线程内覆盖守卫，Drop 恢复原值。
    ///
    /// 目录仅作用于当前测试线程；数据库仍使用 `ensure_test_db` 串行锁，
    /// 锁序遵循 test_support 全局锁序不变式。
    struct LyricRuleDataDirGuard {
        dir: std::path::PathBuf,
        prev: Option<std::path::PathBuf>,
    }

    impl LyricRuleDataDirGuard {
        fn new() -> Self {
            let dir = std::env::temp_dir()
                .join(format!("legado_audio_lyric_test_{}", std::process::id()));
            let _ = std::fs::remove_dir_all(&dir);
            let prev = crate::api::video_api::replace_test_rule_data_dir(Some(dir.clone()));
            Self { dir, prev }
        }
    }

    impl Drop for LyricRuleDataDirGuard {
        fn drop(&mut self) {
            crate::api::video_api::replace_test_rule_data_dir(self.prev.take());
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }

    /// [P2-2] ≥10000 字符歌词落大数据文件后应能读回：
    /// `getAudioChapterMedia` 的 lyric 须补 File 回退
    /// （对齐原版 `RuleDataInterface.getVariable` = variableMap[key] ?:
    /// getBigVariable(key)，`AudioPlay.kt:408`）。
    #[test]
    fn test_get_audio_chapter_media_large_lyric_file_fallback() {
        let _db_guard = crate::db_state::ensure_test_db();
        let _rule_dir = LyricRuleDataDirGuard::new();
        let book_url = "http://test.audio/large-lyric-book";
        let chapter_url = "http://test.audio/ch/large-lyric";
        let big_lyric = "词".repeat(10000); // UTF-16 10000 → 写入侧走大文件分支

        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            book_repo.insert(&Book {
                book_url: book_url.to_string(),
                name: "长歌词听书".into(),
                origin: String::new(), // 无书源 → 取址走章 URL 回退，不触网
                ..Default::default()
            })?;
            let ch_repo = BookChapterRepository::new(db.connection());
            ch_repo.insert(&BookChapter {
                book_url: book_url.to_string(),
                index: 0,
                title: "第1集".into(),
                url: chapter_url.to_string(),
                ..Default::default()
            })?;
            Ok(())
        })
        .unwrap();

        // 经捕获落库（写侧与弹幕同链分流）：≥10000 → lyric 落大数据文件
        crate::api::video_api::put_media_sub_content(
            book_url,
            chapter_url,
            crate::api::video_api::LYRIC_KEY,
            &big_lyric,
        );
        let file = legado_db::rule_big_data::RuleBigDataManager::new(
            &crate::api::video_api::rule_data_dir(),
        )
        .chapter_variable_path(book_url, chapter_url, crate::api::video_api::LYRIC_KEY);
        assert!(file.is_file(), "长歌词应落大数据文件: {file:?}");

        let media = get_audio_chapter_media(book_url, 0).unwrap();
        assert_eq!(
            media.lyric.as_deref(),
            Some(big_lyric.as_str()),
            "variable 未命中时应回退大数据文件读回长歌词"
        );
    }
}
