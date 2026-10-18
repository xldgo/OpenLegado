//! 宿主注入面（P5 子批 2a）
//!
//! 共享 crate 不持有任何宿主（ffi/server）状态：HTTP 客户端、限流注册表、
//! 登录头缓存、DB 书籍变量、explore snapshot 驱动的书源 setup 脚本全部经
//! [`FetcherDeps`] 注入。字段为 `None` 时对应能力关闭（测试/最小宿主可用
//! `FetcherDeps::new` 起步）；ffi 与 server 两宿主均已全量注入（server 侧
//! 见 `handlers/web_book.rs::server_deps`，数据面为 AppState DB）。

use std::sync::Arc;

use legado_core::models::BookSource;
use legado_net::LegadoClient;

use crate::rate_limit::RateLimiterRegistry;

/// 登录头查询闭包（source_url → loginHeader JSON）
pub type LoginHeaderLookup = Arc<dyn Fn(&str) -> Option<String> + Send + Sync>;

/// 书籍变量查询闭包（书籍取址点 → variable JSON）
pub type BookVariableLookup = Arc<dyn Fn(&str) -> Option<String> + Send + Sync>;

/// 书源 JS setup 脚本生成闭包（source → setup script）
pub type SourceContextBuilder = Arc<dyn Fn(&BookSource) -> Option<String> + Send + Sync>;

/// 媒体副内容捕获闭包（bookUrl, sourceUrl, chapterUrl, key, value）
///
/// 契约 §2.49 写入侧：视频/音频书源的内容规则副内容（`contentRule.subContent`）
/// 在抓取链内捕获后交宿主落库（对齐原版 `BookContent.kt:138-155`
/// 音频 `putLyric` / 视频 `putDanmaku`）。`bookUrl` 为 `None` 表示抓取链
/// 未解析到书籍取址点（详情/目录阶段 meta 缓存未命中，如 `refreshToc`
/// 目录链）——宿主可据 `sourceUrl` + `chapterUrl` 走 DB 兜底反查后落库。
/// 共享 crate 不直接触库——本闭包是唯一落库出口（同 `book_variable` 注入先例）。
pub type MediaSubContentSink = Arc<dyn Fn(Option<&str>, &str, &str, &str, &str) + Send + Sync>;

/// 宿主注入载体
///
/// - `client`：所属引擎的 HTTP 客户端（ffi 由 `http_state::shared_client()`
///   委托根实例取得；测试可传独立客户端）；
/// - `web_book`：HTML、书籍元信息、章节关系及目录刷新代数，同引擎连续调用共享；
/// - `js`：规则与 mainJs 的显式执行资源，缓存 VM 不跨引擎共享；
/// - `rate_limiter`：书源 `concurrentRate` 限流注册表（同引擎共享，按书源 URL
///   缓存窗口状态）；
/// - `login_header`：按书源 URL 取登录头 JSON（ffi=`source_login_cache`）；
/// - `book_variable`：按书籍取址点读用户书籍变量 JSON（ffi=`books.variable`
///   两路反查 bookUrl → originBookUrl）；
/// - `source_context`：按书源生成 JS setup 脚本（ffi=`source_js_bindings::
///   book_source_js_setup_script`，依赖 explore_info_map snapshot + 登录缓存）；
/// - `media_sub_content`：媒体副内容落库（ffi=`video_api::put_media_sub_content`，
///   章节 variable / 大数据文件分流，契约 §2.49）。
#[derive(Clone)]
pub struct FetcherDeps {
    /// HTTP 客户端
    pub client: LegadoClient,
    /// 本次操作的仅数据寿命凭据；不得存入 VM/常驻资源，避免反向依赖宿主。
    pub execution_lease: Option<Arc<dyn Send + Sync>>,
    /// 引擎拥有的 HTML、书籍元信息与章节映射缓存。
    pub web_book: Arc<crate::web_book_state::WebBookState>,
    /// 所属引擎的 JS 执行资源，无 quickjs 时不包含 VM。
    pub js: Arc<legado_js::JsResources>,
    /// 书源限流注册表
    pub rate_limiter: Arc<RateLimiterRegistry>,
    /// 登录头查询（source_url → loginHeader JSON）
    pub login_header: Option<LoginHeaderLookup>,
    /// 书籍变量查询（书籍取址点 → variable JSON）
    pub book_variable: Option<BookVariableLookup>,
    /// 书源 JS setup 脚本生成（source → setup script）
    pub source_context: Option<SourceContextBuilder>,
    /// 媒体副内容捕获（bookUrl, chapterUrl, key, value）
    pub media_sub_content: Option<MediaSubContentSink>,
}

