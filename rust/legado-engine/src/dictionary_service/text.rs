//! 释义HTML处理：沿用原块级换行与实体转换。
use regex::Regex;
use std::sync::OnceLock;

/// 块级标签（转换为换行）
static BLOCK_TAG_RE: OnceLock<Regex> = OnceLock::new();
/// 任意 HTML 标签（剥离）
static ANY_TAG_RE: OnceLock<Regex> = OnceLock::new();

/// 轻量 HTML → 纯文本转换
///
/// 原版在 WebView 中渲染规则产出的 HTML；本契约 `definitions` 为纯文本
/// 列表，故做保守转换：块级标签转换行 → 剥离剩余标签 → 解码常见实体。
/// 不追求完整 HTML 语义（非本层职责），仅保证释义可读。
pub(super) fn html_to_text(html: &str) -> String {
    let block_re = BLOCK_TAG_RE.get_or_init(|| {
        Regex::new(r"(?i)<br\s*/?>|</(?:p|div|h[1-6]|li|ul|ol|tr|table|section|blockquote)>")
            .expect("块级标签正则编译失败")
    });
    let any_re = ANY_TAG_RE.get_or_init(|| Regex::new(r"<[^>]+>").expect("标签剥离正则编译失败"));

    let s = block_re.replace_all(html, "\n");
    let s = any_re.replace_all(&s, "");
    let s = decode_html_entities(&s);

    // 压缩多余空行并去除行首尾空白
    let mut out = String::with_capacity(s.len());
    let mut blank = false;
    for line in s.lines() {
        let line = line.trim();
        if line.is_empty() {
            if !blank && !out.is_empty() {
                out.push('\n');
                blank = true;
            }
        } else {
            if blank {
                out.push('\n');
            }
            if !out.is_empty() && !out.ends_with('\n') {
                out.push('\n');
            }
            out.push_str(line);
            blank = false;
        }
    }
    out
}

/// 解码常见 HTML 实体（&amp; 最后处理，避免二次解码）
fn decode_html_entities(s: &str) -> String {
    s.replace("&nbsp;", " ")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&apos;", "'")
        .replace("&amp;", "&")
}
