//! 搜索应用服务：显式资源、会话归属和结果发布，不依赖FFI或进程全局变量。
use crate::source_batches::{SEARCH_CONCURRENCY, drive_source_batches};
use crate::source_catalog::load_search_sources_selected_from;
use crate::{NetworkContext, SearchSession, SearchTasks, StorageContext, TaskGroup, TaskHandle};
use legado_core::{
    LegadoError, LegadoResult,
    models::{BookSource, SearchBook as CoreSearchBook},
    source_matcher::SearchCandidate,
};
use legado_fetcher::deps::FetcherDeps;
use legado_net::LegadoClient;
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::Duration,
};
mod model;
mod records;
mod source;
pub use model::*;
pub use records::*;
pub use source::*;
pub const SEARCH_SOURCE_TIMEOUT: Duration = Duration::from_secs(30);
/// 宿主注入JS绑定等平台装配，不持有根引擎。
pub type SearchDepsFactory = Arc<dyn Fn(LegadoClient) -> FetcherDeps + Send + Sync>;
#[derive(Clone)]
pub struct SearchResources {
    pub storage: Option<StorageContext>,
    pub network: Arc<NetworkContext>,
    pub searches: Arc<SearchTasks>,
    pub tasks: TaskGroup,
    pub runtime: tokio::runtime::Handle,
    pub prepare: SearchDepsFactory,
}
#[derive(Clone)]
pub struct SearchService {
    resources: SearchResources,
}

/// 单次执行的数据快照，不持根引擎或宿主槽位。
#[derive(Clone)]
pub struct SearchContext {
    storage: Option<StorageContext>,
    task: Option<TaskHandle>,
    deps: FetcherDeps,
    session: Option<Arc<SearchSession>>,
}
impl SearchContext {
    pub fn storage(&self) -> Option<&StorageContext> {
        self.storage.as_ref()
    }
    pub fn task(&self) -> Option<&TaskHandle> {
        self.task.as_ref()
    }

    pub fn new(deps: FetcherDeps, storage: Option<StorageContext>) -> Self {
        Self {
            deps,
            storage,
            session: None,
            task: None,
        }
    }
    pub fn with_session(mut self, session: Arc<SearchSession>) -> Self {
        self = self.with_task(session.task().clone());
        self.session = Some(session);
        self
    }
    pub fn with_task(mut self, task: TaskHandle) -> Self {
        self.deps.js = self.deps.js.with_cancellation(Arc::new(task.clone()));
        self.task = Some(task);
        self
    }
    fn ensure_active(&self) -> LegadoResult<()> {
        if self.task.as_ref().is_some_and(TaskHandle::is_cancelled) {
            Err(search_cancelled())
        } else {
            Ok(())
        }
    }
    fn session_id(&self) -> u64 {
        self.session
            .as_ref()
            .map_or(0, |session| session.session_id)
    }
}

