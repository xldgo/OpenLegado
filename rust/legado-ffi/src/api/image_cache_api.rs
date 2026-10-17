//! 图片磁盘缓存（P4-2a，契约 §2.46，对齐原版 BookHelp.saveImage/getImage）
//!
//! 原版取证（`app/src/main/java/io/legado/app/help/book/BookHelp.kt`）：
//! - `getImage(book, src)` L392：路径 =
//!   `downloadDir/book_cache/{book.getFolderName()}/images/{md5Encode16(src)}.{getImageSuffix(src)}`
//!   （`cacheFolderName = "book_cache"` L114、`cacheImageFolderName = "images"` L115）
//! - `MD5Utils.md5Encode16`：MD5 小写 hex 的 `substring(8, 24)`（中段 16 字符）
//! - `UrlUtil.getSuffix(src, "jpg")`：URL 末段（去 query/fragment）`.` 后后缀，
//!   须匹配 `[a-zA-Z0-9]` 且长度 ≤5，否则缺省 `jpg`
//! - `writeImage` L399：创建目录 + 写字节（失败抛 IO 异常）
//! - `saveImage` L347：`isImageExist` 命中即跳过；下载失败仅记 AppLog **不抛异常**
//! - `MangaVH.mangaImagePath` L31-34：本地优先——缓存文件存在取本地，否则走网络
//!
//! 宿主装配约定（业务读写由Engine执行）：
//! - 缓存根目录经 [`set_cache_dir`] 进程注入（FFI `set_image_cache_dir`，§1.6.1，
//!   与 JS 缓存 `legado_js::host_api::cache_store::set_cache_dir` 同型；Dart 启动
//!   注入应用私有缓存目录下 `image_cache` 子目录）。解析优先级对齐 cache_store：
//!   env [`CACHE_DIR_ENV`]（非空，测试隔离用；`cfg(test)` 下由显式测试槽整体旁路）
//!   > 宿主注入目录 > `<temp_dir>/legado-image-cache`（回落时一次性告警）。
//! - 书目录以 `bookUrl` 为键（原版以 `book.getFolderName()` 为键）：非法文件名字符
//!   替换 `_`、截断 64 字符 + `_{md5_8(bookUrl)}` 防截断碰撞（不同书互不串缓存）。
//! - 写失败/读失败均**静默降级**（save 返回 false、get 返回 None，一次性日志），
//!   不抛异常——缓存是加速器不是数据源，失败必须不影响在线加载（对齐原版
//!   saveImage catch 仅记日志语义）。

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
#[cfg(test)]
use std::sync::{Mutex, OnceLock};

/// 图片缓存磁盘目录环境变量名（测试隔离用，非空即覆盖）
pub const CACHE_DIR_ENV: &str = "LEGADO_IMAGE_CACHE_DIR";

/// 缺省回落根目录（未注入且无 env 时）
const DEFAULT_ROOT: &str = "legado-image-cache";

/// `cfg(test)` 显式测试覆盖槽（整体旁路 env 分支：并行测试不得操作
/// 进程级环境变量——对齐 cache_store 的 [`crate`] 先例）
#[cfg(test)]
static TEST_DIR_OVERRIDE: OnceLock<Mutex<Option<PathBuf>>> = OnceLock::new();

/// 回落系统 temp 目录时的一次性告警（对齐 cache_store [`DEFAULT_DIR_WARNED`] 先例，
/// 契约 §1.6.1/§2.46「未注入时回落 `<temp_dir>/legado-image-cache`（一次性告警）」）
static DEFAULT_DIR_WARNED: AtomicBool = AtomicBool::new(false);

/// 注入图片磁盘缓存根目录（宿主注入点，P4-2a）
///
/// 目录解析优先级见模块文档：env [`CACHE_DIR_ENV`] > 注入目录 > 缺省 temp 目录。
/// 后续全部 `save_image_cache`/`get_image_cache` 读写生效。
pub fn set_cache_dir(path: &str) {
    crate::engine_holder::media().set_image_directory(Some(PathBuf::from(path)));
}

/// 图片缓存根目录（env 覆盖 > 宿主注入 > 缺省 `<temp_dir>/legado-image-cache`）
fn cache_root() -> PathBuf {
    #[cfg(test)]
    {
        if let Ok(guard) = TEST_DIR_OVERRIDE.get_or_init(|| Mutex::new(None)).lock()
            && let Some(dir) = guard.clone()
        {
            return dir;
        }
    }
    #[cfg(not(test))]
    {
        if let Ok(dir) = std::env::var(CACHE_DIR_ENV)
            && !dir.trim().is_empty()
        {
            return PathBuf::from(dir);
        }
    }
    if let Some(dir) = crate::engine_holder::media().image_directory() {
        return dir;
    }
    let root = std::env::temp_dir().join(DEFAULT_ROOT);
    if DEFAULT_DIR_WARNED
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
    {
        log::warn!(
            "[image_cache] 未注入宿主图片缓存目录（set_image_cache_dir）且未设 env {CACHE_DIR_ENV}——回落系统临时目录 {root:?}（图片缓存随系统 temp 清理而丢失，宿主应在初始化时注入应用私有缓存目录，对齐 cache_store 先例）"
        );
    }
    root
}

