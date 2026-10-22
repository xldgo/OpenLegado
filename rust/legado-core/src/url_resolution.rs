//! 书源规则URL的原文拼接，供解析、搜索和正文图片复用。— Codex + Rust
//! 从AnalyzeUrl提取既有算法；不编码中文、百分号或复合请求头，不承担规则base预处理。

pub fn resolve_rule_url(base: &str, relative: &str) -> String {
    let relative = relative.trim();
    if relative.starts_with("http://")
        || relative.starts_with("https://")
        || relative.starts_with("data:")
    {
        return relative.to_string();
    }

    let base = base.trim();
    if base.is_empty() {
        return relative.to_string();
    }
    if relative.starts_with("//") {
        let scheme = base.find("://").map_or("https", |end| &base[..end]);
        return format!("{scheme}:{relative}");
    }
    if relative.starts_with('/') {
        if let Some(pos) = base.find("://") {
            if let Some(slash_pos) = base[pos + 3..].find('/') {
                let domain = &base[..pos + 3 + slash_pos];
                return format!("{domain}{relative}");
            }
            return format!("{base}{relative}");
        }
        return format!("{}/{relative}", base.trim_end_matches('/'));
    }

    // 纯主机base的末尾斜杠属于协议，不能把它当成目录分隔符。
    if let Some(scheme_end) = base.find("://")
        && !base[scheme_end + 3..].contains('/')
    {
        return format!("{}/{relative}", base.trim_end_matches('/'));
    }
    if base.ends_with('/') {
        format!("{base}{relative}")
    } else if let Some(pos) = base.rfind('/') {
        format!("{}/{relative}", &base[..pos])
    } else {
        format!("{base}/{relative}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn relative_rules_keep_original_query_and_header_bytes() {
        let relative =
            r#"图/封面.jpg?q=中文&raw=%2F,{"headers":{"Referer":"https://原站.example/"}}"#;
        assert_eq!(
            resolve_rule_url("https://example.com/books/chapter", relative),
            format!("https://example.com/books/{relative}")
        );
    }
}
