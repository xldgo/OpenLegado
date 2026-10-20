//! 搜索宿主适配：捕获资源、转换文档协议并委托Engine搜索服务。
use crate::runtime;
#[cfg(test)]
use legado_core::book_help::format_book_word_count as word_count_format;
use legado_core::{
    LegadoError, LegadoResult,
    models::{BookSource, SearchBook as CoreSearchBook},
    search_aggregate,
    source_matcher::SearchCandidate,
};
#[cfg(all(test, feature = "quickjs"))]
use legado_engine::search_service::SEARCH_SOURCE_TIMEOUT;
pub(crate) use legado_engine::search_service::{
    AnnotatedCandidate, result_to_candidate, result_to_search_book,
};
pub use legado_engine::search_service::{CoverCandidate, SearchResult, SearchSourceBatch};
#[cfg(test)]
use legado_engine::search_service::{
    ReadRecordIndex, SearchContext, SearchRun, annotate_results, build_annotated_candidate,
    classify_source_outcome, dedup_search_results_keep_first, ensure_default_user_agent,
    extract_cover_candidates, parse_search_response_with_context, persist_search_books,
    precise_search_owned, resolve_url, search_single_source_owned,
    search_single_source_with_context, split_book_list_prefix,
};
use legado_engine::search_service::{SearchResources, SearchService};
#[cfg(test)]
use legado_engine::source_batches::{SourceBatchOutcome, drive_source_batches};
#[cfg(test)]
use legado_engine::source_catalog::load_search_sources_selected_from;
#[cfg(test)]
use legado_engine::{SearchSession, StorageContext};
#[cfg(test)]
use legado_fetcher::book_type::book_type_of_source;
use legado_fetcher::deps::FetcherDeps;
#[cfg(test)]
use legado_fetcher::{book_type, web_book::book_list_elements_or_default};
use legado_net::LegadoClient;
#[cfg(test)]
use legado_parser::AnalyzeUrl;
use std::sync::Arc;
#[cfg(test)]
use std::{
    collections::HashMap,
    sync::atomic::{AtomicBool, Ordering},
    time::Duration,
};

#[cfg(test)]
use legado_db::ReadRecordRepository;

fn host_service() -> SearchService {
    service_for_engine(crate::engine_holder::current().ok().as_deref())
}

pub(crate) fn service_for_engine(engine: Option<&legado_engine::EngineContext>) -> SearchService {
    let storage = engine.map(|e| e.storage().clone());
    let network = engine
        .map(|e| e.network().clone())
        .unwrap_or_else(crate::engine_holder::network);
    let js = engine
        .map(|e| e.js_resources().clone())
        .unwrap_or_else(crate::engine_holder::js_resources);
    let web = engine
        .map(|e| e.web_book_state().clone())
        .unwrap_or_else(crate::engine_holder::web_book_state);
    let rate = engine
        .map(|e| e.rate_limiter())
        .unwrap_or_else(crate::engine_holder::rate_limiter);
    let login = engine
        .map(|e| e.source_login_cache().clone())
        .unwrap_or_else(crate::engine_holder::source_login_cache);
    let info = engine
        .map(|e| e.source_info_map().clone())
        .unwrap_or_else(crate::engine_holder::source_info_map);
    let database = storage.clone();
    SearchService::new(SearchResources {
        storage,
        network,
        searches: crate::engine_holder::searches(),
        tasks: engine
            .map(|e| e.tasks().clone())
            .unwrap_or_else(crate::engine_holder::task_group),
        runtime: runtime::get_runtime().handle().clone(),
        prepare: Arc::new(move |client| {
            super::web_book::search_deps(
                FetcherDeps::new(client)
                    .with_js_resources(js.clone())
                    .with_web_book_state(web.clone())
                    .with_rate_limiter(rate.clone()),
                database.clone(),
                login.clone(),
                info.clone(),
            )
        }),
    })
}

#[cfg(test)]
fn host_context(client: LegadoClient) -> SearchContext {
    host_service().context(client)
}

#[cfg(test)]
fn context_for_engine(
    engine: &legado_engine::EngineContext,
    client: LegadoClient,
) -> SearchContext {
    service_for_engine(Some(engine)).context(client)
}

#[cfg(test)]
fn is_current_session(session: &Arc<SearchSession>) -> bool {
    session.is_current()
}

#[cfg(test)]
fn clear_current_session_if_same(session: &Arc<SearchSession>) {
    session.finish();
}

#[cfg(test)]
pub(crate) fn load_search_sources(source_urls_json: &str) -> LegadoResult<Vec<BookSource>> {
    let storage = crate::engine_holder::current()
        .ok()
        .map(|engine| engine.storage().clone());
    load_search_sources_from(storage.as_ref(), source_urls_json)
}

#[cfg(test)]
pub(crate) fn load_search_sources_from(
    storage: Option<&StorageContext>,
    json: &str,
) -> LegadoResult<Vec<BookSource>> {
    load_search_sources_selected_from(storage, &parse_source_urls(json)?)
}

#[cfg(test)]
fn build_search_url(template: &str, keyword: &str, source: &BookSource) -> AnalyzeUrl {
    crate::js_executor::build_search_url(template, keyword, 1, &source.book_source_url)
}

#[cfg(test)]
fn parse_search_response(
    body: &str,
    base_url: &str,
    source: &BookSource,
) -> LegadoResult<Vec<SearchResult>> {
    parse_search_response_ex(body, base_url, source, false, "")
}

#[cfg(test)]
fn parse_search_response_ex(
    body: &str,
    base_url: &str,
    source: &BookSource,
    precision: bool,
    key: &str,
) -> LegadoResult<Vec<SearchResult>> {
    let context = host_context(crate::http_state::shared_client()?);
    parse_search_response_with_context(&context, body, base_url, source, precision, key)
}

pub struct WebSourceSearcher {
    client: LegadoClient,
}

impl WebSourceSearcher {
    pub fn new(client: LegadoClient) -> Self {
        Self { client }
    }
}

impl legado_core::SourceSearcher for WebSourceSearcher {
    async fn search(
        &self,
        source: &BookSource,
        query: &str,
        max_results: usize,
    ) -> Vec<SearchCandidate> {
        let service = host_service();
        let precision = service.precision();
        match service
            .search_single_source(&self.client, source, query, 1, precision)
            .await
        {
            Ok(results) => results
                .into_iter()
                .take(max_results)
                .map(|r| result_to_candidate(r, source.custom_order))
                .collect(),
            Err(_) => Vec::new(),
        }
    }
}

pub fn search_books(keyword: &str, source_urls_json: &str) -> LegadoResult<Vec<SearchResult>> {
    search_books_selected(keyword, &parse_source_urls(source_urls_json)?)
}

pub fn search_books_selected(
    keyword: &str,
    source_urls: &[String],
) -> LegadoResult<Vec<SearchResult>> {
    host_service().search_books_selected(keyword, source_urls)
}

pub fn precise_search(name: &str, author: &str, source_urls_json: &str) -> LegadoResult<String> {
    serde_json::to_string(&precise_search_selected(
        name,
        author,
        &parse_source_urls(source_urls_json)?,
    )?)
    .map_err(LegadoError::Serialization)
}

pub fn precise_search_selected(
    name: &str,
    author: &str,
    source_urls: &[String],
) -> LegadoResult<CoreSearchBook> {
    host_service().precise_search_selected(name, author, source_urls)
}

pub fn multi_source_search(query: &str, source_urls_json: &str) -> LegadoResult<String> {
    serde_json::to_string(&multi_source_search_selected(
        query,
        &parse_source_urls(source_urls_json)?,
    )?)
    .map_err(LegadoError::Serialization)
}

pub(crate) fn multi_source_search_selected(
    query: &str,
    source_urls: &[String],
) -> LegadoResult<Vec<AnnotatedCandidate>> {
    host_service().multi_source_search_selected(query, source_urls)
}

pub fn cancel_search() {
    host_service().cancel_search()
}

pub fn pause_search() {
    host_service().pause_search()
}

pub fn resume_search() {
    host_service().resume_search()
}

pub fn search_cover(book_name: &str) -> LegadoResult<Vec<CoverCandidate>> {
    host_service().search_cover(book_name)
}

pub async fn run_multi_stream<F>(
    query: String,
    source_urls_json: String,
    page: i32,
    mut on_batch: F,
) where
    F: FnMut(String) -> Result<(), String>,
{
    run_multi_stream_typed(query, source_urls_json, page, |batch| {
        on_batch(serde_json::to_string(&batch).map_err(|e| e.to_string())?)
    })
    .await;
}

pub async fn run_multi_stream_typed<F>(query: String, json: String, page: i32, callback: F)
where
    F: FnMut(SearchSourceBatch) -> Result<(), String>,
{
    let Ok(urls) = parse_source_urls(&json) else {
        return;
    };
    run_multi_stream_selected(query, urls, page, callback).await;
}

pub async fn run_multi_stream_selected<F>(
    query: String,
    source_urls: Vec<String>,
    page: i32,
    on_batch: F,
) where
    F: FnMut(SearchSourceBatch) -> Result<(), String>,
{
    host_service()
        .run_multi_stream_selected(query, source_urls, page, on_batch)
        .await
}

pub(crate) fn parse_source_urls(json: &str) -> LegadoResult<Vec<String>> {
    if json.is_empty() {
        Ok(Vec::new())
    } else {
        serde_json::from_str(json)
            .map_err(|error| LegadoError::Ffi(format!("书源 URL 列表解析失败: {error}")))
    }
}

#[cfg(test)]
pub(crate) async fn search_single_source(
    client: &LegadoClient,
    source: &BookSource,
    keyword: &str,
    page: i32,
    precision: bool,
) -> LegadoResult<Vec<SearchResult>> {
    host_service()
        .search_single_source(client, source, keyword, page, precision)
        .await
}

pub fn aggregate_search_books_json(
    books_json: &str,
    key: &str,
    keep_other: bool,
) -> LegadoResult<String> {
    let books: Vec<CoreSearchBook> =
        serde_json::from_str(books_json).map_err(LegadoError::Serialization)?;
    let aggregated = search_aggregate::aggregate_search_books(&books, key, keep_other);
    let json = serde_json::to_string(&aggregated).map_err(LegadoError::Serialization)?;
    Ok(json)
}

#[cfg(test)]
mod p0_2_s2_tests {
    use super::*;

    fn mk_result(source: &str, name: &str, book_url: &str) -> SearchResult {
        SearchResult {
            source_url: source.to_string(),
            source_name: "src".into(),
            book_name: name.to_string(),
            author: String::new(),
            book_url: book_url.to_string(),
            latest_chapter: None,
            intro: None,
            cover_url: None,
            kind: None,
            word_count: None,
            book_type: 0,
            origin_order: 0,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        }
    }

    #[test]
    fn test_split_book_list_prefix_minus_reverses() {
        let (rule, reverse) = split_book_list_prefix("-.bookbox");
        assert_eq!(rule, ".bookbox");
        assert!(reverse);
    }

    #[test]
    fn test_split_book_list_prefix_plus_strips_only() {
        let (rule, reverse) = split_book_list_prefix("+.bookbox");
        assert_eq!(rule, ".bookbox");
        assert!(!reverse);
    }

    #[test]
    fn test_split_book_list_prefix_no_prefix_unchanged() {
        let (rule, reverse) = split_book_list_prefix(".bookbox");
        assert_eq!(rule, ".bookbox");
        assert!(!reverse);
    }

    #[test]
    fn test_dedup_keeps_first_occurrence() {
        let items = vec![
            mk_result("s1", "A", "u1"),
            mk_result("s1", "A", "u1"), // 重复（同 bookUrl）
            mk_result("s1", "B", "u2"),
            mk_result("s2", "A", "u1"), // [S0-E] 原版 SearchBook.equals 仅比较 bookUrl
                                        //（SearchBook.kt:65）→ 同 bookUrl 不同源亦去重
        ];
        let d = dedup_search_results_keep_first(items);
        assert_eq!(d.len(), 2);
        assert_eq!(d[0].book_name, "A");
        assert_eq!(d[1].book_name, "B");
    }

    #[test]
    fn test_dedup_preserves_order_and_empty() {
        let items = vec![
            mk_result("s", "X", "u1"),
            mk_result("s", "Y", "u2"),
            mk_result("s", "Z", "u3"),
        ];
        let d = dedup_search_results_keep_first(items);
        assert_eq!(
            d.iter().map(|r| r.book_name.clone()).collect::<Vec<_>>(),
            vec!["X".to_string(), "Y".to_string(), "Z".to_string()]
        );
        assert_eq!(dedup_search_results_keep_first(Vec::new()).len(), 0);
    }
}

#[cfg(test)]
mod s0e_tests {
    use super::*;
    // 仅 quickjs 门控测试使用（默认 cargo test 无该 feature，不门控会报未使用导入）
    #[cfg(feature = "quickjs")]
    use crate::api::web_book::RealBookSourceFetcher;
    use legado_core::models::rule::{BookInfoRule, SearchRule};

    fn mk_source(
        book_url: &str,
        pattern: Option<&str>,
        login_js: Option<&str>,
        rule_search: Option<SearchRule>,
    ) -> BookSource {
        BookSource {
            book_source_url: book_url.to_string(),
            book_source_name: "S0E-源".to_string(),
            book_url_pattern: pattern.map(|p| p.to_string()),
            login_check_js: login_js.map(|p| p.to_string()),
            rule_search,
            rule_book_info: Some(BookInfoRule {
                name: Some(".title".to_string()),
                author: Some(".author".to_string()),
                ..Default::default()
            }),
            ..BookSource::default()
        }
    }

    fn list_rules(book_list: &str) -> Option<SearchRule> {
        Some(SearchRule {
            book_list: Some(book_list.to_string()),
            name: Some(".name".to_string()),
            author: Some(".author".to_string()),
            book_url: Some("a@href".to_string()),
            ..Default::default()
        })
    }

    fn mk(source_url: &str, name: &str, book_url: &str) -> SearchResult {
        SearchResult {
            source_url: source_url.to_string(),
            source_name: "S0E-源".to_string(),
            book_name: name.to_string(),
            author: String::new(),
            book_url: book_url.to_string(),
            latest_chapter: None,
            intro: None,
            cover_url: None,
            kind: None,
            word_count: None,
            book_type: 0,
            origin_order: 0,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        }
    }

    const LIST_BODY: &str = r#"<html><body>
        <div class="book-item"><a class="name" href="/book/1">列表书A</a><span class="author">作者A</span></div>
        </body></html>"#;
    const DETAIL_BODY: &str = r#"<html><body>
        <div class="title">直连书名</div><div class="author">直连作者</div>
        </body></html>"#;

    /// BookList.kt:62-81：搜索 URL 命中 bookUrlPattern → 详情页直连单条
    #[test]
    fn test_s0e_pattern_direct_hit_parses_detail() {
        let source = mk_source(
            "https://ex.com",
            Some(r#"^https://ex\.com/book/\d+$"#),
            None,
            list_rules(".book-item"),
        );
        let results =
            parse_search_response(DETAIL_BODY, "https://ex.com/book/123", &source).unwrap();
        assert_eq!(results.len(), 1, "命中 pattern 应按详情解析出单条");
        assert_eq!(results[0].book_name, "直连书名");
        assert_eq!(results[0].book_url, "https://ex.com/book/123");
        assert_eq!(results[0].author, "直连作者");
    }

    /// BookList.kt:62-81：pattern 存在但不命中 → 继续走列表解析
    #[test]
    fn test_s0e_pattern_miss_continues_list_parse() {
        let source = mk_source(
            "https://ex.com",
            Some(r#"^https://ex\.com/book/\d+$"#),
            None,
            list_rules(".book-item"),
        );
        let results =
            parse_search_response(LIST_BODY, "https://ex.com/search?kw=x", &source).unwrap();
        assert_eq!(results.len(), 1, "pattern 不命中应正常走列表解析");
        assert_eq!(results[0].book_name, "列表书A");
    }

    /// BookList.kt:100-108：列表空且未配置 pattern → 按详情页规则回退一次
    #[test]
    fn test_s0e_empty_list_falls_back_to_detail() {
        let source = mk_source("https://ex.com", None, None, list_rules(".none"));
        let results = parse_search_response(DETAIL_BODY, "https://ex.com/s", &source).unwrap();
        assert_eq!(results.len(), 1, "空列表应回退详情解析");
        assert_eq!(results[0].book_name, "直连书名");
        assert_eq!(
            results[0].book_url, "https://ex.com/s",
            "回退 bookUrl=baseUrl"
        );
    }

    /// BookList.kt:100-108：pattern 已配置但不命中且列表空 → 不回退、返回空
    #[test]
    fn test_s0e_empty_list_with_pattern_no_fallback() {
        let source = mk_source(
            "https://ex.com",
            Some(r#"^https://ex\.com/book/\d+$"#),
            None,
            list_rules(".none"),
        );
        let results =
            parse_search_response(LIST_BODY, "https://ex.com/search?kw=x", &source).unwrap();
        assert!(results.is_empty(), "pattern 不命中且列表空 → 直接空结果");
    }

    /// SearchBook.kt:65：去重键 = bookUrl 单键（同名同 URL 不重复、同 URL 不同名也去重）
    #[test]
    fn test_s0e_dedup_key_is_book_url_only() {
        let items = vec![
            mk("s1", "甲", "https://ex.com/b/1"),
            mk("s1", "乙", "https://ex.com/b/1"), // 同 URL 不同名 → 去重
        ];
        let d = dedup_search_results_keep_first(items);
        assert_eq!(d.len(), 1);
        assert_eq!(d[0].book_name, "甲", "保留首次出现");
    }

    /// WebBook.kt:76-83：新语义下的「应通过」路径（quickjs，P3-6 A）：
    /// ① 裸 `result`（方法形对象）→ 完成值 `{}`（函数属性被 stringify 丢弃）
    ///    → 直通原始三元组；② JS 返回可 cast 的响应对象（三元表达式）
    ///    → 采用修改后的 body/url。旧谓词写法 `result.code() == 200`（裸布尔
    ///    完成值）在新语义下 cast 失败，不再构成通过路径（s0b 夹具
    ///    login_check_pass 已固化该场景为整源失败）
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_s0e_login_check_pass() {
        // ① 方法形 result 直通：JSON.stringify 丢弃函数属性 → "{}" → 原始三元组
        let source = mk_source("https://ex.com", None, Some("result"), None);
        let resp = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "ok",
            "https://ex.com/s",
            200,
        )
        .expect("方法形 result 应直通原始响应");
        assert_eq!(resp.code, 200);
        assert_eq!(resp.body, "ok", "直通应保留原始 body");
        assert_eq!(resp.url, "https://ex.com/s");

        // ② 可 cast 响应对象：三元 true 分支返回 {code, body, url} → 采用修改值
        let source2 = mk_source(
            "https://ex.com",
            None,
            Some(
                "result.code() == 200 ? { code: 200, body: 'new-body', url: 'https://ex.com/s2' } : false",
            ),
            None,
        );
        let resp2 = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source2,
            "ok",
            "https://ex.com/s",
            200,
        )
        .expect("可 cast 响应对象应通过");
        assert_eq!(resp2.body, "new-body", "应采用 JS 修改后的 body");
        assert_eq!(resp2.url, "https://ex.com/s2", "应采用 JS 修改后的 url");
    }

    /// WebBook.kt:88-90：首检未登录 + errResponse 二次 eval 仍未登录 → LoginRequired
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_s0e_login_check_required() {
        let source = mk_source("https://ex.com", None, Some("false"), None);
        let err = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "b",
            "https://ex.com/s",
            200,
        )
        .expect_err("false 应判定未登录");
        assert!(matches!(err, LegadoError::LoginRequired(_)));
    }

