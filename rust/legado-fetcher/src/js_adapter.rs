//! JS 适配层（自 `legado-ffi/src/js_executor.rs` 与 `api/source_js_bindings.rs`
//! 平移的纯函数面，P5 子批 2a）
//!
//! 把 legado-js 的 QuickJS 执行器适配为 legado-parser 期望的
//! [`legado_parser::JsExecutor`]，供书源规则 `@js:` / `<js>` / `{{JS}}`
//! 模板执行。JS 执行以 `quickjs` 门控；默认档不注入 JS 执行器，仍显式注入变量读者。
//!
//! 宿主侧（legado-ffi `js_executor`）用薄适配注入根实例的 JsResources，
//! 规则与模板算法只保留本 crate 一份实现。

use legado_parser::{AnalyzeRule, AnalyzeUrl};

/// 无 VM 档仍须跟随显式能力；未迁移消费者保持原来的读者。
#[cfg(not(feature = "quickjs"))]
fn variable_reader(resources: &legado_js::JsResources) -> legado_parser::VariableReader {
    resources.variable_reader()
}

/// 从书源 jsLib 提取 `var host = [...];`（大灰狼等聚合源 explore 依赖）
///
/// [P5 尾项] 自 `legado-ffi/src/api/source_js_bindings.rs` 平移（ffi 侧保留
/// 同名 re-export），供 `source_setup` 的 host 兜底与 ffi explore 路径共用。
pub fn extract_js_lib_host_decl(js_lib: &str) -> Option<String> {
    let trimmed = js_lib.trim();
    let start = trimmed.find("var host")?;
    let slice = &trimmed[start..];
    let bracket = slice.find('[')?;
    let mut depth = 0usize;
    for (i, ch) in slice[bracket..].char_indices() {
        match ch {
            '[' => depth += 1,
            ']' => {
                depth = depth.saturating_sub(1);
                if depth == 0 {
                    let end = bracket + i + 1;
                    let mut decl_end = end;
                    if slice[end..].starts_with(';') {
                        decl_end = end + 1;
                    }
                    return Some(slice[..decl_end].trim().to_string());
                }
            }
            _ => {}
        }
    }
    None
}

/// 构造规则解析器并注入书源 jsLib（规则 `<js>`/`@js:` 模板执行前先加载库）
///
/// [UI-fix 2026-08-10 | Reasonix] yckceo 书源的 searchUrl/ruleContent 模板
/// 常引用 jsLib 定义（如 `<js>eval(String(Reload('...')))` 的 Reload、聚合源
/// 的 getHosts() 等），此前模板 JS 执行器不注入 jsLib → 这些书源搜索 URL
/// 构建失败 → 无结果。对齐原版：每次 JS 执行前先 eval 书源 jsLib。
#[cfg(feature = "quickjs")]
pub fn construct_analyzer_with_js_lib(
    resources: &std::sync::Arc<legado_js::JsResources>,
    content: String,
    base_url: String,
    source_tag: &str,
    js_lib: Option<&str>,
) -> AnalyzeRule {
    let executor = legado_js::executor::QuickJsExecutor::new(source_tag)
        .with_resources(resources.clone())
        .with_js_lib(js_lib.map(|s| s.to_string()));
    AnalyzeRule::with_js_executor(content, base_url, std::sync::Arc::new(executor))
}

/// 非 quickjs 构建下的降级实现
#[cfg(not(feature = "quickjs"))]
pub fn construct_analyzer_with_js_lib(
    resources: &std::sync::Arc<legado_js::JsResources>,
    content: String,
    base_url: String,
    source_tag: &str,
    _js_lib: Option<&str>,
) -> AnalyzeRule {
    AnalyzeRule::new(content, base_url)
        .with_variable_reader(variable_reader(resources))
        .with_webview_executor(legado_js::webview::executor(resources, source_tag))
}

