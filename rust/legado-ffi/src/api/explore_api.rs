//! 发现宿主入口：装配窄资源并适配文档协议。
use crate::api::explore_info_map;
use legado_core::explore::ExploreCategory;
use legado_core::{LegadoError, LegadoResult, models::BookSource, web_book::WebSearchResult};
pub use legado_engine::explore_service::ExploreEvalActionResult;
use legado_engine::explore_service::{ExploreResources, ExploreService};
#[cfg(all(test, feature = "quickjs"))]
use legado_fetcher::explore::with_explore_top_bindings;
#[cfg(test)]
use legado_fetcher::explore::{
    format_book_author, format_book_name, format_intro, parse_explore_as_single_book,
};
#[cfg(test)]
use legado_parser::AnalyzeUrl;
use std::{collections::HashMap, sync::Arc};
fn host_service() -> ExploreService {
    let js = crate::engine_holder::js_resources();
    let login = crate::engine_holder::source_login_cache();
    let info = crate::engine_holder::source_info_map();
    ExploreService::new(ExploreResources {
        js,
        info: info.clone(),
        tasks: crate::engine_holder::task_group(),
        runtime: crate::runtime::get_runtime().handle().clone(),
        setup: Arc::new(move |source| {
            super::source_js_bindings::book_source_js_setup_script_with_login_cache(
                source, &login, &info,
            )
        }),
    })
}

pub fn explore_eval_action(source_json: &str, action_js: &str) -> LegadoResult<String> {
    serde_json::to_string(&explore_eval_action_result(
        &serde_json::from_str(source_json)?,
        action_js,
    )?)
    .map_err(LegadoError::Serialization)
}

pub fn explore_eval_action_result(
    source: &BookSource,
    action_js: &str,
) -> LegadoResult<ExploreEvalActionResult> {
    host_service().explore_eval_action_result(source, action_js)
}

pub fn explore_eval_ui_js(source: &BookSource, js_str: &str) -> LegadoResult<String> {
    host_service().explore_eval_ui_js(source, js_str)
}

pub fn explore_info_map_put(source_url: &str, key: &str, value: &str) -> LegadoResult<()> {
    explore_info_map::put(source_url, key, value)
}

pub fn explore_info_map_ensure_default(
    source_url: &str,
    key: &str,
    default_value: &str,
) -> LegadoResult<()> {
    explore_info_map::ensure_default(source_url, key, default_value)
}

pub fn explore_parse_url(explore_url: &str, source_json: &str) -> LegadoResult<String> {
    serde_json::to_string(&explore_parse_url_entity(
        explore_url,
        parse_source_for_explore_optional(source_json)?,
    )?)
    .map_err(LegadoError::Serialization)
}

pub fn explore_parse_url_entity(
    explore_url: &str,
    source: Option<BookSource>,
) -> LegadoResult<Vec<ExploreCategory>> {
    host_service().explore_parse_url_entity(explore_url, source)
}

pub fn explore_fetch_books(source_json: &str, url: &str, page: i32) -> LegadoResult<String> {
    let source: BookSource = serde_json::from_str(source_json)?;

    if url.is_empty() {
        return Err(LegadoError::Internal("发现分类 URL 为空".into()));
    }

    let deps = crate::api::web_book::ffi_deps()?;
    let info = explore_info_map::snapshot(&source.book_source_url).unwrap_or_default();
    explore_fetch_books_with_deps(source_json, url, page, deps, info, None)
}

pub fn explore_fetch_books_entity(
    source: BookSource,
    url: &str,
    page: i32,
) -> LegadoResult<Vec<WebSearchResult>> {
    let deps = crate::api::web_book::ffi_deps()?;
    let info = explore_info_map::snapshot(&source.book_source_url).unwrap_or_default();
    explore_fetch_books_entity_with_deps(source, url, page, deps, info, None)
}

pub(crate) fn explore_fetch_books_with_deps(
    source_json: &str,
    url: &str,
    page: i32,
    deps: legado_fetcher::deps::FetcherDeps,
    info_map: HashMap<String, String>,
    task: Option<legado_engine::TaskHandle>,
) -> LegadoResult<String> {
    let results = explore_fetch_books_entity_with_deps(
        serde_json::from_str(source_json)?,
        url,
        page,
        deps,
        info_map,
        task,
    )?;
    serde_json::to_string(&results).map_err(LegadoError::Serialization)
}

pub(crate) fn explore_fetch_books_entity_with_deps(
    source: BookSource,
    url: &str,
    page: i32,
    deps: legado_fetcher::deps::FetcherDeps,
    info_map: HashMap<String, String>,
    task: Option<legado_engine::TaskHandle>,
) -> LegadoResult<Vec<WebSearchResult>> {
    host_service().explore_fetch_books_entity_with_deps(source, url, page, deps, info_map, task)
}

fn parse_source_for_explore_optional(source_json: &str) -> LegadoResult<Option<BookSource>> {
    if source_json.trim().is_empty() {
        return Ok(None);
    }
    serde_json::from_str(source_json)
        .map(Some)
        .map_err(LegadoError::Serialization)
}

#[cfg(all(test, feature = "quickjs"))]
fn eval_explore_js(js: &str, source: &BookSource) -> LegadoResult<String> {
    host_service().eval_explore_js(js, source)
}

#[cfg(test)]
mod field_clean_tests {
    use super::*;

    #[test]
    fn test_format_book_name_strips_author_suffix() {
        assert_eq!(format_book_name("斗破苍穹 作者天蚕土豆"), "斗破苍穹");
        assert_eq!(format_book_name("凡人修仙传 忘语 著"), "凡人修仙传");
        assert_eq!(format_book_name("  神墓  "), "神墓");
    }

    #[test]
    fn test_format_book_author_strips_prefix_suffix() {
        assert_eq!(format_book_author("作者:天蚕土豆"), "天蚕土豆");
        assert_eq!(format_book_author("作者： 忘语"), "忘语");
        assert_eq!(format_book_author("天蚕土豆 著"), "天蚕土豆");
        assert_eq!(format_book_author("  猫腻  "), "猫腻");
    }

    #[test]
    fn test_format_intro_strips_html() {
        assert_eq!(
            format_intro("<p>简介内容</p><br/>第二段 &amp; 特殊字符"),
            "简介内容 第二段 & 特殊字符"
        );
        assert_eq!(format_intro(""), "");
    }

