//! Migration109To110 — httpTTS 补 speed 与 synthesisThreadCount 列（对齐参考版 HttpTTS 实体）
//!
//! 批次 T1：为 `httpTTS` 表补齐上游 `HttpTTS` 实体的源级语速 `speed`（可空整型，0..80）
//! 与源级声明合成并发上限 `synthesisThreadCount`（整型，1..8，默认 1），
//! 同时保留既有 `pauseDuration` 与 `isEnabled` 列。

use rusqlite::Connection;

use legado_core::{LegadoError, LegadoResult};

use crate::migration::{Migration, add_column_if_not_exists, table_exists};

/// 从 v109 升级到 v110
///
/// 变更内容：`httpTTS` 表补 `speed` 列（INTEGER）与 `synthesisThreadCount` 列
/// （INTEGER NOT NULL DEFAULT 1）。
///
/// 幂等：`user_version` 门禁 + `add_column_if_not_exists` 列存在性检测；
/// `httpTTS` 表不存在时跳过。
pub struct Migration109To110;

impl Migration for Migration109To110 {
    fn from_version(&self) -> u32 {
        109
    }

    fn to_version(&self) -> u32 {
        110
    }

    fn description(&self) -> &str {
        "httpTTS 补 speed 与 synthesisThreadCount 列（源级语速与合成并发上限）"
    }

    fn up(&self, conn: &Connection) -> LegadoResult<()> {
        if table_exists(conn, "httpTTS")? {
            add_column_if_not_exists(conn, "httpTTS", "speed", "INTEGER")?;
            add_column_if_not_exists(
                conn,
                "httpTTS",
                "synthesisThreadCount",
                "INTEGER NOT NULL DEFAULT 1",
            )?;
        }
        Ok(())
    }

    fn down(&self, _conn: &Connection) -> LegadoResult<()> {
        Err(LegadoError::Database(
            "Cannot safely rollback Migration109To110: DROP COLUMN not supported".into(),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::migration::MigrationRegistry;
    use crate::schema;

    fn column_count(conn: &Connection, col: &str) -> i64 {
        conn.query_row(
            "SELECT COUNT(*) FROM pragma_table_info('httpTTS') WHERE name = ?1",
            [col],
            |row| row.get(0),
        )
        .unwrap()
    }

    #[test]
    fn test_migration_109_to_110_adds_speed_and_synthesis_thread_count() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(
            "CREATE TABLE httpTTS (
                id INTEGER NOT NULL,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                contentType TEXT,
                pauseDuration INTEGER NOT NULL DEFAULT 0,
                concurrentRate TEXT DEFAULT '0',
                loginUrl TEXT,
                loginUi TEXT,
                header TEXT,
                jsLib TEXT,
                enabledCookieJar INTEGER DEFAULT 0,
                loginCheckJs TEXT,
                lastUpdateTime INTEGER NOT NULL DEFAULT 0,
                isEnabled INTEGER NOT NULL DEFAULT 1,
                PRIMARY KEY(id)
            );
            INSERT INTO httpTTS (id, name, url) VALUES (1, '旧引擎', 'https://tts.example.com');",
        )
        .unwrap();

        Migration109To110.up(&conn).unwrap();
        assert_eq!(column_count(&conn, "speed"), 1);
        assert_eq!(column_count(&conn, "synthesisThreadCount"), 1);

        let (speed, threads): (Option<i32>, i32) = conn
            .query_row(
                "SELECT speed, synthesisThreadCount FROM httpTTS WHERE id = 1",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .unwrap();
        assert_eq!(speed, None);
        assert_eq!(threads, 1);

        // 幂等重复执行
        Migration109To110.up(&conn).unwrap();
        assert_eq!(column_count(&conn, "speed"), 1);
        assert_eq!(column_count(&conn, "synthesisThreadCount"), 1);
    }

    #[test]
    fn test_migration_109_to_110_via_registry() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(
            "CREATE TABLE httpTTS (
                id INTEGER NOT NULL,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                PRIMARY KEY(id)
            );",
        )
        .unwrap();
        conn.pragma_update(None, "user_version", 109).unwrap();
        let registry = MigrationRegistry::new();
        registry.migrate_to_latest(&conn).unwrap();
        assert_eq!(
            MigrationRegistry::current_version(&conn).unwrap(),
            crate::schema::SCHEMA_VERSION
        );
        assert_eq!(column_count(&conn, "speed"), 1);
        assert_eq!(column_count(&conn, "synthesisThreadCount"), 1);
    }

    #[test]
    fn test_migration_109_to_110_fresh_schema_is_noop() {
        let conn = Connection::open_in_memory().unwrap();
        schema::init_schema(&conn).unwrap();
        assert_eq!(column_count(&conn, "speed"), 1);
        assert_eq!(column_count(&conn, "synthesisThreadCount"), 1);
        Migration109To110.up(&conn).unwrap();
        assert_eq!(column_count(&conn, "speed"), 1);
        assert_eq!(column_count(&conn, "synthesisThreadCount"), 1);
    }

    #[test]
    fn test_migration_109_to_110_skips_missing_table() {
        let conn = Connection::open_in_memory().unwrap();
        conn.pragma_update(None, "user_version", 109).unwrap();
        Migration109To110.up(&conn).unwrap();
    }
}
