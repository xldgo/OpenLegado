//! PDF 专用排版：只负责文档文本、章节和图片，不复用阅读器的交互布局。
use super::*;
use printpdf::{
    FontId, Mm, Op, ParsedFont, PdfDocument, PdfFontHandle, PdfPage, PdfSaveOptions, Point, Pt,
    RawImage, RawImageData, RawImageFormat, TextItem, XObjectTransform,
};

const PAGE_WIDTH: f32 = 210.0 * 72.0 / 25.4;
const PAGE_HEIGHT: f32 = 297.0 * 72.0 / 25.4;
const MARGIN: f32 = 18.0 * 72.0 / 25.4;
const CONTENT_WIDTH: f32 = PAGE_WIDTH - 2.0 * MARGIN;

struct Writer {
    document: PdfDocument,
    fonts: [ParsedFont; 2],
    ids: [FontId; 2],
    pages: Vec<PdfPage>,
    operations: Vec<Op>,
    top: f32,
}

impl Writer {
    fn new(title: &str) -> Result<Self, String> {
        let regular = load_pdf_font(&pdf_regular_candidates())?;
        let bold = load_pdf_font(&pdf_bold_candidates()).unwrap_or_else(|_| regular.clone());
        let mut document = PdfDocument::new(title);
        let ids = [document.add_font(&regular), document.add_font(&bold)];
        Ok(Self {
            document,
            fonts: [regular, bold],
            ids,
            pages: Vec::new(),
            operations: Vec::new(),
            top: PAGE_HEIGHT - MARGIN,
        })
    }

    fn next_page(&mut self) {
        if !self.operations.is_empty() {
            self.pages.push(PdfPage::new(
                Mm(210.0),
                Mm(297.0),
                std::mem::take(&mut self.operations),
            ));
        }
        self.top = PAGE_HEIGHT - MARGIN;
    }

    fn width(&self, text: &str, size: f32, face: usize) -> Result<f32, String> {
        let font = &self.fonts[face];
        let mut width = 0.0;
        for c in text.chars() {
            let gid = font
                .lookup_glyph_index(c as u32)
                .filter(|&id| id != 0)
                .ok_or_else(|| format!("PDF 字体不包含字符 {c}（U+{:04X}）", c as u32))?;
            let advance = font
                .get_glyph_width(gid)
                .ok_or_else(|| format!("PDF 字体缺少字形度量: {c}"))?;
            width += advance as f32 * size / font.units_per_em as f32;
        }
        Ok(width)
    }

    fn line(&mut self, text: &str, size: f32, face: usize, centered: bool) -> Result<(), String> {
        let font = &self.fonts[face];
        let ascent = font.font_metrics.ascent as f32 / font.units_per_em as f32 * size;
        let descent = -(font.font_metrics.descent as f32) / font.units_per_em as f32 * size;
        let height = (ascent + descent).max(size * 1.5);
        if self.top - height < MARGIN {
            self.next_page();
        }
        let width = self.width(text, size, face)?;
        if width > CONTENT_WIDTH + 0.01 {
            return Err("PDF 行宽超出页面内容区".into());
        }
        let x = MARGIN
            + if centered {
                (CONTENT_WIDTH - width).max(0.0) / 2.0
            } else {
                0.0
            };
        self.operations.extend([
            Op::StartTextSection,
            Op::SetFont {
                font: PdfFontHandle::External(self.ids[face].clone()),
                size: Pt(size),
            },
            Op::SetTextCursor {
                pos: Point {
                    x: Pt(x),
                    y: Pt(self.top - ascent),
                },
            },
            Op::ShowText {
                items: vec![TextItem::Text(text.to_string())],
            },
            Op::EndTextSection,
        ]);
        self.top -= height;
        Ok(())
    }

    fn paragraph(
        &mut self,
        text: &str,
        size: f32,
        face: usize,
        centered: bool,
        indent: bool,
    ) -> Result<(), String> {
        for paragraph in text.split('\n').map(str::trim).filter(|s| !s.is_empty()) {
            let mut line = if indent {
                "\u{3000}\u{3000}".to_string()
            } else {
                String::new()
            };
            for c in paragraph.chars() {
                let c = if c == '\t' { ' ' } else { c };
                let mut candidate = line.clone();
                candidate.push(c);
                if self.width(&candidate, size, face)? > CONTENT_WIDTH {
                    if line.is_empty() {
                        return Err("PDF 单个字符超出页面宽度".into());
                    }
                    // 英文优先回退到已有空格，超长词再按字符续行。
                    if let Some(pos) = line.rfind(' ').filter(|&pos| pos > 0) {
                        let tail = line[pos + 1..].to_string();
                        self.line(&line[..pos], size, face, centered)?;
                        line = tail;
                        if self.width(&format!("{line}{c}"), size, face)? > CONTENT_WIDTH {
                            self.line(&line, size, face, centered)?;
                            line.clear();
                        }
                    } else {
                        self.line(&line, size, face, centered)?;
                        line.clear();
                    }
                }
                line.push(c);
            }
            if !line.is_empty() {
                self.line(&line, size, face, centered)?;
            }
            self.top -= size * 0.3;
        }
        Ok(())
    }