    #[test]
    fn test_reverse_prefix_flag_semantics() {
        // `-` 前缀剥离 + reverse 标记（A6）
        let mut rule = "-.list@css:li".to_string();
        let mut reverse = false;
        if rule.starts_with('-') {
            reverse = true;
            rule = rule[1..].to_string();
        }
        assert!(reverse);
        assert_eq!(rule, ".list@css:li");

        // `+` 前缀仅剥离
        let mut rule2 = "+.list@css:li".to_string();
        let mut reverse2 = false;
        if rule2.starts_with('-') {
            reverse2 = true;
            rule2 = rule2[1..].to_string();
        } else if rule2.starts_with('+') {
            rule2 = rule2[1..].to_string();
        }
        assert!(!reverse2);
        assert_eq!(rule2, ".list@css:li");
    }

    /// A9：explore 列表规则无命中时按详情页单本回退解析（对齐原版 getInfoItem）
    #[test]
    fn test_parse_explore_as_single_book() {
        use legado_parser::AnalyzeRule;
        let source = serde_json::from_str::<BookSource>(
            &serde_json::json!({
                "bookSourceUrl": "https://detail.example.com",
                "ruleBookInfo": {
                    "name": "#bookname@text",
                    "author": ".author@text",
                    "intro": ".intro@html"
                }
            })
            .to_string(),
        )
        .unwrap();
        let html = r#"<html><body>
            <h1 id="bookname">斗破苍穹 作者天蚕土豆</h1>
            <span class="author">作者:天蚕土豆</span>
            <div class="intro"><p>简介内容</p><br/>第二段</div>
        </body></html>"#;
        let analyzer = AnalyzeRule::new(
            html.to_string(),
            "https://detail.example.com/book/1".to_string(),
        );
        let book =
            parse_explore_as_single_book(&source, &analyzer, "https://detail.example.com/book/1")
                .expect("详情页回退应解析出单本");
        assert_eq!(book.name, "斗破苍穹");
        assert_eq!(book.author, "天蚕土豆");
        assert_eq!(book.book_url, "https://detail.example.com/book/1");
        assert_eq!(book.intro.as_deref(), Some("简介内容 第二段"));
    }
}

#[cfg(all(test, feature = "quickjs"))]
mod login_check_tests {
    use super::*;
    use crate::api::web_book::RealBookSourceFetcher;
    use legado_core::models::BookSource;

    fn source_with_login_check(js: &str) -> BookSource {
        serde_json::from_str::<BookSource>(
            &serde_json::json!({
                "bookSourceUrl": "https://login-explore.example.com",
                "bookSourceName": "登录探索测试",
                "loginCheckJs": js,
            })
            .to_string(),
        )
        .unwrap()
    }

