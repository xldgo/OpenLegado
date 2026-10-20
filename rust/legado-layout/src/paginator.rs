//! ReaderPaginator.kt 的纯数据移植；一块前瞻、逐行分页与延迟一页输出保持上游语义。
use crate::line_breaker::{BreakInput, break_lines, break_plain, forbidden_break};
use crate::model::*;
use crate::{LayoutError, Result};
use serde_json::json;
use std::collections::VecDeque;
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

struct Row {
    start: usize,
    end: usize,
    top: f32,
    bottom: f32,
    image: bool,
}
struct StoredPage {
    elements: Vec<Element>,
    text: String,
    extent: f32,
}
pub struct PaginationSession {
    config: Config,
    pages: VecDeque<StoredPage>,
    completed_pages: usize,
    emitted: usize,
    elements: Vec<Element>,
    text: String,
    y: f32,
    column: i32,
    column_start: usize,
    rows: Vec<Row>,
    centered_shift: f32,
    first_title_shift: f32,
    pending: Option<Block>,
    index: i32,
    finished: bool,
    cancellation: Option<Arc<AtomicBool>>,
}
impl PaginationSession {
    pub fn new(config: Config) -> Result<Self> {
        validate_config(&config)?;
        Ok(Self {
            y: config.padding_top_px,
            config,
            pages: VecDeque::new(),
            completed_pages: 0,
            emitted: 0,
            elements: vec![],
            text: String::new(),
            column: 0,
            column_start: 0,
            rows: vec![],
            centered_shift: 0.0,
            first_title_shift: 0.0,
            pending: None,
            index: -1,
            finished: false,
            cancellation: None,
        })
    }
    pub fn set_cancellation(&mut self, token: Arc<AtomicBool>) {
        self.cancellation = Some(token);
    }
    fn check_cancelled(&self) -> Result<()> {
        if self
            .cancellation
            .as_ref()
            .is_some_and(|t| t.load(Ordering::Acquire))
        {
            Err(LayoutError("会话已取消".into()))
        } else {
            Ok(())
        }
    }
    pub fn accept(&mut self, block: Block) -> Result<Vec<Page>> {
        self.check_cancelled()?;
        if self.finished {
            return Err(LayoutError("会话已结束".into()));
        }
        validate_block(&block)?;
        if let Some(previous) = self.pending.take() {
            self.process(previous, self.index, true, block.is_title())?;
        }
        self.index += 1;
        self.pending = Some(block);
        Ok(self.drain(false))
    }
    pub fn finish(&mut self) -> Result<Vec<Page>> {
        self.check_cancelled()?;
        if self.finished {
            return Err(LayoutError("会话已结束".into()));
        }
        if let Some(block) = self.pending.take() {
            self.process(block, self.index, false, false)?;
        }
        self.finished = true;
        if self.pages.is_empty() && self.elements.is_empty() {
            return Ok(vec![]);
        }
        self.finish_page();
        self.centered_shift = self.first_title_shift;
        Ok(self.drain(true))
    }
    fn center_first_title(&mut self) {
        if self.config.title_page_center_vertical && self.completed_pages == 1 {
            let page = &mut self.pages[0];
            let text: Vec<_> = page.elements.iter().filter(|e| e.kind == "text").collect();
            if !text.is_empty()
                && text
                    .iter()
                    .all(|e| e.text.as_ref().is_some_and(|t| t.emphasized))
            {
                let top = page
                    .elements
                    .iter()
                    .map(|e| e.bounds.top)
                    .fold(f32::INFINITY, f32::min);
                let bottom = page
                    .elements
                    .iter()
                    .map(|e| e.bounds.bottom)
                    .fold(f32::NEG_INFINITY, f32::max);
                let available = self.config.bottom() - self.config.padding_top_px;
                if bottom - top < available {
                    let dy = self.config.padding_top_px + (available - (bottom - top)) / 2.0 - top;
                    if dy != 0.0 {
                        for e in &mut page.elements {
                            e.shift(dy);
                        }
                        self.first_title_shift = dy;
                    }
                }
            }
        }
    }
    fn drain(&mut self, finish: bool) -> Vec<Page> {
        let end = if finish {
            self.pages.len()
        } else {
            self.pages.len().saturating_sub(1)
        };
        let mut result = Vec::with_capacity(end);
        for offset in 0..end {
            let page = self.pages.pop_front().expect("已定稿页面存在");
            result.push(self.build_page(page, self.emitted, finish && offset + 1 == end));
            self.emitted += 1;
        }
        result
    }
    fn build_page(&self, p: StoredPage, index: usize, last: bool) -> Page {
        let c = &self.config;
        let covered = p.extent + if last { self.centered_shift } else { 0.0 };
        let full = c.single_image_style && p.elements.iter().any(|e| e.kind != "image");
        let extent = if full {
            covered.max(c.bottom() - c.padding_top_px)
        } else {
            covered
        };
        Page {
            id: PageId {
                chapter_index: c.chapter_index,
                page_index: index,
            },
            chapter_title: c.chapter_title.clone(),
            text: p.text,
            width_px: c.viewport_width_px,
            height_px: c.viewport_height_px,
            content_top_px: c.padding_top_px,
            content_bottom_px: if c.continuous_scroll {
                c.bottom()
            } else {
                p.extent - c.padding_bottom_px
            },
            content_left_px: c.padding_left_px,
            content_right_px: c.viewport_width_px as f32 - c.padding_right_px,
            elements: p.elements,
            revision: c.revision,
            layout_revision: c.revision,
            scroll_extent_px: if !c.continuous_scroll {
                p.extent
            } else if last {
                extent + c.chapter_end_padding_px
            } else {
                extent
            },
            decoration: c.decoration.clone(),
            inline_images_preserve_scroll_line: c.inline_images_preserve_scroll_line,
            emphasis_underline_style: c.emphasis_underline_style.clone(),
        }
    }
    fn left(&self) -> f32 {
        self.config.padding_left_px + (self.column * self.config.stride()) as f32
    }
    fn has_content(&self) -> bool {
        self.elements.len() > self.column_start
    }
    fn row(&mut self, start: usize, top: f32, bottom: f32, image: bool) {
        self.rows.push(Row {
            start,
            end: self.elements.len(),
            top,
            bottom,
            image,
        });
    }
    fn justify_bottom(&mut self) -> f32 {
        if !self.config.text_bottom_justify || self.rows.len() <= 1 {
            return 0.0;
        }
        let last = self.rows.last().unwrap();
        if last.image {
            return 0.0;
        }
        let reserve = self.config.line_height_px * self.config.line_spacing_multiplier;
        if self.config.bottom() - (last.bottom + reserve) >= last.bottom - last.top {
            return 0.0;
        }
        let surplus = self.config.bottom() - last.bottom;
        if surplus <= 0.0 {
            return 0.0;
        }
        let gap = surplus / (self.rows.len() - 1) as f32;
        for (i, row) in self.rows.iter().enumerate().skip(1) {
            for e in &mut self.elements[row.start..row.end] {
                e.shift(gap * i as f32);
            }
        }
        surplus
    }
    fn finish_page(&mut self) {
        let shift = self.justify_bottom();
        if !self.elements.is_empty() {
            self.pages.push_back(StoredPage {
                elements: std::mem::take(&mut self.elements),
                text: std::mem::take(&mut self.text),
                extent: if self.config.continuous_scroll {
                    (self.y + shift - self.config.padding_top_px).max(0.0)
                } else {
                    self.config.viewport_height_px as f32
                },
            });
            self.completed_pages += 1;
            // 上游 finish 平移共享的第一页元素；这里在首次输出前生成同样的最终几何快照。
            self.center_first_title();
        }
        self.y = self.config.padding_top_px;
        self.column = 0;
        self.column_start = 0;
        self.rows.clear();
    }
    fn advance_column(&mut self) {
        if !self.has_content() {
            return;
        }
        if self.column + 1 < self.config.column_count {
            self.justify_bottom();
            self.column += 1;
            self.column_start = self.elements.len();
            self.rows.clear();
            self.y = self.config.padding_top_px;
        } else {
            self.finish_page();
        }
    }
    fn underline(&mut self, start: usize, bottom: f32) {
        let Some(u) = &self.config.page_underline else {
            return;
        };
        if self.elements.len() <= start {
            return;
        }
        let x = if u.extend_to_column {
            self.left()
        } else {
            self.elements[start..]
                .iter()
                .map(|e| e.bounds.left)
                .fold(f32::INFINITY, f32::min)
        };
        let right = if u.extend_to_column {
            self.left() + self.config.width()
        } else {
            self.elements[start..]
                .iter()
                .map(|e| e.bounds.right)
                .fold(f32::NEG_INFINITY, f32::max)
        };
        let y = bottom + u.offset_px;
        self.elements.push(Element::new("rule", Rect::new(x,y,right,y), json!({"colorArgb":u.color_argb,"widthPx":u.width_px,"dashed":u.dashed,"dashOnPx":u.dash_on_px,"dashOffPx":u.dash_off_px,"overlayStyledUnderline":true})));
    }
    fn process(
        &mut self,
        block: Block,
        index: i32,
        following: bool,
        next_title: bool,
    ) -> Result<()> {
        let title = block.is_title();
        let title_scale = if let Block::InlineParagraph(p) = &block {
            p.title_spacing_scale
        } else {
            1.0
        };
        if title && index == 0 {
            self.y += self.config.title_top_spacing_px;
        }
        match block {
            Block::Paragraph { value } => self.paragraph(&value, index, following)?,
            Block::InlineParagraph(p) => self.inline_paragraph(&p, index, following)?,
            Block::Image {
                source,
                intrinsic_width_px,
                intrinsic_height_px,
                chapter_position,
                action,
                horizontal_alignment,
                scale_mode,
                page_break_before,
                page_break_after,
            } => {
                if page_break_before {
                    self.advance_column();
                }
                let sw = intrinsic_width_px.max(1.0);
                let sh = intrinsic_height_px.max(1.0);
                let available = self.config.bottom() - self.config.padding_top_px;
                let single =
                    scale_mode == ImageScale::FitPage || page_break_before && page_break_after;
                let continuous =
                    self.config.continuous_scroll && scale_mode == ImageScale::FitWidth;
                let mut scale = if single {
                    (self.config.width() / sw).min(available / sh)
                } else if continuous {
                    self.config.width() / sw
                } else {
                    (self.config.width() / sw).min(available / sh)
                };
                if !single && !continuous && scale_mode == ImageScale::ContainNoUpscale {
                    scale = scale.min(1.0);
                }
                let width = sw * scale;
                let height = sh * scale;
                if (if continuous {
                    self.y > self.config.bottom()
                } else {
                    self.y + height > self.config.bottom()
                }) && self.has_content()
                {
                    self.advance_column();
                }
                if single {
                    self.y = self.config.padding_top_px + (available - height) / 2.0;
                }
                let x = self.left()
                    + match horizontal_alignment {
                        Alignment::Center => (self.config.width() - width) / 2.0,
                        Alignment::End => self.config.width() - width,
                        _ => 0.0,
                    };
                let start = self.elements.len();
                self.elements.push(Element::new("image",Rect::new(x,self.y,x+width,self.y+height),json!({"source":source,"action":action,"chapterPosition":chapter_position,"inline":false})));
                self.row(start, self.y, self.y + height, true);
                self.text.push('\u{fffc}');
                self.y += height + self.config.paragraph_spacing_px;
                if page_break_after {
                    self.advance_column();
                }
            }
            Block::BlankLine {
                chapter_position,
                line_height_px,
                line_spacing_multiplier,
            } => {
                if self.y + line_height_px > self.config.bottom() && self.has_content() {
                    self.advance_column();
                }
                let start = self.elements.len();
                self.elements.push(Element::new(
                    "spacer",
                    Rect::new(
                        self.left(),
                        self.y,
                        self.left() + self.config.width(),
                        self.y + line_height_px,
                    ),
                    json!({"chapterPosition":chapter_position,"paragraphIndex":index}),
                ));
                self.row(start, self.y, self.y + line_height_px, false);
                self.y += line_height_px * line_spacing_multiplier;
                if following {
                    self.text.push('\n');
                    self.y += self.config.paragraph_spacing_px;
                }
            }
            Block::Rule {
                color_argb,
                width_px,
                vertical_padding_px,
                dashed,
            } => {
                let required = vertical_padding_px * 2.0 + width_px;
                if self.y + required > self.config.bottom() && self.has_content() {
                    self.advance_column();
                }
                let y = self.y + vertical_padding_px;
                let start = self.elements.len();
                self.elements.push(Element::new("rule",Rect::new(self.left(),y,self.left()+self.config.width(),y+width_px),json!({"colorArgb":color_argb,"widthPx":width_px,"dashed":dashed,"dashOnPx":6.0,"dashOffPx":6.0,"overlayStyledUnderline":false})));
                self.row(start, y, y + width_px, false);
                self.y += required;
            }
            Block::PageBreak => self.advance_column(),
        }
        if title {
            self.y += if next_title {
                self.config.title_segment_spacing_px * title_scale
            } else {
                self.config.title_bottom_spacing_px
            };
        }
        Ok(())
    }
    fn paragraph(&mut self, p: &Paragraph, index: i32, following: bool) -> Result<()> {
        let text_style = Arc::new(p.style.clone());
        let c = &self.config;
        let height = p.line_height_px.unwrap_or(c.line_height_px);
        let spacing = p.letter_spacing_px.unwrap_or(c.letter_spacing_px);
        let indent = p
            .indent_width_px
            .unwrap_or((p.style.font_size_px + spacing) * p.indent_characters as f32);
        let baseline = p.baseline_offset_px.unwrap_or(c.baseline_offset_px);
        let ideograph = p
            .cluster_widths_px
            .iter()
            .copied()
            .find(|&v| v > 0.0)
            .unwrap_or(p.style.font_size_px);
        let breaker = if self.config.break_mode == BreakMode::Chinese {
            break_lines
        } else {
            break_plain
        };
        let b = breaker(&BreakInput {
            clusters: p.clusters.clone(),
            widths_px: p.cluster_widths_px.iter().map(|v| v + spacing).collect(),
            indent_characters: 0,
            width_px: c.width() as i32,
            ideograph_width_px: ideograph + spacing,
            letter_spacing_px: spacing,
            first_line_width_px: (c.width() - indent).max(0.0) as i32,
        })?;
        let mut offsets = vec![0];
        for cluster in &p.clusters {
            offsets.push(offsets.last().unwrap() + cluster.encode_utf16().count() as i32);
        }
        for line in 0..b.line_widths_px.len() {
            self.check_cancelled()?;
            if self.y + height > self.config.bottom() && self.has_content() {
                self.advance_column();
            }
            let from = b.line_cluster_starts[line];
            let until = b.line_cluster_starts[line + 1];
            let widths = &p.cluster_widths_px[from..until];
            let natural =
                widths.iter().sum::<f32>() + spacing * widths.len().saturating_sub(1) as f32;
            let indent = if line == 0 { indent } else { 0.0 };
            let available = (self.config.width() - indent).max(0.0);
            let gap = if p.alignment == Alignment::Justify
                && line + 1 < b.line_widths_px.len()
                && widths.len() > 1
            {
                ((available - natural) / (widths.len() - 1) as f32).max(0.0)
            } else {
                0.0
            };
            let mut x = self.left() + indent + alignment_offset(p.alignment, available, natural);
            let start = self.elements.len();
            for (i, offset) in offsets.iter().enumerate().take(until).skip(from) {
                let width = p.cluster_widths_px[i].max(0.0);
                self.elements.push(text_element(
                    Rect::new(x, self.y, x + width, self.y + height),
                    self.y + baseline,
                    &p.clusters[i],
                    text_style.clone(),
                    p.is_title,
                    p.link.as_deref(),
                    None,
                    p.chapter_position + offset,
                    index,
                    p.style.background_image.is_some() && i > from,
                    [0.0; 4],
                ));
                self.text.push_str(&p.clusters[i]);
                x += width + spacing + gap;
            }
            self.underline(start, self.y + height);
            self.row(start, self.y, self.y + height, false);
            self.y += height
                * p.line_spacing_multiplier
                    .unwrap_or(self.config.line_spacing_multiplier);
        }
        if following {
            self.text.push('\n');
            self.y += if p.is_title {
                self.config
                    .title_paragraph_spacing_px
                    .unwrap_or(self.config.paragraph_spacing_px)
            } else {
                self.config.paragraph_spacing_px
            };
        }
        Ok(())
    }
    fn inline_paragraph(&mut self, p: &InlineParagraph, index: i32, following: bool) -> Result<()> {
        let prepared = prepare_review(p, self.config.width(), self.config.letter_spacing_px)?;
        let p = prepared.as_ref().unwrap_or(p);
        let mut previous_style: Option<Arc<TextStyle>> = None;
        let styles: Vec<_> = p
            .items
            .iter()
            .map(|item| {
                item.style().map(|style| {
                    if previous_style
                        .as_ref()
                        .is_none_or(|previous| previous.as_ref() != style)
                    {
                        previous_style = Some(Arc::new(style.clone()));
                    }
                    previous_style.as_ref().unwrap().clone()
                })
            })
            .collect();

        if p.items.is_empty() {
            return Ok(());
        }
        let spacing = p.letter_spacing_px.unwrap_or(self.config.letter_spacing_px);
        let indent = p
            .indent_width_px
            .unwrap_or((p.base_text_size_px + spacing) * p.indent_characters as f32);
        let ideograph = p
            .items
            .iter()
            .filter_map(|item| {
                if let InlineItem::Text { width_px, .. } = item {
                    Some(*width_px)
                } else {
                    None
                }
            })
            .find(|&v| v > 0.0)
            .unwrap_or(p.line_height_px);
        let clusters: Vec<String> = p.items.iter().map(|i| i.cluster().into()).collect();
        let match_spacing: Vec<f32> = p
            .items
            .iter()
            .map(|i| {
                i.style().map_or(0.0, |s| {
                    s.match_spacing_before_px + s.match_spacing_after_px
                })
            })
            .collect();
        let breaker = if self.config.break_mode == BreakMode::Chinese {
            break_lines
        } else {
            break_plain
        };
        let b = breaker(&BreakInput {
            clusters: clusters.clone(),
            widths_px: p
                .items
                .iter()
                .enumerate()
                .map(|(i, item)| item.width() + spacing + match_spacing[i])
                .collect(),
            indent_characters: 0,
            width_px: (self.config.width() - p.rest_line_indent_width_px).max(0.0) as i32,
            ideograph_width_px: ideograph + spacing,
            letter_spacing_px: spacing,
            first_line_width_px: (self.config.width() - indent).max(0.0) as i32,
        })?;
        let original_ends = &b.line_cluster_starts[1..];
        let mut starts = vec![0];
        while *starts.last().unwrap() < p.items.len() {
            self.check_cancelled()?;
            let from = *starts.last().unwrap();
            let line_indent = if starts.len() == 1 {
                indent
            } else {
                p.rest_line_indent_width_px
            };
            let available = self.config.width() - line_indent;
            let mut until = original_ends
                .get(starts.len() - 1)
                .copied()
                .unwrap_or(p.items.len())
                .max(from + 1);
            while until - from > 1 {
                let occupied = (from..until)
                    .map(|i| (p.items[i].width() + match_spacing[i]) as f64)
                    .sum::<f64>() as f32
                    + spacing * (until - from - 1) as f32;
                if occupied <= available {
                    break;
                }
                let candidate = until - 1;
                if forbidden_break(&clusters[candidate - 1], &clusters[candidate]) {
                    break;
                }
                until = candidate;
            }
            starts.push(until);
        }
        // 段评扩展只修正最后边界；没有段评时逐项执行上游规则。
        if let Some(tail) = review_tail_start(p)
            && starts[starts.len() - 2] > tail
        {
            starts.retain(|&start| start <= tail);
            if *starts.last().unwrap() != tail {
                starts.push(tail);
            }
            starts.push(p.items.len());
        }
        for line in 0..starts.len() - 1 {
            self.check_cancelled()?;
            let from = starts[line];
            let until = starts[line + 1];
            let items = &p.items[from..until];
            let n = items.len();
            let mut text_scale = 1.0f32;
            let mut tallest = 0.0f32;
            let mut marker_color = None;
            let mut width_sum = 0.0f64;
            let mut match_sum = 0.0f64;
            let mut spaces = 0;
            let mut pad_top = 0.0f32;
            let mut pad_bottom = 0.0f32;
            for (j, item) in items.iter().enumerate() {
                width_sum += item.width() as f64;
                match_sum += match_spacing[from + j] as f64;
                if let InlineItem::Text { value, style, .. } = item {
                    text_scale = text_scale.max(style.font_size_px / p.base_text_size_px.max(1.0));
                    if marker_color.is_none() {
                        marker_color = Some(style.color_argb);
                    }
                    if value == " " {
                        spaces += 1;
                    }
                    pad_top = pad_top.max(style.line_pad_top_px);
                    pad_bottom = pad_bottom.max(style.line_pad_bottom_px);
                } else {
                    tallest = tallest.max(item.height());
                }
            }
            let fallback_height = p.line_height_px * text_scale;
            let fallback_baseline = p.baseline_offset_px * text_scale;
            let mut ascent = f32::NEG_INFINITY;
            let mut descent = f32::NEG_INFINITY;
            for item in items {
                if let InlineItem::Text {
                    line_height_px,
                    baseline_offset_px,
                    baseline_shift_px,
                    ..
                } = item
                {
                    ascent = ascent
                        .max(baseline_offset_px.unwrap_or(fallback_baseline) - baseline_shift_px);
                    descent = descent.max(
                        line_height_px.unwrap_or(fallback_height)
                            - baseline_offset_px.unwrap_or(fallback_baseline)
                            + baseline_shift_px,
                    );
                } else if let InlineItem::Review {
                    height_px,
                    baseline_offset_px,
                    ..
                } = item
                {
                    ascent = ascent.max(*baseline_offset_px);
                    descent = descent.max(height_px - baseline_offset_px);
                }
            }
            let line_ascent = fallback_baseline.max(ascent);
            let line_descent = (fallback_height - fallback_baseline).max(descent);
            let text_height = line_ascent + line_descent;
            let height = text_height.max(tallest);
            let baseline = line_ascent + (height - text_height) / 2.0;
            if self.y + pad_top + height + pad_bottom > self.config.bottom() && self.has_content() {
                self.advance_column();
            }
            self.y += pad_top;
            let indent = if line == 0 {
                indent
            } else {
                p.rest_line_indent_width_px
            };
            let available = (self.config.width() - indent).max(0.0);
            let natural =
                width_sum as f32 + spacing * n.saturating_sub(1) as f32 + match_sum as f32;
            let indent_items = p.leading_indent_items.saturating_sub(from).min(n);
            let gaps = n.saturating_sub(indent_items + 1);
            let residual = if p.alignment == Alignment::Justify && line + 1 < starts.len() - 1 {
                (available - natural).max(0.0)
            } else {
                0.0
            };
            let word_extra = if p.justify_at_word_boundaries && spaces > 1 {
                residual / spaces as f32
            } else {
                0.0
            };
            let gap = if word_extra == 0.0 && gaps > 0 {
                residual / gaps as f32
            } else {
                0.0
            };
            let mut x = self.left() + indent + alignment_offset(p.alignment, available, natural);
            let row_start = self.elements.len();
            for d in &p.decorations {
                let color = d.color_argb.unwrap_or(marker_color.unwrap_or(-16777216));
                let x = self.left()
                    + d.leading_offset_px
                    + match d.kind {
                        DecorationKind::Quote => d.size_px / 2.0,
                        DecorationKind::Bullet => d.size_px,
                    };
                match d.kind {
                    DecorationKind::Quote => self.elements.push(Element::new(
                        "paragraphMarker",
                        Rect::new(x, self.y, x, self.y + height),
                        json!({"colorArgb":color,"strokeWidthPx":d.size_px,"circular":false}),
                    )),
                    DecorationKind::Bullet if line == 0 => self.elements.push(Element::new(
                        "paragraphMarker",
                        Rect::new(x, self.y + height / 2.0, x, self.y + height / 2.0),
                        json!({"colorArgb":color,"strokeWidthPx":d.size_px*2.0,"circular":true}),
                    )),
                    _ => {}
                }
            }
            let underline_start = self.elements.len() + indent_items;
            let mut previous_background: Option<&BackgroundImage> = None;
            let mut previous_after = 0.0;
            for (j, item) in items.iter().enumerate() {
                let style = item.style();
                let before = style.map_or(0.0, |s| s.match_spacing_before_px);
                x += before;
                let background = style.and_then(|s| s.background_image.as_ref());
                match item {
                    InlineItem::Text {
                        value,
                        width_px,
                        chapter_position,
                        link,
                        marking_id,
                        baseline_shift_px,
                        ..
                    } => {
                        let extra = if value == " " { word_extra } else { 0.0 };
                        let continuous = background.is_some()
                            && j > 0
                            && previous_background == background
                            && before <= 0.0
                            && previous_after <= 0.0;
                        self.elements.push(text_element(
                            Rect::new(x, self.y, x + width_px + extra, self.y + height),
                            self.y + baseline + baseline_shift_px,
                            value,
                            styles[from + j].as_ref().unwrap().clone(),
                            p.emphasized,
                            link.as_deref(),
                            marking_id.as_deref(),
                            *chapter_position,
                            index,
                            continuous,
                            background.map_or([0.0; 4], |b| b.frame(height)),
                        ));
                        self.text.push_str(value);
                    }
                    InlineItem::Image {
                        source,
                        width_px,
                        height_px,
                        chapter_position,
                        action,
                        line_final_width_px,
                    } => {
                        let top = self.y + (height - height_px) / 2.0;
                        let width = if j + 1 == n {
                            line_final_width_px.unwrap_or(*width_px)
                        } else {
                            *width_px
                        };
                        self.elements.push(Element::new("image",Rect::new(x,top,x+width,top+height_px),json!({"source":source,"action":action,"chapterPosition":chapter_position,"inline":true})));
                        self.text.push('\u{fffc}');
                    }
                    InlineItem::RoleCast {
                        width_px,
                        height_px,
                        chapter_position,
                        raw,
                        name,
                        voice_pool_label,
                        quote_ordinal,
                        voice_effect_mark,
                    } => {
                        let top = self.y + (height - height_px) / 2.0;
                        let profile = self.config.cast_options.profiles.get(name);
                        self.elements.push(Element::new("roleCast",Rect::new(x,top,x+width_px,top+height_px),json!({"name":name,"voicePoolLabel":voice_pool_label,"avatarUri":profile.map_or("",|p|p.avatar_uri.as_str()),"assigned":!name.is_empty(),"voiceEffectMark":voice_effect_mark,"quoteOrdinal":quote_ordinal,"characterId":profile.map_or("",|p|p.character_id.as_str()),"chapterPosition":chapter_position})));
                        self.text.push_str(raw);
                    }
                    InlineItem::BgmScene {
                        width_px,
                        height_px,
                        chapter_position,
                        paragraph_index,
                        pool_name,
                        track_name,
                    } => {
                        let top = self.y + (height - height_px) / 2.0;
                        self.elements.push(Element::new("bgmScene",Rect::new(x,top,x+width_px,top+height_px),json!({"paragraphIndex":paragraph_index,"poolName":pool_name,"trackName":track_name,"chapterPosition":chapter_position})));
                    }
                    InlineItem::Review {
                        width_px,
                        height_px,
                        chapter_position,
                        paragraph_index,
                        review_key,
                        count,
                        baseline_offset_px,
                        ..
                    } => {
                        let top = self.y + baseline - baseline_offset_px;
                        self.elements.push(Element::new("review",Rect::new(x,top,x+width_px,top+height_px),json!({"paragraphIndex":paragraph_index,"chapterPosition":chapter_position,"reviewKey":review_key,"count":count,"baselinePx":top+baseline_offset_px,"textSizePx":height_px})));
                    }
                }
                x += item.width()
                    + spacing
                    + style.map_or(0.0, |s| s.match_spacing_after_px)
                    + if matches!(item,InlineItem::Text{value,..} if value==" ") {
                        word_extra
                    } else {
                        0.0
                    };
                x += if j >= indent_items { gap } else { 0.0 };
                if !matches!(
                    item,
                    InlineItem::RoleCast { .. }
                        | InlineItem::BgmScene { .. }
                        | InlineItem::Review { .. }
                ) {
                    previous_background = background;
                    previous_after = style.map_or(0.0, |s| s.match_spacing_after_px);
                }
            }
            self.underline(underline_start, self.y + height);
            self.row(row_start, self.y, self.y + height, false);
            let html = if p.justify_at_word_boundaries {
                self.config.html_line_spacing_add_px
            } else {
                0.0
            };
            self.y += pad_bottom
                + if html > 0.0 {
                    (height * p.line_spacing_multiplier + html) * p.line_spacing_multiplier
                } else {
                    height * p.line_spacing_multiplier
                };
        }
        if following {
            self.text.push('\n');
            self.y += if p.emphasized {
                self.config
                    .title_paragraph_spacing_px
                    .unwrap_or(self.config.paragraph_spacing_px)
                    * p.title_spacing_scale
            } else {
                self.config.paragraph_spacing_px
            };
        }
        Ok(())
    }
}
fn alignment_offset(a: Alignment, available: f32, natural: f32) -> f32 {
    match a {
        Alignment::Center => (available - natural).max(0.0) / 2.0,
        Alignment::End => (available - natural).max(0.0),
        _ => 0.0,
    }
}
fn review_tail_start(p: &InlineParagraph) -> Option<usize> {
    if !matches!(p.items.last(), Some(InlineItem::Review { .. })) {
        return None;
    }
    let mut start = p.items.len().checked_sub(2)?;
    while start > 0 && forbidden_break(p.items[start - 1].cluster(), p.items[start].cluster()) {
        start -= 1;
    }
    Some(start)
}
fn prepare_review(
    p: &InlineParagraph,
    width: f32,
    default_spacing: f32,
) -> Result<Option<InlineParagraph>> {
    if !p
        .items
        .iter()
        .any(|i| matches!(i, InlineItem::Review { .. }))
    {
        return Ok(None);
    }
    let mut prepared = p.clone();
    prepared
        .items
        .retain(|i| !matches!(i, InlineItem::Review { count: 0, .. }));
    if prepared.items.is_empty() {
        return Ok(Some(prepared));
    }
    if prepared
        .items
        .iter()
        .take(prepared.items.len() - 1)
        .any(|i| matches!(i, InlineItem::Review { .. }))
    {
        return Err(LayoutError("段评只允许放在段末".into()));
    }
    let Some(tail) = review_tail_start(&prepared) else {
        return Ok(Some(prepared));
    };
    if !prepared.items[tail..prepared.items.len() - 1]
        .iter()
        .any(|i| matches!(i,InlineItem::Text{value,..} if !value.is_empty()))
    {
        return Err(LayoutError("段评需要同段末正文一起布局".into()));
    }
    let spacing = prepared.letter_spacing_px.unwrap_or(default_spacing);
    let indent = if tail == 0 {
        prepared
            .indent_width_px
            .unwrap_or((prepared.base_text_size_px + spacing) * prepared.indent_characters as f32)
    } else {
        prepared.rest_line_indent_width_px
    };
    let occupied = |p: &InlineParagraph| {
        p.items[tail..]
            .iter()
            .map(|i| {
                i.width()
                    + i.style().map_or(0.0, |s| {
                        s.match_spacing_before_px + s.match_spacing_after_px
                    })
            })
            .map(f64::from)
            .sum::<f64>() as f32
            + spacing * (p.items.len() - tail - 1) as f32
    };
    if occupied(&prepared) > width - indent {
        if let Some(InlineItem::Review {
            width_px,
            height_px,
            baseline_offset_px,
            compact_width_px: Some(cw),
            compact_height_px: Some(ch),
            ..
        }) = prepared.items.last_mut()
        {
            let baseline_fraction = *baseline_offset_px / *height_px;
            *width_px = *cw;
            *height_px = *ch;
            *baseline_offset_px = *ch * baseline_fraction;
        }
        if occupied(&prepared) > width - indent {
            return Err(LayoutError("阅读区域太窄，无法容纳正文与段评".into()));
        }
    }
    Ok(Some(prepared))
}
#[allow(clippy::too_many_arguments)]
fn text_element(
    bounds: Rect,
    baseline: f32,
    value: &str,
    style: Arc<TextStyle>,
    emphasized: bool,
    link: Option<&str>,
    marking: Option<&str>,
    position: i32,
    paragraph: i32,
    background_run: bool,
    frame: [f32; 4],
) -> Element {
    Element {
        kind: "text".into(),
        bounds,
        data: Default::default(),
        text: Some(Box::new(TextElementData {
            baseline_px: baseline,
            value: value.into(),
            style,
            selected: false,
            emphasized,
            read_aloud: false,
            search_result: false,
            emphasis_underline: None,
            link: link.map(str::to_owned),
            marking_id: marking.map(str::to_owned),
            chapter_position: position,
            paragraph_index: paragraph,
            background_frame_top_px: frame[0],
            background_frame_bottom_px: frame[1],
            background_frame_left_px: frame[2],
            background_frame_right_px: frame[3],
            continues_background_run: background_run,
        })),
    }
}
pub fn paginate(blocks: Vec<Block>, config: Config) -> Result<Vec<Page>> {
    let mut session = PaginationSession::new(config)?;
    let mut pages = vec![];
    for block in blocks {
        pages.extend(session.accept(block)?);
    }
    pages.extend(session.finish()?);
    Ok(pages)
}

