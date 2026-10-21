//! 书源 JSON 解析语义固化用例（SOURCE-PARSE-UNIFY-20261022 第一批）
//!
//! 本文件把上游 `GsonExtensions.kt` 的宽容语义钉成可执行断言，覆盖：
//! 缺省、显式 null、标量互转、规则对象/字符串两态、空数组、错误提示。
//!
//! 上游依据：
//! - `StringJsonDeserializer`：标量→字符串、null→null、数组/对象→JSON 字符串
//! - 六个规则类 `jsonDeserializer`：对象 / 「内容为 JSON 对象的字符串」
//! - 整数：本项目**有意保留**数字字符串兼容超集（见契约）
//!
//! 用例名沿用上游字段原写法（`respondTime`/`isVolume`/`chapterList` 等），
//! 便于与契约及上游实现逐条对照，故放行 `non_snake_case`。
#![allow(non_snake_case)]

use legado_core::models::book_source::{BookSource, parse::*};

fn parse_one(json: &str) -> BookSource {
    parse_source_json(json).expect("应解析成功")
}

// ─── 缺省与默认值 ─────────────────────────────────────────────────────────────

#[test]
fn 缺省_respondTime_取_180000() {
    let bs = parse_one(r#"{"bookSourceUrl":"https://d.example","bookSourceName":"缺省源"}"#);
    assert_eq!(bs.respond_time, 180000, "缺省 respondTime 应为 180000");
}

#[test]
fn 显式_null_respondTime_与缺省同义() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"空值源","respondTime":null}"#,
    );
    assert_eq!(
        bs.respond_time, 180000,
        "显式 null 应按未提供处理，落 180000"
    );
}

#[test]
fn 缺省_enabled_true_and_cookie_jar_默认开() {
    let bs = parse_one(r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源"}"#);
    assert!(bs.enabled);
    assert!(bs.enabled_explore);
    assert_eq!(bs.enabled_cookie_jar, Some(true));
}

// ─── 整数：兼容超集 + 超范围报错 + 非法类型报错 ────────────────────────────────

#[test]
fn 整数字符串接受_作为明确记录的兼容超集() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","bookSourceType":"1","customOrder":"12","lastUpdateTime":"1792486038190","weight":"2"}"#,
    );
    assert_eq!(bs.book_source_type, 1);
    assert_eq!(bs.custom_order, 12);
    assert_eq!(bs.last_update_time, 1_792_486_038_190);
    assert_eq!(bs.weight, 2);
}

#[test]
fn 整数超出范围明确报错() {
    let err = parse_source_json(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","bookSourceType":"99999999999999"}"#,
    )
    .expect_err("超 i32 范围应报错");
    assert!(
        format!("{err}").contains("超出"),
        "错误应说明超出范围，实际: {err}"
    );
}

#[test]
fn 整数非法形态不静默转零() {
    for bad in [r#""abc""#, "true", "[1,2]", r#"{"a":1}"#] {
        let json = format!(
            r#"{{"bookSourceUrl":"https://d.example","bookSourceName":"源","customOrder":{bad}}}"#
        );
        assert!(
            parse_source_json(&json).is_err(),
            "customOrder={bad} 应报错而非静默转 0"
        );
    }
}

// ─── 布尔 ────────────────────────────────────────────────────────────────────

#[test]
fn 布尔接受字符串与数字两种形态() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","enabled":"false","enabledExplore":0,"eventListener":"1","customButton":1}"#,
    );
    assert!(!bs.enabled);
    assert!(!bs.enabled_explore);
    assert!(bs.event_listener);
    assert!(bs.custom_button);
}

#[test]
fn 布尔非法值报错() {
    let err = parse_source_json(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","enabled":"maybe"}"#,
    )
    .expect_err("非法布尔应报错");
    assert!(format!("{err}").contains("布尔"), "实际: {err}");
}

// ─── 字符串：标量/数组/对象 → 字符串 ─────────────────────────────────────────

#[test]
fn 可空字符串_显式_null_保留为_None() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","header":null,"jsLib":null}"#,
    );
    assert_eq!(bs.header, None);
    assert_eq!(bs.js_lib, None);
}

