//! 朗读缓存窄接口，目录由现有 NativeRustRuntime 初始化。
use legado_core::{
    LegadoResult,
    tts_cache::{CacheContext, TtsCache},
};
pub fn cache() -> LegadoResult<std::sync::Arc<TtsCache>> {
    TtsCache::open(&super::tts_speak_api::tts_cache_dir())
}
pub fn record(path: &str, context: CacheContext) -> LegadoResult<()> {
    cache()?.record(std::path::Path::new(path), context)
}
pub fn list() -> LegadoResult<Vec<legado_core::tts_cache::CacheEntry>> {
    cache()?.list()
}
pub fn clear(
    name: Option<String>,
    before: Option<u64>,
    keep_book: Option<String>,
    keep_chapter: Option<u32>,
) -> LegadoResult<legado_core::tts_cache::ClearResult> {
    cache()?.clear(name.as_deref(), before, keep_book.as_deref(), keep_chapter)
}
