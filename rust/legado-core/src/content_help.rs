//! 对齐原版 ContentHelp 的正文重新分段，不参与排版或朗读请求分片。
//! 原版 363540972 / HapeLee c4182eb9b：引号及词条判断、概率长段切分和对话整理。
use regex::Regex;
use std::sync::LazyLock;

const END: &str = "？。！?!~";
const END_P: &str = ".？。！?!~";
const MID: &str = ".，、,—…";
const SAY: &str = "问说喊唱叫骂道着答";
const BEFORE: &str = "，：,:";
const QUOTES: &str = "\"“”";
const RIGHT: &str = "\"”";
const WORD_MAX: isize = 16;

// Java Regex 默认的 \s 仅包含 ASCII 空白，不以 Rust 的 Unicode \s 替代。
const SPACE: &str = r"[ \t\n\x0B\f\r]";
static PRE: LazyLock<Vec<(Regex, &str)>> = LazyLock::new(|| {
    patterns(&[
        (r"&quot;", "“"),
        (r#"[:：]['"‘”“]+"#, "：“"),
        (r#"["”“]+\s*["”“][\s"”“]*"#, "”\n“"),
    ])
});
static JOINED: LazyLock<Vec<(Regex, &str)>> = LazyLock::new(|| {
    patterns(&[
        (r#"["”“]+\s*["”“]+"#, "”\n“"),
        (r#"["”“]+(？。！?!~)["”“]+"#, "”$1\n“"),
        (r#"["”“]+(？。！?!~)([^"”“])"#, "”$1\n$2"),
        (r"([问说喊唱叫骂道着答])[\.。]", "$1。\n"),
    ])
});
static FINAL: LazyLock<Vec<(Regex, &str)>> = LazyLock::new(|| {
    patterns(&[
        (r#"\s*["”“]+\s*["”“][\s"”“]*"#, "”\n“"),
        (r#"[:：][”“"\s]+"#, "：“"),
        (
            r#"\n["“”]([^\n"“”]+)([,:，：]["”“])([^\n"“”]+)"#,
            "\n$1：“$3",
        ),
        (r"\n(\s*)", "\n"),
    ])
});
static LINE_SPLIT: LazyLock<Regex> = LazyLock::new(|| java_regex(r"\n(\s*)"));
static INTERNAL_SPACE: LazyLock<Regex> = LazyLock::new(|| java_regex(r"[\u3000\s]+"));
static LEADING_SPACE: LazyLock<Regex> = LazyLock::new(|| java_regex(r"^\s+"));
static DICTIONARY: LazyLock<fancy_regex::Regex> = LazyLock::new(|| {
    fancy_regex::Regex::new(r#"(?<=["'”“])([^\n\p{P}]{1,16})(?=["'”“])"#).expect("固定词条正则合法")
});

fn java_regex(pattern: &str) -> Regex {
    let mut expanded = String::new();
    let mut in_class = false;
    let mut chars = pattern.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(escaped) = chars.next() {
                if escaped == 's' {
                    expanded.push_str(if in_class { r" \t\n\x0B\f\r" } else { SPACE });
                } else {
                    expanded.push('\\');
                    expanded.push(escaped);
                }
            }
        } else {
            if c == '[' {
                in_class = true;
            } else if c == ']' {
                in_class = false;
            }
            expanded.push(c);
        }
    }
    Regex::new(&expanded).expect("固定分段正则合法")
}
fn patterns(items: &[(&str, &'static str)]) -> Vec<(Regex, &'static str)> {
    items.iter().map(|(p, r)| (java_regex(p), *r)).collect()
}
fn replace_all(mut text: String, rules: &[(Regex, &str)]) -> String {
    for (pattern, replacement) in rules {
        text = pattern.replace_all(&text, *replacement).into_owned();
    }
    text
}
fn mark(key: &str, unit: u16) -> bool {
    key.encode_utf16().any(|c| c == unit)
}
fn decode(units: &[u16]) -> String {
    String::from_utf16(units).expect("断点位于换行、标点或引号，不拆分UTF-16代理对")
}

/// 输入原始章节正文；概率断点与上游一样，每次处理不保证完全相同。
pub fn re_segment(content: &str, chapter_name: &str) -> String {
    re_segment_with_random(content, chapter_name, &mut fastrand::f64)
}

fn re_segment_with_random(
    content: &str,
    chapter_name: &str,
    random: &mut impl FnMut() -> f64,
) -> String {
    if content.is_empty() {
        return String::new();
    }
    let dictionary = make_dict(content);
    let text = replace_all(content.to_owned(), &PRE);
    let lines: Vec<_> = LINE_SPLIT.split(&text).collect();
    let mut joined = String::from("  ");
    if chapter_name.trim_matches(|c| c <= ' ') != lines[0].trim_matches(|c| c <= ' ') {
        joined.push_str(&INTERNAL_SPACE.replace_all(lines[0], ""));
    }
    for line in &lines[1..] {
        let mut tail = joined.chars().rev();
        if let Some(last) = tail.next()
            && (END.contains(last)
                || (RIGHT.contains(last) && tail.next().is_some_and(|c| END.contains(c))))
        {
            joined.push('\n');
        }
        joined.push_str(&INTERNAL_SPACE.replace_all(line, ""));
    }
    let text = replace_all(joined, &JOINED);
    let mut separated = String::new();
    for line in text.split('\n') {
        separated.push('\n');
        separated.push_str(&find_new_lines(line, &dictionary, random));
    }
    let text = reduce_dialogue(&separated);
    let text = LEADING_SPACE.replace(&text, "").into_owned();
    replace_all(text, &FINAL)
}

fn make_dict(text: &str) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    let mut dictionary = Vec::new();
    for matched in DICTIONARY.find_iter(text) {
        let word = matched.expect("固定且有界的词条匹配").as_str();
        if !seen.insert(word) && !dictionary.iter().any(|w| w == word) {
            dictionary.push(word.to_owned());
        }
    }
    dictionary
}

// 以下位置均为 Kotlin Char 对应的 UTF-16 偏移，不能混用 UTF-8 字节或 Unicode 标量下标。
fn seek_index(text: &[u16], key: &str, from: isize, to: isize, forward: bool) -> Option<usize> {
    let end = if to > 0 {
        (to as usize).min(text.len())
    } else {
        text.len()
    };
    ((from.max(0) as usize)..end)
        .find(|&i| mark(key, text[if forward { i } else { text.len() - i - 1 }]))
}
fn seek_indexes(text: &[u16], key: &str, to: isize) -> Vec<usize> {
    let end = if to > 0 {
        (to as usize).min(text.len())
    } else {
        text.len()
    };
    let mut positions = Vec::new();
    for (i, &unit) in text[..end].iter().enumerate() {
        if mark(key, unit) {
            if positions.last().is_some_and(|&last| i - last == 1) {
                *positions.last_mut().unwrap() = i;
            } else {
                positions.push(i);
            }
        }
    }
    positions
}
fn seek_last(text: &[u16], key: &str, from: isize, to: isize) -> Option<usize> {
    if from < 0 || from >= text.len() as isize {
        return None;
    }
    ((to.max(0) as usize + 1)..=from as usize)
        .rev()
        .find(|&i| mark(key, text[i]))
}
fn force_split(
    text: &[u16],
    offset: usize,
    min: usize,
    gain: usize,
    trigger: usize,
    random: &mut impl FnMut() -> f64,
) -> Vec<usize> {
    let ends = seek_indexes(text, END_P, text.len() as isize - 2);
    let mids = seek_indexes(text, MID, text.len() as isize - 2);
    if ends.len() < trigger && mids.len() < trigger * 3 {
        return Vec::new();
    }
    let (mut i, mut j) = (min, 0);
    let mut result = Vec::new();
    while i < ends.len() {
        let mut count = 0;
        while j < mids.len() {
            if mids[j] < ends[i] {
                count += 1;
            }
            j += 1;
        }
        if random() * (gain as f64) < 0.8 + count as f64 / 2.5 {
            result.push(ends[i] + offset);
            i += min;
        }
        i += 1;
    }
    result
}
fn split_quote(text: &str) -> String {
    let units: Vec<_> = text.encode_utf16().collect();
    let len = units.len();
    if len < 3 {
        return text.to_owned();
    }
    let split = if mark(QUOTES, units[0]) {
        seek_index(&units, QUOTES, 1, len as isize - 2, true).map(|i| i + 1)
    } else if mark(QUOTES, units[len - 1]) {
        seek_index(&units, QUOTES, 1, len as isize - 2, false).map(|i| len - 1 - i)
    } else {
        None
    };
    if let Some(i) = split
        && i > 1
        && !mark(BEFORE, units[i - 1])
    {
        return format!("{}\n{}", decode(&units[..i]), decode(&units[i..]));
    }
    text.to_owned()
}
fn reduce_dialogue(text: &str) -> String {
    let mut lines: Vec<String> = text.split('\n').map(str::to_owned).collect();
    let dialogue: Vec<_> = lines
        .iter()
        .map(|s| {
            let units: Vec<_> = s.encode_utf16().collect();
            units.len() >= 3
                && mark(QUOTES, units[0])
                && mark(QUOTES, units[units.len() - 1])
                && !units[1..units.len() - 1].iter().any(|&c| mark(QUOTES, c))
        })
        .collect();
    let mut consecutive = 0;
    for i in 0..lines.len() {
        if dialogue[i] {
            if consecutive < 0 {
                consecutive = 1;
            } else if consecutive < 2 {
                consecutive += 1;
            }
        } else if consecutive > 1 {
            lines[i] = split_quote(&lines[i]);
            consecutive -= 1;
        } else if consecutive > 0 && i + 2 < lines.len() && dialogue[i + 1] {
            lines[i] = split_quote(&lines[i]);
        }
    }
    format!("\n{}", lines.join("\n"))
}

fn find_new_lines(text: &str, dictionary: &[String], random: &mut impl FnMut() -> f64) -> String {
    let original: Vec<_> = text.encode_utf16().collect();
    let mut string = original.clone();
    let mut quotes = Vec::new();
    let mut breaks = Vec::new();
    let mut modes = vec![0; original.len()];
    let mut wait_close = false;
    for (i, &unit) in original.iter().enumerate() {
        if !mark(QUOTES, unit) {
            continue;
        }
        let size = quotes.len();
        if let Some(&previous) = quotes.last()
            && i - previous == 2
        {
            let separators = if wait_close {
                ",，、/"
            } else {
                ",，、/和与或"
            };
            if mark(separators, original[i - 1]) {
                string[i] = '“' as u16;
                string[i - 2] = '”' as u16;
                quotes.pop();
                modes[size - 1] = 1;
                modes[size] = -1;
                continue;
            }
        }
        quotes.push(i);
        if i <= 1 {
            continue;
        }
        let before = original[i - 1];
        if mark(BEFORE, before) {
            if quotes.len() > 1 {
                let last_quote = quotes[quotes.len() - 2];
                let mut p = 0;
                let mut previous_before = 0;
                if mark(",，", before) && quotes.len() > 2 {
                    p = quotes[quotes.len() - 3];
                    if p > 0 {
                        previous_before = original[p - 1];
                    }
                }
                if mark(END_P, previous_before) {
                    breaks.push(p - 1);
                } else if !mark("的", previous_before) {
                    breaks.push(
                        seek_last(&original, END, i as isize, last_quote as isize)
                            .unwrap_or(last_quote),
                    );
                }
            }
            wait_close = true;
            modes[size] = 1;
            if size > 0 {
                modes[size - 1] = -1;
                if size > 1 {
                    modes[size - 2] = 1;
                }
            }
        } else if wait_close {
            wait_close = false;
            breaks.push(i);
        }
    }
    let size = quotes.len();
    let mut opened = false;
    if size > 0 {
        for (i, mode) in modes[..size].iter_mut().enumerate() {
            if *mode > 0 {
                opened = true;
            } else if *mode < 0 {
                if !opened && i > 0 {
                    *mode = 3;
                }
                opened = false;
            } else {
                opened = !opened;
                *mode = if opened { 2 } else { -2 };
            }
        }
        if opened {
            if quotes[size - 1] + 3 > string.len() {
                if size > 1 {
                    modes[size - 2] = 4;
                }
                modes[size - 1] = -4;
            } else if !mark(SAY, string[string.len() - 2]) {
                string.push('”' as u16);
            }
        }
        let mut previous_mode = if quotes[0] == 0 { 0 } else { -1 };
        let start = usize::from(quotes[0] == 0);
        for i in start..size {
            let j = quotes[i] - 1;
            if previous_mode < 0 && modes[i] > 0 && mark(END, string[j]) {
                breaks.push(j);
            }
            previous_mode = modes[i];
        }
    }
    breaks.retain(|&i| {
        if mark("\"'”“", string[i])
            && let Some(start) =
                seek_last(&original, "\"'”“", i as isize - 1, i as isize - WORD_MAX)
            && (dictionary.contains(&decode(&original[start + 1..i]))
                || mark("的地得", original[start]))
        {
            return false;
        }
        true
    });
    breaks.sort_unstable();
    breaks.dedup();
    let (mut j, mut progress) = (0, 0);
    let mut next_line = breaks.first().copied();
    let (mut min, mut gain, mut trigger) = (0, 3, 2);
    for &quote in &quotes {
        (min, gain, trigger) = if quote > 0 { (2, 4, 4) } else { (0, 3, 2) };
        while j < breaks.len() {
            if next_line.is_some_and(|n| n >= quote) {
                break;
            }
            let next = breaks[j];
            next_line = Some(next);
            if progress < next {
                breaks.extend(force_split(
                    &string[progress..next],
                    progress,
                    min,
                    gain,
                    trigger,
                    random,
                ));
                progress = next + 1;
            }
            j += 1;
        }
        if progress < quote {
            breaks.extend(force_split(
                &string[progress..=quote],
                progress,
                min,
                gain,
                trigger,
                random,
            ));
            progress = quote + 1;
        }
    }
    while j < breaks.len() {
        let next = breaks[j];
        if progress < next {
            breaks.extend(force_split(
                &string[progress..next],
                progress,
                min,
                gain,
                trigger,
                random,
            ));
            progress = next + 1;
        }
        j += 1;
    }
    if progress < string.len() {
        breaks.extend(force_split(
            &string[progress..],
            progress,
            min,
            gain,
            trigger,
            random,
        ));
    }
    let mut insert_quote = vec![false; size];
    opened = false;
    for i in 0..size {
        let p = quotes[i];
        if modes[i] > 0 {
            string[p] = '“' as u16;
            insert_quote[i] = opened;
            opened = true;
        } else if modes[i] < 0 {
            string[p] = '”' as u16;
            opened = false;
        } else {
            opened = !opened;
            string[p] = if opened { '“' as u16 } else { '”' as u16 };
        }
    }
    breaks.sort_unstable();
    breaks.dedup();
    let (mut j, mut progress) = (0, 0);
    let mut next_line = breaks.first().copied();
    let mut buffer = Vec::new();
    for (i, &quote) in quotes.iter().enumerate() {
        while j < breaks.len() {
            if next_line.is_some_and(|n| n >= quote) {
                break;
            }
            let next = breaks[j];
            next_line = Some(next);
            buffer.extend_from_slice(&string[progress..=next]);
            buffer.push('\n' as u16);
            progress = next + 1;
            j += 1;
        }
        if progress < quote {
            buffer.extend_from_slice(&string[progress..=quote]);
            progress = quote + 1;
        }
        if insert_quote[i] && buffer.len() > 2 {
            if buffer.last() == Some(&('\n' as u16)) {
                buffer.push('“' as u16);
            } else {
                buffer.splice(
                    buffer.len() - 1..buffer.len() - 1,
                    ['”' as u16, '\n' as u16],
                );
            }
        }
    }
    while j < breaks.len() {
        let next = breaks[j];
        if progress <= next {
            buffer.extend_from_slice(&string[progress..=next]);
            buffer.push('\n' as u16);
            progress = next + 1;
        }
        j += 1;
    }
    if progress < string.len() {
        buffer.extend_from_slice(&string[progress..]);
    }
    decode(&buffer)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upstream_resegment_examples() {
        let fixtures: serde_json::Value =
            serde_json::from_str(include_str!("../tests/fixtures/content_resegment.json")).unwrap();
        for item in fixtures.as_array().unwrap() {
            let random = item["random"].as_f64().unwrap();
            let actual = re_segment_with_random(
                item["input"].as_str().unwrap(),
                item["title"].as_str().unwrap(),
                &mut || random,
            );
            assert_eq!(
                actual,
                item["expected"].as_str().unwrap(),
                "{}",
                item["name"]
            );
        }
        assert_eq!(re_segment("", ""), "");
    }
}
