//! 无平台内容模型；字段对应上游已测量块，不持有字体或图片运行时对象。
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;
use std::sync::Arc;

fn one() -> f32 {
    1.0
}
fn yes() -> bool {
    true
}
fn sans() -> String {
    "sans-serif".into()
}
fn weight() -> i32 {
    400
}
fn six() -> f32 {
    6.0
}

#[derive(Debug, Clone, Copy, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum Alignment {
    #[default]
    Start,
    Center,
    End,
    Justify,
}
#[derive(Debug, Clone, Copy, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum ImageScale {
    #[default]
    ContainNoUpscale,
    FitWidth,
    FitPage,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum BreakMode {
    #[default]
    Chinese,
    Plain,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Rect {
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}
impl Rect {
    pub fn new(left: f32, top: f32, right: f32, bottom: f32) -> Self {
        Self {
            left,
            top,
            right,
            bottom,
        }
    }
    pub fn shift(&mut self, dy: f32) {
        self.top += dy;
        self.bottom += dy;
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BackgroundImage {
    pub source: String,
    pub fit: i32,
    pub scale: f32,
    #[serde(default = "tenth")]
    pub nine_patch_left: f32,
    #[serde(default = "tenth")]
    pub nine_patch_right: f32,
    #[serde(default = "tenth")]
    pub nine_patch_top: f32,
    #[serde(default = "tenth")]
    pub nine_patch_bottom: f32,
    #[serde(default)]
    pub length_offset_left_px: f32,
    #[serde(default)]
    pub length_offset_right_px: f32,
    #[serde(default)]
    pub content_inset_left_px: f32,
    #[serde(default)]
    pub content_inset_right_px: f32,
    #[serde(default)]
    pub content_inset_top_px: f32,
    #[serde(default)]
    pub content_inset_bottom_px: f32,
    #[serde(default)]
    pub content_band_height_px: f32,
}
fn tenth() -> f32 {
    0.1
}
impl BackgroundImage {
    pub fn frame(&self, height: f32) -> [f32; 4] {
        if self.fit != 3 {
            return [0.0; 4];
        }
        let size = self.scale.clamp(0.1, 5.0);
        let factor = if self.content_band_height_px > 0.0 && height > 0.0 {
            height * size / self.content_band_height_px
        } else {
            1.0
        };
        let overhang = height * (size - 1.0) / 2.0;
        [
            overhang + self.content_inset_top_px * factor,
            overhang + self.content_inset_bottom_px * factor,
            self.content_inset_left_px * factor,
            self.content_inset_right_px * factor,
        ]
    }
}

fn is_false(value: &bool) -> bool {
    !value
}

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TextStyle {
    pub color_argb: i32,
    #[serde(default, skip_serializing_if = "is_false")]
    pub inherit_color: bool,
    pub font_size_px: f32,
    #[serde(default)]
    pub font_path: String,
    #[serde(default = "weight")]
    pub font_weight: i32,
    #[serde(default)]
    pub italic: bool,
    #[serde(default)]
    pub background_argb: Option<i32>,
    #[serde(default)]
    pub underline: Option<Value>,
    #[serde(default)]
    pub shadow: Option<Value>,
    #[serde(default)]
    pub background_image: Option<BackgroundImage>,
    #[serde(default = "sans")]
    pub font_family: String,
    #[serde(default)]
    pub linear_text: bool,
    #[serde(default)]
    pub strike_through: bool,
    #[serde(default)]
    pub native_underline: bool,
    #[serde(default)]
    pub match_spacing_before_px: f32,
    #[serde(default)]
    pub match_spacing_after_px: f32,
    #[serde(default)]
    pub line_pad_top_px: f32,
    #[serde(default)]
    pub line_pad_bottom_px: f32,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PageUnderline {
    pub color_argb: i32,
    pub width_px: f32,
    pub offset_px: f32,
    pub extend_to_column: bool,
    pub dashed: bool,
    #[serde(default = "six")]
    pub dash_on_px: f32,
    #[serde(default = "six")]
    pub dash_off_px: f32,
}
#[derive(Debug, Clone, Deserialize, Serialize, Default)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CastOptions {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub profiles: BTreeMap<String, CastProfile>,
    #[serde(default)]
    pub chapter_effects: BTreeMap<i32, String>,
    #[serde(default)]
    pub character_effects: BTreeMap<String, String>,
    #[serde(default)]
    pub bubbles: BTreeMap<String, Value>,
}
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CastProfile {
    pub character_id: String,
    pub avatar_uri: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Config {
    #[serde(default)]
    pub break_mode: BreakMode,
    pub chapter_index: i32,
    pub chapter_title: String,
    pub viewport_width_px: i32,
    pub viewport_height_px: i32,
    pub padding_left_px: f32,
    pub padding_top_px: f32,
    pub padding_right_px: f32,
    pub padding_bottom_px: f32,
    pub line_height_px: f32,
    pub baseline_offset_px: f32,
    #[serde(default)]
    pub paragraph_spacing_px: f32,
    #[serde(default)]
    pub letter_spacing_px: f32,
    #[serde(default)]
    pub revision: i64,
    #[serde(default = "default_decoration")]
    pub decoration: Value,
    #[serde(default)]
    pub title_top_spacing_px: f32,
    #[serde(default)]
    pub title_bottom_spacing_px: f32,
    #[serde(default)]
    pub title_paragraph_spacing_px: Option<f32>,
    #[serde(default)]
    pub title_segment_spacing_px: f32,
    #[serde(default)]
    pub title_page_center_vertical: bool,
    #[serde(default = "one_column")]
    pub column_count: i32,
    #[serde(default = "one")]
    pub line_spacing_multiplier: f32,
    #[serde(default)]
    pub continuous_scroll: bool,
    #[serde(default)]
    pub single_image_style: bool,
    #[serde(default)]
    pub chapter_end_padding_px: f32,
    #[serde(default)]
    pub text_bottom_justify: bool,
    #[serde(default)]
    pub html_line_spacing_add_px: f32,
    #[serde(default)]
    pub page_underline: Option<PageUnderline>,
    #[serde(default = "yes")]
    pub inline_images_preserve_scroll_line: bool,
    #[serde(default)]
    pub emphasis_underline_style: Option<Value>,
    #[serde(default)]
    pub cast_options: CastOptions,
}
fn default_decoration() -> Value {
    serde_json::json!({"header":null,"footer":null,"bookmarkBadge":null})
}
fn one_column() -> i32 {
    1
}
impl Config {
    pub fn stride(&self) -> i32 {
        self.viewport_width_px / self.column_count
    }
    pub fn width(&self) -> f32 {
        (self.stride() as f32 - self.padding_left_px - self.padding_right_px).max(0.0)
    }
    pub fn bottom(&self) -> f32 {
        (self.viewport_height_px as f32 - self.padding_bottom_px).max(self.padding_top_px)
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Paragraph {
    pub text: String,
    pub clusters: Vec<String>,
    pub cluster_widths_px: Vec<f32>,
    pub style: TextStyle,
    pub chapter_position: i32,
    #[serde(default)]
    pub indent_characters: i32,
    #[serde(default)]
    pub alignment: Alignment,
    #[serde(default)]
    pub is_title: bool,
    #[serde(default)]
    pub link: Option<String>,
    #[serde(default)]
    pub line_height_px: Option<f32>,
    #[serde(default)]
    pub baseline_offset_px: Option<f32>,
    #[serde(default)]
    pub line_spacing_multiplier: Option<f32>,
    #[serde(default)]
    pub letter_spacing_px: Option<f32>,
    #[serde(default)]
    pub indent_width_px: Option<f32>,
}
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct InlineParagraph {
    pub items: Vec<InlineItem>,
    pub indent_characters: i32,
    pub alignment: Alignment,
    pub line_height_px: f32,
    pub baseline_offset_px: f32,
    pub base_text_size_px: f32,
    #[serde(default)]
    pub emphasized: bool,
    #[serde(default = "one")]
    pub title_spacing_scale: f32,
    #[serde(default = "one")]
    pub line_spacing_multiplier: f32,
    #[serde(default)]
    pub letter_spacing_px: Option<f32>,
    #[serde(default)]
    pub indent_width_px: Option<f32>,
    #[serde(default)]
    pub rest_line_indent_width_px: f32,
    #[serde(default)]
    pub leading_indent_items: usize,
    #[serde(default)]
    pub decorations: Vec<ParagraphDecoration>,
    #[serde(default)]
    pub justify_at_word_boundaries: bool,
}
#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum DecorationKind {
    Quote,
    Bullet,
}
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ParagraphDecoration {
    pub kind: DecorationKind,
    pub color_argb: Option<i32>,
    pub size_px: f32,
    #[serde(default)]
    pub leading_offset_px: f32,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
pub enum Block {
    Paragraph {
        value: Box<Paragraph>,
    },
    InlineParagraph(InlineParagraph),
    Image {
        source: String,
        intrinsic_width_px: f32,
        intrinsic_height_px: f32,
        chapter_position: i32,
        #[serde(default)]
        action: Option<String>,
        #[serde(default = "center")]
        horizontal_alignment: Alignment,
        #[serde(default)]
        scale_mode: ImageScale,
        #[serde(default)]
        page_break_before: bool,
        #[serde(default)]
        page_break_after: bool,
    },
    BlankLine {
        chapter_position: i32,
        line_height_px: f32,
        line_spacing_multiplier: f32,
    },
    Rule {
        color_argb: i32,
        width_px: f32,
        vertical_padding_px: f32,
        #[serde(default)]
        dashed: bool,
    },
    PageBreak,
}
fn center() -> Alignment {
    Alignment::Center
}
impl Block {
    pub fn is_title(&self) -> bool {
        match self {
            Self::Paragraph { value } => value.is_title,
            Self::InlineParagraph(p) => p.emphasized,
            _ => false,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
pub enum InlineItem {
    Text {
        value: String,
        width_px: f32,
        style: Box<TextStyle>,
        chapter_position: i32,
        #[serde(default)]
        link: Option<String>,
        #[serde(default)]
        marking_id: Option<String>,
        #[serde(default)]
        line_height_px: Option<f32>,
        #[serde(default)]
        baseline_offset_px: Option<f32>,
        #[serde(default)]
        baseline_shift_px: f32,
    },
    Image {
        source: String,
        width_px: f32,
        height_px: f32,
        chapter_position: i32,
        #[serde(default)]
        action: Option<String>,
        #[serde(default)]
        line_final_width_px: Option<f32>,
    },
    RoleCast {
        width_px: f32,
        height_px: f32,
        chapter_position: i32,
        raw: String,
        name: String,
        voice_pool_label: String,
        quote_ordinal: i32,
        #[serde(default)]
        voice_effect_mark: bool,
    },
    BgmScene {
        width_px: f32,
        height_px: f32,
        chapter_position: i32,
        paragraph_index: i32,
        pool_name: String,
        track_name: String,
    },
    Review {
        width_px: f32,
        height_px: f32,
        chapter_position: i32,
        paragraph_index: i32,
        review_key: String,
        count: u32,
        baseline_offset_px: f32,
        #[serde(default)]
        compact_width_px: Option<f32>,
        #[serde(default)]
        compact_height_px: Option<f32>,
    },
}
impl InlineItem {
    pub fn width(&self) -> f32 {
        match self {
            Self::Text { width_px, .. }
            | Self::Image { width_px, .. }
            | Self::RoleCast { width_px, .. }
            | Self::BgmScene { width_px, .. }
            | Self::Review { width_px, .. } => *width_px,
        }
    }
    pub fn height(&self) -> f32 {
        match self {
            Self::Text { .. } => 0.0,
            Self::Image { height_px, .. }
            | Self::RoleCast { height_px, .. }
            | Self::BgmScene { height_px, .. }
            | Self::Review { height_px, .. } => *height_px,
        }
    }
    pub fn cluster(&self) -> &str {
        match self {
            Self::Text { value, .. } => value,
            Self::BgmScene { .. } | Self::Review { .. } => "",
            _ => "\u{fffc}",
        }
    }
    pub fn style(&self) -> Option<&TextStyle> {
        if let Self::Text { style, .. } = self {
            Some(style)
        } else {
            None
        }
    }
}

/// 高频字形使用结构字段，避免每个字形分配一份动态键值表。
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TextElementData {
    pub baseline_px: f32,
    pub value: String,
    pub style: Arc<TextStyle>,
    pub selected: bool,
    pub emphasized: bool,
    pub read_aloud: bool,
    pub search_result: bool,
    pub emphasis_underline: Option<Value>,
    pub link: Option<String>,
    pub marking_id: Option<String>,
    pub chapter_position: i32,
    pub paragraph_index: i32,
    pub background_frame_top_px: f32,
    pub background_frame_bottom_px: f32,
    pub background_frame_left_px: f32,
    pub background_frame_right_px: f32,
    pub continues_background_run: bool,
}

/// 序列化仍保留上游元素结构；布局位置独立，可平移而不重新塑形。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Element {
    pub bounds: Rect,
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(flatten)]
    pub data: BTreeMap<String, Value>,
    #[serde(flatten)]
    pub text: Option<Box<TextElementData>>,
}
impl<'de> Deserialize<'de> for Element {
    fn deserialize<D: serde::Deserializer<'de>>(
        deserializer: D,
    ) -> std::result::Result<Self, D::Error> {
        #[derive(Deserialize)]
        struct Raw {
            bounds: Rect,
            #[serde(rename = "type")]
            kind: String,
            #[serde(flatten)]
            fields: BTreeMap<String, Value>,
        }
        let raw = Raw::deserialize(deserializer)?;
        let (text, data) = if raw.kind == "text" {
            let value = Value::Object(raw.fields.into_iter().collect());
            let text = serde_json::from_value(value).map_err(serde::de::Error::custom)?;
            (Some(Box::new(text)), BTreeMap::new())
        } else {
            (None, raw.fields)
        };
        Ok(Self {
            bounds: raw.bounds,
            kind: raw.kind,
            text,
            data,
        })
    }
}
impl Element {
    pub fn new(kind: &str, bounds: Rect, data: Value) -> Self {
        Self {
            bounds,
            kind: kind.into(),
            data: data
                .as_object()
                .unwrap()
                .iter()
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect(),
            text: None,
        }
    }
    pub fn shift(&mut self, dy: f32) {
        self.bounds.shift(dy);
        if let Some(text) = &mut self.text {
            text.baseline_px += dy;
        }
        if let Some(value) = self.data.get_mut("baselinePx") {
            *value = Value::from(value.as_f64().unwrap() as f32 + dy);
        }
    }
}
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Page {
    pub id: PageId,
    pub chapter_title: String,
    pub text: String,
    pub width_px: i32,
    pub height_px: i32,
    pub content_top_px: f32,
    pub content_bottom_px: f32,
    pub content_left_px: f32,
    pub content_right_px: f32,
    pub elements: Vec<Element>,
    pub revision: i64,
    pub layout_revision: i64,
    pub scroll_extent_px: f32,
    pub decoration: Value,
    pub inline_images_preserve_scroll_line: bool,
    pub emphasis_underline_style: Option<Value>,
}
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PageId {
    pub chapter_index: i32,
    pub page_index: usize,
}

/// 原文页范围；由布局适配器从已测量项的原文映射生成，单位为 UTF-16。
#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SourceRange {
    pub start_offset: usize,
    pub end_offset: usize,
}
