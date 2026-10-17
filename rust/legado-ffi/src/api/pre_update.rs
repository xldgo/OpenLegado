//! 目录刷新前JS钩子的宿主适配。
use legado_core::{
    LegadoResult,
    models::{Book, BookSource},
};
#[cfg(all(test, feature = "quickjs"))]
use legado_engine::reading_service::apply_web_info_to_book;
pub fn run_pre_update_js(source: &BookSource, book: &mut Book) -> LegadoResult<()> {
    super::reader::host_service().run_pre_update_js(source, book)
}
#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::models::rule::TocRule;

    #[test]
    fn test_run_pre_update_js_empty_is_ok() {
        let source = BookSource::default();
        let mut book = Book::default();
        assert!(run_pre_update_js(&source, &mut book).is_ok());
    }

    #[test]
    fn test_run_pre_update_js_mutates_book_fields() {
        let mut source = BookSource {
            book_source_url: "https://example.com".into(),
            book_source_name: "测试".into(),
            ..BookSource::default()
        };
        source.rule_toc = Some(TocRule {
            pre_update_js: Some(r#"book.tocUrl = "https://example.com/toc";"#.into()),
            ..TocRule::default()
        });
        let mut book = Book {
            name: "书".into(),
            book_url: "https://example.com/book".into(),
            ..Book::default()
        };
        let _ = run_pre_update_js(&source, &mut book);
        #[cfg(feature = "quickjs")]
        {
            assert_eq!(book.toc_url, "https://example.com/toc");
        }
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_apply_web_info_to_book() {
        let mut book = Book::default();
        let info = legado_core::web_book::WebBookInfo::new("名", "作", "https://b", "https://t");
        apply_web_info_to_book(&mut book, &info);
        assert_eq!(book.toc_url, "https://t");
        assert_eq!(book.name, "名");
    }
}
