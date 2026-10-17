//! 用真实SQLite复核服务捕获与清理范围，不依赖宿主全局数据库。
use super::*;
use crate::EngineContext;
use legado_core::{
    cache_book::CachedChapter,
    models::{Book, BookChapter},
};
use legado_db::{BookRepository, repository::Repository};

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