    /// [STAGE4-P36] explore 链三叉点 1（分叉点1：裸布尔 → cast 失败 → 整源失败）：
    /// 对齐原版 WebBook.kt:149-172 `evalJS(checkJs, it) as StrResponse`——
    /// 裸布尔完成值无法 cast 为响应对象（原版 ClassCastException 语义）→
    /// 首检 CastFailed → 二次 errResponse(500) eval 仍 cast 失败 →
    /// 整源失败 LoginRequired（旧谓词语义会按字符串内容判定，已废弃）。
    #[test]
    fn test_explore_login_check_bare_false_whole_source_fail() {
        let source = source_with_login_check("false;");
        let r = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "<html>登录页</html>",
            "https://a.com/explore",
            200,
        )
        .unwrap_err();
        assert!(matches!(r, LegadoError::LoginRequired(_)));
    }

    /// [STAGE4-P36] 分叉点1（裸 true 同样 cast 失败——红测试，旧谓词语义
    /// 会把 `true` 当「已登录」放行，新语义整源失败）。
    #[test]
    fn test_explore_login_check_bare_true_whole_source_fail() {
        let source = source_with_login_check("true;");
        let r = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "<html>正常页</html>",
            "https://a.com/explore",
            200,
        );
        assert!(
            matches!(r, Err(LegadoError::LoginRequired(_))),
            "裸 true 完成值应整源失败（cast 失败不降级），实际: {r:?}"
        );
    }

    /// [STAGE4-P36] 三叉点 2（二次 eval code≠500 → 放行并采用二次结果）：
    /// 正常响应（code 200）下 JS 返回裸字符串 `"false"` → cast 失败走错误
    /// 路径；errResponse(500) 二次 eval 时 JS 自动登录并返回修改响应
    /// `{code: 200, body: ...}`（code≠500）→ 放行且**采用二次结果**
    /// （对齐原版 WebBook.kt:88「块值 = 二次返回值 res」，body 为自动登录
    /// 后的新响应体，url 缺失回退原 URL）。
    #[test]
    fn test_explore_login_check_second_adopt() {
        let js = r#"result.code() === 500 ? {code: 200, body: "auto-login-ok"} : "false""#;
        let source = source_with_login_check(js);
        let r = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "<html>登录页</html>",
            "https://a.com/explore",
            200,
        )
        .expect("二次 eval code≠500 应放行");
        assert_eq!(r.body, "auto-login-ok", "应采用二次修改响应体，实际: {r:?}");
        assert_eq!(r.code, 200);
        assert_eq!(r.url, "https://a.com/explore", "缺失字段应回退原 URL");
    }

    /// [STAGE4-P36] 三叉点 3（JS 修改的响应被采用）：正常响应下 JS 直接
    /// 返回修改响应对象（自动登录场景）→ 首检成功即采用修改值
    /// （对齐原版 analyzeBookList(baseUrl = res.url, body = res.body)）。
    /// 注意：QuickJS 顶层禁 `return`，裸 `{...}` 在语句位置是块语句，
    /// 对象完成值一律用括号表达式形式（见 login_check_response 测试注释）。
    #[test]
    fn test_explore_login_check_modified_response_adopted() {
        let js = r#"({code: 200, body: "modified-body", url: "https://a.com/new"})"#;
        let source = source_with_login_check(js);
        let r = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "<html>正常页</html>",
            "https://a.com/explore",
            200,
        )
        .expect("JS 修改响应应首检成功");
        assert_eq!(
            r.body, "modified-body",
            "应采用 JS 修改的响应体，实际: {r:?}"
        );
        assert_eq!(r.url, "https://a.com/new", "应采用 JS 修改的 URL");
        assert_eq!(r.code, 200);
    }

    /// 无 loginCheckJs 配置 → 原始响应三元组直通（对齐 WebBook.kt:77
    /// checkJs 为空直通）。
    #[test]
    fn test_explore_login_check_no_config_skips() {
        let source = BookSource::default();
        let r = RealBookSourceFetcher::execute_login_check(
            &crate::engine_holder::js_resources(),
            &source,
            "<html>x</html>",
            "https://a.com",
            200,
        )
        .expect("无 loginCheckJs 配置应直通");
        assert_eq!(r.body, "<html>x</html>");
        assert_eq!(r.url, "https://a.com");
        assert_eq!(r.code, 200);
    }

    /// 复现：jsLib 函数体内含 Rhino Packages（try-catch 合法语法）+ 后部
    /// getConfig 定义——exploreUrl 应能访问 getConfig（发现页 ERROR 排查）
    #[test]
    fn test_explore_js_lib_get_config_visible() {
        let source = serde_json::from_str::<BookSource>(
            &serde_json::json!({
                "bookSourceUrl": "https://jslib-explore.example.com",
                "bookSourceName": "jsLib 测试",
                "jsLib": r#"
function checkEnv() {
    try { new Packages.io.foo.Bar(''); } catch (e) { return false; }
    return true;
}
function getConfig() { return { host: 'https://a.test', gender: 'boy' }; }
function getServerHost() { return 'https://a.test'; }
"#,
            })
            .to_string(),
        )
        .unwrap();

        // exploreUrl 调用 jsLib 函数（getConfig/getServerHost；@js: 前缀已剥离）
        let url = "JSON.stringify({c:getConfig.call(this),h:getServerHost()})";
        let result = eval_explore_js(url, &source);
        let out = result.unwrap_or_else(|e| panic!("exploreUrl 执行失败: {e}"));
        assert!(
            out.contains("https://a.test"),
            "getConfig/getServerHost 应可见，实际: {out}"
        );
    }

    /// 真实书山聚合 jsLib（47263 字节，含函数体内 Packages）验证 getConfig 可见。
    /// 依赖设备导出夹具；已标记 #[ignore]（夹具缺失时响亮 panic，需重新导出后手工运行）。
    #[test]
    #[ignore = "外部夹具 tmp_debug/e2e_5558/sources_device.json（仓库外，已于 2026-09-20 删除，无法复跑）+ 实网诊断（需真实登录/网络），非确定性 CI 测试"]
    fn test_explore_real_jslib_get_config_visible() {
        // 真实书山 jsLib 探索解析：JS 内 source./java. 绑定读写全局变量表
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../tmp_debug/e2e_5558/sources_device.json"
        );
        let Ok(raw) = std::fs::read_to_string(path) else {
            panic!("夹具缺失: {path}（仓库外，已于 2026-09-20 删除）——请重新导出后再跑");
        };
        let Ok(serde_json::Value::Array(sources)) = serde_json::from_str::<serde_json::Value>(&raw)
        else {
            return;
        };
        let Some(src) = sources.iter().find(|s| {
            s.get("bookSourceName")
                .and_then(|n| n.as_str())
                .is_some_and(|n| n.contains("书山"))
        }) else {
            eprintln!("未找到书山聚合源，跳过");
            return;
        };
        let Some(_js_lib) = src.get("jsLib").and_then(|l| l.as_str()) else {
            eprintln!("书山 jsLib 缺失，跳过");
            return;
        };
        let source =
            serde_json::from_str::<BookSource>(&serde_json::to_string(src).unwrap()).unwrap();

        // 阶段 1：jsLib 加载后 getConfig/getServerHost/source 均应可见
        let probe = "typeof getConfig + '|' + typeof getServerHost + '|' + typeof source";
        let r1 = eval_explore_js(probe, &source);
        eprintln!("[真实 jsLib] 阶段1 typeof 探测: {:?}", r1);
        if let Ok(o) = r1 {
            assert!(
                o.contains("function|function|object"),
                "jsLib 应完整加载（getConfig/getServerHost/source 均可见），实际: {o}"
            );
        } else {
            panic!("jsLib 加载/探测失败: {:?}", r1);
        }

        // 阶段 2：调用 getServerHost（裸调用，验证非严格 this 语义）
        let url = "JSON.stringify(getServerHost())";
        let result = eval_explore_js(url, &source);
        let out = result.unwrap_or_else(|e| panic!("真实 jsLib getServerHost 调用失败: {e}"));
        eprintln!("[真实 jsLib] 阶段2 getServerHost: {out}");
        assert!(
            !out.contains("Cannot convert"),
            "getServerHost 裸调用应可用，实际: {out}"
        );

        // 阶段 3：完整 exploreUrl 执行（剥离 <js> 标签）
        let explore_url = src.get("exploreUrl").and_then(|u| u.as_str()).unwrap_or("");
        let js = if explore_url.trim_start().starts_with("<js>") {
            let start = explore_url.find("<js>").map(|i| i + 4).unwrap_or(0);
            let end = explore_url.rfind("</js>").unwrap_or(explore_url.len());
            &explore_url[start..end]
        } else {
            explore_url
        };
        let r3 = eval_explore_js(js, &source);
        match &r3 {
            Ok(o) => eprintln!(
                "[真实 jsLib] 阶段3 完整 exploreUrl OK: {}",
                o.chars().take(150).collect::<String>()
            ),
            Err(e) => eprintln!("[真实 jsLib] 阶段3 完整 exploreUrl 失败: {e}"),
        }
        // 完整脚本含网络请求，允许失败（模拟器环境），仅打印诊断
    }

    /// 探测 QuickJS eval 的 this 语义（裸调用函数 this / 顶层 this / Function 构造）
    #[test]
    fn test_eval_this_semantics() {
        use legado_js::JsEngine;
        let tag = "this-semantics-test";
        let engine = crate::js_executor::fresh_engine(tag).unwrap();
        let guard = engine.lock().unwrap();
        let top = guard.eval("typeof this").unwrap_or_default();
        let bare = guard
            .eval("var __f = function(){ return typeof this; }; __f();")
            .unwrap_or_default();
        let fnctor = guard
            .eval("var __g = new Function('return typeof this'); __g();")
            .unwrap_or_default();
        let fnctor2 = guard
            .eval("var __h = new Function('var __i = function(){ return typeof this; }; return __i();'); __h();")
            .unwrap_or_default();
        eprintln!(
            "[this 语义] 顶层={top}, 裸调用={bare}, Function={fnctor}, Function内裸调用={fnctor2}"
        );
    }

    /// 书山聚合空列表根因回归：bookList `<js>` 脚本依赖 jsLib（getSessionId）+
    /// 书源 setup（source/cookie）。验证 analyzer 注入 sanitize jsLib + setup 后
    /// `$.data[*]` 复合规则可解析出书籍。— DeepSeek Harness + Bridge
    #[test]
    #[ignore = "外部夹具 tmp_debug/e2e_5558/sources_device.json（仓库外，已于 2026-09-20 删除，无法复跑）+ 实网诊断（需真实登录/网络），非确定性 CI 测试"]
    fn test_shushan_booklist_js_with_jslib_and_setup() {
        // 书山 bookList `<js>` 脚本（jsLib + setup 注入 source/cookie，
        // source. 绑定读写全局变量表）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../tmp_debug/e2e_5558/sources_device.json"
        );
        let Ok(raw) = std::fs::read_to_string(path) else {
            panic!("夹具缺失: {path}（仓库外，已于 2026-09-20 删除）——请重新导出后再跑");
        };
        let Ok(serde_json::Value::Array(sources)) = serde_json::from_str::<serde_json::Value>(&raw)
        else {
            return;
        };
        let Some(src) = sources.iter().find(|s| {
            s.get("bookSourceName")
                .and_then(|n| n.as_str())
                .is_some_and(|n| n.contains("书山"))
        }) else {
            eprintln!("未找到书山聚合源，跳过");
            return;
        };
        let source =
            serde_json::from_str::<BookSource>(&serde_json::to_string(src).unwrap()).unwrap();
        let book_list_rule = source
            .rule_explore
            .as_ref()
            .and_then(|r| r.book_list.as_deref())
            .expect("书山 ruleExplore.bookList 缺失");

        // 合成 read_recommend 响应（cell_view.book_data 含 2 本）
        let body = serde_json::json!({
            "code": 0,
            "message": "SUCCESS",
            "data": {
                "cell_view": {
                    "cell_name": "推荐榜",
                    "book_data": [
                        {
                            "book_name": "斗破苍穹测试",
                            "author": "天蚕土豆",
                            "abstract": "三十年河东",
                            "thumb_url": "https://img.test/1.jpg",
                            "book_url": "https://v1.vossc.com/detail?book_id=123"
                        },
                        {
                            "book_name": "凡人修仙传测试",
                            "author": "忘语",
                            "abstract": "修仙路",
                            "thumb_url": "https://img.test/2.jpg",
                            "book_url": "https://v1.vossc.com/detail?book_id=456"
                        }
                    ]
                }
            }
        })
        .to_string();
        let base = "https://v1.vossc.com/read_recommend?session=";

        let lib = source.js_lib.as_deref().expect("书山 jsLib 缺失");
        let sanitized = crate::api::source_js_bindings::sanitize_js_lib_for_quickjs(lib);
        let setup = crate::api::source_js_bindings::book_source_js_setup_script(&source).ok();
        let analyzer = crate::js_executor::construct_analyzer_with_source_context(
            body,
            base.to_string(),
            &source.book_source_url,
            Some(&sanitized),
            setup,
        );
        let elements = analyzer
            .get_elements(book_list_rule)
            .unwrap_or_else(|e| panic!("bookList 规则解析失败: {e}"));
        assert_eq!(elements.len(), 2, "应解析出 2 本书，实际: {elements:?}");

        let name_rule = source
            .rule_explore
            .as_ref()
            .and_then(|r| r.name.as_deref())
            .unwrap_or("");
        let mut elem_analyzer = crate::js_executor::construct_analyzer_with_source_context(
            String::new(),
            base.to_string(),
            &source.book_source_url,
            Some(&sanitized),
            crate::api::source_js_bindings::book_source_js_setup_script(&source).ok(),
        );
        elem_analyzer.set_element_content(elements[0].clone());
        let name = elem_analyzer.get_string(name_rule).unwrap_or_default();
        assert_eq!(name, "斗破苍穹测试", "书名规则解析失败: {name}");

        // bookUrl `<js>` 规则：元素模式下 result 注入为对象，
        // `result.source`/`result.book_url` 属性访问可用，产出非空且
        // 每本书各异的 detailsUrl（否则回退 baseUrl → 去重折叠成 1 条）
        let book_url_rule = source
            .rule_explore
            .as_ref()
            .and_then(|r| r.book_url.as_deref())
            .unwrap_or("");
        let mut urls = std::collections::HashSet::new();
        for elem in &elements {
            elem_analyzer.set_element_content(elem.clone());
            let u = elem_analyzer.get_string(book_url_rule).unwrap_or_default();
            assert!(
                !u.is_empty() && u.starts_with("data:detailsUrl;base64,"),
                "bookUrl 规则应产出 detailsUrl，实际: {u:?}"
            );
            urls.insert(u);
        }
        assert_eq!(
            urls.len(),
            elements.len(),
            "每本书 bookUrl 应唯一: {urls:?}"
        );
    }

    /// 书山聚合 header 规则注入回归：setup 应执行书源 header @js 规则
    /// （含固定 X-Novel-Token）并写入全局请求头，java.ajax 请求自动携带
    /// —— 修复书山目录 /catalog 400 无效书源（java.ajax 缺认证头）。
    #[test]
    #[ignore = "外部夹具 tmp_debug/e2e_5558/sources_device.json（仓库外，已于 2026-09-20 删除，无法复跑）+ 实网诊断（需真实登录/网络），非确定性 CI 测试"]
    fn test_shushan_header_rule_injected_to_global_headers() {
        // 书山 header @js 规则（source. 绑定写全局表 + java.ajax 携带认证头）
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../tmp_debug/e2e_5558/sources_device.json"
        );
        let Ok(raw) = std::fs::read_to_string(path) else {
            panic!("夹具缺失: {path}（仓库外，已于 2026-09-20 删除）——请重新导出后再跑");
        };
        let Ok(serde_json::Value::Array(sources)) = serde_json::from_str::<serde_json::Value>(&raw)
        else {
            return;
        };
        let Some(src) = sources.iter().find(|s| {
            s.get("bookSourceName")
                .and_then(|n| n.as_str())
                .is_some_and(|n| n.contains("书山"))
        }) else {
            eprintln!("未找到书山聚合源，跳过");
            return;
        };
        let source =
            serde_json::from_str::<BookSource>(&serde_json::to_string(src).unwrap()).unwrap();
        let header_rule = source.header.clone().unwrap_or_default();
        assert!(
            header_rule.contains("@js:"),
            "书山 header 应为 @js 动态规则"
        );

        let lib = source.js_lib.as_deref().expect("书山 jsLib 缺失");
        let sanitized = crate::api::source_js_bindings::sanitize_js_lib_for_quickjs(lib);
        let setup = crate::api::source_js_bindings::book_source_js_setup_script(&source).ok();
        let analyzer = crate::js_executor::construct_analyzer_with_source_context(
            String::new(),
            "https://v1.vossc.com/".to_string(),
            &source.book_source_url,
            Some(&sanitized),
            setup,
        );
        // 触发一次 JS 求值，setup（含 header 规则执行）此时才真正加载
        let _ = analyzer.get_string("{{1+1}}");

        // setup 执行后，书山 tag 的全局请求头应含固定 X-Novel-Token
        let headers = crate::engine_holder::js_resources()
            .http_resources()
            .headers_for(&source.book_source_url);
        assert_eq!(
            headers.get("X-Novel-Token").map(|s| s.as_str()),
            Some("SHUSAN_READ_2025"),
            "书山 header 规则执行后应写入固定 X-Novel-Token: {headers:?}"
        );
    }

    /// 通用聚合源回归（2026-08-17）：大灰狼融合/七猫四合一/番茄聚合等聚合源
    /// 与书山同机制（jsLib + setup + header 规则）——探索 URL 模板解析不应
    /// 因 jsLib/setup 缺失而报错；header @js 规则应可执行。
    #[test]
    #[ignore = "外部夹具 tmp_debug/e2e_5558/sources_device.json（仓库外，已于 2026-09-20 删除，无法复跑）+ 实网诊断（需真实登录/网络），非确定性 CI 测试"]
    fn test_aggregate_sources_common_explore_and_header() {
        // 通用聚合源（jsLib + setup + header 规则，source. 绑定读写全局表）
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../tmp_debug/e2e_5558/sources_device.json"
        );
        let Ok(raw) = std::fs::read_to_string(path) else {
            panic!("夹具缺失: {path}（仓库外，已于 2026-09-20 删除）——请重新导出后再跑");
        };
        let Ok(serde_json::Value::Array(sources)) = serde_json::from_str::<serde_json::Value>(&raw)
        else {
            return;
        };
        let targets = ["大灰狼", "七猫四合一", "番茄聚合", "书山"];
        for name_kw in targets {
            let Some(src) = sources.iter().find(|s| {
                s.get("bookSourceName")
                    .and_then(|n| n.as_str())
                    .is_some_and(|n| n.contains(name_kw))
            }) else {
                eprintln!("未找到 {name_kw} 源，跳过");
                continue;
            };
            let source =
                serde_json::from_str::<BookSource>(&serde_json::to_string(src).unwrap()).unwrap();
            let lib = source.js_lib.as_deref().unwrap_or("");
            let sanitized = crate::api::source_js_bindings::sanitize_js_lib_for_quickjs(lib);
            let setup = crate::api::source_js_bindings::book_source_js_setup_script(&source).ok();
            let analyzer = crate::js_executor::construct_analyzer_with_source_context(
                String::new(),
                source.book_source_url.clone(),
                &source.book_source_url,
                Some(&sanitized),
                setup,
            );
            let _ = analyzer.get_string("{{1+1}}");
            if let Some(explore) = source.explore_url.as_deref() {
                let url = explore.trim();
                if url.starts_with("@js:") || url.starts_with("<js>") {
                    let _ = analyzer.get_string(url);
                }
            }
            eprintln!("[aggregate-common] {name_kw} setup+explore OK");
        }
    }
}