#[test]
fn 可空字符串_标量转字符串() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","header":123,"jsLib":true}"#,
    );
    assert_eq!(bs.header.as_deref(), Some("123"));
    assert_eq!(bs.js_lib.as_deref(), Some("true"));
}

#[test]
fn 非空字符串_显式_null_落空串() {
    let bs = parse_one(r#"{"bookSourceUrl":null,"bookSourceName":null}"#);
    assert_eq!(bs.book_source_url, "");
    assert_eq!(bs.book_source_name, "");
}

#[test]
fn 非空字符串_数字转字符串() {
    let bs = parse_one(r#"{"bookSourceUrl":"https://d.example","bookSourceName":12}"#);
    assert_eq!(bs.book_source_name, "12");
}

// ─── 规则对象：对象 / JSON 字符串两态 ────────────────────────────────────────

#[test]
fn 规则字段接受对象形态() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","ruleToc":{"chapterList":".list@li","chapterName":"text"}}"#,
    );
    let toc = bs.rule_toc.expect("规则应保留");
    assert_eq!(toc.chapter_list.as_deref(), Some(".list@li"));
    assert_eq!(toc.chapter_name.as_deref(), Some("text"));
}

#[test]
fn 规则字段接受_JSON_字符串形态() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","ruleSearch":"{\"bookList\":\".book\",\"name\":\".name\"}"}"#,
    );
    let search = bs.rule_search.expect("字符串规则应被解析为对象");
    assert_eq!(search.book_list.as_deref(), Some(".book"));
    assert_eq!(search.name.as_deref(), Some(".name"));
}

#[test]
fn 规则内_isVolume_按目标字符串类型转换() {
    // 上游 TocRule.isVolume 是 String?，false 应转成 "false"，不得走布尔语义
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","ruleToc":{"isVolume":false}}"#,
    );
    assert_eq!(bs.rule_toc.unwrap().is_volume.as_deref(), Some("false"));
}

#[test]
fn 规则内_chapterList_数组转_JSON_字符串() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","ruleToc":{"chapterList":[1,2]}}"#,
    );
    assert_eq!(bs.rule_toc.unwrap().chapter_list.as_deref(), Some("[1,2]"));
}

#[test]
fn 规则字段_空数组与空对象降级为无规则() {
    let bs = parse_one(
        r#"{"bookSourceUrl":"https://d.example","bookSourceName":"源","ruleToc":[],"ruleSearch":{}}"#,
    );
    assert!(bs.rule_toc.is_none(), "数组形态按上游降级为 None");
    // 空对象是有效规则，保留为 Some(默认值)
    assert!(bs.rule_search.is_some());
}

// ─── 复合：真实第三方源形态 ───────────────────────────────────────────────────

#[test]
fn 真实第三方源_字符串时间戳与单引号规则可入库() {
    let bs = parse_one(
        r#"{
            "bookSourceUrl": "https://www.alicesw.com",
            "bookSourceName": "爱丽丝书屋",
            "bookSourceType": 0,
            "enabled": true,
            "lastUpdateTime": "1792486038190",
            "respondTime": 13494,
            "exploreUrl": "[{'title':'科幻','url':'/lists/71.html&page={{page}}'}]",
            "ruleContent": {"content": "@js:return result;"}
        }"#,
    );
    assert_eq!(bs.last_update_time, 1_792_486_038_190);
    assert_eq!(bs.respond_time, 13494);
    // 单引号 exploreUrl 是嵌套规则解析问题，不在本批范围：此处仅要求原样保留字符串
    assert!(bs.explore_url.unwrap().starts_with("[{'title'"));
    assert!(bs.rule_content.is_some());
}

// ─── 数组入口与错误定位 ──────────────────────────────────────────────────────

