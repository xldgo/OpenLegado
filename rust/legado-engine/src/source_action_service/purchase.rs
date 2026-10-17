//! 章节购买编排；JS执行期间不持数据库连接。
#[cfg(feature = "quickjs")]
use super::js::json_to_js_value;
use super::*;
use legado_core::models::book::book_type;
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository};

/// 购买动作执行结果（camelCase 序列化）
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PayActionResult {
    /// 结果类型：`url`（打开支付页）/ `success`（购买成功）/ `none`（无明确结果）
    pub kind: String,
    /// JS 返回原文（供 UI 展示/调试）
    pub value: String,
}

fn classify_pay_result(raw: &str) -> String {
    let trimmed = raw.trim();
    let lower = trimmed.to_ascii_lowercase();
    if lower.starts_with("http://") || lower.starts_with("https://") {
        "url".into()
    } else if lower == "true" {
        "success".into()
    } else {
        "none".into()
    }
}

impl SourceActionService {
    pub fn chapter_pay_action(
        &self,
        book_url: &str,
        chapter_index: i32,
    ) -> LegadoResult<PayActionResult> {
        // 1. 取书 + 本地书短路（对齐 Kotlin `if (book.isLocalBook()) return`）
        let book = self
            .with_database(|db| BookRepository::new(db.connection()).find_by_url(book_url))?
            .ok_or_else(|| LegadoError::Database(format!("书籍不存在: {book_url}")))?;

        let is_local = book.origin.is_empty()
            || book.origin == book_type::LOCAL_TAG
            || crate::reading_service::is_local_book(book_url);
        if is_local {
            return Ok(PayActionResult {
                kind: "none".into(),
                value: String::new(),
            });
        }

        // 2. 取章节（baseUrl 绑定与缓存清理键）
        let chapter = self
            .with_database(|db| {
                BookChapterRepository::new(db.connection())
                    .find_by_book_url_and_index(book_url, chapter_index)
            })?
            .ok_or_else(|| {
                LegadoError::Database(format!("章节 {chapter_index} 不存在: {book_url}"))
            })?;

        // 3. 取书源 payAction
        let source = self
            .with_database(|db| {
                BookSourceRepository::new(db.connection()).find_by_url(&book.origin)
            })?
            .ok_or_else(|| LegadoError::Database(format!("书源不存在: {}", book.origin)))?;

        let pay_action = source
            .rule_content
            .as_ref()
            .and_then(|r| r.pay_action.as_deref())
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .ok_or_else(|| LegadoError::Ffi("no pay action".into()))?;

        // 4. 与登录V2共用独立VM构造，绑定内容仍由购买动作决定。
        let raw = self.eval_pay_action(&source, &book, &chapter, pay_action)?;

        // 5. 结果判定（对齐 Kotlin isAbsUrl / isTrue 分支）
        let kind = classify_pay_result(&raw);
        if kind == "success" {
            // 购买成功 → 清当前章正文缓存，强制下次重新抓取
            // 按 (book_url, chapter.url) 复合键精确清除（Task #19），避免误删其他书同 URL 缓存
            self.with_database(|db| {
                CacheBookRepository::new(db.connection())
                    .delete_by_book_and_chapter_url(book_url, &chapter.url)
            })?;
        }
        Ok(PayActionResult { kind, value: raw })
    }

    #[cfg(feature = "quickjs")]
    fn eval_pay_action(
        &self,
        source: &legado_core::models::BookSource,
        book: &legado_core::models::Book,
        chapter: &legado_core::models::BookChapter,
        pay_action: &str,
    ) -> LegadoResult<String> {
        // JsEngine trait 提供 eval_with_bindings（对照 source_login_v2_api）
        use legado_js::{JsEngine, JsValue};

        let engine = self.fresh_engine(&source.book_source_url)?;
        let guard = engine
            .lock()
            .map_err(|e| LegadoError::JsEngine(format!("JS 引擎加锁失败: {e}")))?;

        // 绑定对齐 Kotlin evalJS：book/chapter/title/baseUrl/result=null/src=null
        let book_value: serde_json::Value = serde_json::to_value(book)?;
        let chapter_value: serde_json::Value = serde_json::to_value(chapter)?;
        let bindings: Vec<(&str, JsValue)> = vec![
            ("baseUrl", JsValue::String(chapter.url.clone())),
            ("title", JsValue::String(chapter.title.clone())),
            ("book", json_to_js_value(book_value)),
            ("chapter", json_to_js_value(chapter_value)),
            ("result", JsValue::Null),
            ("src", JsValue::Null),
        ];
        // P2-19：绑定当前书源 tag（对齐 explore_api / js_executor 主路径）：
        // payAction 脚本调用 java.ajax 时 Cookie/全局头按本源 book_source_url
        // 过滤（而非未归属不带、更非全量合并泄漏）；退出时自动恢复原值。
        legado_js::host_api::current_source::with_current_source_tag(
            &source.book_source_url,
            || guard.eval_with_bindings(pay_action, &bindings),
        )
    }

    #[cfg(not(feature = "quickjs"))]
    fn eval_pay_action(
        &self,
        _source: &legado_core::models::BookSource,
        _book: &legado_core::models::Book,
        _chapter: &legado_core::models::BookChapter,
        _pay_action: &str,
    ) -> LegadoResult<String> {
        Err(LegadoError::JsEngine(
            "QuickJS engine not enabled. Build with --features quickjs".into(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_classify_pay_result() {
        assert_eq!(classify_pay_result("https://pay.example.com/order"), "url");
        assert_eq!(classify_pay_result("http://pay.example.com"), "url");
        assert_eq!(classify_pay_result(" TRUE "), "success");
        assert_eq!(classify_pay_result("true"), "success");
        assert_eq!(classify_pay_result(""), "none");
        assert_eq!(classify_pay_result("{\"msg\":\"已购买\"}"), "none");
    }
}
