// SPDX-License-Identifier: GPL-3.0-only
//! 原版 Legado JS 书源行为场景的 Rust 适配。
//!
//! 来源：LegadoTeam/legado @ 363540972195d5d4dd9d4008196767a73a814b36，
//! https://github.com/LegadoTeam/legado/tree/363540972195d5d4dd9d4008196767a73a814b36/app/src/test/java/io/legado/app/model/jsSource
//! app/src/test/java/io/legado/app/model/jsSource/ 下的 JsSourceEngineTest、
//! JsSourceConfigTest、JsSourceMarshallerTest 和 JsSourceBookTest。
//! 保留上游脚本/输入与行为预期，替换 JUnit/Rhino 接线；不读取 Kotlin 源码作为断言。
//! 仅覆盖已迁移的上游场景；修复后的场景作为常规门禁运行。
//! — Codex + Rust

#![cfg(feature = "quickjs")]

use legado_core::models::{Book, BookChapter, BookSource};
use legado_js::engine::JsValue;
use legado_js::js_source::js_source_book::JsSourceBookOrchestrator;
use legado_js::js_source::js_source_config::{extract, stamp_last_update_time};
use legado_js::js_source::js_source_marshaller::{JsChapter, JsSearchResult, JsSourceMarshaller};
use legado_js::source_engine::{JsSourceConfig, JsSourceEngine};
use serde_json::{Value, json};

const VALID_SCRIPT: &str = r#"var config = {
    bookSourceUrl: "https://example.com",
    bookSourceName: "示例源",
    header: "{\"User-Agent\":\"test\"}"
};
function search(key, page) { return []; }
function getChapters(book) { return []; }
function getContent(chapter, book) { return "content"; }"#;

fn engine(script: &str) -> JsSourceEngine {
    JsSourceEngine::new_quickjs(JsSourceConfig::new(
        "https://persisted.example".into(),
        script.into(),
    ))
    .unwrap()
}

mod execution {
    use super::*;

