//! JS 单文件书源配置 FFI 层
//!
//! 对齐 Kotlin `JsSourceConfig.kt`，暴露三项能力：
//! - [`js_source_extract`]：执行 JS 书源脚本并提取顶层 config/source 配置，
//!   返回完整书源（需 quickjs 构建，否则返回错误）
//! - [`js_source_syntax_check`]：JS 语法检查（#479），返回固定语法诊断
//! - [`js_source_stamp_last_update_time`]：写回顶层配置对象的 lastUpdateTime
//!   （#208/#515），无可替换位置时返回空字符串

use legado_core::LegadoResult;

/// 提取 JS 单文件书源配置，返回完整书源
///
/// `content` — 完整 JS 书源脚本文本
pub fn js_source_extract(content: &str) -> LegadoResult<legado_core::models::BookSource> {
    legado_js::js_source::js_source_config::extract(content)
}

/// 只返回引擎原有语法诊断，不执行用户脚本。
pub fn js_source_syntax_check(
    content: &str,
) -> legado_js::js_source::js_source_config::SyntaxCheckResult {
    legado_js::js_source::js_source_config::syntax_check(content)
}

/// 写回顶层配置对象的 lastUpdateTime，返回替换后的脚本文本
///
/// `content` — JS 书源脚本文本；`stamp` — 新时间戳（毫秒）
/// 找不到可替换位置时返回空字符串（对齐 Kotlin 返回 null 的语义）
pub fn js_source_stamp_last_update_time(content: &str, stamp: i64) -> LegadoResult<String> {
    Ok(
        legado_js::js_source::js_source_config::stamp_last_update_time(content, stamp)
            .unwrap_or_default(),
    )
}