// ─── P2-11 ① explore 顶层 JS 绑定回归（src 重绑定 / book=null）──────────────

#[cfg(all(test, feature = "quickjs"))]
mod explore_binding_tests {
    use super::*;
    use legado_core::models::BookSource;

    /// 与生产 `explore_books_async` 同一构造路径（explore_api.rs L567/L575）：
    /// 原始响应文本（`response.body: String`）→ `serde_json::to_string` 得
    /// JSON 字符串字面量（宿主 `java.*` 单参形态读 `globals().src` 期望 JS
    /// 字符串，与搜索路径 `bind_orig_src` 约定一致）→ 顶层分析器 +
    /// [`with_explore_top_bindings`]（src=顶层响应文本、book=null）。
    fn explore_top_analyzer(body: &str) -> legado_parser::AnalyzeRule {
        let source = BookSource::default();
        let body_src_json = serde_json::to_string(body).unwrap();
        let analyzer = crate::js_executor::construct_analyzer_with_source_context(
            body.to_string(),
            "https://explore.example.com/list".to_string(),
            &source.book_source_url,
            None,
            None,
        );
        with_explore_top_bindings(analyzer, &body_src_json)
    }

    /// P2-11 ① 验收 1：bookList 链式步 2 用单参 `java.*` 必须重解析**顶层原始
    /// 发现响应体**，而非步 1 的中间产物。
    ///
    /// 步 1 `$.data.items[*]` 提取出 2 个元素（中间产物 = items 数组）；
    /// 步 2 `@js:JSON.stringify(java.getStringList('$.pageMeta.root'))`：
    /// 单参 `java.getStringList`（宿主 quickjs_impl 单参形态读 `globals().src`）
    /// 对齐上游 `AnalyzeRule.getStringList(rule, null)` 的
    /// `mContent ?: this.content`（this.content 不被规则链更新，见
    /// web_book.rs `bind_orig_src` 注释；上游 AnalyzeRule.kt L904
    /// `bindings["src"] = content`）。修复前 explore 链式子步 `src` 为中间
    /// 产物（P2-11 §194 残差）→ `$.pageMeta.root` 落空 → 空列表；修复后
    /// `src` = 顶层响应体 → `["ROOT-777"]`。
    #[test]
    fn test_explore_chained_step_src_is_top_level_body() {
        // 原始发现响应文本（生产：`response.body: String`）
        let body = serde_json::json!({
            "pageMeta": { "root": "ROOT-777" },
            "data": { "items": [ { "n": "book-a" }, { "n": "book-b" } ] }
        })
        .to_string();
        let analyzer = explore_top_analyzer(&body);

        let rule = "$.data.items[*]\n@js:JSON.stringify(java.getStringList('$.pageMeta.root'))";
        let elements = analyzer
            .get_elements(rule)
            .unwrap_or_else(|e| panic!("链式 bookList 规则解析失败: {e}"));
        assert_eq!(
            elements,
            vec!["ROOT-777"],
            "链式步 2 的单参 java.* 必须重解析顶层原始响应体（而非中间产物），实际: {elements:?}"
        );
    }