/// 构造规则解析器：注入书源 jsLib + 书源上下文 setup（source/cookie 绑定）
///
/// 发现页书籍列表解析专用：聚合源（书山聚合等）的 ruleExplore.bookList
/// `<js>` 脚本无条件调用 jsLib 函数（getSessionId/getServerHost 等），
/// 且部分函数 `let { source, cookie } = this` 依赖书源上下文；此前
/// [`construct_analyzer_with_js_lib`] 仅注入空 jsLib（无 setup），`getSessionId is
/// not defined` ReferenceError → 列表解析失败 →「暂无书籍」。
/// — DeepSeek Harness + Bridge（2026-08-14 发现页修复：书山空列表）
#[cfg(feature = "quickjs")]
pub fn construct_analyzer_with_source_context(
    resources: &std::sync::Arc<legado_js::JsResources>,
    content: String,
    base_url: String,
    source_tag: &str,
    js_lib: Option<&str>,
    setup_script: Option<String>,
) -> AnalyzeRule {
    let executor = legado_js::executor::QuickJsExecutor::new(source_tag)
        .with_resources(resources.clone())
        .with_js_lib(js_lib.map(|s| s.to_string()))
        .with_setup_script(setup_script);
    AnalyzeRule::with_js_executor(content, base_url, std::sync::Arc::new(executor))
}

/// 非 quickjs 构建下的降级实现
#[cfg(not(feature = "quickjs"))]
pub fn construct_analyzer_with_source_context(
    resources: &std::sync::Arc<legado_js::JsResources>,
    content: String,
    base_url: String,
    source_tag: &str,
    _js_lib: Option<&str>,
    _setup_script: Option<String>,
) -> AnalyzeRule {
    AnalyzeRule::new(content, base_url)
        .with_variable_reader(variable_reader(resources))
        .with_webview_executor(legado_js::webview::executor(resources, source_tag))
}

/// 目录分页共享上下文（循环不变部分收敛）
///
/// [性能专项 2026-09-24 | 登记项] 目录分页每页重复开销收敛：同一书源的
/// 分页循环里，`source_tag` / jsLib / setup 脚本属循环不变量。改前逐页经
/// [`construct_analyzer_with_source_context`] 重建执行器（重复克隆 jsLib +
/// setup 串、每次新建 `Arc<QuickJsExecutor>`）；底层引擎本就按
/// `executor:<source_tag>` 缓存一次、执行器本身无状态，逐页重建只有
/// 克隆/分配开销。此处循环前构建一次，`Arc<dyn JsExecutor>` 在各构造点
/// 共享；逐页输入仅剩本页 `content` / `base_url`（+ 逐页 `src` 绑定序列化）。
#[cfg(feature = "quickjs")]
pub type TocPageContext = std::sync::Arc<dyn legado_parser::JsExecutor>;

/// 构建目录分页共享上下文（quickjs 档）
///
/// `setup_script` 按值传入（循环不变量，只移动一次）；传 `None` 得到与
/// [`construct_analyzer_with_js_lib`] 同谱的执行器（无 setup 绑定）。
#[cfg(feature = "quickjs")]
pub fn build_toc_page_context(
    resources: &std::sync::Arc<legado_js::JsResources>,
    source_tag: &str,
    js_lib: Option<&str>,
    setup_script: Option<String>,
) -> TocPageContext {
    std::sync::Arc::new(
        legado_js::executor::QuickJsExecutor::new(source_tag)
            .with_resources(resources.clone())
            .with_js_lib(js_lib.map(|s| s.to_string()))
            .with_setup_script(setup_script),
    )
}

/// 从共享上下文构造目录页解析器（quickjs 档）
///
/// 执行器跨构造点/跨页共享（引擎缓存见 [`build_toc_page_context`] 文档）；
/// 抓取/截断/上限/取消语义不变——仅构造开销收敛。
#[cfg(feature = "quickjs")]
pub fn construct_toc_page_analyzer(
    ctx: &TocPageContext,
    content: String,
    base_url: String,
) -> AnalyzeRule {
    AnalyzeRule::with_js_executor(content, base_url, ctx.clone())
}