    /// WebBook.kt:84-95：errResponse 路径「恢复」→ 放行并采用二次结果
    /// （quickjs，P3-6 A）：首检（code 200）命中三元 false 分支 → 裸 false
    /// → cast 失败进入错误路径；二次 eval（errResponse code 500）命中 true
    /// 分支 → 返回对象 {code: 200} ≠ 500 → 放行采用二次结果（L88 块值
    /// 语义）。旧语义的字符串完成值（'false'/'ok'）在新语义下一律 cast
    /// 失败，本例改用可 cast 响应对象的 code!=500 放行场景（s0b 夹具
    /// login_check_second_adopt 固化同构场景）
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_s0e_login_check_err_path_recovers() {
        let source = mk_source(
            "https://ex.com",
            None,
            Some(
                "result.code() == 500 ? { code: 200, body: 'recovered', url: 'https://ex.com/s' } : false",
            ),
            None,
        );
        let resp = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "login-wall",
            "https://ex.com/s",
            200,
        )
        .expect("二次 eval 返回 code != 500 对象应放行");
        assert_eq!(resp.code, 200, "应采用二次结果的 code");
        assert_eq!(resp.body, "recovered", "应采用二次修改后的 body");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::SourceSearcher;
    use legado_core::models::rule::SearchRule;
    use legado_net::LegadoClientConfig;
    use legado_parser::RequestMethod;

    /// 构造带搜索规则的书源
    fn make_source_with_rules(
        book_list: &str,
        name: &str,
        author: &str,
        book_url: &str,
        cover_url: &str,
        intro: &str,
        last_chapter: &str,
    ) -> BookSource {
        BookSource {
            book_source_url: "https://www.example.com".to_string(),
            book_source_name: "测试书源".to_string(),
            search_url: Some("https://www.example.com/search?q={key}".to_string()),
            rule_search: Some(SearchRule {
                book_list: Some(book_list.to_string()),
                name: Some(name.to_string()),
                author: Some(author.to_string()),
                book_url: Some(book_url.to_string()),
                cover_url: Some(cover_url.to_string()),
                intro: Some(intro.to_string()),
                last_chapter: Some(last_chapter.to_string()),
                ..SearchRule::default()
            }),
            ..BookSource::default()
        }
    }

