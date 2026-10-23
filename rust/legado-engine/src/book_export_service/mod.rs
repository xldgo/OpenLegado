//! 书籍导出服务：内容与存储属于原实例，网络图片由调用方显式提供。
use crate::StorageContext;
use crate::reading_service::{ContentProcessing, chapter_to_local_info, is_local_book};
use legado_book::export::{
    BookExporter, ExportChapter, ExportConfig, ExportData, ExportFormat, ImageFetcher,
    extract_image_sources,
};
use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookChapterRepository, BookRepository, CacheBookRepository};
use legado_parser::AnalyzeUrl;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// 导出结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportResult {
    /// 是否成功
    pub success: bool,
    /// 导出文件原始字节
    pub data: Option<Vec<u8>>,
    /// 仅预览结果包含章节数
    pub chapter_count: Option<usize>,
    /// 文件名
    pub file_name: Option<String>,
    /// MIME 类型
    pub mime_type: Option<String>,
    /// 错误信息（失败时）
    pub error: Option<String>,
}

/// 导出选项 DTO（Task #136 R8，API_CONTRACT §2.43.4，所有字段可选）
///
/// 对照 Kotlin `ExportBookService`（编码）/ `getExportFileName`（文件名模板）。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportOptions {
    /// 输出编码（仅 TXT 生效）：UTF-8（缺省）/ GB2312 / GBK / GB18030 / UTF-16 / UTF-16LE / ASCII
    pub encoding: Option<String>,
    /// 起始章节 index（闭区间；缺省/-1 = 不限）
    pub start_chapter: Option<i32>,
    /// 结束章节 index（闭区间；缺省/-1 = 不限）
    pub end_chapter: Option<i32>,
    /// 文件名模板：`{name}` / `{author}` 占位符（对照 Kotlin getExportFileName
    /// 缺省 `"$name 作者：$author"`；此处缺省保持现行为 `{书名}.{扩展名}`）
    pub file_name_template: Option<String>,
}