    /// 上游：calls source function through complete engine。
    #[test]
    fn calls_source_function_through_complete_engine() {
        let mut engine = engine(
            r#"var source = { bookSourceUrl: 'https://script.example' };
function search(key, page) {
    return [{ name: key, bookUrl: source.bookSourceUrl + '/book/' + page }];
}"#,
        );
        let result = engine
            .call_function(
                "search",
                &[("key", JsValue::from("书名")), ("page", JsValue::Int(3))],
            )
            .unwrap()
            .unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&result).unwrap(),
            json!([{"name":"书名", "bookUrl":"https://script.example/book/3"}])
        );
    }

    /// 上游：executes source functions with const for in loops。
    #[test]
    fn executes_source_functions_with_const_for_in_loops() {
        let mut engine = engine(
            r#"const config = { bookSourceUrl: 'https://audio.example' };
function normalize(params) {
    const output = {};
    for (const key in params) output[key] = String(params[key]);
    if (String(params.mode) === 'free') {
        const result = 'free';
        output.result = result;
    } else {
        const result = 'paid';
        output.result = result;
    }
    return output;
}"#,
        );
        let result = engine
            .call_function(
                "normalize",
                &[(
                    "params",
                    JsValue::from_json(json!({
                        "page":3,"mode":"free","nested":[true,null,{"score":1.5}]
                    }))
                    .unwrap(),
                )],
            )
            .unwrap()
            .unwrap();
        let result: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(result["page"], "3");
        assert_eq!(result["result"], "free");
        // 沿用上游String转换，验证新增绑定路径中的递归数组/对象/null。
        assert_eq!(result["nested"], "true,,[object Object]");
    }

    /// 上游：normalizes custom toJSON and getters in the source scope。
    #[test]
    fn normalizes_custom_to_json_and_getters_in_source_scope() {
        let mut engine = engine(
            r#"var prefix = 'scope';
function search() {
    var result = {};
    Object.defineProperty(result, 'computed', {
        enumerable: true,
        get: function() { return prefix + '-getter'; }
    });
    result.toJSON = function() { return { transformed: this.computed }; };
    return result;
}"#,
        );
        let result = engine.call_function("search", &[]).unwrap().unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&result).unwrap(),
            json!({"transformed":"scope-getter"})
        );
    }

    /// 上游：passes content string through unchanged / maps undefined to null。
    #[test]
    fn preserves_content_and_maps_undefined_to_none() {
        let mut engine =
            engine("function content() { return '第一段\\n第二段'; } function noop() {}");
        assert_eq!(
            engine.call_function("content", &[]).unwrap().as_deref(),
            Some("第一段\n第二段")
        );
        assert_eq!(engine.call_function("noop", &[]).unwrap(), None);
    }

    /// 上游：keeps runtime source available when config object is declared。
    #[test]
    fn keeps_runtime_source_available_when_config_is_declared() {
        let mut engine = engine(
            r#"var config = { bookSourceUrl: 'https://config.example' };
function identity() {
    return {
        configUrl: config.bookSourceUrl,
        runtimeUrl: source.bookSourceUrl,
        aliasUrl: sourceApi.bookSourceUrl
    };
}"#,
        );
        let result = engine.call_function("identity", &[]).unwrap().unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&result).unwrap(),
            json!({
                "configUrl":"https://config.example",
                "runtimeUrl":"https://persisted.example",
                "aliasUrl":"https://persisted.example"
            })
        );
    }

    /// 上游：optional function returns null when missing / executes when present。
    #[test]
    fn optional_function_distinguishes_missing_from_present() {
        let mut absent = engine("var source = {};");
        assert_eq!(
            absent
                .call_function_if_exists("getBookInfo", &[])
                .unwrap()
                .value,
            None
        );
        let mut present = engine(
            "var source = {}; function getBookInfo() { return { intro: 'optional result' }; }",
        );
        let result = present.call_function_if_exists("getBookInfo", &[]).unwrap();
        assert!(result.exists);
        assert_eq!(
            serde_json::from_str::<Value>(&result.value.unwrap()).unwrap(),
            json!({"intro":"optional result"})
        );
        let mut present = engine(
            "var calls=0; function getBookInfo(){calls++; return missingInsideFunction;} function count(){return calls;}",
        );
        assert!(
            present
                .call_function_if_exists("getBookInfo", &[])
                .unwrap_err()
                .to_string()
                .contains("missingInsideFunction")
        );
        assert_eq!(
            present.call_function("count", &[]).unwrap().as_deref(),
            Some("1")
        );
        let mut non_function = engine("var getBookInfo = 42;");
        assert!(
            !non_function
                .call_function_if_exists("getBookInfo", &[])
                .unwrap()
                .exists
        );
    }
}

mod configuration {
    use super::*;