    /// P2-19 批3 接线回归：searchUrl 携带 `{"retry":2}` 时非 2xx/3xx 响应重发
    /// （前 2 次 500 → 第 3 次 200 成功）；服务器精确收到 3 次请求。
    #[test]
    fn test_search_single_source_consumes_retry_option() {
        use std::io::{Read, Write};
        use std::net::TcpListener;
        use std::sync::Arc;
        use std::sync::atomic::{AtomicUsize, Ordering};

        // 回环脚本服务器：前 2 次 500，第 3 次起 200 + 可解析 HTML
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind 回环服务器");
        let port = listener.local_addr().unwrap().port();
        let hits = Arc::new(AtomicUsize::new(0));
        let hits_srv = Arc::clone(&hits);
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(mut stream) = stream else { continue };
                let mut buf = Vec::new();
                let mut byte = [0u8; 1];
                while !buf.ends_with(b"\r\n\r\n") {
                    match stream.read(&mut byte) {
                        Ok(1) => buf.push(byte[0]),
                        _ => break,
                    }
                    if buf.len() > 16 * 1024 {
                        break;
                    }
                }
                let n = hits_srv.fetch_add(1, Ordering::SeqCst);
                let (status, body) = if n < 2 {
                    ("500 Internal Server Error", "boom".to_string())
                } else {
                    (
                        "200 OK",
                        r#"<html><body><div class="book"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div></body></html>"#.to_string(),
                    )
                };
                let resp = format!(
                    "HTTP/1.1 {status}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = stream.write_all(resp.as_bytes());
                let _ = stream.flush();
            }
        });

        let mut source = make_source_with_rules(
            ".book",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        source.book_source_url = format!("http://127.0.0.1:{port}");
        source.search_url = Some(format!("http://127.0.0.1:{port}/s,{{\"retry\":2}}"));

        let client = LegadoClient::new(LegadoClientConfig {
            no_proxy: true,
            ..LegadoClientConfig::default()
        })
        .unwrap();

        let results = crate::runtime::block_on(async {
            search_single_source(&client, &source, "斗破", 1, false).await
        })
        .expect("重发第 3 次应成功");

        assert_eq!(results.len(), 1, "应解析出 1 条结果");
        assert_eq!(results[0].book_name, "斗破苍穹");
        assert_eq!(
            hits.load(Ordering::SeqCst),
            3,
            "retry=2 → 服务器精确收到 3 次请求（2 次 500 + 1 次 200）"
        );
    }

    /// 测试用记录型 Cookie 持久化后端（写侧门控落库断言）
    #[derive(Default)]
    struct GateRecordingPersistence {
        data: std::sync::Mutex<std::collections::HashMap<String, String>>,
    }

    impl legado_net::CookiePersistence for GateRecordingPersistence {
        fn load_all(&self) -> Vec<(String, String)> {
            self.data
                .lock()
                .unwrap()
                .iter()
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect()
        }

        fn save(&self, tag: &str, cookie: &str) {
            self.data
                .lock()
                .unwrap()
                .insert(tag.to_string(), cookie.to_string());
        }
    }

    /// 搜索主链路写侧门控端到端（批 1，回环离线）：
    /// - 开（Some(true)）源 + Set-Cookie → 落库 + 读侧 DB cookie 注入 + 服务器
    ///   收到的头上无标记头（内部头已剥离）；
    /// - 关（Some(false)）源 → 不落库 + 读侧注入不变。
    #[test]
    fn test_search_single_source_cookie_jar_gate_end_to_end() {
        use std::io::{Read, Write};
        use std::net::TcpListener;

        /// 回环服务器：记录每个请求头全文，响应 200 + Set-Cookie + 可解析 HTML
        fn spawn_gate_server() -> (u16, Arc<std::sync::Mutex<Vec<String>>>) {
            let listener = TcpListener::bind("127.0.0.1:0").expect("bind 回环服务器");
            let port = listener.local_addr().unwrap().port();
            let seen = Arc::new(std::sync::Mutex::new(Vec::new()));
            let seen_srv = Arc::clone(&seen);
            std::thread::spawn(move || {
                for stream in listener.incoming() {
                    let Ok(mut stream) = stream else { continue };
                    let mut head: Vec<u8> = Vec::new();
                    let mut byte = [0u8; 1];
                    while !head.ends_with(b"\r\n\r\n") {
                        match stream.read(&mut byte) {
                            Ok(1) => head.push(byte[0]),
                            _ => break,
                        }
                        if head.len() > 16 * 1024 {
                            break;
                        }
                    }
                    if let Ok(mut guard) = seen_srv.lock() {
                        guard.push(String::from_utf8_lossy(&head).to_string());
                    }
                    let body = r#"<html><body><div class="book"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div></body></html>"#;
                    let resp = format!(
                        "HTTP/1.1 200 OK\r\nSet-Cookie: search_gate=on\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = stream.write_all(resp.as_bytes());
                    let _ = stream.flush();
                }
            });
            (port, seen)
        }

        fn make_source(port: u16, enabled: Option<bool>) -> BookSource {
            BookSource {
                book_source_url: format!("http://127.0.0.1:{port}"),
                book_source_name: "门控源".to_string(),
                search_url: Some(format!("http://127.0.0.1:{port}/s?q=searchKey")),
                rule_search: Some(SearchRule {
                    book_list: Some(".book".to_string()),
                    name: Some(".name".to_string()),
                    author: Some(".author".to_string()),
                    book_url: Some(".name@href".to_string()),
                    ..SearchRule::default()
                }),
                enabled_cookie_jar: enabled,
                ..BookSource::default()
            }
        }

        // ① 开：Some(true) → 落库；内部标记头必须在发送前剥离
        let (port_on, seen_on) = spawn_gate_server();
        let persistence_on = Arc::new(GateRecordingPersistence::default());
        persistence_on
            .data
            .lock()
            .unwrap()
            .insert("127.0.0.1".to_string(), "dbs_on=1".to_string());
        let client_on = LegadoClient::with_cookie_persistence(
            LegadoClientConfig {
                no_proxy: true,
                ..LegadoClientConfig::default()
            },
            persistence_on.clone(),
        )
        .unwrap();
        let source_on = make_source(port_on, Some(true));
        let results_on = crate::runtime::block_on(async {
            search_single_source(&client_on, &source_on, "斗破", 1, false).await
        })
        .expect("开启源搜索应成功");
        assert_eq!(results_on.len(), 1, "开启源应解析出 1 条结果");
        let saved_on = persistence_on
            .data
            .lock()
            .unwrap()
            .get("127.0.0.1")
            .cloned()
            .unwrap_or_default();
        assert!(
            saved_on.contains("search_gate=on"),
            "开启源搜索响应 Set-Cookie 必须落库: {saved_on:?}"
        );
        let head_on = seen_on
            .lock()
            .unwrap()
            .first()
            .cloned()
            .unwrap_or_default()
            .to_ascii_lowercase();
        assert!(
            !head_on.contains("cookiejar:"),
            "内部标记头不得发往真实服务器: {head_on}"
        );
        assert!(
            head_on.contains("cookie: dbs_on=1"),
            "读侧 DB cookie 注入不受门控影响: {head_on}"
        );

        // ② 关：Some(false) → 不落库；读侧注入不变
        let (port_off, seen_off) = spawn_gate_server();
        let persistence_off = Arc::new(GateRecordingPersistence::default());
        persistence_off
            .data
            .lock()
            .unwrap()
            .insert("127.0.0.1".to_string(), "dbs_off=1".to_string());
        let client_off = LegadoClient::with_cookie_persistence(
            LegadoClientConfig {
                no_proxy: true,
                ..LegadoClientConfig::default()
            },
            persistence_off.clone(),
        )
        .unwrap();
        let source_off = make_source(port_off, Some(false));
        let results_off = crate::runtime::block_on(async {
            search_single_source(&client_off, &source_off, "斗破", 1, false).await
        })
        .expect("关闭源搜索应成功");
        assert_eq!(results_off.len(), 1, "关闭源应解析出 1 条结果");
        let saved_off = persistence_off
            .data
            .lock()
            .unwrap()
            .get("127.0.0.1")
            .cloned()
            .unwrap_or_default();
        assert_eq!(saved_off, "dbs_off=1", "关闭源搜索响应 Set-Cookie 不得落库");
        let head_off = seen_off
            .lock()
            .unwrap()
            .first()
            .cloned()
            .unwrap_or_default()
            .to_ascii_lowercase();
        assert!(
            !head_off.contains("cookiejar:"),
            "关闭源不得出现内部标记头: {head_off}"
        );
        assert!(
            head_off.contains("cookie: dbs_off=1"),
            "关闭源读侧 DB cookie 仍必须注入: {head_off}"
        );
    }

    /// [P2-19 尾项] 回环单响应搜索：`body_bytes` 原样返回（可为非 UTF-8 字节），
    /// `content_type` 决定响应头，`search_url_suffix` 追加 urlOption（如
    /// `,{"charset":"gbk"}`）。返回解析后的搜索结果（响应体走真实四级解码链）。
    fn search_loopback(
        body_bytes: Vec<u8>,
        content_type: &str,
        search_url_suffix: &str,
    ) -> Vec<SearchResult> {
        use std::io::{Read, Write};
        use std::net::TcpListener;

        let listener = TcpListener::bind("127.0.0.1:0").expect("bind 回环服务器");
        let port = listener.local_addr().unwrap().port();
        let content_type = content_type.to_string();
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(mut stream) = stream else { continue };
                let mut head: Vec<u8> = Vec::new();
                let mut byte = [0u8; 1];
                while !head.ends_with(b"\r\n\r\n") {
                    match stream.read(&mut byte) {
                        Ok(1) => head.push(byte[0]),
                        _ => break,
                    }
                    if head.len() > 16 * 1024 {
                        break;
                    }
                }
                let resp = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    body_bytes.len()
                );
                let _ = stream.write_all(resp.as_bytes());
                let _ = stream.write_all(&body_bytes);
                let _ = stream.flush();
            }
        });

        let mut source = make_source_with_rules(
            ".book",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        source.book_source_url = format!("http://127.0.0.1:{port}");
        source.search_url = Some(format!("http://127.0.0.1:{port}/s{search_url_suffix}"));

        let client = LegadoClient::new(LegadoClientConfig {
            no_proxy: true,
            ..LegadoClientConfig::default()
        })
        .unwrap();

        crate::runtime::block_on(async {
            search_single_source(&client, &source, "斗破", 1, false).await
        })
        .expect("搜索应成功")
    }

    /// [P2-19 尾项 a] 搜索链四级解码：仅 HTML meta 声明 GBK（Content-Type 无
    /// charset）。改前非 explicit 分支走 reqwest `.text()`（只认 Content-Type）
    /// → UTF-8 lossy 书名乱码；修复后经 meta 级按 GBK 正确解码。
    #[test]
    fn test_search_single_source_decodes_meta_only_gbk() {
        let html = r#"<html><head><meta charset="gbk"></head><body><div class="book"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div></body></html>"#;
        let (bytes, _, _) = encoding_rs::GBK.encode(html);

        let results = search_loopback(bytes.into_owned(), "text/html", "");

        assert_eq!(results.len(), 1, "meta-only GBK 页应解析出 1 条");
        assert_eq!(
            results[0].book_name, "斗破苍穹",
            "meta charset=gbk 应被采纳"
        );
        assert_eq!(results[0].author, "天蚕土豆");
    }

    /// [P2-19 尾项 b] 四级全无标识（无显式 / 无 Content-Type charset / 无 meta）
    /// 的 GBK 搜索页经 chardetng 统计探测救回。
    #[test]
    fn test_search_single_source_detects_undeclared_gbk() {
        let html = r#"<html><body><div class="book"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div><p>第一章 陨落的天才，这里是没有任何编码标识的中文搜索页，斗气大陆强者如云。</p></body></html>"#;
        let (bytes, _, _) = encoding_rs::GBK.encode(html);

        let results = search_loopback(bytes.into_owned(), "text/html", "");

        assert_eq!(results.len(), 1, "无标识 GBK 页应解析出 1 条");
        assert_eq!(
            results[0].book_name, "斗破苍穹",
            "第四级探测应救回 GBK 书名"
        );
        assert_eq!(results[0].author, "天蚕土豆");

        // [P2-19 尾项审查 P2-3] 负向锚：同字节的 lossy UTF-8（改前 reqwest
        // 路径的代表性输出）会产出乱码书名；探测退化回 lossy 时该断言先失败，
        // 防止正向断言被巧合满足
        let (gbk_name, _, _) = encoding_rs::GBK.encode("斗破苍穹");
        let lossy_name = String::from_utf8_lossy(&gbk_name).into_owned();
        assert_ne!(
            results[0].book_name, lossy_name,
            "第四级探测不得退化回 lossy UTF-8"
        );
    }

    /// [P2-19 尾项 c] 对抗：urlOption 显式 charset=gbk，但字节实为 UTF-8——
    /// 必须按显式声明以 GBK 解释（探测/meta/头不得覆盖；对齐上游 encode 参数
    /// 最高优先）。
    #[test]
    fn test_search_single_source_explicit_charset_wins_over_detection() {
        let html = r#"<html><body><div class="book"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div></body></html>"#;
        let (expected_name, _, _) = encoding_rs::GBK.decode("斗破苍穹".as_bytes());
        let (expected_author, _, _) = encoding_rs::GBK.decode("天蚕土豆".as_bytes());

        let results = search_loopback(
            html.as_bytes().to_vec(),
            "text/html",
            r#",{"charset":"gbk"}"#,
        );

        assert_eq!(results.len(), 1);
        assert_eq!(
            results[0].book_name, expected_name,
            "显式 charset=gbk 应优先于 UTF-8 探测结果"
        );
        assert_eq!(results[0].author, expected_author);
        assert_ne!(results[0].book_name, "斗破苍穹", "不得被探测按 UTF-8 覆盖");
    }

    /// [P2-19 尾项 d] 无标识合法 UTF-8 搜索页无回归（探测允许 UTF-8：
    /// 行为与改前 reqwest `.text()` 的 UTF-8 解码逐字一致）。
    #[test]
    fn test_search_single_source_utf8_undeclared_no_regression() {
        let html = r#"<html><body><div class="book"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div></body></html>"#;

        let results = search_loopback(html.as_bytes().to_vec(), "text/html", "");

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].book_name, "斗破苍穹");
        assert_eq!(results[0].author, "天蚕土豆");
    }

    /// [P2-19 尾项审查 P2-1] 302 → 目标 GBK 页：统一 send_raw 后下游解析基于
    /// 重定向后 final_url（`raw.url`）。断言两件事：1) 目标页无编码标识 GBK
    /// 经四级链正确解码；2) 结果相对链接以 final_url 为基解析——bookUrl 落在
    /// `/target/` 下，而非原请求路径 `/s` 的目录（改前文本分支同样基于
    /// response.url，属改善但此前未钉住）。
    #[test]
    fn test_search_single_source_uses_final_url_after_redirect() {
        use std::io::{Read, Write};
        use std::net::TcpListener;

        let (gbk_bytes, _, _) = encoding_rs::GBK.encode(
            r#"<html><body><div class="book"><a class="name" href="b/1">斗破苍穹</a><span class="author">天蚕土豆</span></div></body></html>"#,
        );
        let gbk_bytes = gbk_bytes.into_owned();

        let listener = TcpListener::bind("127.0.0.1:0").expect("bind 回环服务器");
        let port = listener.local_addr().unwrap().port();
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(mut stream) = stream else { continue };
                let mut head: Vec<u8> = Vec::new();
                let mut byte = [0u8; 1];
                while !head.ends_with(b"\r\n\r\n") {
                    match stream.read(&mut byte) {
                        Ok(1) => head.push(byte[0]),
                        _ => break,
                    }
                    if head.len() > 16 * 1024 {
                        break;
                    }
                }
                let head_str = String::from_utf8_lossy(&head);
                let path = head_str.split_whitespace().nth(1).unwrap_or("").to_string();
                let (resp, payload): (String, Vec<u8>) = if path == "/s" {
                    (
                        "HTTP/1.1 302 Found\r\nLocation: /target/gbk\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                            .to_string(),
                        Vec::new(),
                    )
                } else {
                    (
                        format!(
                            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            gbk_bytes.len()
                        ),
                        gbk_bytes.clone(),
                    )
                };
                let _ = stream.write_all(resp.as_bytes());
                let _ = stream.write_all(&payload);
                let _ = stream.flush();
            }
        });

        let mut source = make_source_with_rules(
            ".book",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        source.book_source_url = format!("http://127.0.0.1:{port}");
        source.search_url = Some(format!("http://127.0.0.1:{port}/s"));

        let client = LegadoClient::new(LegadoClientConfig {
            no_proxy: true,
            ..LegadoClientConfig::default()
        })
        .unwrap();

        let results = crate::runtime::block_on(async {
            search_single_source(&client, &source, "斗破", 1, false).await
        })
        .expect("302 后目标页搜索应成功");

        assert_eq!(results.len(), 1, "302 后目标 GBK 页应解析出 1 条");
        assert_eq!(
            results[0].book_name, "斗破苍穹",
            "重定向后目标页应经探测正确解码"
        );
        assert_eq!(
            results[0].book_url,
            format!("http://127.0.0.1:{port}/target/b/1"),
            "相对链接应以最终 URL（/target/gbk）为基解析"
        );
    }

    #[test]
    fn test_parse_origin_order_from_custom_order() {
        // [P0-2 S4 | BookList.kt:215] originOrder 必须来自 source.customOrder（非默认 0）
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name" href="/book/1">斗破苍穹</a>
                <span class="author">天蚕土豆</span>
            </div>
        </body></html>"#;
        let mut source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        source.custom_order = 7;
        let results =
            parse_search_response(html, "https://www.example.com/search?q=test", &source).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].origin_order, 7);
    }

    #[test]
    fn test_result_to_search_book_preserves_origin_order() {
        // [P0-2 S4] DTO 转换必须透传真实 originOrder（原恒写 0）
        let r = SearchResult {
            source_url: "https://s.example.com".into(),
            source_name: "src".into(),
            book_name: "book".into(),
            author: "a".into(),
            book_url: "https://s.example.com/b/1".into(),
            latest_chapter: None,
            intro: None,
            cover_url: None,
            kind: None,
            word_count: None,
            book_type: 0,
            origin_order: 5,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        };
        let core = result_to_search_book(r);
        assert_eq!(core.origin_order, 5);
    }

    #[test]
    fn test_annotated_candidate_json_carries_origin_order() {
        // [STAGE4-P36] 跨源候选 originOrder 契约：multi_source_search 输出 DTO
        // （AnnotatedCandidate）必须像 SearchResult 一样携带 originOrder
        // （source.customOrder，BookList.kt:215）。模拟三个源按出现序
        // customOrder 0/1/2 → 首源 0、后续按出现序 1、2
        let index = ReadRecordIndex::of(Vec::new());
        let results = vec![
            result_with_origin_order("首源", "http://s1.example.com", "书甲", 0),
            result_with_origin_order("次源", "http://s2.example.com", "书乙", 1),
            result_with_origin_order("三源", "http://s3.example.com", "书丙", 2),
        ];
        let annotated: Vec<AnnotatedCandidate> = results
            .into_iter()
            .map(|c| build_annotated_candidate(c, &index))
            .collect();
        let json = serde_json::to_value(&annotated).expect("序列化成功");
        let arr = json.as_array().expect("JSON 数组");
        assert_eq!(arr.len(), 3);
        assert_eq!(json[0]["originOrder"], serde_json::json!(0));
        assert_eq!(json[1]["originOrder"], serde_json::json!(1));
        assert_eq!(json[2]["originOrder"], serde_json::json!(2));
        // 原有契约字段不回归
        assert_eq!(json[0]["book_name"], serde_json::json!("书甲"));
        assert_eq!(
            json[1]["source_url"],
            serde_json::json!("http://s2.example.com")
        );
    }

    /// 构造指定书源/originOrder 的 SearchResult（originOrder 契约测试用）
    fn result_with_origin_order(
        source_name: &str,
        source_url: &str,
        book_name: &str,
        origin_order: i32,
    ) -> SearchResult {
        SearchResult {
            source_url: source_url.to_string(),
            source_name: source_name.to_string(),
            book_name: book_name.to_string(),
            author: "作者".to_string(),
            book_url: format!("{source_url}/book/1"),
            latest_chapter: None,
            intro: None,
            cover_url: None,
            kind: None,
            word_count: None,
            book_type: book_type::TEXT,
            origin_order,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        }
    }

    #[test]
    fn test_parse_html_search_results() {
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name" href="/book/1">斗破苍穹</a>
                <span class="author">天蚕土豆</span>
                <img class="cover" src="/covers/1.jpg" />
                <p class="intro">这里是简介</p>
                <span class="last">第100章 大结局</span>
            </div>
            <div class="book-item">
                <a class="name" href="/book/2">凡人修仙传</a>
                <span class="author">忘语</span>
                <img class="cover" src="/covers/2.jpg" />
                <p class="intro">修仙之路</p>
                <span class="last">第200章 飞升</span>
            </div>
        </body></html>"#;

        let source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );

        let results =
            parse_search_response(html, "https://www.example.com/search?q=test", &source).unwrap();

        assert_eq!(results.len(), 2);

        // 验证第一条结果
        assert_eq!(results[0].book_name, "斗破苍穹");
        assert_eq!(results[0].author, "天蚕土豆");
        assert_eq!(results[0].book_url, "https://www.example.com/book/1");
        assert_eq!(
            results[0].cover_url,
            Some("https://www.example.com/covers/1.jpg".to_string())
        );
        assert_eq!(results[0].intro, Some("这里是简介".to_string()));
        assert_eq!(
            results[0].latest_chapter,
            Some("第100章 大结局".to_string())
        );
        assert_eq!(results[0].source_url, "https://www.example.com");
        assert_eq!(results[0].source_name, "测试书源");

        // 验证第二条结果
        assert_eq!(results[1].book_name, "凡人修仙传");
        assert_eq!(results[1].author, "忘语");
        assert_eq!(results[1].book_url, "https://www.example.com/book/2");
    }

    /// 搜索解析须清洗书名/作者（对齐 BookList + BookHelp），否则 mergeItems 聚合键分裂
    #[test]
    fn test_parse_search_formats_name_author() {
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name" href="/book/1">斗破苍穹 作者天蚕土豆</a>
                <span class="author">作者：天蚕土豆</span>
            </div>
            <div class="book-item">
                <a class="name" href="/book/2">斗破苍穹</a>
                <span class="author">天蚕土豆 著</span>
            </div>
        </body></html>"#;

        let source = make_source_with_rules(
            ".book-item",
            ".name@text",
            ".author@text",
            "a@href",
            "img@src",
            ".intro@text",
            ".latest@text",
        );

        let results =
            parse_search_response(html, "https://www.example.com/search?q=test", &source).unwrap();
        assert_eq!(results.len(), 2);
        assert_eq!(results[0].book_name, "斗破苍穹");
        assert_eq!(results[0].author, "天蚕土豆");
        assert_eq!(results[1].book_name, "斗破苍穹");
        assert_eq!(results[1].author, "天蚕土豆");
    }

    // ─── 测试 1.1: bookUrl 规则为空时回退 baseUrl（对齐原版 BookList.kt）───

    #[test]
    fn test_parse_html_book_url_empty_falls_back_to_base() {
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name">斗破苍穹</a>
                <span class="author">天蚕土豆</span>
            </div>
        </body></html>"#;
        // bookUrl 规则指向不存在的属性 → 解析为空串
        let source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            ".missing-attr@href",
            "",
            "",
            "",
        );

        let results =
            parse_search_response(html, "https://www.example.com/search?q=test", &source).unwrap();

        assert_eq!(results.len(), 1);
        // [S0-E] 空 bookUrl 回退 baseUrl（=传入的最终搜索页 URL，BookList.kt:281-284）
        assert_eq!(results[0].book_url, "https://www.example.com/search?q=test");
    }

    // ─── 测试 1.2: 请求头缺 UA 时补充 Chrome UA ───────────────────────────────

    #[test]
    fn test_ensure_default_user_agent_adds_when_missing() {
        let mut headers = HashMap::new();
        headers.insert("Referer".to_string(), "https://www.example.com".to_string());
        ensure_default_user_agent(&mut headers);
        assert!(
            headers
                .get("User-Agent")
                .unwrap()
                .starts_with("Mozilla/5.0")
        );
    }

    #[test]
    fn test_ensure_default_user_agent_keeps_source_ua() {
        // 书源 header 已配置 UA（含小写键名）时不覆盖
        let mut headers = HashMap::new();
        headers.insert("user-agent".to_string(), "CustomMobile/1.0".to_string());
        ensure_default_user_agent(&mut headers);
        assert_eq!(headers.get("user-agent").unwrap(), "CustomMobile/1.0");
        assert!(headers.keys().all(|k| k != "User-Agent"));
    }

    /// 跨 crate 不变式：FFI 主链路注入的缺省 UA 与 JS 桥共享客户端池
    /// （legado-net `LegadoClientConfig::default`，四池配置逐项派生自 Default）
    /// 完全同串——两客户端同 UA 指纹，WAF 与 UA 绑定的 cookie（report_d）
    /// 才能跨层复用；任一侧字面量漂移此测试必红
    #[test]
    fn test_default_user_agent_matches_net_client_default() {
        let mut headers = HashMap::new();
        ensure_default_user_agent(&mut headers);
        assert_eq!(
            headers.get("User-Agent").map(String::as_str),
            Some(legado_net::client::DEFAULT_USER_AGENT),
            "ensure_default_user_agent 注入的 UA 必须引用共享常量"
        );
        assert_eq!(
            legado_net::client::LegadoClientConfig::default().user_agent,
            legado_net::client::DEFAULT_USER_AGENT,
            "JS 桥池缺省 UA（LegadoClientConfig::default）必须与主链路同串"
        );
    }

    // ─── 测试 1.5: sto66 真实响应体复现（XPath bookList + ## 替换）───────────

    /// Task #30 复现：sto66.com 搜索页（真实结构：无引号属性、未闭合 meta/link、
    /// 内嵌脚本），ruleSearch 为 XPath 规则且带 `##` 替换后缀。
    /// 修复前：严格 XML 解析失败→bookList 0 条；修复后：应解析出 >0 条。
    #[test]
    fn test_parse_sto66_real_response_xpath() {
        // 真实响应体片段（取自 https://www.sto66.com/search/99.html，保留致 XML 解析失败的特征）
        let html = "<!DOCTYPE html>\n<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"zh-CN\">\
            <head><title>搜索:99-思绪阅读</title>\
            <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>\
            <meta name=\"viewport\" content=\"width=device-width\">\
            <link rel=\"icon\" href=\"/sto/images/app-icon72x72.png\">\
            <script src=\"/sto/js/default.js\" type=\"text/javascript\"></script>\
            </head><body>\
            <div class=header-left><a href=\"/\" class=\"logo\">思绪阅读</a></div>\
            <div class=\"bookbox\"><div class=\"p10\"><span class=\"num\">1</span>\
            <div class=\"bookinfo\"><h2 class=\"bookname\">\
            <a href=\"/book/26zvJv0kmLb9N2oyvORpxn.html\">重案1990</a></h2>\
            <div class=\"author\">作者：高山流水</div>\
            <div class=\"author\">字数：125.6万</div>\
            <div class=\"cat\"><span>现代都市</span>\
            <a href=\"/chapter/26zvJv0kmLb9N2oyvORpxn/2FqUlMjy8jQylEJA0rygGF.html\">第353章 大结局</a></div>\
            <div class=\"update\"><span>简介：</span>重回1990年的刑侦故事</div>\
            </div><div class=\"delbutton\">\
            <a class=\"del_but\" href=\"/book/26zvJv0kmLb9N2oyvORpxn.html\">阅读</a>\
            </div></div></div>\
            <div class=\"bookbox\"><div class=\"p10\"><span class=\"num\">2</span>\
            <div class=\"bookinfo\"><h2 class=\"bookname\">\
            <a href=\"/book/63c1MuMNVQJEGWKNltSyG8.html\">全能魔女1994</a></h2>\
            <div class=\"author\">作者：云中鹤</div>\
            <div class=\"author\">字数：411.5万</div>\
            <div class=\"cat\"><span>现代都市</span>\
            <a href=\"/chapter/63c1MuMNVQJEGWKNltSyG8/6nthAhzx8ioLiPhVN4roWq.html\">第一章 重生</a></div>\
            <div class=\"update\"><span>简介：</span>魔女重生的故事</div>\
            </div><div class=\"delbutton\">\
            <a class=\"del_but\" href=\"/book/63c1MuMNVQJEGWKNltSyG8.html\">阅读</a>\
            </div></div></div>\
            <div class=\"clear\"></div>\
            <div class=\"pages\"><div class=\"pagelink\">\
            <em id=\"pagestats\">1/6</em><a href=\"/search/99/2.html\">2</a>\
            </div></div></body></html>";

        // sto66 真实 ruleSearch（设备 DB 抓取）
        let source = BookSource {
            book_source_url: "https://www.sto66.com".to_string(),
            book_source_name: "思绪阅读".to_string(),
            rule_search: Some(SearchRule {
                book_list: Some("//*[contains(@class, 'bookbox')]".to_string()),
                name: Some("@XPath:.//*[contains(@class, 'bookname')]/a/text()".to_string()),
                author: Some(
                    "@XPath:.//*[contains(@class, 'author')][1]/text()##作者：".to_string(),
                ),
                book_url: Some("@XPath:.//*[contains(@class, 'bookname')]/a/@href".to_string()),
                intro: Some("@XPath:.//*[contains(@class, 'update')]//text()##简介：".to_string()),
                last_chapter: Some("@XPath:.//*[contains(@class, 'cat')]//a/text()".to_string()),
                ..SearchRule::default()
            }),
            ..BookSource::default()
        };

        let results =
            parse_search_response(html, "https://www.sto66.com/search/99.html", &source).unwrap();

        assert!(
            results.len() >= 2,
            "bookList 应解析出 ≥2 条，实际 {} 条",
            results.len()
        );
        assert_eq!(results[0].book_name, "重案1990");
        // ## 替换：作者前缀应被剔除
        assert_eq!(results[0].author, "高山流水");
        // 相对 URL 绝对化
        assert_eq!(
            results[0].book_url,
            "https://www.sto66.com/book/26zvJv0kmLb9N2oyvORpxn.html"
        );
        assert_eq!(
            results[0].latest_chapter,
            Some("第353章 大结局".to_string())
        );
        // ## 替换：简介前缀应被剔除（//text() 多节点按原版以换行连接，trim 后比较）
        assert_eq!(
            results[0].intro.as_deref().map(str::trim),
            Some("重回1990年的刑侦故事")
        );
        assert_eq!(results[1].book_name, "全能魔女1994");
        assert_eq!(results[1].author, "云中鹤");
    }

    // ─── 测试 1.6: 多源并发驱动器（异常隔离 + 限流 + 超时）───────────────

    /// Task #31：多源并发搜索语义——部分源成功/部分源失败/超时/panic 时，
    /// 成功源结果全部保留、失败源不阻断、并发数不超过上限。
    #[tokio::test]
    async fn test_drive_source_batches_isolation_concurrency_timeout() {
        use std::sync::atomic::AtomicUsize;

        let active = Arc::new(AtomicUsize::new(0));
        let max_active = Arc::new(AtomicUsize::new(0));

        let sources: Vec<BookSource> = ["ok1", "ok2", "fail", "slow", "panic"]
            .into_iter()
            .map(|u| BookSource {
                book_source_url: format!("https://{u}.example.com"),
                book_source_name: format!("源{u}"),
                ..BookSource::default()
            })
            .collect();

        let active_c = Arc::clone(&active);
        let max_c = Arc::clone(&max_active);
        let search_one = move |source: BookSource| {
            let active = Arc::clone(&active_c);
            let max_active = Arc::clone(&max_c);
            async move {
                let cur = active.fetch_add(1, Ordering::SeqCst) + 1;
                max_active.fetch_max(cur, Ordering::SeqCst);
                let url = source.book_source_url.clone();
                let name = source.book_source_name.clone();
                let result = if url.contains("slow") {
                    // 超过单源超时（500ms）→ 应被驱动器判为超时错误
                    tokio::time::sleep(Duration::from_secs(5)).await;
                    Ok(Vec::new())
                } else if url.contains("panic") {
                    panic!("故意 panic：验证单源崩溃隔离");
                } else if url.contains("fail") {
                    Err(LegadoError::Network("故意失败".into()))
                } else {
                    Ok(vec![SearchResult {
                        source_url: url.clone(),
                        source_name: name.clone(),
                        book_name: format!("书{name}"),
                        author: "作者".into(),
                        book_url: format!("{url}/book/1"),
                        variable: None,
                        latest_chapter: None,
                        intro: None,
                        cover_url: None,
                        kind: None,
                        word_count: None,
                        book_type: book_type::TEXT,
                        origin_order: 0,
                        has_read_record: false,
                        read_record_author: None,
                    }])
                };
                // 持有并发窗口一小段时间，使最大并发观测可靠
                tokio::time::sleep(Duration::from_millis(50)).await;
                active.fetch_sub(1, Ordering::SeqCst);
                result
            }
        };

        let outcomes = Arc::new(std::sync::Mutex::new(Vec::new()));
        let outcomes_c = Arc::clone(&outcomes);
        drive_source_batches(
            sources,
            2,
            Duration::from_millis(500),
            &std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            &std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            search_one,
            move |o| {
                let (n, err) = match o.result {
                    Ok(ref b) => (Some(b.len()), None),
                    Err(ref e) => (None, Some(e.to_string())),
                };
                outcomes_c.lock().unwrap().push((
                    o.source_url,
                    n,
                    err,
                    o.finished_count,
                    o.total_count,
                ));
                Ok(())
            },
        )
        .await;

        let got = outcomes.lock().unwrap();
        assert_eq!(
            got.len(),
            5,
            "每个书源都应产出一个批次（含失败/超时/panic）"
        );
        // 成功源结果全部保留
        let ok_books: usize = got.iter().filter_map(|(_, n, _, _, _)| *n).sum();
        assert_eq!(ok_books, 2, "两个成功源各 1 本书应全部保留");
        // 失败/超时/panic 均有错误信息且不阻断其他源
        assert!(
            got.iter()
                .any(|(u, _, e, _, _)| u.contains("fail") && e.is_some())
        );
        assert!(got.iter().any(|(u, _, e, _, _)| u.contains("slow")
            && e.as_deref().is_some_and(|m| m.contains("超时"))));
        assert!(
            got.iter()
                .any(|(u, _, e, _, _)| u.contains("panic") && e.is_some())
        );
        // 进度 total 正确且存在收尾批次（finished == total）
        assert!(got.iter().all(|(_, _, _, _, t)| *t == 5));
        assert!(got.iter().any(|(_, _, _, f, t)| f == t));
        // 并发上限：最大同时在跑的单源搜索不超过 2
        assert!(
            max_active.load(Ordering::SeqCst) <= 2,
            "最大并发 {} 超过上限 2",
            max_active.load(Ordering::SeqCst)
        );
    }

    /// 队列④②：JS 引擎错误必须经现有搜索批次错误通道可见
    ///
    /// searchUrl / bookList 的 JS 失败现统一包成 `LegadoError::JsEngine`
    ///（此前 searchUrl 失败包成 `Internal`，被误分类为 `parser_error`）：
    /// 批次 `error_class` 保持既有映射 `js_error`（契约未变），`error` 字段
    /// 携带可读原因（如「decode is not defined」），搜索结果里直接可见。
    /// 本测试无网络，按驱动器层既有模式断言分类与错误文本的传递。
    #[tokio::test]
    async fn test_js_engine_error_surfaces_via_batch_channel() {
        const MSG: &str = "searchUrl JS 求值失败: decode is not defined";

        // 1) 分类映射：JsEngine → js_error（search.rs 既有映射，契约未变）
        let classified =
            classify_source_outcome(&LegadoResult::Err(LegadoError::JsEngine(MSG.into())));
        assert_eq!(
            classified, "js_error",
            "JsEngine 错误应归类 js_error（而非 parser_error）"
        );

        // 2) 批次 error 字段携带可读文案（SearchSourceBatch.error = e.to_string()）
        let (books, error) =
            match LegadoResult::<Vec<SearchResult>>::Err(LegadoError::JsEngine(MSG.into())) {
                Ok(list) => (list, None),
                Err(e) => (Vec::new(), Some(e.to_string())),
            };
        assert!(books.is_empty(), "失败源书目应为空");
        assert!(
            error.as_deref().is_some_and(|m| m.contains(MSG)),
            "批次 error 字段应含可读原因: {error:?}"
        );

        // 3) 驱动器层：单源 JS 失败不阻断批次，on_source 回调收到错误文本
        let sources = vec![BookSource {
            book_source_url: "https://favcomic.test".into(),
            book_source_name: "favcomic".into(),
            ..BookSource::default()
        }];
        let outcomes = Arc::new(std::sync::Mutex::new(Vec::new()));
        let outcomes_c = Arc::clone(&outcomes);
        drive_source_batches(
            sources,
            1,
            Duration::from_millis(500),
            &Arc::new(std::sync::atomic::AtomicBool::new(false)),
            &Arc::new(std::sync::atomic::AtomicBool::new(false)),
            |_s: BookSource| async move {
                Err(LegadoError::JsEngine(
                    "searchUrl JS 求值失败: decode is not defined".into(),
                ))
            },
            move |o: SourceBatchOutcome<SearchResult>| {
                let (n, err) = match &o.result {
                    Ok(b) => (Some(b.len()), None),
                    Err(e) => (None, Some(e.to_string())),
                };
                outcomes_c.lock().unwrap().push((o.source_url, n, err));
                Ok(())
            },
        )
        .await;
        let got = outcomes.lock().unwrap();
        assert_eq!(got.len(), 1, "失败源也应产出一个批次");
        let (url, n, err) = &got[0];
        assert!(url.contains("favcomic.test"));
        assert_eq!(*n, None, "失败源应无书目");
        assert!(
            err.as_deref()
                .is_some_and(|m| m.contains("decode is not defined")),
            "批次回调 error 应含可读原因: {err:?}"
        );
    }

    /// 队列④ P2-D：bookList 提取错误放行面收窄的三态行为
    ///
    /// 1) JS 求值失败（JsEngine）→ 加「搜索结果列表解析失败」前缀后上抛
    ///    → 整源失败（search_single_source 经 `?` 上抛，批次 error 通道可见）；
    /// 2) 合法无命中（Ok 空列表）→ 仍为 empty（非错误，S0-E 回退可达）；
    /// 3) 非 JS 错误（Parser 等）→ 维持既有吞错语义 → 空列表（整源不失败，
    ///    S0-E 空列表详情回退路径保持可达）。
    #[test]
    fn test_book_list_elements_error_class_narrowing() {
        // 1) bookList JS 失败 → 整源 Err（JsEngine 加前缀上抛）
        let r = book_list_elements_or_default(Err(LegadoError::JsEngine(
            "decode is not defined".into(),
        )));
        match r {
            Err(LegadoError::JsEngine(m)) => assert!(
                m.starts_with("搜索结果列表解析失败: "),
                "JsEngine 错误应加前缀后上抛: {m}"
            ),
            other => panic!("JsEngine 错误应上抛（整源失败），实际: {other:?}"),
        }

        // 2) 合法无命中 → 仍为 empty（非错误；批次分类即 "empty"）
        let empty = book_list_elements_or_default(Ok(Vec::<String>::new())).unwrap();
        assert!(
            empty.is_empty(),
            "合法无命中应保持空列表（error_class=empty）"
        );
        assert_eq!(
            classify_source_outcome(&Ok(Vec::<SearchResult>::new())),
            "empty",
            "合法无命中经批次分类仍为 empty"
        );

        // 3) 非 JS 错误维持吞错语义 → 空列表（整源不失败）
        let swallowed =
            book_list_elements_or_default(Err(LegadoError::Parser("XPath 解析失败".into())))
                .unwrap();
        assert!(
            swallowed.is_empty(),
            "非 JS 错误应吞为 empty 空列表（S0-E 回退可达），不得整源失败"
        );
    }

    // ─── P0-3 真实重叠压力测试（复审 7.3）：A 运行中被取代 → A 中止（排队源不发请求、
    //     在飞结果不交付 on_source），B 干净执行。取消标志直接置位模拟「register(B) 取消 A」，
    //     使用实例控制器，与并发测试隔离。──
    #[tokio::test]
    async fn test_search_overlap_a_replaced_by_b() {
        use std::sync::atomic::AtomicUsize;

        // A：concurrency=2 → 前 2 源在飞（sleep 阻塞），后 3 源排队
        let a_started = Arc::new(AtomicUsize::new(0)); // A 已发起请求的源数
        let a_delivered = Arc::new(AtomicUsize::new(0)); // A on_source 交付次数（取消后应为 0）
        let searches = Arc::new(legado_engine::SearchTasks::new(
            legado_engine::TaskGroup::default(),
        ));
        let session_a = searches.start().unwrap();

        let search_one_a = {
            let c = Arc::clone(&a_started);
            move |_s: BookSource| {
                let cc = Arc::clone(&c);
                async move {
                    cc.fetch_add(1, Ordering::SeqCst);
                    // 模拟「在飞」：阻塞一段时间（被 abort 前不会自行结束）
                    tokio::time::sleep(Duration::from_millis(300)).await;
                    Ok(Vec::new())
                }
            }
        };
        let sources_a: Vec<BookSource> = (1..=5)
            .map(|i| BookSource {
                book_source_url: format!("https://a{i}.example.com"),
                ..BookSource::default()
            })
            .collect();

        // 在独立任务中运行 A（与 B 真正并发）；on_source 记录交付次数
        let a_delivered_c = Arc::clone(&a_delivered);
        let sa = Arc::clone(&session_a); // 移入闭包的克隆；session_a 保留用于后续置位取消
        let drive_a = tokio::spawn(async move {
            drive_source_batches(
                sources_a,
                2,
                Duration::from_secs(30),
                sa.as_ref(),
                &sa.paused,
                search_one_a,
                |_o: SourceBatchOutcome<SearchResult>| {
                    a_delivered_c.fetch_add(1, Ordering::SeqCst);
                    Ok(())
                },
            )
            .await;
        });

        // 等 A 有 2 个在飞（前 2 源已派发，后 3 源排队）
        for _ in 0..400 {
            if a_started.load(Ordering::SeqCst) >= 2 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        assert_eq!(
            a_started.load(Ordering::SeqCst),
            2,
            "A 应有 2 个在飞源（concurrency=2）"
        );

        // B：独立会话、未取消，与 A 并发运行；同时置位 A 的取消标志（模拟 register(B) 取消 A，
        // 覆盖显式停止 / 页面销毁入口——二者均置 cancel 标志）
        let b_started = Arc::new(AtomicUsize::new(0));
        let session_b = searches.start().unwrap();
        let search_one_b = {
            let c = Arc::clone(&b_started);
            move |_s: BookSource| {
                let cc = Arc::clone(&c);
                async move {
                    cc.fetch_add(1, Ordering::SeqCst);
                    Ok(Vec::new())
                }
            }
        };
        let sources_b: Vec<BookSource> = (1..=5)
            .map(|i| BookSource {
                book_source_url: format!("https://b{i}.example.com"),
                ..BookSource::default()
            })
            .collect();

        session_a.cancel(); // 模拟 B 取代 A → 取消 A
        let drive_b = tokio::spawn(async move {
            drive_source_batches(
                sources_b,
                32,
                Duration::from_secs(30),
                session_b.as_ref(),
                &session_b.paused,
                search_one_b,
                // T 由 on_source 闭包标注固定（泛型驱动器推断需要）
                |_o: SourceBatchOutcome<SearchResult>| Ok(()),
            )
            .await;
        });

        let _ = drive_a.await; // A：检测取消 → abort_all + drain（约 300ms）
        let _ = drive_b.await; // B：全部执行

        // A：排队源（后 3 个）从不发请求 → a_started 恒为 2
        assert_eq!(
            a_started.load(Ordering::SeqCst),
            2,
            "A 的排队源在取消后不应发起任何请求"
        );
        // A：在飞结果不交付 on_source（取消后 break，未交付任何批次）→ 不进流/状态/落库
        assert_eq!(
            a_delivered.load(Ordering::SeqCst),
            0,
            "A 取消后在飞结果不应进入 on_source/流"
        );
        // B：全新会话 → 全部执行，不受 A 影响（会话隔离）
        assert_eq!(
            b_started.load(Ordering::SeqCst),
            5,
            "B 应全部执行（会话隔离，A 未污染 B）"
        );
    }

    // ─── 取消即时唤醒（P0-3 强化）：取消置位时收集循环正阻塞在 set.next()，
    //     必须立即 abort 在飞任务并返回，而不昏等待最快下一个自然完成。
    #[tokio::test]
    async fn test_drive_cancel_wakes_blocked_collect_promptly() {
        use std::sync::atomic::AtomicUsize;

        // 在飞任务永不自行完成：阻塞在 Notify 上（模拟长连接）
        let started = Arc::new(AtomicUsize::new(0));
        let gate = Arc::new(tokio::sync::Notify::new());
        let search_one = {
            let g = Arc::clone(&gate);
            let c = Arc::clone(&started);
            move |_s: BookSource| {
                let g = Arc::clone(&g);
                let cc = Arc::clone(&c);
                async move {
                    cc.fetch_add(1, Ordering::SeqCst);
                    g.notified().await; // 测试中永不放开
                    Ok(Vec::new())
                }
            }
        };
        let searches = Arc::new(legado_engine::SearchTasks::new(
            legado_engine::TaskGroup::default(),
        ));
        let session = searches.start().unwrap();
        let delivered = Arc::new(AtomicUsize::new(0));
        let delivered_c = Arc::clone(&delivered);
        let sc = Arc::clone(&session);
        let sources: Vec<BookSource> = (1..=4)
            .map(|i| BookSource {
                book_source_url: format!("https://x{i}.example.com"),
                ..BookSource::default()
            })
            .collect();
        let drive = tokio::spawn(async move {
            drive_source_batches(
                sources,
                2,
                Duration::from_secs(30),
                sc.as_ref(),
                &sc.paused,
                search_one,
                |_o: SourceBatchOutcome<SearchResult>| {
                    delivered_c.fetch_add(1, Ordering::SeqCst);
                    Ok(())
                },
            )
            .await;
        });

        // 等 2 个在飞（concurrency=2，后 2 源排队）
        for _ in 0..400 {
            if started.load(Ordering::SeqCst) >= 2 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        assert_eq!(started.load(Ordering::SeqCst), 2, "应有 2 个在飞源");

        session.cancel();
        // 取消必须即时（≤600ms）唤醒收集循环；在飞任务永不自然完成，
        // 若旧实现（等 set.next()）则永远超时。
        tokio::time::timeout(Duration::from_millis(600), drive)
            .await
            .expect("取消应即时中止收集循环")
            .expect("drive 不应 panic");
        assert_eq!(
            delivered.load(Ordering::SeqCst),
            0,
            "取消后不应交付任何批次"
        );
        // 被 abort 的任务 future 已 drop，通知无人接收也应安全
        gate.notify_waiters();
    }

    // ─── P0-3 sink 关闭入口（复审 7.3）：on_source 返回 Err → 驱动器中止剩余源、abort 在飞 ──
    #[tokio::test]
    async fn test_drive_source_batches_sink_err_aborts_remaining() {
        use std::sync::atomic::AtomicUsize;

        let started = Arc::new(AtomicUsize::new(0));
        let search_one = {
            let c = Arc::clone(&started);
            move |_s: BookSource| {
                let cc = Arc::clone(&c);
                async move {
                    cc.fetch_add(1, Ordering::SeqCst);
                    tokio::time::sleep(Duration::from_millis(200)).await; // 在飞阻塞
                    Ok(Vec::new())
                }
            }
        };
        let sources: Vec<BookSource> = (1..=6)
            .map(|i| BookSource {
                book_source_url: format!("https://s{i}.example.com"),
                ..BookSource::default()
            })
            .collect();

        let cancel = Arc::new(AtomicBool::new(false));
        let paused = Arc::new(AtomicBool::new(false));
        let delivered = Arc::new(AtomicUsize::new(0));
        let delivered_c = Arc::clone(&delivered);

        drive_source_batches(
            sources,
            2, // concurrency=2 → 前 2 源在飞，后 4 源排队
            Duration::from_secs(30),
            &cancel,
            &paused,
            search_one,
            move |_o: SourceBatchOutcome<SearchResult>| {
                delivered_c.fetch_add(1, Ordering::SeqCst);
                Err("sink 已关闭".into()) // 第 1 个批次交付后立即 sink 关闭
            },
        )
        .await;

        // sink 在第 1 批次后关闭 → cancel 置位，剩余源中止、在飞 abort
        assert!(cancel.load(Ordering::SeqCst), "sink 关闭应置位会话取消");
        assert_eq!(
            delivered.load(Ordering::SeqCst),
            1,
            "只交付了 1 个批次即 sink 关闭"
        );
        // 只有前 2 源在飞（已派发）；后 4 排队源中止，不执行
        assert_eq!(
            started.load(Ordering::SeqCst),
            2,
            "sink 关闭后剩余排队源应中止（只执行了 2 个在飞源）"
        );
    }

    // ─── P0-3 会话注册与清理安全（复审 7.5）：register(B) 取消 A；A 的清理不误清 B ──
    //     自有实例无需全局测试锁。

    #[tokio::test]
    async fn test_session_registration_and_cleanup_safety() {
        let searches = Arc::new(legado_engine::SearchTasks::new(
            legado_engine::TaskGroup::default(),
        ));

        // A → B：注册 B 应取消 A，且当前会话变为 B
        let a = searches.start().unwrap();
        assert!(is_current_session(&a), "注册后 A 应为当前会话");

        let b = searches.start().unwrap();
        assert!(a.is_cancelled(), "注册 B 应取消 A（新搜索取代）");
        assert!(is_current_session(&b), "当前会话应为 B");
        assert!(
            !is_current_session(&a),
            "A 不再是当前会话（7.4：A 的 on_source 复检将 early-return，不落库）"
        );

        // A 的清理不应误清已启动的 B（Arc::ptr_eq 保护；复审 7.5）
        clear_current_session_if_same(&a);
        assert!(is_current_session(&b), "A 的清理不应清除 B");

        // B 的清理应清除自身
        clear_current_session_if_same(&b);
        assert!(!is_current_session(&b), "B 的清理应清除当前会话");
    }

    // ─── 测试 2: JSON 搜索结果解析 ────────────────────────────────────────────

    #[test]
    fn test_parse_json_search_results() {
        let json = r#"{
            "data": [
                {
                    "title": "三体",
                    "writer": "刘慈欣",
                    "url": "https://api.example.com/book/3",
                    "cover": "https://cdn.example.com/cover3.jpg",
                    "desc": "地球往事三部曲",
                    "lastCh": "第30章"
                },
                {
                    "title": "黑暗森林",
                    "writer": "刘慈欣",
                    "url": "https://api.example.com/book/4",
                    "cover": "https://cdn.example.com/cover4.jpg",
                    "desc": "面壁计划",
                    "lastCh": "第25章"
                }
            ]
        }"#;

        let source = make_source_with_rules(
            "@json:$.data[*]",
            "@json:$.title",
            "@json:$.writer",
            "@json:$.url",
            "@json:$.cover",
            "@json:$.desc",
            "@json:$.lastCh",
        );

        let results =
            parse_search_response(json, "https://api.example.com/search", &source).unwrap();

        assert_eq!(results.len(), 2);
        assert_eq!(results[0].book_name, "三体");
        assert_eq!(results[0].author, "刘慈欣");
        assert_eq!(results[0].book_url, "https://api.example.com/book/3");
        assert_eq!(
            results[0].cover_url,
            Some("https://cdn.example.com/cover3.jpg".to_string())
        );
        assert_eq!(results[0].intro, Some("地球往事三部曲".to_string()));
        assert_eq!(results[1].book_name, "黑暗森林");
    }

    // ─── 测试 3: 空结果和无规则处理 ───────────────────────────────────────────

    #[test]
    fn test_parse_empty_response() {
        let html = r#"<html><body><p>没有找到相关书籍</p></body></html>"#;

        let source =
            make_source_with_rules(".book-item", ".name", ".author", ".name@href", "", "", "");

        let results =
            parse_search_response(html, "https://www.example.com/search", &source).unwrap();

        assert!(results.is_empty());
    }

    #[test]
    fn test_parse_no_rule_search_returns_empty() {
        let source = BookSource {
            book_source_url: "https://www.example.com".to_string(),
            book_source_name: "无规则源".to_string(),
            rule_search: None,
            ..BookSource::default()
        };

        let results =
            parse_search_response("<html></html>", "https://www.example.com", &source).unwrap();

        assert!(results.is_empty());
    }

    // ─── 测试 4: URL 解析（相对/绝对/协议相对）────────────────────────────────

    #[test]
    fn test_resolve_url_variants() {
        let base = "https://www.example.com/search/page";

        // 绝对 URL 不变
        assert_eq!(
            resolve_url("https://other.com/book/1", base),
            "https://other.com/book/1"
        );

        // 协议相对
        assert_eq!(
            resolve_url("//cdn.example.com/cover.jpg", base),
            "https://cdn.example.com/cover.jpg"
        );

        // 绝对路径
        assert_eq!(
            resolve_url("/book/1", base),
            "https://www.example.com/book/1"
        );

        // 相对路径
        assert_eq!(
            resolve_url("detail.html", base),
            "https://www.example.com/search/detail.html"
        );

        // 空 URL
        assert_eq!(resolve_url("", base), "");
    }

    // ─── 测试 5: build_search_url 关键词替换 ──────────────────────────────────

    #[test]
    fn test_build_search_url_key_replacement() {
        let source = BookSource {
            book_source_url: "https://www.example.com".to_string(),
            ..BookSource::default()
        };

        // {key} 替换
        let url = build_search_url(
            "https://www.example.com/search?q={key}",
            "斗破苍穹",
            &source,
        );
        assert!(url.url().contains("斗破苍穹") || url.url().contains("%E6%96%97"));

        // {{key}} 替换
        let url2 = build_search_url("https://www.example.com/search?q={{key}}", "三体", &source);
        assert!(url2.url().contains("三体") || url2.url().contains("%E4%B8%89"));

        // searchKey 替换
        let url3 = build_search_url(
            "https://www.example.com/search?q=searchKey",
            "rust",
            &source,
        );
        assert!(url3.url().contains("rust"));
    }

    // ─── 测试 6: POST 方法检测 ────────────────────────────────────────────────

    #[test]
    fn test_build_search_url_post_method() {
        let source = BookSource {
            book_source_url: "https://www.example.com".to_string(),
            ..BookSource::default()
        };

        let url = build_search_url(
            r#"https://www.example.com/api,{"method":"POST","body":"keyword={key}"}"#,
            "测试",
            &source,
        );
        assert_eq!(url.method(), &RequestMethod::Post);
        assert!(url.body().unwrap_or("").contains("测试"));
    }

    // ─── 测试 7: WebSourceSearcher 错误容错 ───────────────────────────────────

    #[tokio::test]
    async fn test_web_source_searcher_no_search_url() {
        let client = LegadoClient::new(LegadoClientConfig::default()).unwrap();
        let searcher = WebSourceSearcher::new(client);

        // 无 searchUrl 的书源应返回空列表（不 panic）
        let source = BookSource {
            book_source_url: "https://example.com".to_string(),
            book_source_name: "无搜索源".to_string(),
            search_url: None,
            ..BookSource::default()
        };

        let results = searcher.search(&source, "测试", 10).await;
        assert!(results.is_empty());
    }

    // ─── 测试 8: 无书名时跳过该条目 ──────────────────────────────────────────

    #[test]
    fn test_parse_skips_items_without_name() {
        let html = r#"<html><body>
            <div class="book-item">
                <span class="author">无名氏</span>
            </div>
            <div class="book-item">
                <a class="name" href="/book/9">有书名</a>
                <span class="author">作者A</span>
            </div>
        </body></html>"#;

        let source =
            make_source_with_rules(".book-item", ".name", ".author", ".name@href", "", "", "");

        let results = parse_search_response(html, "https://www.example.com", &source).unwrap();

        // 第一条无书名被跳过，只剩第二条
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].book_name, "有书名");
    }

    // ─── T6: CSS 提取 + @js: 链求值 bookUrl（对齐原版 splitSourceRule）───
    #[test]
    fn test_parse_search_book_url_css_js_chain() {
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name" href="/novel/42">书名</a>
                <span class="author">作者</span>
            </div>
        </body></html>"#;

        let source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            // 先取 href，再经 JS 拼接绝对路径（黑岩等 JS 链书源形态）
            r#".name@href@js:'https://www.example.com'+result"#,
            "",
            "",
            "",
        );

        let results = parse_search_response(html, "https://www.example.com", &source).unwrap();

        #[cfg(feature = "quickjs")]
        {
            assert_eq!(results.len(), 1);
            assert_eq!(
                results[0].book_url, "https://www.example.com/novel/42",
                "CSS@js 链应产出非空绝对 bookUrl"
            );
            assert!(!results[0].book_url.is_empty());
        }

        #[cfg(not(feature = "quickjs"))]
        {
            // 无 quickjs：链中 JS 段降级，bookUrl 空则回退书源主页
            assert_eq!(results.len(), 1);
            assert_eq!(results[0].book_url, "https://www.example.com");
        }
    }

    // ─── 测试 9: @js: 搜索规则注入（quickjs 启用时生效，否则降级）───────────────

    #[test]
    fn test_parse_search_js_rule() {
        let html = r#"<html><body>
            <div class="book-item"><span class="author">作者</span></div>
        </body></html>"#;

        // name / book_url 规则使用 @js:：quickjs 启用时返回固定值，未启用时降级为空
        let source = make_source_with_rules(
            ".book-item",
            "@js:'JS注入书名'",
            ".author",
            "@js:'https://www.example.com/book/js'",
            "",
            "",
            "",
        );

        let results = parse_search_response(html, "https://www.example.com", &source).unwrap();

        #[cfg(feature = "quickjs")]
        {
            assert_eq!(results.len(), 1, "quickjs 启用时 @js: 规则应被执行");
            assert_eq!(results[0].book_name, "JS注入书名");
            assert_eq!(results[0].book_url, "https://www.example.com/book/js");
        }

        #[cfg(not(feature = "quickjs"))]
        {
            // 未启用 quickjs：@js: 规则降级为空，书名为空该条目被跳过
            assert!(results.is_empty(), "未启用 quickjs 时 @js: 规则应降级为空");
        }
    }

    /// P0-2 S1：搜索主路径须建立 source/cookie JS 上下文（对齐原版 AnalyzeRule(ruleData, bookSource)）。
    /// name 规则 `@js:String(source.getKey())` 引用书源上下文——此前搜索仅注入 jsLib（无 setup），
    /// `source is not defined` ReferenceError → 字段降级为空；现经 construct_analyzer_with_source_context
    /// 注入 setup，source.getKey() = bookSourceUrl（对齐 BaseSource.getKey()）。
    #[test]
    fn test_parse_search_source_context_available() {
        let html = r#"<html><body>
            <div class="book-item"><span class="author">作者</span></div>
        </body></html>"#;

        let mut source = make_source_with_rules(
            ".book-item",
            "@js:String(source.getKey())",
            ".author",
            "",
            "",
            "",
            "",
        );
        // bookSourceUrl 即 source.getKey() 返回值（对齐原版 BaseSource.getKey()）
        source.book_source_url = "https://src.example.com".to_string();

        let results = parse_search_response(html, "https://www.example.com", &source).unwrap();

        #[cfg(feature = "quickjs")]
        {
            assert_eq!(
                results.len(),
                1,
                "quickjs：source 上下文应可用，@js: 规则执行"
            );
            assert_eq!(results[0].book_name, "https://src.example.com");
        }

        #[cfg(not(feature = "quickjs"))]
        {
            // 未启用 quickjs：@js: 规则降级为空 → 书名为空该条目被跳过
            assert!(results.is_empty());
        }
    }

    // ─── 测试 fix32: 无匹配/字段完整/多媒体识别 ──────────────

    /// 无匹配：bookList 匹配为空 → 记 0 条 success（非 error、不挂起，对齐原版空列表语义）
    #[test]
    fn test_parse_no_match_is_zero_success() {
        let source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        let body = "<html><body><p>没有找到相关书籍</p></body></html>";
        let results =
            parse_search_response(body, "https://www.example.com/search?q=zzz", &source).unwrap();
        assert!(results.is_empty(), "无匹配应记 0 条而非 error");
    }

    /// 字段完整性：kind/wordCount/cover 绝对化/bookType；部分字段缺失不致整条丢弃
    #[test]
    fn test_parse_fields_complete_and_partial_failure_isolated() {
        let mut source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        if let Some(r) = source.rule_search.as_mut() {
            r.kind = Some(".kind".into());
            r.word_count = Some(".wc".into());
        }
        // image（漫画）源 → BookType.image
        source.book_source_type = 2;
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name" href="/b/1">漫画书</a>
                <span class="author">作者</span>
                <img class="cover" src="/c/1.jpg" />
                <span class="kind">漫画,热血</span>
                <span class="wc">123456</span>
            </div>
            <div class="book-item">
                <a class="name" href="/b/2">缺字段书</a>
                <span class="author">乙</span>
            </div>
        </body></html>"#;

        let results =
            parse_search_response(html, "https://www.example.com/search", &source).unwrap();
        assert_eq!(results.len(), 2);
        let first = &results[0];
        assert_eq!(first.kind.as_deref(), Some("漫画,热血"));
        assert_eq!(first.word_count.as_deref(), Some("12.3万字"));
        // cover 相对路径绝对化（对齐原版 NetworkUtils.getAbsoluteURL）
        assert_eq!(
            first.cover_url.as_deref(),
            Some("https://www.example.com/c/1.jpg")
        );
        assert_eq!(first.book_type, book_type::IMAGE);
        // 第二条缺 cover/kind/wordCount 仍保留（只剔空 name/url）
        let second = &results[1];
        assert_eq!(second.book_name, "缺字段书");
        assert!(second.cover_url.is_none());
        assert!(second.kind.is_none());
        assert!(second.word_count.is_none());
        assert_eq!(second.book_type, book_type::IMAGE);
    }

    /// kind 多标签：多个匹配元素按原版 `getStringList().joinToString(",")` 用逗号分隔（BookList.kt:230）
    #[test]
    fn test_parse_kind_multi_match_joined_with_comma() {
        let mut source = make_source_with_rules(
            ".book-item",
            ".name",
            ".author",
            ".name@href",
            ".cover@src",
            ".intro",
            ".last",
        );
        if let Some(r) = source.rule_search.as_mut() {
            r.kind = Some(".kind".into());
        }
        // 单个 book-item 内含 3 个 .kind 元素 → kind 规则多匹配
        let html = r#"<html><body>
            <div class="book-item">
                <a class="name" href="/b/1">书A</a>
                <span class="author">作者</span>
                <span class="kind">科幻</span>
                <span class="kind">都市</span>
                <span class="kind">玄幻</span>
            </div>
        </body></html>"#;
        let results =
            parse_search_response(html, "https://www.example.com/search", &source).unwrap();
        assert_eq!(results.len(), 1);
        // 3 个 kind 元素 → 原版 joinToString(",") → 逗号分隔（而非 \n）
        assert_eq!(results[0].kind.as_deref(), Some("科幻,都市,玄幻"));
    }

    /// bookType 判定对齐原版 `BookSource.getBookType()`
    #[test]
    fn test_book_type_of_source_mapping() {
        assert_eq!(book_type_of_source(0), book_type::TEXT);
        assert_eq!(book_type_of_source(1), book_type::AUDIO);
        assert_eq!(book_type_of_source(2), book_type::IMAGE);
        assert_eq!(
            book_type_of_source(3),
            book_type::TEXT | book_type::WEB_FILE
        );
        assert_eq!(book_type_of_source(4), book_type::VIDEO);
    }

    /// wordCountFormat 对齐原版 StringUtils.wordCountFormat
    #[test]
    fn test_word_count_format_aligns_original() {
        assert_eq!(word_count_format("123456").as_deref(), Some("12.3万字"));
        assert_eq!(word_count_format("20000").as_deref(), Some("2万字"));
        assert_eq!(word_count_format("5000").as_deref(), Some("5000字"));
        assert_eq!(word_count_format(""), None);
        assert_eq!(word_count_format("0"), None);
        assert_eq!(word_count_format("连载中").as_deref(), Some("连载中"));
    }

    /// 回归：单源超时对阻塞型同步计算生效，整体不挂起
    ///
    /// 实机缺陷回归：同步解析占住 tokio worker 时 `tokio::time::timeout`
    /// 无法触发，信号量排队导致整体挂起（691/692 卡死）。
    /// 修复后同步长计算在阻塞线程执行（spawn_blocking），超时在 await 点生效：
    /// 超时源记错误批次、整体立即完成，不等阻塞任务。
    #[tokio::test]
    async fn test_drive_timeout_effective_for_blocking_parse() {
        use std::time::Duration;
        let sources = vec![make_source_with_rules(".b", ".n", ".a", ".u", "", "", "")];
        let mut batch_errors = Vec::new();
        let started = std::time::Instant::now();
        super::drive_source_batches(
            sources,
            1,
            Duration::from_millis(300),
            &std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            &std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            |_source| async {
                // 模拟修复后实现：同步长计算移入阻塞线程（await 点可中断）
                tokio::task::spawn_blocking(|| {
                    std::thread::sleep(Duration::from_millis(3000));
                    Ok(Vec::new())
                })
                .await
                .map_err(|e| LegadoError::Internal(e.to_string()))?
            },
            |outcome: SourceBatchOutcome<SearchResult>| {
                batch_errors.push(outcome.result.is_err());
                Ok(())
            },
        )
        .await;
        assert_eq!(batch_errors.len(), 1, "超时源仍应推送一个批次");
        assert!(batch_errors[0], "超时源应记错误批次而非挂起");
        assert!(
            started.elapsed() < Duration::from_millis(1500),
            "整体应在超时后立即完成，不等阻塞任务"
        );
    }

    // ─── 测试 10: 封面候选提取（过滤空值 + 去重）────────────────────────────

    /// 构造带指定封面的 SearchResult
    fn make_result_with_cover(cover: Option<&str>) -> SearchResult {
        SearchResult {
            source_url: "https://www.example.com".to_string(),
            source_name: "测试书源".to_string(),
            book_name: "测试书籍".to_string(),
            author: "作者".to_string(),
            book_url: "https://www.example.com/book/1".to_string(),
            latest_chapter: None,
            intro: None,
            cover_url: cover.map(|s| s.to_string()),
            kind: None,
            word_count: None,
            book_type: book_type::TEXT,
            origin_order: 0,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        }
    }

    #[test]
    fn test_extract_cover_candidates_dedup_and_filter() {
        let results = vec![
            make_result_with_cover(Some("https://cdn.example.com/a.jpg")),
            make_result_with_cover(Some("https://cdn.example.com/b.jpg")),
            // 重复 URL 应被去重
            make_result_with_cover(Some("https://cdn.example.com/a.jpg")),
            // 空封面应被过滤
            make_result_with_cover(None),
            // 空字符串封面应被过滤
            make_result_with_cover(Some("")),
            make_result_with_cover(Some("https://cdn.example.com/c.jpg")),
        ];

        let candidates = extract_cover_candidates(results);

        // 去重 + 过滤后仅剩 3 个，且保持首次出现顺序
        assert_eq!(candidates.len(), 3);
        assert_eq!(candidates[0].url, "https://cdn.example.com/a.jpg");
        assert_eq!(candidates[1].url, "https://cdn.example.com/b.jpg");
        assert_eq!(candidates[2].url, "https://cdn.example.com/c.jpg");
        // width / height 均为 0
        assert!(candidates.iter().all(|c| c.width == 0 && c.height == 0));
    }

    #[test]
    fn test_extract_cover_candidates_empty_input() {
        let candidates = extract_cover_candidates(Vec::new());
        assert!(candidates.is_empty());
    }

    #[test]
    fn test_cover_candidate_serialize() {
        let candidate = CoverCandidate {
            url: "https://cdn.example.com/x.jpg".to_string(),
            width: 0,
            height: 0,
        };
        let json = serde_json::to_string(&candidate).unwrap();
        // 字段名为 snake_case，对齐 Dart CoverCandidate 模型
        assert!(json.contains("\"url\""));
        assert!(json.contains("\"width\""));
        assert!(json.contains("\"height\""));
        assert!(json.contains("https://cdn.example.com/x.jpg"));
    }

    /// 回归：`load_search_sources("[]")` 应视为搜全部（Dart 侧无筛选默认传 '[]'）
    #[test]
    fn test_load_search_sources_empty_array_means_all() {
        let _db_guard = crate::db_state::ensure_test_db();
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");

        let from_empty_array = load_search_sources("[]").expect("空数组解析失败");
        let from_empty_str = load_search_sources("").expect("空串解析失败");
        assert!(
            !from_empty_array.is_empty(),
            "空数组 '[]' 应表示搜索全部启用书源"
        );
        assert_eq!(from_empty_array.len(), from_empty_str.len());
    }

    /// E2E 诊断测试（需网络，默认忽略）：
    /// 导入 yckceo 7631 书源并执行真实搜索，用于区分
    /// 「集成测试框架缺陷」与「Rust 搜索链路问题」。
    /// 运行：cargo test -p legado-ffi e2e_yckceo -- --ignored --nocapture
    #[test]
    #[ignore]
    fn test_e2e_yckceo_search_network() {
        // 调 search_books（入口执行 begin_book_flow 切 flow scope）→ 触碰
        // 全局 store，持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db_guard = crate::db_state::ensure_test_db();

        // cwd 为 rust/legado-ffi，书源夹具位于 tests/fixtures/
        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        let imported = crate::api::source::import_sources(&json).expect("导入书源失败");
        eprintln!("[E2E] 导入书源数量: {imported}");

        match search_books("都市", "") {
            Ok(results) => {
                eprintln!("[E2E] 搜索结果数量: {}", results.len());
                for r in results.iter().take(5) {
                    eprintln!(
                        "[E2E] - 《{}》 作者:{} 源:{} url:{}",
                        r.book_name, r.author, r.source_name, r.book_url
                    );
                }
            }
            Err(e) => eprintln!("[E2E] 搜索失败: {e:?}"),
        }
    }

    /// E2E 诊断：搜索 → 刷新目录 → 获取正文，定位阅读链路断点。
    /// 运行：cargo test -p legado-ffi e2e_read_chain --features quickjs -- --ignored --nocapture
    #[test]
    #[ignore]
    fn test_e2e_yckceo_read_chain_network() {
        // 搜索+刷新目录+正文链（search_books / refresh_toc 入口均
        // begin_book_flow）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db_guard = crate::db_state::ensure_test_db();

        let json = std::fs::read_to_string("tests/fixtures/yckceo_7631.json")
            .expect("读取 yckceo_7631.json 失败");
        crate::api::source::import_sources(&json).expect("导入书源失败");

        let results = search_books("都市", "").expect("搜索失败");
        assert!(!results.is_empty(), "搜索无结果");
        // 优先选《都市逍遥邪医》，否则取首条
        let target = results
            .iter()
            .find(|r| r.book_name.contains("都市逍遥邪医"))
            .unwrap_or(&results[0]);
        eprintln!(
            "[E2E-READ] 目标: 《{}》 url={} origin={}",
            target.book_name, target.book_url, target.source_url
        );

        match crate::api::reader::refresh_toc(&target.book_url, &target.source_url) {
            Ok(resp) => {
                eprintln!("[E2E-READ] 目录章节数: {}", resp.total);
                for c in resp.chapters.iter().take(3) {
                    eprintln!("[E2E-READ] - {} url={}", c.title, c.url);
                }
                if let Some(first) = resp.chapters.first() {
                    match crate::api::reader::fetch_chapter_content(
                        &target.book_url,
                        &first.url,
                        &target.source_url,
                    ) {
                        Ok(content) => eprintln!(
                            "[E2E-READ] 正文长度: {} 前80字: {}",
                            content.len(),
                            content.chars().take(80).collect::<String>()
                        ),
                        Err(e) => eprintln!("[E2E-READ] 正文获取失败: {e:?}"),
                    }
                }
            }
            Err(e) => eprintln!("[E2E-READ] 目录获取失败: {e:?}"),
        }
    }

    // ─── 测试 11: 阅读记录标识（对齐上游 ReadRecordIndex，#424）────────────

    use legado_db::repository::read_record_repository::ReadRecord;

    /// 构造 ReadRecord 测试数据（device_id/last_read 为 v101 新增字段，取默认值）
    fn make_record(book_name: &str, author: &str) -> ReadRecord {
        ReadRecord {
            book_name: book_name.to_string(),
            author: author.to_string(),
            read_time: 0,
            ..Default::default()
        }
    }

    /// 构造最简 SearchResult 测试数据
    fn make_result(book_name: &str, author: &str) -> SearchResult {
        SearchResult {
            source_url: "https://s.example.com".into(),
            source_name: "源".into(),
            book_name: book_name.into(),
            author: author.into(),
            book_url: "https://s.example.com/b/1".into(),
            latest_chapter: None,
            intro: None,
            cover_url: None,
            kind: None,
            word_count: None,
            book_type: book_type::TEXT,
            origin_order: 0,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        }
    }

    /// 索引匹配语义（对齐上游 ReadRecordIndex.contains 的四种分支）
    #[test]
    fn test_read_record_index_match_semantics() {
        let index = ReadRecordIndex::of(vec![
            make_record("剑来", "烽火戏诸侯"),
            make_record("旧记录书", ""),
        ]);

        // 书名+作者完全匹配
        assert!(index.contains("剑来", "烽火戏诸侯"));
        // 书名命中但作者不符 → 不算读过
        assert!(!index.contains("剑来", "某同名作者"));
        // 搜索结果无作者 → 退化为按书名判断
        assert!(index.contains("剑来", ""));
        // 记录无作者（旧记录）→ 任意作者都算命中
        assert!(index.contains("旧记录书", "任何作者"));
        // 无记录
        assert!(!index.contains("不存在", ""));
    }

    /// 多作者集合编码（\u{1E}authors: 前缀）解码后逐作者匹配
    #[test]
    fn test_read_record_index_multi_author_encoded() {
        let encoded = "\u{1E}authors:[\"作者A\",\"作者B\"]".to_string();
        let index = ReadRecordIndex::of(vec![make_record("同名书", &encoded)]);

        assert!(index.contains("同名书", "作者A"));
        assert!(index.contains("同名书", "作者B"));
        assert!(!index.contains("同名书", "作者C"));
        // lookup 返回记录侧全部作者（顿号连接）
        let (has, author) = index.lookup("同名书", "作者B");
        assert!(has);
        assert_eq!(author.as_deref(), Some("作者A、作者B"));
    }

    /// 无记录时字段缺省：hasReadRecord=false，readRecordAuthor 缺省
    #[test]
    fn test_read_record_annotation_absent() {
        let index = ReadRecordIndex::of(Vec::new());
        let mut results = vec![make_result("任意书", "任意作者")];

        annotate_results(&mut results, &index);
        assert!(!results[0].has_read_record);
        assert!(results[0].read_record_author.is_none());

        // 序列化：hasReadRecord 恒输出，readRecordAuthor 缺省时不出现
        let json = serde_json::to_string(&results[0]).unwrap();
        assert!(json.contains("\"hasReadRecord\":false"));
        assert!(!json.contains("readRecordAuthor"));
    }

    /// 端到端：DB 存在阅读记录时，搜索结果被批量附加标识
    #[test]
    fn test_read_record_annotation_with_db() {
        let _db_guard = crate::db_state::ensure_test_db();
        crate::db_state::with_database(|db| {
            let repo = ReadRecordRepository::new(db.connection());
            repo.insert_with_author("标识测试书A", "作者甲", 100)?;
            repo.upsert("标识测试书B", 200)?; // 旧式记录，无作者
            Ok(())
        })
        .expect("写入测试阅读记录失败");

        let index = ReadRecordIndex::load_from(
            crate::engine_holder::current()
                .ok()
                .as_ref()
                .map(|e| e.storage()),
        );
        let mut results = vec![
            make_result("标识测试书A", "作者甲"),
            make_result("标识测试书B", "书源给的作者"),
            make_result("无记录书", ""),
        ];

        annotate_results(&mut results, &index);

        // 有记录 + 作者匹配
        assert!(results[0].has_read_record);
        assert_eq!(results[0].read_record_author.as_deref(), Some("作者甲"));
        // 旧式无作者记录 → 按书名命中，无作者展示串
        assert!(results[1].has_read_record);
        assert!(results[1].read_record_author.is_none());
        // 无记录
        assert!(!results[2].has_read_record);

        // 序列化字段名契约（camelCase）
        let json = serde_json::to_string(&results[0]).unwrap();
        assert!(json.contains("\"hasReadRecord\":true"));
        assert!(json.contains("\"readRecordAuthor\":\"作者甲\""));

        // 清理测试记录，避免污染共享测试库
        crate::db_state::with_database(|db| {
            let repo = ReadRecordRepository::new(db.connection());
            repo.delete_by_book_name("标识测试书A")?;
            repo.delete_by_book_name("标识测试书B")?;
            Ok(())
        })
        .expect("清理测试阅读记录失败");
    }

    /// 批量查询性能：大量记录 + 大量结果，一次建索引后 O(1) 查找
    #[test]
    fn test_read_record_index_batch_lookup() {
        // 5000 条记录 + 2000 条搜索结果
        let records: Vec<ReadRecord> = (0..5000)
            .map(|i| make_record(&format!("批量书{i}"), &format!("作者{i}")))
            .collect();
        let index = ReadRecordIndex::of(records);

        let mut results: Vec<SearchResult> = (0..2000)
            .map(|i| make_result(&format!("批量书{}", i * 2), &format!("作者{}", i * 2)))
            .collect();

        let start = std::time::Instant::now();
        annotate_results(&mut results, &index);
        let elapsed = start.elapsed();

        assert!(results.iter().all(|r| r.has_read_record));
        // 2000 次 O(1) 查找应远低于每本一次 DB 查询的开销
        assert!(
            elapsed < std::time::Duration::from_secs(1),
            "批量查找耗时异常: {elapsed:?}"
        );
    }

    /// 设备导出的神漫画/Nhentai/51：search→toc 网络探针
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "requires network + tmp_debug fixtures"]
    fn probe_manga_sources_from_tmp_debug() {
        // tmp_debug 夹具启用时经 search_books 探源（入口 begin_book_flow）
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();
        let root = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tmp_debug");
        for (file, kw) in [
            ("src_51.json", "一人之下"),
            ("src_shen.json", "一人之下"),
            ("src_nhentai.json", "姐姐"),
            ("src_kuaikan.json", "一人之下"),
            ("src_cola.json", "一人之下"),
        ] {
            let path = root.join(file);
            if !path.exists() {
                println!("skip missing {file}");
                continue;
            }
            let raw = std::fs::read_to_string(&path).unwrap();
            let mut v: serde_json::Value = serde_json::from_str(&raw).unwrap();
            if let Some(obj) = v.as_object_mut() {
                for k in [
                    "enabled",
                    "enabledExplore",
                    "enabledCookieJar",
                    "eventListener",
                    "customButton",
                ] {
                    if let Some(n) = obj.get(k).and_then(|x| x.as_i64()) {
                        obj.insert(k.to_string(), serde_json::json!(n != 0));
                    }
                }
            }
            let src: legado_core::models::BookSource = serde_json::from_value(v).unwrap();
            println!("\n==== {} ====", src.book_source_name);
            let arr = serde_json::json!([src]).to_string();
            crate::api::source::import_sources(&arr).unwrap();
            let urls = format!(r#"["{}"]"#, src.book_source_url);
            match search_books(kw, &urls) {
                Ok(list) => {
                    println!("SEARCH n={}", list.len());
                    if let Some(b) = list.first() {
                        println!("  {} {}", b.book_name, b.book_url);
                        match crate::api::reader::refresh_toc(&b.book_url, &b.source_url) {
                            Ok(toc) => {
                                println!("  TOC n={}", toc.chapters.len());
                                if let Some(ch) = toc.chapters.first() {
                                    match crate::api::reader::get_chapter_content_full(
                                        &b.book_url,
                                        ch.index,
                                    ) {
                                        Ok(c) => println!("  CONTENT len={}", c.len()),
                                        Err(e) => println!("  CONTENT err={e}"),
                                    }
                                }
                            }
                            Err(e) => println!("  TOC err={e}"),
                        }
                    }
                }
                Err(e) => println!("SEARCH err={e}"),
            }
        }
    }
    /// 批量图片源搜索/目录探针（网络，ignore）
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "requires network + tmp_debug/sources.json"]
    fn probe_all_image_sources_batch() {
        // tmp_debug 批量探源（search_books 入口 begin_book_flow）→ 持 crate
        // 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/sources.json");
        let raw = std::fs::read_to_string(&path).expect("sources.json");
        let mut data: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        let mut img = Vec::new();
        for v in &mut data {
            if v.get("bookSourceType").and_then(|x| x.as_i64()) != Some(2) {
                continue;
            }
            if let Some(obj) = v.as_object_mut() {
                for k in [
                    "enabled",
                    "enabledExplore",
                    "enabledCookieJar",
                    "eventListener",
                    "customButton",
                ] {
                    if let Some(n) = obj.get(k).and_then(|x| x.as_i64()) {
                        obj.insert(k.to_string(), serde_json::json!(n != 0));
                    }
                }
            }
            img.push(v.clone());
        }
        println!("IMAGE_SOURCES={}", img.len());
        let mut ok_search = 0usize;
        let mut fail_search = 0usize;
        let mut err_counter: std::collections::BTreeMap<String, usize> =
            std::collections::BTreeMap::new();
        let mut ok_names = Vec::new();
        let mut fail_samples = Vec::new();
        for (i, v) in img.iter().enumerate() {
            let src: legado_core::models::BookSource = match serde_json::from_value(v.clone()) {
                Ok(s) => s,
                Err(e) => {
                    fail_search += 1;
                    *err_counter.entry(format!("deserialize:{e}")).or_default() += 1;
                    continue;
                }
            };
            let name = src.book_source_name.clone();
            let url = src.book_source_url.clone();
            let arr = serde_json::json!([src]).to_string();
            let _ = crate::api::source::import_sources(&arr);
            let urls = format!(r#"["{url}"]"#);
            match search_books("一人之下", &urls) {
                Ok(list) if !list.is_empty() => {
                    ok_search += 1;
                    ok_names.push(format!("{name} n={}", list.len()));
                    let b = &list[0];
                    match crate::api::reader::refresh_toc(&b.book_url, &b.source_url) {
                        Ok(toc) => println!(
                            "OK_SEARCH+TOC\t{name}\tsearch={}\ttoc={}",
                            list.len(),
                            toc.chapters.len()
                        ),
                        Err(e) => {
                            let es = e.to_string();
                            println!(
                                "OK_SEARCH+TOC_FAIL\t{name}\tsearch={}\terr={es}",
                                list.len()
                            );
                            *err_counter.entry(format!("toc:{es}")).or_default() += 1;
                        }
                    }
                }
                Ok(_) => {
                    fail_search += 1;
                    *err_counter.entry("search:empty".into()).or_default() += 1;
                    if fail_samples.len() < 25 {
                        fail_samples.push(format!("{name}\tempty"));
                    }
                    println!("FAIL_SEARCH\t{name}\tempty");
                }
                Err(e) => {
                    fail_search += 1;
                    let es = e.to_string();
                    let key = if es.contains("ReferenceError") {
                        format!("js:{}", es.chars().take(80).collect::<String>())
                    } else if es.contains("timeout") || es.contains("Timeout") {
                        "http:timeout".into()
                    } else if es.contains("404") {
                        "http:404".into()
                    } else if es.contains("connect")
                        || es.contains("dns")
                        || es.contains("TLS")
                        || es.contains("ssl")
                    {
                        "http:network".into()
                    } else {
                        format!("other:{}", es.chars().take(60).collect::<String>())
                    };
                    *err_counter.entry(key).or_default() += 1;
                    if fail_samples.len() < 25 {
                        fail_samples.push(format!("{name}\t{es}"));
                    }
                    println!("FAIL_SEARCH\t{name}\t{es}");
                }
            }
            if i % 10 == 0 {
                eprintln!("progress {}/{}", i + 1, img.len());
            }
        }
        println!("\n==== SUMMARY ====");
        println!(
            "ok_search={ok_search} fail_search={fail_search} total={}",
            img.len()
        );
        println!("ok_names={ok_names:?}");
        println!("top_errors:");
        let mut errs: Vec<_> = err_counter.into_iter().collect();
        errs.sort_by_key(|t| std::cmp::Reverse(t.1));
        for (k, c) in errs.iter().take(30) {
            println!("  {c}\t{k}");
        }
        println!("fail_samples:");
        for s in fail_samples {
            println!("  {s}");
        }
    }

    /// 抽样：原版有、重构常空的漫画源
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "e2e network probe"]
    fn probe_missing_manga_sources() {
        // tmp_debug 缺失源探因（search_books 入口 begin_book_flow）→ 持 crate
        // 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/e2e_5558/probe_missing_srcs.json");
        let raw = std::fs::read_to_string(&path).expect("probe_missing_srcs.json");
        let list: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        let _ = crate::api::source::import_sources(&raw);
        let kw = "一人之下";
        for v in &list {
            let name = v
                .get("bookSourceName")
                .and_then(|x| x.as_str())
                .unwrap_or("?");
            let url = v
                .get("bookSourceUrl")
                .and_then(|x| x.as_str())
                .unwrap_or("");
            let urls_json = serde_json::to_string(&vec![url]).unwrap();
            match search_books(kw, &urls_json) {
                Ok(hits) => {
                    let exact: Vec<_> = hits.iter().filter(|r| r.book_name.contains(kw)).collect();
                    println!(
                        "OK\t{name}\tn={}\texact={}\tfirst={}",
                        hits.len(),
                        exact.len(),
                        hits.first().map(|r| r.book_name.as_str()).unwrap_or("-")
                    );
                }
                Err(e) => println!("ERR\t{name}\t{e}"),
            }
        }
    }

    /// 快速书源（普通小说）分组搜索探针 — 对照原版缺口
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "e2e network probe"]
    fn probe_fast_group_novel_search() {
        // fast 组小说探源（search_books 入口 begin_book_flow）→ 持 crate 级
        // test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use std::collections::BTreeMap;
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/sources.json");
        let raw = std::fs::read_to_string(&path).expect("sources.json");
        let mut data: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        let mut fast = Vec::new();
        for v in &mut data {
            let group = v
                .get("bookSourceGroup")
                .and_then(|x| x.as_str())
                .unwrap_or("");
            let ty = v
                .get("bookSourceType")
                .and_then(|x| x.as_i64())
                .unwrap_or(0);
            // 快速书源且文本源（type=0）
            if !group
                .split(|c| ",;，；".contains(c))
                .any(|p| p.trim() == "快速书源")
            {
                continue;
            }
            if ty != 0 {
                continue;
            }
            if let Some(obj) = v.as_object_mut() {
                for k in [
                    "enabled",
                    "enabledExplore",
                    "enabledCookieJar",
                    "eventListener",
                    "customButton",
                ] {
                    if let Some(n) = obj.get(k).and_then(|x| x.as_i64()) {
                        obj.insert(k.to_string(), serde_json::json!(n != 0));
                    }
                }
            }
            fast.push(v.clone());
        }
        println!("FAST_GROUP_TYPE0_SOURCES={}", fast.len());
        let _ =
            crate::api::source::import_sources(&serde_json::Value::Array(fast.clone()).to_string());
        let urls: Vec<String> = fast
            .iter()
            .filter_map(|v| {
                v.get("bookSourceUrl")
                    .and_then(|x| x.as_str())
                    .map(|s| s.to_string())
            })
            .collect();
        let urls_json = serde_json::to_string(&urls).unwrap();
        let kw = "斗破苍穹";
        println!("SEARCH_KW={kw} URLS={}", urls.len());
        match search_books(kw, &urls_json) {
            Ok(list) => {
                let exact: Vec<_> = list.iter().filter(|r| r.book_name.contains(kw)).collect();
                let mut by_origin: BTreeMap<String, usize> = BTreeMap::new();
                let mut by_origin_exact: BTreeMap<String, usize> = BTreeMap::new();
                for r in &list {
                    *by_origin
                        .entry(format!("{}|{}", r.source_name, r.source_url))
                        .or_default() += 1;
                }
                for r in &exact {
                    *by_origin_exact
                        .entry(format!("{}|{}", r.source_name, r.source_url))
                        .or_default() += 1;
                }
                println!("TOTAL_HITS={}", list.len());
                println!("ORIGINS_WITH_HITS={}", by_origin.len());
                println!("EXACT_TITLE_HITS={}", exact.len());
                println!("EXACT_ORIGINS_WITH_HITS={}", by_origin_exact.len());
                // 聚合口径：精确书名下不同 origin 数 ≈ 原版顶条徽标
                for (k, n) in by_origin_exact.iter().take(40) {
                    println!("EXACT_ORIGIN\t{n}\t{k}");
                }
                // 抽样前几条书名
                for r in exact.iter().take(15) {
                    println!(
                        "EXACT_SAMPLE\t{}\t{}\t{}",
                        r.source_name, r.book_name, r.author
                    );
                }
            }
            Err(e) => println!("SEARCH_ERR={e}"),
        }
    }

    /// 快速书源 type=0 逐源失败原因分布（斗破苍穹）
    ///
    /// 对齐 systematic-debugging：先统计 empty/JS/HTTP/timeout/解析等，
    /// 再找引擎级整批失败模式。— Reasonix
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "e2e network probe"]
    fn probe_fast_group_novel_fail_classify() {
        // fast 组失败分类（search_books 入口 begin_book_flow）→ 持 crate 级
        // test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use std::collections::BTreeMap;
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/sources.json");
        let raw = std::fs::read_to_string(&path).expect("sources.json");
        let mut data: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        let mut fast = Vec::new();
        for v in &mut data {
            let group = v
                .get("bookSourceGroup")
                .and_then(|x| x.as_str())
                .unwrap_or("");
            let ty = v
                .get("bookSourceType")
                .and_then(|x| x.as_i64())
                .unwrap_or(0);
            if !group
                .split(|c| ",;，；".contains(c))
                .any(|p| p.trim() == "快速书源")
            {
                continue;
            }
            if ty != 0 {
                continue;
            }
            if let Some(obj) = v.as_object_mut() {
                for k in [
                    "enabled",
                    "enabledExplore",
                    "enabledCookieJar",
                    "eventListener",
                    "customButton",
                ] {
                    if let Some(n) = obj.get(k).and_then(|x| x.as_i64()) {
                        obj.insert(k.to_string(), serde_json::json!(n != 0));
                    }
                }
            }
            fast.push(v.clone());
        }
        println!("FAST_GROUP_TYPE0_SOURCES={}", fast.len());
        let kw = "斗破苍穹";
        let mut ok = 0usize;
        let mut exact_origins = 0usize;
        let mut err_counter: BTreeMap<String, usize> = BTreeMap::new();
        let mut fail_samples: Vec<String> = Vec::new();
        let client = crate::http_state::shared_client().unwrap();
        for (i, v) in fast.iter().enumerate() {
            let src: BookSource = match serde_json::from_value(v.clone()) {
                Ok(s) => s,
                Err(e) => {
                    *err_counter.entry(format!("deserialize:{}", e)).or_default() += 1;
                    continue;
                }
            };
            let name = src.book_source_name.clone();
            let search_url = src.search_url.clone().unwrap_or_default();
            let outcome = crate::runtime::block_on(async {
                tokio::time::timeout(
                    SEARCH_SOURCE_TIMEOUT,
                    search_single_source(&client, &src, kw, 1, false),
                )
                .await
            });
            match outcome {
                Ok(Ok(list)) if !list.is_empty() => {
                    ok += 1;
                    if list.iter().any(|r| r.book_name.contains(kw)) {
                        exact_origins += 1;
                    }
                    let empty_url = list.iter().filter(|r| r.book_url.is_empty()).count();
                    if empty_url > 0 {
                        *err_counter.entry("warn:bookUrl_empty".into()).or_default() += 1;
                    }
                    println!(
                        "OK\t{name}\tn={}\texact={}\tempty_url={empty_url}",
                        list.len(),
                        list.iter().filter(|r| r.book_name.contains(kw)).count()
                    );
                }
                Ok(Ok(_)) => {
                    *err_counter.entry("empty".into()).or_default() += 1;
                    // 附加 searchUrl 形态特征，便于找引擎级模式
                    let feat = if search_url.is_empty() {
                        "no_searchUrl"
                    } else if search_url.starts_with('/') || !search_url.contains("://") {
                        "relative_url"
                    } else if search_url.contains("<js>") || search_url.contains("@js:") {
                        "js_block"
                    } else if search_url.contains("{{") {
                        "mustache"
                    } else {
                        "literal"
                    };
                    *err_counter.entry(format!("empty:{feat}")).or_default() += 1;
                    let bl = src
                        .rule_search
                        .as_ref()
                        .and_then(|r| r.book_list.clone())
                        .unwrap_or_default();
                    if bl.starts_with("class.") {
                        *err_counter
                            .entry("empty:bookList_class.".into())
                            .or_default() += 1;
                    } else if bl.contains("@js:") || bl.contains("<js>") {
                        *err_counter.entry("empty:bookList_js".into()).or_default() += 1;
                    } else if bl.starts_with("$.") || bl.starts_with("$[") {
                        *err_counter.entry("empty:bookList_json".into()).or_default() += 1;
                    }
                    if fail_samples.len() < 40 {
                        fail_samples.push(format!(
                            "{name}\tempty\tfeat={feat}\tbookList={}",
                            bl.chars().take(60).collect::<String>()
                        ));
                    }
                    println!("FAIL\t{name}\tempty\tfeat={feat}");
                }
                Ok(Err(e)) => {
                    let es = e.to_string();
                    let key = classify_search_err(&es);
                    *err_counter.entry(key.clone()).or_default() += 1;
                    if fail_samples.len() < 40 {
                        fail_samples.push(format!("{name}\t{es}"));
                    }
                    println!("FAIL\t{name}\t{key}\t{es}");
                }
                Err(_) => {
                    *err_counter.entry("timeout".into()).or_default() += 1;
                    println!("FAIL\t{name}\ttimeout");
                }
            }
            if (i + 1) % 20 == 0 {
                eprintln!("progress {}/{}", i + 1, fast.len());
            }
        }
        println!("\n==== SUMMARY ====");
        println!("ok={ok} exact_origins={exact_origins} total={}", fast.len());
        println!("top_errors:");
        let mut errs: Vec<_> = err_counter.into_iter().collect();
        errs.sort_by_key(|t| std::cmp::Reverse(t.1));
        for (k, c) in errs {
            println!("  {c}\t{k}");
        }
        println!("fail_samples:");
        for s in fail_samples {
            println!("  {s}");
        }
    }

    // 仅被 quickjs 门控的探针 probe_fast_group_novel_fail_classify 调用：
    // 默认档（无 quickjs）下调用方不编译 → 函数随之门控，免 dead_code
    #[cfg(feature = "quickjs")]
    fn classify_search_err(es: &str) -> String {
        if es.contains("ReferenceError")
            || es.contains("TypeError")
            || es.contains("SyntaxError")
            || es.contains("JS engine")
            || es.contains("jsLib")
            || es.contains("is not defined")
        {
            format!("js:{}", es.chars().take(80).collect::<String>())
        } else if es.contains("timeout") || es.contains("Timeout") || es.contains("timed out") {
            "http:timeout".into()
        } else if es.contains("404") {
            "http:404".into()
        } else if es.contains("403") {
            "http:403".into()
        } else if es.contains("HTTP ") {
            format!("http:status:{}", es.chars().take(40).collect::<String>())
        } else if es.contains("connect")
            || es.contains("dns")
            || es.contains("DNS")
            || es.contains("TLS")
            || es.contains("ssl")
            || es.contains("certificate")
            || es.contains("resolve")
        {
            "http:network".into()
        } else if es.contains("searchUrl") {
            "parse:searchUrl".into()
        } else if es.contains("解析") || es.contains("Parser") || es.contains("selector") {
            format!("parse:{}", es.chars().take(60).collect::<String>())
        } else {
            format!("other:{}", es.chars().take(60).collect::<String>())
        }
    }

    /// GBK charset 书源搜索探针（验证请求编码修复）— Reasonix
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "e2e network probe"]
    fn probe_gbk_charset_novel_search() {
        // GBK 探源（build_search_url_with_lib 评估 search_url JS 规则 +
        // 共享客户端抓取，JS 绑定可读写全局表）→ 持 crate 级 test_support
        // 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/e2e_5558/probe_gbk_srcs.json");
        let raw = std::fs::read_to_string(&path).expect("probe_gbk_srcs.json");
        let list: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        println!("GBK_SOURCES={}", list.len());
        let kw = "斗破苍穹";
        let client = crate::http_state::shared_client().unwrap();
        let mut ok = 0usize;
        let mut exact = 0usize;
        for v in &list {
            let src: BookSource = match serde_json::from_value(v.clone()) {
                Ok(s) => s,
                Err(e) => {
                    println!("DESER_ERR\t{e}");
                    continue;
                }
            };
            let name = src.book_source_name.clone();
            // 打印实际请求 URL，确认 GBK 百分号编码
            if let Some(ref tpl) = src.search_url {
                let au = crate::js_executor::build_search_url_with_lib(
                    tpl,
                    kw,
                    1,
                    &src.book_source_url,
                    src.js_lib.as_deref(),
                );
                println!("URL\t{name}\tcharset={:?}\t{}", au.charset(), au.url());
                if au.method() == &RequestMethod::Post {
                    println!("BODY\t{name}\t{}", au.request_body());
                }
            }
            let outcome = crate::runtime::block_on(async {
                tokio::time::timeout(
                    SEARCH_SOURCE_TIMEOUT,
                    search_single_source(&client, &src, kw, 1, false),
                )
                .await
            });
            match outcome {
                Ok(Ok(hits)) if !hits.is_empty() => {
                    ok += 1;
                    let ex = hits.iter().filter(|r| r.book_name.contains(kw)).count();
                    if ex > 0 {
                        exact += 1;
                    }
                    println!(
                        "OK\t{name}\tn={}\texact={ex}\tfirst={}",
                        hits.len(),
                        hits[0].book_name
                    );
                }
                Ok(Ok(_)) => println!("EMPTY\t{name}"),
                Ok(Err(e)) => println!("ERR\t{name}\t{e}"),
                Err(_) => println!("TIMEOUT\t{name}"),
            }
        }
        println!("SUMMARY ok={ok} exact={exact} total={}", list.len());
    }

    /// 漫画书源分组端到端搜索探针（与模拟器验收同关键词）
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "e2e network probe"]
    fn probe_manga_group_e2e_search() {
        // 漫画组 e2e 探源（search_books 入口 begin_book_flow）→ 持 crate 级
        // test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use std::collections::BTreeMap;
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/sources.json");
        let raw = std::fs::read_to_string(&path).expect("sources.json");
        let mut data: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        let mut manga = Vec::new();
        for v in &mut data {
            let group = v
                .get("bookSourceGroup")
                .and_then(|x| x.as_str())
                .unwrap_or("");
            if !group.contains("漫画书源") {
                continue;
            }
            if let Some(obj) = v.as_object_mut() {
                for k in [
                    "enabled",
                    "enabledExplore",
                    "enabledCookieJar",
                    "eventListener",
                    "customButton",
                ] {
                    if let Some(n) = obj.get(k).and_then(|x| x.as_i64()) {
                        obj.insert(k.to_string(), serde_json::json!(n != 0));
                    }
                }
            }
            manga.push(v.clone());
        }
        println!("MANGA_GROUP_SOURCES={}", manga.len());
        let _ = crate::api::source::import_sources(
            &serde_json::Value::Array(manga.clone()).to_string(),
        );
        let urls: Vec<String> = manga
            .iter()
            .filter_map(|v| {
                v.get("bookSourceUrl")
                    .and_then(|x| x.as_str())
                    .map(|s| s.to_string())
            })
            .collect();
        let urls_json = serde_json::to_string(&urls).unwrap();
        let kw = "一人之下";
        println!("SEARCH_KW={kw} URLS={}", urls.len());
        match search_books(kw, &urls_json) {
            Ok(list) => {
                // 与原版聚合对比：仅统计书名含关键词的命中（排除作者误匹配等噪声）
                let exact: Vec<_> = list.iter().filter(|r| r.book_name.contains(kw)).collect();
                let mut by_origin: BTreeMap<String, usize> = BTreeMap::new();
                let mut by_origin_exact: BTreeMap<String, usize> = BTreeMap::new();
                for r in &list {
                    *by_origin
                        .entry(format!("{}|{}", r.source_name, r.source_url))
                        .or_default() += 1;
                }
                for r in &exact {
                    *by_origin_exact
                        .entry(format!("{}|{}", r.source_name, r.source_url))
                        .or_default() += 1;
                }
                println!("TOTAL_HITS={}", list.len());
                println!("ORIGINS_WITH_HITS={}", by_origin.len());
                println!("EXACT_TITLE_HITS={}", exact.len());
                println!("EXACT_ORIGINS_WITH_HITS={}", by_origin_exact.len());
                for (k, n) in &by_origin_exact {
                    println!("EXACT_ORIGIN\t{n}\t{k}");
                }
                for key in ["51", "神漫", "快看"] {
                    let b = match exact.iter().find(|r| r.source_name.contains(key)) {
                        Some(r) => *r,
                        None => match list.iter().find(|r| r.source_name.contains(key)) {
                            Some(r) => r,
                            None => {
                                println!("TOC_SKIP\t{key}\tno search hit");
                                continue;
                            }
                        },
                    };
                    let exact_hit = b.book_name.contains(kw);
                    match crate::api::reader::refresh_toc(&b.book_url, &b.source_url) {
                        Ok(toc) => println!(
                            "TOC_OK\t{}\tchapters={}\tbook={}\texact_title={}",
                            b.source_name,
                            toc.chapters.len(),
                            b.book_name,
                            exact_hit
                        ),
                        Err(e) => println!(
                            "TOC_FAIL\t{}\texact_title={}\t{e}",
                            b.source_name, exact_hit
                        ),
                    }
                }
            }
            Err(e) => println!("SEARCH_ERR={e}"),
        }
    }

    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "requires network"]
    fn probe_51_toc_detail() {
        // src_51 目录/详情探测（webbook_chapters / webbook_info 入口
        // begin_book_flow）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();
        let path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../tmp_debug/src_51.json");
        let raw = std::fs::read_to_string(&path).unwrap();
        let mut v: serde_json::Value = serde_json::from_str(&raw).unwrap();
        if let Some(obj) = v.as_object_mut() {
            for k in [
                "enabled",
                "enabledExplore",
                "enabledCookieJar",
                "eventListener",
                "customButton",
            ] {
                if let Some(n) = obj.get(k).and_then(|x| x.as_i64()) {
                    obj.insert(k.to_string(), serde_json::json!(n != 0));
                }
            }
        }
        let src: legado_core::models::BookSource = serde_json::from_value(v).unwrap();
        crate::api::source::import_sources(&serde_json::json!([src.clone()]).to_string()).unwrap();
        let urls = format!(r#"["{}"]"#, src.book_source_url);
        let list = search_books("一人之下", &urls).expect("search");
        println!("search n={}", list.len());
        let b = list.first().expect("hit");
        println!("book={} url={}", b.book_name, b.book_url);
        let engine = crate::api::web_book::build_engine().expect("build_engine");
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        match rt.block_on(engine.get_chapters(&src, &b.book_url)) {
            Ok(chs) => {
                println!("engine_toc n={}", chs.len());
                for c in chs.iter().take(3) {
                    println!("  {} -> {}", c.title, c.url);
                }
            }
            Err(e) => println!("engine_toc err={e}"),
        }
        match crate::api::reader::refresh_toc(&b.book_url, &b.source_url) {
            Ok(t) => println!("refresh_toc n={}", t.chapters.len()),
            Err(e) => println!("refresh_toc err={e}"),
        }
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn offline_51_chapter_list_from_saved_html() {
        let html = std::fs::read_to_string(
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("tests/fixtures/comic_2122.html"),
        )
        .expect("html");
        let rule = concat!(
            "<js>\n",
            "const scripts = Array.from(java.getElement(\"script\")).filter(e => String(e).includes('目录'));\n",
            "const c = scripts[0];\n",
            "d = c\n",
            "  ? JSON.parse(c.html()).itemListElement.map(e => ({ title: e.name, url: e.url }))\n",
            "  : [{ title: book.name, url: java.getString(\".btn-read@href\", src) }];\n",
            "JSON.stringify(d);\n",
            "</js>\n",
            "$[*]",
        );
        let analyzer = crate::js_executor::construct_analyzer_with_js_lib(
            html.clone(),
            "https://51acgs.com/comic/2122".into(),
            "https://51acgs.com",
            None,
        )
        .with_js_binding("book", r#"{"name":"下半身第一主義3"}"#);
        match analyzer.get_elements(rule) {
            Ok(els) => {
                println!("elements n={}", els.len());
                for (i, e) in els.iter().take(5).enumerate() {
                    println!("  [{}] {}", i, &e[..e.len().min(200)]);
                }
                assert!(!els.is_empty(), "expected fallback chapter");
            }
            Err(e) => panic!("get_elements err: {e}"),
        }
        let name = crate::js_executor::construct_analyzer_with_js_lib(
            html,
            "https://51acgs.com/comic/2122".into(),
            "https://51acgs.com",
            None,
        )
        .get_string(".comic-content@.text-primary@text")
        .unwrap_or_default();
        println!("book_name_rule=>{name:?}");
    }

    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "requires network"]
    fn probe_relative_search_urls() {
        // 相对 URL 探源（search_books 入口 begin_book_flow）→ 持 crate 级
        // test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();
        let root = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tmp_debug");
        let raw = std::fs::read_to_string(root.join("sources.json")).unwrap();
        let mut data: Vec<serde_json::Value> = serde_json::from_str(&raw).unwrap();
        let want = [
            "漫蛙",
            "拷贝漫画",
            "包子漫画（优+）",
            "爱看漫画",
            "神漫画",
            "51漫画",
        ];
        for v in &mut data {
            let n = v
                .get("bookSourceName")
                .and_then(|x| x.as_str())
                .unwrap_or("");
            if !want.contains(&n) {
                continue;
            }
            if let Some(obj) = v.as_object_mut() {
                for k in [
                    "enabled",
                    "enabledExplore",
                    "enabledCookieJar",
                    "eventListener",
                    "customButton",
                ] {
                    if let Some(num) = obj.get(k).and_then(|x| x.as_i64()) {
                        obj.insert(k.to_string(), serde_json::json!(num != 0));
                    }
                }
            }
            let src: legado_core::models::BookSource = serde_json::from_value(v.clone()).unwrap();
            let _ =
                crate::api::source::import_sources(&serde_json::json!([src.clone()]).to_string());
            let urls = format!(r#"["{}"]"#, src.book_source_url);
            match search_books("一人之下", &urls) {
                Ok(list) => println!(
                    "REL\t{}\tn={}\turl={}",
                    src.book_source_name,
                    list.len(),
                    src.search_url.as_deref().unwrap_or("")
                ),
                Err(e) => println!("REL\t{}\terr={e}", src.book_source_name),
            }
        }
    }
}

#[cfg(test)]
mod p3f_tests {
    use super::*;
    use legado_core::models::rule::SearchRule;

    fn parse_with(precision: bool, key: &str) -> Vec<SearchResult> {
        let html = r#"<html><body>
            <div class="book-item"><a class="name" href="/b/1">斗破苍穹</a><span class="author">天蚕土豆</span><span class="kind">玄幻</span></div>
            <div class="book-item"><a class="name" href="/b/2">凡人修仙传</a><span class="author">忘语</span><span class="kind">仙侠</span></div>
        </body></html>"#;
        let source = BookSource {
            book_source_url: "https://p3f.example.com".to_string(),
            book_source_name: "P3F-源".to_string(),
            rule_search: Some(SearchRule {
                book_list: Some(".book-item".to_string()),
                name: Some(".name".to_string()),
                author: Some(".author".to_string()),
                kind: Some(".kind".to_string()),
                book_url: Some(".name@href".to_string()),
                ..Default::default()
            }),
            ..BookSource::default()
        };
        parse_search_response_ex(
            html,
            "https://p3f.example.com/s?kw=x",
            &source,
            precision,
            key,
        )
        .unwrap()
    }

    /// SearchModel.kt:106-113:precision 开启 → 仅保留 name/author/kind contains(key) 的条目
    #[test]
    fn test_p3f_precision_filters_non_matching() {
        let results = parse_with(true, "斗破");
        assert_eq!(results.len(), 1, "仅保留 name 含关键词的条目");
        assert_eq!(results[0].book_name, "斗破苍穹");
    }

    #[test]
    fn test_p3f_precision_off_keeps_all() {
        let results = parse_with(false, "斗破");
        assert_eq!(results.len(), 2, "precision 关闭全通过");
    }

    /// author 或 kind 命中同样保留(原版 filter 三字段或语义)
    #[test]
    fn test_p3f_precision_author_match_kept() {
        let results = parse_with(true, "忘语");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].book_name, "凡人修仙传");
    }

    #[test]
    fn test_p3f_precision_kind_match_kept() {
        let results = parse_with(true, "仙侠");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].book_name, "凡人修仙传");
    }

    /// 无任何字段命中 → 全部丢弃
    #[test]
    fn test_p3f_precision_no_match_drops_all() {
        let results = parse_with(true, "雪中悍刀行");
        assert!(results.is_empty());
    }

    /// [R1 变量链复现 2026-09-06] 元素级 @put 导出在换源搜索路径（precision=false、
    /// 关键词=书名）下与主搜索路径（precision=true、关键词=短词）结果应一致：
    /// kind 与 variable 均须导出（换源候选变量依赖此导出）。
    #[test]
    fn test_r1v_switch_search_element_variable_export() {
        let list_html = r#"<html><body><div class="book-item">
<a class="name" href="/r1vb/detail?vid={{svid}}">R1换源验证书</a>
<span class="author">R1作者</span>
<span class="kind">玄幻</span>
<span class="vid">VID123</span></div></body></html>"#;
        let source = BookSource {
            book_source_url: "http://127.0.0.1:8092/r1v/home/b".to_string(),
            book_source_name: "R1VB".to_string(),
            search_url: Some("http://127.0.0.1:8092/r1vb/search?kw={{key}}".to_string()),
            rule_search: Some(SearchRule {
                book_list: Some("class.book-item".to_string()),
                name: Some("class.name@text".to_string()),
                author: Some("class.author@text".to_string()),
                kind: Some("class.kind@text@put:{svid:class.vid@text}".to_string()),
                book_url: Some("class.name@href".to_string()),
                ..SearchRule::default()
            }),
            ..BookSource::default()
        };
        let base = "http://127.0.0.1:8092/r1vb/search?kw=R1";
        for (label, precision, key) in [("主搜索", true, "R1"), ("换源搜索", false, "R1换源验证书")]
        {
            let results =
                parse_search_response_ex(list_html, base, &source, precision, key).unwrap();
            assert_eq!(results.len(), 1, "{label}: 应解析出 1 条");
            println!(
                "{label}: kind={:?} variable={:?} book_url={}",
                results[0].kind, results[0].variable, results[0].book_url
            );
            assert!(
                results[0]
                    .variable
                    .as_deref()
                    .unwrap_or("")
                    .contains("VID123"),
                "{label}: 元素级变量应导出 svid"
            );
        }
    }
}