impl FetcherDeps {
    /// 本次抓取的JS任务能力，缓存VM不会永久捕获它。
    pub fn with_cancellation(
        mut self,
        control: Arc<dyn legado_js::cancellation::JsCancellation>,
    ) -> Self {
        self.js = self.js.with_cancellation(control);
        self
    }
    pub fn with_execution_lease(mut self, lease: Arc<dyn Send + Sync>) -> Self {
        self.execution_lease = Some(lease);
        self
    }

    /// 正文请求与 WebView 从本次注入的客户端读取 Cookie，不查询 JS 进程镜像。
    pub(crate) fn cookies_for_url(&self, url: &str) -> String {
        if url.trim().is_empty() {
            return String::new();
        }
        self.client
            .cookie_store()
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .cookies_for_key(url)
    }

    pub(crate) fn merge_cookies(
        &self,
        headers: &mut std::collections::HashMap<String, String>,
        url: &str,
    ) {
        legado_js::host_api::cookie_store::merge_cookie_string(headers, &self.cookies_for_url(url));
    }

    /// 仅注入客户端（其余能力为 None：登录头/书籍变量/书源 setup/副内容捕获全关闭）
    pub fn new(client: LegadoClient) -> Self {
        let js = legado_js::JsResources::default();
        #[cfg(feature = "quickjs")]
        let js = js.with_http_resources(Arc::new(
            legado_js::http_resources::HttpResources::with_memory_cookie_store(
                client.cookie_store().clone(),
            )
            .with_custom_hosts(client.custom_hosts()),
        ));
        Self {
            client,
            execution_lease: None,
            web_book: Arc::new(crate::web_book_state::WebBookState::default()),
            js: Arc::new(js),
            rate_limiter: Arc::new(RateLimiterRegistry::new()),
            login_header: None,
            book_variable: None,
            source_context: None,
            media_sub_content: None,
        }
    }

    /// [`Self::new`] 别名（可读性：以客户端为最小注入面）
    pub fn with_client(client: LegadoClient) -> Self {
        Self::new(client)
    }

    /// 同一引擎的宿主和连续抓取调用共享缓存；默认构造保持实例隔离。
    pub fn with_web_book_state(mut self, state: Arc<crate::web_book_state::WebBookState>) -> Self {
        self.web_book = state;
        self
    }

    /// 规则与 mainJs 执行沿用同一引擎资源。
    pub fn with_js_resources(mut self, resources: Arc<legado_js::JsResources>) -> Self {
        self.js = resources;
        self
    }

    /// 同来源/同书籍阶段共享句柄，不借用宿主的“当前流程”。
    pub fn for_book(&self, source: &str, book: &str) -> Self {
        self.clone()
            .with_js_resources(self.js.for_book(source, book))
    }

    /// 已绑定书籍的调用允许变更实际取址点，不能因此改写逻辑书籍身份。
    pub fn for_book_request(&self, source: &str, fallback_book: &str) -> Self {
        if self
            .js
            .variable_scope()
            .and_then(|scope| scope.book_source())
            == Some(source)
        {
            self.clone()
        } else {
            self.for_book(source, fallback_book)
        }
    }

    pub fn for_source(&self, purpose: &str, source: &str, key: &str) -> Self {
        self.clone()
            .with_js_resources(self.js.for_source(purpose, source, key))
    }

    /// 页面缓存按来源和本次请求头分区；键只在内存中使用，不记录凭据。
    pub(crate) fn page_cache_key(
        &self,
        url: &str,
        headers: Option<&std::collections::HashMap<String, String>>,
    ) -> String {
        let headers: std::collections::BTreeMap<_, _> =
            headers.into_iter().flat_map(|map| map.iter()).collect();
        serde_json::to_string(&(
            self.js
                .variable_scope()
                .and_then(|scope| scope.source_identity()),
            url,
            headers,
        ))
        .expect("字符串缓存身份可序列化")
    }

