//! 参照原版BookSourceImportTest组织完整书源场景，不逐字段机械生成测试。
//! 批量正文规则往返复用ContentRuleCompatibilityTest样例，由实际FFI用例覆盖。
//! 本文件保留Rust特有转换约定与已确认的编辑回填、空值和错误定位回归。

use legado_core::models::book_source::{parse_source_array, parse_source_json};
use serde_json::json;

#[test]
fn 完整书源归一化_单对象与批量入口一致() {
    let document = r#"{
        "bookSourceUrl":"https://source.example","bookSourceName":12,
        "bookSourceType":"1","customOrder":"12","weight":"2",
        "enabled":"false","eventListener":1,"customButton":"0",
        "lastUpdateTime":"1792486038190","respondTime":null,
        "header":{"X-Test":"1"},"variable":true,
        "exploreUrl":"[{'title':'科幻','url':'/lists/71.html'}]",
        "ruleSearch":"{\"bookList\":\".book\",\"name\":\".name\"}",
        "ruleToc":{"chapterList":[1,2],"isVolume":false},
        "ruleContent":{"content":"@js:return result;"},
        "ruleReview":{"enabled":"true","reviewUrl":"/reviews"}
    }"#;
    let expected = json!({
        "bookSourceUrl":"https://source.example","bookSourceName":"12",
        "bookSourceType":1,"customOrder":12,"weight":2,
        "enabled":false,"enabledExplore":true,"enabledCookieJar":true,
        "eventListener":true,"customButton":false,
        "lastUpdateTime":1792486038190_i64,"respondTime":180000,
        "header":"{\"X-Test\":\"1\"}","variable":"true",
        "exploreUrl":"[{'title':'科幻','url':'/lists/71.html'}]",
        "ruleSearch":{"bookList":".book","name":".name"},
        "ruleToc":{"chapterList":"[1,2]","isVolume":"false"},
        "ruleContent":{"content":"@js:return result;"},
        "ruleReview":{"enabled":true,"reviewUrl":"/reviews"}
    });
    assert_eq!(
        serde_json::to_value(parse_source_json(document).unwrap()).unwrap(),
        expected
    );
    for input in [document.to_owned(), format!("[{document}]")] {
        let sources = parse_source_array(&input).unwrap();
        assert_eq!(serde_json::to_value(sources).unwrap(), json!([expected]));
    }
}

#[test]
fn 缺省与显式空值_保留默认和关闭语义() {
    for document in [
        "{}",
        r#"{"enabled":null,"enabledExplore":null,"eventListener":null,"customButton":null,"respondTime":null,"lastUpdateTime":null,"bookSourceType":null,"customOrder":null,"weight":null}"#,
    ] {
        let source = parse_source_json(document).unwrap();
        assert!(source.enabled && source.enabled_explore);
        assert_eq!(
            (source.respond_time, source.enabled_cookie_jar),
            (180000, Some(true))
        );
        assert_eq!(
            (
                source.last_update_time,
                source.book_source_type,
                source.custom_order,
                source.weight
            ),
            (0, 0, 0, 0)
        );
        assert!(!source.event_listener && !source.custom_button);
    }
    let source = parse_source_json(r#"{"bookSourceUrl":null,"bookSourceName":null,"variable":null,"header":null,"enabledCookieJar":null,"ruleToc":[],"ruleSearch":{},"ruleReview":"{\"enabled\":null}"}"#).unwrap();
    assert!(
        source.book_source_url.is_empty()
            && source.book_source_name.is_empty()
            && source.variable.is_empty()
    );
    assert_eq!((source.header, source.enabled_cookie_jar), (None, None));
    assert!(source.rule_toc.is_none() && source.rule_search.is_some());
    assert!(!source.rule_review.unwrap().enabled);
}

#[test]
fn 编辑回填只消费数组首项() {
    let source = parse_source_json(r#"[{"bookSourceName":"首项"},42]"#).unwrap();
    assert_eq!(source.book_source_name, "首项");
    assert!(
        parse_source_json("[]")
            .unwrap_err()
            .to_string()
            .contains("为空")
    );
    assert!(
        parse_source_json("[42]")
            .unwrap_err()
            .to_string()
            .contains("对象")
    );
}

#[test]
fn 解析失败保留语法结构与嵌套字段位置() {
    // 每项代表一种不同的失败路径，不穷举每个字段的同类输入。
    for (document, markers) in [
        (r#"{"bookSourceUrl":"#, &["语法"][..]),
        ("true", &["数组或对象"][..]),
        (r#"{"customOrder":"bad"}"#, &["customOrder"][..]),
        (
            r#"{"bookSourceType":"2147483648"}"#,
            &["bookSourceType", "超出"][..],
        ),
        (r#"{"respondTime":1.5}"#, &["respondTime"][..]),
        (r#"{"enabled":"maybe"}"#, &["enabled"][..]),
        (r#"{"ruleSearch":"{broken"}"#, &["ruleSearch", "语法"][..]),
        (
            r#"{"ruleReview":"{\"enabled\":\"bad\"}"}"#,
            &["ruleReview", "enabled"][..],
        ),
        (
            r#"{"ruleContent":"{\"maxBatchSize\":\"bad\"}"}"#,
            &["ruleContent", "maxBatchSize"][..],
        ),
    ] {
        let error = parse_source_json(document).unwrap_err().to_string();
        assert!(
            markers.iter().all(|marker| error.contains(marker)),
            "{document}: {error}"
        );
    }
    let error = parse_source_array(r#"[{}, {"ruleContent":{"maxBatchSize":2147483648}}]"#)
        .unwrap_err()
        .to_string();
    assert!(
        error.contains("第 2 项")
            && error.contains("ruleContent")
            && error.contains("maxBatchSize"),
        "{error}"
    );
}