#[cfg(all(test, feature = "quickjs"))]
mod d4_js_precision_tests {
    use super::*;
    use legado_net::LegadoClientConfig;

    #[tokio::test]
    async fn test_search_single_source_js_precision_filter() {
        let src = BookSource {
            book_source_url: "http://js.test/source".to_string(),
            book_source_name: "JS测试源".to_string(),
            main_js: Some(
                "function search(key, page){ return JSON.stringify([\
                 {name:'斗破苍穹', author:'天蚕土豆', kind:'玄幻', bookUrl:'http://js.test/1'},\
                 {name:'遮天', author:'辰东', kind:'玄幻', bookUrl:'http://js.test/2'}]); }"
                    .to_string(),
            ),
            ..BookSource::default()
        };
        let client = LegadoClient::new(LegadoClientConfig::default()).unwrap();

        // precision=true：书2（遮天/辰东/玄幻 均不含"斗破"）应被过滤
        let on = search_single_source(&client, &src, "斗破", 1, true)
            .await
            .unwrap();
        assert_eq!(on.len(), 1, "precision=true 应过滤 JS 源未命中条目");
        assert_eq!(on[0].book_name, "斗破苍穹");

        // precision=false：两条全通过
        let off = search_single_source(&client, &src, "斗破", 1, false)
            .await
            .unwrap();
        assert_eq!(off.len(), 2);
    }
}