    /// 注入限流注册表
    pub fn with_rate_limiter(mut self, rate_limiter: Arc<RateLimiterRegistry>) -> Self {
        self.rate_limiter = rate_limiter;
        self
    }

    /// 注入登录头查询
    pub fn with_login_header(mut self, f: LoginHeaderLookup) -> Self {
        self.login_header = Some(f);
        self
    }

    /// 注入书籍变量查询
    pub fn with_book_variable(mut self, f: BookVariableLookup) -> Self {
        self.book_variable = Some(f);
        self
    }

    /// 注入书源 JS setup 脚本生成
    pub fn with_source_context(mut self, f: SourceContextBuilder) -> Self {
        self.source_context = Some(f);
        self
    }

    /// 注入媒体副内容捕获（契约 §2.49 写入侧；未注入 → 捕获点仅日志）
    pub fn with_media_sub_content_sink(mut self, f: MediaSubContentSink) -> Self {
        self.media_sub_content = Some(f);
        self
    }

    /// 捕获媒体副内容交宿主落库（对齐原版 `BookChapter.putLyric/putDanmaku`）
    ///
    /// 返回是否已交给宿主 sink。未注入 sink 或 `book_url` 未知（详情/目录
    /// 阶段 meta 缓存未命中）时仅记日志——副内容是增强层，任何缺失/失败
    /// 均不得阻断正文返回（对齐原版 `runCatching` 仅记日志语义）；宿主
    /// sink 可据 `source_url` + `chapter_url` 走 DB 兜底反查书籍取址点。
    pub fn capture_media_sub_content(
        &self,
        book_url: Option<&str>,
        source_url: &str,
        chapter_url: &str,
        key: &str,
        value: &str,
    ) -> bool {
        let Some(sink) = self.media_sub_content.as_ref() else {
            eprintln!(
                "[web_book] 媒体副内容（{key}）未落库：宿主未注入捕获 sink\
                 （book={book_url:?}，chapter={chapter_url}）"
            );
            return false;
        };
        let book_url = book_url.filter(|u| !u.trim().is_empty());
        if book_url.is_none() {
            // 抓取链 meta 未命中 → 交宿主兜底反查（sourceUrl + chapterUrl）
            eprintln!(
                "[web_book] 媒体副内容（{key}）书本取址点未命中 meta 缓存，\
                 转宿主 DB 兜底（source={source_url}，chapter={chapter_url}）"
            );
        }
        sink(book_url, source_url, chapter_url, key, value);
        true
    }

    /// 按书源 URL 取登录头 JSON（未注入 → None）
    pub fn login_header_for(&self, source_url: &str) -> Option<String> {
        self.login_header.as_ref().and_then(|f| f(source_url))
    }

    /// 按书籍取址点取用户书籍变量（未注入/空值 → None；空串过滤与原
    /// `db_book_variable` 语义一致）
    pub fn book_variable_for(&self, book_url: &str) -> Option<String> {
        self.book_variable
            .as_ref()
            .and_then(|f| f(book_url))
            .filter(|v| !v.trim().is_empty())
    }

