//! 章节购买动作 FFI 层（Task #136 R6，API_CONTRACT §2.43.2）
//!
//! 对齐 Kotlin `ReadBookActivity.payAction`（app 模块 ui/book/read/ReadBookActivity.kt）语义：
//!
//! - 本地书（origin 为空/`loc_book` 或文件型 bookUrl）短路返回 `kind=none`（无购买概念）；
//! - 按书的 `origin` 取书源 `contentRule.payAction`，为空时报错 "no pay action"；
//! - `evalJS(payAction)` 注入绑定对齐 Kotlin：java（引擎全局命名空间）/
//!   book（Book JSON 对象）/ chapter（BookChapter JSON 对象）/ title（章节标题）/
//!   baseUrl = chapter.url / result = null / src = null；
//! - 结果判定：绝对 URL → `kind=url`（UI 打开支付页）；"true" → `kind=success`
//!   （清当前章正文缓存，对齐 Kotlin `BookHelp.delContent`；目录刷新由 UI 侧发起）；
//!   其他返回 → `kind=none`。
//!
//! 原版 payAction 亦支持「包含 `{{js}}` 的 url 模板」形态，语义依赖 Android WebView
//! 注入执行，此处不实现，仅按纯 JS 脚本执行并以注释标注（R6 留项）。
//!
//! 执行委托Engine；独立VM未启用时返回原 `JsEngine` 错误。

#[cfg(test)]
use crate::db_state::with_database;
use legado_core::LegadoResult;
#[cfg(test)]
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};
pub use legado_engine::source_action_service::PayActionResult;

pub fn chapter_pay_action(book_url: &str, chapter_index: i32) -> LegadoResult<PayActionResult> {
    crate::source_action_host::service().chapter_pay_action(book_url, chapter_index)
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_db::repository::Repository;

    /// 本地书短路：origin=loc_book → kind=none，不触碰 JS
    #[test]
    fn test_local_book_short_circuit() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "http://pay-action.example.com/local-book";
        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "本地购买测试",
            "author": "",
            "origin": "loc_book"
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();

        let result = chapter_pay_action(book_url, 0).unwrap();
        assert_eq!(result.kind, "none");
        assert!(result.value.is_empty());

        // 清理
        with_database(|db| BookRepository::new(db.connection()).delete_by_url(book_url)).unwrap();
    }

    /// 无 payAction 规则 → "no pay action" 错误（对齐 Kotlin）
    #[test]
    fn test_missing_pay_action_error() {
        let _db_guard = crate::db_state::ensure_test_db();
        let source_url = "https://pay-no-action.example.com";
        let book_url = "http://pay-action.example.com/book-no-action";

        let source_json = serde_json::json!({
            "bookSourceUrl": source_url,
            "bookSourceName": "无购买规则源"
        })
        .to_string();
        crate::api::source::add_source(&source_json).unwrap();

        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "购买测试",
            "author": "",
            "origin": source_url
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();

        let chapter = legado_core::models::BookChapter {
            url: format!("{book_url}/chapter/0"),
            title: "第一章".into(),
            book_url: book_url.into(),
            index: 0,
            ..Default::default()
        };
        with_database(|db| BookChapterRepository::new(db.connection()).insert_batch(&[chapter]))
            .unwrap();

        let err = chapter_pay_action(book_url, 0).unwrap_err();
        assert!(err.to_string().contains("no pay action"));

        // 清理
        with_database(|db| {
            let conn = db.connection();
            BookChapterRepository::new(conn).delete_by_book_url(book_url)?;
            BookRepository::new(conn).delete_by_url(book_url)?;
            BookSourceRepository::new(conn).delete(source_url)
        })
        .unwrap();
    }
}

/// quickjs 全链路测试：payAction 返回 URL / true
#[cfg(all(test, feature = "quickjs"))]
mod quickjs_tests {
    use super::*;
    use legado_db::repository::Repository;

    fn setup(source_url: &str, book_url: &str, pay_action: &str) {
        let source_json = serde_json::json!({
            "bookSourceUrl": source_url,
            "bookSourceName": "购买测试源",
            "ruleContent": { "payAction": pay_action }
        })
        .to_string();
        crate::api::source::add_source(&source_json).unwrap();

        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "付费书",
            "author": "测试",
            "origin": source_url
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();

        let chapter = legado_core::models::BookChapter {
            url: format!("{book_url}/chapter/1"),
            title: "付费章".into(),
            book_url: book_url.into(),
            index: 1,
            ..Default::default()
        };
        with_database(|db| BookChapterRepository::new(db.connection()).insert_batch(&[chapter]))
            .unwrap();
    }

    fn teardown(source_url: &str, book_url: &str) {
        with_database(|db| {
            let conn = db.connection();
            BookChapterRepository::new(conn).delete_by_book_url(book_url)?;
            BookRepository::new(conn).delete_by_url(book_url)?;
            BookSourceRepository::new(conn).delete(source_url)
        })
        .unwrap();
    }

    /// payAction 返回绝对 URL → kind=url（UI 打开支付页）
    #[test]
    fn test_pay_action_returns_url() {
        let _db_guard = crate::db_state::ensure_test_db();
        let source_url = "https://pay-url.example.com";
        let book_url = "http://pay-action.example.com/book-url";
        setup(
            source_url,
            book_url,
            "'https://pay.example.com/order?chapter=' + chapter.index",
        );

        let result = chapter_pay_action(book_url, 1).unwrap();
        assert_eq!(result.kind, "url");
        assert_eq!(result.value, "https://pay.example.com/order?chapter=1");

        teardown(source_url, book_url);
    }

    /// payAction 返回 true → kind=success，且当前章缓存被清除
    #[test]
    fn test_pay_action_success_clears_cache() {
        let _db_guard = crate::db_state::ensure_test_db();
        let source_url = "https://pay-success.example.com";
        let book_url = "http://pay-action.example.com/book-success";
        setup(source_url, book_url, "true");

        // 预置该章缓存，验证购买成功后被清除（对齐 Kotlin BookHelp.delContent）
        let chapter_url = format!("{book_url}/chapter/1");
        crate::api::cache_api::save_chapter_content(
            book_url,
            1,
            "付费章",
            "付费正文",
            &chapter_url,
        )
        .unwrap();
        assert!(
            !crate::api::cache_api::get_chapter_cache(book_url, 1)
                .unwrap()
                .is_empty()
        );

        let result = chapter_pay_action(book_url, 1).unwrap();
        assert_eq!(result.kind, "success");
        assert!(
            crate::api::cache_api::get_chapter_cache(book_url, 1)
                .unwrap()
                .is_empty()
        );

        teardown(source_url, book_url);
    }
}