fn finite(value: f32, field: &str) -> Result<()> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(LayoutError(format!("{field} 不是有限值")))
    }
}
fn positive(value: f32, field: &str) -> Result<()> {
    finite(value, field)?;
    if value > 0.0 {
        Ok(())
    } else {
        Err(LayoutError(format!("{field} 必须大于零")))
    }
}
pub fn validate_config(c: &Config) -> Result<()> {
    if !(1..=2).contains(&c.column_count) || c.viewport_width_px <= 0 || c.viewport_height_px <= 0 {
        return Err(LayoutError("视口无效或分栏不在 1..2".into()));
    }
    // 直接校验类型中的浮点数；serde_json 将 NaN 转 null，不能用序列化检查代替。
    for value in [
        c.padding_left_px,
        c.padding_top_px,
        c.padding_right_px,
        c.padding_bottom_px,
        c.line_height_px,
        c.baseline_offset_px,
        c.paragraph_spacing_px,
        c.letter_spacing_px,
        c.title_top_spacing_px,
        c.title_bottom_spacing_px,
        c.title_segment_spacing_px,
        c.line_spacing_multiplier,
        c.chapter_end_padding_px,
        c.html_line_spacing_add_px,
    ] {
        finite(value, "config")?;
    }
    if let Some(value) = c.title_paragraph_spacing_px {
        finite(value, "titleParagraphSpacingPx")?;
    }
    if let Some(u) = &c.page_underline {
        for v in [u.width_px, u.offset_px, u.dash_on_px, u.dash_off_px] {
            finite(v, "pageUnderline")?;
        }
    }
    positive(c.line_height_px, "lineHeightPx")?;
    positive(c.line_spacing_multiplier, "lineSpacingMultiplier")?;
    if c.width() <= 0.0 || c.bottom() <= c.padding_top_px {
        return Err(LayoutError("内容区没有可用尺寸".into()));
    }
    Ok(())
}
fn validate_style(s: &TextStyle) -> Result<()> {
    positive(s.font_size_px, "fontSizePx")?;
    for v in [
        s.match_spacing_before_px,
        s.match_spacing_after_px,
        s.line_pad_top_px,
        s.line_pad_bottom_px,
    ] {
        finite(v, "style")?;
    }
    if let Some(b) = &s.background_image {
        for v in [
            b.scale,
            b.nine_patch_left,
            b.nine_patch_right,
            b.nine_patch_top,
            b.nine_patch_bottom,
            b.length_offset_left_px,
            b.length_offset_right_px,
            b.content_inset_left_px,
            b.content_inset_right_px,
            b.content_inset_top_px,
            b.content_inset_bottom_px,
            b.content_band_height_px,
        ] {
            finite(v, "backgroundImage")?;
        }
    }
    Ok(())
}
pub fn validate_block(b: &Block) -> Result<()> {
    match b {
        Block::Paragraph { value: p } => {
            if p.clusters.len() != p.cluster_widths_px.len() || p.clusters.concat() != p.text {
                return Err(LayoutError("正文簇、宽度或原文不匹配".into()));
            }
            if p.chapter_position < 0 || p.indent_characters < 0 {
                return Err(LayoutError("正文位置或缩进为负".into()));
            }
            for w in &p.cluster_widths_px {
                finite(*w, "clusterWidthsPx")?;
            }
            validate_style(&p.style)?;
            if let Some(h) = p.line_height_px {
                positive(h, "lineHeightPx")?;
            }
            if let Some(m) = p.line_spacing_multiplier {
                positive(m, "lineSpacingMultiplier")?;
            }
            for v in [p.baseline_offset_px, p.letter_spacing_px, p.indent_width_px]
                .into_iter()
                .flatten()
            {
                finite(v, "paragraph")?;
            }
            if p.chapter_position as usize + p.text.encode_utf16().count() > i32::MAX as usize {
                return Err(LayoutError("原文位置超出 i32".into()));
            }
        }
        Block::InlineParagraph(p) => {
            positive(p.line_height_px, "lineHeightPx")?;
            positive(p.base_text_size_px, "baseTextSizePx")?;
            positive(p.line_spacing_multiplier, "lineSpacingMultiplier")?;
            for v in [
                p.baseline_offset_px,
                p.title_spacing_scale,
                p.rest_line_indent_width_px,
            ] {
                finite(v, "inlineParagraph")?;
            }
            for v in [p.letter_spacing_px, p.indent_width_px]
                .into_iter()
                .flatten()
            {
                finite(v, "inlineParagraph")?;
            }
            if p.indent_characters < 0 {
                return Err(LayoutError("行内缩进为负".into()));
            }
            for d in &p.decorations {
                finite(d.size_px, "decoration")?;
                finite(d.leading_offset_px, "decoration")?;
            }
            for i in &p.items {
                finite(i.width(), "widthPx")?;
                finite(i.height(), "heightPx")?;
                match i {
                    InlineItem::Text {
                        value,
                        chapter_position,
                        style,
                        line_height_px,
                        baseline_offset_px,
                        baseline_shift_px,
                        ..
                    } => {
                        validate_style(style)?;
                        for v in [
                            *line_height_px,
                            *baseline_offset_px,
                            Some(*baseline_shift_px),
                        ]
                        .into_iter()
                        .flatten()
                        {
                            finite(v, "inlineText")?;
                        }
                        if *chapter_position < 0
                            || *chapter_position as usize + value.encode_utf16().count()
                                > i32::MAX as usize
                        {
                            return Err(LayoutError("行内原文位置无效".into()));
                        }
                    }
                    InlineItem::Image {
                        line_final_width_px: Some(v),
                        ..
                    } => {
                        finite(*v, "lineFinalWidthPx")?;
                    }
                    InlineItem::Review {
                        height_px,
                        baseline_offset_px,
                        compact_width_px,
                        compact_height_px,
                        ..
                    } => {
                        positive(*height_px, "reviewHeight")?;
                        finite(*baseline_offset_px, "review")?;
                        for v in [*compact_width_px, *compact_height_px]
                            .into_iter()
                            .flatten()
                        {
                            positive(v, "compactReview")?;
                        }
                    }
                    _ => {}
                }
            }
        }
        Block::BlankLine {
            line_height_px,
            line_spacing_multiplier,
            ..
        } => {
            positive(*line_height_px, "lineHeightPx")?;
            positive(*line_spacing_multiplier, "lineSpacingMultiplier")?;
        }
        Block::Image {
            intrinsic_width_px,
            intrinsic_height_px,
            ..
        } => {
            finite(*intrinsic_width_px, "imageWidth")?;
            finite(*intrinsic_height_px, "imageHeight")?;
        }
        Block::Rule {
            width_px,
            vertical_padding_px,
            ..
        } => {
            finite(*width_px, "rule")?;
            finite(*vertical_padding_px, "rule")?;
        }
        _ => {}
    }
    Ok(())
}

