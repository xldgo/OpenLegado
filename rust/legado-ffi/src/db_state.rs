//! FFI 数据库访问入口，资源与文件身份由同一个 EngineContext 持有。
//!
//! 本模块只委托数据库能力，不另外保存连接池或可单独改写的路径。

use legado_core::LegadoResult;
use legado_db::Database;
use legado_engine::EngineContext;

/// 返回已成功初始化的数据库文件路径；内存库没有文件路径。
pub fn current_db_path() -> Option<String> {
    crate::engine_holder::current()
        .ok()?
        .storage()
        .path()
        .map(|path| path.to_string_lossy().into_owned())
}

/// 解析本地书籍的真实文件路径（[iOS 视角F C1] 加法式，不改 FFI 契约）。
///
/// `book_url` 可能是三种形态之一：
/// - **Web URL**（含 `://`）：在线书，原样返回（不是本地文件）。
/// - **绝对路径**（如 `/var/.../tmp/x.epub` 或桌面 `C:\...`）：存量本地书
///   / 非 iOS 平台写入的绝对路径，**原样返回**——这是读侧兼容点，保证升级后
///   既有本地书（只要文件还在磁盘）仍可读取，不破坏既有语义。
/// - **相对可迁移标识**（如 `books/x.epub`，iOS 新导入写入）：以「当前容器
///   的 Documents 目录」为基拼接成真实路径。基目录取自 [`current_db_path`]
///   的父目录（App 的 DB 固定落在 `Documents/legado.db`），从而跨重签名 /
///   重装（容器 UUID 变化）仍能重建出正确路径。
///
/// DB 未记录（None）时相对标识无从拼接，原样返回（调用方按文件不存在优雅降级）。
pub fn resolve_local_book_path(book_url: &str) -> String {
    // Web URL 不是本地文件，原样返回
    if book_url.contains("://") {
        return book_url.to_string();
    }
    let p = std::path::Path::new(book_url);
    // 绝对路径（存量/非 iOS）原样返回——读侧兼容旧数据
    if p.is_absolute() {
        return book_url.to_string();
    }
    // 相对可迁移标识：拼接到当前 Documents 目录（DB 路径的父目录）
    let base = current_db_path()
        .as_deref()
        .map(std::path::Path::new)
        .and_then(|db| db.parent())
        .map(|d| d.to_path_buf());
    match base {
        Some(base) => base.join(p).to_string_lossy().into_owned(),
        None => book_url.to_string(),
    }
}

/// 接收宿主已打开的数据库；首个成功实例生效，重复初始化不切换库。
/// 路径从该数据库连接读取，与池同时发布；初始连接立即归还。
pub fn init_database(db: Database) -> LegadoResult<()> {
    crate::engine_holder::initialize(|| Ok(EngineContext::from_database(db)), || {})?;
    Ok(())
}

pub fn is_initialized() -> bool {
    crate::engine_holder::is_initialized()
}

/// 一次操作始终使用同一个引擎实例，不在闭包中重新查全局状态。
pub fn with_database<F, R>(f: F) -> LegadoResult<R>
where
    F: FnOnce(&Database) -> LegadoResult<R>,
{
    crate::engine_holder::current()?.storage().with_database(f)
}

/// Windows 会复用进程号；独占创建新文件，不能打开上次测试留下的同名库。
#[cfg(test)]
fn fresh_test_database_path() -> std::path::PathBuf {
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("测试环境时间早于纪元")
        .as_nanos();
    for sequence in 0..100 {
        let path = std::env::temp_dir().join(format!(
            "legado_ffi_shared_test_{}_{stamp}_{sequence}.db",
            std::process::id()
        ));
        match std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
        {
            Ok(_) => return path,
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => panic!("无法创建独立测试库: {error}"),
        }
    }
    panic!("测试库文件名持续冲突");
}

/// 测试专用：确保全局数据库已初始化，并获取测试串行锁守卫
///
/// # 并行竞态修复（Task #98 缺口#8）
/// 现有 DB 测试仍共享同一个文件数据库（`Once` 初始化的全局连接池）。
/// 此前并行测试对共享库插入固定 ID/名称，互相碰撞（UNIQUE 冲突、
/// 全局启用规则/阅读记录交叉污染）导致 flaky。
///
/// 修复方式：保留共享文件库，返回测试互斥锁守卫。
/// 调用方必须将守卫绑定到局部变量（如 `let _db_guard = ensure_test_db();`），
/// 守卫存活至测试结束才释放，从而让 DB 测试串行执行；
/// 不涉及 DB 的测试不受影响，cargo test 并行模式依旧生效。
///
/// 注意：持有守卫期间勿再次调用本函数（该锁不可重入，会死锁）。
///
/// 锁序约束：同时使用 `test_support::lock_global_store()` 的测试必须
/// **先**取全局 store 锁、**后**调用本函数（全局锁序不变式，见
/// `test_support` 模块文档）——颠倒 + 并行执行 = ABBA 死锁。
#[cfg(test)]
#[must_use = "必须将返回的锁守卫绑定到变量（如 let _db_guard = ...），否则串行化失效"]
pub fn ensure_test_db() -> std::sync::MutexGuard<'static, ()> {
    use std::sync::{Mutex, Once};
    static INIT: Once = Once::new();
    /// 测试串行锁：所有共享内存库的 DB 测试须持锁执行
    static TEST_DB_LOCK: Mutex<()> = Mutex::new(());
    INIT.call_once(|| {
        // 现有 FFI 测试仍复用进程唯一文件池，以支持并行服务/同步回调。
        // Server 已不长期借连接；按实例隔离这些旧测试在后续批次完成。
        let path = fresh_test_database_path();
        let path_str = path.to_str().expect("测试 DB 路径含非 UTF-8 字符");
        let db = legado_db::init_database(path_str).expect("Failed to init test database");
        init_database(db).expect("Failed to set global database");
    });
    // 中毒（前一个持锁测试 panic）时直接恢复：我们只需要串行语义，
    // 不依赖锁内数据一致性（共享库本身仍可用）
    TEST_DB_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

#[cfg(test)]
mod tests {
    use super::resolve_local_book_path;

    #[test]
    fn test_database_paths_are_exclusively_created_without_reusing_old_content() {
        let first = super::fresh_test_database_path();
        std::fs::write(&first, "旧测试内容").unwrap();
        let second = super::fresh_test_database_path();
        assert_ne!(first, second);
        assert_eq!(std::fs::read_to_string(&first).unwrap(), "旧测试内容");
        assert_eq!(std::fs::metadata(&second).unwrap().len(), 0);
        std::fs::remove_file(&first).unwrap();
        std::fs::remove_file(&second).unwrap();
    }

    /// [iOS 视角F C1] 透传语义：Web URL 与绝对路径一律原样返回
    /// （两个分支都在读取全局 DB 路径之前返回，可并行安全）
    #[test]
    fn resolve_passthrough_web_and_absolute() {
        // Web URL：含 :// → 原样
        assert_eq!(
            resolve_local_book_path("https://a.example.com/book.epub"),
            "https://a.example.com/book.epub"
        );
        // 绝对路径（存量本地书 / 桌面）：原样。
        // 用平台真实的绝对路径（temp_dir 恒为绝对）构造：Windows 上
        // `/var/...` 只是 rooted 而非 absolute，会落入相对分支读取全局
        // DB 路径，与并行 DB 测试竞态——故必须平台感知
        let abs = std::env::temp_dir().join("abs_probe.epub");
        let abs = abs.to_string_lossy().into_owned();
        assert_eq!(resolve_local_book_path(&abs), abs);
    }
}