#[test]
fn 数组入口_逐项报错带序号() {
    let err =
        parse_source_array(r#"[{"bookSourceUrl":"https://a.example","bookSourceName":"A"}, 42]"#)
            .expect_err("第 2 项非对象应报错");
    assert!(format!("{err}").contains("第 2 项"), "实际: {err}");
}

#[test]
fn 单对象也按数组一条处理() {
    let list = parse_source_array(r#"{"bookSourceUrl":"https://a.example","bookSourceName":"A"}"#)
        .expect("单对象应可用");
    assert_eq!(list.len(), 1);
}

#[test]
fn 语法错误可定位() {
    let err = parse_source_json(r#"{"bookSourceUrl":"#).expect_err("语法错应报错");
    assert!(format!("{err}").contains("语法"), "实际: {err}");
}

#[test]
fn 审查回归_编辑数组取首项_空数组报错() {
    let source = parse_source_json(r#"[{"bookSourceName":"首项"},42]"#).unwrap();
    assert_eq!(source.book_source_name, "首项");
    assert!(
        parse_source_json("[]")
            .unwrap_err()
            .to_string()
            .contains("为空")
    );
    assert!(parse_source_json("[42]").is_err());
}

#[test]
fn 审查回归_坏规则字符串必须报错并定位() {
    let error = parse_source_json(r#"{"ruleSearch":"{broken"}"#)
        .unwrap_err()
        .to_string();
    assert!(error.contains("ruleSearch"), "{error}");
    assert!(error.contains("规则"), "{error}");
    let error = parse_source_json(r#"{"ruleReview":"{\"enabled\":\"bad\"}"}"#)
        .unwrap_err()
        .to_string();
    assert!(error.contains("ruleReview"), "{error}");
    assert!(error.contains("enabled"), "{error}");
}

#[test]
fn 审查回归_字段错误带名称与数组序号() {
    let error = parse_source_json(r#"{"customOrder":"bad"}"#)
        .unwrap_err()
        .to_string();
    assert!(error.contains("customOrder"), "{error}");
    let error = parse_source_array(r#"[{}, {"weight":"bad"}]"#)
        .unwrap_err()
        .to_string();
    assert!(
        error.contains("第 2 项") && error.contains("weight"),
        "{error}"
    );
}

#[test]
fn 段评_enabled_对象与字符串复用布尔转换() {
    for (value, expected) in [
        (serde_json::json!(false), false),
        (serde_json::json!(true), true),
        (serde_json::json!(0), false),
        (serde_json::json!(1), true),
        (serde_json::json!(-2), true),
        (serde_json::json!("false"), false),
        (serde_json::json!("true"), true),
        (serde_json::json!("0"), false),
        (serde_json::json!("1"), true),
        (serde_json::json!(""), false),
    ] {
        let rule = serde_json::json!({"enabled": value});
        for input in [rule.clone(), serde_json::Value::String(rule.to_string())] {
            let json = serde_json::json!({"ruleReview": input}).to_string();
            let source = parse_source_json(&json).unwrap_or_else(|error| panic!("{json}: {error}"));
            assert_eq!(source.rule_review.unwrap().enabled, expected, "{json}");
        }
    }
}

#[test]
fn 段评_enabled_缺省与显式_null_均关闭() {
    for rule in [serde_json::json!({}), serde_json::json!({"enabled": null})] {
        for input in [rule.clone(), serde_json::Value::String(rule.to_string())] {
            let json = serde_json::json!({"ruleReview": input}).to_string();
            let source = parse_source_json(&json).unwrap_or_else(|error| panic!("{json}: {error}"));
            assert!(!source.rule_review.unwrap().enabled, "{json}");
        }
    }
}

#[test]
fn 段评_enabled_非法值保留内外字段路径() {
    for value in [
        serde_json::json!("maybe"),
        serde_json::json!(1.5),
        serde_json::json!([]),
        serde_json::json!({}),
    ] {
        let rule = serde_json::json!({"enabled": value});
        for input in [rule.clone(), serde_json::Value::String(rule.to_string())] {
            let json = serde_json::json!({"ruleReview": input}).to_string();
            let error = parse_source_json(&json).unwrap_err().to_string();
            assert!(
                error.contains("ruleReview") && error.contains("enabled"),
                "{error}"
            );
        }
    }
}
