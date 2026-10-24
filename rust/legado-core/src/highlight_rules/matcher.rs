//! 原文UTF-16区间；按规则顺序返回，重叠部分由后规则覆盖。
use super::{HighlightStyle, normalize_rule};
use crate::{LegadoError, LegadoResult, models::HighlightRule};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HighlightMatch {
    pub start: i32,
    pub end: i32,
    pub style: String,
}

pub fn adapted_pattern(pattern: &str) -> String {
    crate::content_processor::adapt_java_regex(pattern).replace(r"\p{IsHan}", r"\p{Han}")
}

pub fn match_text(
    rules: &[HighlightRule],
    text: &str,
    is_title: bool,
    config_name: Option<&str>,
) -> LegadoResult<Vec<HighlightMatch>> {
    // 字节边界到UTF-16的单遍映射；不逐命中扫描整段前缀。
    let mut offsets = vec![0; text.len() + 1];
    let mut utf16 = 0;
    for (byte, ch) in text.char_indices() {
        offsets[byte] = utf16;
        utf16 += ch.len_utf16() as i32;
        offsets[byte + ch.len_utf8()] = utf16;
    }
    let mut ordered: Vec<_> = rules.iter().filter(|r| r.isEnabled).collect();
    ordered.sort_by_key(|r| r.sortOrder);
    let mut result = Vec::new();
    for rule in ordered {
        let rule = normalize_rule(rule.clone())?;
        let style = HighlightStyle::parse(&rule.style)?;
        if (style.target_scope == 1 && !is_title)
            || (style.target_scope == 2 && is_title)
            || !matches_config(style.config_name.as_deref(), config_name)
        {
            continue;
        }
        let mut push = |start: usize, end: usize| {
            if start < end {
                result.push(HighlightMatch {
                    start: offsets[start],
                    end: offsets[end],
                    style: rule.style.clone(),
                });
            }
        };
        if !rule.isRegex {
            for (start, matched) in text.match_indices(&rule.pattern) {
                push(start, start + matched.len());
            }
        } else {
            let pattern = adapted_pattern(&rule.pattern);
            if let Some(regex) = crate::regex_safe::compile_regex_safe(&pattern) {
                for matched in regex.find_iter(text) {
                    push(matched.start(), matched.end());
                }
            } else if let Some(regex) = crate::regex_safe::compile_fancy_regex_safe(&pattern) {
                for matched in regex.find_iter(text) {
                    let matched = matched.map_err(|e| {
                        LegadoError::Parser(format!("高亮规则「{}」执行失败：{e}", rule.name))
                    })?;
                    push(matched.start(), matched.end());
                }
            }
        }
    }
    resolve_ranges(result)
}

fn matches_config(binding: Option<&str>, current: Option<&str>) -> bool {
    let Some(binding) = binding.filter(|v| !v.trim().is_empty()) else {
        return true;
    };
    serde_json::from_str::<Vec<String>>(binding)
        .is_ok_and(|names| names.iter().any(|n| Some(n.as_str()) == current))
}

/// 事件扫描保证后规则整体覆盖；命中前后间距只留在真实命中边界。
fn resolve_ranges(ranges: Vec<HighlightMatch>) -> LegadoResult<Vec<HighlightMatch>> {
    use std::collections::{BTreeMap, BTreeSet};
    let mut events = BTreeMap::<i32, Vec<(usize, bool)>>::new();
    for (i, r) in ranges.iter().enumerate() {
        events.entry(r.start).or_default().push((i, true));
        events.entry(r.end).or_default().push((i, false));
    }
    let points: Vec<_> = events.keys().copied().collect();
    let mut active = BTreeSet::new();
    let mut result = Vec::new();
    for pair in points.windows(2) {
        let (start, end) = (pair[0], pair[1]);
        for &(index, entering) in &events[&start] {
            if entering {
                active.insert(index);
            } else {
                active.remove(&index);
            }
        }
        if let Some(&winner) = active.last() {
            let original = &ranges[winner];
            let mut style = HighlightStyle::parse(&original.style)?;
            if start != original.start {
                style.letter_spacing_before = 0.0;
            }
            if end != original.end {
                style.letter_spacing_after = 0.0;
            }
            result.push(HighlightMatch {
                start,
                end,
                style: style.json()?,
            });
        }
    }
    Ok(result)
}
