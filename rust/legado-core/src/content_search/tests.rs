use super::*;
use serde::Deserialize;

/// 由JDK Pattern执行上游findAll语义录制，避免再维护一份匹配算法。
#[derive(Deserialize)]
struct Case {
    name: String,
    content: String,
    query: String,
    valid: bool,
    ranges: Vec<[usize; 2]>,
}
#[test]
fn regex_ranges_and_snippets_follow_recorded_jvm_cases() {
    let cases: Vec<Case> = serde_json::from_str(include_str!("jvm_cases.json")).unwrap();
    for case in cases {
        let matcher = ContentSearchMatcher::new(&case.query, true);
        assert_eq!(matcher.is_some(), case.valid, "{}", case.name);
        let Some(matcher) = matcher else { continue };
        let hits = matcher.search(&case.content).unwrap();
        assert_eq!(
            hits.iter()
                .map(|h| [h.source_start, h.source_end])
                .collect::<Vec<_>>(),
            case.ranges,
            "{}",
            case.name
        );
        let source = case
            .content
            .replace('\n', " ")
            .encode_utf16()
            .collect::<Vec<_>>();
        for hit in hits {
            let snippet = hit.snippet.encode_utf16().collect::<Vec<_>>();
            assert_eq!(
                snippet[hit.highlight_start..hit.highlight_end],
                source[hit.source_start..hit.source_end],
                "{}",
                case.name
            );
            assert!(String::from_utf16(&snippet[..hit.highlight_start]).is_ok());
            assert!(String::from_utf16(&snippet[hit.highlight_end..]).is_ok());
        }
    }
}
#[test]
fn literal_search_preserves_case_insensitivity_and_original_unicode_coordinates() {
    for (content, query, expected) in [
        ("Abc abc ABC", "abc", vec![(0, 3), (4, 7), (8, 11)]),
        ("甲😀AbC乙", "abc", vec![(3, 6)]),
        ("İ😀ABC", "abc", vec![(3, 6)]),
        ("aaaaa", "aa", vec![(0, 2), (2, 4)]),
        ("正文内容", "不存在", vec![]),
    ] {
        let hits = ContentSearchMatcher::new(query, false)
            .unwrap()
            .search(content)
            .unwrap();
        assert_eq!(
            hits.iter()
                .map(|h| (h.source_start, h.source_end))
                .collect::<Vec<_>>(),
            expected
        );
    }
    assert!(ContentSearchMatcher::new("", false).is_none());
    let text = format!("{}😀命中\n{}", "左".repeat(31), "右".repeat(40));
    let hit = ContentSearchMatcher::new("命中", false)
        .unwrap()
        .search(&text)
        .unwrap()
        .remove(0);
    assert!(hit.snippet.starts_with('…') && hit.snippet.ends_with('…'));
    assert!(!hit.snippet.contains('\n'));
    // 摘要增加省略号或替换换行不改变正文位置。
    assert_eq!((hit.source_start, hit.source_end), (33, 35));
    let text = format!("😀{}命中{}", "左".repeat(29), "右".repeat(40));
    let hit = ContentSearchMatcher::new("命中", false)
        .unwrap()
        .search(&text)
        .unwrap()
        .remove(0);
    assert_eq!(hit.source_start, 31);
    assert!(hit.snippet.starts_with('😀'), "上下文边界不能切开emoji");
    let text = "a".repeat(65);
    assert_eq!(
        ContentSearchMatcher::new("a", false)
            .unwrap()
            .search(&text)
            .unwrap()
            .len(),
        50
    );
}
