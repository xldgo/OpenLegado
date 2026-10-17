//! 书源 evalJS 上下文绑定（对标 Android `BaseSource.evalJS` bindings）

use legado_core::LegadoResult;
use legado_core::models::BookSource;

/// 从书源 jsLib 提取 `var host = [...];`（大灰狼等聚合源 explore 依赖）
///
/// [P5 尾项] 实现已平移 `legado_fetcher::js_adapter`（共享 crate 单一实现），
/// 本处保留同名 re-export（本模块内部调用与 ffi 调用方零改动）。
pub use legado_fetcher::js_adapter::extract_js_lib_host_decl;

/// 截取 jsLib 中 QuickJS 可执行的前缀（遇 Rhino `Packages`/`importClass` 行即截断）
pub use legado_fetcher::explore_js::js_lib_quickjs_prefix;

/// explore 降级：host 声明 + 前缀内全部顶层函数（至 Rhino 行之前）
pub use legado_fetcher::explore_js::js_lib_explore_fallback;

/// 非严格模式执行 JS 代码（对齐 Android Rhino 的 this 语义）
///
/// rquickjs `ctx.eval` 为严格模式：脚本内定义的函数裸调用时
/// `this=undefined`，书山等聚合源 jsLib 函数常用 `let { source } = this`
/// 访问书源 → `Cannot convert undefined or null to object`。
/// 经 `new Function` 参数传入 + 函数体内 `eval` 执行：代码在**非严格**
/// 作用域定义/执行，裸调用函数 `this=globalThis`（var source/java 已挂
/// 全局）✅ — 发现页修复（书山聚合等聚合源 ERROR）
#[cfg(feature = "quickjs")]
pub fn eval_js_non_strict(guard: &legado_js::QuickJsEngine, code: &str) -> Result<String, String> {
    use legado_js::JsEngine;
    let encoded = serde_json::to_string(code).map_err(|e| e.to_string())?;
    let wrapped = format!("new Function('__legadoCode', 'eval(__legadoCode);')({encoded})");
    guard.eval(&wrapped).map_err(|e| e.to_string())
}

/// 移除 jsLib 中 Rhino 特有行（`importClass`/`importPackage`/`Packages.` 行首），
/// 使 QuickJS 可**完整**加载 jsLib 并保留全部函数定义（含截断点之后的
/// `getConfig`/`getServerHost` 等）— 发现页修复（书山聚合等聚合源 ERROR）
///
/// P5 子批 2a：实现已随迁 `legado_fetcher::js_adapter`（共享 crate 单一实现），
/// 本处保留同名 re-export（本模块内部调用与 ffi 调用方零改动）。
pub use legado_fetcher::js_adapter::sanitize_js_lib_for_quickjs;

/// explore/callback 上下文加载 jsLib：URL 映射（cap 3）→ 完整 → sanitize 后完整 →
/// QuickJS 前缀 → 仅 host 声明
///
/// `source_tag` 用于 URL 映射拉取失败的台账键（`explore:{source_tag}`，与
/// 执行器路径 `executor:{source_tag}` 同构）
#[cfg(feature = "quickjs")]
pub use legado_fetcher::explore_js::load_js_lib_for_explore;

/// 生成 explore / action / login 等书源 JS 的 source/java 绑定脚本
///
/// [P5 尾项] 脚本生成实现已平移 `legado_fetcher::source_setup`（共享 crate
/// 单一实现）；本层保留宿主数据装配（explore infoMap 快照 + 登录缓存）与
/// 同名签名，ffi 调用方零改动。
pub fn book_source_js_setup_script(source: &BookSource) -> LegadoResult<String> {
    book_source_js_setup_script_with_login_cache(
        source,
        &crate::engine_holder::source_login_cache(),
        &crate::engine_holder::source_info_map(),
    )
}

