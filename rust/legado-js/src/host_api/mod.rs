//! 宿主 API 注册框架
//!
//! 将所有宿主 API 按功能分类注册到 JS 上下文中，
//! 参考 Kotlin 端 `JsExtensions` 接口的方法分组。

#[cfg(feature = "quickjs")]
mod archive_read;
#[cfg(feature = "quickjs")]
pub mod archive_utils;
#[cfg(feature = "quickjs")]
pub mod asymmetric_crypto;
mod base64_codec;
#[cfg(feature = "quickjs")]
mod batch_request;
#[cfg(feature = "quickjs")]
mod binary_encoding_bridge;
pub mod cache_store;
/// 能力受限台账：未知 Java 符号 + jsLib 加载失败登记（队列④，无 feature 门控）
pub mod capability_ledger;
pub mod chinese_utils;
/// 宿主 API 入参的 Rhino LiveConnect 宽松转换（`RhinoStr` / `RhinoOptStr`）
#[cfg(feature = "quickjs")]
pub mod coerce;
pub mod concurrency_api;
pub mod config_api;
pub mod cookie_store;
pub mod crypto_api;
pub mod current_source;
pub mod device_id;
#[cfg(feature = "quickjs")]
mod digest_bridge;
pub mod encoding;
pub mod env;
#[cfg(feature = "quickjs")]
mod file_download;
pub mod file_utils;
pub mod font_api;
#[cfg(feature = "quickjs")]
mod font_bridge;
pub mod html_format;
#[cfg(feature = "quickjs")]
pub mod html_parse;
#[cfg(feature = "quickjs")]
mod java_date_format;
/// 远程 jsLib 加载器（cap 3：URL 映射 jsLib 经共享客户端拉取 + 进程缓存
/// + 台账降级；随 quickjs feature 门控——依赖网络/引擎宿主面）
#[cfg(feature = "quickjs")]
pub mod jslib_loader;
pub mod json_utils;
/// java.security.MessageDigest 摘要核心（MD5及SHA-1/224/256/384/512，复用
/// md-5/sha1/sha2 既有依赖；随 quickjs feature 门控）
#[cfg(feature = "quickjs")]
pub mod message_digest;
pub mod misc_api;
#[cfg(feature = "quickjs")]
pub mod network;
pub mod platform;
pub mod pre_update_hooks;
pub mod query_ttf;
pub mod regex_utils;
pub(crate) mod resource_files;
#[cfg(feature = "quickjs")]
mod rsa_java_bridge;
#[cfg(feature = "quickjs")]
mod rule_request;
#[cfg(feature = "quickjs")]
pub mod runtime_bridge;
pub mod source_callback;
pub mod string_utils;
#[cfg(feature = "quickjs")]
mod symmetric_bridge;
#[cfg(feature = "quickjs")]
pub mod symmetric_crypto;
pub mod time_utils;
pub mod ui_action_queue;
#[cfg(feature = "quickjs")]
mod url_codec;
#[cfg(feature = "quickjs")]
pub(crate) mod variable_bindings;

#[cfg(feature = "quickjs")]
pub mod quickjs_impl;

#[cfg(feature = "quickjs")]
pub mod register;

pub use env::HostEnv;

/// 将所有宿主 API 注册到 QuickJS 全局上下文
///
/// 转发至 `quickjs_impl::register_all_apis`，根据沙箱配置门控文件 API。
#[cfg(feature = "quickjs")]
pub fn register_all(
    ctx: &rquickjs::Ctx<'_>,
    config: &crate::sandbox::SandboxConfig,
) -> Result<(), legado_core::LegadoError> {
    quickjs_impl::register_all_apis(ctx, config)
}
