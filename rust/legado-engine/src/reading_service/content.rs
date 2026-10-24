//! 固定存储/抓取能力的原文读取层；正文提交和媒体副内容共用任务门控。
use crate::{StorageContext, TaskHandle};
use legado_core::cache_book::CachedChapter;
use legado_core::web_book::WebChapter;
use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository};
use std::sync::Arc;

#[derive(Clone)]
pub struct ChapterContent {
    pub storage: StorageContext,
    deps: super::ReadingFetcherFactory,
    runtime: tokio::runtime::Handle,
}
pub struct ChapterRequest<'a> {
    pub book_url: &'a str,
    pub chapter_url: &'a str,
    pub source_url: &'a str,
    pub chapter_index: i32,
    pub chapter_title: &'a str,
    pub chapter_variable: Option<&'a str>,
    pub known_chapter: bool,
}
pub struct RawChapter {
    pub content: String,
    pub title: String,
}

fn cancelled() -> LegadoError {
    LegadoError::Ffi("章节任务已取消".into())
}
fn publish<T>(task: Option<&TaskHandle>, write: impl FnOnce() -> T) -> LegadoResult<T> {
    match task {
        Some(task) => task.with_active(write).ok_or_else(cancelled),
        None => Ok(write()),
    }
}
impl ChapterContent {
    pub fn new(
        storage: StorageContext,
        deps: super::ReadingFetcherFactory,
        runtime: tokio::runtime::Handle,
    ) -> Self {
        Self {
            storage,
            deps,
            runtime,
        }
    }
    pub fn read(
        &self,
        request: ChapterRequest<'_>,
        task: Option<&TaskHandle>,
    ) -> LegadoResult<RawChapter> {
        if task.is_some_and(TaskHandle::is_cancelled) {
            return Err(cancelled());
        }
        let ChapterRequest {
            book_url,
            chapter_url,
            source_url,
            chapter_index,
            chapter_title,
            chapter_variable,
            known_chapter,
        } = request;
        // 1. 检查 DB 缓存
        // Task #16 P0：按 (book_url, chapter_url) 复合键查找，避免不同书籍共用
        // 相同 chapter_url 时命中他书缓存（正文张冠李戴）。
        let cached = self.storage.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.get_by_book_and_chapter_url(book_url, chapter_url)
        })?;

        // [B-1] 空正文缓存行按 miss 处理（对齐上游 BookHelp.kt:271「内容为空
        // 直接返回」/ :557-559「空内容不入缓存」）：历史遗留的空行若按命中
        // 返回，该章节将永久空白、永不重抓
        let cached = cached.filter(|c| !c.content.trim().is_empty());

        if let Some(cached_chapter) = cached {
            // [P2-28b] 存量惰性自愈：缓存命中但该章 wordCount 为空（旧版本
            // 写入的缓存，早于回填链引入）时，按缓存正文长度补算回填**一次**
            // （回填成功后 wordCount 非空，后续命中不再写）。失败仅告警，
            // 不影响正文返回（对齐原版 writeText 的 best-effort 语义）
            let wc_missing = self
                .storage
                .with_database(|db| {
                    BookChapterRepository::new(db.connection())
                        .word_count_missing(book_url, chapter_url)
                })
                .unwrap_or(false);
            if wc_missing
                && let Err(e) = publish(task, || {
                    backfill_chapter_word_count(
                        &self.storage,
                        book_url,
                        chapter_url,
                        &cached_chapter.content,
                    )
                })?
            {
                log::warn!("章节字数自愈回填失败（已忽略，不影响阅读）: {e}");
            }
            return Ok(RawChapter {
                content: cached_chapter.content,
                title: cached_chapter.chapter_title,
            });
        }

        // 2. 缓存未命中，从网络获取
        let source = self
            .storage
            .with_database(|db| {
                let repo = BookSourceRepository::new(db.connection());
                repo.find_by_url(source_url)
            })?
            .ok_or_else(|| LegadoError::Database(format!("书源不存在: {source_url}")))?;

        // [T4 | RuleDataInterface] 内容链变量注入：book.variable ⊕ chapter.variable
        //（章节同名键优先，对齐原版 getVariable chapter → book 级联）。合并结果随
        // WebChapter 进入 get_content 的 AnalyzeUrl 变量表与解析上下文种子——
        // 此前内容链仅携带章节变量（R3），token/host 类书级变量在正文链全丢。
        let book_variable: Option<String> = self.storage.with_database(|db| {
            Ok(BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .and_then(|b| b.variable))
        })?;
        let merged_variable = legado_fetcher::web_book::merge_variables_json(
            book_variable.as_deref(),
            chapter_variable,
        );

        let web_chapter = WebChapter {
            index: chapter_index,
            title: chapter_title.to_string(),
            url: chapter_url.to_string(),
            is_vip: false,
            is_volume: false,
            variable: merged_variable,
            word_count: None,
        };

        if task.is_some_and(TaskHandle::is_cancelled) {
            return Err(cancelled());
        }
        let mut deps = (self.deps)()?.for_book(source_url, book_url);
        if let Some(task) = task {
            deps = deps
                .with_cancellation(Arc::new(task.clone()))
                .with_execution_lease(Arc::new(task.clone()));
        }
        if let Some(task) = task
            && let Some(sink) = deps.media_sub_content.take()
        {
            let task = task.clone();
            deps.media_sub_content = Some(Arc::new(move |book, source, chapter, key, value| {
                task.with_active(|| sink(book, source, chapter, key, value));
            }));
        }
        let engine = legado_fetcher::web_book::build_engine(deps);
        let content = self.runtime.block_on(async {
            let fetch = engine.get_content(&source, &web_chapter);
            if let Some(task) = task {
                tokio::select! { biased;
                    _ = task.cancelled() => Err(cancelled()),
                    content = fetch => content,
                }
            } else {
                fetch.await
            }
        })?;

        // 3. 抓取成功后写入 DB 缓存（对齐原版 BookContent.analyzeContent
        //    L207-209 `needSave → BookHelp.saveContent` 的「获取成功即写」时机）。
        //    写失败仅告警不传播——缓存写入失败不得导致阅读获取失败。
        // [B-12] 未知章节 URL（不在当前目录）不写缓存：上游按目录定位章节，
        // 回退 (0, "") 写出的 index=0 缓存行会污染目录云图标与后续读取
        if known_chapter {
            publish(task, || {
                save_chapter_cache(
                    &self.storage,
                    book_url,
                    chapter_index,
                    chapter_title,
                    chapter_url,
                    &content,
                )
            })?;
        }

        Ok(RawChapter {
            content,
            title: chapter_title.to_string(),
        })
    }
    pub fn download(&self, book: &str, index: i32, task: &TaskHandle) -> LegadoResult<()> {
        let chapter = self
            .storage
            .with_database(|db| {
                BookChapterRepository::new(db.connection()).find_by_book_url_and_index(book, index)
            })?
            .ok_or_else(|| LegadoError::Database(format!("章节 {index} 不存在")))?;
        if chapter.is_volume && crate::manga_cache::is_manga(&self.storage, book)? {
            return Ok(());
        }
        if super::is_local_book(book) {
            let path = std::path::Path::new(book);
            let resolved = if path.is_absolute() {
                path.to_path_buf()
            } else {
                self.storage
                    .path()
                    .and_then(std::path::Path::parent)
                    .map(|parent| parent.join(path))
                    .unwrap_or_else(|| path.to_path_buf())
            };
            let content = legado_book::LocalBook::get_chapter_content(
                &resolved.to_string_lossy(),
                &super::chapter_to_local_info(&chapter),
            )?;
            publish(Some(task), || {
                save_chapter_content_with_storage(
                    &self.storage,
                    book,
                    index,
                    &chapter.title,
                    &content,
                    &chapter.url,
                )
            })??;
        } else {
            let source = self
                .storage
                .with_database(|db| BookRepository::new(db.connection()).find_by_url(book))?
                .ok_or_else(|| LegadoError::Database(format!("书籍 {book} 不存在")))?
                .origin;
            if source.is_empty() {
                return Err(LegadoError::Database(format!(
                    "书籍 {book} 未配置书源（origin 为空）"
                )));
            }
            self.read(
                ChapterRequest {
                    book_url: book,
                    chapter_url: &chapter.url,
                    source_url: &source,
                    chapter_index: index,
                    chapter_title: &chapter.title,
                    chapter_variable: chapter.variable.as_deref(),
                    known_chapter: true,
                },
                Some(task),
            )?;
        }
        Ok(())
    }
}

