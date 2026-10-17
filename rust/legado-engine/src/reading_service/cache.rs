//! 章节缓存有效性、清理与维护规则；仅依赖所属存储能力。
use super::save_chapter_content_with_storage;
use crate::StorageContext;
use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookChapterRepository, CacheBookRepository, CacheRepository};

/// 已缓存章节的 (chapter_url, wordCount) 单条目（P2-28c，API_CONTRACT §2.43.6）
///
/// 内部条目由宿主映射到原CachedChapterDto，字段与原序列化语义保持一致。
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CachedChapterEntry {
    /// 缓存章节 URL（cached_chapters.chapter_url）
    pub url: String,
    /// 章节字数（`chapters` 表当前值；P2-28b 回填链已按原版 wordCountFormat
    /// 格式化为「1200字」/「1.1万字」形态，未回填为空串）
    pub word_count: String,
}

/// 捕获一次存储快照，整个操作不回查宿主全局实例。
pub struct ChapterCacheService {
    storage: Option<StorageContext>,
}
impl ChapterCacheService {
    pub fn new(storage: Option<StorageContext>) -> Self {
        Self { storage }
    }
    fn with_database<T>(
        &self,
        operation: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(operation)
    }
    /// 获取缓存总大小（字节）
    pub fn get_cache_size(&self) -> LegadoResult<i64> {
        self.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            let stats = repo.get_stats()?;
            Ok(stats.total_size_bytes)
        })
    }

    /// 清空所有章节缓存
    pub fn clear_cache(&self) -> LegadoResult<bool> {
        self.with_database(|db| {
            let conn = db.connection();
            // 清空 cached_chapters 表
            conn.execute("DELETE FROM cached_chapters", [])
                .map_err(|e| legado_core::LegadoError::Database(format!("清空缓存失败: {e}")))?;
            // 同时清空通用 KV 缓存
            let cache_repo = CacheRepository::new(conn);
            cache_repo.clear()?;
            Ok(true)
        })
    }

    /// 清除指定书籍的章节缓存（对齐原版 BookHelp.clearCache(book) 的 DB 侧语义）
    ///
    /// [B-10] 清缓存 = 复位该书的阅读偏好：除 cached_chapters 外，同时删除
    /// caches 表 `sameTitleRemoved:{book_url}:%` 章级「不删重复标题」开关键
    /// （写入侧 reader::toggle_same_title_removed，消费侧读取时跳过同标题去重；
    /// 不清则清缓存后章节仍按旧开关渲染，用户预期「重置」落空）。LIKE 模式
    /// 由缓存仓储转义 book_url，防止通配符跨书误删（同 clear_cache_before）。
    pub fn clear_book_cache(&self, book_url: &str) -> LegadoResult<i32> {
        self.with_database(|db| {
            let conn = db.connection();
            let repo = CacheBookRepository::new(conn);
            let deleted = repo.delete_by_book(book_url)?;
            // 复位该书的章级「删除重复标题」开关（caches 表键前缀匹配）
            CacheRepository::new(conn).delete_same_title_removed(book_url)?;
            Ok(deleted as i32)
        })
    }

    /// 清除指定书籍**单章**的章节缓存（STAGE3-C2B，API_CONTRACT §2.16）
    ///
    /// 对齐上游原版 `BookHelp.delContent` 章级语义：仅删除该书指定索引的
    /// 缓存行（book_url + chapter_index 定位），同书其他章节缓存不受影响；
    /// **不触碰** `sameTitleRemoved` 等章级开关键——开关键复位是整书清理
    /// （[`clear_book_cache`] / [`clear_cache_before`]）的语义，章级失效不适用。
    /// 行不存在为 no-op 成功（返回 0）；空 bookUrl 返回参数错误。
    ///
    /// 供阅读器「刷新正文」先失效当前章再强制联网重取（对齐上游
    /// `ReadBookViewModel.refreshContentDur` = delContent → loadContent）。
    pub fn clear_chapter_cache(&self, book_url: &str, chapter_index: i32) -> LegadoResult<i32> {
        if book_url.trim().is_empty() {
            return Err(LegadoError::Internal("bookUrl 不能为空".into()));
        }
        self.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            let deleted = repo.delete_by_book_and_index(book_url, chapter_index)?;
            Ok(deleted as i32)
        })
    }

    /// 获取指定章节的缓存内容（无缓存返回空字符串）
    ///
    /// [B-1] 空正文缓存行按 miss 返回空（对齐上游 BookHelp.kt:271/:557-559）。
    /// [B-5] 读侧 URL 校验：书籍有目录（chapters 表非空）时，缓存行的
    /// `chapter_url` 必须等于当前目录该索引章节的 URL，否则是上一代目录的
    /// 失效缓存行（换目录未清理），按 miss 返回空，避免张冠李戴；
    /// 无目录记录的书籍（纯缓存场景）保持原有行为。
    pub fn get_chapter_cache(&self, book_url: &str, chapter_index: i32) -> LegadoResult<String> {
        self.with_database(|db| {
            let conn = db.connection();
            let repo = CacheBookRepository::new(conn);
            let chapters = repo.get_by_book(book_url)?;
            let cached = chapters
                .into_iter()
                .find(|c| c.chapter_index == chapter_index);
            let Some(cached) = cached else {
                return Ok(String::new());
            };
            // [B-1] 空内容行不是有效缓存（历史遗留空行按命中返回会使章节永久空白）
            if cached.content.trim().is_empty() {
                return Ok(String::new());
            }
            let ch_repo = BookChapterRepository::new(conn);
            let toc = ch_repo.find_by_book_url(book_url)?;
            if toc.is_empty() {
                // 无目录记录：无「当前代」可言，保持既有读行为
                return Ok(cached.content);
            }
            // [B-5] 当前目录该索引的章节 URL 与缓存行 URL 不一致（或章节已不在
            // 目录中）→ 失效缓存，返回 miss
            match toc.iter().find(|c| c.index == chapter_index) {
                Some(ch) if ch.url == cached.chapter_url => Ok(cached.content),
                _ => Ok(String::new()),
            }
        })
    }

    /// 列出某本书已缓存章节的 chapter_url 集合（Task #22，目录页云图标缓存态）
    ///
    /// 复用 [`CacheBookRepository::get_by_book`]（按 book_url 复合键查询，不串本），
    /// 仅提取 chapter_url 供 Flutter 目录页据此为每章标记「已缓存/未缓存」渲染
    /// 云图标；返回顺序按 chapter_index 升序（仓储已排序），空 chapter_url 过滤。
    pub fn list_cached_chapter_urls(&self, book_url: &str) -> LegadoResult<Vec<String>> {
        self.with_database(|db| {
            let conn = db.connection();
            let repo = CacheBookRepository::new(conn);
            let chapters = repo.get_by_book(book_url)?;
            let urls: Vec<String> = chapters
                .into_iter()
                .map(|c| c.chapter_url)
                .filter(|u| !u.trim().is_empty())
                .collect();
            // [B-5] 读侧 URL 校验（云图标对齐）：书籍有目录时，仅当前目录仍
            // 存在的章节 URL 才算「已缓存」——上一代目录的失效缓存行不应点亮
            // 新目录章节的云图标；无目录记录的书籍保持原有行为
            let toc = BookChapterRepository::new(conn).find_by_book_url(book_url)?;
            if toc.is_empty() {
                return Ok(urls);
            }
            let current: std::collections::HashSet<String> =
                toc.iter().map(|c| c.url.clone()).collect();
            Ok(urls.into_iter().filter(|u| current.contains(u)).collect())
        })
    }

    /// 列出某本书已缓存章节的 (chapter_url, wordCount) 集合
    /// （P2-28c，API_CONTRACT §2.43.6，目录页实时字数刷新数据链）
    ///
    /// [`list_cached_chapter_urls`] 的升级形态：单次只读查询（纯 SELECT，
    /// 复用 [`CacheBookRepository::get_by_book`] +
    /// [`BookChapterRepository::find_by_book_url`]，零额外 SQL）同时给出 URL
    /// 集合与字数映射，供 Flutter 目录页 1 秒轮询（P2-28b）一次调用同时完成
    /// ⬇ 图标翻转与字数胶囊同帧刷新。
    ///
    /// 过滤语义与 [`list_cached_chapter_urls`] 一致：按 chapter_index 升序
    /// （仓储已排序）、空 `chapter_url` 过滤；书籍有目录时同步过滤已退出
    /// 当前目录的陈旧缓存行（[B-5] 同源）。`word_count` 取 `chapters` 表
    /// 当前值（与 P2-28b 回填链同源，避免 `cached_chapters` 表内旧快照），
    /// 未回填（NULL/空）为空串。
    pub fn list_cached_chapters(&self, book_url: &str) -> LegadoResult<Vec<CachedChapterEntry>> {
        self.with_database(|db| {
            let conn = db.connection();
            let cached = CacheBookRepository::new(conn).get_by_book(book_url)?;
            let toc = BookChapterRepository::new(conn).find_by_book_url(book_url)?;
            // url -> wordCount（chapters 表当前值；None/空 → 空串）
            let word_counts: std::collections::HashMap<String, String> = toc
                .iter()
                .filter(|c| !c.url.trim().is_empty())
                .map(|c| (c.url.clone(), c.word_count.clone().unwrap_or_default()))
                .collect();
            // [B-5] 与 §2.43.5 同源：有目录时仅保留仍在当前目录中的缓存行
            let current: Option<std::collections::HashSet<String>> = if toc.is_empty() {
                None
            } else {
                Some(toc.iter().map(|c| c.url.clone()).collect())
            };
            Ok(cached
                .into_iter()
                .filter(|c| !c.chapter_url.trim().is_empty())
                .filter(|c| match &current {
                    Some(set) => set.contains(&c.chapter_url),
                    None => true,
                })
                .map(|c| CachedChapterEntry {
                    word_count: word_counts.get(&c.chapter_url).cloned().unwrap_or_default(),
                    url: c.chapter_url,
                })
                .collect())
        })
    }

    /// 获取缓存书籍数量
    pub fn get_cache_book_count(&self) -> LegadoResult<i32> {
        self.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            let stats = repo.get_stats()?;
            Ok(stats.books_cached)
        })
    }

    /// 获取缓存章节数量
    pub fn get_cache_chapter_count(&self) -> LegadoResult<i32> {
        self.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            let stats = repo.get_stats()?;
            Ok(stats.total_chapters)
        })
    }

    /// 写入/覆盖单章缓存（Task #136 R5，API_CONTRACT §2.43.1）
    ///
    /// 复用 [`CacheBookRepository::insert`]（INSERT OR REPLACE），供阅读器
    /// 「编辑内容/反转」闭环回写章节缓存；正文按原文存储（不做净化，
    /// 与正文抓取链路缓存写入一致，读取时再净化）。
    ///
    /// `title` / `chapter_url` 为空串时从 DB 章节表回填（章节也不存在则报错）。
    pub fn save_chapter_content(
        &self,
        book_url: &str,
        chapter_index: i32,
        title: &str,
        content: &str,
        chapter_url: &str,
    ) -> LegadoResult<bool> {
        if content.trim().is_empty() {
            return Ok(false);
        }
        let storage = self
            .storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?;
        save_chapter_content_with_storage(
            storage,
            book_url,
            chapter_index,
            title,
            content,
            chapter_url,
        )
    }

    /// 执行 SQLite VACUUM 压缩数据库，返回释放的字节数（Task #51，API_CONTRACT §2.16.6）
    ///
    /// 通过 VACUUM 前后 `PRAGMA page_count * page_size` 对比计算释放量；
    /// VACUUM 失败（数据库锁/文件损坏）或数据库未初始化时一律降级返回 0，
    /// 不抛异常阻断业务（契约错误语义）。宿主负责线程调度，本服务不创建运行时。
    pub fn shrink_database(&self) -> i64 {
        self.shrink_database_inner().unwrap_or(0)
    }

    /// VACUUM 内部实现（错误由上层降级为 0）
    fn shrink_database_inner(&self) -> LegadoResult<i64> {
        self.with_database(|db| {
            let conn = db.connection();
            let before = db_logical_size_bytes(conn)?;
            conn.execute("VACUUM", [])
                .map_err(|e| LegadoError::Database(format!("VACUUM 失败: {e}")))?;
            let after = db_logical_size_bytes(conn)?;
            Ok(before.saturating_sub(after))
        })
    }

    /// 清除指定时间之前的缓存，返回删除的行数
    ///
    /// 语义对齐原版（Task #55 F5）：原版时段清理会删除对应章节的 .nr
    /// 缓存标记文件（即复位「不删重复标题」章级标记）；本实现等价地在清理
    /// cached_chapters 的同时，删除【被清理书籍】在 caches 表的
    /// `sameTitleRemoved:{bookUrl}:*` 章级开关键；未被清理的书籍不受影响。
    pub fn clear_cache_before(&self, before_timestamp: i64) -> LegadoResult<i64> {
        self.with_database(|db| {
            let conn = db.connection();
            let repo = CacheBookRepository::new(conn);
            // 保留查询、章节删除、逐书复位的顺序，不新增统一事务。
            let book_urls = repo.books_cached_before(before_timestamp)?;
            let deleted = repo.delete_expired(before_timestamp)?;
            let flags = CacheRepository::new(conn);
            for book_url in book_urls {
                flags.delete_same_title_removed(&book_url)?;
            }
            Ok(deleted as i64)
        })
    }
}

/// 数据库逻辑大小（字节）：`page_count * page_size`
fn db_logical_size_bytes(conn: &rusqlite::Connection) -> LegadoResult<i64> {
    let page_count: i64 = conn
        .query_row("PRAGMA page_count", [], |row| row.get(0))
        .map_err(|e| LegadoError::Database(format!("查询 page_count 失败: {e}")))?;
    let page_size: i64 = conn
        .query_row("PRAGMA page_size", [], |row| row.get(0))
        .map_err(|e| LegadoError::Database(format!("查询 page_size 失败: {e}")))?;
    Ok(page_count.saturating_mul(page_size))
}

#[cfg(test)]
mod tests;