#[cfg(test)]
mod error_class_tests {
    use super::*;

    fn mk_result() -> SearchResult {
        SearchResult {
            source_url: "src".to_string(),
            source_name: "src".into(),
            book_name: "书名".to_string(),
            author: String::new(),
            book_url: "https://ex.com/book/1".to_string(),
            latest_chapter: None,
            intro: None,
            cover_url: None,
            kind: None,
            word_count: None,
            book_type: 0,
            origin_order: 0,
            has_read_record: false,
            read_record_author: None,
            variable: None,
        }
    }

    fn ok_nonempty() -> LegadoResult<Vec<SearchResult>> {
        Ok(vec![mk_result()])
    }

    #[test]
    fn test_ok_nonempty_maps_ok() {
        assert_eq!(classify_source_outcome(&ok_nonempty()), "ok");
    }

    #[test]
    fn test_ok_empty_maps_empty() {
        let r: LegadoResult<Vec<SearchResult>> = Ok(Vec::new());
        assert_eq!(classify_source_outcome(&r), "empty");
    }

    #[test]
    fn test_login_required_maps_login_required() {
        let r = LegadoResult::Err(LegadoError::LoginRequired("未登录".into()));
        assert_eq!(classify_source_outcome(&r), "login_required");
    }

    #[test]
    fn test_timeout_variant_and_batch_wrapper_map_timeout() {
        let r1 = LegadoResult::Err(LegadoError::Timeout("30s".into()));
        assert_eq!(classify_source_outcome(&r1), "timeout");
        // drive_source_batches L791 包装：`搜索超时（{}s）`
        let r2 = LegadoResult::Err(LegadoError::Network("搜索超时（30s）".into()));
        assert_eq!(classify_source_outcome(&r2), "timeout");
    }

