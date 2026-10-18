//! 书源事件回调编排；动作仅在原任务发布门控内返回。
#[cfg(feature = "quickjs")]
use super::js::json_to_js_value;
use super::*;
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};
use serde::Serialize;

/// callBackBtn 执行结果（camelCase）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SourceCallBackBtnResult {
    /// 是否实际执行了 callBackJs（false 时 UI 应走 noCall 默认行为）
    pub invoked: bool,
    /// JS 返回值经 Kotlin `String?.isTrue()` 判定后是否为真
    /// （为假时 UI 同样应执行 noCall）
    pub js_true: bool,
    /// JS 返回原文
    pub raw: String,
    /// 中途 UI 副作用队列（openBrowser / refreshBookInfo / copyText …）
    pub actions: Vec<serde_json::Value>,
}

fn is_js_true(raw: &str) -> bool {
    let t = raw.trim();
    if t.is_empty() || t.eq_ignore_ascii_case("null") {
        return false;
    }
    !regex_is_falsey(t)
}

fn regex_is_falsey(s: &str) -> bool {
    let lower = s.to_ascii_lowercase();
    matches!(lower.as_str(), "false" | "no" | "not" | "0" | "0.0")
}

impl SourceActionService {
    pub fn source_call_back_btn(
        &self,
        tasks: &crate::TaskGroup,
        event: &str,
        book_url: &str,
        chapter_index: Option<i32>,
        result: Option<&str>,
    ) -> LegadoResult<SourceCallBackBtnResult> {
        let task = tasks.begin().map_err(|e| LegadoError::Ffi(e.to_string()))?;
        let _guard = task.guard();
        let _execution = legado_js::cancellation::Scope::enter(Some(Arc::new(task.clone())));
        let book = self
            .with_database(|db| BookRepository::new(db.connection()).find_by_url(book_url))?
            .ok_or_else(|| LegadoError::Database(format!("书籍不存在: {book_url}")))?;

        let source = self.with_database(|db| {
            BookSourceRepository::new(db.connection()).find_by_url(&book.origin)
        })?;

        let Some(source) = source else {
            return Ok(SourceCallBackBtnResult {
                invoked: false,
                js_true: false,
                raw: String::new(),
                actions: vec![],
            });
        };

        if !source.event_listener {
            return Ok(SourceCallBackBtnResult {
                invoked: false,
                js_true: false,
                raw: String::new(),
                actions: vec![],
            });
        }

        let js_str = source
            .rule_content
            .as_ref()
            .and_then(|r| r.call_back_js.as_deref())
            .map(str::trim)
            .filter(|s| !s.is_empty());

        let Some(js_str) = js_str else {
            return Ok(SourceCallBackBtnResult {
                invoked: false,
                js_true: false,
                raw: String::new(),
                actions: vec![],
            });
        };

        let chapter = match chapter_index {
            Some(idx) => self.with_database(|db| {
                BookChapterRepository::new(db.connection())
                    .find_by_book_url_and_index(book_url, idx)
            })?,
            None => None,
        };

        let evaluated =
            self.eval_call_back_js(&source, &book, chapter.as_ref(), event, result, js_str);
        if task.is_cancelled() {
            return Err(LegadoError::Ffi("书源回调已取消".into()));
        }
        let (raw, actions) = evaluated?;

        task.with_active(|| {
            Ok(SourceCallBackBtnResult {
                invoked: true,
                js_true: is_js_true(&raw),
                raw,
                actions,
            })
        })
        .unwrap_or_else(|| Err(LegadoError::Ffi("书源回调已取消".into())))
    }