    fn image(&mut self, bytes: &[u8]) -> Result<(), String> {
        let image = decode_pdf_image(bytes)?;
        let (width, height) = image.dimensions();
        let scale = image_fit_scale(width, height) as f32;
        let w = width as f32 * 72.0 / 300.0 * scale;
        let h = height as f32 * 72.0 / 300.0 * scale;
        if self.top - h < MARGIN {
            self.next_page();
        }
        let (pixels, data_format) = match image {
            image::DynamicImage::ImageLuma8(p) => {
                (RawImageData::U8(p.into_raw()), RawImageFormat::R8)
            }
            image::DynamicImage::ImageLuma16(p) => {
                (RawImageData::U16(p.into_raw()), RawImageFormat::R16)
            }
            image::DynamicImage::ImageRgb16(p) => {
                (RawImageData::U16(p.into_raw()), RawImageFormat::RGB16)
            }
            other => (
                RawImageData::U8(other.into_rgb8().into_raw()),
                RawImageFormat::RGB8,
            ),
        };
        let id = self.document.add_image(&RawImage {
            pixels,
            width: width as usize,
            height: height as usize,
            data_format,
            tag: Vec::new(),
        });
        self.operations.push(Op::UseXobject {
            id,
            transform: XObjectTransform {
                translate_x: Some(Pt(MARGIN + (CONTENT_WIDTH - w) / 2.0)),
                translate_y: Some(Pt(self.top - h)),
                scale_x: Some(scale),
                scale_y: Some(scale),
                dpi: Some(300.0),
                ..Default::default()
            },
        });
        self.top -= h + 6.0;
        Ok(())
    }

    fn finish(mut self) -> Result<Vec<u8>, String> {
        self.next_page();
        let mut warnings = Vec::new();
        let options = PdfSaveOptions {
            image_optimization: None,
            ..Default::default()
        };
        let bytes = self
            .document
            .with_pages(self.pages)
            .save(&options, &mut warnings);
        if let Some(error) = warnings
            .iter()
            .find(|w| w.severity == printpdf::PdfParseErrorSeverity::Error)
        {
            return Err(format!("PDF 渲染失败: {}", error.msg));
        }
        Ok(bytes)
    }
}

pub(super) fn export(
    data: &ExportData,
    config: &ExportConfig,
    fetcher: Option<&ImageFetcher>,
) -> Result<Vec<u8>, String> {
    let mut writer = Writer::new(&data.title)?;
    writer.paragraph(&data.title, 22.0, 1, true, false)?;
    writer.paragraph(&format!("作者：{}", data.author), 11.0, 0, true, false)?;
    if let Some(intro) = &data.intro {
        writer.paragraph(&format!("简介：{intro}"), 10.0, 0, false, false)?;
    }
    if config.include_toc && !data.chapters.is_empty() {
        writer.next_page();
        writer.paragraph("目录", 18.0, 1, false, false)?;
        for chapter in &data.chapters {
            writer.paragraph(&chapter.title, 11.0, 0, false, false)?;
        }
    }
    for chapter in &data.chapters {
        writer.next_page();
        writer.paragraph(&chapter.title, 16.0, 1, false, false)?;
        let content = if chapter.images.is_empty() {
            std::borrow::Cow::Borrowed(chapter.content.as_str())
        } else {
            IMG_SRC_RE.replace_all(&chapter.content, "")
        };
        writer.paragraph(&content, 12.0, 0, false, true)?;
        for (index, source) in chapter.images.iter().enumerate() {
            let bytes = fetch_image_bytes(source, fetcher).map_err(|e| {
                format!(
                    "图片导出失败：章节「{}」第 {} 张图片获取失败: {e}",
                    chapter.title,
                    index + 1
                )
            })?;
            writer.image(&bytes).map_err(|e| {
                format!(
                    "图片导出失败：章节「{}」第 {} 张图片: {e}",
                    chapter.title,
                    index + 1
                )
            })?;
        }
    }
    writer.finish()
}