/// 抓取依赖捕获本次服务，不在稍后的 setup 回调中重新寻找全局根实例。
#[cfg(feature = "quickjs")]
pub(crate) fn book_source_js_setup_script_with_login_cache(
    source: &BookSource,
    login_cache: &legado_engine::SourceLoginCache,
    info_maps: &legado_engine::SourceInfoMap,
) -> LegadoResult<String> {
    let tag = source.book_source_url.clone();
    let info_map = info_maps.snapshot(&tag);
    let login_header = login_cache.get_login_header(&tag);
    let login_info = login_cache.get_login_info(&tag);
    legado_fetcher::source_setup::book_source_js_setup_script(
        source,
        &info_map,
        login_header.as_deref(),
        login_info.as_deref(),
    )
}

#[cfg(not(feature = "quickjs"))]
pub(crate) fn book_source_js_setup_script_with_login_cache(
    _source: &BookSource,
    _login_cache: &legado_engine::SourceLoginCache,
    _info_maps: &legado_engine::SourceInfoMap,
) -> LegadoResult<String> {
    Ok(String::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(feature = "quickjs")]
    #[test]
    fn login_setup_uses_the_captured_service_instead_of_the_root_cache() {
        use legado_js::{JsEngine, JsResources, sandbox::SandboxConfig};
        let source = BookSource {
            book_source_url: "https://captured-login-setup.test".into(),
            ..Default::default()
        };
        for user in ["first-user", "second-user"] {
            let cache = std::sync::Arc::new(legado_engine::SourceLoginCache::default());
            cache.put_login_info(&source.book_source_url, user);
            let info_maps = legado_engine::SourceInfoMap::default();
            info_maps.put(&source.book_source_url, "用户", user);
            let setup =
                book_source_js_setup_script_with_login_cache(&source, &cache, &info_maps).unwrap();
            let engine = JsResources::default()
                .with_source_login_store(cache.clone())
                .create_engine(SandboxConfig::default().with_allow_script_run(true))
                .unwrap();
            engine.eval(&setup).unwrap();
            assert_eq!(engine.eval("source.getLoginInfo()").unwrap(), user);
            assert_eq!(engine.eval("infoMap['用户']").unwrap(), user);
        }
    }

    #[test]
    fn test_extract_js_lib_host_decl() {
        let lib = r#"var host = ['https://a.test', 'https://b.test'];
function foo() { return host[0]; }"#;
        let decl = extract_js_lib_host_decl(lib).unwrap();
        assert!(decl.starts_with("var host = ["));
        assert!(decl.contains("https://a.test"));
    }

    #[test]
    fn test_js_lib_quickjs_prefix_trims_packages() {
        let lib = "var host = [1];\nfunction ok(){}\nnew Packages.foo.Bar();\nvar x=1;";
        let prefix = js_lib_quickjs_prefix(lib);
        assert!(prefix.contains("var host"));
        assert!(!prefix.contains("Packages"));
    }

    #[test]
    fn test_js_lib_quickjs_prefix_balanced_when_packages_inside_function() {
        let lib = "var host = [1];\nfunction ok() { return 1; }\nfunction bad() {\n  new Packages.foo();\n}\nvar tail=1;";
        let prefix = js_lib_quickjs_prefix(lib);
        assert!(prefix.contains("function ok"));
        assert!(!prefix.contains("Packages"));
        assert!(!prefix.contains("function bad"));
    }

    /// sanitize 应移除 Rhino 特有行但保留全部函数定义（含 Packages 行之后的
    /// getConfig 等）— 发现页修复（书山聚合等聚合源 ERROR）
    #[test]
    fn test_sanitize_js_lib_keeps_functions_after_packages() {
        let lib = "var host = [];\nimportClass(Packages.java.util.HashMap);\nfunction getConfig(){return {};}\nfunction getServerHost(){return 'https://a.test';}\n";
        let cleaned = sanitize_js_lib_for_quickjs(lib);
        assert!(
            !cleaned.contains("importClass"),
            "Rhino importClass 行应移除"
        );
        assert!(
            cleaned.contains("function getConfig"),
            "getConfig 定义应保留"
        );
        assert!(
            cleaned.contains("function getServerHost"),
            "getServerHost 定义应保留"
        );
        assert!(cleaned.contains("var host"), "host 声明应保留");
    }
}
