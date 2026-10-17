//! 书源调试服务：捕获实例能力，复用抓取与发现，不访问FFI宿主。
//!
//! - `printLog(state, msg)` 语义：经 StreamSink 推送 `{"state":int,"msg":String}`
//! - 关键字分流对齐 `Debug.startDebug(bookSource, key)`：
//!   绝对 URL → 详情；`::` → 发现；`++` → 目录；`--` → 正文；否则搜索
//! - 时间戳格式 `[mm:ss.SSS]`，state=-1 失败 / 1000 完成

use std::sync::{Arc, Mutex};
use std::time::Instant;

use serde::Serialize;

use legado_core::models::BookSource;
use legado_core::{LegadoError, LegadoResult};
use legado_db::BookSourceRepository;
use legado_js::js_source::js_source_debug_formatter::JsSourceDebugFormatter;

use crate::explore_service::ExploreService;
use crate::{Operation, OperationSlot, SourceInfoMap, StorageContext};
use legado_fetcher::deps::FetcherDeps;

/// 只捕获所属实例能力，不保存根引擎或重新发现当前宿主。
pub type DebugFetcherFactory = Arc<dyn Fn() -> LegadoResult<FetcherDeps> + Send + Sync>;
pub struct SourceDebugResources {
    pub storage: Option<StorageContext>,
    pub deps: Option<DebugFetcherFactory>,
    pub info: Arc<SourceInfoMap>,
    pub slot: Arc<OperationSlot>,
    pub runtime: tokio::runtime::Handle,
    pub explore: Arc<ExploreService>,
}
pub struct SourceDebugService {
    resources: SourceDebugResources,
}
impl SourceDebugService {
    pub fn new(resources: SourceDebugResources) -> Self {
        Self { resources }
    }
    pub fn cancel(&self) {
        self.resources.slot.cancel();
    }
    /// 阻塞worker独立保留凭据；丢弃入口只撤销本次发布，不强杀同步工作。
    pub async fn run<F>(&self, source_url: String, key: String, on_log: F)
    where
        F: FnMut(DebugLogItem) -> Result<(), String> + Send + 'static,
    {
        let Ok(operation) = self.resources.slot.start() else {
            return;
        };
        let run = Arc::new(DebugRun {
            source_url,
            start: Instant::now(),
            operation,
            storage: self.resources.storage.clone(),
            deps: self.resources.deps.clone(),
            info: self.resources.info.clone(),
            runtime: self.resources.runtime.clone(),
            explore: self.resources.explore.clone(),
            on_log: Mutex::new(Box::new(on_log)),
        });
        run_debug(run, key).await;
    }
}

/// 单条调试日志；宿主负责适配传输协议。
#[derive(Debug, Clone, Serialize)]
pub struct DebugLogItem {
    pub state: i32,
    pub msg: String,
}

fn format_elapsed(start: Instant) -> String {
    let ms = start.elapsed().as_millis() as u64;
    let m = ms / 60_000;
    let s = (ms % 60_000) / 1000;
    let milli = ms % 1000;
    format!("[{m:02}:{s:02}.{milli:03}]")
}

/// 日志、数据及凭据属于原会话；回调不重新发现当前宿主或日志槽。
type DebugEmitter = Box<dyn FnMut(DebugLogItem) -> Result<(), String> + Send>;

struct DebugRun {
    source_url: String,
    start: Instant,
    operation: Arc<Operation>,
    storage: Option<StorageContext>,
    deps: Option<DebugFetcherFactory>,
    info: Arc<SourceInfoMap>,
    runtime: tokio::runtime::Handle,
    explore: Arc<ExploreService>,
    on_log: Mutex<DebugEmitter>,
}

fn is_abs_url(s: &str) -> bool {
    let lower = s.to_ascii_lowercase();
    lower.starts_with("http://") || lower.starts_with("https://")
}

fn preview(text: &str, max: usize) -> String {
    let t = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if t.chars().count() <= max {
        t
    } else {
        format!("{}…", t.chars().take(max).collect::<String>())
    }
}

struct CancelDebugOnDrop(Arc<Operation>);
impl Drop for CancelDebugOnDrop {
    fn drop(&mut self) {
        self.0.cancel();
    }
}
async fn run_debug(run: Arc<DebugRun>, key: String) {
    let _cancel = CancelDebugOnDrop(run.operation.clone());
    let _guard = run.operation.guard();
    let worker = run.clone();
    let join = tokio::task::spawn_blocking(move || {
        worker.debug_book_source_sync(&worker.source_url, &key)
    });
    if let Err(error) = join.await {
        run.log_debug(None, &format!("调试任务异常: {error}"), -1, false);
    }
}