pub struct SearchRun(pub Arc<SearchSession>);
impl Drop for SearchRun {
    fn drop(&mut self) {
        self.0.cancel();
        self.0.finish();
    }
}
fn search_cancelled() -> LegadoError {
    LegadoError::Network("搜索已取消".into())
}
fn clear_current_session_if_same(session: &Arc<SearchSession>) {
    session.finish();
}
pub async fn precise_search_owned(
    context: SearchContext,
    name: &str,
    author: &str,
    sources: Vec<BookSource>,
) -> LegadoResult<CoreSearchBook> {
    let task = context.task.clone().expect("精搜入口必须登记任务");
    let _guard = task.guard();
    let search = async {
        for source in sources {
            context.ensure_active()?;
            let items =
                match search_single_source_with_context(&context, &source, name, 1, false).await {
                    Ok(items) => items,
                    Err(error) => {
                        context.ensure_active()?;
                        eprintln!(
                            "[precise_search] 书源 {} 失败（跳过）: {error}",
                            source.book_source_name
                        );
                        continue;
                    }
                };
            context.ensure_active()?;
            for item in items {
                if item.book_name == name && (author.is_empty() || item.author == author) {
                    return Ok(result_to_search_book(item));
                }
            }
        }
        Err(LegadoError::Network(format!(
            "未搜索到 {name}({author}) 书籍"
        )))
    };
    let result = tokio::select! {
        biased;
        _ = task.cancelled() => return Err(search_cancelled()),
        result = search => result,
    };
    task.with_active(|| result)
        .unwrap_or_else(|| Err(search_cancelled()))
}
pub fn classify_source_outcome(result: &LegadoResult<Vec<SearchResult>>) -> &'static str {
    match result {
        Ok(list) if !list.is_empty() => "ok",
        Ok(_) => "empty",
        Err(e) => match e {
            LegadoError::LoginRequired(_) => "login_required",
            LegadoError::Timeout(_) => "timeout",
            LegadoError::JsEngine(_) => "js_error",
            LegadoError::Network(msg) => {
                let lower = msg.to_lowercase();
                if msg.starts_with("单源搜索崩溃: ") {
                    // panic 文本来自底层执行，不能让其中的 timeout/cancel 改写异常分类。
                    "parser_error"
                } else if msg.contains("超时")
                    || lower.contains("timeout")
                    || lower.contains("timed out")
                {
                    "timeout"
                } else if msg.contains("取消") || lower.contains("cancel") {
                    "cancelled"
                } else if msg.contains("崩溃") {
                    "parser_error"
                } else if msg.contains("任务异常") {
                    "cancelled"
                } else {
                    "http_error"
                }
            }
            LegadoError::ContentEmpty(_) | LegadoError::TocEmpty(_) => "empty",
            LegadoError::Io(_) => "http_error",
            LegadoError::Parser(_)
            | LegadoError::BookParse(_)
            | LegadoError::Serialization(_)
            | LegadoError::Database(_)
            | LegadoError::Ffi(_)
            | LegadoError::Internal(_) => "parser_error",
        },
    }
}
impl SearchService {
    pub fn new(resources: SearchResources) -> Self {
        Self { resources }
    }
    pub fn context(&self, client: LegadoClient) -> SearchContext {
        SearchContext::new(
            (self.resources.prepare)(client),
            self.resources.storage.clone(),
        )
    }
    pub fn begin_search(&self) -> LegadoResult<Arc<SearchSession>> {
        self.resources
            .searches
            .start()
            .map_err(|e| LegadoError::Internal(e.to_string()))
    }
    pub fn current_session(&self) -> Option<Arc<SearchSession>> {
        self.resources.searches.current()
    }
    pub fn load_search_sources_selected(&self, urls: &[String]) -> LegadoResult<Vec<BookSource>> {
        load_search_sources_selected_from(self.resources.storage.as_ref(), urls)
    }
    pub fn precision(&self) -> bool {
        self.resources
            .storage
            .as_ref()
            .and_then(|storage| {
                storage
                    .with_database(|db| {
                        Ok(legado_db::CacheRepository::new(db.connection())
                            .get("config:precisionSearch")?
                            .unwrap_or_default())
                    })
                    .ok()
            })
            .is_some_and(|value| value == "true")
    }
    pub fn search_books_selected(
        &self,
        keyword: &str,
        source_urls: &[String],
    ) -> LegadoResult<Vec<SearchResult>> {
        // 搜索变量按来源/关键词取得显式作用域，不共享“当前流程”单槽。
        // 获取待搜索的书源
        let sources = self.load_search_sources_selected(source_urls)?;
        if sources.is_empty() {
            return Ok(Vec::new());
        }
        let precision = self.precision();

        // 限流并发 + 单源超时 + 异常隔离（对齐原版 SearchModel 线程池语义），
        // 逐源完成后累积结果；失败源跳过不阻断整体。
        let keyword_owned = keyword.to_string();
        // P0-3：为本次搜索创建独立会话（取代并取消上一会话），不再重置全局标志
        let session = self.begin_search()?;
        let _run = SearchRun(session.clone());
        let context = self
            .context(self.resources.network.client()?)
            .with_session(session.clone());
        let mut results = self.resources.runtime.block_on(async {
            let work = context.clone();
            let mut all_results: Vec<SearchResult> = Vec::new();
            // 7.4：on_source 复检用（会话身份）
            let session_cb = Arc::clone(&session);
            drive_source_batches(
                sources,
                SEARCH_CONCURRENCY,
                SEARCH_SOURCE_TIMEOUT,
                session.as_ref(),
                &session.paused,
                move |source: BookSource| {
                    let work = work.clone();
                    let keyword = keyword_owned.clone();
                    async move {
                        search_single_source_with_context(&work, &source, &keyword, 1, precision)
                            .await
                    }
                },
                |outcome| {
                    // 门控同时检查取消与原槽位身份，避免检查后被替换仍累积。
                    session_cb.with_current(|| {
                        if let Ok(mut items) = outcome.result {
                            all_results.append(&mut items);
                        }
                    });
                    Ok(())
                },
            )
            .await;
            Ok::<_, LegadoError>(all_results)
        })?;

        // 7.4：持久化前复检——若已取消则丢弃累积结果，不落库（防旧搜索残留污染 searchBooks）
        if session.is_cancelled() {
            return Ok(Vec::new());
        }

        // 搜索完成后批量附加阅读记录标识（一次性构建内存索引，O(1) 查找，
        // 对齐上游 ReadRecordIndex 思路；search_cover 复用本函数但不关心该字段）
        let index = ReadRecordIndex::load_from(context.storage.as_ref());
        annotate_results(&mut results, &index);

        // 一次性搜索同样落库（对齐 SearchModel.insert），供换源复用
        let core_books: Vec<_> = results.iter().cloned().map(result_to_search_book).collect();
        if session
            .with_current(|| persist_search_books(context.storage.as_ref(), &core_books))
            .is_none()
        {
            return Ok(Vec::new());
        }

        Ok(results)
    }

