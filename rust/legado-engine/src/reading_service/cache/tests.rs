//! 用真实SQLite复核服务捕获与清理范围，不依赖宿主全局数据库。
use super::*;
use crate::EngineContext;
use legado_core::{
    cache_book::CachedChapter,
    models::{Book, BookChapter},
};
use legado_db::{BookRepository, repository::Repository};

#[test]
fn clear_all_preserves_durable_state_and_rolls_back_on_flag_failure() {
    let engine = EngineContext::in_memory().unwrap();
    let storage = engine.storage();
    let service = ChapterCacheService::new(Some(storage.clone()));
    let keys = [
        "config:threadCount",
        "config:cacheBookThreadCount",
        "cacheDownloadTask:7",
        "cacheDownloadTaskIndex",
        "cacheDownloadNextId",
        "audio_progress:book:0",
        "loginHeader_source",
        "userInfo_source",
        "other",
    ];
    storage
        .with_database(|db| {
            let conn = db.connection();
            CacheBookRepository::new(conn).insert(&CachedChapter {
                id: 0,
                book_url: "book".into(),
                chapter_index: 0,
                chapter_title: "标题".into(),
                chapter_url: "chapter".into(),
                content: "正文".into(),
                cached_at: 1,
                size_bytes: 6,
            })?;
            let repo = CacheRepository::new(conn);
            for key in keys {
                repo.put(key, "保留值", 0)?;
            }
            repo.put("sameTitleRemoved:book:0", "1", 0)?;
            conn.execute_batch(
                "CREATE TRIGGER reject_flag BEFORE DELETE ON caches
            WHEN OLD.key GLOB 'sameTitleRemoved:*'
            BEGIN SELECT RAISE(ABORT,'拒绝清理标记'); END;",
            )
            .unwrap();
            Ok(())
        })
        .unwrap();
    assert!(service.clear_cache().is_err());
    storage
        .with_database(|db| {
            assert_eq!(
                CacheBookRepository::new(db.connection())
                    .get_stats()?
                    .total_chapters,
                1
            );
            db.connection()
                .execute_batch("DROP TRIGGER reject_flag")
                .unwrap();
            Ok(())
        })
        .unwrap();
    assert!(service.clear_cache().unwrap());
    assert!(service.clear_cache().unwrap());
    // 新服务从数据库重新读取，不能用原服务内存快照证明保留成功。
    let rebuilt = ChapterCacheService::new(Some(storage.clone()));
    assert_eq!(rebuilt.get_cache_size().unwrap(), 0);
    storage
        .with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            assert!(!repo.contains_key("sameTitleRemoved:book:0")?);
            for key in keys {
                assert_eq!(repo.get(key)?.as_deref(), Some("保留值"));
            }
            Ok(())
        })
        .unwrap();
}

#[test]
fn cleanup_keeps_statement_order_and_partial_failure() {
    for time_based in [false, true] {
        let engine = EngineContext::in_memory().unwrap();
        let storage = engine.storage();
        let service = ChapterCacheService::new(Some(storage.clone()));
        let cleanup = || {
            if time_based {
                service.clear_cache_before(10)
            } else {
                service.clear_book_cache("book").map(i64::from)
            }
        };
        storage
            .with_database(|db| {
                let conn = db.connection();
                for (index, time) in [(0, 9), (1, 10), (2, 11)] {
                    CacheBookRepository::new(conn).insert(&CachedChapter {
                        id: 0,
                        book_url: "book".into(),
                        chapter_index: index,
                        chapter_title: "标题".into(),
                        chapter_url: format!("chapter/{index}"),
                        content: "正文".into(),
                        cached_at: time,
                        size_bytes: 6,
                    })?;
                }
                CacheRepository::new(conn).put("sameTitleRemoved:book:0", "1", 0)?;
                conn.execute_batch(
                    "CREATE TRIGGER reject_chapter BEFORE DELETE ON cached_chapters
                BEGIN SELECT RAISE(ABORT,'chapter blocked'); END;",
                )
                .unwrap();
                Ok(())
            })
            .unwrap();
        assert!(
            cleanup()
                .unwrap_err()
                .to_string()
                .contains("chapter blocked")
        );
        storage
            .with_database(|db| {
                let conn = db.connection();
                assert_eq!(
                    CacheBookRepository::new(conn).get_stats()?.total_chapters,
                    3
                );
                assert!(CacheRepository::new(conn).contains_key("sameTitleRemoved:book:0")?);
                conn.execute_batch(
                    "DROP TRIGGER reject_chapter;
                CREATE TRIGGER reject_flag BEFORE DELETE ON caches
                BEGIN SELECT RAISE(ABORT,'flag blocked'); END;",
                )
                .unwrap();
                Ok(())
            })
            .unwrap();
        assert!(
            cleanup()
                .unwrap_err()
                .to_string()
                .contains("复位章级开关失败：flag blocked")
        );
        storage
            .with_database(|db| {
                let conn = db.connection();
                assert_eq!(
                    CacheBookRepository::new(conn).get_stats()?.total_chapters,
                    if time_based { 2 } else { 0 }
                );
                assert!(CacheRepository::new(conn).contains_key("sameTitleRemoved:book:0")?);
                conn.execute_batch("DROP TRIGGER reject_flag").unwrap();
                Ok(())
            })
            .unwrap();
        // 失败前删除的章节不回滚，后续无章节可删时仍保留原来的残留标记语义。
        assert_eq!(cleanup().unwrap(), 0);
        storage
            .with_database(|db| {
                assert_eq!(
                    CacheRepository::new(db.connection())
                        .contains_key("sameTitleRemoved:book:0")?,
                    time_based
                );
                Ok(())
            })
            .unwrap();
    }
}

