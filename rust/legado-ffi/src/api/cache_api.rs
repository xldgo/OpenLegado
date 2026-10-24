//! 章节缓存FFI适配：捕获存储并委托阅读服务，不维护第二套有效性和清理规则。
#[cfg(test)]
use crate::db_state::with_database;
#[cfg(test)]
use legado_core::LegadoError;
use legado_core::LegadoResult;
#[cfg(test)]
use legado_core::cache_book::CachedChapter;
#[cfg(test)]
use legado_db::{BookChapterRepository, CacheBookRepository, CacheRepository};
pub use legado_engine::reading_service::CachedChapterEntry;
use legado_engine::reading_service::ChapterCacheService;

fn service() -> ChapterCacheService {
    let engine = crate::engine_holder::current().ok();
    let media = engine
        .as_ref()
        .map(|engine| engine.media().clone())
        .unwrap_or_else(crate::engine_holder::media);
    ChapterCacheService::new(engine.map(|engine| engine.storage().clone())).with_image_cache(
        legado_engine::image_cache_service::ImageCacheService::new(
            super::image_cache_api::cache_root_for(&media),
        ),
    )
}

pub fn get_cache_size() -> LegadoResult<i64> {
    service().get_cache_size()
}

pub fn clear_cache() -> LegadoResult<bool> {
    service().clear_cache()
}

pub fn clear_book_cache(book_url: &str) -> LegadoResult<i32> {
    service().clear_book_cache(book_url)
}

pub fn clear_chapter_cache(book_url: &str, chapter_index: i32) -> LegadoResult<i32> {
    service().clear_chapter_cache(book_url, chapter_index)
}

pub fn get_chapter_cache(book_url: &str, chapter_index: i32) -> LegadoResult<String> {
    service().get_chapter_cache(book_url, chapter_index)
}

pub fn list_cached_chapter_urls(book_url: &str) -> LegadoResult<Vec<String>> {
    service().list_cached_chapter_urls(book_url)
}

pub fn list_cached_chapters(book_url: &str) -> LegadoResult<Vec<CachedChapterEntry>> {
    service().list_cached_chapters(book_url)
}

pub fn get_cache_book_count() -> LegadoResult<i32> {
    service().get_cache_book_count()
}

pub fn get_cache_chapter_count() -> LegadoResult<i32> {
    service().get_cache_chapter_count()
}

pub fn save_chapter_content(
    book_url: &str,
    chapter_index: i32,
    title: &str,
    content: &str,
    chapter_url: &str,
) -> LegadoResult<bool> {
    service().save_chapter_content(book_url, chapter_index, title, content, chapter_url)
}

pub fn shrink_database() -> i64 {
    service().shrink_database()
}