    /// 上游：extracts metadata and keeps full script / strips declarative rules。
    #[test]
    fn extracts_metadata_keeps_script_and_strips_declarative_rules() {
        let source = extract(VALID_SCRIPT).unwrap();
        assert_eq!(source.book_source_url, "https://example.com");
        assert_eq!(source.book_source_name, "示例源");
        assert_eq!(source.header.as_deref(), Some(r#"{"User-Agent":"test"}"#));
        assert_eq!(source.main_js.as_deref(), Some(VALID_SCRIPT));
        let script = VALID_SCRIPT.replace(
            r#"header: "{\"User-Agent\":\"test\"}""#,
            r#"ruleSearch: { bookList: "ignored" }, mainJs: "OLD_JS""#,
        );
        let source = extract(&script).unwrap();
        assert!(source.rule_search.is_none());
        assert_eq!(source.main_js.as_deref(), Some(script.as_str()));
    }

    /// 上游：accepts legacy source config object / prefers config over legacy source。
    #[test]
    fn chooses_current_configuration_and_accepts_legacy_source() {
        let legacy = VALID_SCRIPT.replacen("var config =", "var source =", 1);
        assert_eq!(
            extract(&legacy).unwrap().book_source_url,
            "https://example.com"
        );
        let script = format!(
            "var source = {{bookSourceUrl:'https://legacy.example',bookSourceName:'旧配置'}};\n{VALID_SCRIPT}"
        );
        assert_eq!(
            extract(&script).unwrap().book_source_url,
            "https://example.com"
        );
    }

    /// 上游：normalizes explore array / login form array / web login URL。
    #[test]
    fn normalizes_explore_and_login_configuration() {
        let script = format!(
            "{VALID_SCRIPT}\nconfig.exploreUrl=[{{title:'分类',url:'https://example.com/list'}}];\n\
             config.loginUi=[{{name:'账号',type:'text'}},{{name:'密码',type:'password'}}];\n\
             function explore(url,page){{return [];}} function login(){{}}"
        );
        let source = extract(&script).unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(source.explore_url.as_deref().unwrap()).unwrap(),
            json!([{"title":"分类","url":"https://example.com/list"}])
        );
        assert_eq!(
            serde_json::from_str::<Value>(source.login_ui.as_deref().unwrap()).unwrap(),
            json!([{"name":"账号","type":"text"},{"name":"密码","type":"password"}])
        );
        for form in ["[]", r#""[ ]""#] {
            let source = extract(&format!("{VALID_SCRIPT}\nconfig.loginUi={form};")).unwrap();
            assert_eq!(source.login_ui, None);
        }
        let source = extract(&format!(
            "{VALID_SCRIPT}\nconfig.loginUrl='https://example.com/login';"
        ))
        .unwrap();
        assert_eq!(
            source.login_url.as_deref(),
            Some("https://example.com/login")
        );
    }

    /// 上游：loginUi function enables v2 / requires loginAction / conflicts with data。
    #[test]
    fn login_ui_function_requires_exclusive_configuration_and_action() {
        let functions = "function loginUi(state){return {rows:[]};} function loginAction(action,state,form){return {}; }";
        let source = extract(&format!("{VALID_SCRIPT}\n{functions}")).unwrap();
        assert_eq!(source.login_ui.as_deref(), Some(r#"{"version":2}"#));
        for (suffix, error) in [
            ("function loginUi(state){return {rows:[]};}", "loginAction"),
            ("config.loginUi=[{name:'账号',type:'text'}];", "loginUi"),
        ] {
            let script = if error == "loginUi" {
                format!("{VALID_SCRIPT}\n{suffix}\n{functions}")
            } else {
                format!("{VALID_SCRIPT}\n{suffix}")
            };
            assert!(extract(&script).unwrap_err().to_string().contains(error));
        }
    }

    /// 上游：requires config/core functions / explore/login/review 配对约束。
    #[test]
    fn rejects_missing_configuration_and_unpaired_functions() {
        for (script, expected) in [
            ("  ".to_string(), "为空"),
            (
                "function search(key,page){return []; }".to_string(),
                "config",
            ),
            (
                VALID_SCRIPT.replace(
                    "function getContent(chapter, book) { return \"content\"; }",
                    "",
                ),
                "getContent",
            ),
            (
                format!("{VALID_SCRIPT}\nconfig.exploreUrl='分类::https://example.com/list';"),
                "explore",
            ),
            (
                format!("{VALID_SCRIPT}\nconfig.loginUi=[{{name:'账号',type:'text'}}];"),
                "login",
            ),
            (
                format!("{VALID_SCRIPT}\nfunction getReviewSummary(chapter,book){{return [];}}"),
                "getReviewDetail",
            ),
            (
                format!(
                    "{VALID_SCRIPT}\nfunction getReviewDetail(chapter,book,paraIndex,paraData,page){{return {{items:[]}};}}"
                ),
                "getReviewSummary",
            ),
        ] {
            let error = extract(&script).unwrap_err().to_string();
            assert!(error.contains(expected), "预期 {expected}，实际 {error}");
        }
    }

    /// 上游：stamps declared update time / 不修改后续对象、注释或无关对象。
    #[test]
    fn stamps_declared_update_time_without_rewriting_other_content() {
        for (script, expected) in [
            (
                "var config = { lastUpdateTime: Date.now() };",
                "var config = { lastUpdateTime: 123456 };",
            ),
            (
                "var source = {\n    lastUpdateTime: 0 // version timestamp\n};\nvar fallback = { lastUpdateTime: 1 };",
                "var source = {\n    lastUpdateTime: 123456 // version timestamp\n};\nvar fallback = { lastUpdateTime: 1 };",
            ),
            (
                "// lastUpdateTime: 1\nvar metadata = { lastUpdateTime: 2 };\nvar config = { \"lastUpdateTime\": Date.now() };",
                "// lastUpdateTime: 1\nvar metadata = { lastUpdateTime: 2 };\nvar config = { \"lastUpdateTime\": 123456 };",
            ),
        ] {
            assert_eq!(
                stamp_last_update_time(script, 123456).as_deref(),
                Some(expected)
            );
        }
        assert_eq!(extract(VALID_SCRIPT).unwrap().last_update_time, 0);
        assert_eq!(
            extract(&format!(
                "{VALID_SCRIPT}\nconfig.lastUpdateTime=1752449000000;"
            ))
            .unwrap()
            .last_update_time,
            1752449000000
        );
    }
}

mod marshalling {
    use super::*;

    /// 上游：drops search entries missing required fields；同时消费实际 camelCase 模型。
    #[test]
    fn drops_search_entries_missing_required_fields() {
        let values = JsSourceMarshaller::marshal_search(
            r#"[{"name":"缺地址"},{"bookUrl":"缺名称"},{"name":"有效","bookUrl":"u"}]"#,
        )
        .unwrap();
        let books: Vec<JsSearchResult> = serde_json::from_value(Value::Array(values)).unwrap();
        assert_eq!(books.len(), 1);
        assert_eq!(books[0].name, "有效");
        assert_eq!(books[0].book_url, "u");
    }

    /// 上游：injects chapter identity and resolves relative urls。
    /// 当前转换接口不提供身份注入，仅迁移其过滤、卷章与 URL/VIP 预期，不宣称覆盖完整身份协议。
    #[test]
    fn filters_chapters_and_resolves_relative_urls() {
        let values = JsSourceMarshaller::marshal_chapters(
            r#"[
                {"title":"第一卷","url":"第一卷","isVolume":true},
                {"title":"第1章","url":"/read/1"},
                {"title":"第2章","url":"https://other.example/read/2","isVip":true},
                {"url":"缺标题"}
            ]"#,
            "https://source.example/toc/index",
        )
        .unwrap();
        let chapters: Vec<JsChapter> = serde_json::from_value(Value::Array(values)).unwrap();
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第一卷");
        assert_eq!(chapters[0].url, "第一卷");
        assert_eq!(chapters[0].is_volume, Some(true));
        assert_eq!(chapters[1].url, "https://source.example/read/1");
        assert_eq!(chapters[2].url, "https://other.example/read/2");
        assert_eq!(chapters[2].is_vip, Some(true));
    }
}

mod book {
    use super::*;

    /// 上游：volume placeholder skips js content and ignores its tag。
    #[test]
    fn volume_placeholder_skips_js_content_and_ignores_tag() {
        let mut book_engine = JsSourceBookOrchestrator::new(engine(
            "function getContent() { throw 'must not run'; }",
        ));
        let chapter = BookChapter {
            url: "Volume 1#0".into(),
            title: "Volume 1".into(),
            is_volume: true,
            tag: Some("2026-08-10".into()),
            ..BookChapter::default()
        };
        let book = Book {
            book_url: "https://source.example/book/1".into(),
            name: "Book".into(),
            ..Book::default()
        };
        assert_eq!(
            book_engine
                .get_content(&BookSource::default(), &chapter, &book, None)
                .unwrap(),
            ""
        );
    }

    /// 上游：blank content is allowed only for volume chapters。
    #[test]
    fn blank_content_is_allowed_only_for_volume_chapters() {
        let mut engine = JsSourceBookOrchestrator::new(engine("function getContent(){return '';}"));
        let mut chapter = BookChapter {
            url: "https://source.example/volume/1".into(),
            title: "Volume 1".into(),
            is_volume: true,
            ..Default::default()
        };
        assert_eq!(
            engine
                .get_content(&BookSource::default(), &chapter, &Book::default(), None)
                .unwrap(),
            ""
        );
        chapter.is_volume = false;
        assert!(matches!(
            engine.get_content(&BookSource::default(), &chapter, &Book::default(), None),
            Err(legado_core::LegadoError::ContentEmpty(_))
        ));
    }
}