    #[cfg(feature = "quickjs")]
    fn eval_call_back_js(
        &self,
        source: &legado_core::models::BookSource,
        book: &legado_core::models::Book,
        chapter: Option<&legado_core::models::BookChapter>,
        event: &str,
        result: Option<&str>,
        js_str: &str,
    ) -> LegadoResult<(String, Vec<serde_json::Value>)> {
        use legado_js::{JsEngine, JsValue};

        let collected =
            legado_js::host_api::ui_action_queue::collect_actions(|| -> LegadoResult<String> {
                let engine = self.fresh_engine(&source.book_source_url)?;
                let guard = engine
                    .lock()
                    .map_err(|e| LegadoError::JsEngine(format!("JS 引擎加锁失败: {e}")))?;

                let book_value: serde_json::Value = serde_json::to_value(book)?;
                let chapter_value = match chapter {
                    Some(ch) => serde_json::to_value(ch)?,
                    None => serde_json::Value::Null,
                };
                let result_value = match result {
                    Some(r) => JsValue::String(r.to_string()),
                    None => JsValue::Null,
                };

                let bindings: Vec<(&str, JsValue)> = vec![
                    ("event", JsValue::String(event.to_string())),
                    ("book", json_to_js_value(book_value)),
                    ("chapter", json_to_js_value(chapter_value)),
                    ("result", result_value),
                ];

                // P2-19：绑定当前书源 tag（对齐 explore_api / js_executor 主路径）：
                // callBackJs 调用 java.ajax 时 Cookie/全局头按本源 book_source_url 过滤
                // （而非未归属不带、更非全量合并泄漏）。
                legado_js::host_api::current_source::with_current_source_tag(
                    &source.book_source_url,
                    || guard.eval_with_bindings(js_str, &bindings),
                )
            });
        collected.result.map(|raw| (raw, collected.actions))
    }

    #[cfg(not(feature = "quickjs"))]
    fn eval_call_back_js(
        &self,
        _source: &legado_core::models::BookSource,
        _book: &legado_core::models::Book,
        _chapter: Option<&legado_core::models::BookChapter>,
        _event: &str,
        _result: Option<&str>,
        _js_str: &str,
    ) -> LegadoResult<(String, Vec<serde_json::Value>)> {
        Err(LegadoError::JsEngine(
            "QuickJS engine not enabled. Build with --features quickjs".into(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn is_js_true_aligns_kotlin() {
        assert!(!is_js_true(""));
        assert!(!is_js_true("null"));
        assert!(!is_js_true("false"));
        assert!(!is_js_true("0"));
        assert!(is_js_true("true"));
        assert!(is_js_true("yes"));
        assert!(is_js_true("1"));
    }
    #[cfg(feature = "quickjs")]
    #[test]
    fn blocked_callback_and_other_source_keep_their_own_real_js_actions() {
        use crate::test_http_fixture::Fixture;
        let engine = crate::EngineContext::in_memory().unwrap();
        let service = super::super::tests::service(&engine);
        let second_service = super::super::tests::service(&engine);
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let mut fixture = Fixture::new(1, true, |_| "继续".into());
        let first = legado_core::models::BookSource {
            book_source_url: format!("{}/first", fixture.url),
            ..Default::default()
        };
        let second = legado_core::models::BookSource {
            book_source_url: format!("{}/second", fixture.url),
            ..Default::default()
        };
        let script = format!(
            "java.copyText('甲');java.ajax('{}/blocked');true",
            fixture.url
        );
        let blocked = std::thread::spawn(move || {
            service.eval_call_back_js(
                &first,
                &Default::default(),
                None,
                "clickCustomButton",
                None,
                &script,
            )
        });
        assert!(
            runtime
                .block_on(fixture.request())
                .starts_with("GET /blocked ")
        );
        let (raw, actions) = second_service
            .eval_call_back_js(
                &second,
                &Default::default(),
                None,
                "clickCustomButton",
                None,
                "java.copyText('乙');true",
            )
            .unwrap();
        assert!(is_js_true(&raw));
        assert_eq!(
            actions,
            vec![serde_json::json!({"action":"copyText","text":"乙"})]
        );
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
        let (raw, actions) = blocked.join().unwrap().unwrap();
        assert!(is_js_true(&raw));
        assert_eq!(
            actions,
            vec![serde_json::json!({"action":"copyText","text":"甲"})]
        );
        assert!(!legado_js::host_api::ui_action_queue::is_collecting());
    }
}