impl DebugRun {
    fn log_debug(&self, source_url: Option<&str>, msg: &str, state: i32, show_time: bool) {
        if source_url.is_some_and(|url| url != self.source_url) {
            return;
        }
        let item = DebugLogItem {
            state,
            msg: if show_time {
                format!("{} {msg}", format_elapsed(self.start))
            } else {
                msg.into()
            },
        };
        let outcome = self
            .operation
            .publish(|| self.on_log.lock().unwrap_or_else(|p| p.into_inner())(item));
        if matches!(outcome, Some(Err(_))) {
            self.operation.cancel();
        }
    }

    fn emit_lines(&self, source_url: &str, lines: &[String], state: i32) {
        for line in lines {
            self.log_debug(Some(source_url), line, state, true);
        }
    }

    fn load_source(&self, source_url: &str) -> LegadoResult<BookSource> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(|db| {
                BookSourceRepository::new(db.connection())
                    .find_by_url(source_url)?
                    .ok_or_else(|| LegadoError::Ffi(format!("未找到书源: {source_url}")))
            })
    }

    fn fetcher_deps(&self) -> LegadoResult<FetcherDeps> {
        if !self.operation.is_active() {
            return Err(LegadoError::Ffi("书源调试已取消".into()));
        }
        let mut deps =
            self.deps.as_ref().ok_or_else(|| {
                LegadoError::Database("数据库尚未初始化，请先调用 db_open".into())
            })?()?;
        if let Some(sink) = deps.media_sub_content.take() {
            let task = self.operation.task().clone();
            deps.media_sub_content = Some(Arc::new(move |book, source, chapter, key, value| {
                task.with_active(|| sink(book, source, chapter, key, value));
            }));
        }
        Ok(deps)
    }

    fn webbook_search(&self, source: &str, query: &str, page: i32) -> LegadoResult<String> {
        self.runtime
            .block_on(legado_fetcher::web_book::webbook_search(
                self.fetcher_deps()?,
                source,
                query,
                page,
            ))
    }
    fn webbook_info(&self, source: &str, url: &str) -> LegadoResult<String> {
        self.runtime
            .block_on(legado_fetcher::web_book::webbook_info(
                self.fetcher_deps()?,
                source,
                url,
            ))
    }
    fn webbook_chapters(
        &self,
        source: &str,
        url: &str,
        toc: &str,
        name: &str,
    ) -> LegadoResult<String> {
        self.runtime
            .block_on(legado_fetcher::web_book::webbook_chapters(
                self.fetcher_deps()?,
                source,
                url,
                toc,
                name,
            ))
    }
    fn webbook_content(&self, source: &str, chapter: &str) -> LegadoResult<String> {
        self.runtime
            .block_on(legado_fetcher::web_book::webbook_content(
                self.fetcher_deps()?,
                source,
                chapter,
            ))
    }
    fn explore_books(&self, source: &str, url: &str) -> LegadoResult<String> {
        let results = self.explore.explore_fetch_books_entity_with_deps(
            serde_json::from_str(source)?,
            url,
            1,
            self.fetcher_deps()?,
            self.info.snapshot(&self.source_url),
            Some(self.operation.task().clone()),
        )?;
        serde_json::to_string(&results).map_err(LegadoError::Serialization)
    }

    fn debug_book_source_sync(&self, source_url: &str, key: &str) {
        if !self.operation.is_active() {
            return;
        }

        let source = match self.load_source(source_url) {
            Ok(s) => s,
            Err(e) => {
                self.log_debug(Some(source_url), &e.to_string(), -1, true);
                return;
            }
        };
        let source_json = match serde_json::to_string(&source) {
            Ok(j) => j,
            Err(e) => {
                self.log_debug(Some(source_url), &format!("书源序列化失败: {e}"), -1, true);
                return;
            }
        };

        self.log_debug(
            Some(source_url),
            &format!("书源名称: {}", source.book_source_name),
            1,
            true,
        );

        if let Some(chapter_url) = key.strip_prefix("--") {
            self.log_debug(
                Some(source_url),
                &format!("⇒开始访正文页:{chapter_url}"),
                1,
                true,
            );
            self.content_debug(source_url, &source_json, chapter_url, "调试");
        } else if let Some(toc_url) = key.strip_prefix("++") {
            self.log_debug(
                Some(source_url),
                &format!("⇒开始访目录页:{toc_url}"),
                1,
                true,
            );
            self.toc_then_content(source_url, &source_json, toc_url);
        } else if key.contains("::") {
            let url = key.split("::").nth(1).unwrap_or("");
            self.log_debug(Some(source_url), &format!("⇒开始访问发现页:{url}"), 1, true);
            self.explore_debug(source_url, &source_json, url);
        } else if is_abs_url(key) {
            self.log_debug(Some(source_url), &format!("⇒开始访问详情页:{key}"), 1, true);
            self.info_toc_content(source_url, &source_json, key);
        } else {
            self.log_debug(Some(source_url), &format!("⇒开始搜索关键字:{key}"), 1, true);
            self.search_debug(source_url, &source_json, key);
        }
    }

    fn search_debug(&self, source_url: &str, source_json: &str, key: &str) {
        if !self.operation.is_active() {
            return;
        }
        self.log_debug(Some(source_url), "︾开始解析搜索页", 1, true);
        match self.webbook_search(source_json, key, 1) {
            Ok(json) => {
                if !self.operation.is_active() {
                    return;
                }
                let results: Vec<serde_json::Value> =
                    serde_json::from_str(&json).unwrap_or_default();
                if results.is_empty() {
                    self.log_debug(Some(source_url), "︽未获取到书籍", -1, true);
                    return;
                }
                self.log_debug(Some(source_url), "︽搜索页解析完成", 1, true);
                self.log_debug(Some(source_url), "", 1, false);

                let first_name = results.first().and_then(|v| {
                    v.get("name")
                        .or_else(|| v.get("book_name"))
                        .and_then(|x| x.as_str())
                });
                let lines =
                    JsSourceDebugFormatter::format_book_list(source_url, results.len(), first_name);
                self.emit_lines(source_url, &lines, 1);

                for (i, item) in results.iter().take(5).enumerate() {
                    let name = item
                        .get("name")
                        .or_else(|| item.get("book_name"))
                        .and_then(|x| x.as_str())
                        .unwrap_or("未知");
                    let author = item.get("author").and_then(|x| x.as_str()).unwrap_or("");
                    let line = if author.is_empty() {
                        format!("  [{i}] {name}")
                    } else {
                        format!("  [{i}] {name} - {author}")
                    };
                    self.log_debug(Some(source_url), &line, 1, true);
                }

                let book_url = results
                    .first()
                    .and_then(|v| {
                        v.get("book_url")
                            .or_else(|| v.get("bookUrl"))
                            .and_then(|x| x.as_str())
                    })
                    .unwrap_or("");
                if book_url.is_empty() {
                    self.log_debug(Some(source_url), "首条结果无 bookUrl", -1, true);
                    return;
                }
                self.info_toc_content(source_url, source_json, book_url);
            }
            Err(e) => {
                self.log_debug(Some(source_url), &e.to_string(), -1, true);
            }
        }
    }

    fn explore_debug(&self, source_url: &str, source_json: &str, url: &str) {
        if !self.operation.is_active() {
            return;
        }
        self.log_debug(Some(source_url), "︾开始解析发现页", 1, true);
        match self.explore_books(source_json, url) {
            Ok(json) => {
                if !self.operation.is_active() {
                    return;
                }
                let results: Vec<serde_json::Value> =
                    serde_json::from_str(&json).unwrap_or_default();
                if results.is_empty() {
                    self.log_debug(Some(source_url), "︽未获取到书籍", -1, true);
                    return;
                }
                self.log_debug(Some(source_url), "︽发现页解析完成", 1, true);
                self.log_debug(Some(source_url), "", 1, false);
                let book_url = results
                    .first()
                    .and_then(|v| {
                        v.get("book_url")
                            .or_else(|| v.get("bookUrl"))
                            .and_then(|x| x.as_str())
                    })
                    .unwrap_or("");
                if book_url.is_empty() {
                    self.log_debug(Some(source_url), "首条发现结果无 bookUrl", -1, true);
                    return;
                }
                self.info_toc_content(source_url, source_json, book_url);
            }
            Err(e) => {
                self.log_debug(Some(source_url), &e.to_string(), -1, true);
            }
        }
    }

    fn info_toc_content(&self, source_url: &str, source_json: &str, book_url: &str) {
        if !self.operation.is_active() {
            return;
        }
        self.log_debug(Some(source_url), "︾开始解析详情页", 1, true);
        match self.webbook_info(source_json, book_url) {
            Ok(json) => {
                if !self.operation.is_active() {
                    return;
                }
                self.log_debug(Some(source_url), "︽详情页解析完成", 1, true);
                self.log_debug(Some(source_url), "", 1, false);
                if let Ok(info) = serde_json::from_str::<serde_json::Value>(&json) {
                    if let Some(name) = info.get("name").and_then(|x| x.as_str()) {
                        self.log_debug(Some(source_url), "┌获取书名", 1, true);
                        self.log_debug(Some(source_url), &format!("└{name}"), 1, true);
                    }
                    if let Some(author) = info.get("author").and_then(|x| x.as_str()) {
                        self.log_debug(Some(source_url), "┌获取作者", 1, true);
                        self.log_debug(Some(source_url), &format!("└{author}"), 1, true);
                    }
                    let toc_url = info
                        .get("toc_url")
                        .or_else(|| info.get("tocUrl"))
                        .and_then(|x| x.as_str())
                        .unwrap_or(book_url);
                    self.toc_then_content(source_url, source_json, toc_url);
                } else {
                    self.toc_then_content(source_url, source_json, book_url);
                }
            }
            Err(e) => {
                self.log_debug(Some(source_url), &e.to_string(), -1, true);
            }
        }
    }

    fn toc_then_content(&self, source_url: &str, source_json: &str, book_url: &str) {
        if !self.operation.is_active() {
            return;
        }
        self.log_debug(Some(source_url), "︾开始解析目录页", 1, true);
        match self.webbook_chapters(source_json, book_url, "", "") {
            Ok(json) => {
                if !self.operation.is_active() {
                    return;
                }
                let chapters: Vec<serde_json::Value> =
                    serde_json::from_str(&json).unwrap_or_default();
                if chapters.is_empty() {
                    self.log_debug(Some(source_url), "︽未获取到目录", -1, true);
                    return;
                }
                self.log_debug(Some(source_url), "︽目录页解析完成", 1, true);
                self.log_debug(Some(source_url), "", 1, false);

                let first_title = chapters
                    .first()
                    .and_then(|c| c.get("title").or_else(|| c.get("name")))
                    .and_then(|x| x.as_str());
                let last_title = chapters
                    .last()
                    .and_then(|c| c.get("title").or_else(|| c.get("name")))
                    .and_then(|x| x.as_str());
                let lines = JsSourceDebugFormatter::format_chapter_list(
                    source_url,
                    chapters.len(),
                    first_title,
                    last_title,
                );
                self.emit_lines(source_url, &lines, 1);

                let first = &chapters[0];
                let title = first
                    .get("title")
                    .or_else(|| first.get("name"))
                    .and_then(|x| x.as_str())
                    .unwrap_or("调试");
                let chapter_url = first
                    .get("url")
                    .or_else(|| first.get("chapter_url"))
                    .or_else(|| first.get("link"))
                    .and_then(|x| x.as_str())
                    .unwrap_or("");

                if chapter_url.is_empty() {
                    // 用整章 JSON
                    self.log_debug(Some(source_url), "⇒开始获取正文（首章 JSON）", 1, true);
                    self.content_debug_json(source_url, source_json, first, title);
                } else {
                    self.log_debug(
                        Some(source_url),
                        &format!("⇒开始获取正文:{chapter_url}"),
                        1,
                        true,
                    );
                    self.content_debug(source_url, source_json, chapter_url, title);
                }
            }
            Err(e) => {
                self.log_debug(Some(source_url), &e.to_string(), -1, true);
            }
        }
    }

    fn content_debug(&self, source_url: &str, source_json: &str, chapter_url: &str, title: &str) {
        let chapter = serde_json::json!({
            "title": title,
            "url": chapter_url,
            "index": 0,
            "is_vip": false,
        });
        self.content_debug_json(source_url, source_json, &chapter, title);
    }

    fn content_debug_json(
        &self,
        source_url: &str,
        source_json: &str,
        chapter: &serde_json::Value,
        title: &str,
    ) {
        if !self.operation.is_active() {
            return;
        }
        self.log_debug(Some(source_url), "︾开始解析正文页", 1, true);
        let chapter_json = match serde_json::to_string(chapter) {
            Ok(j) => j,
            Err(e) => {
                self.log_debug(Some(source_url), &format!("章节 JSON 失败: {e}"), -1, true);
                return;
            }
        };
        match self.webbook_content(source_json, &chapter_json) {
            Ok(content) => {
                if !self.operation.is_active() {
                    return;
                }
                let lines = JsSourceDebugFormatter::format_content_detail(title, content.len());
                self.emit_lines(source_url, &lines, 1);
                if content.trim().is_empty() {
                    self.log_debug(Some(source_url), "︽正文为空", 1, true);
                } else {
                    self.log_debug(Some(source_url), &preview(&content, 400), 1, true);
                }
                self.log_debug(Some(source_url), "︽正文页解析完成", 1000, true);
            }
            Err(e) => {
                self.log_debug(Some(source_url), &e.to_string(), -1, true);
            }
        }
    }
}

#[cfg(test)]
mod tests;
