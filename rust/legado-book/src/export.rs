//! 书籍导出模块
//!
//! 支持将书籍内容导出为 TXT、EPUB、HTML、PDF 四种格式。
//!
//! PDF 导出对齐上游 ExportBookService.kt 的排版风格：
//! A4 页面、章节标题加粗加大、正文段落首行缩进、自动分页。
//! 中文渲染依赖系统 CJK 字体（自动查找，支持 TTC 字体面选择），
//! 字体缺失时返回明确错误而非 panic。
//!
//! 图片书（漫画类书源）PDF 导出（对齐上游 #483 图片路径）：
//! 章节图片列表（`ExportChapter::images`，URL 或本地路径）逐张写入 PDF，
//! 每页一图、按原始宽高比适配 A4 内容区并水平居中；本地图片直接读文件，
//! 网络图片通过调用方注入的 [`ImageFetcher`] 下载（复用 legado-net 客户端）。

use std::io::{Cursor, Write};
use std::path::PathBuf;
use std::sync::LazyLock;

use image::GenericImageView;

#[path = "export_pdf.rs"]
mod pdf;
use zip::ZipWriter;
use zip::write::SimpleFileOptions;

/// 导出格式
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportFormat {
    Txt,
    Epub,
    Html,
    Pdf,
}

impl ExportFormat {
    /// 从字符串解析导出格式
    #[allow(clippy::should_implement_trait)]
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "txt" => Some(Self::Txt),
            "epub" => Some(Self::Epub),
            "html" => Some(Self::Html),
            "pdf" => Some(Self::Pdf),
            _ => None,
        }
    }

    /// 获取文件扩展名
    pub fn extension(&self) -> &'static str {
        match self {
            Self::Txt => "txt",
            Self::Epub => "epub",
            Self::Html => "html",
            Self::Pdf => "pdf",
        }
    }

    /// 获取 MIME 类型
    pub fn mime_type(&self) -> &'static str {
        match self {
            Self::Txt => "text/plain",
            Self::Epub => "application/epub+zip",
            Self::Html => "text/html",
            Self::Pdf => "application/pdf",
        }
    }
}

/// 导出配置
#[derive(Debug, Clone)]
pub struct ExportConfig {
    pub format: ExportFormat,
    /// 是否包含目录
    pub include_toc: bool,
    /// 章节分隔符
    pub chapter_separator: String,
    /// 输出编码（UTF-8/GBK）
    pub encoding: String,
}

impl Default for ExportConfig {
    fn default() -> Self {
        Self {
            format: ExportFormat::Txt,
            include_toc: true,
            chapter_separator: String::new(),
            encoding: "UTF-8".to_string(),
        }
    }
}

/// 导出数据
#[derive(Debug, Clone)]
pub struct ExportData {
    pub title: String,
    pub author: String,
    pub intro: Option<String>,
    pub chapters: Vec<ExportChapter>,
}

/// 导出章节
#[derive(Debug, Clone)]
pub struct ExportChapter {
    pub index: i32,
    pub title: String,
    pub content: String,
    /// 章节图片源列表（绝对 URL 或本地文件路径，按页面顺序）
    ///
    /// 图片书（漫画）的章节正文缓存中以 `<img src="...">` 标签承载图片，
    /// API 层提取并绝对化后填入本字段；文本章节保持空列表。
    pub images: Vec<String>,
}

/// 图片获取器：将图片源解析为原始字节
///
/// 由 API 层注入（如 FFI 层用 legado-net 的共享 LegadoClient 下载），
/// 保持 legado-book 零网络依赖。仅处理网络 URL；本地文件路径由
/// [`fetch_image_bytes`] 直接读取，不会进入本回调。
pub type ImageFetcher = dyn Fn(&str) -> Result<Vec<u8>, String> + Send + Sync;

/// 导出器
pub struct BookExporter;

impl BookExporter {
    /// 导出为 TXT
    pub fn export_txt(data: &ExportData, config: &ExportConfig) -> Result<Vec<u8>, String> {
        let mut output = String::new();
        // 标题 + 作者
        output.push_str(&format!("{}\n作者：{}\n\n", data.title, data.author));
        if let Some(intro) = &data.intro {
            output.push_str(&format!("简介：{}\n\n", intro));
        }
        if config.include_toc {
            output.push_str("目录\n");
            for ch in &data.chapters {
                output.push_str(&format!("  {}\n", ch.title));
            }
            output.push('\n');
        }
        for ch in &data.chapters {
            output.push_str(&format!("{}\n\n{}\n\n", ch.title, ch.content));
            if !config.chapter_separator.is_empty() {
                output.push_str(&config.chapter_separator);
                output.push('\n');
            }
        }
        // 按 config.encoding 编码输出（Task #136 R8，对齐 Kotlin ExportBookService
        // `Charset.forName(AppConfig.exportCharset)`；仅 TXT 生效，缺省 UTF-8 行为不变）
        Ok(encode_text(&output, &config.encoding))
    }

    /// 导出为 EPUB
    pub fn export_epub(data: &ExportData, _config: &ExportConfig) -> Result<Vec<u8>, String> {
        let buf = Cursor::new(Vec::new());
        let mut zip = ZipWriter::new(buf);

        // 1. mimetype（不压缩，必须是第一个文件）
        let stored =
            SimpleFileOptions::default().compression_method(zip::CompressionMethod::Stored);
        zip.start_file("mimetype", stored)
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;
        zip.write_all(b"application/epub+zip")
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;

        // 2. META-INF/container.xml
        let deflate =
            SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
        zip.start_file("META-INF/container.xml", deflate)
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;
        zip.write_all(epub_container_xml().as_bytes())
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;

        // 3. OEBPS/content.opf
        zip.start_file("OEBPS/content.opf", deflate)
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;
        zip.write_all(epub_content_opf(data).as_bytes())
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;

        // 4. OEBPS/toc.ncx
        zip.start_file("OEBPS/toc.ncx", deflate)
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;
        zip.write_all(epub_toc_ncx(data).as_bytes())
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;

        // 5. OEBPS/style.css
        zip.start_file("OEBPS/style.css", deflate)
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;
        zip.write_all(epub_style_css().as_bytes())
            .map_err(|e| format!("EPUB 写入失败: {e}"))?;

        // 6. 各章节 XHTML
        for ch in &data.chapters {
            let path = format!("OEBPS/chapters/chapter_{}.xhtml", ch.index);
            zip.start_file(&path, deflate)
                .map_err(|e| format!("EPUB 写入失败: {e}"))?;
            zip.write_all(epub_chapter_xhtml(ch).as_bytes())
                .map_err(|e| format!("EPUB 写入失败: {e}"))?;
        }

        let cursor = zip
            .finish()
            .map_err(|e| format!("EPUB 完成写入失败: {e}"))?;
        Ok(cursor.into_inner())
    }

