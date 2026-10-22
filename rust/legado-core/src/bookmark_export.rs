//! 书签导出格式；不访问数据库或文件系统。— Codex + Rust

use crate::{LegadoError, LegadoResult, models::Bookmark};
use serde::Serialize;
use std::fmt::Write;

#[derive(Debug, Clone, Copy)]
pub enum BookmarkExportFormat {
    Json,
    Markdown,
}

pub struct BookmarkExportDocument {
    pub file_name: String,
    pub mime_type: String,
    pub content: String,
}

/// 原版书签交换格式不包含本项目的本地id，不能直接序列化数据库实体。
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ExportBookmark<'a> {
    time: i64,
    book_name: &'a str,
    book_author: &'a str,
    chapter_index: i32,
    chapter_pos: i32,
    chapter_name: &'a str,
    book_text: &'a str,
    content: &'a str,
}

pub fn export_bookmarks(
    book_name: &str,
    book_author: &str,
    bookmarks: &[Bookmark],
    format: BookmarkExportFormat,
) -> LegadoResult<BookmarkExportDocument> {
    let (extension, mime_type, content) = match format {
        BookmarkExportFormat::Json => {
            let entries: Vec<_> = bookmarks
                .iter()
                .map(|b| ExportBookmark {
                    time: b.time,
                    book_name: &b.book_name,
                    book_author: &b.book_author,
                    chapter_index: b.chapter_index,
                    chapter_pos: b.chapter_pos,
                    chapter_name: &b.chapter_name,
                    book_text: &b.book_text,
                    content: &b.content,
                })
                .collect();
            let content = serde_json::to_string(&entries)
                .map_err(|e| LegadoError::Parser(format!("书签导出序列化失败: {e}")))?;
            ("json", "application/json", content)
        }
        BookmarkExportFormat::Markdown => {
            let mut content = format!("## {book_name} {book_author}\n\n");
            for b in bookmarks {
                // String的fmt写入不会失败；模板保留原版的空行与原文前置空格。
                let _ = write!(
                    content,
                    "#### {}\n\n###### 原文\n {}\n\n###### 摘要\n {}\n\n",
                    b.chapter_name, b.book_text, b.content,
                );
            }
            ("md", "text/markdown", content)
        }
    };
    let base: String = format!("bookmark-{book_name} {book_author}")
        .chars()
        .map(|c| {
            if c <= '\u{1f}' || "\\/:*?\"<>|".contains(c) {
                '_'
            } else {
                c
            }
        })
        .collect();
    // 与原Dart trim口径一致，额外包含Unicode BOM。
    let base = base.trim_matches(|c: char| c.is_whitespace() || c == '\u{feff}');
    Ok(BookmarkExportDocument {
        file_name: format!("{base}.{extension}"),
        mime_type: mime_type.into(),
        content,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn export_preserves_exchange_fields_order_and_markdown_template() {
        let bookmarks = vec![
            Bookmark {
                id: 42,
                time: 1700000000000,
                book_name: "书/名".into(),
                book_author: "作:者".into(),
                chapter_index: 2,
                chapter_pos: 17,
                chapter_name: "第三章".into(),
                book_text: "他说：\"你好😀\"\n下一行".into(),
                content: "**备注**".into(),
            },
            Bookmark {
                id: 43,
                time: 1700000000001,
                book_name: "书/名".into(),
                book_author: "作:者".into(),
                chapter_index: 4,
                chapter_name: "第五章".into(),
                book_text: "结尾".into(),
                ..Default::default()
            },
        ];
        let json_doc =
            export_bookmarks("书/名", "作:者", &bookmarks, BookmarkExportFormat::Json).unwrap();
        assert_eq!(json_doc.file_name, "bookmark-书_名 作_者.json");
        assert_eq!(json_doc.mime_type, "application/json");
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(&json_doc.content).unwrap(),
            json!([
                {"time":1700000000000i64,"bookName":"书/名","bookAuthor":"作:者","chapterIndex":2,"chapterPos":17,
                 "chapterName":"第三章","bookText":"他说：\"你好😀\"\n下一行","content":"**备注**"},
                {"time":1700000000001i64,"bookName":"书/名","bookAuthor":"作:者","chapterIndex":4,"chapterPos":0,
                 "chapterName":"第五章","bookText":"结尾","content":""}
            ])
        );
        let markdown =
            export_bookmarks("书/名", "作:者", &bookmarks, BookmarkExportFormat::Markdown).unwrap();
        assert_eq!(markdown.file_name, "bookmark-书_名 作_者.md");
        assert_eq!(markdown.mime_type, "text/markdown");
        assert_eq!(
            markdown.content,
            concat!(
                "## 书/名 作:者\n\n",
                "#### 第三章\n\n###### 原文\n 他说：\"你好😀\"\n下一行\n\n###### 摘要\n **备注**\n\n",
                "#### 第五章\n\n###### 原文\n 结尾\n\n###### 摘要\n \n\n",
            )
        );
    }

    #[test]
    fn empty_exports_and_filename_sanitizing_do_not_modify_content() {
        let name = "书\\/:*?\"<>|\n名";
        let json =
            export_bookmarks(name, "作者 \u{feff}", &[], BookmarkExportFormat::Json).unwrap();
        assert_eq!(json.file_name, "bookmark-书__________名 作者.json");
        assert_eq!(json.content, "[]");
        let markdown =
            export_bookmarks(name, "作者 \u{feff}", &[], BookmarkExportFormat::Markdown).unwrap();
        assert_eq!(markdown.content, format!("## {name} 作者 \u{feff}\n\n"));
    }
}