/// 每次操作重新解析目录，使后续宿主注入即时生效。
fn host_service() -> legado_engine::image_cache_service::ImageCacheService {
    legado_engine::image_cache_service::ImageCacheService::new(cache_root())
}
pub fn save_image_cache(book_url: &str, url: &str, bytes: &[u8]) -> bool {
    host_service().save_image_cache(book_url, url, bytes)
}
pub fn get_image_cache(book_url: &str, url: &str) -> Option<Vec<u8>> {
    host_service().get_image_cache(book_url, url)
}

// ─── 测试 ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;
    use std::{fs, path::Path};

    /// 测试串行锁：`INJECTED_DIR`/`TEST_DIR_OVERRIDE` 为进程级状态，
    /// 并行测试互踩 → 触碰进程级目录状态的测试先持锁（对齐 cache_store 先例）
    static TEST_LOCK: Mutex<()> = Mutex::new(());
    static COUNTER: AtomicUsize = AtomicUsize::new(0);

    /// 进程级唯一临时根目录（测试收尾 remove_dir_all 清理）
    fn unique_root(tag: &str) -> PathBuf {
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        std::env::temp_dir().join(format!(
            "legado-image-cache-test-{}-{}-{}",
            std::process::id(),
            n,
            tag
        ))
    }

    /// 设置测试目录覆盖槽（`cfg(test)` 专属，旁路 env 分支）
    fn set_test_root(dir: &Path) {
        if let Ok(mut guard) = TEST_DIR_OVERRIDE.get_or_init(|| Mutex::new(None)).lock() {
            *guard = Some(dir.to_path_buf());
        }
    }

    /// 清空测试目录覆盖槽（复位进程级状态，避免串行测试互踩）
    fn clear_test_root() {
        if let Ok(mut guard) = TEST_DIR_OVERRIDE.get_or_init(|| Mutex::new(None)).lock() {
            *guard = None;
        }
    }

    // set_cache_dir 注入：后续读写落注入目录
    #[test]
    fn injected_dir_used() {
        let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let root = unique_root("injected");
        // 前置清空覆盖槽：`cfg(test)` 下覆盖槽优先于注入槽，
        // 若残留前序测试的目录将旁路本测试的断言
        clear_test_root();
        set_cache_dir(root.to_str().unwrap());
        assert!(save_image_cache(
            "https://a.com/book/3",
            "https://cdn.com/z.jpg",
            b"z"
        ));
        assert_eq!(
            get_image_cache("https://a.com/book/3", "https://cdn.com/z.jpg").as_deref(),
            Some(b"z".as_slice())
        );
        // 书目录名 = 净化+截断+md5_8 后缀（与 image_file_path 同一构造器）
        let book_dir = host_service()
            .image_file_path("https://a.com/book/3", "https://cdn.com/z.jpg")
            .parent()
            .unwrap()
            .to_path_buf();
        assert!(
            book_dir.exists(),
            "文件应落在注入根目录下的书级目录：{book_dir:?}"
        );
        // 下一次操作重新装配目录；切换后不能读到旧根目录内容。
        let next = unique_root("reinjected");
        set_cache_dir(next.to_str().unwrap());
        assert!(get_image_cache("https://a.com/book/3", "https://cdn.com/z.jpg").is_none());
        assert!(save_image_cache(
            "https://a.com/book/3",
            "https://cdn.com/z.jpg",
            b"next"
        ));
        let override_root = unique_root("override");
        set_test_root(&override_root);
        assert!(get_image_cache("https://a.com/book/3", "https://cdn.com/z.jpg").is_none());
        clear_test_root();
        assert_eq!(
            get_image_cache("https://a.com/book/3", "https://cdn.com/z.jpg").unwrap(),
            b"next"
        );
        set_cache_dir(root.to_str().unwrap());
        assert_eq!(
            get_image_cache("https://a.com/book/3", "https://cdn.com/z.jpg").unwrap(),
            b"z"
        );
        let _ = fs::remove_dir_all(next);
        // 复位注入槽为 None（不污染其他测试）
        crate::engine_holder::media().set_image_directory(None);
        clear_test_root();
        let _ = fs::remove_dir_all(&root);
    }
}