#[test]
fn captured_cache_filters_stale_entries_and_cleans_only_its_storage() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a_storage = first.storage().clone();
    let b_storage = second.storage().clone();
    let a = ChapterCacheService::new(Some(a_storage.clone()));
    let b = ChapterCacheService::new(Some(b_storage.clone()));
    drop(first);
    drop(second);
    let book = "fixture://a%_";
    for (storage, text) in [(&a_storage, "甲"), (&b_storage, "乙")] {
        storage
            .with_database(|db| {
                let conn = db.connection();
                BookRepository::new(conn).insert(&Book {
                    book_url: book.into(),
                    name: text.into(),
                    ..Default::default()
                })?;
                BookChapterRepository::new(conn).insert(&BookChapter {
                    book_url: book.into(),
                    url: "current".into(),
                    title: "章名".into(),
                    index: 0,
                    word_count: Some("1字".into()),
                    ..Default::default()
                })?;
                CacheBookRepository::new(conn).insert(&CachedChapter {
                    id: 0,
                    book_url: book.into(),
                    chapter_index: 1,
                    chapter_title: "旧章".into(),
                    chapter_url: "stale".into(),
                    content: "旧正文".into(),
                    cached_at: 0,
                    size_bytes: 9,
                })?;
                let repo = CacheRepository::new(conn);
                repo.put(&format!("sameTitleRemoved:{book}:0"), "1", 0)?;
                repo.put("sameTitleRemoved:fixture://aXY:0", "1", 0)?;
                Ok(())
            })
            .unwrap();
    }
    assert!(a.save_chapter_content(book, 0, "", "甲正文", "").unwrap());
    assert!(b.save_chapter_content(book, 0, "", "乙正文", "").unwrap());
    assert_eq!(a.get_chapter_cache(book, 0).unwrap(), "甲正文");
    assert_eq!(b.get_chapter_cache(book, 0).unwrap(), "乙正文");
    assert!(a.get_chapter_cache(book, 1).unwrap().is_empty());
    assert_eq!(a.list_cached_chapter_urls(book).unwrap(), ["current"]);
    let entries = a.list_cached_chapters(book).unwrap();
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].url, "current");
    assert_eq!(entries[0].word_count, "1字");
    a_storage
        .with_database(|db| {
            db.connection()
                .execute("UPDATE cached_chapters SET cached_at=0", [])
                .unwrap();
            Ok(())
        })
        .unwrap();
    assert_eq!(a.clear_cache_before(1).unwrap(), 2);
    a_storage
        .with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            assert!(repo.get(&format!("sameTitleRemoved:{book}:0"))?.is_none());
            assert_eq!(
                repo.get("sameTitleRemoved:fixture://aXY:0")?.as_deref(),
                Some("1")
            );
            Ok(())
        })
        .unwrap();
    assert_eq!(b.get_chapter_cache(book, 0).unwrap(), "乙正文");
    b_storage
        .with_database(|db| {
            assert_eq!(
                CacheRepository::new(db.connection())
                    .get(&format!("sameTitleRemoved:{book}:0"))?
                    .as_deref(),
                Some("1")
            );
            Ok(())
        })
        .unwrap();
    let absent = ChapterCacheService::new(None);
    assert!(!absent.save_chapter_content(book, 0, "", " ", "").unwrap());
    assert!(absent.get_chapter_cache(book, 0).is_err());
    assert_eq!(absent.shrink_database(), 0);
}