pub struct BookExportResources {
    pub storage: Option<StorageContext>,
    pub image_fetcher: Arc<ImageFetcher>,
}
pub struct BookExportService {
    storage: Option<StorageContext>,
    content: ContentProcessing,
    image_fetcher: Arc<ImageFetcher>,
}
impl BookExportService {
    pub fn new(resources: BookExportResources) -> Self {
        Self {
            content: ContentProcessing::new(resources.storage.clone()),
            storage: resources.storage,
            image_fetcher: resources.image_fetcher,
        }
    }
    fn with_database<T>(
        &self,
        f: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(f)
    }
    pub fn export_book(
        &self,
        book_url: &str,
        format: &str,
        include_toc: bool,
        options: &ExportOptions,
    ) -> LegadoResult<ExportResult> {
        // 解析导出格式
        let export_format = match ExportFormat::from_str(format) {
            Some(f) => f,
            None => {
                return Ok(ExportResult {
                    success: false,
                    data: None,
                    chapter_count: None,
                    file_name: None,
                    mime_type: None,
                    error: Some(format!(
                        "不支持的导出格式: {format}，支持 txt/epub/html/pdf"
                    )),
                });
            }
        };

        // 从数据库获取书籍与章节元数据
        let book_data = self.with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = book_repo.find_by_url(book_url)?;
            let book = match book {
                Some(b) => b,
                None => return Ok(None),
            };
            let chapter_repo = BookChapterRepository::new(db.connection());
            let chapters = chapter_repo.find_by_book_url(book_url)?;
            Ok(Some((book, chapters)))
        })?;

        let (book, chapters) = match book_data {
            Some(v) => v,
            None => {
                return Ok(ExportResult {
                    success: false,
                    data: None,
                    chapter_count: None,
                    file_name: None,
                    mime_type: None,
                    error: Some(format!("书籍不存在: {book_url}")),
                });
            }
        };

        // 在线书：预加载缓存正文（本地书不走缓存，逐章走解析器）
        let cached = if is_local_book(book_url) {
            Vec::new()
        } else {
            self.with_database(|db| {
                let cache_repo = CacheBookRepository::new(db.connection());
                Ok(cache_repo.get_by_book(book_url).unwrap_or_default())
            })?
        };

        // 章节范围筛选（R8：startChapter/endChapter 闭区间，缺省/-1 = 不限）
        let range_ok = |index: i32| {
            let start_ok = match options.start_chapter {
                Some(s) if s >= 0 => index >= s,
                _ => true,
            };
            let end_ok = match options.end_chapter {
                Some(e) if e >= 0 => index <= e,
                _ => true,
            };
            start_ok && end_ok
        };

        // 逐章取正文（与阅读器 get_chapter_content 同源）并应用净化，与 Android 导出经 ContentProcessor 一致
        let local = is_local_book(book_url);
        let export_chapters: Vec<ExportChapter> = chapters
            .iter()
            .filter(|ch| range_ok(ch.index))
            .map(|ch| {
                let raw_content = if local {
                    // 本地书：走解析器读取文件正文（修复仅读缓存导致本地书导出全空的回归）
                    legado_book::LocalBook::get_chapter_content(
                        book_url,
                        &chapter_to_local_info(ch),
                    )
                    .unwrap_or_default()
                } else {
                    // 在线书：从缓存取原始正文
                    cached
                        .iter()
                        .find(|c| c.chapter_index == ch.index)
                        .map(|c| c.content.clone())
                        .unwrap_or_default()
                };
                // 导出内容与阅读器显示对齐：应用替换规则 + 内容净化
                // （含章级「删除重复标题」开关，Task #51）
                let content = self.content.apply_content_processing_export(
                    book_url,
                    &raw_content,
                    &ch.title,
                    ch.index,
                );
                // 图片书 PDF 导出（对齐上游 #483）：从正文提取 img 标签，
                // 并相对章节 URL 绝对化（对齐 Kotlin NetworkUtils.getAbsoluteURL）
                let images = if matches!(export_format, ExportFormat::Pdf) {
                    extract_image_sources(&content)
                        .into_iter()
                        .map(|src| AnalyzeUrl::get_absolute_url(&ch.url, &src))
                        .collect()
                } else {
                    Vec::new()
                };
                ExportChapter {
                    index: ch.index,
                    title: ch.title.clone(),
                    content,
                    images,
                }
            })
            .collect();

        let export_data = ExportData {
            title: book.name.clone(),
            author: book.author.clone(),
            intro: book.intro.clone(),
            chapters: export_chapters,
        };

        let config = ExportConfig {
            format: export_format,
            include_toc,
            chapter_separator: String::new(),
            // R8：编码透传（仅 TXT 生效，缺省 UTF-8 行为不变）
            encoding: options
                .encoding
                .clone()
                .filter(|s| !s.trim().is_empty())
                .unwrap_or_else(|| "UTF-8".to_string()),
        };

        // 图片书 PDF 导出：注入网络图片获取器（复用共享 HTTP 客户端，与阅读器下载链路同源）
        let fetcher = if matches!(export_format, ExportFormat::Pdf) {
            Some(self.image_fetcher.as_ref())
        } else {
            None
        };

        // 执行导出
        Ok(
            match BookExporter::export_with(&export_data, &config, fetcher) {
                Ok(bytes) => {
                    // R8：文件名模板（{name}/{author} 占位符），缺省 = 现行为 `{书名}.{扩展名}`
                    let file_name = match options
                        .file_name_template
                        .as_deref()
                        .filter(|s| !s.trim().is_empty())
                    {
                        Some(template) => {
                            let base = template
                                .replace("{name}", &book.name)
                                .replace("{author}", &book.author);
                            format!("{}.{}", base, export_format.extension())
                        }
                        None => format!("{}.{}", book.name, export_format.extension()),
                    };
                    ExportResult {
                        success: true,
                        data: Some(bytes),
                        chapter_count: None,
                        file_name: Some(file_name),
                        mime_type: Some(export_format.mime_type().to_string()),
                        error: None,
                    }
                }
                Err(e) => ExportResult {
                    success: false,
                    data: None,
                    chapter_count: None,
                    file_name: None,
                    mime_type: None,
                    error: Some(format!("导出失败: {e}")),
                },
            },
        )
    }
    pub fn export_info(&self, book_url: &str, format: &str) -> LegadoResult<ExportResult> {
        let export_format = match ExportFormat::from_str(format) {
            Some(f) => f,
            None => {
                return Ok(ExportResult {
                    success: false,
                    data: None,
                    chapter_count: None,
                    file_name: None,
                    mime_type: None,
                    error: Some(format!("不支持的导出格式: {format}")),
                });
            }
        };

        self.with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = book_repo.find_by_url(book_url)?;

            match book {
                Some(b) => {
                    let chapter_repo = BookChapterRepository::new(db.connection());
                    let chapters = chapter_repo.find_by_book_url(book_url)?;
                    let file_name = format!("{}.{}", b.name, export_format.extension());
                    Ok(ExportResult {
                        success: true,
                        data: None,
                        chapter_count: Some(chapters.len()),
                        file_name: Some(file_name),
                        mime_type: Some(export_format.mime_type().to_string()),
                        error: None,
                    })
                }
                None => Ok(ExportResult {
                    success: false,
                    data: None,
                    chapter_count: None,
                    file_name: None,
                    mime_type: None,
                    error: Some(format!("书籍不存在: {book_url}")),
                }),
            }
        })
    }
}

#[cfg(test)]
mod tests;
