//! 朗读内容与请求长度切分；只消费原文和真实页界，不持有布局或播放会话。
use crate::{
    LegadoError, LegadoResult,
    cloud_tts::{CloudTtsProviderType, CloudTtsSpeechLimits},
};
use legado_layout::model::SourceRange;
use unicode_segmentation::UnicodeSegmentation;

#[derive(Debug, Clone, Copy)]
pub enum SplitMode {
    Paragraph,
    Symbols,
    Page,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ReadAloudUnit {
    pub range: SourceRange,
    pub source_paragraph_index: usize,
    pub is_paragraph_end: bool,
}

const SYMBOLS: &str = "。！？…；，、：.!?;,:";
const DEFAULT_SYMBOLS: &str = "。！？…";
fn whitespace(c: char) -> bool {
    c.is_whitespace() || c == '\u{feff}'
}
fn trim(s: &str) -> &str {
    s.trim_matches(whitespace)
}
fn error(s: &str) -> LegadoError {
    LegadoError::Parser(s.into())
}

/// UTF-16范围与UTF-8字节边界仅在本次输入内转换，不以字符数代替任一索引。
pub fn plan(
    content: &str,
    mode: SplitMode,
    symbols: &str,
    pages: &[SourceRange],
) -> LegadoResult<Vec<ReadAloudUnit>> {
    let mut paragraphs = Vec::new();
    let mut paragraph_texts = Vec::new();
    let mut utf16 = 0;
    for raw in content.split_inclusive(['\r', '\n', '\u{2028}', '\u{2029}']) {
        let text = trim(raw);
        if !text.is_empty() {
            let leading = raw.len() - raw.trim_start_matches(whitespace).len();
            let start = utf16 + raw[..leading].encode_utf16().count();
            paragraphs.push(ReadAloudUnit {
                range: SourceRange {
                    start_offset: start,
                    end_offset: start + text.encode_utf16().count(),
                },
                source_paragraph_index: paragraphs.len(),
                is_paragraph_end: true,
            });
            paragraph_texts.push(text);
        }
        utf16 += raw.encode_utf16().count();
    }
    match mode {
        SplitMode::Paragraph => Ok(paragraphs),
        SplitMode::Page => {
            validate_pages(content, pages)?;
            let mut result = Vec::new();
            let mut starts = pages.iter().map(|p| p.start_offset).peekable();
            for paragraph in paragraphs {
                let mut start = paragraph.range.start_offset;
                while starts.peek().is_some_and(|p| *p <= start) {
                    starts.next();
                }
                while starts
                    .peek()
                    .is_some_and(|p| *p < paragraph.range.end_offset)
                {
                    let end = starts.next().unwrap();
                    if end > start {
                        result.push(ReadAloudUnit {
                            range: SourceRange {
                                start_offset: start,
                                end_offset: end,
                            },
                            is_paragraph_end: false,
                            ..paragraph.clone()
                        });
                    }
                    start = end;
                }
                result.push(ReadAloudUnit {
                    range: SourceRange {
                        start_offset: start,
                        ..paragraph.range
                    },
                    ..paragraph
                });
            }
            Ok(result)
        }
        SplitMode::Symbols => {
            let mut selected: Vec<char> =
                symbols.chars().filter(|&c| SYMBOLS.contains(c)).collect();
            if selected.is_empty() {
                selected.extend(DEFAULT_SYMBOLS.chars());
            }
            let mut result = Vec::new();
            // 只合并连续已选标点；结束引号吸收继续按用户约定暂缓。
            for (paragraph, text) in paragraphs.into_iter().zip(paragraph_texts) {
                let mut start = paragraph.range.start_offset;
                let mut position = 0;
                let mut chars = text.chars().peekable();
                while let Some(c) = chars.next() {
                    position += c.len_utf16();
                    if !selected.contains(&c) {
                        continue;
                    }
                    while chars.peek().is_some_and(|c| selected.contains(c)) {
                        position += chars.next().unwrap().len_utf16();
                    }
                    let end = paragraph.range.start_offset + position;
                    result.push(ReadAloudUnit {
                        range: SourceRange {
                            start_offset: start,
                            end_offset: end,
                        },
                        is_paragraph_end: end == paragraph.range.end_offset,
                        ..paragraph.clone()
                    });
                    start = end;
                }
                if start < paragraph.range.end_offset {
                    result.push(ReadAloudUnit {
                        range: SourceRange {
                            start_offset: start,
                            ..paragraph.range
                        },
                        ..paragraph
                    });
                }
            }
            Ok(result)
        }
    }
}

fn validate_pages(content: &str, pages: &[SourceRange]) -> LegadoResult<()> {
    if pages.is_empty() {
        return Err(error("请先在阅读器完成本章分页，再使用整页朗读"));
    }
    let mut boundaries = std::collections::BTreeMap::from([(0, 0)]);
    let mut offset = 0;
    for (byte, cluster) in content.grapheme_indices(true) {
        offset += cluster.encode_utf16().count();
        boundaries.insert(offset, byte + cluster.len());
    }
    let mut previous = 0;
    for page in pages {
        if page.start_offset < previous
            || page.end_offset < page.start_offset
            || !boundaries.contains_key(&page.start_offset)
            || !boundaries.contains_key(&page.end_offset)
            || !trim(&content[boundaries[&previous]..boundaries[&page.start_offset]]).is_empty()
        {
            return Err(error("朗读页面范围与当前章节不一致"));
        }
        previous = page.end_offset;
    }
    if !trim(&content[boundaries[&previous]..]).is_empty() {
        return Err(error("本章分页尚未完成"));
    }
    Ok(())
}

pub fn partition(
    provider: CloudTtsProviderType,
    texts: &[String],
) -> LegadoResult<Vec<Vec<SourceRange>>> {
    texts
        .iter()
        .map(|text| partition_with_limits(text, provider.speech_limits()))
        .collect()
}

fn partition_with_limits(
    text: &str,
    limits: CloudTtsSpeechLimits,
) -> LegadoResult<Vec<SourceRange>> {
    let limit = limits.max_utf16_units as usize;
    let clusters: Vec<&str> = text.graphemes(true).collect();
    let mut offsets = vec![0];
    let mut bytes = vec![0];
    for cluster in &clusters {
        let len = cluster.encode_utf16().count();
        if len > limit {
            return Err(error("单个字形簇超过云端朗读长度限制"));
        }
        if limits
            .max_utf8_bytes
            .is_some_and(|max| cluster.len() > max as usize)
        {
            return Err(error("单个字形簇超过云端朗读字节限制"));
        }
        offsets.push(offsets.last().unwrap() + len);
        bytes.push(bytes.last().unwrap() + cluster.len());
    }
    let mut result = Vec::new();
    let mut start = 0;
    while start < clusters.len() {
        let mut end = start;
        while end < clusters.len()
            && offsets[end + 1] - offsets[start] <= limit
            && limits
                .max_utf8_bytes
                .is_none_or(|max| bytes[end + 1] - bytes[start] <= max as usize)
        {
            end += 1;
        }
        let mut cut = end;
        if end < clusters.len() {
            let (mut sentence, mut word) = (None, None);
            for i in start + 1..=end {
                let left = clusters[i - 1];
                let right = clusters[i];
                let mut punctuation = Some(i - 1);
                while let Some(p) = punctuation {
                    if p < start || !"”’」』）)]".contains(clusters[p]) {
                        break;
                    }
                    punctuation = p.checked_sub(1);
                }
                if let Some(p) = punctuation.filter(|&p| p >= start)
                    && "。！？…!?；;.".contains(clusters[p])
                    && !"。！？…!?；;.”’」』）)]".contains(right)
                    && !(clusters[p] == "."
                        && p > start
                        && ascii_digit(clusters[p - 1])
                        && ascii_digit(right))
                {
                    sentence = Some(i);
                }
                if !"。！？…!?；;.”’」』）)]".contains(right)
                    && (trim(left).is_empty()
                        || trim(right).is_empty()
                        || (!latin(left) && !latin(right)))
                {
                    word = Some(i);
                }
            }
            cut = sentence.or(word).unwrap_or(end);
        }
        result.push(SourceRange {
            start_offset: offsets[start],
            end_offset: offsets[cut],
        });
        start = cut;
    }
    Ok(result)
}
fn latin(s: &str) -> bool {
    s.chars().any(|c| c.is_ascii_alphanumeric())
}
fn ascii_digit(s: &str) -> bool {
    s.len() == 1 && s.as_bytes()[0].is_ascii_digit()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{Value, json};

    #[test]
    fn preserves_recorded_app_contract() {
        let cases: Vec<Value> = serde_json::from_str(include_str!(
            "../../../flutter_legado/test/fixtures/read_aloud_partition_cases.json"
        ))
        .unwrap();
        for case in cases {
            let text = case["text"].as_str().unwrap();
            if case["kind"] == "plan" {
                let mode = match case["mode"].as_str().unwrap() {
                    "paragraph" => SplitMode::Paragraph,
                    "symbols" => SplitMode::Symbols,
                    "page" => SplitMode::Page,
                    _ => unreachable!(),
                };
                let pages: Vec<_> = case["pages"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|p| SourceRange {
                        start_offset: p["start"].as_u64().unwrap() as usize,
                        end_offset: p["end"].as_u64().unwrap() as usize,
                    })
                    .collect();
                let result = plan(text, mode, case["symbols"].as_str().unwrap(), &pages);
                if case.get("error").is_some() {
                    assert!(result.is_err(), "{case}");
                    continue;
                }
                let units: Vec<_> = result.unwrap().iter().map(|u| json!({"start":u.range.start_offset,"end":u.range.end_offset,"paragraph":u.source_paragraph_index,"last":u.is_paragraph_end})).collect();
                assert_eq!(json!(units), case["units"], "{case}");
            } else {
                let limit = case["limit"].as_i64().unwrap();
                let limits = CloudTtsSpeechLimits {
                    max_utf16_units: limit as u32,
                    max_utf8_bytes: case["bytes"].as_u64().map(|v| v as u32),
                };
                let result = partition_with_limits(text, limits);
                if case.get("error").is_some() {
                    assert!(result.is_err(), "{case}");
                    continue;
                }
                let ranges: Vec<_> = result
                    .unwrap()
                    .iter()
                    .map(|r| json!({"start":r.start_offset,"end":r.end_offset}))
                    .collect();
                assert_eq!(json!(ranges), case["ranges"], "{case}");
            }
        }
    }

    #[test]
    fn provider_batch_ranges_preserve_graphemes_and_input_order() {
        let text = format!(
            "{}😀{} e\u{301} 👨‍👩‍👧‍👦 English words。末尾",
            "甲".repeat(340),
            "乙".repeat(400)
        );
        let texts = vec![text.clone(), String::new(), "hello world".into()];
        for provider in CloudTtsProviderType::ALL {
            let result = partition(provider, &texts).unwrap();
            assert_eq!(result.len(), texts.len());
            for (input, ranges) in texts.iter().zip(result) {
                let mut previous = 0;
                let mut bytes = 0;
                let mut utf16 = 0;
                let mut boundaries = std::collections::BTreeMap::from([(0, 0)]);
                for g in input.graphemes(true) {
                    bytes += g.len();
                    utf16 += g.encode_utf16().count();
                    boundaries.insert(utf16, bytes);
                }
                for r in ranges {
                    assert_eq!(r.start_offset, previous);
                    let part = &input[boundaries[&r.start_offset]..boundaries[&r.end_offset]];
                    assert!(
                        r.end_offset - r.start_offset
                            <= provider.speech_limits().max_utf16_units as usize
                    );
                    if let Some(max) = provider.speech_limits().max_utf8_bytes {
                        assert!(part.len() <= max as usize);
                    }
                    previous = r.end_offset;
                }
                assert_eq!(previous, input.encode_utf16().count());
            }
        }
    }
}