    #[test]
    fn test_js_engine_maps_js_error() {
        let r = LegadoResult::Err(LegadoError::JsEngine("quickjs: 规则脚本异常".into()));
        assert_eq!(classify_source_outcome(&r), "js_error");
    }

    #[test]
    fn test_network_panic_wrapper_maps_parser_error() {
        // drive_source_batches L787 包装：单源 panic 隔离
        let r = LegadoResult::Err(LegadoError::Network(
            "单源搜索崩溃: panic at rule eval（已隔离，不影响其他源）".into(),
        ));
        assert_eq!(classify_source_outcome(&r), "parser_error");
    }

    #[test]
    fn test_network_cancel_and_task_error_map_cancelled() {
        // drive_source_batches L775 包装：`搜索已取消`
        let r1 = LegadoResult::Err(LegadoError::Network("搜索已取消".into()));
        assert_eq!(classify_source_outcome(&r1), "cancelled");
        // L827 包装：`搜索任务异常: {e}`（join 错误，最近类归 cancelled）
        let r2 = LegadoResult::Err(LegadoError::Network(
            "搜索任务异常: task was canceled".into(),
        ));
        assert_eq!(classify_source_outcome(&r2), "cancelled");
    }

    #[test]
    fn test_network_generic_maps_http_error() {
        // 其余 Network（含 L312「没有可用书源」、HTTP 层错误）→ http_error
        let r1 = LegadoResult::Err(LegadoError::Network("HTTP 404".into()));
        assert_eq!(classify_source_outcome(&r1), "http_error");
        let r2 = LegadoResult::Err(LegadoError::Network("没有可用书源".into()));
        assert_eq!(classify_source_outcome(&r2), "http_error");
    }