fn backfill_chapter_word_count(
    storage: &StorageContext,
    book_url: &str,
    chapter_url: &str,
    content: &str,
) -> LegadoResult<u64> {
    // 原版字数 = Kotlin `String.length`（UTF-16 码元数）
    let word_count = super::word_count_format(content.encode_utf16().count());
    if word_count.is_empty() {
        return Ok(0);
    }
    storage.with_database(|db| {
        BookChapterRepository::new(db.connection()).up_word_count(
            book_url,
            chapter_url,
            &word_count,
        )
    })
}

pub fn save_chapter_cache(
    storage: &StorageContext,
    book_url: &str,
    chapter_index: i32,
    chapter_title: &str,
    chapter_url: &str,
    content: &str,
) -> bool {
    // [B-1] 空内容不入缓存（对齐上游 BookHelp.kt:557-559）：杜绝空行入库后
    // 被读侧按命中返回、章节永久空白的缺陷链
    if content.trim().is_empty() {
        return false;
    }
    let now_ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    let cached_chapter = CachedChapter {
        id: 0,
        book_url: book_url.to_string(),
        chapter_index,
        chapter_title: chapter_title.to_string(),
        chapter_url: chapter_url.to_string(),
        content: content.to_string(),
        cached_at: now_ms,
        size_bytes: content.len() as i64,
    };
    let result = storage.with_database(|db| {
        let repo = CacheBookRepository::new(db.connection());
        repo.insert(&cached_chapter)?;
        Ok(())
    });
    if let Err(e) = result {
        log::warn!("阅读缓存写入失败（已忽略，不影响阅读）: {e}");
        return false;
    }
    // 回填失败仅告警（对齐原版 writeText：回填属 best-effort，不得影响阅读）
    if let Err(e) = backfill_chapter_word_count(storage, book_url, chapter_url, content) {
        log::warn!("章节字数回填失败（已忽略，不影响阅读）: {e}");
    }
    true
}

