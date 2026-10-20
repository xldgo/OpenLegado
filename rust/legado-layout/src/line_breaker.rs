//! ChineseLineBreaker.kt 的逐条移植；保留 f32 累计与 Kotlin sumOf(Double) 的区别。
use crate::unicode::latin_word_part;
use crate::{LayoutError, Result};
use serde::{Deserialize, Serialize};

const CLOSING: &[&str] = &[
    "！", "，", "。", "、", "；", "：", "？", "”", "’", "）", "］", "｝", "》", "〉", "〕", "】",
    "〗", "」", "』", "﹂", "﹄", "…", "—", "～", "·", "!", ",", ".", ":", ";", "?", ")", "]", "}",
    ">",
];
const OPENING: &[&str] = &[
    "“", "‘", "（", "［", "｛", "《", "〈", "〔", "【", "〖", "『", "「", "﹁", "﹃", "(", "[",
    "{", "<",
];
pub fn forbidden_break(previous: &str, next: &str) -> bool {
    CLOSING.contains(&next) || OPENING.contains(&previous)
}
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BreakInput {
    pub clusters: Vec<String>,
    pub widths_px: Vec<f32>,
    pub indent_characters: usize,
    pub width_px: i32,
    pub ideograph_width_px: f32,
    pub letter_spacing_px: f32,
    pub first_line_width_px: i32,
}
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct BreakResult {
    pub line_starts: Vec<usize>,
    pub line_cluster_starts: Vec<usize>,
    pub line_widths_px: Vec<f32>,
}
#[derive(PartialEq)]
enum Mode {
    Normal,
    PullPrevious,
    Rewind,
    Hang,
}

