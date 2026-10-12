//! 无损传输适配：共享字形样式、压缩重复字段，不参与断行或分页。
use crate::model::{Element, Page, TextStyle};
use base64::{engine::general_purpose::STANDARD, Engine};
use serde::Serialize;
use serde_json::{json, Value};
use std::{collections::HashMap, sync::Arc};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WirePages {
    pub pages: Vec<WirePage>,
    pub text_styles: Vec<Arc<TextStyle>>,
    pub glyphs: WireColumns,
}
#[derive(Default, Serialize)]
pub struct WireColumns {
    count: usize,
    text: String,
    geometry: String,
    positions: String,
    extras: serde_json::Map<String, Value>,
    #[serde(skip)]
    geometry_bytes: Vec<u8>,
    #[serde(skip)]
    position_bytes: Vec<u8>,
    #[serde(skip)]
    text_length: u32,
}
#[derive(Serialize)]
pub struct WirePage {
    #[serde(flatten)]
    metadata: serde_json::Map<String, Value>,
    elements: Vec<WireElement>,
}
#[derive(Serialize)]
#[serde(untagged)]
enum WireElement {
    Text(usize),
    Other(Box<Element>),
}
pub fn pack_pages(pages: Vec<Page>) -> WirePages {
    let mut result = WirePages {
        pages: vec![],
        text_styles: vec![],
        glyphs: WireColumns::default(),
    };
    let mut indices = HashMap::new();
    for mut page in pages {
        let elements = std::mem::take(&mut page.elements);
        let Value::Object(mut metadata) = serde_json::to_value(page).expect("已校验的页面可序列化")
        else {
            unreachable!()
        };
        metadata.remove("elements");
        let elements = elements
            .into_iter()
            .map(|element| {
                pack_element(
                    element,
                    &mut indices,
                    &mut result.text_styles,
                    &mut result.glyphs,
                )
            })
            .collect();
        result.pages.push(WirePage { metadata, elements });
    }
    result.glyphs.geometry = STANDARD.encode(std::mem::take(&mut result.glyphs.geometry_bytes));
    result.glyphs.positions = STANDARD.encode(std::mem::take(&mut result.glyphs.position_bytes));
    result
}
fn pack_element(
    mut element: Element,
    indices: &mut HashMap<usize, usize>,
    styles: &mut Vec<Arc<TextStyle>>,
    columns: &mut WireColumns,
) -> WireElement {
    if element.kind != "text" {
        return WireElement::Other(Box::new(element));
    }
    let text = element.text.take().expect("文字携带已测量字段");
    let style = text.style;
    let pointer = Arc::as_ptr(&style) as usize;
    let index = *indices.entry(pointer).or_insert_with(|| {
        styles
            .iter()
            .position(|s| s.as_ref() == style.as_ref())
            .unwrap_or_else(|| {
                styles.push(style);
                styles.len() - 1
            })
    });
    let mut d = serde_json::Map::new();
    for (key, value) in [
        ("selected", text.selected),
        ("emphasized", text.emphasized),
        ("readAloud", text.read_aloud),
        ("searchResult", text.search_result),
        ("continuesBackgroundRun", text.continues_background_run),
    ] {
        if value {
            d.insert(key.into(), json!(true));
        }
    }
    for (key, value) in [("link", text.link), ("markingId", text.marking_id)] {
        if let Some(value) = value {
            d.insert(key.into(), json!(value));
        }
    }
    if let Some(value) = text.emphasis_underline {
        d.insert("emphasisUnderline".into(), value);
    }
    for (key, value) in [
        ("backgroundFrameTopPx", text.background_frame_top_px),
        ("backgroundFrameBottomPx", text.background_frame_bottom_px),
        ("backgroundFrameLeftPx", text.background_frame_left_px),
        ("backgroundFrameRightPx", text.background_frame_right_px),
    ] {
        if value != 0.0 {
            d.insert(key.into(), json!(value));
        }
    }
    for coordinate in [
        element.bounds.left,
        element.bounds.top,
        element.bounds.right,
        element.bounds.bottom,
        text.baseline_px,
    ] {
        columns
            .geometry_bytes
            .extend_from_slice(&coordinate.to_le_bytes());
    }
    columns.text_length += text.value.encode_utf16().count() as u32;
    columns.text.push_str(&text.value);
    for position in [
        text.chapter_position as u32,
        text.paragraph_index as u32,
        index as u32,
        columns.text_length,
    ] {
        columns
            .position_bytes
            .extend_from_slice(&position.to_le_bytes());
    }
    let glyph_index = columns.count;
    if !d.is_empty() {
        columns
            .extras
            .insert(glyph_index.to_string(), Value::Object(d));
    }
    columns.count += 1;
    WireElement::Text(glyph_index)
}