    /// 按书源生成 JS setup 脚本（未注入 → None，等价无书源上下文）
    pub fn setup_script_for(&self, source: &BookSource) -> Option<String> {
        self.source_context.as_ref().and_then(|f| f(source))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    #[test]
    fn web_requests_and_webview_read_only_the_injected_client_cookie_jar() {
        let one = FetcherDeps::new(test_client());
        let two = FetcherDeps::new(test_client());
        one.client
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("book.test", "one=value; same=jar");
        two.client
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("book.test", "two=value");
        let url = "https://sub.book.test/page";
        let mut headers =
            std::collections::HashMap::from([("cOoKiE".into(), "same=explicit".into())]);
        one.merge_cookies(&mut headers, url);
        let values = legado_net::CookieStore::cookie_string_to_map(&headers["cOoKiE"]);
        assert_eq!(values.get("same").unwrap(), "explicit");
        assert_eq!(values.get("one").unwrap(), "value");
        assert!(!values.contains_key("two"));
        assert_eq!(two.cookies_for_url(url), "two=value");
        assert_eq!(one.cookies_for_url("https://foreign.test"), "");
        assert_eq!(one.cookies_for_url(""), "");
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn minimal_host_js_uses_the_injected_client_jar_in_both_directions() {
        use legado_js::JsEngine;
        let deps = FetcherDeps::new(test_client());
        let vm = deps
            .js
            .create_engine(legado_js::SandboxConfig::default())
            .unwrap();
        vm.eval("java.setCookie('https://minimal.test','fromJs=one')")
            .unwrap();
        assert_eq!(
            deps.cookies_for_url("https://minimal.test/chapter"),
            "fromJs=one"
        );
        deps.client
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("minimal.test", "fromHttp=two");
        assert_eq!(
            vm.eval("java.getCookie('https://minimal.test','fromHttp')")
                .unwrap(),
            "two"
        );
    }

    /// 捕获调用记录：(bookUrl, sourceUrl, chapterUrl, key, value)
    type CapturedCalls = Arc<Mutex<Vec<(String, String, String, String, String)>>>;

    fn test_client() -> LegadoClient {
        LegadoClient::new(legado_net::LegadoClientConfig {
            no_proxy: true,
            ..legado_net::LegadoClientConfig::default()
        })
        .expect("test http client")
    }

    /// [V-B1 §2.49] 注入 sink 且 bookUrl 已知 → 闭包收到完整五元组
    #[test]
    fn test_capture_media_sub_content_calls_sink() {
        let got: CapturedCalls = Arc::new(Mutex::new(Vec::new()));
        let sink_got = Arc::clone(&got);
        let deps = FetcherDeps::new(test_client()).with_media_sub_content_sink(Arc::new(
            move |book, source, chapter, key, value| {
                sink_got.lock().unwrap().push((
                    book.unwrap_or_default().to_string(),
                    source.to_string(),
                    chapter.to_string(),
                    key.to_string(),
                    value.to_string(),
                ));
            },
        ));

        assert!(deps.capture_media_sub_content(
            Some("https://b.example/book"),
            "https://b.example",
            "https://b.example/ch/1",
            "danmaku",
            "<i><d p=\"1\"/></i>"
        ));
        let got = got.lock().unwrap();
        assert_eq!(got.len(), 1);
        assert_eq!(got[0].0, "https://b.example/book");
        assert_eq!(got[0].1, "https://b.example");
        assert_eq!(got[0].2, "https://b.example/ch/1");
        assert_eq!(got[0].3, "danmaku");
        assert_eq!(got[0].4, "<i><d p=\"1\"/></i>");
    }

    /// [V-B1 §2.49] 未注入 sink → 返回 false 且不 panic；bookUrl 未知时
    /// 仍调用 sink（宿主走 DB 兜底反查），book 参数为 None
    #[test]
    fn test_capture_media_sub_content_degrades_without_sink_or_book() {
        // 未注入 sink → false（降级仅日志，不阻断正文）
        let deps = FetcherDeps::new(test_client());
        assert!(!deps.capture_media_sub_content(
            Some("https://b.example/book"),
            "https://b.example",
            "https://b.example/ch/1",
            "danmaku",
            "x"
        ));

        // 注入 sink 但 bookUrl 未知 → 仍交宿主（sourceUrl 供兜底反查）
        let seen: Arc<Mutex<Vec<Option<String>>>> = Arc::new(Mutex::new(Vec::new()));
        let sink_seen = Arc::clone(&seen);
        let deps = FetcherDeps::new(test_client()).with_media_sub_content_sink(Arc::new(
            move |book, _, _, _, _| {
                sink_seen.lock().unwrap().push(book.map(str::to_string));
            },
        ));
        assert!(deps.capture_media_sub_content(
            None,
            "https://b.example",
            "https://b.example/ch/1",
            "lyric",
            "x"
        ));
        assert!(deps.capture_media_sub_content(
            Some("  "),
            "https://b.example",
            "https://b.example/ch/1",
            "lyric",
            "x"
        ));
        assert_eq!(
            seen.lock().unwrap().as_slice(),
            &[None, None],
            "bookUrl 未知/空白时应以 None 交宿主兜底"
        );
    }
}