/// 非 quickjs 构建下的降级实现
///
/// 该档无 JS 执行器，但目录每页仍携带同一实例的变量读取能力。
#[cfg(not(feature = "quickjs"))]
pub struct TocPageContext(
    legado_parser::VariableReader,
    legado_parser::analyze_rule::WebViewExecutor,
);

/// 非quickjs档携带变量与WebView数据能力，不创建VM。
#[cfg(not(feature = "quickjs"))]
pub fn build_toc_page_context(
    resources: &std::sync::Arc<legado_js::JsResources>,
    source_tag: &str,
    _js_lib: Option<&str>,
    _setup_script: Option<String>,
) -> TocPageContext {
    TocPageContext(
        variable_reader(resources),
        legado_js::webview::executor(resources, source_tag),
    )
}

/// 非 quickjs 档：原样降级
#[cfg(not(feature = "quickjs"))]
pub fn construct_toc_page_analyzer(
    ctx: &TocPageContext,
    content: String,
    base_url: String,
) -> AnalyzeRule {
    AnalyzeRule::new(content, base_url)
        .with_variable_reader(ctx.0.clone())
        .with_webview_executor(ctx.1.clone())
}

/// 构建搜索 URL（携带书源 jsLib + 书源上下文 setup）
///
/// 对齐原版 AnalyzeUrl.kt evalJS：搜索模板 `{{source.getKey()}}` 等依赖
/// source/cookie 绑定（爱下电子等源 searchUrl 用 `{{source.getKey()}}/search`）；
/// 仅注入 jsLib 无 setup → source 未定义 → URL 构建失败 → 搜索结果为空。
/// — 聚合/上下文书源搜索修复（2026-08-17）
pub fn build_search_url_with_setup(
    resources: &std::sync::Arc<legado_js::JsResources>,
    template: &str,
    keyword: &str,
    page: i32,
    source_tag: &str,
    js_lib: Option<&str>,
    setup_script: Option<String>,
) -> AnalyzeUrl {
    let page_u32 = page.max(1) as u32;
    // 含任一 JS 语法（{{表达式}} / <js> 内嵌 / @js: 前缀）都走 JS 求值路径：
    // [UI-fix 2026-08-10 | Reasonix] <js>/@js: 模板此前落入旧版字面路径，
    // 而 AnalyzeUrl::new 不执行内嵌 JS → yckceo 漫画源 searchUrl 构建失败
    if template.contains("{{") || template.contains("<js>") || template.contains("@js:") {
        // searchKey 字面替换（对齐旧版 init_url 行为）
        let pre = template.replace("searchKey", keyword);
        // 变量集对齐原版 AnalyzeUrl.kt evalJS 绑定：key/page/baseUrl
        // （searchKey 额外注入，使 `{{searchKey}}` 模板亦可渲染）
        let mut variables = std::collections::HashMap::new();
        variables.insert("key".to_string(), keyword.to_string());
        variables.insert("page".to_string(), page.to_string());
        variables.insert("baseUrl".to_string(), source_tag.to_string());
        variables.insert("searchKey".to_string(), keyword.to_string());
        match search_url_with_js(
            resources,
            &pre,
            &variables,
            page,
            source_tag,
            js_lib,
            setup_script,
        ) {
            Ok(analyzed) => return analyzed,
            Err(e) => {
                // @js:/<js> 主模板失败时禁止字面回退（否则会把脚本文本当 URL
                // → HTTP 404/403，云霄小说/键盘小说/玄幻文学等实测）。
                // 对齐 explore_url_with_js：JS 失败上抛语义；此处返回类型仍为
                // AnalyzeUrl，用明确错误占位 URL 让上层 fetch 失败可辨。
                let trimmed = template.trim_start();
                let js_primary = trimmed.starts_with("@js:")
                    || trimmed.starts_with("<js>")
                    || template.contains("<js>");
                if js_primary {
                    eprintln!(
                        "[build_search_url] @js/<js> 求值失败，拒绝字面回退: {}",
                        e.to_string().chars().take(200).collect::<String>()
                    );
                    return AnalyzeUrl::new(
                        &format!(
                            "legado-js-error://search?e={}",
                            urlencoding_lite(&e.to_string())
                        ),
                        Some(keyword),
                        Some(page_u32),
                        source_tag,
                        None,
                    );
                }
                eprintln!(
                    "[build_search_url] JS 模板求值失败，回退字面路径: {}",
                    e.to_string().chars().take(160).collect::<String>()
                );
            }
        }
    }
    // 旧版路径：字面占位符替换 + AnalyzeUrl::new
    let url_with_key = template
        .replace("{{key}}", keyword)
        .replace("{key}", keyword);
    AnalyzeUrl::new(
        &url_with_key,
        Some(keyword),
        Some(page_u32),
        source_tag,
        None,
    )
}

