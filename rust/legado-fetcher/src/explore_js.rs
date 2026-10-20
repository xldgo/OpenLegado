//! 发现及回调使用的jsLib兼容加载，沿用既有降级顺序。
use crate::js_adapter::extract_js_lib_host_decl;
#[cfg(feature = "quickjs")]
use crate::js_adapter::sanitize_js_lib_for_quickjs;

fn trim_js_to_balanced_prefix(s: &str) -> String {
    let mut depth = 0i32;
    let mut last_good = 0usize;
    for (i, ch) in s.char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    last_good = i + ch.len_utf8();
                }
            }
            _ => {}
        }
    }
    let trimmed = s.trim();
    if depth != 0 && last_good > 0 {
        trimmed[..last_good.min(trimmed.len())].trim().to_string()
    } else {
        trimmed.to_string()
    }
}

pub fn js_lib_quickjs_prefix(js_lib: &str) -> String {
    let markers = ["Packages.", "importClass(", "importPackage("];
    let mut cut = js_lib.len();
    for marker in markers {
        if let Some(idx) = js_lib.find(marker) {
            let line_start = js_lib[..idx].rfind('\n').map(|i| i + 1).unwrap_or(0);
            cut = cut.min(line_start);
        }
    }
    if cut >= js_lib.len() {
        return trim_js_to_balanced_prefix(js_lib);
    }
    trim_js_to_balanced_prefix(&js_lib[..cut])
}

pub fn js_lib_explore_fallback(js_lib: &str) -> String {
    let mut parts = Vec::new();
    if let Some(host) = extract_js_lib_host_decl(js_lib) {
        parts.push(host);
    }
    let prefix = js_lib_quickjs_prefix(js_lib);
    if !prefix.is_empty() {
        parts.push(prefix);
    }
    parts.join("\n")
}

#[cfg(feature = "quickjs")]
pub fn load_js_lib_for_explore(
    guard: &legado_js::QuickJsEngine,
    source_tag: &str,
    js_lib: Option<&str>,
) {
    use legado_js::JsEngine;

    let Some(lib) = js_lib.map(str::trim).filter(|s| !s.is_empty()) else {
        return;
    };

    // 0) cap 3（URL 映射 jsLib）：经加载器解析（共享客户端拉取 + 实例缓存 +
    //    逐条降级台账登记）→ eval 拼接脚本；非 URL 映射形态走下列原始级联
    let is_url_map = legado_js::host_api::jslib_loader::parse_js_lib_url_map(lib).is_some();
    if is_url_map {
        let ledger_tag = format!("explore:{}", source_tag);
        match legado_js::host_api::jslib_loader::resolve_js_lib_url_map(
            guard.http_resources(),
            lib,
            &ledger_tag,
            &|url| {
                legado_js::host_api::jslib_loader::default_js_lib_fetcher(
                    guard.http_resources(),
                    url,
                )
            },
        ) {
            Some(script) => {
                if guard.eval(&script).is_ok() {
                    return;
                }
                eprintln!("[explore] URL 映射 jsLib eval 失败（降级继续）");
            }
            // 全条拉取失败：加载器内已逐条记台账（上游「下载jsLib-…失败」措辞）
            None => eprintln!(
                "[explore] 书源 {source_tag} URL 映射 jsLib 全条拉取失败（台账已登记，降级继续）"
            ),
        }
        // URL 映射形态不回退原始级联（原始 JSON 非合法 JS，级联只会重复失败）
        return;
    }

    // 1) 完整 jsLib（引擎 eval 已非严格：全局可见 + 函数裸调用 this=globalThis，
    //    对齐 Rhino 语义；书山等聚合源函数 `let { source } = this` 可用）
    if guard.eval(lib).is_ok() {
        return;
    }

    // 2) 移除 Rhino 特有行后完整加载：聚合源 jsLib 尾部常含 `Packages.*`，
    //    整文件解析失败导致首部变量也不执行；sanitize 后保留全部函数定义
    let sanitized = sanitize_js_lib_for_quickjs(lib);
    if !sanitized.trim().is_empty() && guard.eval(&sanitized).is_ok() {
        eprintln!("[explore] jsLib 完整加载失败，已 sanitize 后加载（保留函数定义）");
        return;
    }

    // 3) 前缀降级（host 声明 + 前缀内顶层函数）
    let prefix = js_lib_quickjs_prefix(lib);
    if !prefix.is_empty() {
        match guard.eval(&prefix) {
            Ok(_) => return,
            Err(e) => eprintln!("[explore] jsLib 前缀加载失败: {e}"),
        }
    }

    let fallback = js_lib_explore_fallback(lib);
    if !fallback.is_empty() && guard.eval(&fallback).is_ok() {
        eprintln!("[explore] jsLib 完整加载失败，已降级 explore 符号集");
        return;
    }

    if let Some(host_decl) = extract_js_lib_host_decl(lib)
        && guard.eval(&host_decl).is_ok()
    {
        eprintln!("[explore] jsLib 完整加载失败，已预置 host 数组");
        return;
    }

    eprintln!("[explore] jsLib 加载失败（降级继续）");
}
