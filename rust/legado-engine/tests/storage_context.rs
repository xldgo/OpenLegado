//! 验证实例隔离、连接归还和实际数据库身份，不依赖 FFI 全局状态。

use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Barrier};

use legado_core::{LegadoError, LegadoResult};
use legado_db::{CacheRepository, Database};
use legado_engine::EngineContext;

struct TestDirectory(PathBuf);

impl TestDirectory {
    fn new() -> Self {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let path = std::env::temp_dir().join(format!(
            "legado_engine_{}_{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }

    fn db_path(&self) -> String {
        self.0.join("legado.db").to_str().unwrap().to_owned()
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        // Windows 的连接池后台线程可能稍后才释放文件；清理不遮蔽行为断言。
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn write(context: &EngineContext, value: &str) -> LegadoResult<()> {
    context
        .storage()
        .with_database(|db| CacheRepository::new(db.connection()).put("same-key", value, 0))
}

fn read(context: &EngineContext) -> Option<String> {
    context
        .storage()
        .with_database(|db| CacheRepository::new(db.connection()).get("same-key"))
        .unwrap()
}

#[test]
fn independent_memory_contexts_keep_data_separate() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    assert!(first.storage().path().is_none());
    write(&first, "first").unwrap();
    assert_eq!(read(&second), None);
    write(&second, "second").unwrap();
    assert_eq!(read(&first).as_deref(), Some("first"));
    assert_eq!(read(&second).as_deref(), Some("second"));
}

#[test]
fn adopting_database_returns_initial_connection_and_reuses_pool() {
    let db = Database::open_in_memory().unwrap();
    let pool = db.pool().clone();
    assert_eq!(pool.state().idle_connections, 0);
    CacheRepository::new(db.connection())
        .put("same-key", "adopted", 0)
        .unwrap();
    let context = EngineContext::from_database(db);
    assert_eq!(pool.state().idle_connections, 1);
    assert_eq!(read(&context).as_deref(), Some("adopted"));
    assert_eq!(pool.state().idle_connections, 1);

    let error: LegadoResult<()> = context
        .storage()
        .with_database(|_| Err(LegadoError::Database("操作失败".into())));
    assert!(error.is_err());
    assert_eq!(pool.state().idle_connections, 1, "失败也应归还连接");
    write(&context, "after-error").unwrap();
    assert_eq!(read(&context).as_deref(), Some("after-error"));
}

#[test]
fn file_context_paths_match_their_data_and_survive_reopen() {
    let first_dir = TestDirectory::new();
    let second_dir = TestDirectory::new();
    let first_path = first_dir.db_path();
    let first = EngineContext::open(&first_path).unwrap();
    let second = EngineContext::open(&second_dir.db_path()).unwrap();
    assert_eq!(
        first.storage().path().unwrap().canonicalize().unwrap(),
        PathBuf::from(&first_path).canonicalize().unwrap()
    );
    assert_ne!(first.storage().path(), second.storage().path());
    write(&first, "persisted").unwrap();
    write(&second, "other").unwrap();
    drop(first);
    let reopened = EngineContext::open(&first_path).unwrap();
    assert_eq!(read(&reopened).as_deref(), Some("persisted"));
    assert_eq!(read(&second).as_deref(), Some("other"));
}

#[test]
fn failed_file_open_does_not_prevent_later_valid_construction() {
    let directory = TestDirectory::new();
    let invalid = directory.0.join("missing-parent/legado.db");
    assert!(EngineContext::open(invalid.to_str().unwrap()).is_err());
    assert!(!invalid.exists());
    let valid = EngineContext::open(&directory.db_path()).unwrap();
    write(&valid, "ready").unwrap();
    assert_eq!(read(&valid).as_deref(), Some("ready"));
}

#[test]
fn shared_file_context_supports_parallel_short_operations() {
    let directory = TestDirectory::new();
    let context = Arc::new(EngineContext::open(&directory.db_path()).unwrap());
    let barrier = Arc::new(Barrier::new(4));
    std::thread::scope(|scope| {
        for index in 0..4 {
            let context = context.clone();
            let barrier = barrier.clone();
            scope.spawn(move || {
                barrier.wait();
                let key = format!("worker-{index}");
                context
                    .storage()
                    .with_database(|db| {
                        let repo = CacheRepository::new(db.connection());
                        repo.put(&key, &key, 0)?;
                        assert_eq!(repo.get(&key)?.as_deref(), Some(key.as_str()));
                        Ok(())
                    })
                    .unwrap();
            });
        }
    });
    // 连接池或操作闭包不得反向保活根上下文。
    let weak = Arc::downgrade(&context);
    drop(context);
    assert!(weak.upgrade().is_none());
}

#[tokio::test]
async fn waiting_for_single_connection_keeps_current_thread_runtime_responsive() {
    let context = Arc::new(EngineContext::in_memory().unwrap());
    write(&context, "after-wait").unwrap();
    let held = context.storage().database().unwrap();
    let reader = context.clone();
    let task = tokio::spawn(async move {
        reader
            .storage()
            .run(|db| CacheRepository::new(db.connection()).get("same-key"))
            .await
    });
    // 单连接仍被持有；运行时应能继续调度计时器并释放连接，而不是同步卡住。
    tokio::time::sleep(std::time::Duration::from_millis(10)).await;
    assert!(!task.is_finished());
    drop(held);
    let value = tokio::time::timeout(std::time::Duration::from_secs(2), task)
        .await
        .unwrap()
        .unwrap()
        .unwrap()
        .unwrap();
    assert_eq!(value.as_deref(), Some("after-wait"));
}

#[tokio::test]
async fn async_database_transaction_rolls_back_and_returns_connection() {
    let context = EngineContext::in_memory().unwrap();
    write(&context, "before").unwrap();
    let result: LegadoResult<()> = context
        .storage()
        .run(|db| {
            let _transaction = db.immediate_transaction()?;
            CacheRepository::new(db.connection()).put("same-key", "not-committed", 0)?;
            Err(LegadoError::Database("业务拒绝提交".into()))
        })
        .await
        .unwrap();
    assert!(result.is_err());
    assert_eq!(read(&context).as_deref(), Some("before"));
    write(&context, "ready-again").unwrap();
    assert_eq!(read(&context).as_deref(), Some("ready-again"));
}

#[test]
fn concurrent_read_modify_write_uses_database_transaction() {
    let directory = TestDirectory::new();
    let context = Arc::new(EngineContext::open(&directory.db_path()).unwrap());
    write(&context, "0").unwrap();
    std::thread::scope(|scope| {
        for _ in 0..4 {
            let context = context.clone();
            scope.spawn(move || {
                for _ in 0..8 {
                    context
                        .storage()
                        .with_database(|db| {
                            let transaction = db.immediate_transaction()?;
                            let repo = CacheRepository::new(db.connection());
                            let value: usize = repo.get("same-key")?.unwrap().parse().unwrap();
                            repo.put("same-key", &(value + 1).to_string(), 0)?;
                            transaction
                                .commit()
                                .map_err(|e| LegadoError::Database(e.to_string()))?;
                            Ok(())
                        })
                        .unwrap();
                }
            });
        }
    });
    assert_eq!(read(&context).as_deref(), Some("32"));
}

#[tokio::test]
async fn rate_windows_are_shared_only_within_one_context() {
    use legado_core::models::BookSource;
    use std::time::Duration;
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let source = BookSource {
        book_source_url: "https://same-source.test".into(),
        concurrent_rate: Some("1/10000".into()),
        ..Default::default()
    };
    first.rate_limiter().acquire(&source).await;
    assert!(
        tokio::time::timeout(
            Duration::from_millis(30),
            first.rate_limiter().acquire(&source)
        )
        .await
        .is_err()
    );
    assert!(
        tokio::time::timeout(
            Duration::from_secs(1),
            second.rate_limiter().acquire(&source)
        )
        .await
        .is_ok()
    );
}