/// 极简 URL 编码（仅错误消息占位，避免引入额外依赖）
pub fn urlencoding_lite(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes().take(180) {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

/// [`urlencoding_lite`] 的逆操作：解码 `%XX` 百分号转义
pub fn percent_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hi = (bytes[i + 1] as char).to_digit(16);
            let lo = (bytes[i + 2] as char).to_digit(16);
            if let (Some(h), Some(l)) = (hi, lo) {
                out.push((h * 16 + l) as u8);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// 解码 `legado-js-error://search?e=<百分号编码>` 错误 URL，还原 JS 错误文本
///
/// `build_search_url_with_setup` 等在 JS 求值失败时以该错误 URL 携带真实错误
/// 文本（避免把 @js: 脚本文本拼进请求 URL）；搜索路径据此还原、标注为
/// `LegadoError::JsEngine` 上抛（error_class 仍为 `js_error`，契约不变）。
pub fn decode_js_error_url(url: &str) -> Option<String> {
    const PREFIX: &str = "legado-js-error://";
    let rest = url.strip_prefix(PREFIX)?;
    let query = rest.split_once('?').map(|(_, q)| q).unwrap_or("");
    let e_val = query.split('&').find_map(|kv| kv.strip_prefix("e="))?;
    Some(percent_decode(e_val))
}

/// 移除 jsLib 中 Rhino 特有行（`importClass`/`importPackage`/`Packages.` 行首），
/// 使 QuickJS 可**完整**加载 jsLib 并保留全部函数定义（含截断点之后的
/// `getConfig`/`getServerHost` 等）— 发现页修复（书山聚合等聚合源 ERROR）
///
/// 自 `legado-ffi/src/api/source_js_bindings.rs` 平移（ffi 侧保留 re-export）。
pub fn sanitize_js_lib_for_quickjs(js_lib: &str) -> String {
    let mut out = String::with_capacity(js_lib.len() + 64);
    for line in js_lib.lines() {
        let t = line.trim_start();
        if t.starts_with("importClass(")
            || t.starts_with("importPackage(")
            || t.starts_with("Packages.")
        {
            out.push_str("// [legado] Rhino 特有行已移除（QuickJS 兼容）\n");
        } else {
            out.push_str(line);
            out.push('\n');
        }
    }
    out
}

/// quickjs 启用：用 QuickJS 引擎求值 `{{expression}}`
///
/// 注入书源上下文 setup（source/cookie 绑定）——搜索模板 `{{source.getKey()}}`
/// 等依赖（爱下电子等源）；对齐原版 AnalyzeUrl.kt evalJS 的 source 绑定。
#[cfg(feature = "quickjs")]
fn search_url_with_js(
    resources: &std::sync::Arc<legado_js::JsResources>,
    template: &str,
    variables: &std::collections::HashMap<String, String>,
    page: i32,
    source_tag: &str,
    js_lib: Option<&str>,
    setup_script: Option<String>,
) -> legado_core::LegadoResult<AnalyzeUrl> {
    let executor = legado_js::executor::QuickJsExecutor::new(source_tag)
        .with_resources(resources.clone())
        .with_js_lib(js_lib.map(|s| s.to_string()))
        .with_setup_script(setup_script);
    AnalyzeUrl::parse_with_js(template, variables, page, &executor)
}

/// 未启用 quickjs：降级为标准 parse（简单变量查找，复杂表达式保留原样）
#[cfg(not(feature = "quickjs"))]
fn search_url_with_js(
    _resources: &std::sync::Arc<legado_js::JsResources>,
    template: &str,
    variables: &std::collections::HashMap<String, String>,
    page: i32,
    _source_tag: &str,
    _js_lib: Option<&str>,
    _setup_script: Option<String>,
) -> legado_core::LegadoResult<AnalyzeUrl> {
    AnalyzeUrl::parse(template, variables, page)
}

#[cfg(test)]
mod scoped_variable_tests {
    use super::*;
    use std::sync::Arc;

    #[test]
    fn rule_and_toc_parsers_keep_the_book_anchor_in_both_feature_modes() {
        let resources = Arc::new(legado_js::JsResources::default());
        let a = resources.for_book("source-a", "same-book");
        let b = resources.for_book("source-b", "same-book");
        a.variable_scope()
            .unwrap()
            .set_book_variable("same-book", "key", "a")
            .unwrap();
        b.variable_scope()
            .unwrap()
            .set_book_variable("same-book", "key", "b")
            .unwrap();
        let rule = construct_analyzer_with_js_lib(&a, String::new(), String::new(), "tag", None);
        let contextual = construct_analyzer_with_source_context(
            &b,
            String::new(),
            String::new(),
            "tag",
            None,
            None,
        );
        let toc = build_toc_page_context(&a, "tag", None, None);
        assert_eq!(rule.get_string("@get:{key}").unwrap(), "a");
        assert_eq!(contextual.get_string("@get:{key}").unwrap(), "b");
        for page in ["first-page", "second-page"] {
            let parser = construct_toc_page_analyzer(&toc, String::new(), page.to_string());
            assert_eq!(parser.get_string("@get:{key}").unwrap(), "a");
            #[cfg(not(feature = "quickjs"))]
            assert!(
                parser.js_executor().is_none(),
                "无 JS 档不能为变量读取偷偷启用 VM"
            );
        }
        a.variable_scope()
            .unwrap()
            .put_flow_variable("key", "flow-a")
            .unwrap();
        assert_eq!(
            construct_toc_page_analyzer(&toc, String::new(), String::new())
                .get_string("@get:{key}")
                .unwrap(),
            "flow-a"
        );
        assert_eq!(contextual.get_string("@get:{key}").unwrap(), "b");
    }

    #[test]
    fn toc_context_does_not_keep_vm_resources_alive() {
        let resources = Arc::new(legado_js::JsResources::default());
        let weak_root = Arc::downgrade(&resources);
        let weak_store = Arc::downgrade(&resources.variables());
        let view = resources.for_book("source", "book");
        view.variable_scope()
            .unwrap()
            .set_book_variable("book", "key", "value")
            .unwrap();
        let context = build_toc_page_context(&view, "tag", None, None);
        drop((view, resources));
        assert!(weak_root.upgrade().is_none(), "目录上下文不持有根资源");
        assert_eq!(
            construct_toc_page_analyzer(&context, String::new(), String::new())
                .get_string("@get:{key}")
                .unwrap(),
            "value"
        );
        drop(context);
        assert!(weak_store.upgrade().is_none());
    }
}
