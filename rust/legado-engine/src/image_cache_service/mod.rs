//! 图片磁盘缓存：调用者明确提供根目录，路径与IO策略沿用既有约定。
use std::{
    fs, io,
    path::PathBuf,
    sync::atomic::{AtomicBool, Ordering},
};
const IMAGES_DIR: &str = "images";
const BOOK_DIR_MAX_CHARS: usize = 64;
// 保留进程内同类失败仅告警一次的既有策略，不参与目录或内容选择。
static WRITE_FAIL_WARNED: AtomicBool = AtomicBool::new(false);
static READ_FAIL_WARNED: AtomicBool = AtomicBool::new(false);

pub struct ImageCacheService {
    root: PathBuf,
}
impl ImageCacheService {
    /// 根目录为本次操作快照，服务不读取环境变量或宿主全局。
    pub fn new(root: PathBuf) -> Self {
        Self { root }
    }
    /// 图片缓存文件路径（对齐原版 `BookHelp.getImage` L392 路径结构）：
    /// `{root}/{book_dir_name(bookUrl)}/images/{md5_mid16(url)}.{suffix}`
    ///
    /// `md5_mid16` = MD5 小写 hex 的 `[8..24]` 中段 16 字符（原版
    /// `MD5Utils.md5Encode16` = `substring(8, 24)`，逐字节对齐）。
    pub fn image_file_path(&self, book_url: &str, url: &str) -> PathBuf {
        let hex = format!("{:x}", md5::compute(url));
        let mid16 = &hex[8..24];
        self.root
            .clone()
            .join(book_dir_name(book_url))
            .join(IMAGES_DIR)
            .join(format!("{mid16}.{}", image_suffix(url)))
    }

    /// 写入图片缓存（对齐原版 `BookHelp.writeImage` L399）
    ///
    /// 成功返回 `true`；目录创建失败/写盘失败返回 `false`（静默降级 +
    /// 一次性日志，**不抛异常**——缓存失败不影响在线加载）。
    pub fn save_image_cache(&self, book_url: &str, url: &str, bytes: &[u8]) -> bool {
        let file = self.image_file_path(book_url, url);
        if let Some(parent) = file.parent()
            && let Err(e) = fs::create_dir_all(parent)
        {
            if WRITE_FAIL_WARNED
                .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
                .is_ok()
            {
                log::warn!(
                    "[image_cache] 目录创建失败 {parent:?}: {e}（降级：本次不落盘，不影响在线加载；同类失败后续不再逐条记日志）"
                );
            }
            return false;
        }
        match fs::write(&file, bytes) {
            Ok(()) => true,
            Err(e) => {
                if WRITE_FAIL_WARNED
                    .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
                    .is_ok()
                {
                    log::warn!(
                        "[image_cache] 写盘失败 {file:?}: {e}（降级：本次不落盘，不影响在线加载；同类失败后续不再逐条记日志）"
                    );
                }
                false
            }
        }
    }

    /// 读取图片缓存（对齐原版 `BookHelp.getImage`/`isImageExist` 的本地优先语义）
    ///
    /// 命中返回图片字节；未命中返回 `None`；读失败（非 NotFound 的 IO 错误）
    /// 降级 `None`（静默 + 一次性日志）——调用方一律回落网络加载。
    pub fn get_image_cache(&self, book_url: &str, url: &str) -> Option<Vec<u8>> {
        let file = self.image_file_path(book_url, url);
        match fs::read(&file) {
            Ok(bytes) => Some(bytes),
            Err(e) if matches!(e.kind(), io::ErrorKind::NotFound) => None,
            Err(e) => {
                if READ_FAIL_WARNED
                    .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
                    .is_ok()
                {
                    log::warn!(
                        "[image_cache] 读盘失败 {file:?}: {e}（降级：按未命中处理走网络加载；同类失败后续不再逐条记日志）"
                    );
                }
                None
            }
        }
    }
}
/// 书目录名（对齐原版 `book.getFolderName()` 的「书级隔离目录」语义，
/// 键由 folderName 换为 bookUrl）：非法文件名字符替换 `_`，截断
/// [`BOOK_DIR_MAX_CHARS`] 字符后追加 `_{md5_8(bookUrl)}` 防截断碰撞。
fn book_dir_name(book_url: &str) -> String {
    let sanitized: String = book_url
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-') {
                c
            } else {
                '_'
            }
        })
        .collect();
    let truncated: String = sanitized.chars().take(BOOK_DIR_MAX_CHARS).collect();
    let digest = format!("{:x}", md5::compute(book_url));
    format!("{truncated}_{}", &digest[0..8])
}

/// 图片文件后缀（对齐原版 `UrlUtil.getSuffix(src, "jpg")`）：
/// URL 去 query/fragment 后末段 `.` 之后部分，须匹配 `[a-zA-Z0-9]`
/// 且长度 ≤5，否则缺省 `jpg`。
fn image_suffix(url: &str) -> String {
    let without_query = url.split('?').next().unwrap_or("");
    let without_frag = without_query.split('#').next().unwrap_or("");
    let last_segment = without_frag.rsplit('/').next().unwrap_or("");
    let suffix = match last_segment.rfind('.') {
        Some(i) => &last_segment[i + 1..],
        None => "",
    };
    if suffix.is_empty() || suffix.len() > 5 || !suffix.chars().all(|c| c.is_ascii_alphanumeric()) {
        "jpg".to_string()
    } else {
        suffix.to_string()
    }
}

#[cfg(test)]
mod tests;