    /// P2-11 ① 验收 2：explore 顶层 `book` 绑定值与上游一致 = `null`（JS
    /// null，而非 undefined、而非未声明）。
    ///
    /// 上游 `WebBook.exploreBookAwait`（WebBook.kt L131-148）用裸
    /// `val ruleData = RuleData()`（L137）；`AnalyzeRule.book get() =
    /// ruleData as? BaseBook`（AnalyzeRule.kt L68）→ null；`evalJS` 无条件
    /// `bindings["book"] = book`（L899）→ JS 侧 `book === null` 而非
    /// undefined。探测用三态哨兵字符串（未绑定 undefined → "UNDEFINED"；
    /// 绑定 null → "IS_NULL"；绑定非 null → 其 `String(book)` 值），修复前
    /// （无绑定）输出 "UNDEFINED" 断言失败，修复后输出 "IS_NULL" 通过。
    /// 不用 `String(book)` 直探：`normalize_js_rule_result`
    ///（analyze_rule.rs L2004-2007）把 "null"/"undefined" 结果归一为空 →
    /// `get_string` 恒得 ""，无法区分三态。
    #[test]
    fn test_explore_top_level_book_binding_is_null() {
        let body = serde_json::json!({ "data": { "items": [] } }).to_string();
        let analyzer = explore_top_analyzer(&body);

        let probe = analyzer
            .get_string(
                "@js:typeof book === 'undefined' ? 'UNDEFINED' : (book === null ? 'IS_NULL' : String(book))",
            )
            .unwrap_or_else(|e| panic!("book 绑定探测失败: {e}"));
        assert_eq!(
            probe, "IS_NULL",
            "explore 顶层 book 应为 null（上游 WebBook.kt L137 裸 RuleData → AnalyzeRule.kt L68 as? BaseBook = null），实际: {probe}"
        );
    }
}

