//! 正文搜索只计算匹配、摘要和UTF-16位置，章节IO由调用方拥有。— Codex + Rust
use crate::regex_safe::{compile_fancy_regex_safe, compile_regex_safe};
use crate::{LegadoError, LegadoResult};
use std::sync::Arc;

const MAX_CHAPTER_HITS: usize = 50;
const CONTEXT_UNITS: usize = 30;

pub enum ContentSearchMatcher {
    Literal(String),
    Regex(Arc<regex::Regex>),
    Fancy(Box<fancy_regex::Regex>),
}
#[derive(Debug, PartialEq, Eq)]
pub struct ContentSearchHit {
    pub source_start: usize,
    pub source_end: usize,
    pub snippet: String,
    pub highlight_start: usize,
    pub highlight_end: usize,
}
impl ContentSearchMatcher {
    /// 非法正则按上游不搜索；不将执行错误混同为无命中。
    pub fn new(query: &str, use_regex: bool) -> Option<Self> {
        if query.is_empty() {
            return None;
        }
        if !use_regex {
            return Some(Self::Literal(query.to_lowercase()));
        }
        if let Some(regex) = compile_regex_safe(query) {
            return Some(Self::Regex(regex));
        }
        compile_fancy_regex_safe(query).map(|r| Self::Fancy(Box::new(r)))
    }
    pub fn search(&self, content: &str) -> LegadoResult<Vec<ContentSearchHit>> {
        let ranges: Vec<(usize, usize)> = match self {
            Self::Regex(re) => re
                .find_iter(content)
                .take(MAX_CHAPTER_HITS)
                .map(|m| (m.start(), m.end()))
                .collect(),
            Self::Fancy(re) => re
                .find_iter(content)
                .take(MAX_CHAPTER_HITS)
                .map(|m| {
                    m.map(|m| (m.start(), m.end()))
                        .map_err(|e| LegadoError::Parser(format!("正文搜索正则执行失败: {e}")))
                })
                .collect::<LegadoResult<_>>()?,
            Self::Literal(query) => literal_ranges(content, query),
        };
        if ranges.is_empty() {
            return Ok(Vec::new());
        }
        // 一次建立UTF-8字节与UTF-16的边界映射，命中及上下文复用。
        let mut units = 0;
        let mut boundaries = content
            .char_indices()
            .map(|(byte, c)| {
                let boundary = (byte, units);
                units += c.len_utf16();
                boundary
            })
            .collect::<Vec<_>>();
        boundaries.push((content.len(), units));
        Ok(ranges
            .into_iter()
            .map(|(start, end)| render_hit(content, &boundaries, start, end))
            .collect())
    }
}

/// 保留普通搜索忽略大小写；扩展字符的小写长度变化不能污染原文位置。
fn literal_ranges(content: &str, query: &str) -> Vec<(usize, usize)> {
    let folded = content.to_lowercase();
    let mut folded_end = 0;
    let segments = content
        .char_indices()
        .map(|(start, c)| {
            folded_end += c.to_lowercase().map(char::len_utf8).sum::<usize>();
            (folded_end, start, start + c.len_utf8())
        })
        .collect::<Vec<_>>();
    folded
        .match_indices(query)
        .take(MAX_CHAPTER_HITS)
        .map(|(start, value)| {
            let first = segments.partition_point(|s| s.0 <= start);
            let last = segments.partition_point(|s| s.0 < start + value.len());
            (segments[first].1, segments[last].2)
        })
        .collect()
}
fn render_hit(
    content: &str,
    bounds: &[(usize, usize)],
    start: usize,
    end: usize,
) -> ContentSearchHit {
    let first = bounds.binary_search_by_key(&start, |b| b.0).unwrap();
    let last = bounds.binary_search_by_key(&end, |b| b.0).unwrap();
    let source_start = bounds[first].1;
    let source_end = bounds[last].1;
    let left = bounds
        .partition_point(|b| b.1 <= source_start.saturating_sub(CONTEXT_UNITS))
        .saturating_sub(1);
    let right = bounds.partition_point(|b| b.1 < source_end.saturating_add(CONTEXT_UNITS));
    let right = right.min(bounds.len() - 1);
    let mut snippet = String::new();
    if left > 0 {
        snippet.push('…');
    }
    snippet.push_str(&content[bounds[left].0..bounds[right].0].replace('\n', " "));
    if right < bounds.len() - 1 {
        snippet.push('…');
    }
    let highlight_start = source_start - bounds[left].1 + usize::from(left > 0);
    ContentSearchHit {
        source_start,
        source_end,
        snippet,
        highlight_start,
        highlight_end: highlight_start + source_end - source_start,
    }
}

#[cfg(test)]
mod tests;
