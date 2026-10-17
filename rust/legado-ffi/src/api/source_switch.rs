//! 换源宿主适配：捕获显式资源、复用单源搜索并转换旧文档入口。
use crate::runtime;
use legado_core::{LegadoError, LegadoResult, models::Book, source_matcher::SearchCandidate};
#[cfg(test)]
use legado_core::{
    models::{BookChapter, BookSource},
    source_matcher::SourceMatch,
    web_book::{BookSourceFetcher, WebBookInfo, WebChapter},
};
use legado_engine::SourceSwitchState;
#[cfg(test)]
use legado_engine::SwitchPrefetchEntry;
#[cfg(test)]
use legado_engine::source_switch_service::ENRICH_CONCURRENCY;
pub use legado_engine::source_switch_service::{
    ChangeSourceBatch, SourceSwitchResponse, SwitchSearchOptions, merge_variables,
    yield_stale_overlay_to_db,
};
use legado_engine::source_switch_service::{SourceSwitchService, SwitchResources, SwitchSearcher};
use std::{ops::Deref, sync::Arc};

#[derive(Clone)]
struct SwitchContext(SourceSwitchService);
impl Deref for SwitchContext {
    type Target = SourceSwitchService;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
impl SwitchContext {
    fn host() -> Self {
        if let Ok(engine) = crate::engine_holder::current() {
            return Self::from_engine(&engine, crate::engine_holder::switches());
        }
        Self::capture(None, crate::engine_holder::switches())
    }
    fn from_engine(engine: &legado_engine::EngineContext, state: Arc<SourceSwitchState>) -> Self {
        Self::capture(Some(engine), state)
    }

