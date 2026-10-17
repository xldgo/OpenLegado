//! 导出宿主适配：选项文档与能力装配，导出/预览归Engine服务。
use legado_core::LegadoResult;
use legado_engine::book_export_service::{BookExportResources, BookExportService};
pub use legado_engine::book_export_service::{ExportOptions, ExportResult};
use std::sync::Arc;
fn host_service() -> BookExportService {
    let engine = crate::engine_holder::current().ok();
    let storage = engine.as_ref().map(|e| e.storage().clone());
    let network = engine
        .as_ref()
        .map(|e| e.network().clone())
        .unwrap_or_else(crate::engine_holder::network);
    let runtime = crate::runtime::get_runtime().handle().clone();
    BookExportService::new(BookExportResources {
        storage,
        image_fetcher: Arc::new(move |src| {
            runtime.block_on(async {
                network
                    .client()
                    .map_err(|e| e.to_string())?
                    .get_bytes(src, None)
                    .await
                    .map_err(|e| e.to_string())
            })
        }),
    })
}
pub fn export_book(book_url: &str, format: &str, include_toc: bool) -> LegadoResult<ExportResult> {
    host_service().export_book(book_url, format, include_toc, &ExportOptions::default())
}
pub fn export_book_with_options(
    book_url: &str,
    format: &str,
    include_toc: bool,
    options_json: &str,
) -> LegadoResult<ExportResult> {
    let options = if options_json.trim().is_empty() {
        ExportOptions::default()
    } else {
        match serde_json::from_str::<ExportOptions>(options_json) {
            Ok(o) => o,
            Err(e) => {
                return Ok(ExportResult {
                    success: false,
                    data: None,
                    chapter_count: None,
                    file_name: None,
                    mime_type: None,
                    error: Some(format!("导出选项 JSON 解析失败: {e}")),
                });
            }
        }
    };
    host_service().export_book(book_url, format, include_toc, &options)
}
pub fn export_info(book_url: &str, format: &str) -> LegadoResult<ExportResult> {
    host_service().export_info(book_url, format)
}
#[cfg(test)]
use crate::db_state::with_database;
#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::models::{Book, ReplaceRule};
    use legado_db::repository::Repository;
    use legado_db::{BookRepository, ReplaceRuleRepository};
    use std::io::Write;

    /// 创建临时 TXT 书籍文件（含两个章节）并返回路径
    fn create_temp_txt(suffix_tag: &str) -> String {
        let dir = std::env::temp_dir();
        let path = dir.join(format!(
            "legado_export_test_{suffix_tag}_{}.txt",
            std::process::id()
        ));
        let content = "第一章 测试章节一\n这是第一章的正文广告文字。\n第二章 测试章节二\n这是第二章的正文。\n";
        let mut file = std::fs::File::create(&path).unwrap();
        file.write_all(content.as_bytes()).unwrap();
        path.to_string_lossy().to_string()
    }

    /// 在 DB 中注册书籍并解析章节入库（返回串行锁守卫，测试必须绑定到变量）
    fn register_book_and_chapters(
        book_url: &str,
        book_name: &str,
    ) -> std::sync::MutexGuard<'static, ()> {
        let db_guard = crate::db_state::ensure_test_db();
        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            if book_repo.find_by_url(book_url)?.is_none() {
                book_repo.insert(&Book {
                    book_url: book_url.to_string(),
                    name: book_name.to_string(),
                    ..Book::default()
                })?;
            }
            Ok(())
        })
        .unwrap();
        // 解析章节并入库（与 get_chapters 懒加载逻辑一致）
        let chapters = crate::api::reader::get_chapters(book_url).unwrap();
        assert!(chapters.total >= 2, "临时 TXT 应至少解析出 2 章");
        db_guard
    }

    /// 将导出原始字节作为 UTF-8 文本读取
    fn decode_export(result: &ExportResult) -> String {
        assert!(result.success, "导出应成功: {:?}", result.error);
        let bytes = result.data.as_ref().unwrap();
        String::from_utf8(bytes.clone()).unwrap()
    }

    /// 测试本地书导出正文非空（修复仅读缓存导致全空的回归）
    #[test]
    fn test_export_local_book_non_empty_content() {
        let path = create_temp_txt("nonempty");
        let _db_guard = register_book_and_chapters(&path, "导出测试书A");

        let result = export_book(&path, "txt", false).unwrap();
        let text = decode_export(&result);
        assert!(text.contains("第一章"), "导出应包含章节标题");
        assert!(text.contains("这是第一章的正文"), "本地书导出正文不应为空");
        assert!(text.contains("这是第二章的正文"));

        let _ = std::fs::remove_file(&path);
    }

    /// 测试导出应用替换规则净化（与阅读器/Android 对齐）
    #[test]
    fn test_export_local_book_applies_replace_rules() {
        let path = create_temp_txt("purify");
        let _db_guard = register_book_and_chapters(&path, "导出测试书B");

        // 插入唯一命名的全局启用规则
        let rule_id = with_database(|db| {
            let repo = ReplaceRuleRepository::new(db.connection());
            repo.insert(&ReplaceRule {
                name: "export_测试规则_unique".to_string(),
                pattern: "广告文字".to_string(),
                replacement: String::new(),
                is_regex: false,
                is_enabled: true,
                ..ReplaceRule::default()
            })
        })
        .unwrap();

        let result = export_book(&path, "txt", false).unwrap();
        let text = decode_export(&result);
        assert!(!text.contains("广告文字"), "导出应已净化（替换规则生效）");
        assert!(text.contains("这是第一章的正文。"), "净化后正文应保留");

        // 清理本测试插入的规则
        with_database(|db| {
            let repo = ReplaceRuleRepository::new(db.connection());
            repo.delete(rule_id)?;
            Ok(())
        })
        .unwrap();
        let _ = std::fs::remove_file(&path);
    }

    /// 集成测试：PDF 格式全链路导出
    ///
    /// 环境有中文字体时应成功且输出有效 PDF（%PDF 文件头）；
    /// 无字体时应优雅降级为带明确错误信息的结果（不 panic）。
    #[test]
    fn test_export_local_book_pdf() {
        let path = create_temp_txt("pdf");
        let _db_guard = register_book_and_chapters(&path, "导出测试书PDF");

        let result = export_book(&path, "pdf", false).unwrap();
        if result.success {
            let bytes = result.data.as_ref().unwrap();
            assert!(bytes.len() > 4, "PDF 输出不应为空");
            assert_eq!(&bytes[0..4], b"%PDF", "导出文件应为有效 PDF");
            assert_eq!(
                result.mime_type.as_deref(),
                Some("application/pdf"),
                "MIME 类型应为 application/pdf"
            );
            assert!(
                result.file_name.as_ref().unwrap().ends_with(".pdf"),
                "文件名应以 .pdf 结尾"
            );
        } else {
            // 无 CJK 字体环境：错误信息应明确提示字体问题
            let err = result.error.unwrap_or_default();
            assert!(err.contains("字体"), "导出失败应提示字体问题: {err}");
        }

        let _ = std::fs::remove_file(&path);
    }

    /// Task #136 R8：GBK 编码导出（对照 Kotlin AppConfig.exportCharset）
    #[test]
    fn test_export_with_gbk_encoding() {
        let path = create_temp_txt("gbk");
        let _db_guard = register_book_and_chapters(&path, "导出测试书GBK");

        let result =
            export_book_with_options(&path, "txt", false, r#"{"encoding":"GBK"}"#).unwrap();
        assert!(result.success, "GBK 导出应成功: {:?}", result.error);

        let bytes = result.data.as_ref().unwrap();
        // GBK 输出非合法 UTF-8（中文首字节 ≥ 0x81）
        assert!(std::str::from_utf8(bytes).is_err(), "GBK 输出不应为 UTF-8");
        // 首字符「导」的 GBK 编码为 0xB5 0xBC
        assert_eq!(&bytes[0..2], &[0xB5, 0xBC], "首字符应按 GBK 编码");

        let _ = std::fs::remove_file(&path);
    }

    /// Task #136 R8：章节范围筛选（startChapter/endChapter 闭区间）
    #[test]
    fn test_export_with_chapter_range() {
        let path = create_temp_txt("range");
        let _db_guard = register_book_and_chapters(&path, "导出测试书范围");

        // 仅导出第 2 章（index=1）
        let result =
            export_book_with_options(&path, "txt", false, r#"{"startChapter":1,"endChapter":1}"#)
                .unwrap();
        let text = decode_export(&result);
        assert!(text.contains("第二章"), "应包含范围内章节");
        assert!(!text.contains("这是第一章的正文"), "不应包含范围外章节");

        // -1 = 不限（全量）
        let result = export_book_with_options(
            &path,
            "txt",
            false,
            r#"{"startChapter":-1,"endChapter":-1}"#,
        )
        .unwrap();
        let text = decode_export(&result);
        assert!(text.contains("这是第一章的正文") && text.contains("这是第二章的正文"));

        let _ = std::fs::remove_file(&path);
    }

    /// Task #136 R8：文件名模板（{name}/{author} 占位符）与缺省兼容
    #[test]
    fn test_export_with_file_name_template() {
        let path = create_temp_txt("filename");
        let _db_guard = register_book_and_chapters(&path, "导出测试书模板");

        let result = export_book_with_options(
            &path,
            "txt",
            false,
            r#"{"fileNameTemplate":"{name} 作者：{author}"}"#,
        )
        .unwrap();
        assert!(result.success);
        // 测试书 author 为空 → 模板展开为 「导出测试书模板 作者：.txt」
        assert_eq!(
            result.file_name.as_deref(),
            Some("导出测试书模板 作者：.txt")
        );

        // 缺省（空 optionsJson）行为不变：`{书名}.txt`
        let result = export_book_with_options(&path, "txt", false, "").unwrap();
        assert_eq!(result.file_name.as_deref(), Some("导出测试书模板.txt"));

        // 非法 JSON：返回错误结果不 panic
        let result = export_book_with_options(&path, "txt", false, "{bad").unwrap();
        assert!(!result.success);
        assert!(result.error.unwrap().contains("导出选项 JSON 解析失败"));

        let _ = std::fs::remove_file(&path);
    }
}