    pub fn precise_search_selected(
        &self,
        name: &str,
        author: &str,
        source_urls: &[String],
    ) -> LegadoResult<CoreSearchBook> {
        let name = name.trim();
        if name.is_empty() {
            return Err(LegadoError::Parser("精确搜索书名不能为空".into()));
        }
        let author = author.trim();
        let task = self
            .resources
            .tasks
            .begin()
            .map_err(|error| LegadoError::Network(format!("搜索任务不可用: {error}")))?;
        let storage = self.resources.storage.clone();
        let sources = load_search_sources_selected_from(storage.as_ref(), source_urls)?;
        if sources.is_empty() {
            return Err(LegadoError::Network("没有可用书源".into()));
        }
        let context = self
            .context(self.resources.network.client()?)
            .with_task(task);
        self.resources
            .runtime
            .block_on(precise_search_owned(context, name, author, sources))
    }

    pub fn multi_source_search_selected(
        &self,
        query: &str,
        source_urls: &[String],
    ) -> LegadoResult<Vec<AnnotatedCandidate>> {
        // 本次操作固定资源与会话，逐源变量不依赖进程当前流程。
        // P0-3：为本次搜索创建独立会话（取代并取消上一会话），不再重置全局标志
        let session = self.begin_search()?;
        let _run = SearchRun(session.clone());

        let sources = self.load_search_sources_selected(source_urls)?;
        if sources.is_empty() {
            clear_current_session_if_same(&session); // 7.5：空源早退亦清理会话
            return Ok(Vec::new());
        }
        let precision = self.precision();

        // 先保留书源输入错误/空源的原返回顺序，再装配网络能力。
        let context = self
            .context(self.resources.network.client()?)
            .with_session(session.clone());

        // 委托统一单源执行器（drive_source_batches + search_single_source），与
        // search_books / run_multi_stream 共享同一并发/超时/解析语义：有界并发
        // SEARCH_CONCURRENCY、每源 SEARCH_SOURCE_TIMEOUT(30s)、无截断。原
        // MultiSourceSearcher/WebSourceSearcher 独立驱动器的 10s 全局超时、20 条
        // 截断与跨源去重/相关性排序已移除——聚合排序下沉至 Flutter，对齐原版
        // SearchModel「Rust 出原始单源结果、UI 按 mergeItems 聚合」。
        let query_owned = query.to_string();
        let results: Vec<SearchResult> = self.resources.runtime.block_on(async {
            let work = context.clone();
            let mut all_results: Vec<SearchResult> = Vec::new();
            // 7.4：on_source 复检用（会话身份）
            let session_cb = Arc::clone(&session);
            drive_source_batches(
                sources,
                SEARCH_CONCURRENCY,
                SEARCH_SOURCE_TIMEOUT,
                session.as_ref(),
                &session.paused,
                move |source: BookSource| {
                    let work = work.clone();
                    let query = query_owned.clone();
                    async move {
                        search_single_source_with_context(&work, &source, &query, 1, precision)
                            .await
                    }
                },
                |outcome| {
                    // 门控同时检查取消与原槽位身份，避免检查后被替换仍累积。
                    session_cb.with_current(|| {
                        if let Ok(mut items) = outcome.result {
                            all_results.append(&mut items);
                        }
                    });
                    Ok(())
                },
            )
            .await;
            Ok::<_, LegadoError>(all_results)
        })?;

        // 7.4：已取消则丢弃累积结果（一次性入口语义，防旧搜索残留）
        if session.is_cancelled() {
            return Ok(Vec::new());
        }

        // [审计 D3 | SearchModel.insert] 一次性入口同样落库 searchBooks，供换源
        // getDbSearchBooks 复用（search_books 已有同款；当前 UI 只用流式主路径，
        // 此处对齐原版"两入口均落库"语义，防后续调用方换源 DB 缓存偏少）
        let core_books: Vec<_> = results.iter().cloned().map(result_to_search_book).collect();
        if session
            .with_current(|| persist_search_books(context.storage.as_ref(), &core_books))
            .is_none()
        {
            return Ok(Vec::new());
        }

        // 批量附加阅读记录标识后序列化（不修改 core 的 SearchResult 结构，通过加法式
        // DTO 扩展输出 JSON）。统一执行器不做跨源去重/相关性排序（聚合下沉至 Flutter），
        // 故 relevance_score 恒为 0。
        let index = ReadRecordIndex::load_from(context.storage.as_ref());
        let annotated: Vec<AnnotatedCandidate> = results
            .into_iter()
            .map(|c| build_annotated_candidate(c, &index))
            .collect();

        Ok(annotated)
    }

