//! 正文搜索执行：任务内选择章节、读取真实内容并发布增量命中。— Codex + Rust
use super::*;
use crate::TaskHandle;
use legado_core::content_search::{ContentSearchHit, ContentSearchMatcher};
use legado_db::CacheBookRepository;
use std::collections::HashSet;

const MAX_RESULTS: usize = 200;
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ContentSearchScope {
    Current,
    Cached,
    Network,
}
pub struct ContentSearchOptions {
    pub book_url: String,
    pub query: String,
    pub use_regex: bool,
    pub use_replace: bool,
    pub scope: ContentSearchScope,
    pub current_chapter_index: i32,
}
pub struct ContentSearchBatch {
    pub chapter_index: Option<i32>,
    pub chapter_title: String,
    pub hits: Vec<ContentSearchHit>,
    pub scanned: usize,
    pub total: usize,
    pub error: Option<String>,
    pub limit_reached: bool,
}
impl ReadingService {
    pub fn begin_content_search(&self) -> LegadoResult<TaskHandle> {
        self.resources
            .tasks
            .begin()
            .map_err(|e| LegadoError::Ffi(e.to_string()))
    }
    /// 在阻塞执行器运行；HTTP等待通过同一任务取消，事件提交使用既有发布门控。
    pub fn search_content(
        &self,
        options: ContentSearchOptions,
        task: &TaskHandle,
        mut emit: impl FnMut(ContentSearchBatch) -> bool,
    ) -> LegadoResult<()> {
        if task.is_cancelled() {
            return Ok(());
        }
        let Some(matcher) = ContentSearchMatcher::new(&options.query, options.use_regex) else {
            return Ok(());
        };
        if task.is_cancelled() {
            return Ok(());
        }
        let chapters = self.get_chapters(&options.book_url)?.chapters;
        let total = chapters.len();
        let mut send = |batch| task.with_active(|| emit(batch)).unwrap_or(false);
        if !send(ContentSearchBatch {
            chapter_index: None,
            chapter_title: String::new(),
            hits: vec![],
            scanned: 0,
            total,
            error: None,
            limit_reached: false,
        }) {
            return Ok(());
        }
        let cached: HashSet<String> = if options.scope == ContentSearchScope::Cached {
            ChapterCacheService::new(self.resources.storage.clone())
                .list_cached_chapters(&options.book_url)?
                .into_iter()
                .map(|c| c.url)
                .collect()
        } else {
            HashSet::new()
        };
        let mut count = 0;
        for (ordinal, chapter) in chapters.iter().enumerate() {
            if task.is_cancelled() {
                break;
            }
            let current = chapter.index == options.current_chapter_index;
            if options.scope == ContentSearchScope::Current && !current
                || options.scope == ContentSearchScope::Cached
                    && !current
                    && !cached.contains(&chapter.url)
            {
                continue;
            }
            let result = self
                .content_for_search(&options, chapter, task)
                .and_then(|content| {
                    if task.is_cancelled() {
                        return Ok(vec![]);
                    }
                    match content {
                        Some(text) => matcher.search(&text),
                        None => Ok(vec![]),
                    }
                });
            if task.is_cancelled() {
                break;
            }
            let (mut hits, error) = match result {
                Ok(hits) => (hits, None),
                Err(error) => (vec![], Some(error.to_string())),
            };
            hits.truncate(MAX_RESULTS - count);
            count += hits.len();
            if !send(ContentSearchBatch {
                chapter_index: Some(chapter.index),
                chapter_title: chapter.title.clone(),
                hits,
                scanned: ordinal + 1,
                total,
                error,
                limit_reached: count == MAX_RESULTS,
            }) || count == MAX_RESULTS
            {
                break;
            }
        }
        Ok(())
    }
    fn content_for_search(
        &self,
        options: &ContentSearchOptions,
        chapter: &BookChapter,
        task: &TaskHandle,
    ) -> LegadoResult<Option<String>> {
        let book = &options.book_url;
        if is_local_book(book) {
            let path = (self.resources.resolve_path)(book);
            let raw = legado_book::LocalBook::get_chapter_content(
                &path,
                &chapter_to_local_info(chapter),
            )?;
            return Ok(Some(self.apply_content_processing_inner(
                book,
                &raw,
                &chapter.title,
                options.use_replace,
                Some(chapter.index),
                false,
            )));
        }
        let cached_only = options.scope == ContentSearchScope::Cached
            && chapter.index != options.current_chapter_index;
        let raw = if cached_only {
            // 缓存快照之后可被用户清理；缺失/空内容只跳过，不能因此联网。
            let cached = self
                .with_database(|db| {
                    CacheBookRepository::new(db.connection())
                        .get_by_book_and_chapter_url(book, &chapter.url)
                })?
                .filter(|c| !c.content.trim().is_empty());
            let Some(cached) = cached else {
                return Ok(None);
            };
            RawChapter {
                content: cached.content,
                title: cached.chapter_title,
            }
        } else {
            let origin = self
                .with_database(|db| {
                    Ok(BookRepository::new(db.connection())
                        .find_by_url(book)?
                        .map(|b| b.origin))
                })?
                .ok_or_else(|| LegadoError::Database(format!("书籍 {book} 不存在")))?;
            self.chapter_content()?.read(
                ChapterRequest {
                    book_url: book,
                    chapter_url: &chapter.url,
                    source_url: &origin,
                    chapter_index: chapter.index,
                    chapter_title: &chapter.title,
                    chapter_variable: chapter.variable.as_deref(),
                    known_chapter: true,
                },
                Some(task),
            )?
        };
        Ok(Some(self.apply_content_processing_inner(
            book,
            &raw.content,
            &raw.title,
            options.use_replace,
            Some(chapter.index),
            false,
        )))
    }
}
#[cfg(all(test, feature = "quickjs"))]
mod tests;