pub fn clear_cache_before(before_timestamp: i64) -> LegadoResult<i64> {
    service().clear_cache_before(before_timestamp)
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::models::{Book, BookChapter};
    use legado_db::repository::Repository;
    use legado_db::repository::book_repository::BookRepository;

    #[test]
    fn test_cache_apis() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 先清空缓存确保测试隔离
        clear_cache().unwrap();

        // 清空后缓存大小为 0
        let size = get_cache_size().unwrap();
        assert_eq!(size, 0);

        // 无缓存时返回空
        let content = get_chapter_cache("http://book.com/1", 0).unwrap();
        assert!(content.is_empty());

        // 清空缓存不报错
        assert!(clear_cache().unwrap());
    }

    /// STAGE3-C2B：单章失效只删 (book_url, chapter_index) 行——
    /// 同书他章保留、`sameTitleRemoved` 章级开关键不动、行不存在 no-op
    #[test]
    fn test_clear_chapter_cache_single_row() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cache().unwrap();

        let book_url = "http://clear-chapter.example.com/book1";

        // 两章缓存 + 一章级「不删重复标题」开关键
        assert!(
            save_chapter_content(
                book_url,
                0,
                "第一章",
                "第一章正文",
                "http://clear-chapter.example.com/ch1"
            )
            .unwrap()
        );
        assert!(
            save_chapter_content(
                book_url,
                1,
                "第二章",
                "第二章正文",
                "http://clear-chapter.example.com/ch2"
            )
            .unwrap()
        );
        with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            repo.put(&format!("sameTitleRemoved:{book_url}:0"), "1", 0)?;
            Ok(())
        })
        .unwrap();

        // 仅失效第 0 章
        let deleted = clear_chapter_cache(book_url, 0).unwrap();
        assert_eq!(deleted, 1, "应仅删除 1 行");

        // 第 0 章已删、第 1 章保留（无整书清理）
        assert!(
            get_chapter_cache(book_url, 0).unwrap().is_empty(),
            "被失效章缓存应已删除"
        );
        assert_eq!(get_chapter_cache(book_url, 1).unwrap(), "第二章正文");

        // 章级开关键不受影响（区别于 clear_book_cache 的整书复位语义）
        with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            assert!(
                repo.contains_key(&format!("sameTitleRemoved:{book_url}:0"))?,
                "章级开关键不得被单章失效触碰"
            );
            Ok(())
        })
        .unwrap();

        // 行不存在为 no-op：重复删除 / 未缓存索引均返回 0 且不报错
        assert_eq!(clear_chapter_cache(book_url, 0).unwrap(), 0);
        assert_eq!(clear_chapter_cache(book_url, 99).unwrap(), 0);

        // 清理测试数据
        clear_cache().unwrap();
    }

    /// STAGE3-C2B：空 bookUrl 为参数错误（不上抛至 DB 层）
    #[test]
    fn test_clear_chapter_cache_empty_book_url() {
        let _db_guard = crate::db_state::ensure_test_db();

        let err = clear_chapter_cache("", 0).unwrap_err();
        assert!(
            err.to_string().contains("bookUrl 不能为空"),
            "空 bookUrl 应报参数错误，实际: {err}"
        );
        assert!(
            matches!(err, LegadoError::Internal(_)),
            "空 bookUrl 应为 Internal（参数）错误"
        );
    }

    /// Task #136 R5：写入→cache_get 读回一致
    #[test]
    fn test_save_chapter_content_roundtrip() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cache().unwrap();

        let book_url = "http://save-chapter.example.com/book1";
        let chapter_url = "http://save-chapter.example.com/ch3";
        let content = "第三章正文：缓存写侧闭环测试。";

        // 写入（显式 title/chapter_url）
        assert!(save_chapter_content(book_url, 3, "第三章", content, chapter_url).unwrap());

        // 读回一致
        let read_back = get_chapter_cache(book_url, 3).unwrap();
        assert_eq!(read_back, content, "写入后读回应一致");

        // 覆盖写入（INSERT OR REPLACE）
        let edited = "第三章正文（用户编辑后）";
        assert!(save_chapter_content(book_url, 3, "第三章", edited, chapter_url).unwrap());
        assert_eq!(get_chapter_cache(book_url, 3).unwrap(), edited);

        // 清理测试数据
        clear_cache().unwrap();
    }

    /// Task #51：VACUUM 压缩释放可回收空间；Task #55 F7 断言加强：
    /// 构造已知垃圾数据后首次压缩必须释放 > 0 字节，且首次释放量
    /// 大于第二次（第二次通常释放 0）
    #[test]
    fn test_shrink_database() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 制造可回收空间：写入再删除一大批缓存（量级足够大，确保
        // 删除后留下可被 VACUUM 回收的整页，共享库下仍稳定 freed > 0）
        for i in 0..100 {
            save_chapter_content(
                "http://shrink-test.example.com/book",
                i,
                &format!("第{i}章"),
                &"冗余正文数据填充".repeat(2000),
                &format!("http://shrink-test.example.com/ch/{i}"),
            )
            .unwrap();
        }
        clear_cache().unwrap();

        // 首次 VACUUM：构造的垃圾数据刚被删除，必然回收空间
        let freed = shrink_database();
        assert!(freed > 0, "首次压缩应释放正字节数，实际 {freed}");

        // 重复执行不报错（幂等语义：无新增垃圾时释放量应小于首次）
        let freed_again = shrink_database();
        assert!(freed_again >= 0);
        assert!(
            freed_again < freed,
            "第二次压缩释放量应小于首次（首次 {freed}，二次 {freed_again}）"
        );
    }

    /// Task #55 F5：clear_cache_before 清理过期章节的同时，复位被清理
    /// 书籍的章级「删除重复标题」开关键；未过期/他书的键不受影响
    #[test]
    fn test_clear_cache_before_resets_same_title_flags() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cache().unwrap();

        let old_book = "http://clear-before.example.com/book/old";
        let fresh_book = "http://clear-before.example.com/book/fresh";

        // 两本书各写一章缓存
        assert!(
            save_chapter_content(
                old_book,
                0,
                "旧章",
                "旧正文",
                "http://clear-before.example.com/ch/old0"
            )
            .unwrap()
        );
        assert!(
            save_chapter_content(
                fresh_book,
                0,
                "新章",
                "新正文",
                "http://clear-before.example.com/ch/fresh0"
            )
            .unwrap()
        );

        // 将 old_book 的 cached_at 改为远古时间，fresh_book 保持当前时间
        with_database(|db| {
            use rusqlite::params;
            db.connection()
                .execute(
                    "UPDATE cached_chapters SET cached_at = 1 WHERE book_url = ?1",
                    params![old_book],
                )
                .map_err(|e| LegadoError::Database(format!("构造测试数据失败: {e}")))?;
            Ok(())
        })
        .unwrap();

        // 两本书各写一个章级开关键（格式与 reader.rs same_title_removed_key 一致）
        with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            repo.put(&format!("sameTitleRemoved:{old_book}:0"), "1", 0)?;
            repo.put(&format!("sameTitleRemoved:{fresh_book}:0"), "1", 0)?;
            Ok(())
        })
        .unwrap();

        // 以中间时刻为界清理（old_book cached_at=1 命中，fresh_book
        // cached_at=当前时间不命中）
        let cutoff = 1_000_000_000_000i64; // 2001-09-09，介于远古与当前之间
        let deleted = clear_cache_before(cutoff).unwrap();
        assert_eq!(deleted, 1, "应仅删除 old_book 的过期章节");

        // old_book 的章级开关被复位（键已删），fresh_book 的不受影响
        with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            assert!(
                !repo.contains_key(&format!("sameTitleRemoved:{old_book}:0"))?,
                "被清理书籍的章级开关键应被删除"
            );
            assert!(
                repo.contains_key(&format!("sameTitleRemoved:{fresh_book}:0"))?,
                "未清理书籍的章级开关键应保留"
            );
            Ok(())
        })
        .unwrap();

        // 清理测试数据
        clear_cache().unwrap();
    }

    /// [P2-28c] list_cached_chapters：集合正确（chapter_index 升序、[B-5]
    /// 过滤陈旧缓存行）+ wordCount 取 `chapters` 表当前值（未回填 → 空串）。
    /// 直写缓存行（绕过 save_chapter_content 的回填链），避免回填改写 ch0
    /// 现值，证明 wordCount 读自 chapters 表而非缓存正文重算；纯 SELECT
    /// （查询前后 chapters 表内容不变）。
    #[test]
    fn test_list_cached_chapters_set_and_word_count() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://wc-poll.example.com/book/1";
        let ch0 = "https://wc-poll.example.com/ch/0";
        let ch3 = "https://wc-poll.example.com/ch/3";
        let ch9 = "https://wc-poll.example.com/ch/9";

        with_database(|db| {
            let conn = db.connection();
            BookRepository::new(conn).insert(&Book {
                book_url: book_url.to_string(),
                origin: "https://wc-poll-src.example.com".to_string(),
                ..Book::default()
            })?;
            // 目录行：ch0 已回填字数（当前值），ch3 未回填（NULL）
            BookChapterRepository::new(conn).insert(&BookChapter {
                url: ch0.to_string(),
                title: "第一章".to_string(),
                book_url: book_url.to_string(),
                index: 0,
                word_count: Some("1200字".to_string()),
                ..BookChapter::default()
            })?;
            BookChapterRepository::new(conn).insert(&BookChapter {
                url: ch3.to_string(),
                title: "第四章".to_string(),
                book_url: book_url.to_string(),
                index: 3,
                ..BookChapter::default()
            })?;
            // 直写缓存行（绕过 save_chapter_content 的回填链）
            for (index, url, content) in [(0i32, ch0, "第一章正文"), (3, ch3, "第四章正文")]
            {
                CacheBookRepository::new(conn).insert(&CachedChapter {
                    id: 0,
                    book_url: book_url.to_string(),
                    chapter_index: index,
                    chapter_title: format!("第{}章", index + 1),
                    chapter_url: url.to_string(),
                    content: content.to_string(),
                    cached_at: 0,
                    size_bytes: content.len() as i64,
                })?;
            }
            // 陈旧缓存行：ch9 不在当前目录（模拟上一代目录残留，[B-5]）
            CacheBookRepository::new(conn).insert(&CachedChapter {
                id: 0,
                book_url: book_url.to_string(),
                chapter_index: 9,
                chapter_title: "第十章".to_string(),
                chapter_url: ch9.to_string(),
                content: "陈旧缓存正文".to_string(),
                cached_at: 0,
                size_bytes: 8,
            })?;
            Ok(())
        })
        .expect("前置数据写入失败");

        let entries = list_cached_chapters(book_url).expect("查询应成功");
        assert_eq!(
            entries
                .iter()
                .map(|e| (e.url.as_str(), e.word_count.as_str()))
                .collect::<Vec<_>>(),
            vec![(ch0, "1200字"), (ch3, "")],
            "chapter_index 升序、过滤陈旧缓存行（[B-5]）、wordCount 取 chapters 表当前值（未回填 → 空串）"
        );

        // 清理测试数据（章节行事务外删除为 B-7 no-op，测试库隔离无害）
        with_database(|db| {
            CacheBookRepository::new(db.connection()).delete_by_book(book_url)?;
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            BookRepository::new(db.connection()).delete_by_url(book_url)?;
            Ok(())
        })
        .ok();
    }

    /// [P2-28c] 空书 → 空集合；无目录书（纯缓存场景）→ 缓存行全量返回
    /// 且 wordCount 为空串（无目录可取，保持 §2.43.5 原有行为）
    #[test]
    fn test_list_cached_chapters_empty_book_and_no_toc() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 完全未缓存的书 → 空集合
        assert!(
            list_cached_chapters("https://wc-none.example.com/absent")
                .expect("查询应成功")
                .is_empty(),
            "无缓存行的书应返回空集合"
        );

        // 无目录记录的书（纯缓存场景）：缓存行全量返回、wordCount 空串
        let book_url = "https://wc-notoc.example.com/book/9";
        let ch_url = "https://wc-notoc.example.com/ch/0";
        with_database(|db| {
            CacheBookRepository::new(db.connection()).insert(&CachedChapter {
                id: 0,
                book_url: book_url.to_string(),
                chapter_index: 0,
                chapter_title: "第一章".to_string(),
                chapter_url: ch_url.to_string(),
                content: "纯缓存章正文".to_string(),
                cached_at: 0,
                size_bytes: 8,
            })?;
            Ok(())
        })
        .expect("前置数据写入失败");

        let entries = list_cached_chapters(book_url).expect("查询应成功");
        assert_eq!(entries.len(), 1, "无目录书应保持原有行为（全量返回缓存行）");
        assert_eq!(entries[0].url, ch_url);
        assert_eq!(entries[0].word_count, "", "无目录可取 wordCount → 空串");

        // 清理测试数据
        with_database(|db| {
            CacheBookRepository::new(db.connection()).delete_by_book(book_url)?;
            Ok(())
        })
        .ok();
    }
}
