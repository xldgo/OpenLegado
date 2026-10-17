//! 本地书籍导入服务：文件解析和入库使用显式实例资源。
use crate::StorageContext;
use crate::reading_service::LocalPathResolver;
use legado_book::{BookFormat, BookMetadata, LocalBook};
use legado_core::{LegadoError, LegadoResult, models::Book};
use legado_db::{BookRepository, repository::Repository};
use serde::{Deserialize, Serialize};

/// 书籍格式检测结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectFormatResult {
    /// 检测到的格式
    pub format: String,
    /// 文件路径
    pub path: String,
}

/// 导入结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportResult {
    /// 是否成功
    pub success: bool,
    /// 导入的书籍信息（成功时）
    pub book: Option<Book>,
    /// 错误信息（失败时）
    pub error: Option<String>,
}

pub struct BookImportResources {
    pub storage: Option<StorageContext>,
    pub resolve_path: LocalPathResolver,
}
pub struct BookImportService {
    resources: BookImportResources,
}
impl BookImportService {
    pub fn new(resources: BookImportResources) -> Self {
        Self { resources }
    }
    fn with_database<T>(
        &self,
        f: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.resources
            .storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(f)
    }
    pub fn detect_format(&self, file_path: &str) -> LegadoResult<DetectFormatResult> {
        let format = LocalBook::detect_format(file_path)?;
        Ok(DetectFormatResult {
            format: format.as_str().to_string(),
            path: file_path.to_string(),
        })
    }
    pub fn parse_metadata(&self, file_path: &str) -> LegadoResult<BookMetadata> {
        LocalBook::parse(file_path)
    }
    pub fn import_local_book(&self, file_path: &str) -> LegadoResult<ImportResult> {
        // 还原为真实文件路径（相对标识 → 当前 Documents 拼接；绝对/Web 原样）
        let real_path = (self.resources.resolve_path)(file_path);

        // 检测格式（用于验证文件是否为支持的格式）
        let format = LocalBook::detect_format(&real_path)?;

        // 解析元数据
        let metadata = match LocalBook::parse(&real_path) {
            Ok(m) => m,
            Err(e) => {
                return Ok(ImportResult {
                    success: false,
                    book: None,
                    error: Some(format!("元数据解析失败: {e}")),
                });
            }
        };

        // 构造 Book 实体
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;

        let mut book = Book::default();
        book.book_url = file_path.to_string();
        book.name = metadata.title;
        book.author = metadata.author;
        book.intro = Some(metadata.description);
        book.origin = legado_core::models::book::book_type::LOCAL_TAG.to_string();
        book.origin_name = std::path::Path::new(file_path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        // 书类型：本地书基础位 LOCAL；[cbz 批 B | 2026-10-03] `.cbz` 漫画包
        // 额外带 IMAGE_BIT(64) 媒体位（位域组合，对齐 Kotlin `BookType` 位语义；
        // 与 BookSourceType 数值域的 `book_type::IMAGE=2` 不同域，勿混用）。
        // 其余本地格式（txt/epub/mobi/azw/azw3/pdf/umd）保持 LOCAL 无媒体位。
        book.book_type = if format == BookFormat::Cbz {
            legado_core::models::book::book_type::LOCAL
                | legado_core::models::book::book_type::IMAGE_BIT
        } else {
            legado_core::models::book::book_type::LOCAL
        };
        book.last_check_time = now;

        // 插入数据库
        let result = self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.insert(&book)
        });

        match result {
            Ok(()) => Ok(ImportResult {
                success: true,
                book: Some(book),
                error: None,
            }),
            Err(e) => Ok(ImportResult {
                success: false,
                book: None,
                error: Some(format!("导入数据库失败: {e}")),
            }),
        }
    }
}

#[cfg(test)]
mod tests;
