//! 换源应用服务：明确资源快照、取消边界与事务提交，不访问宿主全局状态。
use crate::{Operation, SourceSwitchState, StorageContext, SwitchPrefetchEntry, TaskHandle};
use futures::stream::{self, StreamExt};
use legado_core::{
    LegadoError, LegadoResult,
    models::{Book, BookChapter, BookSource},
    source_matcher::{SearchCandidate, SourceMatch, SourceMatcher},
    web_book::{BookSourceFetcher, WebBookInfo, WebChapter},
};
use legado_net::LegadoClient;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, future::Future, pin::Pin, sync::Arc};

mod apply;
mod enrich;
mod repository;
mod search;
pub use apply::{merge_variables, yield_stale_overlay_to_db};

pub const ENRICH_CONCURRENCY: usize = 8;
pub type SwitchFetcherFactory =
    Arc<dyn Fn() -> LegadoResult<legado_fetcher::deps::FetcherDeps> + Send + Sync>;
pub type SwitchSearchFuture =
    Pin<Box<dyn Future<Output = LegadoResult<Vec<SearchCandidate>>> + Send>>;
pub type SwitchSearcher = Arc<dyn Fn(SwitchSearchRequest) -> SwitchSearchFuture + Send + Sync>;

/// 单源搜索的窄请求；实现方只捕获所需数据能力，不持有根引擎。
pub struct SwitchSearchRequest {
    pub client: LegadoClient,
    pub source: BookSource,
    pub keyword: String,
    pub task: Option<TaskHandle>,
}

/// 由宿主装配；运行时寿命由宿主保证，服务只借Handle，不创建运行时。
pub struct SwitchResources {
    pub storage: Option<StorageContext>,
    pub factory: Option<SwitchFetcherFactory>,
    pub state: Arc<SourceSwitchState>,
    pub network: Arc<crate::NetworkContext>,
    pub web_book: Arc<legado_fetcher::web_book_state::WebBookState>,
    pub js: Arc<legado_js::JsResources>,
    pub runtime: tokio::runtime::Handle,
    pub search: SwitchSearcher,
}

#[derive(Clone)]
pub struct SourceSwitchService {
    storage: Option<StorageContext>,
    factory: Option<SwitchFetcherFactory>,
    state: Arc<SourceSwitchState>,
    operation: Option<Arc<Operation>>,
    deadline: Option<TaskHandle>,
    network: Arc<crate::NetworkContext>,
    web_book: Arc<legado_fetcher::web_book_state::WebBookState>,
    js: Arc<legado_js::JsResources>,
    runtime: tokio::runtime::Handle,
    search: SwitchSearcher,
}

