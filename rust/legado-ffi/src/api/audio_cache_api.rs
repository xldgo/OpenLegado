//! 音频缓存宿主环境发现与Engine服务适配。
use crate::media_dto::AudioCacheDownloadDto;
use legado_core::{LegadoError, LegadoResult};
pub use legado_engine::audio_cache_service::cache_key16;
use legado_engine::audio_cache_service::{AudioCacheService, AudioDownloadContext};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
/// 音频缓存磁盘目录环境变量名（测试隔离用，非空即覆盖）
pub const CACHE_DIR_ENV: &str = "LEGADO_AUDIO_CACHE_DIR";

/// 缺省回落根目录（未注入且无 env 时）
const DEFAULT_ROOT: &str = "legado-audio-cache";

/// 回落系统 temp 目录时的一次性告警（契约 §2.47，对齐 image_cache 先例）
static DEFAULT_DIR_WARNED: AtomicBool = AtomicBool::new(false);

/// 注入音频磁盘缓存根目录（宿主注入点，B1）
///
/// 目录解析优先级见模块文档：env [`CACHE_DIR_ENV`] > 注入目录 > 缺省 temp 目录。
/// 后续全部查询/列举/清理以此根目录为准。
pub fn set_cache_dir(path: &str) {
    crate::engine_holder::media().set_audio_directory(Some(PathBuf::from(path)));
}

/// 音频缓存根目录（env 覆盖 > 宿主注入 > 缺省 `<temp_dir>/legado-audio-cache`）
fn cache_root(media: &legado_engine::MediaState) -> PathBuf {
    #[cfg(not(test))]
    {
        if let Ok(dir) = std::env::var(CACHE_DIR_ENV)
            && !dir.trim().is_empty()
        {
            return PathBuf::from(dir);
        }
    }
    if let Some(dir) = media.audio_directory() {
        return dir;
    }
    let root = std::env::temp_dir().join(DEFAULT_ROOT);
    if DEFAULT_DIR_WARNED
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
    {
        log::warn!(
            "[audio_cache] 未注入宿主音频缓存目录（set_audio_cache_dir）且未设 env {CACHE_DIR_ENV}——回落系统临时目录 {root:?}（音频缓存随系统 temp 清理而丢失，宿主应在初始化时注入应用私有缓存目录，对齐 image_cache/cache_store 先例）"
        );
    }
    root
}

pub fn audio_cache_query(book_url: &str, index: i32, chapter_url: &str, title: &str) -> bool {
    cache_service().audio_cache_query(book_url, index, chapter_url, title)
}
pub fn audio_cache_list(book_url: &str) -> Vec<i32> {
    cache_service().audio_cache_list(book_url)
}
pub fn audio_cache_clear_chapter(
    book_url: &str,
    index: i32,
    chapter_url: &str,
    title: &str,
) -> i32 {
    cache_service().audio_cache_clear_chapter(book_url, index, chapter_url, title)
}
pub fn audio_cache_clear_book(book_url: &str) -> i32 {
    cache_service().audio_cache_clear_book(book_url)
}
fn cache_service() -> AudioCacheService {
    AudioCacheService::new(cache_root(&crate::engine_holder::media()))
}
pub fn audio_cache_cancel() -> LegadoResult<bool> {
    Ok(crate::engine_holder::media().cancel_audio())
}
pub fn audio_cache_download(
    book_url: &str,
    index: i32,
    chapter_url: &str,
    title: &str,
    play_url: &str,
) -> LegadoResult<AudioCacheDownloadDto> {
    let client = crate::http_state::shared_client()?;
    if legado_engine::audio_cache_service::kotlin_is_blank(book_url) {
        return Err(LegadoError::Ffi("书籍 URL 为空".into()));
    }
    let engine = crate::engine_holder::current()?;
    let context = AudioDownloadContext::new(
        engine.storage().clone(),
        engine.media().clone(),
        cache_root(engine.media()),
        super::web_book::deps_for_engine(&engine),
        engine.tasks(),
        crate::runtime::get_runtime().handle().clone(),
    )?;
    drop(engine);
    Ok(legado_engine::audio_cache_service::download(
        &context,
        &client,
        book_url,
        index,
        chapter_url,
        title,
        play_url,
    )?
    .into())
}
