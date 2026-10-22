//! 文件和服务稳定快照；原生字节不经 Base64。— Codex + Bridge

/// 书签导出仅支持既有JSON与Markdown两种格式。
#[derive(Debug, Clone, Copy)]
pub enum BookmarkExportFormatDto {
    Json,
    Markdown,
}
impl From<BookmarkExportFormatDto> for legado_core::bookmark_export::BookmarkExportFormat {
    fn from(value: BookmarkExportFormatDto) -> Self {
        match value {
            BookmarkExportFormatDto::Json => Self::Json,
            BookmarkExportFormatDto::Markdown => Self::Markdown,
        }
    }
}

#[derive(Debug, Clone)]
pub struct BookmarkExportDocumentDto {
    pub file_name: String,
    pub mime_type: String,
    pub content: String,
}
impl From<legado_core::bookmark_export::BookmarkExportDocument> for BookmarkExportDocumentDto {
    fn from(value: legado_core::bookmark_export::BookmarkExportDocument) -> Self {
        Self {
            file_name: value.file_name,
            mime_type: value.mime_type,
            content: value.content,
        }
    }
}

#[derive(Debug, Clone)]
pub struct DetectFormatDto {
    pub format: String,
    pub path: String,
}
impl From<crate::api::book_import::DetectFormatResult> for DetectFormatDto {
    fn from(v: crate::api::book_import::DetectFormatResult) -> Self {
        Self {
            format: v.format,
            path: v.path,
        }
    }
}
#[derive(Debug, Clone)]
pub struct LocalImportDto {
    pub success: bool,
    pub book: Option<crate::transfer_dto::BookDto>,
    pub error: Option<String>,
}
impl From<crate::api::book_import::ImportResult> for LocalImportDto {
    fn from(v: crate::api::book_import::ImportResult) -> Self {
        Self {
            success: v.success,
            book: v.book.map(Into::into),
            error: v.error,
        }
    }
}
#[derive(Debug, Clone)]
pub struct BookExportDto {
    pub success: bool,
    pub data: Option<Vec<u8>>,
    pub file_name: Option<String>,
    pub mime_type: Option<String>,
    pub chapter_count: Option<usize>,
    pub error: Option<String>,
}
impl From<crate::api::book_export::ExportResult> for BookExportDto {
    fn from(v: crate::api::book_export::ExportResult) -> Self {
        Self {
            success: v.success,
            data: v.data,
            file_name: v.file_name,
            mime_type: v.mime_type,
            chapter_count: v.chapter_count,
            error: v.error,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ArchiveImportDto {
    pub success: bool,
    pub extracted_files: Vec<String>,
    pub error: Option<String>,
}
impl From<crate::api::archive_import_api::ArchiveImportResult> for ArchiveImportDto {
    fn from(v: crate::api::archive_import_api::ArchiveImportResult) -> Self {
        Self {
            success: v.success,
            extracted_files: v.extracted_files,
            error: v.error,
        }
    }
}
#[derive(Debug, Clone)]
pub struct EncodingDto {
    pub encoding: String,
    pub has_bom: bool,
    pub confidence: String,
}
impl From<crate::api::archive_import_api::EncodingResult> for EncodingDto {
    fn from(v: crate::api::archive_import_api::EncodingResult) -> Self {
        Self {
            encoding: v.encoding,
            has_bom: v.has_bom,
            confidence: v.confidence,
        }
    }
}
#[derive(Debug, Clone)]
pub struct EncodingConversionDto {
    pub success: bool,
    pub output_path: Option<String>,
    pub error: Option<String>,
}
impl From<crate::api::archive_import_api::ConvertResult> for EncodingConversionDto {
    fn from(v: crate::api::archive_import_api::ConvertResult) -> Self {
        Self {
            success: v.success,
            output_path: v.output_path,
            error: v.error,
        }
    }
}
#[derive(Debug, Clone)]
pub struct WebDavFileDto {
    pub name: String,
    pub path: String,
    pub size: u64,
    pub last_modified: Option<String>,
    pub etag: Option<String>,
    pub is_dir: bool,
}
impl From<legado_net::webdav::WebDavFileInfo> for WebDavFileDto {
    fn from(v: legado_net::webdav::WebDavFileInfo) -> Self {
        Self {
            name: v.name,
            path: v.path,
            size: v.size,
            last_modified: v.last_modified,
            etag: v.etag,
            is_dir: v.is_dir,
        }
    }
}
#[derive(Debug, Clone)]
pub enum BookFormatDto {
    Epub,
    Mobi,
    Txt,
    Pdf,
    Umd,
    Cbz,
}
impl From<legado_book::BookFormat> for BookFormatDto {
    fn from(v: legado_book::BookFormat) -> Self {
        match v {
            legado_book::BookFormat::Epub => Self::Epub,
            legado_book::BookFormat::Mobi => Self::Mobi,
            legado_book::BookFormat::Txt => Self::Txt,
            legado_book::BookFormat::Pdf => Self::Pdf,
            legado_book::BookFormat::Umd => Self::Umd,
            legado_book::BookFormat::Cbz => Self::Cbz,
        }
    }
}
#[derive(Debug, Clone)]
pub struct BookMetadataDto {
    pub title: String,
    pub author: String,
    pub description: String,
    pub format: BookFormatDto,
}
impl From<legado_book::BookMetadata> for BookMetadataDto {
    fn from(v: legado_book::BookMetadata) -> Self {
        Self {
            title: v.title,
            author: v.author,
            description: v.description,
            format: v.format.into(),
        }
    }
}
#[derive(Debug, Clone)]
pub struct ServerStatusDto {
    pub running: bool,
    pub port: u16,
}