    pub fn cancel_search(&self) {
        if let Some(s) = self.current_session() {
            s.cancel();
        }
    }

    pub fn pause_search(&self) {
        if let Some(s) = self.current_session() {
            s.set_paused(true);
        }
    }

    pub fn resume_search(&self) {
        if let Some(s) = self.current_session() {
            s.set_paused(false);
        }
    }

    pub fn search_cover(&self, book_name: &str) -> LegadoResult<Vec<CoverCandidate>> {
        // 复用多书源搜索（搜索所有启用的书源）
        let results = self.search_books_selected(book_name, &[])?;
        Ok(extract_cover_candidates(results))
    }

    pub async fn run_multi_stream_selected<F>(
        &self,
        query: String,
        source_urls: Vec<String>,
        page: i32,
        mut on_batch: F,
    ) where
        F: FnMut(SearchSourceBatch) -> Result<(), String>,
    {
        // 所有源使用本次会话捕获的数据能力，回调只向原所属实例提交。
        // P0-3：为本次搜索创建独立会话（取代并取消上一会话），不再重置全局标志
        let session = match self.begin_search() {
            Ok(session) => session,
            Err(error) => {
                log::error!("流式搜索无法登记: {error}");
                return;
            }
        };
        let _run = SearchRun(session.clone());

        // 书源加载失败时以空流结束（Dart 侧表现为无结果）
        let sources = self
            .load_search_sources_selected(&source_urls)
            .unwrap_or_default();
        if sources.is_empty() {
            clear_current_session_if_same(&session); // 7.5：空源早退亦清理会话
            return;
        }

        let client = match self.resources.network.client() {
            Ok(c) => c,
            Err(e) => {
                log::error!("流式搜索：共享 HTTP 客户端初始化失败: {e}");
                clear_current_session_if_same(&session); // 7.5：HTTP 失败早退亦清理会话
                return;
            }
        };

        let context = self.context(client).with_session(session.clone());
        let work = context.clone();

        // 一次性构建阅读记录索引，逐批附加标识（对齐 ReadRecordIndex 思路）
        let read_record_index = ReadRecordIndex::load_from(context.storage.as_ref());

        // hasMore 累积（批次B G-B-02）：任一已推送批次非空 → true
        // 对齐原版 SearchModel `hasMore = hasMore || items.isNotEmpty()` 语义
        let mut has_more_acc = false;
        // 7.4：on_source 复检用（会话身份），避免旧会话批次进入持久化/流
        let session_cb = Arc::clone(&session);
        let precision = self.precision();

        drive_source_batches(
            sources,
            SEARCH_CONCURRENCY,
            SEARCH_SOURCE_TIMEOUT,
            session.as_ref(),
            &session.paused,
            move |source: BookSource| {
                let work = work.clone();
                let query = query.clone();
                // 页码透传（批次B G-B-01）：同关键词翻页递增、新关键词重置为 1
                async move {
                    search_single_source_with_context(&work, &source, &query, page, precision).await
                }
            },
            |outcome| {
                // 7.4：序列化/持久化/sink.add 前复检会话未取消且仍为当前（防旧会话残留写入）
                session_cb
                    .with_current(|| {
                        // 逐源错误八分类（任务书 B P2 项1，2026-09-19）：批次组装单点映射，
                        // 结果写入批次 JSON `error_class`（加法式字段，见 API_CONTRACT.md §2.4 登记）
                        let error_class = classify_source_outcome(&outcome.result);
                        let (mut books, error) = match outcome.result {
                            Ok(list) => (list, None),
                            Err(e) => (Vec::new(), Some(e.to_string())),
                        };

                        // 批次推送前附加阅读记录标识
                        annotate_results(&mut books, &read_record_index);

                        // 对齐原版 SearchModel：逐源 insert searchBooks，供换源 getDbSearchBooks 复用
                        let core_books: Vec<_> =
                            books.iter().cloned().map(result_to_search_book).collect();
                        persist_search_books(context.storage.as_ref(), &core_books);

                        // hasMore 累积（原版语义：非空批次的 OR；失败/空批次不贡献）
                        if !books.is_empty() {
                            has_more_acc = true;
                        }

                        let batch = SearchSourceBatch {
                            source_index: outcome.index,
                            source_url: outcome.source_url,
                            source_name: outcome.source_name,
                            books: core_books,
                            error,
                            finished_count: outcome.finished_count,
                            total_count: outcome.total_count,
                            is_last: outcome.is_last,
                            has_more: has_more_acc,
                            error_class: error_class.to_string(),
                        };

                        on_batch(batch)
                    })
                    .unwrap_or(Ok(()))
            },
        )
        .await;
        // 7.5：drive 返回后清理当前会话（若仍为本会话；A 被 B 取代时不误清 B）
        clear_current_session_if_same(&session);
    }

    pub async fn search_single_source(
        &self,
        client: &LegadoClient,
        source: &BookSource,
        keyword: &str,
        page: i32,
        precision: bool,
    ) -> LegadoResult<Vec<SearchResult>> {
        let task = self
            .resources
            .tasks
            .begin()
            .map_err(|error| LegadoError::Network(format!("搜索任务不可用: {error}")))?;
        let context = self.context(client.clone()).with_task(task);
        search_single_source_owned(context, source, keyword, page, precision).await
    }
}

#[cfg(test)]
mod tests;