    fn capture(
        engine: Option<&legado_engine::EngineContext>,
        state: Arc<SourceSwitchState>,
    ) -> Self {
        let storage = engine.map(|e| e.storage().clone());
        let factory = engine.map(super::web_book::deps_for_engine);
        let network = engine
            .map(|e| e.network().clone())
            .unwrap_or_else(crate::engine_holder::network);
        let web_book = engine
            .map(|e| e.web_book_state().clone())
            .unwrap_or_else(crate::engine_holder::web_book_state);
        let js = engine
            .map(|e| e.js_resources().clone())
            .unwrap_or_else(crate::engine_holder::js_resources);
        let login = engine
            .map(|e| e.source_login_cache().clone())
            .unwrap_or_else(crate::engine_holder::source_login_cache);
        let info = engine
            .map(|e| e.source_info_map().clone())
            .unwrap_or_else(crate::engine_holder::source_info_map);
        let rate = engine
            .map(|e| e.rate_limiter())
            .unwrap_or_else(crate::engine_holder::rate_limiter);
        let (search_storage, search_js, search_web_book) =
            (storage.clone(), js.clone(), web_book.clone());
        let search: SwitchSearcher = Arc::new(move |request| {
            let mut deps = legado_fetcher::deps::FetcherDeps::new(request.client)
                .with_js_resources(search_js.clone())
                .with_web_book_state(search_web_book.clone());
            deps.rate_limiter = rate.clone();
            let mut context = super::search::SearchContext::assemble(
                deps,
                search_storage.clone(),
                login.clone(),
                info.clone(),
            );
            if let Some(task) = request.task {
                context = context.with_task(task);
            }
            Box::pin(async move {
                let source = request.source;
                let results = super::search::search_single_source_with_context(
                    &context,
                    &source,
                    &request.keyword,
                    1,
                    false,
                )
                .await?;
                Ok(results
                    .into_iter()
                    .map(|r| SearchCandidate {
                        source_url: r.source_url,
                        source_name: r.source_name,
                        book_url: r.book_url,
                        book_name: r.book_name,
                        author: r.author,
                        latest_chapter: r.latest_chapter,
                        word_count: r.word_count,
                        chapter_word_count_text: None,
                        chapter_word_count: -1,
                        respond_time: -1,
                        origin_order: source.custom_order,
                        book_score: 0,
                        variable: r.variable,
                    })
                    .collect())
            })
        });
        Self(SourceSwitchService::new(SwitchResources {
            storage,
            factory,
            state,
            network,
            web_book,
            js,
            runtime: runtime::get_runtime().handle().clone(),
            search,
        }))
    }
    fn start_search(self) -> LegadoResult<Self> {
        Ok(Self(self.0.start_search()?))
    }
    fn start_apply(self) -> LegadoResult<Self> {
        Ok(Self(self.0.start_apply()?))
    }
    #[cfg(test)]
    fn switch_book_source_prefetch_with<F: BookSourceFetcher>(
        &self,
        fetcher: &F,
        book_url: &str,
        source_url: &str,
        detail_url: &str,
    ) -> LegadoResult<String> {
        serde_json::to_string(
            &self.switch_book_source_prefetch_entity_with(
                fetcher, book_url, source_url, detail_url,
            )?,
        )
        .map_err(LegadoError::Serialization)
    }
    fn search_alternative_sources(
        &self,
        name: &str,
        author: &str,
        json: &str,
        options: &str,
    ) -> LegadoResult<SourceSwitchResponse> {
        self.search_alternative_sources_selected(
            name,
            author,
            &crate::api::search::parse_source_urls(json)?,
            self.resolve_switch_options(options),
        )
    }
    #[cfg(test)]
    async fn run_change_source_stream<F>(
        &self,
        name: String,
        author: String,
        urls: String,
        options: String,
        mut callback: F,
    ) where
        F: FnMut(String) -> Result<(), String>,
    {
        self.run_change_source_stream_typed(name, author, urls, options, |batch| {
            callback(serde_json::to_string(&batch).map_err(|e| e.to_string())?)
        })
        .await;
    }
    async fn run_change_source_stream_typed<F>(
        &self,
        name: String,
        author: String,
        json: String,
        options: String,
        callback: F,
    ) where
        F: FnMut(ChangeSourceBatch) -> Result<(), String>,
    {
        let Ok(urls) = crate::api::search::parse_source_urls(&json) else {
            return;
        };
        self.run_change_source_stream_selected(
            name,
            author,
            urls,
            self.resolve_switch_options(&options),
            callback,
        )
        .await;
    }
    #[cfg(test)]
    fn resolve_switch_sources(&self, json: &str) -> LegadoResult<Vec<BookSource>> {
        self.resolve_switch_sources_selected(&crate::api::search::parse_source_urls(json)?)
    }
    fn resolve_switch_options(&self, options_json: &str) -> SwitchSearchOptions {
        let trimmed = options_json.trim();
        if !trimmed.is_empty()
            && trimmed != "null"
            && let Ok(opts) = serde_json::from_str::<SwitchSearchOptions>(trimmed)
        {
            return opts;
        }
        self.default_options()
    }
    #[cfg(test)]
    async fn enrich_item_with_timeout(
        &self,
        fetcher: &impl BookSourceFetcher,
        source: &BookSource,
        candidate: SearchCandidate,
        options: &SwitchSearchOptions,
        timeout: std::time::Duration,
    ) -> SearchCandidate {
        match tokio::time::timeout(
            timeout,
            self.enrich_one_switch_candidate_with(fetcher, source, candidate.clone(), options),
        )
        .await
        {
            Ok(enriched) => enriched,
            Err(_) => {
                log::warn!(
                    "换源预拉超时（{}s）候选={} 源={}：候选原样保留（单失败隔离不阻塞他项）",
                    timeout.as_secs(),
                    candidate.book_url,
                    source.book_source_url
                );
                candidate
            }
        }
    }
}

#[cfg(test)]
fn prefetch_cache_clear() {
    crate::engine_holder::switches().clear();
}

#[cfg(test)]
fn prefetch_cache_insert(
    source: &str,
    book: &str,
    info: Option<WebBookInfo>,
    chapters: Vec<WebChapter>,
) {
    crate::engine_holder::switches().insert(source, book, info, chapters);
}

#[cfg(test)]
fn prefetch_cache_get(source: &str, book: &str) -> Option<SwitchPrefetchEntry> {
    crate::engine_holder::switches().get(source, book)
}

pub fn search_alternative_sources(
    book_name: &str,
    author: &str,
    source_urls_json: &str,
    options_json: &str,
) -> LegadoResult<SourceSwitchResponse> {
    let context = SwitchContext::host().start_search()?;
    let _guard = context.operation().unwrap().guard();
    let result =
        context.search_alternative_sources(book_name, author, source_urls_json, options_json);
    context
        .publish(|| result)
        .unwrap_or_else(|| Err(LegadoError::Internal("换源已取消".into())))
}

pub async fn run_change_source_stream<F>(
    book_name: String,
    author: String,
    urls: String,
    options: String,
    mut on_batch: F,
) where
    F: FnMut(String) -> Result<(), String>,
{
    run_change_source_stream_typed(book_name, author, urls, options, |batch| {
        on_batch(serde_json::to_string(&batch).map_err(|e| e.to_string())?)
    })
    .await;
}

pub async fn run_change_source_stream_typed<F>(
    book_name: String,
    author: String,
    source_urls_json: String,
    options_json: String,
    on_batch: F,
) where
    F: FnMut(ChangeSourceBatch) -> Result<(), String>,
{
    let Ok(context) = SwitchContext::host().start_search() else {
        return;
    };
    let _guard = context.operation().unwrap().guard();
    context
        .run_change_source_stream_typed(book_name, author, source_urls_json, options_json, on_batch)
        .await
}

pub fn switch_book_source(
    book_url: &str,
    new_source_url: &str,
    new_book_url: &str,
) -> LegadoResult<String> {
    serde_json::to_string(&switch_book_source_entity(
        book_url,
        new_source_url,
        new_book_url,
    )?)
    .map_err(LegadoError::Serialization)
}

pub fn switch_book_source_entity(
    book_url: &str,
    new_source_url: &str,
    new_book_url: &str,
) -> LegadoResult<Book> {
    let context = SwitchContext::host().start_apply()?;
    let _guard = context.operation().unwrap().guard();
    let fetcher = context.fetcher_for_book(new_source_url, new_book_url)?;
    context.switch_book_source_entity_with(&fetcher, book_url, new_source_url, new_book_url)
}

#[cfg(test)]
fn switch_book_source_with<F: BookSourceFetcher>(
    fetcher: &F,
    book_url: &str,
    new_source_url: &str,
    new_book_url: &str,
) -> LegadoResult<String> {
    let context = SwitchContext::host().start_apply()?;
    let _guard = context.operation().unwrap().guard();
    serde_json::to_string(&context.switch_book_source_entity_with(
        fetcher,
        book_url,
        new_source_url,
        new_book_url,
    )?)
    .map_err(LegadoError::Serialization)
}

pub fn switch_book_source_prefetch(
    book_url: &str,
    new_source_url: &str,
    new_book_url: &str,
) -> LegadoResult<String> {
    serde_json::to_string(&switch_book_source_prefetch_entity(
        book_url,
        new_source_url,
        new_book_url,
    )?)
    .map_err(LegadoError::Serialization)
}

pub fn switch_book_source_prefetch_entity(
    book_url: &str,
    new_source_url: &str,
    new_book_url: &str,
) -> LegadoResult<Book> {
    let context = SwitchContext::host().start_apply()?;
    let _guard = context.operation().unwrap().guard();
    let fetcher = context.fetcher_for_book(new_source_url, new_book_url)?;
    context.switch_book_source_prefetch_entity_with(
        &fetcher,
        book_url,
        new_source_url,
        new_book_url,
    )
}

#[cfg(test)]
fn switch_book_source_prefetch_with<F: BookSourceFetcher>(
    fetcher: &F,
    book_url: &str,
    new_source_url: &str,
    new_book_url: &str,
) -> LegadoResult<String> {
    let context = SwitchContext::host().start_apply()?;
    let _guard = context.operation().unwrap().guard();
    serde_json::to_string(&context.switch_book_source_prefetch_entity_with(
        fetcher,
        book_url,
        new_source_url,
        new_book_url,
    )?)
    .map_err(LegadoError::Serialization)
}

#[cfg(test)]
pub(crate) fn resolve_switch_sources(source_urls_json: &str) -> LegadoResult<Vec<BookSource>> {
    SwitchContext::host().resolve_switch_sources(source_urls_json)
}

#[cfg(test)]
pub(crate) fn resolve_switch_options(options_json: &str) -> SwitchSearchOptions {
    SwitchContext::host().resolve_switch_options(options_json)
}

#[cfg(test)]
async fn enrich_switch_candidates_async<F, MF>(
    sources: &[BookSource],
    candidates: Vec<SearchCandidate>,
    options: &SwitchSearchOptions,
    make_fetcher: MF,
) -> LegadoResult<Vec<SearchCandidate>>
where
    F: BookSourceFetcher + Send + 'static,
    MF: Fn() -> LegadoResult<F> + Send + Sync + 'static,
{
    SwitchContext::host()
        .enrich_switch_candidates_async(sources, candidates, options, move |_| make_fetcher())
        .await
}

#[cfg(test)]
async fn enrich_item_with_timeout(
    fetcher: &impl BookSourceFetcher,
    source: &BookSource,
    candidate: SearchCandidate,
    options: &SwitchSearchOptions,
    timeout: std::time::Duration,
) -> SearchCandidate {
    SwitchContext::host()
        .enrich_item_with_timeout(fetcher, source, candidate, options, timeout)
        .await
}

#[cfg(test)]
async fn enrich_one_switch_candidate_with(
    fetcher: &impl BookSourceFetcher,
    source: &BookSource,
    candidate: SearchCandidate,
    options: &SwitchSearchOptions,
) -> SearchCandidate {
    SwitchContext::host()
        .enrich_one_switch_candidate_with(fetcher, source, candidate, options)
        .await
}

#[cfg(test)]
fn persist_switch_matches(matches: &[SourceMatch]) {
    SwitchContext::host().persist_switch_matches(matches)
}

pub fn search_alternative_sources_selected(
    name: &str,
    author: &str,
    urls: &[String],
    options: SwitchSearchOptions,
) -> LegadoResult<SourceSwitchResponse> {
    let context = SwitchContext::host().start_search()?;
    let _guard = context.operation().unwrap().guard();
    let result = context.search_alternative_sources_selected(name, author, urls, options);
    context
        .publish(|| result)
        .unwrap_or_else(|| Err(LegadoError::Internal("换源已取消".into())))
}

pub async fn run_change_source_stream_selected<F>(
    name: String,
    author: String,
    urls: Vec<String>,
    options: SwitchSearchOptions,
    callback: F,
) where
    F: FnMut(ChangeSourceBatch) -> Result<(), String>,
{
    let Ok(context) = SwitchContext::host().start_search() else {
        return;
    };
    let _guard = context.operation().unwrap().guard();
    context
        .run_change_source_stream_selected(name, author, urls, options, callback)
        .await;
}

pub fn cancel_switch_apply() {
    SwitchContext::host().cancel_apply();
}
pub fn update_search_book_score(book_url: &str, score: i32) -> LegadoResult<()> {
    SwitchContext::host().update_search_book_score(book_url, score)
}
pub fn delete_search_book(book_url: &str) -> LegadoResult<()> {
    SwitchContext::host().delete_search_book(book_url)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::source as source_api;
    use std::sync::atomic::Ordering;

    #[test]
    fn test_source_switch_response_serialize() {
        let resp = SourceSwitchResponse {
            book_name: "斗破苍穹".to_string(),
            author: "天蚕土豆".to_string(),
            matches: Vec::new(),
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("斗破苍穹"));
        assert!(json.contains("天蚕土豆"));
    }

    /// 留项#12（Task #131）：传 URL 列表时仅搜指定源
    /// Task #145：先清空 searchGroup config，避免分组过滤干扰本用例
    #[test]
    fn test_resolve_switch_sources_url_filter() {
        let _db_guard = crate::db_state::ensure_test_db();
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");
        crate::api::config_api::set_config("searchGroup", "").expect("清空 searchGroup 失败");

        let all = source_api::list_enabled_sources().expect("列出启用书源失败");
        assert!(!all.is_empty(), "测试夹具应含启用书源");

        // 取首个启用源 URL，仅搜该源
        let target = all[0].book_source_url.clone();
        let urls_json = serde_json::to_string(&vec![target.clone()]).unwrap();
        let filtered = resolve_switch_sources(&urls_json).expect("URL 列表解析失败");
        assert_eq!(filtered.len(), 1, "传 URL 列表应只搜指定源");
        assert_eq!(filtered[0].book_source_url, target);
    }

    /// 留项#12（Task #131）：空参数（空串/空数组）搜全部启用源
    /// Task #145：先清空 searchGroup config，避免分组过滤干扰本用例
    #[test]
    fn test_resolve_switch_sources_empty_means_all() {
        let _db_guard = crate::db_state::ensure_test_db();
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");
        crate::api::config_api::set_config("searchGroup", "").expect("清空 searchGroup 失败");

        let enabled = source_api::list_enabled_sources().expect("列出启用书源失败");
        let from_empty_str = resolve_switch_sources("").expect("空串解析失败");
        let from_empty_array = resolve_switch_sources("[]").expect("空数组解析失败");
        assert_eq!(from_empty_str.len(), enabled.len(), "空串应搜全部启用源");
        assert_eq!(
            from_empty_array.len(),
            enabled.len(),
            "空数组应搜全部启用源"
        );
    }

    #[test]
    fn test_resolve_switch_options_from_json_and_config() {
        let _db_guard = crate::db_state::ensure_test_db();
        let json = r#"{"loadInfo":true,"loadToc":false,"loadWordCount":true}"#;
        let opts = resolve_switch_options(json);
        assert!(opts.load_info);
        assert!(!opts.load_toc);
        assert!(opts.load_word_count);

        crate::api::config_api::set_config("changeSourceLoadInfo", "false").unwrap();
        crate::api::config_api::set_config("changeSourceLoadToc", "true").unwrap();
        crate::api::config_api::set_config("changeSourceLoadWordCount", "false").unwrap();
        let from_config = resolve_switch_options("");
        assert!(!from_config.load_info);
        assert!(from_config.load_toc);
        assert!(!from_config.load_word_count);
    }

    /// Task #145（留项#12）：多组包含匹配——分组字段含多组的源按目标组命中
    #[test]
    fn test_resolve_switch_sources_group_membership() {
        use crate::db_state::with_database;
        use legado_db::BookSourceRepository;
        use legado_db::repository::Repository;

        let _db_guard = crate::db_state::ensure_test_db();
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");

        // 给首个启用源打上多组标记（逗号分隔，第二个组名为目标组）
        let all = source_api::list_enabled_sources().expect("列出启用书源失败");
        assert!(!all.is_empty(), "测试夹具应含启用书源");
        let target_url = all[0].book_source_url.clone();
        with_database(|db| {
            let repo = BookSourceRepository::new(db.connection());
            let mut src = repo
                .find_by_url(&target_url)?
                .ok_or_else(|| legado_core::LegadoError::Database("测试源不存在".into()))?;
            src.book_source_group = Some("Task145组A, Task145组B".to_string());
            repo.update(&src)
        })
        .expect("更新测试源分组失败");

        // searchGroup 指向第二个组（含前导空格组名，验证 trim 匹配）
        crate::api::config_api::set_config("searchGroup", "Task145组B")
            .expect("设置 searchGroup 失败");
        let filtered = resolve_switch_sources("").expect("分组过滤解析失败");
        assert_eq!(filtered.len(), 1, "应仅保留含目标分组的源");
        assert_eq!(filtered[0].book_source_url, target_url);

        // 收尾：清空分组 config，避免污染后续共享库用例
        crate::api::config_api::set_config("searchGroup", "").expect("清空 searchGroup 失败");
    }

    /// Task #145（留项#12）：空分组 config（空串/纯空白）= 全部启用源
    #[test]
    fn test_resolve_switch_sources_blank_group_means_all() {
        let _db_guard = crate::db_state::ensure_test_db();
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");

        let enabled = source_api::list_enabled_sources().expect("列出启用书源失败");
        crate::api::config_api::set_config("searchGroup", "   ").expect("设置 searchGroup 失败");
        let filtered = resolve_switch_sources("[]").expect("分组过滤解析失败");
        assert_eq!(filtered.len(), enabled.len(), "纯空白分组应等同全部分组");
        crate::api::config_api::set_config("searchGroup", "").expect("清空 searchGroup 失败");
    }

    /// Task #145（留项#12）：过滤后零结果——目标分组无任何源时返回空列表
    /// （UI 侧据此弹「分组搜索结果为空，是否切换到全部分组」对话框）
    #[test]
    fn test_resolve_switch_sources_group_no_match() {
        let _db_guard = crate::db_state::ensure_test_db();
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");

        crate::api::config_api::set_config("searchGroup", "Task145不存在的分组")
            .expect("设置 searchGroup 失败");
        let filtered = resolve_switch_sources("").expect("分组过滤解析失败");
        assert!(filtered.is_empty(), "目标分组无源时应返回空列表");
        crate::api::config_api::set_config("searchGroup", "").expect("清空 searchGroup 失败");
    }

    /// Task #16 P0：换源保持 bookUrl 稳定——不产生僵尸记录且旧章节/旧缓存被清理
    ///
    /// `switch_book_source` 的网络抓取部分（get_chapters）需真实网络，见下方
    /// `#[ignore]` 集成测试；本用例在 DB 层确定性验证修复后的契约：
    /// 仅更新书源字段且 **bookUrl 保持不变** 时 `BookRepository::update` 命中原行
    /// （不会因 WHERE 落空而 insert 出新 new_book_url 僵尸行），且旧章节与旧缓存
    /// 可经 `delete_by_book_url`/`delete_by_book` 清理干净。
    #[test]
    fn test_switch_keeps_book_url_stable_no_zombie() {
        use crate::db_state::with_database;
        use legado_core::cache_book::CachedChapter;
        use legado_core::models::{Book, BookChapter};
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, CacheBookRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://task16-old-src.example.com/book/1";
        let new_url = "https://task16-new-src.example.com/book/1";

        // 初始数据：旧源书籍 + 旧章节 + 旧缓存正文
        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            let book = Book {
                book_url: old_url.to_string(),
                origin: "https://task16-old-src.example.com".to_string(),
                origin_name: "旧源".to_string(),
                ..Book::default()
            };
            repo.insert(&book)?;

            let chapter_repo = BookChapterRepository::new(db.connection());
            chapter_repo.insert_batch(&[BookChapter {
                url: format!("{old_url}/ch0"),
                title: "旧章节".to_string(),
                base_url: old_url.to_string(),
                book_url: old_url.to_string(),
                index: 0,
                ..BookChapter::default()
            }])?;

            let cache_repo = CacheBookRepository::new(db.connection());
            cache_repo.insert(&CachedChapter {
                id: 0,
                book_url: old_url.to_string(),
                chapter_index: 0,
                chapter_title: "旧章节".to_string(),
                chapter_url: format!("{old_url}/ch0"),
                content: "旧源正文".to_string(),
                cached_at: 1,
                size_bytes: 9,
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 复现 switch_book_source 的 DB 部分：仅改书源字段，bookUrl 保持稳定，然后清旧章节+缓存
        // [B-7] 与换源事务同款：删旧章节须包事务（delete_by_book_url 事务外为 no-op）
        with_database(|db| {
            let conn = db.connection();
            let tx = conn.unchecked_transaction().map_err(|e| {
                legado_core::LegadoError::Database(format!("开启换源测试事务失败: {e}"))
            })?;
            let repo = BookRepository::new(conn);
            let mut book = repo.find_by_url(old_url)?.expect("书籍应存在");
            book.origin = "https://task16-new-src.example.com".to_string();
            book.origin_name = "新源".to_string();
            book.toc_url = new_url.to_string();
            repo.update(&book)?; // WHERE bookUrl=old_url 命中原行

            let cache_repo = CacheBookRepository::new(conn);
            cache_repo.delete_by_book(old_url)?;
            let chapter_repo = BookChapterRepository::new(conn);
            chapter_repo.delete_by_book_url(old_url)?;
            tx.commit().map_err(|e| {
                legado_core::LegadoError::Database(format!("提交换源测试事务失败: {e}"))
            })?;
            Ok(())
        })
        .expect("换源 DB 更新失败");

        // 断言：原 bookUrl 仍在且已换源；无 new_url 僵尸记录；旧章节/旧缓存已清
        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            let updated = repo.find_by_url(old_url)?.expect("原 bookUrl 记录应仍存在");
            assert_eq!(updated.origin, "https://task16-new-src.example.com");
            assert_eq!(updated.origin_name, "新源");
            assert_eq!(updated.toc_url, new_url);
            assert!(
                repo.find_by_url(new_url)?.is_none(),
                "不应出现 new_book_url 僵尸记录"
            );

            let chapter_repo = BookChapterRepository::new(db.connection());
            assert_eq!(
                chapter_repo.count_by_book_url(old_url)?,
                0,
                "旧章节应被清理"
            );
            let cache_repo = CacheBookRepository::new(db.connection());
            assert!(
                cache_repo.get_by_book(old_url)?.is_empty(),
                "旧缓存正文应被清理"
            );
            Ok(())
        })
        .expect("断言查询失败");

        // 收尾：删除本用例书籍，避免污染共享测试库
        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.delete(old_url)
        })
        .ok();
    }

    // ─── [T2 | ChangeBookSourceViewModel.kt:718-731] 换源执行链 mock 单测 ─────

    /// 换源链 mock：详情/目录按序注入，记录 get_chapters 实际收到的 URL
    struct SwitchMockFetcher {
        info: LegadoResult<legado_core::web_book::WebBookInfo>,
        chapters: LegadoResult<Vec<WebChapter>>,
        /// 记录每次 get_chapters 调用的 book_url 入参
        chapters_requested: std::sync::Mutex<Vec<String>>,
        /// [R1 变量链] 记录每次详情请求收到的变量表
        detail_vars_requested: std::sync::Mutex<Vec<std::collections::HashMap<String, String>>>,
        /// [R1 变量链] 记录每次目录请求收到的变量表
        toc_vars_requested: std::sync::Mutex<Vec<std::collections::HashMap<String, String>>>,
    }

    impl BookSourceFetcher for SwitchMockFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<legado_core::web_book::WebBookInfo> {
            self.get_book_info_with_existing(_source, _book_url, true, "", "")
                .await
        }

        async fn get_book_info_with_existing(
            &self,
            _source: &BookSource,
            _book_url: &str,
            can_re_name: bool,
            existing_name: &str,
            existing_author: &str,
        ) -> LegadoResult<legado_core::web_book::WebBookInfo> {
            // 模拟 Real fetcher parse 的 B2.1 重命名门控：can_re_name=false 且
            // 既有值非空时保留既有书名/作者
            match &self.info {
                Ok(info) => {
                    let mut info = info.clone();
                    if !can_re_name && !existing_name.is_empty() {
                        info.name = existing_name.to_string();
                    }
                    if !can_re_name && !existing_author.is_empty() {
                        info.author = existing_author.to_string();
                    }
                    Ok(info)
                }
                Err(e) => Err(LegadoError::Internal(e.to_string())),
            }
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            self.chapters_requested
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(book_url.to_string());
            match &self.chapters {
                Ok(list) => Ok(list.clone()),
                Err(e) => Err(LegadoError::Internal(e.to_string())),
            }
        }

        /// [R1 变量链] 记录详情请求变量表后委托既有门控行为
        async fn get_book_info_with_existing_and_vars(
            &self,
            source: &BookSource,
            book_url: &str,
            can_re_name: bool,
            existing_name: &str,
            existing_author: &str,
            variables: &std::collections::HashMap<String, String>,
        ) -> LegadoResult<legado_core::web_book::WebBookInfo> {
            self.detail_vars_requested
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(variables.clone());
            self.get_book_info_with_existing(
                source,
                book_url,
                can_re_name,
                existing_name,
                existing_author,
            )
            .await
        }

        /// [R1 变量链] 记录目录请求变量表后委托既有行为
        async fn get_chapters_with_vars(
            &self,
            source: &BookSource,
            toc_url: &str,
            variables: &std::collections::HashMap<String, String>,
        ) -> LegadoResult<Vec<WebChapter>> {
            self.toc_vars_requested
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(variables.clone());
            self.get_chapters(source, toc_url).await
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }
    }

    /// T2 主路径：详情解析出的 tocUrl（目录页≠详情页）用于取目录并落库；
    /// 书名/作者保留既有值（canReName=false）；章节 variable/is_volume 保留解析值
    #[test]
    fn test_switch_uses_parsed_toc_url_and_preserves_parsed_values() {
        // 调 switch_book_source_with（换源执行链内含 begin_book_flow 切
        // flow scope，JS 解析可写全局表）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_core::web_book::WebBookInfo;
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://t2-old.example.com/book/1";
        let new_source = "https://t2-new.example.com";
        let new_detail = "https://t2-new.example.com/book/1";
        let new_toc = "https://t2-new.example.com/book/1/chapters";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://t2-old.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "旧源书名".to_string(),
                author: "旧作者".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "新源".to_string(),
                ..BookSource::default()
            })?;
            // [T5] 搜索期候选行（searchBooks），携带搜索期级联变量
            legado_db::SearchBookRepository::new(db.connection()).insert(
                &legado_core::models::SearchBook {
                    book_url: new_detail.to_string(),
                    origin: new_source.to_string(),
                    origin_name: "新源".to_string(),
                    name: "旧源书名".to_string(),
                    toc_url: new_detail.to_string(),
                    variable: Some(r#"{"token":"c456","sid":"s1"}"#.to_string()),
                    ..Default::default()
                },
            )?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let mock = SwitchMockFetcher {
            info: Ok(WebBookInfo {
                name: "新源解析名".to_string(),
                author: "新源解析作者".to_string(),
                cover_url: Some("https://t2-new.example.com/cover.jpg".to_string()),
                intro: Some("新简介".to_string()),
                categories: vec![],
                last_chapter: Some("大结局".to_string()),
                // [T5] 详情页导出变量（@put 级联）：token 覆盖候选值
                variable: Some(r#"{"token":"d123"}"#.to_string()),
                book_url: new_detail.to_string(),
                toc_url: new_toc.to_string(),
                word_count: Some("123456".to_string()),
                kind: Some("玄幻".to_string()),
                book_type: 0,
            }),
            chapters: Ok(vec![WebChapter {
                index: 0,
                title: "第一卷 第一章".to_string(),
                url: format!("{new_toc}/c1"),
                is_vip: false,
                is_volume: true,
                variable: Some(r#"{"token":"abc123"}"#.to_string()),
                word_count: None,
            }]),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp =
            switch_book_source_with(&mock, old_url, new_source, new_detail).expect("换源应成功");
        let book: Book = serde_json::from_str(&resp).unwrap();

        // 2a/2b：取目录用的是详情解析出的 toc_url，而非详情页 URL
        assert_eq!(
            mock.chapters_requested.lock().unwrap().as_slice(),
            [new_toc],
            "get_chapters 应收到解析后的目录页 URL"
        );
        assert_eq!(book.toc_url, new_toc, "toc_url 应为解析后目录页");
        // canReName=false：保留既有书名/作者；其余字段按解析值更新
        assert_eq!(book.name, "旧源书名");
        assert_eq!(book.author, "旧作者");
        assert_eq!(book.origin, new_source);
        // [目录派生字段同步] 目录成功后 latestChapterTitle 以目录末章为准
        // （对齐上游：详情写在目录写之前，目录写胜出——详情「大结局」被覆盖）；
        // totalChapterNum = 落库章节数
        assert_eq!(
            book.latest_chapter_title.as_deref(),
            Some("第一卷 第一章"),
            "latestChapterTitle 应为目录末章标题（覆盖详情 lastChapter 值）"
        );
        assert_eq!(book.total_chapter_num, 1, "totalChapterNum 应为落库章节数");
        // [T5] book.variable = 候选变量 ⊕ 详情导出变量（详情页后写入者优先），
        // 旧源旧值不再残留（R1）
        let book_var: serde_json::Value =
            serde_json::from_str(book.variable.as_deref().expect("book.variable 应有值")).unwrap();
        assert_eq!(book_var["token"], serde_json::json!("d123"));
        assert_eq!(book_var["sid"], serde_json::json!("s1"));
        // [R1 变量链 2026-09-06] 详情请求变量表=候选搜索期变量（对齐原版
        // getBookInfoAwait ruleData=book）；目录请求变量表=候选⊕详情导出合并值
        assert_eq!(
            mock.detail_vars_requested.lock().unwrap().as_slice(),
            [std::collections::HashMap::from([
                ("token".to_string(), "c456".to_string()),
                ("sid".to_string(), "s1".to_string()),
            ])],
            "详情请求应携带候选搜索期变量"
        );
        assert_eq!(
            mock.toc_vars_requested.lock().unwrap().as_slice(),
            [std::collections::HashMap::from([
                ("token".to_string(), "d123".to_string()),
                ("sid".to_string(), "s1".to_string()),
            ])],
            "目录请求应携带候选⊕详情导出合并变量（详情页优先）"
        );

        // T1：章节 variable/is_volume 保留解析值
        with_database(|db| {
            let repo = BookChapterRepository::new(db.connection());
            let chapters = repo.find_by_book_url(old_url).expect("章节查询失败");
            assert_eq!(chapters.len(), 1);
            assert_eq!(
                chapters[0].variable.as_deref(),
                Some(r#"{"token":"abc123"}"#)
            );
            assert!(chapters[0].is_volume, "卷章标记应保留解析值");
            Ok(())
        })
        .expect("章节断言失败");

        // 收尾清理
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            let _ = legado_db::SearchBookRepository::new(db.connection())
                .delete_by_book_url(new_detail);
            Ok(())
        })
        .ok();
    }

    /// [目录派生字段同步] 换源（现场抓取通道）后 totalChapterNum/latestChapterTitle
    /// 必须按**新目录**同步：播种陈旧派生字段（999 章/「旧源最新章节」），新目录
    /// 5 章（末章「第4章」）→ 提交后两字段 == 新目录值（返回 JSON + DB 双断言），
    /// 且与同事务落库的 bookChapters 行数一致（DB 内部一致性）。
    /// 红态（修复前）：commit_source_switch 从 total_chapter_num 取值，全行
    /// `update` 把抓取前快照的旧值原样写回（999/「旧源最新章节」）；
    /// latestChapterTitle 只取详情 lastChapter（B-13），目录末章被忽略。
    /// 语义对齐上游 updateBookTocInfo：目录成功后 total=目录章数、
    /// latest=目录末章标题（详情值被目录写覆盖——上游目录写在详情写之后）。
    #[test]
    fn test_source_switch_syncs_toc_derived_fields() {
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_core::web_book::WebBookInfo;
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://sw-sync-old.example.com/book/1";
        let new_source = "https://sw-sync-new.example.com";
        let new_detail = "https://sw-sync-new.example.com/book/1";
        let new_toc = "https://sw-sync-new.example.com/book/1/chapters";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://sw-sync-old-src.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                // 红态播种：陈旧的目录派生字段（换源前旧源值）
                total_chapter_num: 999,
                latest_chapter_title: Some("旧源最新章节".to_string()),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "新源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 新目录 5 章：第0章..第4章（末章标题 = 第4章）
        let mock = SwitchMockFetcher {
            info: Ok(WebBookInfo {
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                cover_url: None,
                intro: None,
                categories: vec![],
                // 详情 lastChapter 值不得胜出：目录成功后由目录末章覆盖
                // （对齐上游：详情写在目录写之前，目录写胜出）
                last_chapter: Some("详情末章".to_string()),
                variable: None,
                book_url: new_detail.to_string(),
                toc_url: new_toc.to_string(),
                word_count: None,
                kind: None,
                book_type: 0,
            }),
            chapters: Ok(test_web_chapters(5, new_toc)),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp =
            switch_book_source_with(&mock, old_url, new_source, new_detail).expect("换源应成功");
        let book: Book = serde_json::from_str(&resp).unwrap();

        assert_eq!(
            book.total_chapter_num, 5,
            "totalChapterNum 应为新目录章数（不得写回抓取前快照旧值 999）"
        );
        assert_eq!(
            book.latest_chapter_title.as_deref(),
            Some("第4章"),
            "latestChapterTitle 应为新目录末章标题（覆盖详情值/旧值）"
        );

        // DB 终态：派生字段与目录行数同事务一致
        with_database(|db| {
            let persisted = BookRepository::new(db.connection())
                .find_by_url(old_url)?
                .expect("书籍记录应仍存在");
            assert_eq!(
                persisted.total_chapter_num, 5,
                "DB totalChapterNum 应为新目录章数"
            );
            assert_eq!(
                persisted.latest_chapter_title.as_deref(),
                Some("第4章"),
                "DB latestChapterTitle 应为新目录末章标题"
            );
            let chapters = BookChapterRepository::new(db.connection()).find_by_book_url(old_url)?;
            assert_eq!(
                chapters.len() as i32,
                persisted.total_chapter_num,
                "DB 内部一致性：totalChapterNum == 落库章节数"
            );
            Ok(())
        })
        .expect("DB 断言失败");

        // 收尾清理
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// [P2-15 剩项②] `yield_stale_overlay_to_db` 规则矩阵（纯函数，不触 DB）：
    /// - overlay 键域内键 + DB 有同名不同值 → 让位 DB 值；
    /// - DB 值与合并值相等 → 不动（零副作用）；
    /// - DB 无该键 → 原样直通；
    /// - 键在候选搜索行 → 绝不让位（T5 候选优先不变）；
    /// - overlay 键域为空 → 原样直通；
    /// - merged None → None；merged / 输入非法 JSON → 降级直通（不阻断换源）。
    #[test]
    fn test_p215_yield_stale_overlay_to_db_rule_matrix() {
        let overlay = std::collections::HashMap::from([
            ("custom".to_string(), "stale-overlay".to_string()),
            ("page".to_string(), "stale-page".to_string()),
        ]);

        // ① 让位：DB 同名不同值 → 用 DB 值；非 overlay 键不动
        let out = yield_stale_overlay_to_db(
            Some(r#"{"custom":"stale-overlay","detail":"d"}"#),
            Some(r#"{"custom":"db-value"}"#),
            None,
            &overlay,
        )
        .expect("merged 为 JSON 对象应可产出");
        let v: serde_json::Value = serde_json::from_str(&out).expect("输出应为 JSON");
        assert_eq!(
            v["custom"],
            serde_json::json!("db-value"),
            "DB 持久权威值应覆盖陈旧 overlay"
        );
        assert_eq!(v["detail"], serde_json::json!("d"), "非 overlay 键不动");

        // ② DB 值与合并值相等 → 不动（输出与输入语义相等）
        let out = yield_stale_overlay_to_db(
            Some(r#"{"custom":"db-value"}"#),
            Some(r#"{"custom":"db-value"}"#),
            None,
            &overlay,
        )
        .expect("merged 为 JSON 对象应可产出");
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&out).unwrap()["custom"],
            serde_json::json!("db-value")
        );

        // ③ DB 无该键 → overlay 值原样保留
        assert_eq!(
            yield_stale_overlay_to_db(
                Some(r#"{"custom":"stale-overlay"}"#),
                Some(r#"{"other":"o"}"#),
                None,
                &overlay,
            ),
            Some(r#"{"custom":"stale-overlay"}"#.to_string()),
            "DB 无同名键 → 不动"
        );

        // ④ 键在候选搜索行 → 绝不让位（即使 DB 值不同）
        let out = yield_stale_overlay_to_db(
            Some(r#"{"custom":"stale-overlay"}"#),
            Some(r#"{"custom":"db-value"}"#),
            Some(r#"{"custom":"cand"}"#),
            &overlay,
        )
        .expect("merged 为 JSON 对象应可产出");
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&out).unwrap()["custom"],
            serde_json::json!("stale-overlay"),
            "候选携带键绝不让位（T5 候选优先）"
        );

        // ⑤ overlay 键域为空 → 原样直通
        assert_eq!(
            yield_stale_overlay_to_db(
                Some(r#"{"custom":"stale-overlay"}"#),
                Some(r#"{"custom":"db-value"}"#),
                None,
                &std::collections::HashMap::new(),
            ),
            Some(r#"{"custom":"stale-overlay"}"#.to_string()),
            "空 overlay 键域 → 直通"
        );

        // ⑥ merged None → None
        assert_eq!(
            yield_stale_overlay_to_db(None, Some(r#"{"custom":"db-value"}"#), None, &overlay),
            None,
            "merged None → None"
        );

        // ⑦ merged 非 JSON 对象 → 降级原样返回（不阻断换源）
        assert_eq!(
            yield_stale_overlay_to_db(
                Some("not-json"),
                Some(r#"{"custom":"db-value"}"#),
                None,
                &overlay,
            ),
            Some("not-json".to_string()),
            "非 JSON merged 降级直通"
        );

        // ⑧ DB / 候选非法 JSON → 降级不让位
        assert_eq!(
            yield_stale_overlay_to_db(
                Some(r#"{"custom":"stale-overlay"}"#),
                Some("not-json"),
                Some("not-json"),
                &overlay,
            ),
            Some(r#"{"custom":"stale-overlay"}"#.to_string()),
            "非法 JSON 输入降级为不让位"
        );
    }

    /// [P2-15 剩项②] 换源端到端：本进程 JS 写路径残留 overlay（bookVar 层
    /// 预置 `custom=stale-overlay`，流程级不清——P2-15 剩项① 的 bookVar
    /// 进程级保留语义）+ DB `books.variable` 已有同名不同值（持久权威）
    /// 且候选搜索行未携带该键 → 换源后 `book.variable` 取 DB 值（陈旧
    /// overlay 让位）；DB 非 overlay 键域内的键（`keep`）不并入结果
    /// （让位仅针对 overlay 键域，非通用 DB 合并）。
    ///
    /// 与 web_book 的 flow-scope 相关测试持有同一把
    /// `GLOBAL_STORE_TEST_LOCK`（换源执行链内含 `begin_book_flow` 切
    /// scope，并行清 scope 会互串），串行执行。
    #[test]
    fn test_p215_switch_yields_stale_overlay_to_db_variable() {
        use crate::db_state::{ensure_test_db, with_database};
        use legado_core::models::{Book, BookSource};
        use legado_core::web_book::{WebBookInfo, WebChapter};
        use legado_db::repository::Repository;
        use legado_db::{BookRepository, BookSourceRepository};

        let _lock = crate::test_support::lock_global_store();
        let _db_guard = ensure_test_db();
        let old_url = "https://p215-yield.example.com/book/1";
        let new_source = "https://p215-yield.example.com/new";
        let new_detail = "https://p215-yield.example.com/book/1";

        // DB 预置：books.variable 已有 custom（持久权威值：用户编辑/既有落库）
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://p215-yield.example.com/old".to_string(),
                origin_name: "旧源".to_string(),
                name: "让位测试书".to_string(),
                author: "作者".to_string(),
                variable: Some(r#"{"custom":"db-value","keep":"k"}"#.to_string()),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "新源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 预置本进程 JS 写路径残留 overlay（bookVar 持久裸层键）
        let resources = crate::engine_holder::js_resources().for_book(new_source, new_detail);
        resources
            .variable_scope()
            .unwrap()
            .set_book_variable(new_detail, "custom", "stale-overlay")
            .expect("预置同来源书籍覆盖");

        // Mock 详情导出：模拟 parse_book_info_from_body 的
        // 「详情 @put 导出 ⊕ overlay」合并结果（custom 来自 overlay 并入）
        let mock = SwitchMockFetcher {
            info: Ok(WebBookInfo {
                name: "让位测试书".to_string(),
                author: "作者".to_string(),
                cover_url: None,
                intro: None,
                categories: vec![],
                last_chapter: None,
                variable: Some(r#"{"detail_key":"d","custom":"stale-overlay"}"#.to_string()),
                book_url: new_detail.to_string(),
                toc_url: new_detail.to_string(),
                word_count: None,
                kind: None,
                book_type: 0,
            }),
            chapters: Ok(vec![WebChapter {
                index: 0,
                title: "第一章".to_string(),
                url: format!("{new_detail}/c1"),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            }]),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp =
            switch_book_source_with(&mock, old_url, new_source, new_detail).expect("换源应成功");
        let book: Book = serde_json::from_str(&resp).expect("换源返回应可解析");
        let book_var: serde_json::Value =
            serde_json::from_str(book.variable.as_deref().expect("book.variable 应有值")).unwrap();
        assert_eq!(
            book_var["custom"],
            serde_json::json!("db-value"),
            "陈旧 overlay 应让位给 DB 持久权威值"
        );
        assert_eq!(
            book_var["detail_key"],
            serde_json::json!("d"),
            "详情导出键不动"
        );
        assert!(
            book_var.get("keep").is_none(),
            "DB 非 overlay 键域内的键不并入（让位非通用 DB 合并）"
        );

        // 收尾：清 bookVar 键 + 复位 flow scope（换源链已切至 new_detail）
        resources
            .variable_scope()
            .unwrap()
            .remove_book_variable(new_detail, "custom")
            .unwrap();
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// [R1 变量链 2026-09-06] persist_switch_matches 落库必须携带候选搜索期变量：
    /// switch_book_source 按 (new_book_url, origin) 回查 searchBooks 取候选变量
    /// （对齐原版 SearchBook.toBook() 复制 variable），此前 `..SearchBook::default()`
    /// 丢字段导致网络/读库两条路径的候选变量双双丢失。
    #[test]
    fn test_persist_switch_matches_keeps_candidate_variable() {
        use crate::db_state::with_database;
        use legado_core::source_matcher::SourceMatch;

        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://r1-persist.example.com/book/1";
        let origin = "https://r1-persist.example.com";

        // searchBooks.origin 外键引用 book_sources，须先建源
        with_database(|db| {
            use legado_core::models::BookSource;
            use legado_db::repository::Repository;
            legado_db::BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: origin.to_string(),
                book_source_name: "变量源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("建源失败");

        persist_switch_matches(&[SourceMatch {
            source_url: origin.to_string(),
            source_name: "变量源".to_string(),
            book_url: book_url.to_string(),
            book_name: "变量书".to_string(),
            author: "作者".to_string(),
            latest_chapter: None,
            word_count: None,
            score: 100.0,
            chapter_word_count_text: None,
            chapter_word_count: -1,
            respond_time: -1,
            origin_order: 0,
            book_score: 0,
            variable: Some(r#"{"token":"tk-1"}"#.to_string()),
        }]);

        let row = with_database(|db| {
            legado_db::SearchBookRepository::new(db.connection()).find_by_book_url(book_url)
        })
        .expect("查询失败")
        .expect("searchBooks 行应存在");
        assert_eq!(
            row.variable.as_deref(),
            Some(r#"{"token":"tk-1"}"#),
            "落库行必须保留候选搜索期变量"
        );
        assert_eq!(row.origin, origin, "switch 回查需按 origin 匹配候选");

        // 收尾清理，避免污染共享测试库
        with_database(|db| {
            let _ =
                legado_db::SearchBookRepository::new(db.connection()).delete_by_book_url(book_url);
            Ok(())
        })
        .ok();
    }

    /// T2 失败语义：详情解析失败 → 整个换源失败，旧源/旧目录/旧章节原样保留
    #[test]
    fn test_switch_fails_and_keeps_old_source_when_info_fails() {
        // 调 switch_book_source_with（换源执行链内含 begin_book_flow 切
        // flow scope）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://t2f-old.example.com/book/1";
        let new_source = "https://t2f-new.example.com";
        let new_detail = "https://t2f-new.example.com/book/1";

        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://t2f-old.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "旧源书名".to_string(),
                toc_url: "https://t2f-old.example.com/toc".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "新源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let mock = SwitchMockFetcher {
            info: Err(LegadoError::Internal("详情页 403".into())),
            chapters: Ok(vec![WebChapter {
                index: 0,
                title: "不应被使用".to_string(),
                url: "https://t2f-new.example.com/c1".to_string(),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            }]),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let err = switch_book_source_with(&mock, old_url, new_source, new_detail)
            .expect_err("详情失败应导致换源失败");
        assert!(err.to_string().contains("新源"), "错误应含书源名: {err}");
        assert!(
            mock.chapters_requested.lock().unwrap().is_empty(),
            "详情失败后不得再用 new_book_url 硬闯目录"
        );

        // 旧源/旧目录/旧章节原样保留（单事务未提交）
        with_database(|db| {
            let book = BookRepository::new(db.connection())
                .find_by_url(old_url)?
                .expect("书籍应存在");
            assert_eq!(book.origin, "https://t2f-old.example.com");
            assert_eq!(book.toc_url, "https://t2f-old.example.com/toc");
            assert_eq!(
                BookChapterRepository::new(db.connection()).count_by_book_url(old_url)?,
                0
            );
            Ok(())
        })
        .expect("保留旧源断言失败");

        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// [P2-8] 换源根因修复：换源事务必须写入当前书源详情页地址
    /// （originBookUrl = new_book_url），且 bookUrl（稳定主键）保持不变；
    /// 旧书（originBookUrl 为空，存量库）换源同样成功（向后兼容）。
    /// 同时验证「按新字段抓详情」链路：详情解析出的真实 tocUrl 用于取目录。
    #[test]
    fn test_switch_writes_origin_book_url_and_keeps_book_url_stable() {
        // 调 switch_book_source_with（换源执行链内含 begin_book_flow 切
        // flow scope）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_core::web_book::WebBookInfo;
        use legado_db::repository::Repository;
        use legado_db::{BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://p8-old.example.com/book/1";
        let new_source = "https://p8-new.example.com";
        let new_detail = "https://p8-new.example.com/book/9";
        let new_toc = "https://p8-new.example.com/book/9/chapters";

        with_database(|db| {
            // 存量书：originBookUrl 为空（未换源 / 迁移前旧库形态）
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://p8-old.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "书名".to_string(),
                author: "作者".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "新源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let mock = SwitchMockFetcher {
            info: Ok(WebBookInfo {
                name: "书名".to_string(),
                author: "作者".to_string(),
                cover_url: None,
                intro: None,
                categories: vec![],
                last_chapter: None,
                variable: None,
                book_url: new_detail.to_string(),
                // 目录页≠详情页：详情解析出的真实 tocUrl 必须被采用
                toc_url: new_toc.to_string(),
                word_count: None,
                kind: None,
                book_type: 0,
            }),
            chapters: Ok(vec![WebChapter {
                index: 0,
                title: "第一章".to_string(),
                url: format!("{new_toc}/c1"),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            }]),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp = switch_book_source_with(&mock, old_url, new_source, new_detail)
            .expect("存量书（originBookUrl 为空）换源应成功");
        let book: Book = serde_json::from_str(&resp).unwrap();
        assert_eq!(book.book_url, old_url, "bookUrl 必须保持稳定主键不变");
        assert_eq!(
            book.origin_book_url, new_detail,
            "换源后必须写入当前书源详情页地址 originBookUrl"
        );
        // 详情按 new_book_url 抓取并解析出真实 tocUrl，目录抓取用该 tocUrl
        assert_eq!(book.toc_url, new_toc, "tocUrl 应为详情解析出的目录页");
        assert_eq!(
            mock.chapters_requested.lock().unwrap().as_slice(),
            [new_toc],
            "取目录应使用详情解析出的 tocUrl，而非详情页/旧 bookUrl"
        );

        // DB 行持久值与返回值一致
        with_database(|db| {
            let persisted = BookRepository::new(db.connection())
                .find_by_url(old_url)?
                .expect("原 bookUrl 记录应仍存在");
            assert_eq!(persisted.book_url, old_url);
            assert_eq!(
                persisted.origin_book_url, new_detail,
                "DB 落库 originBookUrl 必须等于新源详情页地址"
            );
            assert_eq!(persisted.origin, new_source);
            assert!(
                BookRepository::new(db.connection())
                    .find_by_url(new_detail)?
                    .is_none(),
                "不应出现 new_book_url 僵尸记录"
            );
            Ok(())
        })
        .expect("DB 断言失败");

        // 收尾清理
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// [P2-8] 回归网：连续两次换源均成功——第二次换源时 DB 行 originBookUrl
    /// 已非空（第一次写入），执行链仍按稳定主键 bookUrl 命中并更新
    /// originBookUrl 为第二源的详情页地址，不产生僵尸记录、不丢章节。
    #[test]
    fn test_two_consecutive_switches_both_succeed() {
        // 连续两次 switch_book_source_with（换源执行链内含 begin_book_flow
        // 切 flow scope）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_core::web_book::WebBookInfo;
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://p8-2x.example.com/book/1";
        let src_a = "https://p8-2x-a.example.com";
        let detail_a = "https://p8-2x-a.example.com/book/7";
        let src_b = "https://p8-2x-b.example.com";
        let detail_b = "https://p8-2x-b.example.com/book/8";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://p8-2x-origin.example.com".to_string(),
                origin_name: "原源".to_string(),
                name: "书名".to_string(),
                author: "作者".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: src_a.to_string(),
                book_source_name: "源A".to_string(),
                ..BookSource::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: src_b.to_string(),
                book_source_name: "源B".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        fn switch_mock(detail: &str) -> SwitchMockFetcher {
            SwitchMockFetcher {
                info: Ok(WebBookInfo {
                    name: "书名".to_string(),
                    author: "作者".to_string(),
                    cover_url: None,
                    intro: None,
                    categories: vec![],
                    last_chapter: None,
                    variable: None,
                    book_url: detail.to_string(),
                    toc_url: String::new(),
                    word_count: None,
                    kind: None,
                    book_type: 0,
                }),
                chapters: Ok(vec![WebChapter {
                    index: 0,
                    title: "第一章".to_string(),
                    url: format!("{detail}/c1"),
                    is_vip: false,
                    is_volume: false,
                    variable: None,
                    word_count: None,
                }]),
                chapters_requested: std::sync::Mutex::new(Vec::new()),
                detail_vars_requested: std::sync::Mutex::new(Vec::new()),
                toc_vars_requested: std::sync::Mutex::new(Vec::new()),
            }
        }

        // 第一次换源：存量书（originBookUrl 空）→ 源A
        let mock_a = switch_mock(detail_a);
        let r1 =
            switch_book_source_with(&mock_a, old_url, src_a, detail_a).expect("第一次换源应成功");
        let b1: Book = serde_json::from_str(&r1).unwrap();
        assert_eq!(b1.book_url, old_url, "第一次换源 bookUrl 不变");
        assert_eq!(
            b1.origin_book_url, detail_a,
            "第一次换源 originBookUrl=源A 详情页"
        );

        // 第二次换源：DB 行 originBookUrl 已非空（=detail_a），
        // 执行链仍按稳定主键命中，更新为源B 详情页地址
        let mock_b = switch_mock(detail_b);
        let r2 =
            switch_book_source_with(&mock_b, old_url, src_b, detail_b).expect("第二次换源应成功");
        let b2: Book = serde_json::from_str(&r2).unwrap();
        assert_eq!(b2.book_url, old_url, "第二次换源 bookUrl 仍不变");
        assert_eq!(
            b2.origin_book_url, detail_b,
            "第二次换源 originBookUrl 应刷新为源B 详情页地址"
        );

        // DB 终态：单行、originBookUrl=detail_b、源A/B 详情页地址均无僵尸行、
        // 章节挂在稳定主键下
        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            let final_book = repo.find_by_url(old_url)?.expect("原 bookUrl 记录应仍存在");
            assert_eq!(final_book.origin_book_url, detail_b);
            assert_eq!(final_book.origin, src_b);
            assert!(
                repo.find_by_url(detail_a)?.is_none(),
                "源A 详情页地址不应产生僵尸记录"
            );
            assert!(
                repo.find_by_url(detail_b)?.is_none(),
                "源B 详情页地址不应产生僵尸记录"
            );
            let chapters = BookChapterRepository::new(db.connection()).find_by_book_url(old_url)?;
            assert_eq!(chapters.len(), 1, "第二次换源后章节应挂在稳定主键下");
            assert_eq!(
                chapters[0].book_url, old_url,
                "章节 book_url 必须保持稳定主键"
            );
            Ok(())
        })
        .expect("DB 终态断言失败");

        // 收尾清理
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(src_a);
            let _ = BookSourceRepository::new(db.connection()).delete(src_b);
            Ok(())
        })
        .ok();
    }

    /// [P2-8 P1-1 | 回归固化 2026-09-18] 换源后以**不含 originBookUrl 键**的
    /// Book JSON 调 update_book，DB 内该列不得被清空：`bookshelf::update_book`
    /// 写侧防守（`fill_origin_book_url_if_empty`）必须从库内既有行补齐。
    ///
    /// 触发场景：Dart 侧持有换源前构造的陈旧 Book 内存对象（字段缺失/为空），
    /// 全行 UPDATE 会把缺失键序列化为空串覆盖换源事务写入的详情页地址。
    /// 本测试固化防守行为，防止后续重构把该分支删掉。
    #[test]
    fn test_update_book_missing_origin_book_url_keeps_column() {
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_db::repository::Repository;
        use legado_db::{BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://p1-1-regression.example.com/book/1";
        let source_url = "https://p1-1-regression-src.example.com";
        let origin_detail = "https://p1-1-regression-src.example.com/book/9";

        // 初始：模拟换源事务后的库内状态（originBookUrl 已由换源写入）
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                origin_name: "固化源".to_string(),
                name: "书名".to_string(),
                author: "作者".to_string(),
                origin_book_url: origin_detail.to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: source_url.to_string(),
                book_source_name: "固化源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 完全不含 originBookUrl 键的 Book JSON（Dart 陈旧内存对象形态）
        let book_json = r#"{
            "bookUrl": "https://p1-1-regression.example.com/book/1",
            "name": "书名",
            "author": "作者",
            "type": 0
        }"#;
        crate::api::bookshelf::update_book(book_json).expect("update_book 应成功");

        with_database(|db| {
            let saved = BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .expect("书籍记录应仍存在");
            assert_eq!(
                saved.origin_book_url, origin_detail,
                "入参缺 originBookUrl 时不得清空换源事务写入的列，写侧防守须从库内既有行补齐"
            );
            Ok(())
        })
        .expect("DB 断言失败");

        // 收尾清理，避免污染共享测试库
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(book_url);
            let _ = BookSourceRepository::new(db.connection()).delete(source_url);
            Ok(())
        })
        .ok();
    }

    /// Task #16 P0：换源完整链路集成测试（需真实网络，CI 忽略）
    ///
    /// 验证 switch_book_source 返回的 JSON 中 bookUrl 与传入的原 bookUrl 一致（稳定主键）。
    #[test]
    #[ignore = "requires network access"]
    fn test_switch_book_source_keeps_book_url_in_returned_json() {
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_db::repository::Repository;
        use legado_db::{BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://switch-old.example.com/book/1";
        let new_source = "https://switch-new.example.com";
        let new_book_url = "https://switch-new.example.com/book/1";

        with_database(|db| {
            let brepo = BookRepository::new(db.connection());
            brepo.insert(&Book {
                book_url: old_url.to_string(),
                ..Book::default()
            })?;
            let srepo = BookSourceRepository::new(db.connection());
            srepo.insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "新源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .unwrap();

        let json = switch_book_source(old_url, new_source, new_book_url).unwrap();
        let decoded: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(
            decoded["bookUrl"].as_str(),
            Some(old_url),
            "返回 bookUrl 应保持稳定"
        );
    }

    /// Task #21 回归：换源目标详情页 URL 为空时应提前返回可读错误，
    /// 而非把空 URL 传进解析器抛出令人困惑的 "bookUrl不能为空"。
    ///
    /// 无需数据库或网络；但真实入口先替换宿主 apply 操作槽，再校验 URL。
    /// 必须和其他宿主测试共用隔离锁，否则无效请求也会取消并行换源。
    /// 空串与纯空白均被拦截，且错误不暴露裸 "bookUrl不能为空"。
    #[test]
    fn test_switch_book_source_rejects_empty_new_book_url() {
        let _lock = crate::test_support::lock_global_store();
        for empty in ["", "   ", "\t\n"] {
            let err = switch_book_source(
                "https://any-book.example.com/1",
                "https://any-src.example.com",
                empty,
            )
            .expect_err("空 new_book_url 应返回错误");
            let msg = err.to_string();
            assert!(
                msg.contains("详情页 URL 为空"),
                "错误信息应可读地说明详情页 URL 为空，实际: {msg}"
            );
            assert!(
                !msg.contains("bookUrl不能为空"),
                "不应暴露解析器内部的 bookUrl不能为空，实际: {msg}"
            );
        }
    }

    // ─── [2026-09-24 换源预拉缓存] 缓存/取消/增强 单测 ─────────────────────
    //
    // 全部涉及进程级全局态（FFI 根数据库与宿主操作槽 /
    // TOC 刷新代数 / JS 全局表 flow scope），统一持 crate 级 test_support
    // 锁串行执行（与 web_book / T2 换源链测试同一把锁，防串表）。

    /// 测试辅助：全字段 WebBookInfo（测试书/测试作者，目录页 = 入参）
    fn test_web_info(toc_url: &str) -> WebBookInfo {
        WebBookInfo {
            name: "测试书".to_string(),
            author: "测试作者".to_string(),
            cover_url: None,
            intro: None,
            categories: vec![],
            last_chapter: Some("大结局".to_string()),
            variable: None,
            book_url: String::new(),
            toc_url: toc_url.to_string(),
            word_count: Some("9999".to_string()),
            kind: None,
            book_type: 0,
        }
    }

    /// 测试辅助：n 章（URL 在 base 下，c0..c(n-1)）
    fn test_web_chapters(n: usize, base: &str) -> Vec<WebChapter> {
        (0..n)
            .map(|i| WebChapter {
                index: i as i32,
                title: format!("第{i}章"),
                url: format!("{base}/c{i}"),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            })
            .collect()
    }

    /// 测试辅助：候选（SearchCandidate 无 Default，13 字段全量构造）
    fn mk_candidate(source_url: &str, book_url: &str, book_name: &str) -> SearchCandidate {
        SearchCandidate {
            source_url: source_url.to_string(),
            source_name: "测试源".to_string(),
            book_url: book_url.to_string(),
            book_name: book_name.to_string(),
            author: "测试作者".to_string(),
            latest_chapter: None,
            word_count: None,
            chapter_word_count_text: None,
            chapter_word_count: -1,
            respond_time: -1,
            origin_order: 0,
            book_score: 0,
            variable: None,
        }
    }

    /// 在途取消 mock：目录抓取时调 [`cancel_switch_apply`]（原 apply 取消
    /// 并 bump TOC 刷新代数）再返回 Ok —— 验证预拉缓存版 apply 提交门控
    /// 比对阻断提交（DB 零变更，对齐上游 cancelChangeSource L715-721）
    struct CancelDuringTocFetcher {
        info: WebBookInfo,
        chapters: Vec<WebChapter>,
    }

    impl BookSourceFetcher for CancelDuringTocFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<WebBookInfo> {
            Ok(self.info.clone())
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            // 本用例核心：目录抓取途中取消（上游 cancelChangeSource）
            cancel_switch_apply();
            Ok(self.chapters.clone())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }
    }

    /// 慢目录 mock：get_chapters 睡 300ms 再返回 —— 与
    /// [`enrich_item_with_timeout`]（50ms）配合验证单候选超时 → 原样直通
    /// + 不写缓存（单失败隔离，不阻塞他项）
    struct SlowTocFetcher {
        info: WebBookInfo,
        chapters: Vec<WebChapter>,
    }

    impl BookSourceFetcher for SlowTocFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<WebBookInfo> {
            Ok(self.info.clone())
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            tokio::time::sleep(std::time::Duration::from_millis(300)).await;
            Ok(self.chapters.clone())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }
    }

    /// 并发探针 mock：get_chapters 记录在飞数/最大在飞并睡 100ms ——
    /// 验证 [`ENRICH_CONCURRENCY`] 上限（≤8）且真并行（≥2，非串行）
    #[derive(Clone)]
    struct ConcurrencyProbeFetcher {
        in_flight: std::sync::Arc<std::sync::atomic::AtomicUsize>,
        max_in_flight: std::sync::Arc<std::sync::atomic::AtomicUsize>,
        chapters: Vec<WebChapter>,
    }

    impl BookSourceFetcher for ConcurrencyProbeFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<WebBookInfo> {
            Ok(WebBookInfo {
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                cover_url: None,
                intro: None,
                categories: vec![],
                last_chapter: None,
                variable: None,
                book_url: String::new(),
                toc_url: String::new(),
                word_count: None,
                kind: None,
                book_type: 0,
            })
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            let now = self.in_flight.fetch_add(1, Ordering::SeqCst) + 1;
            loop {
                let cur = self.max_in_flight.load(Ordering::SeqCst);
                if now <= cur {
                    break;
                }
                match self.max_in_flight.compare_exchange_weak(
                    cur,
                    now,
                    Ordering::SeqCst,
                    Ordering::SeqCst,
                ) {
                    Ok(_) => break,
                    Err(_) => continue,
                }
            }
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            self.in_flight.fetch_sub(1, Ordering::SeqCst);
            Ok(self.chapters.clone())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }
    }

    /// 缓存往返 + 键分隔符：两对键直接拼接会同串（"https://a"+"bc.example.com/x"
    /// ≡ "https://ab"+"c.example.com/x"），\0 分隔后不得互相串扰（对齐上游
    /// primaryStr 两键拼接，且修复其边界歧义）
    #[test]
    fn test_prefetch_cache_roundtrip_and_key_separator() {
        let _lock = crate::test_support::lock_global_store();
        prefetch_cache_clear();

        prefetch_cache_insert(
            "https://a",
            "bc.example.com/x",
            Some(test_web_info("https://a/toc-1")),
            test_web_chapters(1, "https://a/b1"),
        );
        prefetch_cache_insert(
            "https://ab",
            "c.example.com/x",
            Some(test_web_info("https://ab/toc-2")),
            test_web_chapters(2, "https://ab/b2"),
        );

        let e1 = prefetch_cache_get("https://a", "bc.example.com/x")
            .expect("键对1 应命中（不得被键对2 串扰）");
        assert_eq!(e1.chapters.len(), 1);
        assert_eq!(
            e1.info.as_ref().expect("info 应随条目缓存").toc_url,
            "https://a/toc-1"
        );

        let e2 = prefetch_cache_get("https://ab", "c.example.com/x").expect("键对2 应命中");
        assert_eq!(e2.chapters.len(), 2);
        assert_eq!(
            e2.info.as_ref().expect("info 应随条目缓存").toc_url,
            "https://ab/toc-2"
        );

        assert!(
            prefetch_cache_get("https://a", "https://a/b1").is_none(),
            "未写入的键不得命中"
        );

        // 清空语义（对齐上游 startSearch 清 tocMap/bookMap，L279-281）
        prefetch_cache_clear();
        assert!(
            prefetch_cache_get("https://a", "bc.example.com/x").is_none(),
            "clear 后不得残留（防选中读到上一会话陈旧目录）"
        );
    }

    /// 总章数上限守卫（对齐上游 tocMapChapterCount < 30000，L399-403）：
    /// 超限写入跳过；被跳过的写入**不推进计数器**（否则后续合法写入被误拒）
    #[test]
    fn test_prefetch_cache_cap_skips_oversized_entry() {
        let _lock = crate::test_support::lock_global_store();
        prefetch_cache_clear();

        // A：25000 章放行（0+25000 ≤ 30000）
        prefetch_cache_insert("cap-src", "cap-a", None, test_web_chapters(25_000, "cap-a"));
        // B：25000+6000=31000 > 30000 → 跳过
        prefetch_cache_insert("cap-src", "cap-b", None, test_web_chapters(6_000, "cap-b"));
        // C：若跳过未推进计数器 → 25000+4000=29000 ≤ 30000 应放行
        prefetch_cache_insert("cap-src", "cap-c", None, test_web_chapters(4_000, "cap-c"));

        assert!(
            prefetch_cache_get("cap-src", "cap-a").is_some(),
            "上限内条目应写入"
        );
        assert!(
            prefetch_cache_get("cap-src", "cap-b").is_none(),
            "超限条目应跳过（仅损失命中收益，不影响候选展示）"
        );
        assert!(
            prefetch_cache_get("cap-src", "cap-c").is_some(),
            "跳过不得推进计数器（否则 C 也会被误拒）"
        );

        prefetch_cache_clear();
    }

    #[test]
    fn test_cancel_switch_apply_is_instance_owned_and_new_apply_is_allowed() {
        let _lock = crate::test_support::lock_global_store();
        let state = crate::engine_holder::switches();
        let old = state.applies.start().unwrap();
        cancel_switch_apply();
        assert!(!old.is_active());
        let next = state.applies.start().unwrap();
        old.finish();
        assert!(next.is_active());
        cancel_switch_apply();
        assert!(!next.is_active());
    }

    /// 命中零抓取：缓存有完整条目（info + 非空目录）→ 2a/2b 全跳过
    /// （mock 详情/目录均 Err 仍不影响换源——证明零网络），缓存目录以稳定
    /// bookUrl 落库，字段更新/下一章登记用缓存值
    #[test]
    fn test_prefetch_hit_skips_fetch() {
        // apply 执行链内含 begin_book_flow 切 flow scope + 命中路径最终代数
        // 比对 → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://pf-hit.example.com/book/1";
        let old_origin = "https://pf-hit-old.example.com";
        let new_source = "https://pf-hit.example.com/new";
        let new_detail = "https://pf-hit.example.com/book/1";
        let new_toc = "https://pf-hit.example.com/book/1/chapters";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: old_origin.to_string(),
                origin_name: "旧源".to_string(),
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "预拉新源".to_string(),
                custom_order: 7,
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 种子预拉缓存完整条目（info + 2 章目录）
        prefetch_cache_clear();
        prefetch_cache_insert(
            new_source,
            new_detail,
            Some(test_web_info(new_toc)),
            test_web_chapters(2, new_toc),
        );

        // mock 全 Err：全命中路径下三者均不得被调用
        let mock = SwitchMockFetcher {
            info: Err(LegadoError::Internal("全命中不得抓详情".into())),
            chapters: Err(LegadoError::Internal("全命中不得抓目录".into())),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp = switch_book_source_prefetch_with(&mock, old_url, new_source, new_detail)
            .expect("全命中换源应成功");
        let book: Book = serde_json::from_str(&resp).expect("换源返回应可解析");

        // 零网络：三个 mock 记录向量全空
        assert!(
            mock.detail_vars_requested.lock().unwrap().is_empty(),
            "全命中不得发起详情抓取"
        );
        assert!(
            mock.toc_vars_requested.lock().unwrap().is_empty(),
            "全命中不得发起目录抓取"
        );
        assert!(
            mock.chapters_requested.lock().unwrap().is_empty(),
            "全命中不得发起目录抓取"
        );

        // 字段更新来自缓存 info（canReName 门控后：书名/作者保留既有值）
        assert_eq!(book.origin, new_source);
        assert_eq!(book.toc_url, new_toc, "tocUrl 应为缓存详情解析出的目录页");
        assert_eq!(
            book.word_count.as_deref(),
            Some("9999"),
            "字数应用缓存详情值"
        );
        // [目录派生字段同步] 命中路径同样以目录为准：缓存目录 2 章（第0章/第1章）
        // → 末章「第1章」覆盖缓存详情 lastChapter（「大结局」）
        assert_eq!(
            book.latest_chapter_title.as_deref(),
            Some("第1章"),
            "最新章节应用缓存目录末章值（目录写覆盖详情 lastChapter）"
        );
        assert_eq!(
            book.total_chapter_num, 2,
            "totalChapterNum 应为缓存目录章数"
        );

        // DB 终态：目录挂稳定主键、字段落库一致
        with_database(|db| {
            let persisted = BookRepository::new(db.connection())
                .find_by_url(old_url)?
                .expect("原 bookUrl 记录应仍存在");
            assert_eq!(persisted.origin, new_source);
            assert_eq!(persisted.toc_url, new_toc);
            let chapters = BookChapterRepository::new(db.connection()).find_by_book_url(old_url)?;
            assert_eq!(chapters.len(), 2, "缓存的 2 章应落库");
            assert_eq!(chapters[0].book_url, old_url, "章节须挂稳定主键");
            Ok(())
        })
        .expect("DB 断言失败");

        // apply 不消费缓存条目（条目留待同会话其他候选/重选）
        assert!(
            prefetch_cache_get(new_source, new_detail).is_some(),
            "apply 不得删除缓存条目"
        );

        // 收尾清理
        prefetch_cache_clear();
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// [目录派生字段同步] 预拉缓存命中通道（零网络）同样同步派生字段：
    /// 缓存目录（3 章，末章「第2章」）为准——mock 全 Err 证明命中路径零抓取，
    /// 缓存 info 的 lastChapter（「大结局」）不得胜出；提交后 total/latest
    /// == 缓存目录值（返回 JSON + DB 双断言）。
    /// 红态（修复前）：同现场抓取通道——全行 update 写回抓取前快照旧值
    /// （999/「旧源最新章节」），latest 取缓存详情值（「大结局」）。
    #[test]
    fn test_source_switch_prefetch_hit_syncs_toc_derived_fields() {
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_core::models::{Book, BookSource};
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://sw-pf-sync.example.com/book/1";
        let new_source = "https://sw-pf-sync.example.com/new";
        let new_detail = "https://sw-pf-sync.example.com/book/1";
        let new_toc = "https://sw-pf-sync.example.com/book/1/chapters";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://sw-pf-sync-old.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                // 红态播种：陈旧的目录派生字段
                total_chapter_num: 999,
                latest_chapter_title: Some("旧源最新章节".to_string()),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "预拉新源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 缓存种子：3 章目录（第0章..第2章）+ 详情 info（lastChapter=「大结局」）
        prefetch_cache_clear();
        prefetch_cache_insert(
            new_source,
            new_detail,
            Some(test_web_info(new_toc)),
            test_web_chapters(3, new_toc),
        );

        // mock 全 Err：命中路径零网络（详情/目录均不得抓取），目录以缓存值为准
        let mock = SwitchMockFetcher {
            info: Err(LegadoError::Internal("全命中不得抓详情".into())),
            chapters: Err(LegadoError::Internal("全命中不得抓目录".into())),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp = switch_book_source_prefetch_with(&mock, old_url, new_source, new_detail)
            .expect("全命中换源应成功");
        let book: Book = serde_json::from_str(&resp).expect("换源返回应可解析");

        // 零网络 + 派生字段同步
        assert!(
            mock.detail_vars_requested.lock().unwrap().is_empty(),
            "全命中不得发起详情抓取"
        );
        assert!(
            mock.chapters_requested.lock().unwrap().is_empty(),
            "全命中不得发起目录抓取"
        );
        assert_eq!(
            book.total_chapter_num, 3,
            "totalChapterNum 应为缓存目录章数（不得写回旧值 999）"
        );
        assert_eq!(
            book.latest_chapter_title.as_deref(),
            Some("第2章"),
            "latestChapterTitle 应为缓存目录末章标题（覆盖缓存详情 lastChapter 值）"
        );

        // DB 终态：派生字段与目录行数同事务一致
        with_database(|db| {
            let persisted = BookRepository::new(db.connection())
                .find_by_url(old_url)?
                .expect("书籍记录应仍存在");
            assert_eq!(
                persisted.total_chapter_num, 3,
                "DB totalChapterNum 应为缓存目录章数"
            );
            assert_eq!(
                persisted.latest_chapter_title.as_deref(),
                Some("第2章"),
                "DB latestChapterTitle 应为缓存目录末章标题"
            );
            let chapters = BookChapterRepository::new(db.connection()).find_by_book_url(old_url)?;
            assert_eq!(
                chapters.len() as i32,
                persisted.total_chapter_num,
                "DB 内部一致性：totalChapterNum == 落库章节数"
            );
            Ok(())
        })
        .expect("DB 断言失败");

        // 收尾清理
        prefetch_cache_clear();
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// 性能自证（2026-09-24 换源感知等待）：「选中 → 落地」前后对比
    /// （本地假源，非真网络）。同一本书两次测量，规避 books 表
    /// (name, author) 二级唯一索引在双书场景的相互 remap：
    /// - 前（未命中/旧行为）：选中后现场抓 2a 详情 + 2b 目录（真实源为
    ///   K 页目录串行抓取，本 mock 以单抓 300ms 压缩表达，共 ~600ms）
    /// - 后（预拉缓存命中/新行为）：搜索期已预拉 → 选中零网络，仅 DB 事务提交
    ///   命中阶段抓取计数必须为 0（计数断言 + 耗时对比双重证明）。
    ///   数字经 `cargo test -p legado-ffi --lib test_perf -- --nocapture` 输出供报告引用
    #[test]
    fn test_perf_apply_hit_vs_on_spot_miss() {
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_db::repository::Repository;
        use legado_db::{BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://perf-miss.example.com/book/1";
        let source_url = "https://perf-slow.example.com/new";
        let detail_url = "https://perf-slow.example.com/book/1";
        let toc_url = "https://perf-slow.example.com/book/1/chapters";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: book_url.to_string(),
                origin: "https://perf-miss-old.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "性能测试书".to_string(),
                author: "性能作者".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: source_url.to_string(),
                book_source_name: "慢源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // 慢 mock：详情/目录各睡 300ms（压缩表达真实源的 2a + K 页目录），
        // 抓取计数用于证明命中阶段零网络
        let fetch_calls = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let slow = PerfSlowFetcher {
            info: test_web_info(toc_url),
            chapters: test_web_chapters(50, toc_url),
            fetch_calls: fetch_calls.clone(),
        };

        // 前（未命中/旧行为）：现场 2a + 2b，~600ms 量级
        prefetch_cache_clear();
        let t0 = std::time::Instant::now();
        switch_book_source_prefetch_with(&slow, book_url, source_url, detail_url)
            .expect("未命中现场抓取换源应成功");
        let miss_ms = t0.elapsed().as_millis();
        assert_eq!(
            fetch_calls.load(Ordering::SeqCst),
            2,
            "未命中阶段应现场抓详情 + 目录各一次"
        );

        // 后（预拉缓存命中/新行为）：模拟搜索期预拉完成 → 缓存种入完整条目
        prefetch_cache_clear();
        prefetch_cache_insert(
            source_url,
            detail_url,
            Some(slow.info.clone()),
            slow.chapters.clone(),
        );
        let calls_before_hit = fetch_calls.load(Ordering::SeqCst);
        let t1 = std::time::Instant::now();
        switch_book_source_prefetch_with(&slow, book_url, source_url, detail_url)
            .expect("命中换源应成功");
        let hit_ms = t1.elapsed().as_millis();
        assert_eq!(
            fetch_calls.load(Ordering::SeqCst),
            calls_before_hit,
            "命中阶段不得发起任何网络抓取"
        );

        println!(
            "perf[apply]: 前(未命中现场抓 2a+2b, 50 章) = {miss_ms} ms; \
             后(预拉缓存命中零网络) = {hit_ms} ms; \
             提速比 = {:.1}x",
            miss_ms as f64 / hit_ms.max(1) as f64
        );
        assert!(
            hit_ms < miss_ms,
            "命中路径不得慢于现场抓取（命中 = 零网络仅 DB 提交）"
        );

        // 收尾清理
        prefetch_cache_clear();
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(book_url);
            let _ = BookSourceRepository::new(db.connection()).delete(source_url);
            Ok(())
        })
        .ok();
    }

    /// 性能自证用慢 mock：详情/目录各睡 300ms 后返回（非真网络），
    /// 每次抓取计 1（命中路径计数必须不增）
    struct PerfSlowFetcher {
        info: WebBookInfo,
        chapters: Vec<WebChapter>,
        fetch_calls: std::sync::Arc<std::sync::atomic::AtomicUsize>,
    }

    impl BookSourceFetcher for PerfSlowFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<WebBookInfo> {
            self.fetch_calls.fetch_add(1, Ordering::SeqCst);
            tokio::time::sleep(std::time::Duration::from_millis(300)).await;
            Ok(self.info.clone())
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            self.fetch_calls.fetch_add(1, Ordering::SeqCst);
            tokio::time::sleep(std::time::Duration::from_millis(300)).await;
            Ok(self.chapters.clone())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }
    }

    /// 未命中现场抓取：缓存无条目 → 2a 详情 + 2b 目录各抓 1 次（执行链与
    /// 旧路径一致），目录用详情解析出的 tocUrl；apply 自身不写缓存
    /// （写缓存职责在增强期，保持 apply 纯读）
    #[test]
    fn test_prefetch_miss_fetches_on_spot() {
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_db::repository::Repository;
        use legado_db::{BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://pf-miss.example.com/book/1";
        let new_source = "https://pf-miss.example.com/new";
        let new_detail = "https://pf-miss.example.com/book/1";
        let new_toc = "https://pf-miss.example.com/book/1/chapters";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: "https://pf-miss-old.example.com".to_string(),
                origin_name: "旧源".to_string(),
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "未命中源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        prefetch_cache_clear();
        let mock = SwitchMockFetcher {
            info: Ok(test_web_info(new_toc)),
            chapters: Ok(test_web_chapters(1, new_toc)),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };

        let resp = switch_book_source_prefetch_with(&mock, old_url, new_source, new_detail)
            .expect("未命中现场抓取换源应成功");
        let book: Book = serde_json::from_str(&resp).expect("换源返回应可解析");

        // 现场抓取：2a 详情 1 次 + 2b 目录 1 次，且目录用解析后的 tocUrl
        assert_eq!(
            mock.detail_vars_requested.lock().unwrap().len(),
            1,
            "未命中应现场抓详情一次"
        );
        assert_eq!(
            mock.toc_vars_requested.lock().unwrap().len(),
            1,
            "未命中应现场抓目录一次"
        );
        assert_eq!(
            mock.chapters_requested.lock().unwrap().as_slice(),
            [new_toc],
            "目录抓取应使用详情解析出的 tocUrl"
        );
        assert_eq!(book.origin, new_source);
        assert_eq!(book.toc_url, new_toc);

        // apply 不写缓存（与增强期职责分离）
        assert!(
            prefetch_cache_get(new_source, new_detail).is_none(),
            "apply 路径不得写预拉缓存"
        );

        // 收尾清理
        prefetch_cache_clear();
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// 在途取消：目录抓取途中 cancel_switch_apply（原 apply 取消）→ 2a/2b
    /// 成功后提交前代数比对发现取消 → Err「换源已取消」，DB 零变更
    /// （origin/tocUrl/章节全保留原值，对齐上游 cancelChangeSource）
    #[test]
    fn test_cancel_during_apply_blocks_commit() {
        let _lock = crate::test_support::lock_global_store();
        use crate::db_state::with_database;
        use legado_db::repository::Repository;
        use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};

        let _db_guard = crate::db_state::ensure_test_db();
        let old_url = "https://pf-cancel.example.com/book/1";
        let old_origin = "https://pf-cancel-old.example.com";
        let old_toc = "https://pf-cancel-old.example.com/toc";
        let new_source = "https://pf-cancel.example.com/new";
        let new_detail = "https://pf-cancel.example.com/book/1";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: old_url.to_string(),
                origin: old_origin.to_string(),
                origin_name: "旧源".to_string(),
                name: "测试书".to_string(),
                author: "测试作者".to_string(),
                toc_url: old_toc.to_string(),
                ..Book::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: new_source.to_string(),
                book_source_name: "取消源".to_string(),
                ..BookSource::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        prefetch_cache_clear();
        let mock = CancelDuringTocFetcher {
            info: test_web_info(new_detail),
            chapters: test_web_chapters(1, new_detail),
        };

        let err = switch_book_source_prefetch_with(&mock, old_url, new_source, new_detail)
            .expect_err("在途取消应阻断提交");
        assert!(
            err.to_string().contains("换源已取消"),
            "错误须明确说明换源已取消，实际: {err}"
        );

        // DB 零变更：origin/tocUrl 保持原值，章节未写入
        with_database(|db| {
            let persisted = BookRepository::new(db.connection())
                .find_by_url(old_url)?
                .expect("书籍应存在");
            assert_eq!(persisted.origin, old_origin, "origin 不得被改");
            assert_eq!(persisted.toc_url, old_toc, "tocUrl 不得被改");
            assert_eq!(
                BookChapterRepository::new(db.connection()).count_by_book_url(old_url)?,
                0,
                "章节不得写入"
            );
            Ok(())
        })
        .expect("零变更断言失败");

        // 收尾清理
        prefetch_cache_clear();
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(old_url);
            let _ = BookSourceRepository::new(db.connection()).delete(new_source);
            Ok(())
        })
        .ok();
    }

    /// 增强期缓存写入：loadInfo+loadToc → 候选补 latest_chapter/word_count/
    /// origin_order（源 customOrder），并写完整条目（info + 目录）进预拉缓存
    #[test]
    fn test_enrich_one_switch_candidate_writes_prefetch_cache() {
        let _lock = crate::test_support::lock_global_store();
        let src_url = "https://enr-1.example.com";
        let detail = "https://enr-1.example.com/book/1";
        let new_toc = "https://enr-1.example.com/book/1/chapters";
        let source = BookSource {
            book_source_url: src_url.to_string(),
            book_source_name: "增强源".to_string(),
            custom_order: 7,
            ..BookSource::default()
        };
        let mock = SwitchMockFetcher {
            info: Ok(test_web_info(new_toc)),
            chapters: Ok(test_web_chapters(2, new_toc)),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };
        let options = SwitchSearchOptions {
            load_info: true,
            load_toc: true,
            ..SwitchSearchOptions::default()
        };

        prefetch_cache_clear();
        let candidate = mk_candidate(src_url, detail, "测试书");
        let enriched = runtime::block_on(enrich_one_switch_candidate_with(
            &mock, &source, candidate, &options,
        ));

        assert_eq!(enriched.origin_order, 7, "origin_order 应用源 customOrder");
        assert_eq!(
            enriched.latest_chapter.as_deref(),
            Some("大结局"),
            "latest_chapter 应由详情补全"
        );
        assert_eq!(
            enriched.word_count.as_deref(),
            Some("9999"),
            "word_count 应由详情补全"
        );
        assert_eq!(
            mock.chapters_requested.lock().unwrap().as_slice(),
            [detail],
            "增强期目录抓取以候选 bookUrl 为取址点"
        );

        let entry = prefetch_cache_get(src_url, detail).expect("应写入完整缓存条目");
        assert_eq!(entry.chapters.len(), 2);
        assert_eq!(
            entry
                .info
                .as_ref()
                .expect("详情应随条目缓存（apply 命中零网络的前提）")
                .toc_url,
            new_toc
        );

        prefetch_cache_clear();
    }

    /// 单失败隔离（增强期）：目录抓取失败 → 候选原样直通（不传播错误、
    /// 不阻塞他项）；load_info 成功已写「详情-only」条目（对齐上游
    /// bookMap 恒写：apply 命中可降级省一次详情抓取）
    #[test]
    fn test_enrich_single_failure_passthrough_keeps_info_entry() {
        let _lock = crate::test_support::lock_global_store();
        let src_url = "https://enr-fail.example.com";
        let detail = "https://enr-fail.example.com/book/1";
        let source = BookSource {
            book_source_url: src_url.to_string(),
            book_source_name: "增强源".to_string(),
            custom_order: 3,
            ..BookSource::default()
        };
        let mock = SwitchMockFetcher {
            info: Ok(test_web_info(detail)),
            chapters: Err(LegadoError::Internal("目录解析失败".into())),
            chapters_requested: std::sync::Mutex::new(Vec::new()),
            detail_vars_requested: std::sync::Mutex::new(Vec::new()),
            toc_vars_requested: std::sync::Mutex::new(Vec::new()),
        };
        let options = SwitchSearchOptions {
            load_info: true,
            load_toc: true,
            ..SwitchSearchOptions::default()
        };

        prefetch_cache_clear();
        let candidate = mk_candidate(src_url, detail, "测试书");
        let enriched = runtime::block_on(enrich_one_switch_candidate_with(
            &mock, &source, candidate, &options,
        ));

        // 候选原样直通：字段补全不受目录失败影响，函数不返回错误
        assert_eq!(enriched.origin_order, 3);
        assert_eq!(
            enriched.latest_chapter.as_deref(),
            Some("大结局"),
            "详情成功 → latest_chapter 照常补全"
        );

        // 目录失败 → 不得写完整条目；但 load_info 期的详情-only 条目保留
        let entry = prefetch_cache_get(src_url, detail).expect("应存在详情-only 条目");
        assert!(entry.chapters.is_empty(), "目录失败不得写完整条目");
        assert!(
            entry.info.is_some(),
            "详情应缓存（apply 命中降级：省一次详情抓取）"
        );

        prefetch_cache_clear();
    }

    /// 单候选超时隔离：慢候选（300ms）+ 50ms 超时 → 候选原样直通（字段
    /// 未补全、origin_order 未更新）、不写缓存；在途抓取随超时丢弃
    #[test]
    fn test_enrich_timeout_isolates_slow_candidate() {
        let _lock = crate::test_support::lock_global_store();
        let src_url = "https://enr-slow.example.com";
        let detail = "https://enr-slow.example.com/book/1";
        let source = BookSource {
            book_source_url: src_url.to_string(),
            book_source_name: "慢源".to_string(),
            custom_order: 4,
            ..BookSource::default()
        };
        let mock = SlowTocFetcher {
            info: test_web_info(detail),
            chapters: test_web_chapters(1, detail),
        };
        // 仅 load_toc：慢点集中在目录抓取；load_info 关闭避免详情-only
        // 条目干扰「超时无任何缓存写入」断言
        let options = SwitchSearchOptions {
            load_toc: true,
            ..SwitchSearchOptions::default()
        };

        prefetch_cache_clear();
        let candidate = mk_candidate(src_url, detail, "测试书");
        let out = runtime::block_on(enrich_item_with_timeout(
            &mock,
            &source,
            candidate.clone(),
            &options,
            std::time::Duration::from_millis(50),
        ));

        // 超时 → 原始候选直通：origin_order / latest_chapter 均保持原值
        // （SearchCandidate 未派生 PartialEq，逐字段比对）
        assert_eq!(
            out.origin_order, 0,
            "超时后候选应原样直通（origin_order 不得更新）"
        );
        assert!(
            out.latest_chapter.is_none() && out.word_count.is_none(),
            "超时后字段不得补全"
        );
        assert_eq!(
            (out.book_url.as_str(), out.source_url.as_str()),
            (candidate.book_url.as_str(), candidate.source_url.as_str()),
            "超时输出应与原始候选一致（关键标识字段）"
        );
        assert!(
            prefetch_cache_get(src_url, detail).is_none(),
            "超时候选不得写缓存（在途抓取已丢弃）"
        );

        prefetch_cache_clear();
    }

    /// 有界并发 + 顺序恢复：16 候选 + 2 孤儿候选（源不在列表）→ 孤儿在前
    /// 原样直通、其余 16 个按原顺序返回；目录抓取期最大在飞
    /// ≤ ENRICH_CONCURRENCY（=8）且 ≥2（真并行非串行）；成功候选写缓存
    #[test]
    fn test_enrich_parallel_bounded_and_order_preserved() {
        let _lock = crate::test_support::lock_global_store();
        const N: usize = 16;
        let sources: Vec<BookSource> = (0..N)
            .map(|i| BookSource {
                book_source_url: format!("https://par-{i}.example.com"),
                book_source_name: format!("源{i}"),
                custom_order: (i + 1) as i32,
                ..BookSource::default()
            })
            .collect();
        let mut candidates: Vec<SearchCandidate> = (0..N)
            .map(|i| {
                mk_candidate(
                    &format!("https://par-{i}.example.com"),
                    &format!("https://par-{i}.example.com/book/{i}"),
                    "测试书",
                )
            })
            .collect();
        // 孤儿候选：源不在 sources 列表 → 须原样直通且排最前
        candidates.insert(
            0,
            mk_candidate(
                "https://ghost-1.example.com",
                "https://ghost-1.example.com/book/9",
                "孤1",
            ),
        );
        candidates.push(mk_candidate(
            "https://ghost-2.example.com",
            "https://ghost-2.example.com/book/9",
            "孤2",
        ));

        let probe = ConcurrencyProbeFetcher {
            in_flight: std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0)),
            max_in_flight: std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0)),
            chapters: test_web_chapters(1, "probe"),
        };
        let probe_max = probe.max_in_flight.clone();
        let options = SwitchSearchOptions {
            load_toc: true,
            ..SwitchSearchOptions::default()
        };

        prefetch_cache_clear();
        let out = runtime::block_on(enrich_switch_candidates_async(
            &sources,
            candidates.clone(),
            &options,
            move || Ok::<_, LegadoError>(probe.clone()),
        ))
        .expect("增强应成功");

        // 顺序恢复：孤儿在前（原顺序），其后 16 job 按原候选顺序
        assert_eq!(out.len(), N + 2);
        assert_eq!(
            out[0].book_url, "https://ghost-1.example.com/book/9",
            "孤儿1 应排最前"
        );
        assert_eq!(out[0].origin_order, 0, "孤儿候选应原样直通（源不在列表）");
        assert_eq!(
            out[1].book_url, "https://ghost-2.example.com/book/9",
            "孤儿2 应紧随其后"
        );
        for (j, i) in (0..N).enumerate() {
            let expected = format!("https://par-{i}.example.com/book/{i}");
            assert_eq!(
                out[2 + j].book_url,
                expected,
                "job 顺序应与原始候选顺序一致"
            );
            assert_eq!(
                out[2 + j].origin_order,
                (i + 1) as i32,
                "origin_order 应用源 customOrder"
            );
        }

        // 有界并发：最大在飞 ≤ 上限且真并行
        let max = probe_max.load(Ordering::SeqCst);
        assert!(
            max <= ENRICH_CONCURRENCY,
            "在飞数不得超 ENRICH_CONCURRENCY 上限（实际 {max}）"
        );
        assert!(max >= 2, "应真并行执行（最大在飞 {max}，疑似串行）");

        // 成功候选应写预拉缓存（load_toc 成功 → 完整条目：补抓详情 + 1 章目录）
        assert!(
            prefetch_cache_get(
                "https://par-0.example.com",
                "https://par-0.example.com/book/0"
            )
            .is_some(),
            "成功候选应写预拉缓存"
        );

        prefetch_cache_clear();
    }
    fn isolated_context(engine: &legado_engine::EngineContext) -> SwitchContext {
        SwitchContext::from_engine(
            engine,
            Arc::new(SourceSwitchState::new(engine.tasks().clone())),
        )
    }
    fn seed_isolated_switch(
        engine: &legado_engine::EngineContext,
        base: &str,
        search: &str,
    ) -> BookSource {
        use legado_db::repository::Repository;
        let source:BookSource=serde_json::from_value(serde_json::json!({
            "bookSourceUrl":base,"bookSourceName":"新源","searchUrl":search,
            "ruleSearch":{"bookList":".book","name":".name@text","author":".author@text","bookUrl":"a@href"},
            "ruleBookInfo":{"name":".name@text","author":".author@text","tocUrl":".toc@href"},
            "ruleToc":{"chapterList":".chapter","chapterName":"a@text","chapterUrl":"a@href"},
            "ruleContent":{"content":".content@text","subContent":".sub@text"}
        })).unwrap();
        engine
            .storage()
            .with_database(|db| {
                legado_db::BookSourceRepository::new(db.connection()).insert(&source)?;
                legado_db::BookRepository::new(db.connection()).insert(&Book {
                    book_url: "https://stable.test/book".into(),
                    origin: "https://old.test".into(),
                    name: "测试书".into(),
                    author: "测试作者".into(),
                    ..Default::default()
                })?;
                legado_db::BookChapterRepository::new(db.connection()).insert_batch(&[
                    BookChapter {
                        book_url: "https://stable.test/book".into(),
                        url: "https://old.test/chapter".into(),
                        title: "旧章节".into(),
                        ..Default::default()
                    },
                ])
            })
            .unwrap();
        source
    }
    fn network_switch_body(request: &str) -> String {
        let identity = if request.contains("identity=first") {
            "甲"
        } else {
            "乙"
        };
        if request.starts_with("GET /search ") {
            "<div class='book'><span class='name'>测试书</span><span class='author'>测试作者</span><a href='/detail'>详情</a></div>".into()
        } else if request.starts_with("GET /detail ") {
            "<span class='name'>测试书</span><span class='author'>测试作者</span><a class='toc' href='/toc'>目录</a>".into()
        } else {
            format!("<div class='chapter'><a href='/chapter'>{identity}章节</a></div>")
        }
    }

    #[tokio::test]
    async fn isolated_complete_search_enrichment_and_cached_apply_use_the_original_instances() {
        use super::super::source_task_fixture::Fixture;
        let mut server = Fixture::new(6, false, network_switch_body);
        let first = legado_engine::EngineContext::in_memory().unwrap();
        let second = legado_engine::EngineContext::in_memory().unwrap();
        let mut contexts = Vec::new();
        for (engine, identity, title) in
            [(&first, "first", "甲章节"), (&second, "second", "乙章节")]
        {
            seed_isolated_switch(engine, &server.url, &format!("{}/search", server.url));
            engine
                .network()
                .set_cookie("127.0.0.1", &format!("identity={identity}"))
                .unwrap();
            let context = isolated_context(engine);
            let searching = context.clone().start_search().unwrap();
            let guard = searching.operation().unwrap().guard();
            let mut events = Vec::new();
            searching
                .run_change_source_stream(
                    "测试书".into(),
                    "测试作者".into(),
                    "[]".into(),
                    r#"{"loadInfo":true,"loadToc":true,"forceRefresh":true}"#.into(),
                    |json| {
                        events.push(serde_json::from_str::<serde_json::Value>(&json).unwrap());
                        Ok(())
                    },
                )
                .await;
            assert_eq!(events.len(), 2);
            assert_eq!(events.last().unwrap()["matches"][0]["book_name"], "测试书");
            let entry = context
                .state()
                .get(&server.url, &format!("{}/detail", server.url))
                .unwrap();
            assert_eq!(entry.chapters[0].title, title);
            for _ in 0..3 {
                assert!(
                    server
                        .request()
                        .await
                        .contains(&format!("identity={identity}"))
                );
            }
            drop(guard);
            drop(searching);
            let applying = context.clone().start_apply().unwrap();
            let guard = applying.operation().unwrap().guard();
            let fetcher = applying
                .fetcher_for_book(&server.url, &format!("{}/detail", server.url))
                .unwrap();
            // 缓存完整命中后，服务端已不提供额外请求额度，实际 apply 不得再抓取。
            let applying_worker = applying.clone();
            let base = server.url.clone();
            let result = tokio::task::spawn_blocking(move || {
                applying_worker.switch_book_source_prefetch_with(
                    &fetcher,
                    "https://stable.test/book",
                    &base,
                    &format!("{base}/detail"),
                )
            })
            .await
            .unwrap()
            .unwrap();
            let book: serde_json::Value = serde_json::from_str(&result).unwrap();
            assert_eq!(book["bookUrl"], "https://stable.test/book");
            engine
                .storage()
                .with_database(|db| {
                    let chapters = legado_db::BookChapterRepository::new(db.connection())
                        .find_by_book_url("https://stable.test/book")?;
                    assert_eq!(chapters[0].title, title);
                    assert!(
                        legado_db::SearchBookRepository::new(db.connection())
                            .find_by_book_url(&format!("{}/detail", server.url))?
                            .is_some()
                    );
                    Ok(())
                })
                .unwrap();
            drop(guard);
            drop(applying);
            assert_eq!(engine.tasks().active_count(), 0);
            contexts.push(context);
        }
        assert_eq!(
            contexts[0]
                .state()
                .get(&server.url, &format!("{}/detail", server.url))
                .unwrap()
                .chapters[0]
                .title,
            "甲章节"
        );
        server.worker.join().unwrap();
    }

    #[tokio::test]
    async fn isolated_sink_close_stops_enrichment_and_search_book_persistence() {
        use super::super::source_task_fixture::Fixture;
        let mut server = Fixture::new(1, false, network_switch_body);
        let engine = legado_engine::EngineContext::in_memory().unwrap();
        seed_isolated_switch(&engine, &server.url, &format!("{}/search", server.url));
        let context = isolated_context(&engine).start_search().unwrap();
        let guard = context.operation().unwrap().guard();
        let mut count = 0;
        context
            .run_change_source_stream(
                "测试书".into(),
                "测试作者".into(),
                "[]".into(),
                r#"{"loadInfo":true,"loadToc":true,"forceRefresh":true}"#.into(),
                |_| {
                    count += 1;
                    Err("sink 已关闭".into())
                },
            )
            .await;
        assert_eq!(count, 1);
        server.request().await;
        assert!(
            context
                .state()
                .get(&server.url, &format!("{}/detail", server.url))
                .is_none()
        );
        engine
            .storage()
            .with_database(|db| {
                assert!(
                    legado_db::SearchBookRepository::new(db.connection())
                        .find_by_book_url(&format!("{}/detail", server.url))?
                        .is_none()
                );
                Ok(())
            })
            .unwrap();
        drop(guard);
        drop(context);
        assert_eq!(engine.tasks().active_count(), 0);
        server.worker.join().unwrap();
    }

    #[tokio::test]
    async fn isolated_replaced_enrichment_cannot_refill_new_cache_or_keep_root_alive() {
        use super::super::source_task_fixture::Fixture;
        use std::time::Duration;
        let mut details = Fixture::new(1, true, |_| {
            "<span class='name'>测试书</span><span class='author'>测试作者</span><a class='toc' href='/toc'>目录</a>".into()
        });
        let detail = format!("{}/detail", details.url);
        let payload = detail.clone();
        let search = Fixture::new(1, false, move |_| {
            format!(
                "<div class='book'><span class='name'>测试书</span><span class='author'>测试作者</span><a href='{payload}'>详情</a></div>"
            )
        });
        let engine = Arc::new(legado_engine::EngineContext::in_memory().unwrap());
        let weak = Arc::downgrade(&engine);
        let tasks = engine.tasks().clone();
        let storage = engine.storage().clone();
        seed_isolated_switch(&engine, &search.url, &format!("{}/search", search.url));
        let context = isolated_context(&engine).start_search().unwrap();
        let state = context.state().clone();
        let guard = context.operation().unwrap().guard();
        let mut count = 0;
        let mut stream = Box::pin(context.run_change_source_stream(
            "测试书".into(),
            "测试作者".into(),
            "[]".into(),
            r#"{"loadInfo":true,"loadToc":true,"forceRefresh":true}"#.into(),
            |_| {
                count += 1;
                Ok(())
            },
        ));
        tokio::select! {_=details.request()=>{},result=&mut stream=>panic!("增强未进入真实等待: {result:?}")}
        let next = state.start_search().unwrap();
        next.publish(|| {
            state.insert(
                &search.url,
                &detail,
                None,
                test_web_chapters(1, "new-session"),
            )
        });
        drop(stream);
        drop(guard);
        drop(context);
        drop(next);
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(!tasks.shutdown(Duration::from_millis(20)).await);
        details.release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(5)).await);
        assert_eq!(
            state.get(&search.url, &detail).unwrap().chapters[0].url,
            "new-session/c0"
        );
        assert_eq!(count, 1);
        storage
            .with_database(|db| {
                assert!(
                    legado_db::SearchBookRepository::new(db.connection())
                        .find_by_book_url(&detail)?
                        .is_none()
                );
                Ok(())
            })
            .unwrap();
        details.worker.join().unwrap();
        search.worker.join().unwrap();
    }

    #[tokio::test]
    async fn isolated_cancelled_real_apply_keeps_old_book_and_chapters() {
        use super::super::source_task_fixture::Fixture;
        use std::time::Duration;
        let mut toc = Fixture::new(1, true, |_| {
            "<div class='chapter'><a href='/new-chapter'>新章节</a></div>".into()
        });
        let toc_url = format!("{}/toc", toc.url);
        let details = Fixture::new(1, false, move |_| {
            format!(
                "<span class='name'>测试书</span><span class='author'>测试作者</span><a class='toc' href='{toc_url}'>目录</a>"
            )
        });
        let engine = Arc::new(legado_engine::EngineContext::in_memory().unwrap());
        let weak = Arc::downgrade(&engine);
        let tasks = engine.tasks().clone();
        let storage = engine.storage().clone();
        seed_isolated_switch(&engine, &details.url, &format!("{}/unused", details.url));
        let context = isolated_context(&engine).start_apply().unwrap();
        let state = context.state().clone();
        let source = details.url.clone();
        let worker = tokio::task::spawn_blocking(move || {
            let _guard = context.operation().unwrap().guard();
            let fetcher = context.fetcher_for_book(&source, &format!("{source}/detail"))?;
            context.switch_book_source_prefetch_with(
                &fetcher,
                "https://stable.test/book",
                &source,
                &format!("{source}/detail"),
            )
        });
        toc.request().await;
        state.applies.cancel();
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(!tasks.shutdown(Duration::from_millis(20)).await);
        toc.release.send(()).unwrap();
        let error = worker.await.unwrap().unwrap_err();
        assert!(error.to_string().contains("换源已取消"));
        assert!(tasks.shutdown(Duration::from_secs(5)).await);
        storage
            .with_database(|db| {
                assert_eq!(
                    legado_db::BookRepository::new(db.connection())
                        .find_by_url("https://stable.test/book")?
                        .unwrap()
                        .origin,
                    "https://old.test"
                );
                let chapters = legado_db::BookChapterRepository::new(db.connection())
                    .find_by_book_url("https://stable.test/book")?;
                assert_eq!(chapters.len(), 1);
                assert_eq!(chapters[0].title, "旧章节");
                Ok(())
            })
            .unwrap();
        toc.worker.join().unwrap();
        details.worker.join().unwrap();
    }

    #[tokio::test(start_paused = true)]
    async fn isolated_candidate_timeout_blocks_late_cache_write_without_cancelling_other_candidates()
     {
        use super::super::source_task_fixture::Fixture;
        use std::time::Duration;
        let mut details = Fixture::new(1, true, |_| {
            "<span class='name'>测试书</span><span class='author'>测试作者</span>".into()
        });
        let engine = legado_engine::EngineContext::in_memory().unwrap();
        let source =
            seed_isolated_switch(&engine, &details.url, &format!("{}/unused", details.url));
        let context = isolated_context(&engine).start_search().unwrap();
        let guard = context.operation().unwrap().guard();
        let book = format!("{}/detail", details.url);
        let options = SwitchSearchOptions {
            load_info: true,
            ..Default::default()
        };
        let worker_context = context.clone();
        let jobs = vec![(mk_candidate(&details.url, &book, "测试书"), source)];
        let worker = tokio::spawn(async move {
            worker_context
                .run_enrich_jobs_until(
                    |context: &SourceSwitchService| context.fetcher(),
                    jobs,
                    &options,
                    Duration::from_millis(50),
                )
                .await
        });
        // 请求来自另一个真实运行时。保持本测试可调度，防止暂停时钟在
        // HTTP 尚未到达时自动跳到超时；真实看门狗仅防夹具故障。
        let startup = std::time::Instant::now();
        loop {
            match details.requests.try_recv() {
                Ok(_) => break,
                Err(tokio::sync::mpsc::error::TryRecvError::Empty) => {
                    assert!(!worker.is_finished(), "请求到达前候选已结束");
                    assert!(
                        startup.elapsed() < Duration::from_secs(5),
                        "候选未进入真实等待"
                    );
                    tokio::task::yield_now().await;
                }
                Err(error) => panic!("HTTP 夹具提前关闭: {error}"),
            }
        }
        tokio::time::advance(Duration::from_millis(49)).await;
        tokio::task::yield_now().await;
        assert!(!worker.is_finished(), "候选在50ms期限前提前结束");
        tokio::time::advance(Duration::from_millis(1)).await;
        let result = worker.await.unwrap();
        // 后半段观察真实后台工作，不让暂停时钟把五秒看门狗自动耗尽。
        tokio::time::resume();
        assert_eq!(result.len(), 1);
        assert!(context.operation().unwrap().is_active());
        assert!(context.state().get(&details.url, &book).is_none());
        assert!(engine.tasks().active_count() > 1);
        context.publish(|| {
            context
                .state()
                .insert(&details.url, &book, None, test_web_chapters(1, "accepted"))
        });
        details.release.send(()).unwrap();
        tokio::time::timeout(Duration::from_secs(5), async {
            while engine.tasks().active_count() > 1 {
                tokio::task::yield_now().await;
            }
        })
        .await
        .unwrap();
        assert_eq!(
            context.state().get(&details.url, &book).unwrap().chapters[0].url,
            "accepted/c0"
        );
        drop(guard);
        drop(context);
        assert_eq!(engine.tasks().active_count(), 0);
        details.worker.join().unwrap();
    }
}