struct SwitchCommitTarget<'a> {
    book_url: &'a str,
    source_url: &'a str,
    detail_url: &'a str,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SwitchSearchOptions {
    #[serde(default, rename = "loadInfo")]
    pub load_info: bool,
    #[serde(default, rename = "loadToc")]
    pub load_toc: bool,
    #[serde(default, rename = "loadWordCount")]
    pub load_word_count: bool,
    /// 强制网络重搜（对齐原版换源「刷新列表」/startSearch；默认 false 优先复用 searchBooks）
    #[serde(default, rename = "forceRefresh")]
    pub force_refresh: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceSwitchResponse {
    /// 原始书籍名称
    pub book_name: String,
    /// 原始作者
    pub author: String,
    /// 匹配到的候选列表（按评分降序）
    pub matches: Vec<SourceMatch>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ChangeSourceBatch {
    /// 刚完成书源的索引（0-based；DB 复用 / enrich 终批为 0）
    pub source_index: usize,
    pub source_url: String,
    pub source_name: String,
    /// 该源搜索失败时的错误信息（成功为 None）
    pub error: Option<String>,
    /// 已完成书源数量
    pub finished_count: usize,
    /// 本次搜索书源总数
    pub total_count: usize,
    /// 是否为最后一个批次（finished_count == total_count）
    pub is_last: bool,
    /// 当前已过滤评分候选全量快照（同名过滤(+可选作者校验) + 评分排序）
    pub matches: Vec<SourceMatch>,
}

impl SourceSwitchService {
    pub fn new(resources: SwitchResources) -> Self {
        Self {
            storage: resources.storage,
            factory: resources.factory,
            state: resources.state,
            network: resources.network,
            web_book: resources.web_book,
            js: resources.js,
            runtime: resources.runtime,
            search: resources.search,
            operation: None,
            deadline: None,
        }
    }
    pub fn state(&self) -> &Arc<SourceSwitchState> {
        &self.state
    }
    pub fn operation(&self) -> Option<&Arc<Operation>> {
        self.operation.as_ref()
    }
    pub fn cancel_apply(&self) {
        self.state.applies.cancel();
        legado_fetcher::web_book::bump_toc_fetch_epoch(&self.web_book);
    }
    pub fn start_search(mut self) -> LegadoResult<Self> {
        self.operation = Some(
            self.state
                .start_search()
                .map_err(|e| LegadoError::Internal(e.to_string()))?,
        );
        Ok(self)
    }

    pub fn start_apply(mut self) -> LegadoResult<Self> {
        self.operation = Some(
            self.state
                .applies
                .start()
                .map_err(|e| LegadoError::Internal(e.to_string()))?,
        );
        Ok(self)
    }

    pub(super) fn ensure_active(&self) -> LegadoResult<()> {
        if self.operation.as_ref().is_some_and(|op| !op.is_active())
            || self.deadline.as_ref().is_some_and(TaskHandle::is_cancelled)
        {
            Err(LegadoError::Internal("换源已取消".into()))
        } else {
            Ok(())
        }
    }

    pub(super) async fn cancelled(&self) {
        let parent = async {
            if let Some(operation) = &self.operation {
                operation.task().cancelled().await;
            } else {
                std::future::pending::<()>().await;
            }
        };
        let child = async {
            if let Some(task) = &self.deadline {
                task.cancelled().await;
            } else {
                std::future::pending::<()>().await;
            }
        };
        tokio::select! {_=parent=>{},_=child=>{}}
    }

    pub fn publish<T>(&self, callback: impl FnOnce() -> T) -> Option<T> {
        let publish = || {
            if let Some(operation) = &self.operation {
                operation.publish(callback)
            } else {
                Some(callback())
            }
        };
        if let Some(deadline) = &self.deadline {
            deadline.with_active(publish).flatten()
        } else {
            publish()
        }
    }

    pub(super) fn database<T>(
        &self,
        callback: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(callback)
    }

    pub(super) fn config(&self, key: &str) -> String {
        self.database(|db| {
            Ok(legado_db::CacheRepository::new(db.connection())
                .get(&format!("config:{key}"))?
                .unwrap_or_default())
        })
        .unwrap_or_default()
    }

    pub fn fetcher(&self) -> LegadoResult<legado_fetcher::web_book::RealBookSourceFetcher> {
        self.fetcher_for_book("", "")
    }

    pub fn fetcher_for_book(
        &self,
        source: &str,
        book: &str,
    ) -> LegadoResult<legado_fetcher::web_book::RealBookSourceFetcher> {
        self.ensure_active()?;
        let mut deps =
            self.factory.as_ref().ok_or_else(|| {
                LegadoError::Database("数据库尚未初始化，请先调用 db_open".into())
            })?()?;
        if let Some(sink) = deps.media_sub_content.take() {
            let context = self.clone();
            deps.media_sub_content = Some(Arc::new(move |book, source, chapter, key, value| {
                context.publish(|| sink(book, source, chapter, key, value));
            }));
        }
        if !source.is_empty() {
            deps = deps.for_book(source, book);
        }
        Ok(legado_fetcher::web_book::RealBookSourceFetcher::with_deps(
            deps,
        ))
    }

    pub fn prefetch_cache_insert(
        &self,
        source: &str,
        book: &str,
        info: Option<WebBookInfo>,
        chapters: Vec<WebChapter>,
    ) {
        self.publish(|| self.state.insert(source, book, info, chapters));
    }

    pub fn prefetch_cache_get(&self, source: &str, book: &str) -> Option<SwitchPrefetchEntry> {
        self.state.get(source, book)
    }
}

const SEARCH_GROUP_CONFIG_KEY: &str = "searchGroup";
impl SwitchSearchOptions {
    fn needs_enrichment(&self) -> bool {
        self.load_info || self.load_toc || self.load_word_count
    }
}

#[cfg(test)]
mod tests;
