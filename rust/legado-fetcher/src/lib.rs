//! legado-fetcher：书源驱动抓取共享 crate（P5 子批 2a）
//!
//! 从 `legado-ffi/src/api/web_book.rs` 下沉的 `RealBookSourceFetcher`
//! （搜索→详情→目录→正文完整链路）+ 宿主注入面 [`deps::FetcherDeps`]。
//! server 与 ffi 两侧共用同一实现：
//!
//! - 本 crate **不得反向引用任何 ffi/宿主模块**；宿主状态（共享 HTTP 客户端、
//!   登录头缓存、DB 书籍变量、explore snapshot 驱动的 setup 脚本）一律经
//!   [`deps::FetcherDeps`] 闭包注入；setup 脚本的纯生成面已平移本 crate
//!   [`source_setup`]（宿主数据经参数注入）；
//! - 入口函数为 async（[`web_book::webbook_search`] 等 4 个），宿主负责
//!   runtime 驱动（ffi 侧 `runtime::block_on` 包装）。
//!
//! `quickjs` feature 透传 `legado-js/quickjs`：无 feature 时 JS 相关构造
//! 全部退化为无执行器（与既有非 quickjs 构建行为一致）。

pub mod analyze_request;
pub mod book_type;
pub mod cloud_tts;
pub mod deps;
pub mod explore;
pub mod explore_js;
pub mod explore_url;
pub mod js_adapter;
pub mod rate_limit;
pub mod source_setup;
pub mod tts_control;
pub mod tts_fetcher;
mod tts_response;
pub mod tts_source;
mod tts_transport;
pub mod web_book;
pub mod web_book_state;

pub use tts_fetcher::{
    HttpTtsConfig, TtsFetchResult, TtsSpeakContext, fetch_tts_audio, fetch_tts_audio_with_executor,
    parse_tts_analyze_url_with_executor, tts_cache_key_from_context,
};

/// 测试支撑：全局变量 store / flow scope 的进程级状态锁 + 多线程 runtime 驱动
/// （仅测试编译；本 crate 测试二进制内的串行防串表，语义同 legado-ffi
/// `test_support`，因测试进程独立而自持一把锁）。
#[cfg(test)]
pub(crate) mod test_support;
