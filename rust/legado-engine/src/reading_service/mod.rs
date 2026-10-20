//! 阅读应用服务：目录、正文和处理配置使用同一份显式资源。
use crate::search_service::SearchService;
use crate::{StorageContext, TaskGroup};
use legado_core::{
    LegadoError, LegadoResult,
    models::{Book, BookChapter, BookSource, ReplaceRule},
    web_book::{BookSourceFetcher, WebBookEngine, WebChapter},
};
use legado_db::{
    BookChapterRepository, BookRepository, BookSourceRepository, CacheRepository,
    ReplaceRuleRepository, repository::Repository,
};
use legado_fetcher::deps::FetcherDeps;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
mod access;
mod cache;
mod content;
mod pre_update;
mod processing;
mod toc;
pub use access::{chapter_to_local_info, is_local_book};
pub use cache::{CachedChapterEntry, ChapterCacheService};
pub use content::{
    ChapterContent, ChapterRequest, RawChapter, save_chapter_cache,
    save_chapter_content_with_storage,
};
#[cfg(feature = "quickjs")]
pub use pre_update::apply_web_info_to_book;
pub use processing::{
    ContentProcessing, can_remove_same_title, chinese_convert_direction, convert_title_by_type,
    process_content_with_rules_inner, same_title_removed_key, word_count_format,
};
pub type ReadingFetcherFactory = Arc<dyn Fn() -> LegadoResult<FetcherDeps> + Send + Sync>;
pub type LocalPathResolver = Arc<dyn Fn(&str) -> String + Send + Sync>;
#[derive(Clone)]
pub struct ReadingResources {
    pub storage: Option<StorageContext>,
    pub deps: Option<ReadingFetcherFactory>,
    pub tasks: TaskGroup,
    pub runtime: tokio::runtime::Handle,
    pub web_book: Arc<legado_fetcher::web_book_state::WebBookState>,
    pub js: Arc<legado_js::JsResources>,
    pub search: SearchService,
    pub resolve_path: LocalPathResolver,
}
#[derive(Clone)]
pub struct ReadingService {
    resources: ReadingResources,
}
impl ReadingService {
    pub fn new(resources: ReadingResources) -> Self {
        Self { resources }
    }
    fn with_database<F, R>(&self, f: F) -> LegadoResult<R>
    where
        F: FnOnce(&legado_db::Database) -> LegadoResult<R>,
    {
        self.storage()?.with_database(f)
    }
    fn storage(&self) -> LegadoResult<&StorageContext> {
        self.resources
            .storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))
    }
    pub fn chapter_content(&self) -> LegadoResult<ChapterContent> {
        Ok(ChapterContent::new(
            self.storage()?.clone(),
            self.resources.deps.clone().ok_or_else(|| {
                LegadoError::Database("数据库尚未初始化，请先调用 db_open".into())
            })?,
            self.resources.runtime.clone(),
        ))
    }
    #[cfg(feature = "quickjs")]
    fn deps_for_book(&self, source: &str, book: &str) -> LegadoResult<FetcherDeps> {
        let task = self
            .resources
            .tasks
            .begin()
            .map_err(|e| LegadoError::Ffi(e.to_string()))?;
        let factory =
            self.resources.deps.as_ref().ok_or_else(|| {
                LegadoError::Database("数据库尚未初始化，请先调用 db_open".into())
            })?;
        let mut deps = factory()?;
        if let Some(sink) = deps.media_sub_content.take() {
            let permit = task.clone();
            deps.media_sub_content = Some(Arc::new(move |book, source, chapter, key, value| {
                permit.with_active(|| sink(book, source, chapter, key, value));
            }));
        }
        Ok(deps
            .with_cancellation(Arc::new(task.clone()))
            .with_execution_lease(Arc::new(task))
            .for_book(source, book))
    }
}
fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChapterListResponse {
    /// 章节总数
    pub total: i32,
    /// 章节列表
    pub chapters: Vec<BookChapter>,
}

#[cfg(test)]
mod tests;