pub fn save_chapter_content_with_storage(
    storage: &StorageContext,
    book_url: &str,
    chapter_index: i32,
    title: &str,
    content: &str,
    chapter_url: &str,
) -> LegadoResult<bool> {
    // [B-1] 空内容不入缓存（对齐上游 BookHelp.kt:557-559）：空行入库会被
    // 读侧按命中返回，使该章节永久空白、永不重抓；返回 false 表示未写入
    if content.trim().is_empty() {
        return Ok(false);
    }
    // 缺省字段回填：对齐 Kotlin cached_chapters 主键（book_url + chapter_url）
    let (chapter_title, chapter_url) = if title.is_empty() || chapter_url.is_empty() {
        let ch = storage
            .with_database(|db| {
                let repo = BookChapterRepository::new(db.connection());
                repo.find_by_book_url_and_index(book_url, chapter_index)
            })?
            .ok_or_else(|| {
                LegadoError::Database(format!("章节 {chapter_index} 不存在: {book_url}"))
            })?;
        (
            if title.is_empty() {
                ch.title
            } else {
                title.to_string()
            },
            if chapter_url.is_empty() {
                ch.url
            } else {
                chapter_url.to_string()
            },
        )
    } else {
        (title.to_string(), chapter_url.to_string())
    };

    let now_ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    let chapter = CachedChapter {
        id: 0,
        book_url: book_url.to_string(),
        chapter_index,
        chapter_title,
        chapter_url,
        content: content.to_string(),
        cached_at: now_ms,
        size_bytes: content.len() as i64,
    };

    storage.with_database(|db| {
        let repo = CacheBookRepository::new(db.connection());
        repo.insert(&chapter)?;
        Ok(true)
    })
}
