//! 开读媒体识别。基础类型对照上游，视频误标与HTML抽图保留项目既有适配。

use crate::models::{BookSource, book_source_type as st};
use regex::Regex;
use std::sync::LazyLock;

pub const VIDEO: i32 = 4;
pub const TEXT: i32 = 8;
pub const AUDIO: i32 = 32;
pub const IMAGE: i32 = 64;
pub const WEB_FILE: i32 = 128;
pub const MEDIA_MASK: i32 = VIDEO | TEXT | AUDIO | IMAGE | WEB_FILE;

/// 书源类型枚举与书籍媒体位属于不同数值域。
pub fn source_book_type(source_type: i32) -> i32 {
    match source_type {
        st::FILE => TEXT | WEB_FILE,
        st::IMAGE => IMAGE,
        st::AUDIO => AUDIO,
        st::VIDEO => VIDEO,
        _ => TEXT,
    }
}

/// 只输出媒体位，不写库；无书源时保留无媒体位的本地书语义。
pub fn resolve_reading_type(book_type: i32, source: Option<&BookSource>) -> i32 {
    let existing = book_type & MEDIA_MASK;
    let Some(source) = source else {
        return existing;
    };
    if looks_like_video(source) {
        return VIDEO;
    }
    if (st::AUDIO..=st::VIDEO).contains(&source.book_source_type) {
        return source_book_type(source.book_source_type);
    }
    let base = if existing == 0 { TEXT } else { existing };
    if base & (VIDEO | AUDIO | IMAGE) != 0 || !has_image_html_content(source) {
        return base;
    }
    (base & !TEXT) | IMAGE
}

fn looks_like_video(source: &BookSource) -> bool {
    if source.book_source_type == st::VIDEO {
        return true;
    }
    if source.book_source_type != st::TEXT && source.book_source_type != st::IMAGE {
        return false;
    }
    let group = source
        .book_source_group
        .as_deref()
        .unwrap_or("")
        .to_lowercase();
    let name = source.book_source_name.to_lowercase();
    let url = source.book_source_url.to_lowercase();
    let toc = source
        .rule_toc
        .as_ref()
        .and_then(|r| r.chapter_list.as_deref())
        .unwrap_or("")
        .to_lowercase();
    let content = source
        .rule_content
        .as_ref()
        .and_then(|r| r.content.as_deref())
        .unwrap_or("")
        .to_lowercase();
    let source_regex = source
        .rule_content
        .as_ref()
        .and_then(|r| r.source_regex.as_deref())
        .unwrap_or("")
        .to_lowercase();
    let blob = format!(
        "{group}\n{name}\n{url}\n{}\n{}\n{toc}\n{content}\n{source_regex}",
        source.search_url.as_deref().unwrap_or("").to_lowercase(),
        source.explore_url.as_deref().unwrap_or("").to_lowercase()
    );
    if blob.contains("provide/vod") || blob.contains("vod_play_url") {
        return true;
    }
    let video_group = ["影视", "视频源", "视频"].iter().any(|s| group.contains(s));
    let video_name = (name.contains("资源")
        && [
            "红牛", "非凡", "量子", "乌酷", "u酷", "最大", "影视", "视频",
        ]
        .iter()
        .any(|s| name.contains(s)))
        || ["hongniu", "ukuzy", "ffzy", "lzizy", "zuidazy"]
            .iter()
            .any(|s| url.contains(s));
    // 在已转为小写的相同字段上执行原有流媒体与直接返回章节地址规则。
    let stream = |s: &str| {
        ["m3u8", "mp4", "flv", "m3u"]
            .iter()
            .any(|token| s.contains(token))
    };
    static RETURNS_BASE_URL: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"result\s*=\s*baseurl").unwrap());
    ((video_group || video_name)
        && (stream(&content)
            || stream(&source_regex)
            || stream(&toc)
            || RETURNS_BASE_URL.is_match(&content)))
        || ["m3u8", "mp4", "flv"]
            .iter()
            .any(|s| source_regex.contains(s))
}