    #[test]
    fn test_parser_family_maps_parser_error() {
        let r1 = LegadoResult::Err(LegadoError::Parser("css: 规则错误".into()));
        assert_eq!(classify_source_outcome(&r1), "parser_error");
        let r2 = LegadoResult::Err(LegadoError::BookParse("书名缺失".into()));
        assert_eq!(classify_source_outcome(&r2), "parser_error");
        let r3 = LegadoResult::Err(LegadoError::Serialization(serde_json::Error::io(
            std::io::Error::other("x"),
        )));
        assert_eq!(classify_source_outcome(&r3), "parser_error");
    }

    #[test]
    fn test_db_ffi_internal_fall_back_to_parser_error() {
        // 无专用类，最近类兜底（报告 §⑤ 说明）
        for r in [
            LegadoResult::Err(LegadoError::Database("db 打开失败".into())),
            LegadoResult::Err(LegadoError::Ffi("ffi 边界错误".into())),
            LegadoResult::Err(LegadoError::Internal("未知内部错误".into())),
        ] {
            assert_eq!(classify_source_outcome(&r), "parser_error");
        }
    }

    #[test]
    fn test_io_maps_http_error() {
        let r = LegadoResult::Err(LegadoError::Io(std::io::Error::other("connect failed")));
        assert_eq!(classify_source_outcome(&r), "http_error");
    }

