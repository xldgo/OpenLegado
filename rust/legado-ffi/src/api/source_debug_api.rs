//! 书源调试流式 API（对齐 Kotlin `Debug.Callback`）
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

use crate::api::web_book::CapturedFetcherFactory;
use legado_engine::{Operation, SourceInfoMap, StorageContext};
use legado_fetcher::deps::FetcherDeps;

/// 单条调试日志（跨 FFI JSON）
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
    deps: Option<CapturedFetcherFactory>,
    info: Arc<SourceInfoMap>,
    on_log: Mutex<DebugEmitter>,
}

/// 取消宿主自己的当前调试，不影响校验或其他实例。
pub fn cancel_debug_book_source() {
    crate::engine_holder::source_debug().cancel();
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

/// 流式调试书源；阻塞 worker 即使入口被丢弃也持有原任务凭据。
pub async fn run_debug_book_source_stream<F>(source_url: String, key: String, on_log: F)
where
    F: FnMut(DebugLogItem) -> Result<(), String> + Send + 'static,
{
    let slot = crate::engine_holder::source_debug();
    let Ok(operation) = slot.start() else {
        return;
    };
    let engine = crate::engine_holder::current().ok();
    let run = Arc::new(DebugRun {
        source_url,
        start: Instant::now(),
        operation,
        storage: engine.as_ref().map(|engine| engine.storage().clone()),
        deps: engine
            .as_ref()
            .map(|engine| crate::api::web_book::deps_for_engine(engine)),
        info: crate::engine_holder::source_info_map(),
        on_log: Mutex::new(Box::new(on_log)),
    });
    drop(engine);
    run_debug(run, key).await;
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
        crate::runtime::block_on(legado_fetcher::web_book::webbook_search(
            self.fetcher_deps()?,
            source,
            query,
            page,
        ))
    }
    fn webbook_info(&self, source: &str, url: &str) -> LegadoResult<String> {
        crate::runtime::block_on(legado_fetcher::web_book::webbook_info(
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
        crate::runtime::block_on(legado_fetcher::web_book::webbook_chapters(
            self.fetcher_deps()?,
            source,
            url,
            toc,
            name,
        ))
    }
    fn webbook_content(&self, source: &str, chapter: &str) -> LegadoResult<String> {
        crate::runtime::block_on(legado_fetcher::web_book::webbook_content(
            self.fetcher_deps()?,
            source,
            chapter,
        ))
    }
    fn explore_books(&self, source: &str, url: &str) -> LegadoResult<String> {
        crate::api::explore_api::explore_fetch_books_with_deps(
            source,
            url,
            1,
            self.fetcher_deps()?,
            self.info.snapshot(&self.source_url),
            Some(self.operation.task().clone()),
        )
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
mod tests {
    use super::super::source_task_fixture::Fixture;
    use super::*;
    use legado_db::repository::Repository;

    #[test]
    fn test_format_elapsed_zeroish() {
        let start = Instant::now();
        let s = format_elapsed(start);
        assert!(s.starts_with('['));
        assert!(s.contains(':'));
    }

    #[test]
    fn test_debug_log_item_json() {
        let item = DebugLogItem {
            state: 1000,
            msg: "[00:01.000] ︽正文页解析完成".into(),
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"state\":1000"));
        assert!(json.contains("正文页解析完成"));
    }

    #[test]
    fn test_is_abs_url() {
        assert!(is_abs_url("https://example.com/book/1"));
        assert!(is_abs_url("HTTP://a.com"));
        assert!(!is_abs_url("斗破苍穹"));
        assert!(!is_abs_url("++https://a.com/toc"));
    }

    use legado_engine::{EngineContext, OperationSlot};
    use std::time::Duration;

    fn run_for_engine(
        engine: &EngineContext,
        slot: &Arc<OperationSlot>,
        source_url: &str,
        logs: Arc<Mutex<Vec<serde_json::Value>>>,
    ) -> Arc<DebugRun> {
        Arc::new(DebugRun {
            source_url: source_url.into(),
            start: Instant::now(),
            operation: slot.start().unwrap(),
            storage: Some(engine.storage().clone()),
            deps: Some(crate::api::web_book::deps_for_engine(engine)),
            info: engine.source_info_map().clone(),
            on_log: Mutex::new(Box::new(move |item| {
                logs.lock()
                    .unwrap()
                    .push(serde_json::to_value(item).unwrap());
                Ok(())
            })),
        })
    }

    fn seed(engine: &EngineContext, url: &str, name: &str) {
        let source: BookSource = serde_json::from_value(serde_json::json!({
            "bookSourceUrl":url,"bookSourceName":name,
            "searchUrl":format!("{url}/search"),
            "ruleSearch":{"bookList":".book","name":".name@text","bookUrl":"a@href"},
            "ruleExplore":{"bookList":".book","name":".name@text","bookUrl":"a@href"},
            "ruleBookInfo":{"name":".name@text","author":".author@text","tocUrl":".toc@href"},
            "ruleToc":{"chapterList":".chapter","chapterName":"a@text","chapterUrl":"a@href"},
            "ruleContent":{"content":".content@text","subContent":".sub@text"}
        }))
        .unwrap();
        engine
            .storage()
            .with_database(|db| BookSourceRepository::new(db.connection()).insert(&source))
            .unwrap();
    }

    #[tokio::test]
    async fn real_debug_steps_and_logs_use_only_the_original_engine_and_cookie() {
        let mut fixture = Fixture::new(8, false, |request| {
            let identity = if request.contains("identity=first") {
                "甲"
            } else {
                "乙"
            };
            if request.starts_with("GET /search ") {
                format!(
                    "<div class='book'><span class='name'>{identity}书</span><a href='/book'>书</a></div>"
                )
            } else if request.starts_with("GET /book ") {
                format!(
                    "<span class='name'>{identity}书</span><span class='author'>作者</span><a class='toc' href='/toc'>目录</a>"
                )
            } else if request.starts_with("GET /toc ") {
                "<div class='chapter'><a href='/chapter'>第一章</a></div>".into()
            } else {
                format!("<div class='content'>{identity}实例正文</div>")
            }
        });
        for (identity, name) in [("first", "甲源"), ("second", "乙源")] {
            let engine = EngineContext::in_memory().unwrap();
            seed(&engine, &fixture.url, name);
            engine
                .network()
                .set_cookie("127.0.0.1", &format!("identity={identity}"))
                .unwrap();
            let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
            let logs = Arc::new(Mutex::new(Vec::new()));
            let run = run_for_engine(&engine, &slot, &fixture.url, logs.clone());
            run_debug(run, "关键字".into()).await;
            {
                let logs = logs.lock().unwrap();
                assert!(
                    logs.iter().any(|log| log["state"] == 1000),
                    "没有完成正文调试: {logs:?}"
                );
                assert!(
                    logs.iter()
                        .any(|log| log["msg"].as_str().unwrap().contains(name))
                );
                let expected = if identity == "first" {
                    "甲实例正文"
                } else {
                    "乙实例正文"
                };
                assert!(
                    logs.iter()
                        .any(|log| log["msg"].as_str().unwrap().contains(expected))
                );
            }
            for _ in 0..4 {
                assert!(
                    fixture
                        .request()
                        .await
                        .contains(&format!("identity={identity}"))
                );
            }
            assert_eq!(engine.tasks().active_count(), 0);
            assert!(slot.current().is_none());
        }
        fixture.worker.join().unwrap();
    }

    #[tokio::test]
    async fn replaced_real_debug_cannot_publish_to_or_clear_the_next_session() {
        let mut fixture = Fixture::new(1, true, |_| "<div class='content'>迟到正文</div>".into());
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        seed(&engine, &fixture.url, "原源");
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let old_logs = Arc::new(Mutex::new(Vec::new()));
        let old = run_for_engine(&engine, &slot, &fixture.url, old_logs.clone());
        let mut future = Box::pin(run_debug(old.clone(), format!("--{}/chapter", fixture.url)));
        tokio::select! { _ = fixture.request() => {}, _ = &mut future => panic!("请求应等待响应") }
        let count = old_logs.lock().unwrap().len();
        let next_logs = Arc::new(Mutex::new(Vec::new()));
        let next = run_for_engine(&engine, &slot, &fixture.url, next_logs.clone());
        fixture.release.send(()).unwrap();
        tokio::time::timeout(Duration::from_secs(5), future)
            .await
            .unwrap();
        assert_eq!(old_logs.lock().unwrap().len(), count);
        assert!(next.operation.is_active());
        next.log_debug(None, "新会话仍可发布", 1, false);
        assert_eq!(next_logs.lock().unwrap().len(), 1);
        drop(old);
        next.operation.finish();
        drop(next);
        assert_eq!(engine.tasks().active_count(), 0);
        fixture.worker.join().unwrap();
    }

    #[tokio::test]
    async fn abandoned_real_debug_keeps_blocking_worker_but_does_not_retain_root() {
        let mut fixture = Fixture::new(1, true, |_| {
            format!(
                "<div class='content'>https://cdn.example/late.mp4</div><div class='sub'>{}</div>",
                "迟到弹幕".repeat(3000)
            )
        });
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        seed(&engine, &fixture.url, "原源");
        let book = format!("{}/book", fixture.url);
        let chapter = format!("{}/chapter", fixture.url);
        engine
            .storage()
            .with_database(|db| {
                let repo = BookSourceRepository::new(db.connection());
                let mut source = repo.find_by_url(&fixture.url)?.unwrap();
                source.book_source_type = 4;
                repo.update(&source)?;
                legado_db::BookRepository::new(db.connection()).insert(
                    &legado_core::models::Book {
                        book_url: book.clone(),
                        origin: fixture.url.clone(),
                        name: "媒体书".into(),
                        ..Default::default()
                    },
                )?;
                legado_db::BookChapterRepository::new(db.connection()).insert_batch(&[
                    legado_core::models::BookChapter {
                        book_url: book.clone(),
                        url: chapter.clone(),
                        title: "第一章".into(),
                        ..Default::default()
                    },
                ])
            })
            .unwrap();
        let storage = engine.storage().clone();
        let weak = Arc::downgrade(&engine);
        let tasks = engine.tasks().clone();
        let slot = Arc::new(OperationSlot::new(tasks.clone()));
        let logs = Arc::new(Mutex::new(Vec::new()));
        let run = run_for_engine(&engine, &slot, &fixture.url, logs.clone());
        let mut future = Box::pin(run_debug(run, format!("--{}/chapter", fixture.url)));
        tokio::select! { _ = fixture.request() => {}, _ = &mut future => panic!("请求应等待响应") }
        drop(future);
        let count = logs.lock().unwrap().len();
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(!tasks.shutdown(Duration::from_millis(20)).await);
        fixture.release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(5)).await);
        assert_eq!(logs.lock().unwrap().len(), count);
        assert!(slot.current().is_none());
        storage
            .with_database(|db| {
                let saved = legado_db::BookChapterRepository::new(db.connection())
                    .find_by_book_url_and_index(&book, 0)?
                    .unwrap();
                assert!(!saved.variable.unwrap_or_default().contains("danmaku"));
                Ok(())
            })
            .unwrap();
        let directory = storage.data_directory("ruleData").unwrap();
        assert!(
            legado_db::rule_big_data::RuleBigDataManager::new(&directory)
                .get_chapter_variable(&book, &chapter, "danmaku")
                .unwrap()
                .is_none()
        );
        fixture.worker.join().unwrap();
    }

    #[test]
    fn closed_log_sink_cancels_only_its_own_session_without_reentrant_deadlock() {
        let engine = EngineContext::in_memory().unwrap();
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let operation = slot.start().unwrap();
        let run = DebugRun {
            source_url: "source".into(),
            start: Instant::now(),
            operation: operation.clone(),
            storage: None,
            deps: None,
            info: engine.source_info_map().clone(),
            on_log: Mutex::new(Box::new(|_| Err("sink 已关闭".into()))),
        };
        run.log_debug(None, "日志", 1, false);
        assert!(!operation.is_active());
        assert!(!engine.tasks().is_closed());
        run.log_debug(None, "迟到日志", 1, false);
        assert!(slot.start().unwrap().is_active());
    }

    #[tokio::test]
    async fn debug_explore_uses_captured_dependencies_instead_of_the_ffi_host() {
        let mut fixture = Fixture::new(1, false, |_| {
            "<div class='book'><span class='name'>发现书</span><a href='/book'>书</a></div>".into()
        });
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine, &fixture.url, "发现源");
        engine
            .network()
            .set_cookie("127.0.0.1", "identity=explore")
            .unwrap();
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let run = run_for_engine(
            &engine,
            &slot,
            &fixture.url,
            Arc::new(Mutex::new(Vec::new())),
        );
        let source = run.load_source(&fixture.url).unwrap();
        let json = serde_json::to_string(&source).unwrap();
        let url = format!("{}/explore", fixture.url);
        let result = tokio::task::spawn_blocking(move || run.explore_books(&json, &url))
            .await
            .unwrap()
            .unwrap();
        let books: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(books[0]["name"], "发现书");
        assert!(fixture.request().await.contains("identity=explore"));
        fixture.worker.join().unwrap();
    }
    #[tokio::test]
    async fn worker_panic_reports_only_to_its_own_sink_and_releases_the_slot() {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine, "https://panic-debug.test", "异常源");
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let logs = Arc::new(Mutex::new(Vec::new()));
        let mut run = run_for_engine(&engine, &slot, "https://panic-debug.test", logs.clone());
        Arc::get_mut(&mut run).unwrap().deps = Some(Arc::new(|| panic!("调试任务异常夹具")));
        run_debug(run, "关键字".into()).await;
        assert!(
            logs.lock().unwrap().iter().any(|log| log["state"] == -1
                && log["msg"].as_str().unwrap().starts_with("调试任务异常:"))
        );
        assert_eq!(engine.tasks().active_count(), 0);
        assert!(slot.current().is_none());
        assert!(slot.start().unwrap().is_active());
    }
    #[tokio::test]
    async fn key_dispatch_executes_all_five_real_debug_routes() {
        for (route, count) in [(0, 4), (1, 3), (2, 2), (3, 1), (4, 4)] {
            let mut fixture = Fixture::new(count, false, |request| {
                if request.starts_with("GET /search ") || request.starts_with("GET /explore ") {
                    "<div class='book'><span class='name'>测试书</span><a href='/book'>书</a></div>"
                        .into()
                } else if request.starts_with("GET /book ") {
                    "<span class='name'>测试书</span><a class='toc' href='/toc'>目录</a>".into()
                } else if request.starts_with("GET /toc ") {
                    "<div class='chapter'><a href='/chapter'>第一章</a></div>".into()
                } else {
                    "<div class='content'>分流正文</div>".into()
                }
            });
            let engine = EngineContext::in_memory().unwrap();
            seed(&engine, &fixture.url, "分流源");
            let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
            let logs = Arc::new(Mutex::new(Vec::new()));
            let run = run_for_engine(&engine, &slot, &fixture.url, logs.clone());
            let key = match route {
                0 => "关键字".into(),
                1 => format!("{}/book", fixture.url),
                2 => format!("++{}/toc", fixture.url),
                3 => format!("--{}/chapter", fixture.url),
                _ => format!("分类::{}/explore", fixture.url),
            };
            run_debug(run, key).await;
            {
                let messages = logs.lock().unwrap();
                assert!(
                    messages.iter().any(|log| log["state"] == 1000),
                    "入口 {route} 未完成: {messages:?}"
                );
            }
            for _ in 0..count {
                fixture.request().await;
            }
            fixture.worker.join().unwrap();
            assert_eq!(engine.tasks().active_count(), 0);
        }
    }

    #[cfg(feature = "quickjs")]
    #[tokio::test]
    async fn main_js_content_and_explore_share_only_the_original_cookie_capability() {
        let url = "https://same-debug.test";
        for identity in ["甲实例", "乙实例"] {
            let engine = EngineContext::in_memory().unwrap();
            seed(&engine, url, "JS 调试源");
            engine
                .network()
                .set_cookie(url, &format!("identity={identity}"))
                .unwrap();
            engine.storage().with_database(|db| {
                let repo = BookSourceRepository::new(db.connection());
                let mut source = repo.find_by_url(url)?.unwrap();
                source.main_js = Some(r#"
                    function getContent(chapter,book,nextChapterUrl) { return java.getCookie('https://same-debug.test'); }
                    function explore(url,page) { return [{name:java.getCookie('https://same-debug.test'),bookUrl:'https://same-debug.test/book'}]; }
                "#.into());
                repo.update(&source)
            }).unwrap();
            let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
            let logs = Arc::new(Mutex::new(Vec::new()));
            let run = run_for_engine(&engine, &slot, url, logs.clone());
            run_debug(run, format!("--{url}/chapter")).await;
            assert!(logs.lock().unwrap().iter().any(|log| log["state"] == 1000));
            assert!(
                logs.lock()
                    .unwrap()
                    .iter()
                    .any(|log| log["msg"].as_str().unwrap().contains(identity))
            );
            let run = run_for_engine(&engine, &slot, url, Arc::new(Mutex::new(Vec::new())));
            let source = serde_json::to_string(&run.load_source(url).unwrap()).unwrap();
            let result = tokio::task::spawn_blocking(move || {
                run.explore_books(&source, "https://same-debug.test/explore")
            })
            .await
            .unwrap()
            .unwrap();
            let books: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
            assert!(books[0]["name"].as_str().unwrap().contains(identity));
            assert_eq!(engine.tasks().active_count(), 0);
        }
    }
}