fn has_image_html_content(source: &BookSource) -> bool {
    let Some(rule) = source.rule_content.as_ref() else {
        return false;
    };
    // Dart trim还包含BOM；迁移不改变既有规则输入的空白边界。
    let trim = |c: char| c.is_whitespace() || c == '\u{feff}';
    let style = rule
        .image_style
        .as_deref()
        .unwrap_or("")
        .trim_matches(trim)
        .to_uppercase();
    if !matches!(style.as_str(), "" | "FULL" | "SINGLE") {
        return false;
    }
    let content = rule
        .content
        .as_deref()
        .unwrap_or("")
        .trim_matches(trim)
        .to_lowercase();
    content.contains("@img@html")
        || content.contains("cp_img@html")
        || (content.encode_utf16().count() <= 120
            && content.contains("@html")
            && ["img", "lazy-read", ".img", "#cp_img"]
                .iter()
                .any(|s| content.contains(s)))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source(json: serde_json::Value) -> BookSource {
        serde_json::from_value(json).unwrap()
    }

    #[test]
    fn source_declarations_and_existing_media_keep_their_priority() {
        for (declaration, expected) in [
            (0, TEXT),
            (1, AUDIO),
            (2, IMAGE),
            (3, TEXT | WEB_FILE),
            (4, VIDEO),
            (99, TEXT),
        ] {
            assert_eq!(source_book_type(declaration), expected);
        }
        assert_eq!(resolve_reading_type(0x1000, None), 0);
        assert_eq!(resolve_reading_type(0x1000 | IMAGE, None), IMAGE);
        for declaration in 1..=4 {
            let source = source(serde_json::json!({"bookSourceType": declaration}));
            assert_eq!(
                resolve_reading_type(TEXT | IMAGE, Some(&source)),
                source_book_type(declaration)
            );
        }
        let source = source(serde_json::json!({}));
        assert_eq!(resolve_reading_type(IMAGE, Some(&source)), IMAGE);
        assert_eq!(resolve_reading_type(0, Some(&source)), TEXT);
    }

    #[test]
    fn known_mislabeled_video_sources_do_not_open_as_comics() {
        for json in [
            serde_json::json!({"bookSourceName":"非凡资源网-www.ffzy.tv", "bookSourceType":0, "searchUrl":"/api.php/provide/vod/?ac=detail&wd={{key}}&pg={{page}}"}),
            serde_json::json!({"bookSourceName":"红牛资源", "bookSourceType":2, "bookSourceGroup":"影视频源", "ruleContent":{"content":"@js:result=/.*\\.m3u8.*/.test(baseUrl)?baseUrl:'';"}}),
            serde_json::json!({"bookSourceUrl":"https://ukuzy.com/", "bookSourceType":2, "ruleContent":{"content":"@js:result=/.*\\.m3u8.*/.test(baseUrl)?baseUrl:'';"}}),
            serde_json::json!({"bookSourceType":0, "ruleContent":{"sourceRegex":".*\\.(m3u8|mp4|flv).*"}}),
            serde_json::json!({"bookSourceGroup":"影视频源", "ruleContent":{"content":"@js:result = baseUrl;"}}),
        ] {
            let source = source(json);
            assert_eq!(
                resolve_reading_type(IMAGE | TEXT, Some(&source)),
                VIDEO,
                "{}",
                source.book_source_name
            );
        }
        for (declaration, expected) in [(st::AUDIO, AUDIO), (st::FILE, TEXT | WEB_FILE)] {
            let source = source(
                serde_json::json!({"bookSourceType":declaration,"searchUrl":"/provide/vod"}),
            );
            assert_eq!(resolve_reading_type(0, Some(&source)), expected);
        }
    }

    #[test]
    fn image_html_promotes_text_only_and_keeps_style_and_utf16_limits() {
        let image = source(
            serde_json::json!({"bookSourceName":"必应漫画","ruleContent":{"content":".img@img@html","imageStyle":"FULL"}}),
        );
        assert_eq!(resolve_reading_type(TEXT, Some(&image)), IMAGE);
        assert_eq!(resolve_reading_type(AUDIO, Some(&image)), AUDIO);
        assert_eq!(resolve_reading_type(VIDEO, Some(&image)), VIDEO);
        assert_eq!(
            resolve_reading_type(TEXT | WEB_FILE, Some(&image)),
            IMAGE | WEB_FILE
        );
        for (content, style, expected) in [
            (".img@img@html".to_owned(), "TEXT", TEXT),
            ("id.content@html".to_owned(), "FULL", TEXT),
            (format!("{}@html img", "a".repeat(200)), "FULL", TEXT),
            (format!("{}@html img", "😀".repeat(56)), "FULL", TEXT),
            (".lazy-read@html".to_owned(), "SINGLE", IMAGE),
        ] {
            let source =
                source(serde_json::json!({"ruleContent":{"content":content,"imageStyle":style}}));
            assert_eq!(resolve_reading_type(0, Some(&source)), expected);
        }
    }
}
