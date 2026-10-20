//! 阅读排版专用传输模型；结构快照与低频扩展值不进行 JSON 字符串中转。— Codex + Bridge
use crate::ffi::BridgeError;
use std::collections::HashMap;

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutValueKind {
    Null,
    Boolean,
    Integer,
    Positive,
    Decimal,
    Text,
    Array,
    Object,
}
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutValueDto {
    pub kind: LayoutValueKind,
    pub boolean: Option<bool>,
    pub integer: Option<i64>,
    pub positive: Option<u64>,
    pub decimal: Option<f64>,
    pub text: Option<String>,
    pub array: Vec<LayoutValueDto>,
    pub object: HashMap<String, LayoutValueDto>,
}
impl From<serde_json::Value> for LayoutValueDto {
    fn from(v: serde_json::Value) -> Self {
        let mut d = Self {
            kind: LayoutValueKind::Null,
            boolean: None,
            integer: None,
            positive: None,
            decimal: None,
            text: None,
            array: vec![],
            object: HashMap::new(),
        };
        use serde_json::Value;
        match v {
            Value::Null => {}
            Value::Bool(v) => {
                d.kind = LayoutValueKind::Boolean;
                d.boolean = Some(v)
            }
            Value::Number(v) => {
                if let Some(x) = v.as_i64() {
                    d.kind = LayoutValueKind::Integer;
                    d.integer = Some(x)
                } else if let Some(x) = v.as_u64() {
                    d.kind = LayoutValueKind::Positive;
                    d.positive = Some(x)
                } else {
                    d.kind = LayoutValueKind::Decimal;
                    d.decimal = v.as_f64()
                }
            }
            Value::String(v) => {
                d.kind = LayoutValueKind::Text;
                d.text = Some(v)
            }
            Value::Array(v) => {
                d.kind = LayoutValueKind::Array;
                d.array = v.into_iter().map(Into::into).collect()
            }
            Value::Object(v) => {
                d.kind = LayoutValueKind::Object;
                d.object = v.into_iter().map(|(k, v)| (k, v.into())).collect()
            }
        };
        d
    }
}
impl TryFrom<LayoutValueDto> for serde_json::Value {
    type Error = BridgeError;
    fn try_from(v: LayoutValueDto) -> Result<Self, BridgeError> {
        let bad = || BridgeError {
            message: "阅读布局扩展字段无效".into(),
        };
        Ok(match v.kind {
            LayoutValueKind::Null => Self::Null,
            LayoutValueKind::Boolean => Self::Bool(v.boolean.ok_or_else(bad)?),
            LayoutValueKind::Integer => Self::from(v.integer.ok_or_else(bad)?),
            LayoutValueKind::Positive => Self::from(v.positive.ok_or_else(bad)?),
            LayoutValueKind::Decimal => Self::Number(
                serde_json::Number::from_f64(v.decimal.ok_or_else(bad)?).ok_or_else(bad)?,
            ),
            LayoutValueKind::Text => Self::String(v.text.ok_or_else(bad)?),
            LayoutValueKind::Array => Self::Array(
                v.array
                    .into_iter()
                    .map(TryInto::try_into)
                    .collect::<Result<_, BridgeError>>()?,
            ),
            LayoutValueKind::Object => Self::Object(
                v.object
                    .into_iter()
                    .map(|(k, v)| Ok((k, v.try_into()?)))
                    .collect::<Result<_, BridgeError>>()?,
            ),
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutAlignmentDto {
    Start,
    Center,
    End,
    Justify,
}

impl From<legado_layout::model::Alignment> for LayoutAlignmentDto {
    fn from(value: legado_layout::model::Alignment) -> Self {
        match value {
            legado_layout::model::Alignment::Start => Self::Start,
            legado_layout::model::Alignment::Center => Self::Center,
            legado_layout::model::Alignment::End => Self::End,
            legado_layout::model::Alignment::Justify => Self::Justify,
        }
    }
}

impl TryFrom<LayoutAlignmentDto> for legado_layout::model::Alignment {
    type Error = BridgeError;
    fn try_from(value: LayoutAlignmentDto) -> Result<Self, BridgeError> {
        Ok(match value {
            LayoutAlignmentDto::Start => Self::Start,
            LayoutAlignmentDto::Center => Self::Center,
            LayoutAlignmentDto::End => Self::End,
            LayoutAlignmentDto::Justify => Self::Justify,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutImageScaleDto {
    ContainNoUpscale,
    FitWidth,
    FitPage,
}

impl From<legado_layout::model::ImageScale> for LayoutImageScaleDto {
    fn from(value: legado_layout::model::ImageScale) -> Self {
        match value {
            legado_layout::model::ImageScale::ContainNoUpscale => Self::ContainNoUpscale,
            legado_layout::model::ImageScale::FitWidth => Self::FitWidth,
            legado_layout::model::ImageScale::FitPage => Self::FitPage,
        }
    }
}

impl TryFrom<LayoutImageScaleDto> for legado_layout::model::ImageScale {
    type Error = BridgeError;
    fn try_from(value: LayoutImageScaleDto) -> Result<Self, BridgeError> {
        Ok(match value {
            LayoutImageScaleDto::ContainNoUpscale => Self::ContainNoUpscale,
            LayoutImageScaleDto::FitWidth => Self::FitWidth,
            LayoutImageScaleDto::FitPage => Self::FitPage,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutBreakModeDto {
    Chinese,
    Plain,
}

impl From<legado_layout::model::BreakMode> for LayoutBreakModeDto {
    fn from(value: legado_layout::model::BreakMode) -> Self {
        match value {
            legado_layout::model::BreakMode::Chinese => Self::Chinese,
            legado_layout::model::BreakMode::Plain => Self::Plain,
        }
    }
}

impl TryFrom<LayoutBreakModeDto> for legado_layout::model::BreakMode {
    type Error = BridgeError;
    fn try_from(value: LayoutBreakModeDto) -> Result<Self, BridgeError> {
        Ok(match value {
            LayoutBreakModeDto::Chinese => Self::Chinese,
            LayoutBreakModeDto::Plain => Self::Plain,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutBackgroundImageDto {
    pub source: String,
    pub fit: i32,
    pub scale: f32,

    pub nine_patch_left: f32,

    pub nine_patch_right: f32,

    pub nine_patch_top: f32,

    pub nine_patch_bottom: f32,

    pub length_offset_left_px: f32,

    pub length_offset_right_px: f32,

    pub content_inset_left_px: f32,

    pub content_inset_right_px: f32,

    pub content_inset_top_px: f32,

    pub content_inset_bottom_px: f32,

    pub content_band_height_px: f32,
}

impl From<legado_layout::model::BackgroundImage> for LayoutBackgroundImageDto {
    fn from(value: legado_layout::model::BackgroundImage) -> Self {
        Self {
            source: value.source,
            fit: value.fit,
            scale: value.scale,
            nine_patch_left: value.nine_patch_left,
            nine_patch_right: value.nine_patch_right,
            nine_patch_top: value.nine_patch_top,
            nine_patch_bottom: value.nine_patch_bottom,
            length_offset_left_px: value.length_offset_left_px,
            length_offset_right_px: value.length_offset_right_px,
            content_inset_left_px: value.content_inset_left_px,
            content_inset_right_px: value.content_inset_right_px,
            content_inset_top_px: value.content_inset_top_px,
            content_inset_bottom_px: value.content_inset_bottom_px,
            content_band_height_px: value.content_band_height_px,
        }
    }
}

impl TryFrom<LayoutBackgroundImageDto> for legado_layout::model::BackgroundImage {
    type Error = BridgeError;
    fn try_from(value: LayoutBackgroundImageDto) -> Result<Self, BridgeError> {
        Ok(Self {
            source: value.source,
            fit: value.fit,
            scale: value.scale,
            nine_patch_left: value.nine_patch_left,
            nine_patch_right: value.nine_patch_right,
            nine_patch_top: value.nine_patch_top,
            nine_patch_bottom: value.nine_patch_bottom,
            length_offset_left_px: value.length_offset_left_px,
            length_offset_right_px: value.length_offset_right_px,
            content_inset_left_px: value.content_inset_left_px,
            content_inset_right_px: value.content_inset_right_px,
            content_inset_top_px: value.content_inset_top_px,
            content_inset_bottom_px: value.content_inset_bottom_px,
            content_band_height_px: value.content_band_height_px,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutTextStyleDto {
    pub color_argb: i32,
    pub font_size_px: f32,

    pub font_path: String,

    pub font_weight: i32,

    pub italic: bool,

    pub background_argb: Option<i32>,

    pub underline: Option<LayoutValueDto>,

    pub shadow: Option<LayoutValueDto>,

    pub background_image: Option<LayoutBackgroundImageDto>,

    pub font_family: String,

    pub linear_text: bool,

    pub strike_through: bool,

    pub native_underline: bool,

    pub match_spacing_before_px: f32,

    pub match_spacing_after_px: f32,

    pub line_pad_top_px: f32,

    pub line_pad_bottom_px: f32,
}

impl From<legado_layout::model::TextStyle> for LayoutTextStyleDto {
    fn from(value: legado_layout::model::TextStyle) -> Self {
        Self {
            color_argb: value.color_argb,
            font_size_px: value.font_size_px,
            font_path: value.font_path,
            font_weight: value.font_weight,
            italic: value.italic,
            background_argb: value.background_argb,
            underline: value.underline.map(|item| item.into()),
            shadow: value.shadow.map(|item| item.into()),
            background_image: value.background_image.map(|item| item.into()),
            font_family: value.font_family,
            linear_text: value.linear_text,
            strike_through: value.strike_through,
            native_underline: value.native_underline,
            match_spacing_before_px: value.match_spacing_before_px,
            match_spacing_after_px: value.match_spacing_after_px,
            line_pad_top_px: value.line_pad_top_px,
            line_pad_bottom_px: value.line_pad_bottom_px,
        }
    }
}

impl TryFrom<LayoutTextStyleDto> for legado_layout::model::TextStyle {
    type Error = BridgeError;
    fn try_from(value: LayoutTextStyleDto) -> Result<Self, BridgeError> {
        Ok(Self {
            color_argb: value.color_argb,
            font_size_px: value.font_size_px,
            font_path: value.font_path,
            font_weight: value.font_weight,
            italic: value.italic,
            background_argb: value.background_argb,
            underline: value.underline.map(TryInto::try_into).transpose()?,
            shadow: value.shadow.map(TryInto::try_into).transpose()?,
            background_image: value.background_image.map(TryInto::try_into).transpose()?,
            font_family: value.font_family,
            linear_text: value.linear_text,
            strike_through: value.strike_through,
            native_underline: value.native_underline,
            match_spacing_before_px: value.match_spacing_before_px,
            match_spacing_after_px: value.match_spacing_after_px,
            line_pad_top_px: value.line_pad_top_px,
            line_pad_bottom_px: value.line_pad_bottom_px,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutPageUnderlineDto {
    pub color_argb: i32,
    pub width_px: f32,
    pub offset_px: f32,
    pub extend_to_column: bool,
    pub dashed: bool,

    pub dash_on_px: f32,

    pub dash_off_px: f32,
}

impl From<legado_layout::model::PageUnderline> for LayoutPageUnderlineDto {
    fn from(value: legado_layout::model::PageUnderline) -> Self {
        Self {
            color_argb: value.color_argb,
            width_px: value.width_px,
            offset_px: value.offset_px,
            extend_to_column: value.extend_to_column,
            dashed: value.dashed,
            dash_on_px: value.dash_on_px,
            dash_off_px: value.dash_off_px,
        }
    }
}

impl TryFrom<LayoutPageUnderlineDto> for legado_layout::model::PageUnderline {
    type Error = BridgeError;
    fn try_from(value: LayoutPageUnderlineDto) -> Result<Self, BridgeError> {
        Ok(Self {
            color_argb: value.color_argb,
            width_px: value.width_px,
            offset_px: value.offset_px,
            extend_to_column: value.extend_to_column,
            dashed: value.dashed,
            dash_on_px: value.dash_on_px,
            dash_off_px: value.dash_off_px,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutCastOptionsDto {
    pub enabled: bool,

    pub profiles: HashMap<String, LayoutCastProfileDto>,

    pub chapter_effects: HashMap<i32, String>,

    pub character_effects: HashMap<String, String>,

    pub bubbles: HashMap<String, LayoutValueDto>,
}

impl From<legado_layout::model::CastOptions> for LayoutCastOptionsDto {
    fn from(value: legado_layout::model::CastOptions) -> Self {
        Self {
            enabled: value.enabled,
            profiles: value
                .profiles
                .into_iter()
                .map(|(key, item)| (key, item.into()))
                .collect(),
            chapter_effects: value.chapter_effects.into_iter().collect(),
            character_effects: value.character_effects.into_iter().collect(),
            bubbles: value
                .bubbles
                .into_iter()
                .map(|(key, item)| (key, item.into()))
                .collect(),
        }
    }
}

impl TryFrom<LayoutCastOptionsDto> for legado_layout::model::CastOptions {
    type Error = BridgeError;
    fn try_from(value: LayoutCastOptionsDto) -> Result<Self, BridgeError> {
        Ok(Self {
            enabled: value.enabled,
            profiles: value
                .profiles
                .into_iter()
                .map(|(key, item)| Ok((key, item.try_into()?)))
                .collect::<Result<_, BridgeError>>()?,
            chapter_effects: value
                .chapter_effects
                .into_iter()
                .map(|(key, item)| Ok((key, item)))
                .collect::<Result<_, BridgeError>>()?,
            character_effects: value
                .character_effects
                .into_iter()
                .map(|(key, item)| Ok((key, item)))
                .collect::<Result<_, BridgeError>>()?,
            bubbles: value
                .bubbles
                .into_iter()
                .map(|(key, item)| Ok((key, item.try_into()?)))
                .collect::<Result<_, BridgeError>>()?,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutCastProfileDto {
    pub character_id: String,
    pub avatar_uri: String,
}

impl From<legado_layout::model::CastProfile> for LayoutCastProfileDto {
    fn from(value: legado_layout::model::CastProfile) -> Self {
        Self {
            character_id: value.character_id,
            avatar_uri: value.avatar_uri,
        }
    }
}

impl TryFrom<LayoutCastProfileDto> for legado_layout::model::CastProfile {
    type Error = BridgeError;
    fn try_from(value: LayoutCastProfileDto) -> Result<Self, BridgeError> {
        Ok(Self {
            character_id: value.character_id,
            avatar_uri: value.avatar_uri,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutConfigDto {
    pub break_mode: LayoutBreakModeDto,
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

    pub paragraph_spacing_px: f32,

    pub letter_spacing_px: f32,

    pub revision: i64,

    pub decoration: LayoutValueDto,

    pub title_top_spacing_px: f32,

    pub title_bottom_spacing_px: f32,

    pub title_paragraph_spacing_px: Option<f32>,

    pub title_segment_spacing_px: f32,

    pub title_page_center_vertical: bool,

    pub column_count: i32,

    pub line_spacing_multiplier: f32,

    pub continuous_scroll: bool,

    pub single_image_style: bool,

    pub chapter_end_padding_px: f32,

    pub text_bottom_justify: bool,

    pub html_line_spacing_add_px: f32,

    pub page_underline: Option<LayoutPageUnderlineDto>,

    pub inline_images_preserve_scroll_line: bool,

    pub emphasis_underline_style: Option<LayoutValueDto>,

    pub cast_options: LayoutCastOptionsDto,
}

impl From<legado_layout::model::Config> for LayoutConfigDto {
    fn from(value: legado_layout::model::Config) -> Self {
        Self {
            break_mode: value.break_mode.into(),
            chapter_index: value.chapter_index,
            chapter_title: value.chapter_title,
            viewport_width_px: value.viewport_width_px,
            viewport_height_px: value.viewport_height_px,
            padding_left_px: value.padding_left_px,
            padding_top_px: value.padding_top_px,
            padding_right_px: value.padding_right_px,
            padding_bottom_px: value.padding_bottom_px,
            line_height_px: value.line_height_px,
            baseline_offset_px: value.baseline_offset_px,
            paragraph_spacing_px: value.paragraph_spacing_px,
            letter_spacing_px: value.letter_spacing_px,
            revision: value.revision,
            decoration: value.decoration.into(),
            title_top_spacing_px: value.title_top_spacing_px,
            title_bottom_spacing_px: value.title_bottom_spacing_px,
            title_paragraph_spacing_px: value.title_paragraph_spacing_px,
            title_segment_spacing_px: value.title_segment_spacing_px,
            title_page_center_vertical: value.title_page_center_vertical,
            column_count: value.column_count,
            line_spacing_multiplier: value.line_spacing_multiplier,
            continuous_scroll: value.continuous_scroll,
            single_image_style: value.single_image_style,
            chapter_end_padding_px: value.chapter_end_padding_px,
            text_bottom_justify: value.text_bottom_justify,
            html_line_spacing_add_px: value.html_line_spacing_add_px,
            page_underline: value.page_underline.map(|item| item.into()),
            inline_images_preserve_scroll_line: value.inline_images_preserve_scroll_line,
            emphasis_underline_style: value.emphasis_underline_style.map(|item| item.into()),
            cast_options: value.cast_options.into(),
        }
    }
}

impl TryFrom<LayoutConfigDto> for legado_layout::model::Config {
    type Error = BridgeError;
    fn try_from(value: LayoutConfigDto) -> Result<Self, BridgeError> {
        Ok(Self {
            break_mode: value.break_mode.try_into()?,
            chapter_index: value.chapter_index,
            chapter_title: value.chapter_title,
            viewport_width_px: value.viewport_width_px,
            viewport_height_px: value.viewport_height_px,
            padding_left_px: value.padding_left_px,
            padding_top_px: value.padding_top_px,
            padding_right_px: value.padding_right_px,
            padding_bottom_px: value.padding_bottom_px,
            line_height_px: value.line_height_px,
            baseline_offset_px: value.baseline_offset_px,
            paragraph_spacing_px: value.paragraph_spacing_px,
            letter_spacing_px: value.letter_spacing_px,
            revision: value.revision,
            decoration: value.decoration.try_into()?,
            title_top_spacing_px: value.title_top_spacing_px,
            title_bottom_spacing_px: value.title_bottom_spacing_px,
            title_paragraph_spacing_px: value.title_paragraph_spacing_px,
            title_segment_spacing_px: value.title_segment_spacing_px,
            title_page_center_vertical: value.title_page_center_vertical,
            column_count: value.column_count,
            line_spacing_multiplier: value.line_spacing_multiplier,
            continuous_scroll: value.continuous_scroll,
            single_image_style: value.single_image_style,
            chapter_end_padding_px: value.chapter_end_padding_px,
            text_bottom_justify: value.text_bottom_justify,
            html_line_spacing_add_px: value.html_line_spacing_add_px,
            page_underline: value.page_underline.map(TryInto::try_into).transpose()?,
            inline_images_preserve_scroll_line: value.inline_images_preserve_scroll_line,
            emphasis_underline_style: value
                .emphasis_underline_style
                .map(TryInto::try_into)
                .transpose()?,
            cast_options: value.cast_options.try_into()?,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutParagraphDto {
    pub text: String,
    pub clusters: Vec<String>,
    pub cluster_widths_px: Vec<f32>,
    pub style: LayoutTextStyleDto,
    pub chapter_position: i32,

    pub indent_characters: i32,

    pub alignment: LayoutAlignmentDto,

    pub is_title: bool,

    pub link: Option<String>,

    pub line_height_px: Option<f32>,

    pub baseline_offset_px: Option<f32>,

    pub line_spacing_multiplier: Option<f32>,

    pub letter_spacing_px: Option<f32>,

    pub indent_width_px: Option<f32>,
}

impl From<legado_layout::model::Paragraph> for LayoutParagraphDto {
    fn from(value: legado_layout::model::Paragraph) -> Self {
        Self {
            text: value.text,
            clusters: value.clusters,
            cluster_widths_px: value.cluster_widths_px,
            style: value.style.into(),
            chapter_position: value.chapter_position,
            indent_characters: value.indent_characters,
            alignment: value.alignment.into(),
            is_title: value.is_title,
            link: value.link,
            line_height_px: value.line_height_px,
            baseline_offset_px: value.baseline_offset_px,
            line_spacing_multiplier: value.line_spacing_multiplier,
            letter_spacing_px: value.letter_spacing_px,
            indent_width_px: value.indent_width_px,
        }
    }
}

impl TryFrom<LayoutParagraphDto> for legado_layout::model::Paragraph {
    type Error = BridgeError;
    fn try_from(value: LayoutParagraphDto) -> Result<Self, BridgeError> {
        Ok(Self {
            text: value.text,
            clusters: value.clusters,
            cluster_widths_px: value.cluster_widths_px,
            style: value.style.try_into()?,
            chapter_position: value.chapter_position,
            indent_characters: value.indent_characters,
            alignment: value.alignment.try_into()?,
            is_title: value.is_title,
            link: value.link,
            line_height_px: value.line_height_px,
            baseline_offset_px: value.baseline_offset_px,
            line_spacing_multiplier: value.line_spacing_multiplier,
            letter_spacing_px: value.letter_spacing_px,
            indent_width_px: value.indent_width_px,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutInlineParagraphDto {
    pub items: Vec<LayoutInlineItemDto>,
    pub indent_characters: i32,
    pub alignment: LayoutAlignmentDto,
    pub line_height_px: f32,
    pub baseline_offset_px: f32,
    pub base_text_size_px: f32,

    pub emphasized: bool,

    pub title_spacing_scale: f32,

    pub line_spacing_multiplier: f32,

    pub letter_spacing_px: Option<f32>,

    pub indent_width_px: Option<f32>,

    pub rest_line_indent_width_px: f32,

    pub leading_indent_items: usize,

    pub decorations: Vec<LayoutParagraphDecorationDto>,

    pub justify_at_word_boundaries: bool,
}

impl From<legado_layout::model::InlineParagraph> for LayoutInlineParagraphDto {
    fn from(value: legado_layout::model::InlineParagraph) -> Self {
        Self {
            items: value.items.into_iter().map(|item| item.into()).collect(),
            indent_characters: value.indent_characters,
            alignment: value.alignment.into(),
            line_height_px: value.line_height_px,
            baseline_offset_px: value.baseline_offset_px,
            base_text_size_px: value.base_text_size_px,
            emphasized: value.emphasized,
            title_spacing_scale: value.title_spacing_scale,
            line_spacing_multiplier: value.line_spacing_multiplier,
            letter_spacing_px: value.letter_spacing_px,
            indent_width_px: value.indent_width_px,
            rest_line_indent_width_px: value.rest_line_indent_width_px,
            leading_indent_items: value.leading_indent_items,
            decorations: value
                .decorations
                .into_iter()
                .map(|item| item.into())
                .collect(),
            justify_at_word_boundaries: value.justify_at_word_boundaries,
        }
    }
}

impl TryFrom<LayoutInlineParagraphDto> for legado_layout::model::InlineParagraph {
    type Error = BridgeError;
    fn try_from(value: LayoutInlineParagraphDto) -> Result<Self, BridgeError> {
        Ok(Self {
            items: value
                .items
                .into_iter()
                .map(TryInto::try_into)
                .collect::<Result<_, BridgeError>>()?,
            indent_characters: value.indent_characters,
            alignment: value.alignment.try_into()?,
            line_height_px: value.line_height_px,
            baseline_offset_px: value.baseline_offset_px,
            base_text_size_px: value.base_text_size_px,
            emphasized: value.emphasized,
            title_spacing_scale: value.title_spacing_scale,
            line_spacing_multiplier: value.line_spacing_multiplier,
            letter_spacing_px: value.letter_spacing_px,
            indent_width_px: value.indent_width_px,
            rest_line_indent_width_px: value.rest_line_indent_width_px,
            leading_indent_items: value.leading_indent_items,
            decorations: value
                .decorations
                .into_iter()
                .map(TryInto::try_into)
                .collect::<Result<_, BridgeError>>()?,
            justify_at_word_boundaries: value.justify_at_word_boundaries,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutDecorationKindDto {
    Quote,
    Bullet,
}

impl From<legado_layout::model::DecorationKind> for LayoutDecorationKindDto {
    fn from(value: legado_layout::model::DecorationKind) -> Self {
        match value {
            legado_layout::model::DecorationKind::Quote => Self::Quote,
            legado_layout::model::DecorationKind::Bullet => Self::Bullet,
        }
    }
}

impl TryFrom<LayoutDecorationKindDto> for legado_layout::model::DecorationKind {
    type Error = BridgeError;
    fn try_from(value: LayoutDecorationKindDto) -> Result<Self, BridgeError> {
        Ok(match value {
            LayoutDecorationKindDto::Quote => Self::Quote,
            LayoutDecorationKindDto::Bullet => Self::Bullet,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutParagraphDecorationDto {
    pub kind: LayoutDecorationKindDto,
    pub color_argb: Option<i32>,
    pub size_px: f32,

    pub leading_offset_px: f32,
}

impl From<legado_layout::model::ParagraphDecoration> for LayoutParagraphDecorationDto {
    fn from(value: legado_layout::model::ParagraphDecoration) -> Self {
        Self {
            kind: value.kind.into(),
            color_argb: value.color_argb,
            size_px: value.size_px,
            leading_offset_px: value.leading_offset_px,
        }
    }
}

impl TryFrom<LayoutParagraphDecorationDto> for legado_layout::model::ParagraphDecoration {
    type Error = BridgeError;
    fn try_from(value: LayoutParagraphDecorationDto) -> Result<Self, BridgeError> {
        Ok(Self {
            kind: value.kind.try_into()?,
            color_argb: value.color_argb,
            size_px: value.size_px,
            leading_offset_px: value.leading_offset_px,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutBlockDto {
    Paragraph {
        value: Box<LayoutParagraphDto>,
    },
    InlineParagraph(LayoutInlineParagraphDto),
    Image {
        source: String,
        intrinsic_width_px: f32,
        intrinsic_height_px: f32,
        chapter_position: i32,

        action: Option<String>,

        horizontal_alignment: LayoutAlignmentDto,

        scale_mode: LayoutImageScaleDto,

        page_break_before: bool,

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

        dashed: bool,
    },
    PageBreak,
}

impl From<legado_layout::model::Block> for LayoutBlockDto {
    fn from(value: legado_layout::model::Block) -> Self {
        match value {
            legado_layout::model::Block::Paragraph { value } => Self::Paragraph {
                value: Box::new((*value).into()),
            },
            legado_layout::model::Block::InlineParagraph(inner) => {
                Self::InlineParagraph(inner.into())
            }
            legado_layout::model::Block::Image {
                source,
                intrinsic_width_px,
                intrinsic_height_px,
                chapter_position,
                action,
                horizontal_alignment,
                scale_mode,
                page_break_before,
                page_break_after,
            } => Self::Image {
                source,
                intrinsic_width_px,
                intrinsic_height_px,
                chapter_position,
                action,
                horizontal_alignment: horizontal_alignment.into(),
                scale_mode: scale_mode.into(),
                page_break_before,
                page_break_after,
            },
            legado_layout::model::Block::BlankLine {
                chapter_position,
                line_height_px,
                line_spacing_multiplier,
            } => Self::BlankLine {
                chapter_position,
                line_height_px,
                line_spacing_multiplier,
            },
            legado_layout::model::Block::Rule {
                color_argb,
                width_px,
                vertical_padding_px,
                dashed,
            } => Self::Rule {
                color_argb,
                width_px,
                vertical_padding_px,
                dashed,
            },
            legado_layout::model::Block::PageBreak => Self::PageBreak,
        }
    }
}

impl TryFrom<LayoutBlockDto> for legado_layout::model::Block {
    type Error = BridgeError;
    fn try_from(value: LayoutBlockDto) -> Result<Self, BridgeError> {
        Ok(match value {
            LayoutBlockDto::Paragraph { value } => Self::Paragraph {
                value: Box::new((*value).try_into()?),
            },
            LayoutBlockDto::InlineParagraph(inner) => Self::InlineParagraph(inner.try_into()?),
            LayoutBlockDto::Image {
                source,
                intrinsic_width_px,
                intrinsic_height_px,
                chapter_position,
                action,
                horizontal_alignment,
                scale_mode,
                page_break_before,
                page_break_after,
            } => Self::Image {
                source,
                intrinsic_width_px,
                intrinsic_height_px,
                chapter_position,
                action,
                horizontal_alignment: horizontal_alignment.try_into()?,
                scale_mode: scale_mode.try_into()?,
                page_break_before,
                page_break_after,
            },
            LayoutBlockDto::BlankLine {
                chapter_position,
                line_height_px,
                line_spacing_multiplier,
            } => Self::BlankLine {
                chapter_position,
                line_height_px,
                line_spacing_multiplier,
            },
            LayoutBlockDto::Rule {
                color_argb,
                width_px,
                vertical_padding_px,
                dashed,
            } => Self::Rule {
                color_argb,
                width_px,
                vertical_padding_px,
                dashed,
            },
            LayoutBlockDto::PageBreak => Self::PageBreak,
        })
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum LayoutInlineItemDto {
    Text {
        value: String,
        width_px: f32,
        style: Box<LayoutTextStyleDto>,
        chapter_position: i32,

        link: Option<String>,

        marking_id: Option<String>,

        line_height_px: Option<f32>,

        baseline_offset_px: Option<f32>,

        baseline_shift_px: f32,
    },
    Image {
        source: String,
        width_px: f32,
        height_px: f32,
        chapter_position: i32,

        action: Option<String>,

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

        compact_width_px: Option<f32>,

        compact_height_px: Option<f32>,
    },
}

impl From<legado_layout::model::InlineItem> for LayoutInlineItemDto {
    fn from(value: legado_layout::model::InlineItem) -> Self {
        match value {
            legado_layout::model::InlineItem::Text {
                value,
                width_px,
                style,
                chapter_position,
                link,
                marking_id,
                line_height_px,
                baseline_offset_px,
                baseline_shift_px,
            } => Self::Text {
                value,
                width_px,
                style: Box::new((*style).into()),
                chapter_position,
                link,
                marking_id,
                line_height_px,
                baseline_offset_px,
                baseline_shift_px,
            },
            legado_layout::model::InlineItem::Image {
                source,
                width_px,
                height_px,
                chapter_position,
                action,
                line_final_width_px,
            } => Self::Image {
                source,
                width_px,
                height_px,
                chapter_position,
                action,
                line_final_width_px,
            },
            legado_layout::model::InlineItem::RoleCast {
                width_px,
                height_px,
                chapter_position,
                raw,
                name,
                voice_pool_label,
                quote_ordinal,
                voice_effect_mark,
            } => Self::RoleCast {
                width_px,
                height_px,
                chapter_position,
                raw,
                name,
                voice_pool_label,
                quote_ordinal,
                voice_effect_mark,
            },
            legado_layout::model::InlineItem::BgmScene {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                pool_name,
                track_name,
            } => Self::BgmScene {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                pool_name,
                track_name,
            },
            legado_layout::model::InlineItem::Review {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                review_key,
                count,
                baseline_offset_px,
                compact_width_px,
                compact_height_px,
            } => Self::Review {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                review_key,
                count,
                baseline_offset_px,
                compact_width_px,
                compact_height_px,
            },
        }
    }
}

impl TryFrom<LayoutInlineItemDto> for legado_layout::model::InlineItem {
    type Error = BridgeError;
    fn try_from(value: LayoutInlineItemDto) -> Result<Self, BridgeError> {
        Ok(match value {
            LayoutInlineItemDto::Text {
                value,
                width_px,
                style,
                chapter_position,
                link,
                marking_id,
                line_height_px,
                baseline_offset_px,
                baseline_shift_px,
            } => Self::Text {
                value,
                width_px,
                style: Box::new((*style).try_into()?),
                chapter_position,
                link,
                marking_id,
                line_height_px,
                baseline_offset_px,
                baseline_shift_px,
            },
            LayoutInlineItemDto::Image {
                source,
                width_px,
                height_px,
                chapter_position,
                action,
                line_final_width_px,
            } => Self::Image {
                source,
                width_px,
                height_px,
                chapter_position,
                action,
                line_final_width_px,
            },
            LayoutInlineItemDto::RoleCast {
                width_px,
                height_px,
                chapter_position,
                raw,
                name,
                voice_pool_label,
                quote_ordinal,
                voice_effect_mark,
            } => Self::RoleCast {
                width_px,
                height_px,
                chapter_position,
                raw,
                name,
                voice_pool_label,
                quote_ordinal,
                voice_effect_mark,
            },
            LayoutInlineItemDto::BgmScene {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                pool_name,
                track_name,
            } => Self::BgmScene {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                pool_name,
                track_name,
            },
            LayoutInlineItemDto::Review {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                review_key,
                count,
                baseline_offset_px,
                compact_width_px,
                compact_height_px,
            } => Self::Review {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                review_key,
                count,
                baseline_offset_px,
                compact_width_px,
                compact_height_px,
            },
        })
    }
}

/// 布局结果沿用紧凑字形列。低频页面/元素元数据使用类型树。
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutReplyDto {
    pub pages: Vec<LayoutPageDto>,
    pub text_styles: Vec<LayoutTextStyleDto>,
    pub count: usize,
    pub text: String,
    pub geometry: Vec<u8>,
    pub positions: Vec<u8>,
    pub extras: HashMap<String, LayoutValueDto>,
    pub rust_micros: u64,
}
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutPageDto {
    pub metadata: HashMap<String, LayoutValueDto>,
    pub elements: Vec<LayoutElementDto>,
}
#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct LayoutElementDto {
    pub glyph_index: Option<usize>,
    pub other: Option<LayoutValueDto>,
}
impl LayoutReplyDto {
    pub(crate) fn pack(pages: Vec<legado_layout::model::Page>, start: std::time::Instant) -> Self {
        let p = legado_layout::wire::pack_pages_binary(pages);
        Self {
            pages: p
                .pages
                .into_iter()
                .map(|page| LayoutPageDto {
                    metadata: page
                        .metadata
                        .into_iter()
                        .map(|(k, v)| (k, v.into()))
                        .collect(),
                    elements: page
                        .elements
                        .into_iter()
                        .map(|e| match e {
                            legado_layout::wire::WireElement::Text(i) => LayoutElementDto {
                                glyph_index: Some(i),
                                other: None,
                            },
                            legado_layout::wire::WireElement::Other(e) => LayoutElementDto {
                                glyph_index: None,
                                other: Some(
                                    serde_json::to_value(*e).expect("已校验布局元素").into(),
                                ),
                            },
                        })
                        .collect(),
                })
                .collect(),
            text_styles: p
                .text_styles
                .into_iter()
                .map(|s| (*s).clone().into())
                .collect(),
            count: p.count,
            text: p.text,
            geometry: p.geometry,
            positions: p.positions,
            extras: p.extras.into_iter().map(|(k, v)| (k, v.into())).collect(),
            rust_micros: start.elapsed().as_micros().min(u64::MAX as u128) as u64,
        }
    }
}

use crate::layout_bridge::{Budget, PayloadBudget};
impl Budget for String {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(self.len(), d)
    }
}
impl<T: Budget> Budget for Vec<T> {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<T>().saturating_mul(self.len()), d)?;
        for v in self {
            v.check_budget(b, d + 1)?;
        }
        Ok(())
    }
}
impl<T: Budget> Budget for Option<T> {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        if let Some(v) = self {
            v.check_budget(b, d + 1)?;
        }
        Ok(())
    }
}
impl<T: Budget> Budget for Box<T> {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        self.as_ref().check_budget(b, d + 1)
    }
}
impl<K: Budget, V: Budget> Budget for HashMap<K, V> {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        for (k, v) in self {
            k.check_budget(b, d + 1)?;
            v.check_budget(b, d + 1)?;
        }
        Ok(())
    }
}
macro_rules! scalar_budget {($($t:ty),*)=>{$(impl Budget for $t {fn check_budget(&self,b:&mut PayloadBudget,d:usize)->Result<(),BridgeError>{b.add(std::mem::size_of::<Self>(),d)}})*};}
scalar_budget!(bool, i32, i64, u32, u64, usize, f32, f64, LayoutValueKind);
impl Budget for LayoutValueDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.text.check_budget(b, d + 1)?;
        self.array.check_budget(b, d + 1)?;
        self.object.check_budget(b, d + 1)
    }
}
impl Budget for LayoutAlignmentDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        match self {
            Self::Start => {}
            Self::Center => {}
            Self::End => {}
            Self::Justify => {}
        };
        Ok(())
    }
}
impl Budget for LayoutImageScaleDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        match self {
            Self::ContainNoUpscale => {}
            Self::FitWidth => {}
            Self::FitPage => {}
        };
        Ok(())
    }
}
impl Budget for LayoutBreakModeDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        match self {
            Self::Chinese => {}
            Self::Plain => {}
        };
        Ok(())
    }
}
impl Budget for LayoutBackgroundImageDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.source.check_budget(b, d + 1)?;
        self.fit.check_budget(b, d + 1)?;
        self.scale.check_budget(b, d + 1)?;
        self.nine_patch_left.check_budget(b, d + 1)?;
        self.nine_patch_right.check_budget(b, d + 1)?;
        self.nine_patch_top.check_budget(b, d + 1)?;
        self.nine_patch_bottom.check_budget(b, d + 1)?;
        self.length_offset_left_px.check_budget(b, d + 1)?;
        self.length_offset_right_px.check_budget(b, d + 1)?;
        self.content_inset_left_px.check_budget(b, d + 1)?;
        self.content_inset_right_px.check_budget(b, d + 1)?;
        self.content_inset_top_px.check_budget(b, d + 1)?;
        self.content_inset_bottom_px.check_budget(b, d + 1)?;
        self.content_band_height_px.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutTextStyleDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.color_argb.check_budget(b, d + 1)?;
        self.font_size_px.check_budget(b, d + 1)?;
        self.font_path.check_budget(b, d + 1)?;
        self.font_weight.check_budget(b, d + 1)?;
        self.italic.check_budget(b, d + 1)?;
        self.background_argb.check_budget(b, d + 1)?;
        self.underline.check_budget(b, d + 1)?;
        self.shadow.check_budget(b, d + 1)?;
        self.background_image.check_budget(b, d + 1)?;
        self.font_family.check_budget(b, d + 1)?;
        self.linear_text.check_budget(b, d + 1)?;
        self.strike_through.check_budget(b, d + 1)?;
        self.native_underline.check_budget(b, d + 1)?;
        self.match_spacing_before_px.check_budget(b, d + 1)?;
        self.match_spacing_after_px.check_budget(b, d + 1)?;
        self.line_pad_top_px.check_budget(b, d + 1)?;
        self.line_pad_bottom_px.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutPageUnderlineDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.color_argb.check_budget(b, d + 1)?;
        self.width_px.check_budget(b, d + 1)?;
        self.offset_px.check_budget(b, d + 1)?;
        self.extend_to_column.check_budget(b, d + 1)?;
        self.dashed.check_budget(b, d + 1)?;
        self.dash_on_px.check_budget(b, d + 1)?;
        self.dash_off_px.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutCastOptionsDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.enabled.check_budget(b, d + 1)?;
        self.profiles.check_budget(b, d + 1)?;
        self.chapter_effects.check_budget(b, d + 1)?;
        self.character_effects.check_budget(b, d + 1)?;
        self.bubbles.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutCastProfileDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.character_id.check_budget(b, d + 1)?;
        self.avatar_uri.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutConfigDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.break_mode.check_budget(b, d + 1)?;
        self.chapter_index.check_budget(b, d + 1)?;
        self.chapter_title.check_budget(b, d + 1)?;
        self.viewport_width_px.check_budget(b, d + 1)?;
        self.viewport_height_px.check_budget(b, d + 1)?;
        self.padding_left_px.check_budget(b, d + 1)?;
        self.padding_top_px.check_budget(b, d + 1)?;
        self.padding_right_px.check_budget(b, d + 1)?;
        self.padding_bottom_px.check_budget(b, d + 1)?;
        self.line_height_px.check_budget(b, d + 1)?;
        self.baseline_offset_px.check_budget(b, d + 1)?;
        self.paragraph_spacing_px.check_budget(b, d + 1)?;
        self.letter_spacing_px.check_budget(b, d + 1)?;
        self.revision.check_budget(b, d + 1)?;
        self.decoration.check_budget(b, d + 1)?;
        self.title_top_spacing_px.check_budget(b, d + 1)?;
        self.title_bottom_spacing_px.check_budget(b, d + 1)?;
        self.title_paragraph_spacing_px.check_budget(b, d + 1)?;
        self.title_segment_spacing_px.check_budget(b, d + 1)?;
        self.title_page_center_vertical.check_budget(b, d + 1)?;
        self.column_count.check_budget(b, d + 1)?;
        self.line_spacing_multiplier.check_budget(b, d + 1)?;
        self.continuous_scroll.check_budget(b, d + 1)?;
        self.single_image_style.check_budget(b, d + 1)?;
        self.chapter_end_padding_px.check_budget(b, d + 1)?;
        self.text_bottom_justify.check_budget(b, d + 1)?;
        self.html_line_spacing_add_px.check_budget(b, d + 1)?;
        self.page_underline.check_budget(b, d + 1)?;
        self.inline_images_preserve_scroll_line
            .check_budget(b, d + 1)?;
        self.emphasis_underline_style.check_budget(b, d + 1)?;
        self.cast_options.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutParagraphDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.text.check_budget(b, d + 1)?;
        self.clusters.check_budget(b, d + 1)?;
        self.cluster_widths_px.check_budget(b, d + 1)?;
        self.style.check_budget(b, d + 1)?;
        self.chapter_position.check_budget(b, d + 1)?;
        self.indent_characters.check_budget(b, d + 1)?;
        self.alignment.check_budget(b, d + 1)?;
        self.is_title.check_budget(b, d + 1)?;
        self.link.check_budget(b, d + 1)?;
        self.line_height_px.check_budget(b, d + 1)?;
        self.baseline_offset_px.check_budget(b, d + 1)?;
        self.line_spacing_multiplier.check_budget(b, d + 1)?;
        self.letter_spacing_px.check_budget(b, d + 1)?;
        self.indent_width_px.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutInlineParagraphDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.items.check_budget(b, d + 1)?;
        self.indent_characters.check_budget(b, d + 1)?;
        self.alignment.check_budget(b, d + 1)?;
        self.line_height_px.check_budget(b, d + 1)?;
        self.baseline_offset_px.check_budget(b, d + 1)?;
        self.base_text_size_px.check_budget(b, d + 1)?;
        self.emphasized.check_budget(b, d + 1)?;
        self.title_spacing_scale.check_budget(b, d + 1)?;
        self.line_spacing_multiplier.check_budget(b, d + 1)?;
        self.letter_spacing_px.check_budget(b, d + 1)?;
        self.indent_width_px.check_budget(b, d + 1)?;
        self.rest_line_indent_width_px.check_budget(b, d + 1)?;
        self.leading_indent_items.check_budget(b, d + 1)?;
        self.decorations.check_budget(b, d + 1)?;
        self.justify_at_word_boundaries.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutDecorationKindDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        match self {
            Self::Quote => {}
            Self::Bullet => {}
        };
        Ok(())
    }
}
impl Budget for LayoutParagraphDecorationDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        self.kind.check_budget(b, d + 1)?;
        self.color_argb.check_budget(b, d + 1)?;
        self.size_px.check_budget(b, d + 1)?;
        self.leading_offset_px.check_budget(b, d + 1)?;
        Ok(())
    }
}
impl Budget for LayoutBlockDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        match self {
            Self::Paragraph { value } => {
                value.check_budget(b, d + 1)?;
            }
            Self::InlineParagraph(v) => v.check_budget(b, d + 1)?,
            Self::Image {
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
                source.check_budget(b, d + 1)?;
                intrinsic_width_px.check_budget(b, d + 1)?;
                intrinsic_height_px.check_budget(b, d + 1)?;
                chapter_position.check_budget(b, d + 1)?;
                action.check_budget(b, d + 1)?;
                horizontal_alignment.check_budget(b, d + 1)?;
                scale_mode.check_budget(b, d + 1)?;
                page_break_before.check_budget(b, d + 1)?;
                page_break_after.check_budget(b, d + 1)?;
            }
            Self::BlankLine {
                chapter_position,
                line_height_px,
                line_spacing_multiplier,
            } => {
                chapter_position.check_budget(b, d + 1)?;
                line_height_px.check_budget(b, d + 1)?;
                line_spacing_multiplier.check_budget(b, d + 1)?;
            }
            Self::Rule {
                color_argb,
                width_px,
                vertical_padding_px,
                dashed,
            } => {
                color_argb.check_budget(b, d + 1)?;
                width_px.check_budget(b, d + 1)?;
                vertical_padding_px.check_budget(b, d + 1)?;
                dashed.check_budget(b, d + 1)?;
            }
            Self::PageBreak => {}
        };
        Ok(())
    }
}
impl Budget for LayoutInlineItemDto {
    #[flutter_rust_bridge::frb(ignore)]
    fn check_budget(&self, b: &mut PayloadBudget, d: usize) -> Result<(), BridgeError> {
        b.add(std::mem::size_of::<Self>(), d)?;
        match self {
            Self::Text {
                value,
                width_px,
                style,
                chapter_position,
                link,
                marking_id,
                line_height_px,
                baseline_offset_px,
                baseline_shift_px,
            } => {
                value.check_budget(b, d + 1)?;
                width_px.check_budget(b, d + 1)?;
                style.check_budget(b, d + 1)?;
                chapter_position.check_budget(b, d + 1)?;
                link.check_budget(b, d + 1)?;
                marking_id.check_budget(b, d + 1)?;
                line_height_px.check_budget(b, d + 1)?;
                baseline_offset_px.check_budget(b, d + 1)?;
                baseline_shift_px.check_budget(b, d + 1)?;
            }
            Self::Image {
                source,
                width_px,
                height_px,
                chapter_position,
                action,
                line_final_width_px,
            } => {
                source.check_budget(b, d + 1)?;
                width_px.check_budget(b, d + 1)?;
                height_px.check_budget(b, d + 1)?;
                chapter_position.check_budget(b, d + 1)?;
                action.check_budget(b, d + 1)?;
                line_final_width_px.check_budget(b, d + 1)?;
            }
            Self::RoleCast {
                width_px,
                height_px,
                chapter_position,
                raw,
                name,
                voice_pool_label,
                quote_ordinal,
                voice_effect_mark,
            } => {
                width_px.check_budget(b, d + 1)?;
                height_px.check_budget(b, d + 1)?;
                chapter_position.check_budget(b, d + 1)?;
                raw.check_budget(b, d + 1)?;
                name.check_budget(b, d + 1)?;
                voice_pool_label.check_budget(b, d + 1)?;
                quote_ordinal.check_budget(b, d + 1)?;
                voice_effect_mark.check_budget(b, d + 1)?;
            }
            Self::BgmScene {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                pool_name,
                track_name,
            } => {
                width_px.check_budget(b, d + 1)?;
                height_px.check_budget(b, d + 1)?;
                chapter_position.check_budget(b, d + 1)?;
                paragraph_index.check_budget(b, d + 1)?;
                pool_name.check_budget(b, d + 1)?;
                track_name.check_budget(b, d + 1)?;
            }
            Self::Review {
                width_px,
                height_px,
                chapter_position,
                paragraph_index,
                review_key,
                count,
                baseline_offset_px,
                compact_width_px,
                compact_height_px,
            } => {
                width_px.check_budget(b, d + 1)?;
                height_px.check_budget(b, d + 1)?;
                chapter_position.check_budget(b, d + 1)?;
                paragraph_index.check_budget(b, d + 1)?;
                review_key.check_budget(b, d + 1)?;
                count.check_budget(b, d + 1)?;
                baseline_offset_px.check_budget(b, d + 1)?;
                compact_width_px.check_budget(b, d + 1)?;
                compact_height_px.check_budget(b, d + 1)?;
            }
        };
        Ok(())
    }
}