#[cfg(test)]
mod ownership_tests {
    use super::*;
    use serde_json::json;

    fn config() -> Config {
        serde_json::from_value(json!({"chapterIndex":0,"chapterTitle":"测试","viewportWidthPx":64,"viewportHeightPx":40,"paddingLeftPx":0,"paddingTopPx":0,"paddingRightPx":0,"paddingBottomPx":0,"lineHeightPx":20,"baselineOffsetPx":15})).unwrap()
    }
    #[test]
    fn emitted_pages_do_not_accumulate_in_session() {
        let mut session = PaginationSession::new(config()).unwrap();
        let mut emitted = 0;
        for i in 0..120 {
            let block = serde_json::from_value(json!({"type":"paragraph","value":{"text":"甲乙丙丁戊己庚辛","clusters":["甲","乙","丙","丁","戊","己","庚","辛"],"clusterWidthsPx":[16,16,16,16,16,16,16,16],"style":{"colorArgb":-1,"fontSizePx":16},"chapterPosition":i*8}})).unwrap();
            for page in session.accept(block).unwrap() {
                assert_eq!(page.id.page_index, emitted);
                emitted += 1;
            }
            assert!(session.pages.len() <= 1, "只保留上游要求的延迟页");
        }
        for page in session.finish().unwrap() {
            assert_eq!(page.id.page_index, emitted);
            emitted += 1;
        }
        assert!(emitted > 100);
        assert!(session.pages.is_empty());
    }
    #[test]
    fn page_transfer_keeps_original_allocations() {
        let session = PaginationSession::new(config()).unwrap();
        let mut elements = Vec::with_capacity(32);
        elements.push(Element {
            kind: "blankLine".into(),
            bounds: Rect {
                left: 0.0,
                top: 0.0,
                right: 64.0,
                bottom: 20.0,
            },
            text: None,
            data: Default::default(),
        });
        let text = String::from("转移页面原始数据");
        let element_pointer = elements.as_ptr();
        let text_pointer = text.as_ptr();
        let page = session.build_page(
            StoredPage {
                elements,
                text,
                extent: 20.0,
            },
            9,
            false,
        );
        assert_eq!(page.id.page_index, 9);
        assert_eq!(page.elements.as_ptr(), element_pointer);
        assert_eq!(page.text.as_ptr(), text_pointer);
    }
}