/// 保留项目已有中文排版关闭设置；默认中文路径仍按上游逐条执行。
pub fn break_plain(input: &BreakInput) -> Result<BreakResult> {
    if input.clusters.len() != input.widths_px.len()
        || input.widths_px.iter().any(|w| !w.is_finite())
    {
        return Err(LayoutError("朴素断行输入无效".into()));
    }
    let mut result = BreakResult {
        line_starts: vec![0],
        line_cluster_starts: vec![0],
        line_widths_px: vec![],
    };
    let mut width = 0.0;
    let mut offset = 0;
    for (i, c) in input.clusters.iter().enumerate() {
        let limit = if result.line_widths_px.is_empty() {
            input.first_line_width_px
        } else {
            input.width_px
        } as f32
            + input.letter_spacing_px;
        if i > *result.line_cluster_starts.last().unwrap() && width + input.widths_px[i] > limit {
            result.line_widths_px.push(width);
            result.line_cluster_starts.push(i);
            result.line_starts.push(offset);
            width = 0.0;
        }
        width += input.widths_px[i];
        offset += c.encode_utf16().count();
    }
    if !input.clusters.is_empty() {
        result.line_widths_px.push(width);
        result.line_cluster_starts.push(input.clusters.len());
        result.line_starts.push(offset);
    }
    Ok(result)
}
pub fn break_lines(input: &BreakInput) -> Result<BreakResult> {
    let c = &input.clusters;
    let w = &input.widths_px;
    if c.len() != w.len()
        || w.iter().any(|v| !v.is_finite())
        || !input.ideograph_width_px.is_finite()
        || !input.letter_spacing_px.is_finite()
    {
        return Err(LayoutError("断行簇与宽度不匹配或包含非有限值".into()));
    }
    let mut result = BreakResult {
        line_starts: vec![0],
        line_cluster_starts: vec![0],
        line_widths_px: vec![],
    };
    let limit = input.width_px as f32 + input.letter_spacing_px;
    let first_limit = input.first_line_width_px as f32 + input.letter_spacing_px;
    let mut line_width = 0.0f32;
    let mut text_length = 0;
    for (index, cluster) in c.iter().enumerate() {
        let length = cluster.encode_utf16().count();
        line_width += w[index];
        let mut carried_width = 0.0;
        let mut carried_characters = 0;
        let mut carried_clusters = 0;
        let mut hung_line = false;
        let width_limit = if result.line_widths_px.is_empty() {
            first_limit
        } else {
            limit
        };
        if line_width > width_limit {
            let line_start = *result.line_cluster_starts.last().unwrap();
            let previous_closing = index > 0 && CLOSING.contains(&c[index - 1].as_str());
            let previous_opening = index > 0 && OPENING.contains(&c[index - 1].as_str());
            let second_opening = index > 1 && OPENING.contains(&c[index - 2].as_str());
            let next_closing = index + 1 < c.len() && CLOSING.contains(&c[index + 1].as_str());
            let closing = CLOSING.contains(&cluster.as_str());
            let compressible = |at: usize| w[at] < input.ideograph_width_px;
            let compressible_around = if previous_opening && second_opening {
                compressible(index - 1) || compressible(index - 2)
            } else if closing && previous_closing {
                compressible(index) || compressible(index - 1)
            } else if closing && second_opening {
                compressible(index) || compressible(index - 2)
            } else {
                false
            };
            let hangs = index > 0
                && !compressible_around
                && !next_closing
                && ((previous_opening && second_opening)
                    || (closing && (previous_closing || second_opening)));
            let mut mode = if hangs {
                Mode::Hang
            } else if index > 0 && (previous_opening || closing) {
                Mode::PullPrevious
            } else {
                Mode::Normal
            };
            let mut rewind = 0;
            if mode == Mode::PullPrevious && (previous_closing || next_closing) && index > 2 {
                let floor = if result.line_widths_px.is_empty() {
                    input.indent_characters
                } else {
                    line_start
                };
                mode = Mode::Normal;
                for candidate in ((floor + 1)..=index).rev() {
                    if candidate != index {
                        rewind += 1;
                    }
                    if !forbidden_break(&c[candidate - 1], &c[candidate]) {
                        mode = Mode::Rewind;
                        break;
                    }
                }
            }
            if mode == Mode::Hang {
                result.line_starts.push(text_length + length);
                result.line_cluster_starts.push(index + 1);
                hung_line = true;
            } else {
                let candidate = match mode {
                    Mode::PullPrevious => index - 1,
                    Mode::Rewind => index - rewind,
                    _ => index,
                };
                let mut start = candidate;
                if candidate > 0
                    && latin_word_part(&c[candidate])
                    && latin_word_part(&c[candidate - 1])
                {
                    let mut word_start = candidate - 1;
                    while word_start > 0 && latin_word_part(&c[word_start - 1]) {
                        word_start -= 1;
                    }
                    if word_start > line_start && !OPENING.contains(&c[word_start - 1].as_str()) {
                        start = word_start;
                    }
                }
                carried_width = w[start..=index].iter().map(|&v| v as f64).sum::<f64>() as f32;
                carried_characters = c[start..=index]
                    .iter()
                    .map(|v| v.encode_utf16().count())
                    .sum();
                carried_clusters = index - start + 1;
                result
                    .line_starts
                    .push(text_length + length - carried_characters);
                result.line_cluster_starts.push(start);
            }
            result.line_widths_px.push(line_width - carried_width);
            line_width = carried_width;
        }
        if index + 1 == c.len() {
            if result.line_starts.len() == result.line_widths_px.len() + 1 {
                if !hung_line {
                    result.line_starts.push(text_length + length);
                    result.line_cluster_starts.push(index + 1);
                    result.line_widths_px.push(line_width);
                }
            } else if carried_clusters > 0 {
                result
                    .line_starts
                    .push(result.line_starts.last().unwrap() + carried_characters);
                result
                    .line_cluster_starts
                    .push(result.line_cluster_starts.last().unwrap() + carried_clusters);
                result.line_widths_px.push(line_width);
            }
        }
        text_length += length;
    }
    Ok(result)
}