    #[test]
    fn test_empty_content_variants_map_empty() {
        let r1 = LegadoResult::Err(LegadoError::ContentEmpty("无内容".into()));
        assert_eq!(classify_source_outcome(&r1), "empty");
        let r2 = LegadoResult::Err(LegadoError::TocEmpty("无目录".into()));
        assert_eq!(classify_source_outcome(&r2), "empty");
    }
}

#[cfg(test)]
mod engine_task_tests {
    use super::*;
    use legado_engine::{EngineContext, SearchTasks, TaskGroup};

    #[tokio::test]
    async fn aborting_the_collector_keeps_blocking_work_registered_until_real_exit() {
        let tasks = TaskGroup::default();
        let searches = Arc::new(SearchTasks::new(tasks.clone()));
        let session = searches.start().unwrap();
        let (started, ready) = tokio::sync::oneshot::channel();
        let started = Arc::new(std::sync::Mutex::new(Some(started)));
        let (release, wait) = std::sync::mpsc::channel();
        let wait = Arc::new(std::sync::Mutex::new(wait));
        let running = session.clone();
        let work = session.task().clone();
        let driver = tokio::spawn(async move {
            let _run = SearchRun(running.clone());
            drive_source_batches(
                vec![BookSource::default()],
                1,
                Duration::from_secs(30),
                running.as_ref(),
                &running.paused,
                move |_| {
                    let task = work.clone();
                    let started = started.clone();
                    let wait = wait.clone();
                    async move {
                        tokio::task::spawn_blocking(move || {
                            let _task = task;
                            started.lock().unwrap().take().unwrap().send(()).unwrap();
                            wait.lock()
                                .unwrap()
                                .recv_timeout(Duration::from_secs(5))
                                .unwrap();
                            Ok(Vec::<SearchResult>::new())
                        })
                        .await
                        .unwrap()
                    }
                },
                |_| panic!("丢弃收集器后不能发布"),
            )
            .await;
        });
        ready.await.unwrap();
        driver.abort();
        assert!(driver.await.unwrap_err().is_cancelled());
        assert!(session.is_cancelled());
        drop(session);
        assert!(!tasks.shutdown(Duration::from_millis(10)).await);
        assert_eq!(tasks.active_count(), 1);
        release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(1)).await);
    }

    #[tokio::test]
    async fn paused_session_resumes_with_the_same_task_and_result_sequence() {
        let tasks = TaskGroup::default();
        let searches = Arc::new(SearchTasks::new(tasks.clone()));
        let session = searches.start().unwrap();
        session.set_paused(true);
        let (ready, received) = tokio::sync::oneshot::channel();
        let running = session.clone();
        let driver = tokio::spawn(async move {
            ready.send(()).unwrap();
            let mut delivered = Vec::new();
            drive_source_batches(
                vec![BookSource::default(), BookSource::default()],
                1,
                Duration::from_secs(30),
                running.as_ref(),
                &running.paused,
                |_| async { Ok(Vec::<SearchResult>::new()) },
                |outcome| {
                    delivered.push(outcome.index);
                    Ok(())
                },
            )
            .await;
            delivered
        });
        received.await.unwrap();
        assert_eq!(tasks.active_count(), 1);
        session.set_paused(false);
        assert_eq!(
            tokio::time::timeout(Duration::from_secs(1), driver)
                .await
                .unwrap()
                .unwrap(),
            vec![0, 1]
        );
        assert!(!session.is_cancelled());
        session.finish();
        drop(session);
        assert!(tasks.shutdown(Duration::from_secs(1)).await);
    }

    #[tokio::test]
    async fn captured_search_uses_its_cookie_rules_and_original_database() {
        use std::io::{Read, Write};
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let server = std::thread::spawn(move || {
            for _ in 0..2 {
                let deadline = std::time::Instant::now() + Duration::from_secs(10);
                let mut stream = loop {
                    match listener.accept() {
                        Ok((stream, _)) => break stream,
                        Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                            assert!(std::time::Instant::now() < deadline, "未收到预期搜索请求");
                            std::thread::sleep(Duration::from_millis(5));
                        }
                        Err(error) => panic!("搜索夹具连接失败: {error}"),
                    }
                };
                stream.set_nonblocking(false).unwrap();
                stream
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                let mut request = Vec::new();
                let mut byte = [0];
                while !request.ends_with(b"\r\n\r\n") {
                    assert_eq!(stream.read(&mut byte).unwrap(), 1);
                    request.push(byte[0]);
                    assert!(request.len() < 16384);
                }
                let request = String::from_utf8(request).unwrap();
                let identity = if request.contains("identity=first") {
                    "first"
                } else if request.contains("identity=second") {
                    "second"
                } else {
                    panic!("请求未携带所属实例 Cookie: {request}")
                };
                let body = format!(
                    r#"<div class="book"><a class="name" href="/book/{identity}">{identity}</a><span class="author">author</span></div>"#
                );
                write!(stream, "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len()).unwrap();
            }
        });
        let first = EngineContext::in_memory().unwrap();
        let second = EngineContext::in_memory().unwrap();
        let source: BookSource = serde_json::from_value(serde_json::json!({
            "bookSourceUrl": base,
            "bookSourceName": "实例搜索",
            "searchUrl": format!("{base}/search"),
            "ruleSearch": {"bookList":".book", "name":".name", "author":".author", "bookUrl":".name@href"}
        })).unwrap();
        for (engine, identity) in [(&first, "first"), (&second, "second")] {
            engine
                .storage()
                .with_database(|db| {
                    legado_db::BookSourceRepository::new(db.connection())
                        .insert_batch(std::slice::from_ref(&source))
                })
                .unwrap();
            engine
                .network()
                .set_cookie("127.0.0.1", &format!("identity={identity}"))
                .unwrap();
            engine.source_login_cache().put_login_info(&base, identity);
            let searches = Arc::new(SearchTasks::new(engine.tasks().clone()));
            let session = searches.start().unwrap();
            let context = context_for_engine(engine, engine.network().client().unwrap())
                .with_session(session.clone());
            let rules = source.clone();
            #[cfg(feature = "quickjs")]
            let rules = {
                let mut rules = rules;
                rules.rule_search.as_mut().unwrap().author =
                    Some("@js:source.getLoginInfo()".into());
                rules
            };
            let results = search_single_source_with_context(&context, &rules, "key", 1, false)
                .await
                .unwrap();
            assert_eq!(results.len(), 1);
            assert_eq!(results[0].book_name, identity);
            #[cfg(feature = "quickjs")]
            assert_eq!(results[0].author, identity);
            let books = results
                .into_iter()
                .map(result_to_search_book)
                .collect::<Vec<_>>();
            assert_eq!(
                session.with_current(|| persist_search_books(context.storage(), &books)),
                Some(())
            );
            let next = searches.start().unwrap();
            assert!(
                session
                    .with_current(|| panic!("取消后的源不能再写入或推流"))
                    .is_none()
            );
            assert!(next.is_current());
        }
        server.join().unwrap();
        for (engine, own, other) in [(&first, "first", "second"), (&second, "second", "first")] {
            engine
                .storage()
                .with_database(|db| {
                    let repo = legado_db::SearchBookRepository::new(db.connection());
                    assert!(
                        repo.find_by_book_url(&format!("{base}/book/{own}"))?
                            .is_some()
                    );
                    assert!(
                        repo.find_by_book_url(&format!("{base}/book/{other}"))?
                            .is_none()
                    );
                    Ok(())
                })
                .unwrap();
        }
    }

    #[tokio::test]
    async fn root_shutdown_wakes_paused_dispatch_without_starting_a_source() {
        let tasks = TaskGroup::default();
        let searches = Arc::new(SearchTasks::new(tasks.clone()));
        let session = searches.start().unwrap();
        session.set_paused(true);
        let entered = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let calls = entered.clone();
        let running = session.clone();
        let driver = tokio::spawn(async move {
            drive_source_batches(
                vec![BookSource::default()],
                1,
                Duration::from_secs(30),
                running.as_ref(),
                &running.paused,
                move |_| {
                    calls.fetch_add(1, Ordering::SeqCst);
                    async { Ok(Vec::<SearchResult>::new()) }
                },
                |_| panic!("暂停后取消不能交付结果"),
            )
            .await;
        });
        tokio::task::yield_now().await;
        tasks.cancel();
        tokio::time::timeout(Duration::from_secs(1), driver)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(entered.load(Ordering::SeqCst), 0);
        drop(session);
        assert!(tasks.shutdown(Duration::from_secs(1)).await);
    }

    #[tokio::test]
    async fn sink_close_cancels_the_registered_session_without_publish_reentrance() {
        let tasks = TaskGroup::default();
        let searches = Arc::new(SearchTasks::new(tasks.clone()));
        let session = searches.start().unwrap();
        let callback = session.clone();
        drive_source_batches(
            vec![BookSource::default()],
            1,
            Duration::from_secs(30),
            session.as_ref(),
            &session.paused,
            |_| async { Ok(Vec::<SearchResult>::new()) },
            move |_| {
                callback
                    .with_current(|| Err("sink 已关闭".to_string()))
                    .unwrap_or(Ok(()))
            },
        )
        .await;
        assert!(session.is_cancelled());
        drop(session);
        assert!(tasks.shutdown(Duration::from_secs(1)).await);
    }
}

#[cfg(test)]
mod standalone_task_tests {
    use super::super::source_task_fixture::Fixture;
    use super::*;
    use legado_db::repository::Repository;
    use legado_engine::{EngineContext, SearchTasks};

    fn source(base: &str, path: &str, order: i32) -> BookSource {
        serde_json::from_value(serde_json::json!({
            "bookSourceUrl":format!("{base}/source/{order}"),"bookSourceName":format!("源{order}"),
            "customOrder":order,"searchUrl":format!("{base}/{path}"),
            "ruleSearch":{"bookList":".book","name":".name@text","author":".author@text","bookUrl":"a@href"}
        })).unwrap()
    }
    fn context(engine: &EngineContext) -> SearchContext {
        context_for_engine(engine, engine.network().client().unwrap())
            .with_task(engine.tasks().begin().unwrap())
    }
    fn body(author: &str) -> String {
        format!(
            "<div class='book'><span class='name'>目标书</span><span class='author'>{author}</span><a href='/book/hit'>书</a></div>"
        )
    }

    #[tokio::test]
    async fn precise_search_keeps_source_order_author_matching_early_exit_and_no_persistence() {
        let mut fixture = Fixture::new(2, false, |request| {
            body(if request.starts_with("GET /wrong ") {
                "其他作者"
            } else {
                "目标作者"
            })
        });
        let engine = EngineContext::in_memory().unwrap();
        let searches = Arc::new(SearchTasks::new(engine.tasks().clone()));
        let ui_session = searches.start().unwrap();
        let mut failure = source(&fixture.url, "unused", 0);
        failure.search_url = None;
        let result = precise_search_owned(
            context(&engine),
            "目标书",
            "目标作者",
            vec![
                failure,
                source(&fixture.url, "wrong", 1),
                source(&fixture.url, "match", 2),
                source(&fixture.url, "never", 3),
            ],
        )
        .await
        .unwrap();
        let book = serde_json::to_value(result).unwrap();
        assert_eq!(book["name"], "目标书");
        assert_eq!(book["author"], "目标作者");
        assert_eq!(book["bookUrl"], format!("{}/book/hit", fixture.url));
        assert!(fixture.request().await.starts_with("GET /wrong "));
        assert!(fixture.request().await.starts_with("GET /match "));
        assert!(ui_session.is_current() && !ui_session.is_cancelled());
        engine
            .storage()
            .with_database(|db| {
                assert!(
                    legado_db::SearchBookRepository::new(db.connection())
                        .find_by_book_url(&format!("{}/book/hit", fixture.url))?
                        .is_none()
                );
                Ok(())
            })
            .unwrap();
        drop(ui_session);
        assert_eq!(engine.tasks().active_count(), 0);
        fixture.worker.join().unwrap();
    }

    #[tokio::test]
    async fn cancelling_precise_search_stops_before_the_next_source_and_does_not_become_not_found()
    {
        let mut fixture = Fixture::new(1, true, |_| body("目标作者"));
        let engine = EngineContext::in_memory().unwrap();
        let context = context(&engine);
        let task = context.task().cloned().unwrap();
        let mut run = Box::pin(precise_search_owned(
            context,
            "目标书",
            "目标作者",
            vec![
                source(&fixture.url, "blocked", 1),
                source(&fixture.url, "never", 2),
            ],
        ));
        tokio::select! { _ = fixture.request() => {}, _ = &mut run => panic!("应处于网络等待") }
        task.cancel();
        let error = tokio::time::timeout(Duration::from_secs(2), run)
            .await
            .unwrap()
            .unwrap_err();
        assert!(matches!(error,LegadoError::Network(ref message) if message == "搜索已取消"));
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
        drop(task);
        assert_eq!(engine.tasks().active_count(), 0);
    }

    #[tokio::test]
    async fn dropping_a_standalone_http_search_cancels_its_task_without_cancelling_ui_search() {
        let mut fixture = Fixture::new(1, true, |_| body("目标作者"));
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        let weak = Arc::downgrade(&engine);
        let tasks = engine.tasks().clone();
        let searches = Arc::new(SearchTasks::new(tasks.clone()));
        let ui_session = searches.start().unwrap();
        let context = context(&engine);
        let task = context.task().cloned().unwrap();
        let source = source(&fixture.url, "blocked", 1);
        let mut run = Box::pin(search_single_source_owned(
            context,
            &source,
            "目标书",
            1,
            false,
        ));
        tokio::select! { _ = fixture.request() => {}, _ = &mut run => panic!("应处于网络等待") }
        drop(run);
        assert!(task.is_cancelled());
        assert!(!ui_session.is_cancelled());
        drop(task);
        drop(ui_session);
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(tasks.shutdown(Duration::from_secs(2)).await);
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
    }

    #[test]
    fn loading_search_sources_uses_captured_storage_and_preserves_enabled_order_and_filters() {
        for name in ["甲库", "乙库"] {
            let engine = EngineContext::in_memory().unwrap();
            engine
                .storage()
                .with_database(|db| {
                    let repo = legado_db::BookSourceRepository::new(db.connection());
                    for order in [2, 0, 1] {
                        let mut source = source("https://same-source.test", "search", order);
                        source.book_source_name = format!("{name}{order}");
                        source.enabled = order != 0;
                        repo.insert(&source)?;
                    }
                    Ok(())
                })
                .unwrap();
            let all = load_search_sources_from(Some(engine.storage()), "[]").unwrap();
            assert_eq!(
                all.iter().map(|s| s.custom_order).collect::<Vec<_>>(),
                vec![1, 2]
            );
            assert!(all.iter().all(|s| s.book_source_name.starts_with(name)));
            let selected = load_search_sources_from(
                Some(engine.storage()),
                r#"["https://same-source.test/source/2","https://same-source.test/source/0"]"#,
            )
            .unwrap();
            assert_eq!(selected.len(), 1);
            assert_eq!(selected[0].custom_order, 2);
        }
        assert!(matches!(
            load_search_sources_from(None, "bad"),
            Err(LegadoError::Ffi(_))
        ));
        assert!(matches!(
            load_search_sources_from(None, "[]"),
            Err(LegadoError::Database(_))
        ));
    }

    #[cfg(feature = "quickjs")]
    // mainJs在spawn_blocking中调用同步网络桥，需与真实宿主一样使用多线程运行时。
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn all_four_real_blocking_search_stages_cancel_http_after_entry_is_dropped() {
        for phase in 0..4 {
            let mut gate = Fixture::new(1, true, |_| "放行".into());
            let mut response = if phase >= 2 {
                Some(Fixture::new(1, false, |_| body("目标作者")))
            } else {
                None
            };
            let engine = Arc::new(EngineContext::in_memory().unwrap());
            let tasks = engine.tasks().clone();
            let weak = Arc::downgrade(&engine);
            let context = context(&engine);
            let task = context.task().cloned().unwrap();
            let base = response
                .as_ref()
                .map_or(gate.url.as_str(), |f| f.url.as_str());
            let mut source = source(base, "search", phase);
            let call = format!("java.ajax('{}/gate')", gate.url);
            match phase {
                0 => source.search_url = Some(format!("{base}/search?q={{{{{call}}}}}")),
                1 => {
                    source.main_js = Some(format!(
                        "function search(key,page) {{ const reply = {call}; if (reply !== '放行') throw new Error(reply); return [{{name:'目标书',author:'目标作者',bookUrl:'{base}/book'}}]; }}"
                    ))
                }
                2 => source.login_check_js = Some(format!("{call}; result;")),
                _ => {
                    source.rule_search.as_mut().unwrap().book_list =
                        Some(format!("@js:{call}; result;"))
                }
            }
            let mut run = Box::pin(search_single_source_owned(
                context,
                &source,
                "目标书",
                1,
                false,
            ));
            let request = tokio::select! {
                request = gate.request() => request,
                result = &mut run => panic!("阶段 {phase} 没有进入阻塞等待: {result:?}"),
            };
            assert!(
                request.starts_with("GET /gate "),
                "阶段 {phase} 未进入JS阻塞请求: {request}"
            );
            drop(run);
            assert!(task.is_cancelled());
            drop(task);
            drop(engine);
            assert!(weak.upgrade().is_none(), "阶段 {phase} 强持根实例");
            // HTTP等待已可主动取消，无需服务器先返回；登记仍由阻塞工作实际退出释放。
            assert!(
                tasks.shutdown(Duration::from_secs(5)).await,
                "阶段 {phase} 取消HTTP等待后未释放登记"
            );
            gate.release.send(()).unwrap();
            gate.worker.join().unwrap();
            if let Some(ref mut response) = response {
                response.request().await;
            }
            if let Some(response) = response {
                response.worker.join().unwrap();
            }
        }
    }
}