// ─── 测试 ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_explore_parse_url_text() {
        let json = explore_parse_url("玄幻::https://a.com\n都市::https://b.com", "").unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert_eq!(categories.len(), 2);
        assert_eq!(categories[0].title, "玄幻");
    }

    #[test]
    fn test_explore_parse_url_empty() {
        let json = explore_parse_url("", "").unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert!(categories.is_empty());
    }

    #[test]
    fn test_explore_parse_url_json_with_style() {
        let input = r#"[{"title":"都市","url":"http://example.com/a","style":{"layout_flexGrow":1,"layout_flexBasisPercent":1}},{"title":"玄幻","url":"http://example.com/b","style":{"layout_flexGrow":1,"layout_flexBasisPercent":0.25}}]"#;
        let json = explore_parse_url(input, "").unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert_eq!(categories.len(), 2);
        assert_eq!(categories[0].title, "都市");
        assert_eq!(categories[0].url, Some("http://example.com/a".to_string()));
        let style0 = categories[0].style.as_ref().unwrap();
        assert!((style0.layout_flex_basis_percent - 1.0).abs() < f32::EPSILON);
        let style1 = categories[1].style.as_ref().unwrap();
        assert!((style1.layout_flex_basis_percent - 0.25).abs() < f32::EPSILON);
    }

    #[test]
    fn test_explore_parse_url_text_without_source_json() {
        let json = explore_parse_url("玄幻::https://a.com\n都市::https://b.com", "").unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert_eq!(categories.len(), 2);
        assert_eq!(categories[0].title, "玄幻");
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_parse_url_js_returns_json_array() {
        let source = BookSource {
            book_source_url: "https://explore-js.test".to_string(),
            book_source_name: "JS测试".to_string(),
            ..BookSource::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let explore_url = "@js:[{title:'热门',url:'/hot'},{title:'新书',url:'/new'}]";
        let json = explore_parse_url(explore_url, &source_json).unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert_eq!(categories.len(), 2);
        assert_eq!(categories[0].title, "热门");
        assert_eq!(categories[0].url, Some("/hot".to_string()));
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_parse_url_js_source_get_put() {
        // 探索 URL 解析 JS：source.get/put 绑定读写全局变量表
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let source = BookSource {
            book_source_url: "https://explore-get.test".to_string(),
            book_source_name: "get/put".to_string(),
            ..BookSource::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let explore_url = r#"@js:
source.put('k','v');
if(source.get('k')!=='v'){throw new Error('source.get/put failed');}
[{title:'OK',url:'/ok'}]"#;
        let json = explore_parse_url(explore_url, &source_json).unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert_eq!(categories.len(), 1);
        assert_eq!(categories[0].title, "OK");
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_parse_url_js_java_get_put() {
        // 探索 URL 解析 JS：java.get 单参读全局变量表 / java.put 写全局表
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let source = BookSource {
            book_source_url: "https://explore-java.test".to_string(),
            book_source_name: "java.get".to_string(),
            ..BookSource::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let explore_url = r#"@js:
java.put('mode','audio');
if(java.get('mode')!=='audio'){throw new Error('java.get failed');}
if(source.get('mode')!=='audio'){throw new Error('source.get failed');}
[{title:'线路',type:'select',url:'',style:{layout_flexBasisPercent:0.5}}]"#;
        let json = explore_parse_url(explore_url, &source_json).unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert_eq!(categories.len(), 1);
        assert_eq!(categories[0].title, "线路");
        assert_eq!(categories[0].r#type, "select");
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_parse_url_js_aggregate_explore_kinds() {
        // 聚合探索 JS：java.get + source.getLoginHeader 读全局变量表，
        // 并写登录缓存 → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        use crate::api::source_login_cache;
        let main_js = r#"
function exploreKinds() {
  var mode = java.get('mode') || '小说';
  var header = source.getLoginHeader();
  if (header) java.put('hasHeader', '1');
  infoMap['模式'] = mode;
  return [
    {title: '线路', type: 'select', chars: ['线路A','线路B'], style: {layout_flexBasisPercent: 0.5}},
    {title: '模式', type: 'select', chars: ['小说','听书'], url: ''},
    {title: '登录番茄', type: 'button', action: "java.refreshExplore()"},
    {title: mode + '榜', type: 'url', url: '/rank/hot'}
  ];
}
"#;
        let source = BookSource {
            book_source_url: "https://dahuiwolf.test".to_string(),
            book_source_name: "大灰狼模拟".to_string(),
            main_js: Some(main_js.to_string()),
            login_url: Some("function login(){return true;}".to_string()),
            ..BookSource::default()
        };
        source_login_cache::put_login_header(
            &source.book_source_url,
            r#"{"Authorization":"Bearer x"}"#,
        )
        .unwrap();
        let source_json = serde_json::to_string(&source).unwrap();
        let json = explore_parse_url("@js:exploreKinds()", &source_json).unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert!(categories.len() >= 4, "categories: {json}");
        assert_eq!(categories[0].title, "线路");
        assert_eq!(categories[0].r#type, "select");
        assert_eq!(categories[2].title, "登录番茄");
        assert_eq!(categories[2].r#type, "button");
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_parse_url_js_host_from_jslib() {
        // 大灰狼 jsLib 探索解析：source.getVariable/setVariable 读写全局表
        // → 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let js_lib = r#"var host = ['https://api.dahuiwolf.test','https://backup.test'];
function getArguments(open_argument, key) {
  try { open_argument = JSON.parse(open_argument); } catch (e) { open_argument = { server: host[0] }; }
  return key ? open_argument[key] : open_argument;
}
function createFilter(title, chars, current, key, flex) {
  return { title: title, type: 'select', chars: chars, url: '', style: { layout_flexBasisPercent: flex } };
}"#;
        let explore_url = r#"<js>
var open_argument = source.getVariable();
if (!open_argument || open_argument == '') {
  var initData = { tab: '小说', server: host[0], sources: '番茄' };
  source.setVariable(JSON.stringify(initData));
}
var base_url = getArguments(open_argument, 'server') || host[0];
var qtsj = [];
qtsj.push(createFilter('线路', host, base_url, 'server', 1));
JSON.stringify(qtsj.concat([{title: base_url + '榜', url: '/rank'}]));
</js>"#;
        let source = BookSource {
            book_source_url: "大灰狼融合VIP5.0".to_string(),
            book_source_name: "大灰狼模拟".to_string(),
            js_lib: Some(js_lib.to_string()),
            explore_url: Some(explore_url.to_string()),
            ..BookSource::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let json = explore_parse_url(explore_url, &source_json).unwrap();
        let categories: Vec<ExploreCategory> = serde_json::from_str(&json).unwrap();
        assert!(
            categories.len() >= 2,
            "应解析出 selector + 榜单，实际: {json}"
        );
        assert_eq!(categories[0].title, "线路");
        assert_eq!(categories[0].r#type, "select");
        assert!(
            categories[1].title.contains("https://api.dahuiwolf.test"),
            "榜单标题应含 host[0]: {}",
            categories[1].title
        );
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_parse_url_dahuiwolf_from_env() {
        // 大灰狼 env 探源（启用时执行真实 jsLib 探索 JS，source. 绑定读写
        // 全局表）→ 持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let Ok(explore_url) = std::env::var("DAHUI_EXPLORE_URL") else {
            return;
        };
        let Ok(source_json) = std::env::var("DAHUI_SOURCE_JSON") else {
            return;
        };
        let json = explore_parse_url(&explore_url, &source_json).unwrap_or_else(|e| {
            panic!("大灰狼 explore 解析失败: {e}");
        });
        assert!(
            !json.contains("host is not defined"),
            "不应含 host 错误: {json}"
        );
        let categories: Vec<ExploreCategory> =
            serde_json::from_str(&json).unwrap_or_else(|e| panic!("JSON 解析失败: {e} | {json}"));
        assert!(!categories.is_empty(), "分类为空: {json}");
        if let Some(err) = categories.iter().find(|c| c.title == "ERROR") {
            panic!("ERROR 分类: {}", err.url.as_deref().unwrap_or(""));
        }
        let has_selector = categories
            .iter()
            .any(|c| c.title.contains("线路") || c.title.contains("模式") || c.r#type == "select");
        if !has_selector {
            let login_only = !categories.is_empty()
                && categories.iter().all(|c| {
                    c.title.contains("登录")
                        || c.url.as_deref().unwrap_or("").contains("startBrowser")
                });
            assert!(
                login_only,
                "应含 selector/线路/模式，或未登录时的登录入口，实际: {json}"
            );
        }
    }

    #[test]
    fn test_explore_parse_url_js_requires_source_json() {
        let err = explore_parse_url("@js:[]", "").unwrap_err();
        assert!(err.to_string().contains("书源 JSON"));
    }

    #[test]
    fn test_explore_fetch_books_invalid_source_json() {
        let err = explore_fetch_books("not valid json", "https://example.com", 1).unwrap_err();
        assert!(matches!(err, LegadoError::Serialization(_)));
    }

    #[test]
    fn test_explore_fetch_books_empty_url() {
        let source_json = serde_json::to_string(&BookSource::default()).unwrap();
        let err = explore_fetch_books(&source_json, "", 1).unwrap_err();
        assert!(err.to_string().contains("URL 为空"));
    }

    /// 发现页 URL 组装：`{{page}}` 须展开为页码，禁止误伤成字面量 `{1}`（思路客回归）
    #[test]
    fn test_explore_analyze_url_double_brace_page() {
        let analyze = AnalyzeUrl::new(
            "/list1/{{page}}.html",
            None,
            Some(1),
            "http://www.silukezw.com",
            None,
        );
        assert_eq!(analyze.url(), "http://www.silukezw.com/list1/1.html");
        assert!(
            !analyze.url().contains('{'),
            "URL 不得残留花括号占位: {}",
            analyze.url()
        );
    }

    /// 回环夹具服务器：`/list1/*` 路径投递固定 HTML 样本，其余路径 404——
    /// 思路客发现用例离线化（2026-09-19），不再发外网请求
    fn spawn_explore_fixture_server(fixture: &str) -> u16 {
        use std::io::{Read, Write};
        let body: Vec<u8> = fixture.as_bytes().to_vec();
        let listener =
            std::net::TcpListener::bind("127.0.0.1:0").expect("bind 思路客发现夹具服务器");
        let port = listener.local_addr().unwrap().port();
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(mut stream) = stream else { continue };
                let mut buf: Vec<u8> = Vec::new();
                let mut one = [0u8; 1];
                while !buf.ends_with(b"\r\n\r\n") {
                    match stream.read(&mut one) {
                        Ok(1) => buf.push(one[0]),
                        _ => break,
                    }
                    if buf.len() > 16 * 1024 {
                        break;
                    }
                }
                let head = String::from_utf8_lossy(&buf).to_string();
                let target = head
                    .lines()
                    .next()
                    .unwrap_or("")
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("/")
                    .to_string();
                let path_only = target.split('?').next().unwrap_or("/");
                let (status, status_text, resp_body) = if path_only.starts_with("/list1/") {
                    (200, "OK", body.clone())
                } else {
                    (404, "Not Found", b"not found".to_vec())
                };
                let resp = format!(
                    "HTTP/1.1 {status} {status_text}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    resp_body.len()
                );
                let _ = stream.write_all(resp.as_bytes());
                let _ = stream.write_all(&resp_body);
                let _ = stream.flush();
            }
        });
        port
    }

    /// 发现页回归：思路客「玄幻」页码展开后应成功并解析到书名（夹具化）
    ///
    /// 2026-09-19 夹具化：原为直连 `www.silukezw.com` 的联网用例
    /// （`#[ignore = "requires network access"]`）。现取当日一次真实抓取的
    /// 固定样本 `tests/fixtures/siluke_explore_xuanhuan_p1.html`
    /// （抓取 URL 与时间见文件头注释），由 127.0.0.1 回环夹具服务器
    /// 投递，书源 URL 指向回环地址——测试运行期间不再发外网请求；
    /// 断言语义不变（≥5 本、bookUrl 多数非空、无 `{{page}}` 残留、
    /// 错误信息不得含占位符 404）。
    /// 注意：`explore_books_async` 复用 `http_state::shared_client()`
    /// （默认配置，随宿主 env 代理路由）——无代理环境全离线可跑；代理
    /// 环境下回环流量可能被劫持（需 http_state 层注入 no_proxy 客户端，
    /// 该文件在本次文件避让范围内，属后续项）。
    #[test]
    fn test_explore_fetch_siluke_xuanhuan_live() {
        // P2-1：explore_fetch_books 入口执行 begin_book_flow（切 flow
        // scope）→ 触碰全局 store 状态，须与其它 store 测试串行（共享
        // crate 级 test_support 锁）；结尾复位 flow scope
        let _lock = crate::test_support::lock_global_store();
        // 回环夹具服务器：投递固定样本（抓取说明见夹具文件头注释）
        let fixture = std::fs::read_to_string("tests/fixtures/siluke_explore_xuanhuan_p1.html")
            .expect("夹具文件缺失: tests/fixtures/siluke_explore_xuanhuan_p1.html");
        let port = spawn_explore_fixture_server(&fixture);
        let base = format!("http://127.0.0.1:{port}");
        let source = serde_json::json!({
            "bookSourceUrl": base,
            "bookSourceName": "思路客#2",
            "bookSourceType": 0,
            "ruleExplore": {
                "bookList": "",
                "name": "",
                "author": "",
                "bookUrl": "",
                "coverUrl": ""
            },
            "ruleSearch": {
                "bookList": ".col-md-6@dl",
                "name": "h3@a@text##.*\\]|小说全文阅读|小说全集",
                "author": "dd.1@span.0@text",
                "bookUrl": "a.0@href",
                "coverUrl": "img@src",
                "kind": "dd.2:3@text##.*：|.*：",
                "lastChapter": "dd.4@a@text"
            }
        });
        let source_json = source.to_string();
        let result = explore_fetch_books(&source_json, "/list1/{{page}}.html", 1);
        match result {
            Ok(json) => {
                assert!(!json.contains("{1}"), "响应不得含未替换占位: {json}");
                let books: Vec<serde_json::Value> =
                    serde_json::from_str(&json).expect("应为书籍 JSON 数组");
                eprintln!("siluke explore books={}", books.len());
                let empty_url = books
                    .iter()
                    .filter(|b| {
                        b.get("bookUrl")
                            .or_else(|| b.get("book_url"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .is_empty()
                    })
                    .count();
                assert!(
                    books.len() >= 5,
                    "思路客玄幻发现应有多本书，实际 {} 本: {json}",
                    books.len()
                );
                assert!(
                    empty_url < books.len() / 2,
                    "多数书籍 bookUrl 为空会导致 Flutter 按 URL 去重后只剩 1 本: {json}"
                );
            }
            Err(e) => {
                let msg = e.to_string();
                assert!(
                    !msg.contains("{1}"),
                    "失败信息不得含未替换占位 {{1}}: {msg}"
                );
                assert!(!msg.contains("404"), "页码未替换导致的 404 回归: {msg}");
                panic!("网络/解析失败（非占位符问题）: {msg}");
            }
        }
    }

    /// 猫眼看书形态回归（15 号实机缺陷）：空 mime data URI
    /// （`data:;base64,<b64>`，书源实际形态带 `,{"type":"maoyankanshu"}` 选项）
    /// 必须本地解码、绝不进 reqwest（reqwest 不支持 data: 协议 → 实机
    /// 「builder error for url (data:;base64,...)」）。
    ///
    /// 修复前：client.get(data: URI) → `请求发现页失败: builder error...`；
    /// 修复后：本地解码出书籍 JSON → 源「能出结果」（书名可解析）。
    #[test]
    fn test_explore_fetch_data_uri_empty_mime_decoded_locally() {
        let _lock = crate::test_support::lock_global_store();
        // base64(`[{"name":"解码成功"}]`)——空 mime 形态（无 type 选项 → 文本语义）
        let url = "data:;base64,W3sibmFtZSI6Iuino+eggeaIkOWKnyJ9XQ==";
        let source = serde_json::json!({
            "bookSourceUrl": "https://data-uri-explore.test",
            "bookSourceName": "data URI 回归",
            "bookSourceType": 0,
            "ruleExplore": {
                "bookList": "$[*]",
                "name": "$.name"
            }
        });
        let out = explore_fetch_books(&source.to_string(), url, 1);
        match out {
            Ok(json) => {
                assert!(
                    json.contains("解码成功"),
                    "空 mime data URI 应本地解码出书籍（不发起请求）: {json}"
                );
            }
            Err(e) => {
                panic!("空 mime data URI 不得进 reqwest（builder error 回归，实机 15 号形态）: {e}")
            }
        }
    }

    /// 带 `,{"type":...}` 选项的空 mime data URI（猫眼分类 URL 精确形态）：
    /// type 非空 → 按上游语义回 hex 编码字节（书源 JS 再 hexDecodeToString
    /// 还原，`{$.type}` 消费点），同样不得进 reqwest；同时锁定「直接消费已
    /// 解析 AnalyzeUrl 的 response_type」不回退成纯文本（二次 parse 丢失
    /// 选项会退化为文本 → hexDecodeToString 解不出 JSON）。
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_explore_fetch_data_uri_with_type_option_decoded_locally() {
        let _lock = crate::test_support::lock_global_store();
        // base64(`[{"name":"解码成功"}]`) + type 选项
        let url = "data:;base64,W3sibmFtZSI6Iuino+eggeaIkOWKnyJ9XQ==,{\"type\":\"maoyankanshu\"}";
        let source = serde_json::json!({
            "bookSourceUrl": "https://data-uri-explore-type.test",
            "bookSourceName": "data URI type 回归",
            "bookSourceType": 0,
            "ruleExplore": {
                // 书源侧消费语义：hexDecodeToString(hex 文本) 还原 JSON 列表
                "bookList": "<js>java.hexDecodeToString(result)</js>\n$[*]",
                "name": "$.name"
            }
        });
        let out = explore_fetch_books(&source.to_string(), url, 1);
        match out {
            Ok(json) => assert!(
                json.contains("解码成功"),
                "type 非空应回 hex 编码字节并经 hexDecodeToString 还原（非纯文本）: {json}"
            ),
            Err(e) => panic!("带 type 选项的空 mime data URI 不得进 reqwest: {e}"),
        }
    }
}
