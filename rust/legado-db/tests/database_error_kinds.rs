//! 分类依赖驱动码，显示文案不影响重试，原始原因可继续诊断。
use legado_core::{LegadoError, error::DatabaseErrorKind};
use legado_db::error::database_error;
use std::error::Error;
#[test]
fn real_conversion_and_constraint_errors_keep_their_causes() {
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE t(n INTEGER UNIQUE);INSERT INTO t VALUES(1);")
        .unwrap();
    let constraint = database_error(
        "忙碌 busy locked 只是文案",
        db.execute("INSERT INTO t VALUES(1)", []).unwrap_err(),
    );
    assert!(!constraint.is_database_contention());
    assert!(matches!(
        constraint,
        LegadoError::DatabaseFailure {
            kind: DatabaseErrorKind::Constraint,
            ..
        }
    ));
    assert!(
        constraint
            .source()
            .unwrap()
            .downcast_ref::<rusqlite::Error>()
            .is_some()
    );
    let e = db
        .query_row("SELECT 'bad'", [], |row| row.get::<_, i64>(0))
        .unwrap_err();
    let e = database_error("转换", e);
    assert!(matches!(
        e,
        LegadoError::DatabaseFailure {
            kind: DatabaseErrorKind::Conversion,
            ..
        }
    ));
    assert_eq!(e.to_error_code(), 1004);
    assert!(!LegadoError::Database("database is locked".into()).is_database_contention());
}
#[test]
fn actual_sqlite_busy_is_retryable_without_matching_any_message() {
    let path = std::env::temp_dir().join(format!(
        "legado-busy-{}-{}.db",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let first = rusqlite::Connection::open(&path).unwrap();
    let second = rusqlite::Connection::open(&path).unwrap();
    second.busy_timeout(std::time::Duration::ZERO).unwrap();
    first
        .execute_batch("CREATE TABLE t(n);BEGIN IMMEDIATE;INSERT INTO t VALUES(1);")
        .unwrap();
    let e = database_error(
        "任意中文上下文",
        second.execute("INSERT INTO t VALUES(2)", []).unwrap_err(),
    );
    assert!(e.is_database_contention());
    first.execute_batch("ROLLBACK").unwrap();
    second.execute("INSERT INTO t VALUES(2)", []).unwrap();
    drop(first);
    drop(second);
    std::fs::remove_file(path).unwrap();
}
