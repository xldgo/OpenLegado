//! 独立进程验证真实 FFI 初始化顺序，不与其他集成测试共享全局持有者。

use legado_ffi::db_state;
use legado_ffi::ffi::ffi::db_open;
use legado_ffi::legado_db::CacheRepository;

#[test]
fn ffi_initialization_publishes_database_and_path_only_after_success() {
    let directory = std::env::temp_dir().join(format!(
        "legado_engine_ffi_{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    std::fs::create_dir(&directory).unwrap();
    assert!(!db_state::is_initialized());
    assert_eq!(db_state::current_db_path(), None);
    let error = db_state::with_database(|_| Ok(())).unwrap_err();
    assert!(error.to_string().contains("请先调用 db_open"));

    let bad_path = directory.join("missing/legado.db");
    assert!(db_open(bad_path.to_str().unwrap().to_owned()).is_err());
    assert!(!db_state::is_initialized());
    assert_eq!(db_state::current_db_path(), None);

    let path = directory.join("legado.db");
    db_open(path.to_str().unwrap().to_owned()).unwrap();
    assert!(db_state::is_initialized());
    let published = db_state::current_db_path().unwrap();
    assert_eq!(
        std::fs::canonicalize(&published).unwrap(),
        path.canonicalize().unwrap()
    );
    assert_eq!(
        db_state::resolve_local_book_path("books/sample.txt"),
        std::path::Path::new(&published)
            .parent()
            .unwrap()
            .join("books/sample.txt")
            .to_string_lossy()
    );
    db_state::with_database(|db| {
        CacheRepository::new(db.connection()).put("engine-init", "kept", 0)
    })
    .unwrap();

    // 重复初始化即使传入无效路径也维持首个实例，不创建或打开另一数据库。
    db_open(bad_path.to_str().unwrap().to_owned()).unwrap();
    assert!(!bad_path.exists());
    assert_eq!(
        db_state::current_db_path().as_deref(),
        Some(published.as_str())
    );
    let value =
        db_state::with_database(|db| CacheRepository::new(db.connection()).get("engine-init"))
            .unwrap();
    assert_eq!(value.as_deref(), Some("kept"));
    // FFI 根仍是进程级持有者，文件在进程结束后才能完整释放；此批不伪造关闭能力。
}
