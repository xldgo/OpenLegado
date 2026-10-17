//! 发现URL求值与infoMap变量注入，宿主提供已捕获的source绑定。
#[cfg(feature = "quickjs")]
use legado_js::executor::QuickJsExecutor;
use legado_parser::AnalyzeUrl;
use std::collections::HashMap;

pub fn build_explore_url_with_setup(
    resources: &std::sync::Arc<legado_js::JsResources>,
    template: &str,
    page: i32,
    source: &legado_core::models::BookSource,
    info_map: &HashMap<String, String>,
    setup_script: Option<String>,
) -> legado_core::LegadoResult<AnalyzeUrl> {
    let source_tag = source.book_source_url.clone();
    let js_lib = source.js_lib.as_deref();
    let page_u32 = page.max(1) as u32;
    let mut variables = HashMap::new();
    variables.insert("page".to_string(), page.to_string());
    variables.insert("baseUrl".to_string(), source_tag.clone());
    for (k, v) in info_map {
        variables.insert(k.clone(), v.clone());
        variables.insert(format!("infoMap.{k}"), v.clone());
    }
    let info_json = serde_json::to_string(info_map).unwrap_or_else(|_| "{}".to_string());
    variables.insert("__infoMapJson".to_string(), info_json);

    // 书源上下文 setup 脚本（source/cookie 绑定 + BookSource 方法）

    if template.contains("{{") || template.contains("<js>") || template.contains("@js:") {
        // JS 求值失败**上抛真实错误**（对齐原版：懒人听书等需登录会话的
        // 书源未配置时 lrtsResolveSession 抛「请先登录…」应原样提示用户；
        // 此前静默回退字面量 URL 会把 @js: 脚本文本拼进请求 → HTTP 404
        // 误导（2026-08-14 用户反馈懒人听书发现页 http404））
        return explore_url_with_js(
            resources,
            template,
            &variables,
            page,
            &source_tag,
            js_lib,
            setup_script,
        );
    }
    Ok(AnalyzeUrl::new(
        template,
        None,
        Some(page_u32),
        &source_tag,
        None,
    ))
}

#[cfg(feature = "quickjs")]
fn explore_url_with_js(
    resources: &std::sync::Arc<legado_js::JsResources>,
    template: &str,
    variables: &HashMap<String, String>,
    page: i32,
    source_tag: &str,
    js_lib: Option<&str>,
    setup_script: Option<String>,
) -> legado_core::LegadoResult<AnalyzeUrl> {
    let info_json = variables
        .get("__infoMapJson")
        .cloned()
        .unwrap_or_else(|| "{}".to_string());
    let executor = ExploreInfoMapJsExecutor::with_resources(
        resources.clone(),
        source_tag,
        js_lib.map(|s| s.to_string()),
        info_json,
        setup_script,
        page,
        source_tag,
    );
    AnalyzeUrl::parse_with_js(template, variables, page, &executor)
}

#[cfg(not(feature = "quickjs"))]
fn explore_url_with_js(
    _resources: &std::sync::Arc<legado_js::JsResources>,
    template: &str,
    variables: &HashMap<String, String>,
    page: i32,
    _source_tag: &str,
    _js_lib: Option<&str>,
    _setup_script: Option<String>,
) -> legado_core::LegadoResult<AnalyzeUrl> {
    AnalyzeUrl::parse(template, variables, page)
}

#[cfg(feature = "quickjs")]
struct ExploreInfoMapJsExecutor {
    inner: QuickJsExecutor,
    info_map_json: String,
    page: i32,
    base_url: String,
}

#[cfg(feature = "quickjs")]
impl ExploreInfoMapJsExecutor {
    fn with_resources(
        resources: std::sync::Arc<legado_js::JsResources>,
        source_tag: &str,
        js_lib: Option<String>,
        info_map_json: String,
        setup_script: Option<String>,
        page: i32,
        base_url: &str,
    ) -> Self {
        Self {
            inner: QuickJsExecutor::new(source_tag)
                .with_resources(resources)
                .with_js_lib(js_lib)
                .with_setup_script(setup_script),
            info_map_json,
            page,
            base_url: base_url.to_string(),
        }
    }
}

#[cfg(feature = "quickjs")]
impl legado_parser::JsExecutor for ExploreInfoMapJsExecutor {
    fn read_variable(&self, key: &str) -> Option<String> {
        self.inner.read_variable(key)
    }

    fn execute_js(&self, js_code: &str) -> Result<String, String> {
        // [能力对账批次 2 | #702/#850] var → globalThis 属性注入（不注册全局
        // var 条目，与书源块顶层 let 声明不再冲突；读路径等价）
        let wrapped = format!(
            "globalThis.infoMap = {};\nglobalThis.page = {};\nglobalThis.baseUrl = {};\n{}",
            self.info_map_json,
            self.page,
            serde_json::to_string(&self.base_url).unwrap_or_else(|_| "\"\"".to_string()),
            js_code
        );
        self.inner.execute_js(&wrapped)
    }
}