    /// 导出为 HTML
    pub fn export_html(data: &ExportData, config: &ExportConfig) -> Result<Vec<u8>, String> {
        let mut html = String::new();
        html.push_str("<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n");
        html.push_str("<meta charset=\"UTF-8\">\n");
        html.push_str(&format!("<title>{}</title>\n", html_escape(&data.title)));
        html.push_str("<style>\n");
        html.push_str(HTML_CSS);
        html.push_str("</style>\n</head>\n<body>\n");

        // 标题区
        html.push_str("<div class=\"book-header\">\n");
        html.push_str(&format!("  <h1>{}</h1>\n", html_escape(&data.title)));
        html.push_str(&format!(
            "  <p class=\"author\">作者：{}</p>\n",
            html_escape(&data.author)
        ));
        if let Some(intro) = &data.intro {
            html.push_str(&format!(
                "  <p class=\"intro\">{}</p>\n",
                html_escape(intro)
            ));
        }
        html.push_str("</div>\n");

        // 目录
        if config.include_toc {
            html.push_str("<div class=\"toc\">\n  <h2>目录</h2>\n  <ul>\n");
            for ch in &data.chapters {
                html.push_str(&format!(
                    "    <li><a href=\"#chapter-{}\">{}</a></li>\n",
                    ch.index,
                    html_escape(&ch.title)
                ));
            }
            html.push_str("  </ul>\n</div>\n");
        }

        // 章节内容
        html.push_str("<div class=\"content\">\n");
        for ch in &data.chapters {
            html.push_str(&format!(
                "  <div class=\"chapter\" id=\"chapter-{}\">\n",
                ch.index
            ));
            html.push_str(&format!("    <h2>{}</h2>\n", html_escape(&ch.title)));
            // 将段落转换为 <p> 标签
            for para in ch.content.split('\n') {
                let trimmed = para.trim();
                if !trimmed.is_empty() {
                    html.push_str(&format!("    <p>{}</p>\n", html_escape(trimmed)));
                }
            }
            html.push_str("  </div>\n");
        }
        html.push_str("</div>\n</body>\n</html>\n");

        Ok(html.into_bytes())
    }

    /// 统一导出接口
    pub fn export(data: &ExportData, config: &ExportConfig) -> Result<Vec<u8>, String> {
        Self::export_with(data, config, None)
    }

    /// 统一导出接口（带图片获取器）
    ///
    /// `fetcher` 用于图片书 PDF 导出时下载网络图片；
    /// 传 `None` 时仅支持本地图片，网络图片返回明确错误。
    pub fn export_with(
        data: &ExportData,
        config: &ExportConfig,
        fetcher: Option<&ImageFetcher>,
    ) -> Result<Vec<u8>, String> {
        match config.format {
            ExportFormat::Txt => Self::export_txt(data, config),
            ExportFormat::Epub => Self::export_epub(data, config),
            ExportFormat::Html => Self::export_html(data, config),
            ExportFormat::Pdf => Self::export_pdf_with(data, config, fetcher),
        }
    }

    /// 导出为 PDF
    ///
    /// 排版规则（对齐上游 ExportBookService.kt）：
    /// - 书名（加粗加大，居中）+ 作者 + 简介
    /// - 可选目录
    /// - 每章分页，章节标题加粗加大，正文段落首行缩进两字符
    ///
    /// 图片书（含图片列表的章节）自动走图片管线，见 [`export_pdf_with`]。
    pub fn export_pdf(data: &ExportData, config: &ExportConfig) -> Result<Vec<u8>, String> {
        Self::export_pdf_with(data, config, None)
    }

    /// 导出为 PDF（带图片获取器）
    ///
    /// 正文和图片按章节顺序写入；图片按原始宽高比适配A4内容区并水平居中，不放大。
    pub fn export_pdf_with(
        data: &ExportData,
        config: &ExportConfig,
        fetcher: Option<&ImageFetcher>,
    ) -> Result<Vec<u8>, String> {
        pdf::export(data, config, fetcher)
    }
}

// ---------------------------------------------------------------------------
// 图片获取与解码（图片书 PDF 导出管线）
// ---------------------------------------------------------------------------

/// A4 内容区尺寸（页宽 210mm − 左右各 18mm 边距；页高 297mm − 上下各 18mm）
const PDF_CONTENT_WIDTH_MM: f64 = 174.0;
const PDF_CONTENT_HEIGHT_MM: f64 = 261.0;

/// img 标签 src 提取正则（对齐 Kotlin AppPattern.imgPattern）
static IMG_SRC_RE: LazyLock<regex::Regex> = LazyLock::new(|| {
    regex::Regex::new(r#"<img[^>]*src="([^"]*(?:"[^>]+\})?)"[^>]*>"#)
        .expect("内置 img 提取正则应可编译")
});

/// 从章节正文中提取图片源列表（`<img src="...">` 标签的 src 属性，按顺序）
///
/// 图片书的章节正文缓存中以 img 标签承载图片（与 Android 原版一致）。
pub fn extract_image_sources(content: &str) -> Vec<String> {
    IMG_SRC_RE
        .captures_iter(content)
        .filter_map(|caps| {
            let src = caps.get(1)?.as_str().trim();
            if src.is_empty() {
                None
            } else {
                Some(src.to_string())
            }
        })
        .collect()
}

/// 按指定编码编码文本（Task #136 R8，对齐 Kotlin ExportBookService
/// `Charset.forName(AppConfig.exportCharset)` 的 TXT 导出编码配置）
///
/// 支持标签对齐 Kotlin `AppConst.charsets`：UTF-8 / GB2312 / GB18030 / GBK /
/// UTF-16 / UTF-16LE / ASCII（WHATWG 标签归一，GB2312 归入 GBK）。
/// 空串/未知编码/UTF-8 回落 UTF-8 字节（加法式：缺省行为不变）；
/// 不可映射字符以 `?` 替代（对齐 Kotlin 编码器 REPLACE 语义）。
pub fn encode_text(text: &str, encoding: &str) -> Vec<u8> {
    let label = encoding.trim();
    if label.is_empty() || label.eq_ignore_ascii_case("utf-8") {
        return text.as_bytes().to_vec();
    }
    let enc = match encoding_rs::Encoding::for_label_no_replacement(label.as_bytes()) {
        Some(e) => e,
        None => return text.as_bytes().to_vec(),
    };
    if enc == encoding_rs::UTF_8 {
        return text.as_bytes().to_vec();
    }

    // 逐块编码，不可映射字符替换为 '?'
    let mut encoder = enc.new_encoder();
    let mut out = Vec::with_capacity(text.len());
    let mut rest = text;
    let mut chunk = [0u8; 8192];
    loop {
        let (result, read, written) =
            encoder.encode_from_utf8_without_replacement(rest, &mut chunk, true);
        out.extend_from_slice(&chunk[..written]);
        match result {
            encoding_rs::EncoderResult::InputEmpty => break,
            encoding_rs::EncoderResult::OutputFull => continue,
            encoding_rs::EncoderResult::Unmappable(_) => {
                out.push(b'?');
                // encoding_rs 语义：read 已计入不可映射字符本身，直接从 read 处续编
                rest = &rest[read..];
            }
        }
    }
    out
}

/// 将图片源解析为原始字节
///
/// - `http://` / `https://`：调用注入的 [`ImageFetcher`] 下载；
///   未注入时返回明确错误（保持 legado-book 零网络依赖）
/// - `file://` 前缀或普通路径：直接读本地文件
pub fn fetch_image_bytes(src: &str, fetcher: Option<&ImageFetcher>) -> Result<Vec<u8>, String> {
    let src = src.trim();
    if src.starts_with("http://") || src.starts_with("https://") {
        match fetcher {
            Some(f) => f(src),
            None => Err(format!(
                "网络图片需要注入图片获取器（ImageFetcher），当前不可用: {src}"
            )),
        }
    } else {
        let path = src.strip_prefix("file://").unwrap_or(src);
        std::fs::read(path).map_err(|e| format!("读取本地图片失败: {e}"))
    }
}

/// 解码图片字节为可嵌入 PDF 的 DynamicImage（支持 JPEG/PNG）
///
/// 为保持既有导出白底呈现：带透明通道的图片先平铺到白色背景。
fn decode_pdf_image(bytes: &[u8]) -> Result<image::DynamicImage, String> {
    let img = image::load_from_memory(bytes).map_err(|e| format!("图片解码失败: {e}"))?;
    if !img.color().has_alpha() {
        return Ok(img);
    }
    // alpha 平铺到白色背景（对齐常见 PDF 阅读器的白底呈现）
    let rgba = img.to_rgba8();
    let mut rgb = image::RgbImage::new(rgba.width(), rgba.height());
    for (x, y, pixel) in rgba.enumerate_pixels() {
        let [r, g, b, a] = pixel.0;
        let af = a as f32 / 255.0;
        let blend = |c: u8| (c as f32 * af + 255.0 * (1.0 - af)).round() as u8;
        rgb.put_pixel(x, y, image::Rgb([blend(r), blend(g), blend(b)]));
    }
    Ok(image::DynamicImage::ImageRgb8(rgb))
}

/// 计算图片适配 A4 内容区的等比缩放系数
///
/// 图片按 300 DPI 将像素尺寸换算为物理尺寸；这里反算出使图片
/// 完整落入内容区（174mm × 261mm）的最大缩放，且不放大（上限 1.0，
/// 对齐 Kotlin drawImage 的 `minOf(1f, ...)` 行为）。
fn image_fit_scale(width_px: u32, height_px: u32) -> f64 {
    const DPI: f64 = 300.0; // 图片物理尺寸换算使用固定DPI
    const MM_PER_INCH: f64 = 25.4;
    let w_mm = width_px as f64 * MM_PER_INCH / DPI;
    let h_mm = height_px as f64 * MM_PER_INCH / DPI;
    let mut scale = 1.0f64;
    if w_mm > 0.0 {
        scale = scale.min(PDF_CONTENT_WIDTH_MM / w_mm);
    }
    if h_mm > 0.0 {
        scale = scale.min(PDF_CONTENT_HEIGHT_MM / h_mm);
    }
    scale
}

// ---------------------------------------------------------------------------
// HTML CSS 样式
// ---------------------------------------------------------------------------

const HTML_CSS: &str = r#"body {
  font-family: "Noto Serif SC", "Source Han Serif CN", serif;
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  line-height: 1.8;
  color: #333;
}
.book-header { text-align: center; margin-bottom: 2rem; }
.book-header h1 { font-size: 2rem; margin-bottom: 0.5rem; }
.book-header .author { color: #666; font-size: 1.1rem; }
.book-header .intro { color: #555; font-size: 0.95rem; margin-top: 1rem; }
.toc { margin: 2rem 0; padding: 1rem; border: 1px solid #ddd; border-radius: 4px; }
.toc h2 { margin-top: 0; }
.toc ul { list-style: none; padding-left: 0; }
.toc li { margin: 0.3rem 0; }
.toc a { text-decoration: none; color: #2c5aa0; }
.toc a:hover { text-decoration: underline; }
.chapter { margin: 2rem 0; page-break-before: always; }
.chapter h2 { border-bottom: 1px solid #eee; padding-bottom: 0.5rem; }
.chapter p { text-indent: 2em; margin: 0.5rem 0; }
"#;

// ---------------------------------------------------------------------------
// EPUB 辅助函数
// ---------------------------------------------------------------------------

fn epub_container_xml() -> String {
    r#"<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"#
    .to_string()
}

fn epub_content_opf(data: &ExportData) -> String {
    let mut opf = String::new();
    opf.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    opf.push_str("<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"2.0\" unique-identifier=\"BookId\">\n");
    opf.push_str("  <metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:opf=\"http://www.idpf.org/2007/opf\">\n");
    opf.push_str(&format!(
        "    <dc:title>{}</dc:title>\n",
        xml_escape(&data.title)
    ));
    opf.push_str(&format!(
        "    <dc:creator>{}</dc:creator>\n",
        xml_escape(&data.author)
    ));
    opf.push_str("    <dc:language>zh-CN</dc:language>\n");
    opf.push_str("    <dc:identifier id=\"BookId\">urn:uuid:legado-export</dc:identifier>\n");
    if let Some(intro) = &data.intro {
        opf.push_str(&format!(
            "    <dc:description>{}</dc:description>\n",
            xml_escape(intro)
        ));
    }
    opf.push_str("  </metadata>\n");

    // manifest
    opf.push_str("  <manifest>\n");
    opf.push_str(
        "    <item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/>\n",
    );
    opf.push_str("    <item id=\"style\" href=\"style.css\" media-type=\"text/css\"/>\n");
    for ch in &data.chapters {
        opf.push_str(&format!(
            "    <item id=\"chapter_{}\" href=\"chapters/chapter_{}.xhtml\" media-type=\"application/xhtml+xml\"/>\n",
            ch.index, ch.index
        ));
    }
    opf.push_str("  </manifest>\n");

    // spine
    opf.push_str("  <spine toc=\"ncx\">\n");
    for ch in &data.chapters {
        opf.push_str(&format!("    <itemref idref=\"chapter_{}\"/>\n", ch.index));
    }
    opf.push_str("  </spine>\n");
    opf.push_str("</package>\n");
    opf
}

fn epub_toc_ncx(data: &ExportData) -> String {
    let mut ncx = String::new();
    ncx.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    ncx.push_str("<ncx xmlns=\"http://www.daisy.org/z3986/2005/ncx/\" version=\"2005-1\">\n");
    ncx.push_str("  <head>\n");
    ncx.push_str("    <meta name=\"dtb:uid\" content=\"urn:uuid:legado-export\"/>\n");
    ncx.push_str("    <meta name=\"dtb:depth\" content=\"1\"/>\n");
    ncx.push_str("    <meta name=\"dtb:totalPageCount\" content=\"0\"/>\n");
    ncx.push_str("    <meta name=\"dtb:maxPageNumber\" content=\"0\"/>\n");
    ncx.push_str("  </head>\n");
    ncx.push_str(&format!(
        "  <docTitle><text>{}</text></docTitle>\n",
        xml_escape(&data.title)
    ));
    ncx.push_str("  <navMap>\n");
    for (i, ch) in data.chapters.iter().enumerate() {
        ncx.push_str(&format!(
            "    <navPoint id=\"navPoint-{}\" playOrder=\"{}\">\n",
            i + 1,
            i + 1
        ));
        ncx.push_str(&format!(
            "      <navLabel><text>{}</text></navLabel>\n",
            xml_escape(&ch.title)
        ));
        ncx.push_str(&format!(
            "      <content src=\"chapters/chapter_{}.xhtml\"/>\n",
            ch.index
        ));
        ncx.push_str("    </navPoint>\n");
    }
    ncx.push_str("  </navMap>\n");
    ncx.push_str("</ncx>\n");
    ncx
}

fn epub_style_css() -> String {
    r#"body {
  font-family: "Noto Serif SC", serif;
  line-height: 1.8;
  padding: 1em;
}
h1 { text-align: center; }
p { text-indent: 2em; margin: 0.5em 0; }
"#
    .to_string()
}

fn epub_chapter_xhtml(chapter: &ExportChapter) -> String {
    let mut xhtml = String::new();
    xhtml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    xhtml.push_str("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n");
    xhtml.push_str("<html xmlns=\"http://www.w3.org/1999/xhtml\">\n");
    xhtml.push_str("<head>\n");
    xhtml.push_str(&format!(
        "  <title>{}</title>\n",
        xml_escape(&chapter.title)
    ));
    xhtml.push_str("  <link rel=\"stylesheet\" type=\"text/css\" href=\"../style.css\"/>\n");
    xhtml.push_str("</head>\n<body>\n");
    xhtml.push_str(&format!("  <h1>{}</h1>\n", xml_escape(&chapter.title)));
    for para in chapter.content.split('\n') {
        let trimmed = para.trim();
        if !trimmed.is_empty() {
            xhtml.push_str(&format!("  <p>{}</p>\n", xml_escape(trimmed)));
        }
    }
    xhtml.push_str("</body>\n</html>\n");
    xhtml
}

// ---------------------------------------------------------------------------
// PDF 字体与排版辅助
// ---------------------------------------------------------------------------

/// PDF 字体候选项：文件路径 + 是否为 TTC 集合（取第几个字体面）
type PdfFontCandidate = (PathBuf, Option<u32>);

#[cfg(not(test))]
fn font_path(dir: &str, name: &str) -> PathBuf {
    std::path::Path::new(dir).join(name)
}

/// 常规字重候选列表（按优先级，覆盖 Windows/Linux/macOS/Android）
fn pdf_regular_candidates() -> Vec<PdfFontCandidate> {
    #[cfg(test)]
    {
        vec![(
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/pdf/pdf-test.ttf"),
            None,
        )]
    }
    #[cfg(not(test))]
    {
        let mut list: Vec<PdfFontCandidate> = Vec::new();
        // 环境变量指定的自定义字体优先级最高
        if let Ok(custom) = std::env::var("LEGADO_PDF_FONT") {
            list.push((PathBuf::from(custom), None));
        }
        // Windows
        let win = "C:\\Windows\\Fonts";
        list.push((font_path(win, "msyh.ttc"), Some(0))); // 微软雅黑
        list.push((font_path(win, "simsun.ttc"), Some(0))); // 宋体
        list.push((font_path(win, "simhei.ttf"), None)); // 黑体
        list.push((font_path(win, "simkai.ttf"), None)); // 楷体
        list.push((font_path(win, "simfang.ttf"), None)); // 仿宋
        list.push((font_path(win, "msyh.ttf"), None)); // 旧版微软雅黑
        // Linux（文泉驿/思源/Droid 等常见 CJK 字体）
        list.push((
            PathBuf::from("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"),
            Some(0),
        ));
        list.push((
            PathBuf::from("/usr/share/fonts/wqy-microhei/wqy-microhei.ttc"),
            Some(0),
        ));
        list.push((
            PathBuf::from("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"),
            Some(0),
        ));
        list.push((
            PathBuf::from("/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"),
            None,
        ));
        list.push((
            PathBuf::from("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
            Some(0),
        ));
        // macOS
        list.push((PathBuf::from("/System/Library/Fonts/PingFang.ttc"), Some(0)));
        list.push((
            PathBuf::from("/System/Library/Fonts/STHeiti Light.ttc"),
            Some(0),
        ));
        list.push((
            PathBuf::from("/System/Library/Fonts/Supplemental/Songti.ttc"),
            Some(0),
        ));
        // Android
        list.push((PathBuf::from("/system/fonts/DroidSansFallback.ttf"), None));
        list.push((
            PathBuf::from("/system/fonts/NotoSansCJK-Regular.ttc"),
            Some(0),
        ));
        list
    }
}

/// 粗体字重候选列表（找不到时由调用方退化为常规字重）
fn pdf_bold_candidates() -> Vec<PdfFontCandidate> {
    #[cfg(test)]
    {
        vec![(
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/pdf/pdf-test.ttf"),
            None,
        )]
    }
    #[cfg(not(test))]
    {
        let mut list: Vec<PdfFontCandidate> = Vec::new();
        let win = "C:\\Windows\\Fonts";
        list.push((font_path(win, "msyhbd.ttc"), Some(0))); // 微软雅黑粗体
        list.push((font_path(win, "msyhbd.ttf"), None));
        list.push((
            PathBuf::from("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"),
            Some(0),
        ));
        list
    }
}

/// 按候选列表查找并加载第一个可用的中文字体
///
/// 字体缺失时返回明确错误信息（不 panic）。
fn load_pdf_font(candidates: &[PdfFontCandidate]) -> Result<printpdf::ParsedFont, String> {
    for (path, ttc_face) in candidates {
        let Some(data) = std::fs::read(path).ok() else {
            continue;
        };
        if data.len() < 4 {
            continue;
        }
        // printpdf直接选择TTC字体面，不再重建整套sfnt表。
        if let Some(font) =
            printpdf::ParsedFont::from_bytes(&data, ttc_face.unwrap_or(0) as usize, &mut Vec::new())
            && font.units_per_em > 0
        {
            return Ok(font);
        }
    }
    Err(
        "PDF 导出失败：未找到可用的中文字体。请安装 CJK 字体（如微软雅黑、\
         文泉驿微米黑、思源黑体），或通过 LEGADO_PDF_FONT 环境变量指定字体文件路径"
            .to_string(),
    )
}

// ---------------------------------------------------------------------------
// 转义辅助
// ---------------------------------------------------------------------------

/// HTML 转义
fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

/// XML 转义
fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_data() -> ExportData {
        ExportData {
            title: "测试书籍".to_string(),
            author: "测试作者".to_string(),
            intro: Some("这是一本测试书籍的简介。".to_string()),
            chapters: vec![
                ExportChapter {
                    index: 0,
                    title: "第一章 开始".to_string(),
                    content: "这是第一章的内容。\n第二段文字。".to_string(),
                    images: vec![],
                },
                ExportChapter {
                    index: 1,
                    title: "第二章 发展".to_string(),
                    content: "这是第二章的内容。".to_string(),
                    images: vec![],
                },
                ExportChapter {
                    index: 2,
                    title: "第三章 结局".to_string(),
                    content: "这是第三章的内容。".to_string(),
                    images: vec![],
                },
            ],
        }
    }

    fn default_config(format: ExportFormat) -> ExportConfig {
        ExportConfig {
            format,
            include_toc: true,
            chapter_separator: String::new(),
            encoding: "UTF-8".to_string(),
        }
    }

    #[test]
    fn test_export_txt_basic() {
        let data = sample_data();
        let config = default_config(ExportFormat::Txt);
        let result = BookExporter::export_txt(&data, &config).unwrap();
        let text = String::from_utf8(result).unwrap();

        assert!(text.contains("测试书籍"));
        assert!(text.contains("作者：测试作者"));
        assert!(text.contains("简介：这是一本测试书籍的简介。"));
        assert!(text.contains("第一章 开始"));
        assert!(text.contains("这是第一章的内容。"));
        assert!(text.contains("第二章 发展"));
        assert!(text.contains("第三章 结局"));
    }

    /// Task #136 R8：编码转换（对齐 Kotlin AppConfig.exportCharset）
    #[test]
    fn test_encode_text() {
        // 缺省/UTF-8/空串 → 原字节
        assert_eq!(encode_text("中文abc", ""), "中文abc".as_bytes());
        assert_eq!(encode_text("中文abc", "UTF-8"), "中文abc".as_bytes());

        // GBK：「中」= 0xD6 0xD0；GB2312 标签归入 GBK
        assert_eq!(&encode_text("中", "GBK")[..2], &[0xD6, 0xD0]);
        assert_eq!(&encode_text("中", "GB2312")[..2], &[0xD6, 0xD0]);

        // ASCII：不可映射字符以 '?' 替代（对齐 Kotlin REPLACE 语义）
        assert_eq!(encode_text("A中B", "ASCII"), b"A?B");

        // 未知编码回落 UTF-8（加法式缺省兼容）
        assert_eq!(encode_text("中文", "NO-SUCH"), "中文".as_bytes());

        // TXT 导出按 encoding 生效
        let data = sample_data();
        let mut config = default_config(ExportFormat::Txt);
        config.encoding = "GBK".to_string();
        let bytes = BookExporter::export_txt(&data, &config).unwrap();
        assert!(std::str::from_utf8(&bytes).is_err(), "GBK 输出不应为 UTF-8");
    }

    #[test]
    fn test_export_txt_with_toc() {
        let data = sample_data();
        let config = default_config(ExportFormat::Txt);
        let result = BookExporter::export_txt(&data, &config).unwrap();
        let text = String::from_utf8(result).unwrap();

        assert!(text.contains("目录"));
        assert!(text.contains("  第一章 开始"));
        assert!(text.contains("  第二章 发展"));
        assert!(text.contains("  第三章 结局"));
    }

    #[test]
    fn test_export_txt_without_toc() {
        let data = sample_data();
        let mut config = default_config(ExportFormat::Txt);
        config.include_toc = false;
        let result = BookExporter::export_txt(&data, &config).unwrap();
        let text = String::from_utf8(result).unwrap();

        assert!(!text.contains("目录\n"));
    }

    #[test]
    fn test_export_txt_with_separator() {
        let data = sample_data();
        let mut config = default_config(ExportFormat::Txt);
        config.chapter_separator = "---".to_string();
        let result = BookExporter::export_txt(&data, &config).unwrap();
        let text = String::from_utf8(result).unwrap();

        assert!(text.contains("---"));
    }

    #[test]
    fn test_export_txt_empty_chapters() {
        let data = ExportData {
            title: "空书".to_string(),
            author: "无名".to_string(),
            intro: None,
            chapters: vec![],
        };
        let config = default_config(ExportFormat::Txt);
        let result = BookExporter::export_txt(&data, &config).unwrap();
        let text = String::from_utf8(result).unwrap();

        assert!(text.contains("空书"));
        assert!(text.contains("作者：无名"));
        assert!(!text.contains("简介"));
    }

    #[test]
    fn test_export_txt_special_characters() {
        let data = ExportData {
            title: "特殊<字符>&\"测试\"".to_string(),
            author: "作者'甲'".to_string(),
            intro: Some("包含 <html> & 特殊字符".to_string()),
            chapters: vec![ExportChapter {
                index: 0,
                title: "章节<1>".to_string(),
                content: "内容包含 & < > \" ' 字符".to_string(),
                images: vec![],
            }],
        };
        let config = default_config(ExportFormat::Txt);
        let result = BookExporter::export_txt(&data, &config).unwrap();
        let text = String::from_utf8(result).unwrap();

        // TXT 不做转义，原样输出
        assert!(text.contains("特殊<字符>&\"测试\""));
        assert!(text.contains("内容包含 & < > \" ' 字符"));
    }

    #[test]
    fn test_export_epub_basic() {
        let data = sample_data();
        let config = default_config(ExportFormat::Epub);
        let result = BookExporter::export_epub(&data, &config).unwrap();

        // EPUB 是 ZIP 文件，以 PK 开头
        assert!(result.len() > 4);
        assert_eq!(result[0], 0x50); // 'P'
        assert_eq!(result[1], 0x4B); // 'K'

        // 验证 ZIP 内容
        let cursor = Cursor::new(result);
        let mut archive = zip::ZipArchive::new(cursor).unwrap();
        let names: Vec<String> = (0..archive.len())
            .map(|i| archive.by_index(i).unwrap().name().unwrap().into_owned())
            .collect();

        assert!(names.contains(&"mimetype".to_string()));
        assert!(names.contains(&"META-INF/container.xml".to_string()));
        assert!(names.contains(&"OEBPS/content.opf".to_string()));
        assert!(names.contains(&"OEBPS/toc.ncx".to_string()));
        assert!(names.contains(&"OEBPS/style.css".to_string()));
        assert!(names.contains(&"OEBPS/chapters/chapter_0.xhtml".to_string()));
        assert!(names.contains(&"OEBPS/chapters/chapter_1.xhtml".to_string()));
        assert!(names.contains(&"OEBPS/chapters/chapter_2.xhtml".to_string()));
    }

    #[test]
    fn test_export_epub_mimetype_first() {
        let data = sample_data();
        let config = default_config(ExportFormat::Epub);
        let result = BookExporter::export_epub(&data, &config).unwrap();

        let cursor = Cursor::new(result);
        let mut archive = zip::ZipArchive::new(cursor).unwrap();
        // 第一个文件必须是 mimetype
        let first = archive.by_index(0).unwrap();
        assert_eq!(first.name().unwrap(), "mimetype");
    }

    #[test]
    fn test_export_epub_empty_chapters() {
        let data = ExportData {
            title: "空书".to_string(),
            author: "无名".to_string(),
            intro: None,
            chapters: vec![],
        };
        let config = default_config(ExportFormat::Epub);
        let result = BookExporter::export_epub(&data, &config).unwrap();

        // 仍然应该是有效的 ZIP
        let cursor = Cursor::new(result);
        let archive = zip::ZipArchive::new(cursor).unwrap();
        assert!(archive.len() >= 5); // mimetype + container + opf + ncx + css
    }

    #[test]
    fn test_export_html_basic() {
        let data = sample_data();
        let config = default_config(ExportFormat::Html);
        let result = BookExporter::export_html(&data, &config).unwrap();
        let html = String::from_utf8(result).unwrap();

        assert!(html.contains("<!DOCTYPE html>"));
        assert!(html.contains("<title>测试书籍</title>"));
        assert!(html.contains("<h1>测试书籍</h1>"));
        assert!(html.contains("作者：测试作者"));
        assert!(html.contains("第一章 开始"));
        assert!(html.contains("这是第一章的内容。"));
    }

    #[test]
    fn test_export_html_toc_links() {
        let data = sample_data();
        let config = default_config(ExportFormat::Html);
        let result = BookExporter::export_html(&data, &config).unwrap();
        let html = String::from_utf8(result).unwrap();

        assert!(html.contains("href=\"#chapter-0\""));
        assert!(html.contains("href=\"#chapter-1\""));
        assert!(html.contains("href=\"#chapter-2\""));
        assert!(html.contains("id=\"chapter-0\""));
        assert!(html.contains("id=\"chapter-1\""));
        assert!(html.contains("id=\"chapter-2\""));
    }

    #[test]
    fn test_export_html_special_characters_escaped() {
        let data = ExportData {
            title: "书<名>&\"引号\"".to_string(),
            author: "作者".to_string(),
            intro: None,
            chapters: vec![ExportChapter {
                index: 0,
                title: "章节<1>&测试".to_string(),
                content: "内容 <script>alert('xss')</script>".to_string(),
                images: vec![],
            }],
        };
        let config = default_config(ExportFormat::Html);
        let result = BookExporter::export_html(&data, &config).unwrap();
        let html = String::from_utf8(result).unwrap();

        // 特殊字符应被转义
        assert!(html.contains("书&lt;名&gt;&amp;&quot;引号&quot;"));
        assert!(html.contains("&lt;script&gt;"));
        // 不应有未转义的 script 标签
        assert!(!html.contains("<script>"));
    }

    #[test]
    fn test_export_html_no_toc() {
        let data = sample_data();
        let mut config = default_config(ExportFormat::Html);
        config.include_toc = false;
        let result = BookExporter::export_html(&data, &config).unwrap();
        let html = String::from_utf8(result).unwrap();

        assert!(!html.contains("class=\"toc\""));
    }

    #[test]
    fn test_export_large_text() {
        let large_content = "这是一段很长的文字。".repeat(10000);
        let data = ExportData {
            title: "大文本测试".to_string(),
            author: "作者".to_string(),
            intro: None,
            chapters: vec![ExportChapter {
                index: 0,
                title: "超长章节".to_string(),
                content: large_content,
                images: vec![],
            }],
        };

        // TXT
        let config = default_config(ExportFormat::Txt);
        let result = BookExporter::export_txt(&data, &config).unwrap();
        assert!(result.len() > 100_000);

        // HTML
        let config = default_config(ExportFormat::Html);
        let result = BookExporter::export_html(&data, &config).unwrap();
        assert!(result.len() > 100_000);

        // EPUB (compressed, so smaller)
        let config = default_config(ExportFormat::Epub);
        let result = BookExporter::export_epub(&data, &config).unwrap();
        assert!(result.len() > 1_000);
    }

    #[test]
    fn test_export_unified_interface() {
        let data = sample_data();

        let config = default_config(ExportFormat::Txt);
        let txt = BookExporter::export(&data, &config).unwrap();
        assert!(!txt.is_empty());

        let config = default_config(ExportFormat::Epub);
        let epub = BookExporter::export(&data, &config).unwrap();
        assert_eq!(epub[0], 0x50);

        let config = default_config(ExportFormat::Html);
        let html = BookExporter::export(&data, &config).unwrap();
        let html_str = String::from_utf8(html).unwrap();
        assert!(html_str.contains("<!DOCTYPE html>"));
    }

    #[test]
    fn test_export_format_from_str() {
        assert_eq!(ExportFormat::from_str("txt"), Some(ExportFormat::Txt));
        assert_eq!(ExportFormat::from_str("TXT"), Some(ExportFormat::Txt));
        assert_eq!(ExportFormat::from_str("epub"), Some(ExportFormat::Epub));
        assert_eq!(ExportFormat::from_str("EPUB"), Some(ExportFormat::Epub));
        assert_eq!(ExportFormat::from_str("html"), Some(ExportFormat::Html));
        assert_eq!(ExportFormat::from_str("HTML"), Some(ExportFormat::Html));
        assert_eq!(ExportFormat::from_str("pdf"), Some(ExportFormat::Pdf));
        assert_eq!(ExportFormat::from_str("PDF"), Some(ExportFormat::Pdf));
        assert_eq!(ExportFormat::from_str("docx"), None);
        assert_eq!(ExportFormat::from_str(""), None);
    }

    #[test]
    fn test_export_format_extension_and_mime() {
        assert_eq!(ExportFormat::Txt.extension(), "txt");
        assert_eq!(ExportFormat::Epub.extension(), "epub");
        assert_eq!(ExportFormat::Html.extension(), "html");
        assert_eq!(ExportFormat::Pdf.extension(), "pdf");

        assert_eq!(ExportFormat::Txt.mime_type(), "text/plain");
        assert_eq!(ExportFormat::Epub.mime_type(), "application/epub+zip");
        assert_eq!(ExportFormat::Html.mime_type(), "text/html");
        assert_eq!(ExportFormat::Pdf.mime_type(), "application/pdf");
    }

    // ------------------------------------------------------------------
    // PDF 导出测试
    // ------------------------------------------------------------------

    /// 小文本 PDF 生成：验证文件头 %PDF 与基本内容大小
    /// 使用受控测试字体，无字体时不得静默跳过。
    #[test]
    fn test_export_pdf_basic() {
        let bytes =
            BookExporter::export_pdf(&sample_data(), &default_config(ExportFormat::Pdf)).unwrap();
        assert!(bytes.starts_with(b"%PDF"));
        let doc = lopdf::Document::load_mem(&bytes).unwrap();
        let pages: Vec<_> = doc.get_pages().keys().copied().collect();
        let text = doc.extract_text(&pages).unwrap();
        let normalized: String = text.chars().filter(|c| !c.is_whitespace()).collect();
        assert!(normalized.contains("测试书籍"));
        assert!(normalized.contains("目录"));
        for chapter in sample_data().chapters {
            for paragraph in chapter.content.lines() {
                assert!(normalized.contains(paragraph));
            }
        }
    }

    /// 统一导出接口应覆盖 Pdf 变体
    #[test]
    fn test_export_unified_interface_pdf() {
        let bytes =
            BookExporter::export(&sample_data(), &default_config(ExportFormat::Pdf)).unwrap();
        assert!(bytes.starts_with(b"%PDF"));
    }

    #[test]
    fn pdf_chapter_pages_toc_and_long_text_are_complete() {
        let mut data = sample_data();
        data.chapters.truncate(2);
        data.chapters[0].content = format!("{}[END]", "正文内容。".repeat(1000));
        data.chapters[1].content = "结束".into();
        let mut config = default_config(ExportFormat::Pdf);
        config.include_toc = false;
        let bytes = BookExporter::export_pdf(&data, &config).unwrap();
        let doc = lopdf::Document::load_mem(&bytes).unwrap();
        let pages: Vec<_> = doc.get_pages().keys().copied().collect();
        assert!(pages.len() > 3);
        let text = doc.extract_text(&pages).unwrap();
        let normalized: String = text.chars().filter(|c| !c.is_whitespace()).collect();
        assert_eq!(normalized.matches("正文内容。").count(), 1000);
        assert_eq!(normalized.matches("[END]").count(), 1);
        assert!(!normalized.contains("目录"));
        let final_page = doc.extract_text(&[*pages.last().unwrap()]).unwrap();
        let final_page: String = final_page.chars().filter(|c| !c.is_whitespace()).collect();
        assert!(final_page.contains("第二章发展"));
        assert!(final_page.contains("结束"));
        assert!(!final_page.contains("[END]"));
    }

    #[test]
    fn pdf_mixed_content_keeps_text_and_actual_image_dimensions() {
        let mut data = sample_data();
        data.chapters.truncate(1);
        data.chapters[0].images = vec!["https://example.com/image.png".into()];
        let fetcher: &ImageFetcher = &|_| Ok(make_png_bytes(80, 40, true));
        let bytes =
            BookExporter::export_pdf_with(&data, &default_config(ExportFormat::Pdf), Some(fetcher))
                .unwrap();
        let doc = lopdf::Document::load_mem(&bytes).unwrap();
        let pages: Vec<_> = doc.get_pages().keys().copied().collect();
        let text = doc.extract_text(&pages).unwrap();
        let text: String = text.chars().filter(|c| !c.is_whitespace()).collect();
        assert!(text.contains("这是第一章的内容。"));
        let dimensions: Vec<_> = doc
            .objects
            .values()
            .filter_map(|object| {
                let stream = object.as_stream().ok()?;
                if stream.dict.get(b"Subtype").ok()?.as_name().ok()? != b"Image" {
                    return None;
                }
                Some((
                    stream.dict.get(b"Width").ok()?.as_i64().ok()?,
                    stream.dict.get(b"Height").ok()?.as_i64().ok()?,
                ))
            })
            .collect();
        assert_eq!(dimensions, vec![(80, 40)]);
    }

    #[test]
    fn pdf_missing_glyph_is_an_error_instead_of_silent_text_loss() {
        let mut data = sample_data();
        data.title = "\u{10ffff}".into();
        assert!(
            BookExporter::export_pdf(&data, &default_config(ExportFormat::Pdf))
                .unwrap_err()
                .contains("字体不包含字符")
        );
    }

    /// 字体降级：空候选列表必须返回明确错误而非 panic
    #[test]
    fn test_pdf_font_fallback_error() {
        let result = load_pdf_font(&[]);
        assert!(result.is_err(), "无候选字体时应返回错误");
        let err = result.unwrap_err();
        assert!(err.contains("字体"), "错误信息应提及字体: {err}");
        assert!(err.contains("LEGADO_PDF_FONT"), "应提示环境变量降级方案");
    }

    /// 字体降级：全部候选路径不存在时应返回错误
    #[test]
    fn test_pdf_font_missing_candidates() {
        let candidates: Vec<PdfFontCandidate> = vec![
            (PathBuf::from("/nonexistent/font_a.ttf"), None),
            (PathBuf::from("/nonexistent/font_b.ttc"), Some(0)),
        ];
        assert!(load_pdf_font(&candidates).is_err());
    }

    #[test]
    fn test_pdf_font_invalid_and_ttc_face_selection() {
        assert!(printpdf::ParsedFont::from_bytes(b"not-a-font", 0, &mut Vec::new()).is_none());
        let path =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/pdf/pdf-test.ttc");
        let font = load_pdf_font(&[(path.clone(), Some(0))]).unwrap();
        assert!(font.lookup_glyph_index('中' as u32).is_some());
        assert!(load_pdf_font(&[(path, Some(1))]).is_err());
    }

    #[test]
    fn test_html_escape_function() {
        assert_eq!(html_escape("a & b"), "a &amp; b");
        assert_eq!(html_escape("<tag>"), "&lt;tag&gt;");
        assert_eq!(html_escape("\"quote\""), "&quot;quote&quot;");
        assert_eq!(html_escape("it's"), "it&#39;s");
    }

    #[test]
    fn test_xml_escape_function() {
        assert_eq!(xml_escape("a & b"), "a &amp; b");
        assert_eq!(xml_escape("<tag>"), "&lt;tag&gt;");
        assert_eq!(xml_escape("\"quote\""), "&quot;quote&quot;");
        assert_eq!(xml_escape("it's"), "it&apos;s");
    }

    // ------------------------------------------------------------------
    // 图片书（漫画）PDF 导出测试（对齐上游 #483）
    // ------------------------------------------------------------------

    /// 用 image crate 生成最小 PNG 字节（测试样本，避免外部文件依赖）
    fn make_png_bytes(width: u32, height: u32, alpha: bool) -> Vec<u8> {
        use image::ImageEncoder;
        let mut buf = Vec::new();
        if alpha {
            // 半透明红色（验证 alpha 平铺白底逻辑）
            let img = image::RgbaImage::from_pixel(width, height, image::Rgba([255, 0, 0, 128]));
            let encoder = image::codecs::png::PngEncoder::new(&mut buf);
            encoder
                .write_image(img.as_raw(), width, height, image::ExtendedColorType::Rgba8)
                .unwrap();
        } else {
            let img = image::RgbImage::from_pixel(width, height, image::Rgb([30, 60, 200]));
            let encoder = image::codecs::png::PngEncoder::new(&mut buf);
            encoder
                .write_image(img.as_raw(), width, height, image::ExtendedColorType::Rgb8)
                .unwrap();
        }
        buf
    }

    /// 程序化生成最小合法 JPEG（验证 JPEG 解码路径）
    fn make_jpeg_bytes() -> Vec<u8> {
        let img = image::RgbImage::from_pixel(8, 8, image::Rgb([200, 100, 40]));
        let mut buf = Vec::new();
        let mut encoder = image::codecs::jpeg::JpegEncoder::new(&mut buf);
        encoder
            .encode(img.as_raw(), 8, 8, image::ExtendedColorType::Rgb8)
            .unwrap();
        buf
    }

    /// 统计 PDF 页数（lopdf 已是依赖，无需新增）
    fn pdf_page_count(bytes: &[u8]) -> usize {
        let doc = lopdf::Document::load_mem(bytes).expect("导出结果应为可解析的 PDF");
        doc.get_pages().len()
    }

    /// 图片源提取：对齐 Kotlin AppPattern.imgPattern 行为
    #[test]
    fn test_extract_image_sources() {
        let content = "前文<img src=\"https://cdn.example.com/1.jpg\">中间文字\
<img class=\"lazy\" data-x=\"1\" src='/images/2.png' >尾部";
        // 注意：正则匹配双引号 src，单引号的不匹配（与上游一致）
        let srcs = extract_image_sources(content);
        assert_eq!(srcs.len(), 1);
        assert_eq!(srcs[0], "https://cdn.example.com/1.jpg");

        // 多张顺序保持
        let multi = "<img src=\"a.png\"><img src=\"b.png\"><img src=\"c.png\">";
        assert_eq!(
            extract_image_sources(multi),
            vec![
                "a.png".to_string(),
                "b.png".to_string(),
                "c.png".to_string()
            ]
        );

        // 无图片返回空
        assert!(extract_image_sources("纯文本章节内容").is_empty());
    }

    /// 图片获取：本地路径直读，file:// 前缀支持
    #[test]
    fn test_fetch_image_bytes_local() {
        let dir = std::env::temp_dir();
        let path = dir.join(format!("legado_img_fetch_{}.png", std::process::id()));
        let png = make_png_bytes(8, 8, false);
        std::fs::write(&path, &png).unwrap();

        let bytes = fetch_image_bytes(path.to_str().unwrap(), None).unwrap();
        assert_eq!(bytes, png);

        let file_url = format!("file://{}", path.to_string_lossy().replace('\\', "/"));
        // Windows 下 file:// + 盘符路径仅作前缀去除验证，路径不存在时应报读文件错
        let _ = fetch_image_bytes(&file_url, None);

        let _ = std::fs::remove_file(&path);

        // 不存在的本地文件返回错误而非 panic
        let err = fetch_image_bytes("/nonexistent/img_不存在.png", None).unwrap_err();
        assert!(err.contains("本地图片"), "错误应提及本地图片: {err}");
    }

    /// 图片获取：网络图片未注入 fetcher 时返回明确错误
    #[test]
    fn test_fetch_image_bytes_network_without_fetcher() {
        let err = fetch_image_bytes("https://cdn.example.com/1.jpg", None).unwrap_err();
        assert!(
            err.contains("ImageFetcher"),
            "错误应提示需要注入获取器: {err}"
        );

        // 注入 mock fetcher 后正常返回字节
        let fetcher: &ImageFetcher = &|src: &str| {
            assert_eq!(src, "https://cdn.example.com/1.jpg");
            Ok(vec![1, 2, 3])
        };
        assert_eq!(
            fetch_image_bytes("https://cdn.example.com/1.jpg", Some(fetcher)).unwrap(),
            vec![1, 2, 3]
        );
    }

    /// 图片解码：JPEG/PNG 均可解码；带 alpha 的 PNG 自动平铺白底
    #[test]
    fn test_decode_pdf_image_formats_and_alpha() {
        let png = make_png_bytes(16, 24, false);
        let img = decode_pdf_image(&png).unwrap();
        assert_eq!(img.dimensions(), (16, 24));
        assert!(!img.color().has_alpha(), "无 alpha 输入应保持无 alpha");

        let jpeg = make_jpeg_bytes();
        let img = decode_pdf_image(&jpeg).unwrap();
        assert_eq!(img.dimensions(), (8, 8), "生成的 8x8 JPEG 应可解码");

        let rgba_png = make_png_bytes(8, 8, true);
        let img = decode_pdf_image(&rgba_png).unwrap();
        assert!(!img.color().has_alpha(), "alpha 应被平铺到白底");
        assert_eq!(img.to_rgb8().get_pixel(0, 0).0, [255, 127, 127]);

        // 非法字节返回错误而非 panic
        assert!(decode_pdf_image(b"not-an-image").is_err());
    }

    #[test]
    fn test_pdf_image_preserves_grayscale_and_16_bit_pixels() {
        for modern in [
            image::DynamicImage::ImageLuma8(image::GrayImage::from_pixel(2, 3, image::Luma([42]))),
            image::DynamicImage::ImageLuma16(image::ImageBuffer::from_pixel(
                2,
                3,
                image::Luma([12345u16]),
            )),
            image::DynamicImage::ImageRgb16(image::ImageBuffer::from_pixel(
                2,
                3,
                image::Rgb([12345u16, 23456, 34567]),
            )),
        ] {
            let expected = modern.as_bytes().to_vec();
            let mut png = Cursor::new(Vec::new());
            modern.write_to(&mut png, image::ImageFormat::Png).unwrap();
            let legacy = decode_pdf_image(png.get_ref()).unwrap();
            assert_eq!(legacy.dimensions(), (2, 3));
            assert_eq!(legacy.as_bytes(), expected);
            assert_eq!(
                legacy.color().bits_per_pixel(),
                modern.color().bits_per_pixel()
            );
        }
    }

    /// 适配缩放：保持宽高比、不放大、适配 A4 内容区
    #[test]
    fn test_image_fit_scale() {
        assert_eq!(image_fit_scale(100, 100), 1.0);
        assert!(image_fit_scale(800, 20000) < 1.0);
        assert!(image_fit_scale(20000, 800) < 1.0);
        let scale = image_fit_scale(1, u32::MAX);
        assert!(scale < 0.01);
        assert!((u32::MAX as f64 * 25.4 / 300.0 * scale - PDF_CONTENT_HEIGHT_MM).abs() < 0.001);
    }

    /// 图片书 PDF 生成：本地图片路径（验证 %PDF 头 + 页数）
    #[test]
    fn test_export_pdf_images_local() {
        let dir = std::env::temp_dir();
        let path = dir.join(format!("legado_img_pdf_{}.png", std::process::id()));
        std::fs::write(&path, make_png_bytes(64, 64, false)).unwrap();

        let data = ExportData {
            title: "测试漫画".to_string(),
            author: "漫画作者".to_string(),
            intro: None,
            chapters: vec![ExportChapter {
                index: 0,
                title: "第1话".to_string(),
                content: String::new(),
                images: vec![path.to_string_lossy().to_string()],
            }],
        };
        let config = default_config(ExportFormat::Pdf);
        match BookExporter::export_pdf(&data, &config) {
            Ok(bytes) => {
                assert!(bytes.len() > 4);
                assert_eq!(&bytes[0..4], b"%PDF", "图片 PDF 文件头应为 %PDF");
                // 标题页 + 章节页（含图）
                assert!(
                    pdf_page_count(&bytes) >= 2,
                    "图片 PDF 至少应有标题页 + 章节图片页"
                );
            }
            Err(e) => {
                panic!("图片 PDF 导出失败: {e}");
            }
        }
        let _ = std::fs::remove_file(&path);
    }

    /// 图片书 PDF 生成：网络图片走注入的 mock fetcher（含 JPEG 解码路径）
    #[test]
    fn test_export_pdf_images_network_mock() {
        let jpeg = make_jpeg_bytes();
        let png = make_png_bytes(32, 32, false);
        // move 闭包获取字节所有权，满足 ImageFetcher 的 'static 约束
        let fetcher: &ImageFetcher = &move |src: &str| match src {
            "https://cdn.example.com/1.jpg" => Ok(jpeg.clone()),
            "https://cdn.example.com/2.png" => Ok(png.clone()),
            _ => Err(format!("意外的图片源: {src}")),
        };

        let data = ExportData {
            title: "网络漫画".to_string(),
            author: "作者".to_string(),
            intro: Some("简介".to_string()),
            chapters: vec![
                ExportChapter {
                    index: 0,
                    title: "第1话".to_string(),
                    content: String::new(),
                    images: vec![
                        "https://cdn.example.com/1.jpg".to_string(),
                        "https://cdn.example.com/2.png".to_string(),
                    ],
                },
                ExportChapter {
                    index: 1,
                    title: "卷分隔（无图）".to_string(),
                    content: String::new(),
                    images: vec![],
                },
            ],
        };
        let mut config = default_config(ExportFormat::Pdf);
        config.include_toc = false;
        match BookExporter::export_with(&data, &config, Some(fetcher)) {
            Ok(bytes) => {
                assert_eq!(&bytes[0..4], b"%PDF");
                // 标题页 + 第1话（含 2 图）+ 卷页
                assert!(pdf_page_count(&bytes) >= 3);
            }
            Err(e) => {
                panic!("网络图片 PDF 导出失败: {e}");
            }
        }
    }

    /// 图片书 PDF：网络图片未注入 fetcher 时应返回明确错误
    #[test]
    fn test_export_pdf_images_missing_fetcher_error() {
        let data = ExportData {
            title: "漫画".to_string(),
            author: "作者".to_string(),
            intro: None,
            chapters: vec![ExportChapter {
                index: 0,
                title: "第1话".to_string(),
                content: String::new(),
                images: vec!["https://cdn.example.com/x.jpg".to_string()],
            }],
        };
        let config = default_config(ExportFormat::Pdf);
        match BookExporter::export_pdf(&data, &config) {
            Ok(_) => {
                // 无字体环境会先报字体错，此处不会 Ok；若 Ok 说明逻辑异常
                panic!("无 fetcher 时网络图片导出不应成功");
            }
            Err(e) => {
                // 可能是字体缺失（CI 环境）或 fetcher 缺失，两者都应是明确错误
                assert!(
                    e.contains("ImageFetcher") && e.contains("图片导出失败"),
                    "错误信息应明确: {e}"
                );
            }
        }
    }

    /// 图片书 PDF：损坏图片应返回带章节定位的错误而非 panic
    #[test]
    fn test_export_pdf_images_broken_image_error() {
        let dir = std::env::temp_dir();
        let path = dir.join(format!("legado_img_broken_{}.bin", std::process::id()));
        std::fs::write(&path, b"broken-image-bytes").unwrap();

        let data = ExportData {
            title: "漫画".to_string(),
            author: "作者".to_string(),
            intro: None,
            chapters: vec![ExportChapter {
                index: 0,
                title: "第1话".to_string(),
                content: String::new(),
                images: vec![path.to_string_lossy().to_string()],
            }],
        };
        let config = default_config(ExportFormat::Pdf);
        match BookExporter::export_pdf(&data, &config) {
            Ok(_) => panic!("损坏图片不应导出成功"),
            Err(e) => {
                assert!(
                    e.contains("图片导出失败") && e.contains("第1话"),
                    "错误应定位到图片或字体: {e}"
                );
            }
        }
        let _ = std::fs::remove_file(&path);
    }
}
