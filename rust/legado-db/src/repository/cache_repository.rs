//! 通用 KV 缓存 Repository
//!
//! 移植自 Kotlin CacheManager.kt，提供带 TTL 的键值缓存能力。
//! deadline = 0 表示永不过期；deadline > 0 表示过期时间戳（毫秒）。

use rusqlite::{Connection, params};
use std::sync::atomic::{AtomicBool, Ordering};

use legado_core::{LegadoError, LegadoResult};

/// 配置坏行继续跳过，仅首次告警，避免高频读取刷屏。
static CONFIG_ROW_FAIL_WARNED: AtomicBool = AtomicBool::new(false);

/// 缓存记录（对应 caches 表）
#[derive(Debug, Clone, PartialEq)]
pub struct CacheEntry {
    /// 缓存键（主键）
    pub key: String,
    /// 缓存值
    pub value: String,
    /// 过期时间戳（毫秒），0 表示永不过期
    pub deadline: i64,
    /// 创建时间戳（毫秒）
    pub created_at: i64,
}

/// 通用 KV 缓存数据访问层
pub struct CacheRepository<'a> {
    conn: &'a Connection,
}

impl<'a> CacheRepository<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }

    /// 批量读取配置原始键值；不套用普通缓存的过期清理规则。
    pub fn configuration_entries(&self) -> LegadoResult<Vec<(String, String)>> {
        let mut stmt = self
            .conn
            .prepare("SELECT key, value FROM caches WHERE key LIKE ?1")
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;
        let rows = stmt
            .query_map(params!["config:%"], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?;
        let mut entries = Vec::new();
        for row in rows {
            match row {
                Ok(entry) => entries.push(entry),
                Err(e) => {
                    if CONFIG_ROW_FAIL_WARNED
                        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
                        .is_ok()
                    {
                        log::warn!("读取配置行失败（仅告警一次，后续静默跳过）: {e}");
                    }
                }
            }
        }
        Ok(entries)
    }

    /// 清理指定书籍的章级开关，书籍 URL 中的 LIKE 通配符只按字面匹配。
    pub fn delete_same_title_removed(&self, book_url: &str) -> LegadoResult<usize> {
        let escaped = book_url
            .replace('\\', "\\\\")
            .replace('%', "\\%")
            .replace('_', "\\_");
        let pattern = format!("sameTitleRemoved:{escaped}:%");
        self.conn
            .execute(
                "DELETE FROM caches WHERE key LIKE ?1 ESCAPE '\\'",
                params![pattern],
            )
            .map_err(|e| LegadoError::Database(format!("复位章级开关失败：{e}")))
    }

    /// 写入缓存
    ///
    /// - `ttl_seconds`: 生存时间（秒），0 表示永不过期
    pub fn put(&self, key: &str, value: &str, ttl_seconds: i64) -> LegadoResult<()> {
        let now = current_time_millis();
        let deadline = if ttl_seconds == 0 {
            0
        } else {
            now + ttl_seconds * 1000
        };
        self.conn
            .execute(
                "INSERT OR REPLACE INTO caches (key, value, deadline, created_at)
                 VALUES (?1, ?2, ?3, ?4)",
                params![key, value, deadline, now],
            )
            .map_err(|e| LegadoError::Database(format!("写入缓存失败: {e}")))?;
        Ok(())
    }

    /// 读取缓存，过期则删除并返回 None
    pub fn get(&self, key: &str) -> LegadoResult<Option<String>> {
        let result = self.conn.query_row(
            "SELECT value, deadline FROM caches WHERE key = ?1",
            params![key],
            |row| {
                let value: String = row.get(0)?;
                let deadline: i64 = row.get(1)?;
                Ok((value, deadline))
            },
        );

        match result {
            Ok((value, deadline)) => {
                if deadline == 0 || deadline > current_time_millis() {
                    Ok(Some(value))
                } else {
                    // 已过期，删除
                    self.delete(key)?;
                    Ok(None)
                }
            }
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(LegadoError::Database(format!("读取缓存失败: {e}"))),
        }
    }

    /// 删除指定缓存
    pub fn delete(&self, key: &str) -> LegadoResult<()> {
        self.conn
            .execute("DELETE FROM caches WHERE key = ?1", params![key])
            .map_err(|e| LegadoError::Database(format!("删除缓存失败: {e}")))?;
        Ok(())
    }

    /// 清理所有过期缓存，返回清理条数
    pub fn cleanup_expired(&self) -> LegadoResult<usize> {
        let now = current_time_millis();
        let count = self
            .conn
            .execute(
                "DELETE FROM caches WHERE deadline > 0 AND deadline <= ?1",
                params![now],
            )
            .map_err(|e| LegadoError::Database(format!("清理过期缓存失败: {e}")))?;
        Ok(count)
    }

    /// 清空所有缓存
    pub fn clear(&self) -> LegadoResult<()> {
        self.conn
            .execute("DELETE FROM caches", [])
            .map_err(|e| LegadoError::Database(format!("清空缓存失败: {e}")))?;
        Ok(())
    }

    /// 获取缓存总数
    pub fn count(&self) -> LegadoResult<usize> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM caches", [], |row| row.get(0))
            .map_err(|e| LegadoError::Database(format!("查询缓存数量失败: {e}")))?;
        usize::try_from(count)
            .map_err(|e| LegadoError::Database(format!("缓存数量超出可表示范围: {e}")))
    }

    /// 判断 key 是否存在（不考虑过期）
    pub fn contains_key(&self, key: &str) -> LegadoResult<bool> {
        let count: i32 = self
            .conn
            .query_row(
                "SELECT COUNT(*) FROM caches WHERE key = ?1",
                params![key],
                |row| row.get(0),
            )
            .map_err(|e| LegadoError::Database(format!("查询缓存失败: {e}")))?;
        Ok(count > 0)
    }
}

/// 获取当前时间戳（毫秒）
fn current_time_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::schema;

    fn setup_db() -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        schema::init_schema(&conn).unwrap();
        conn
    }

    #[test]
    fn configuration_query_skips_bad_rows_without_expiring_entries() {
        let conn = setup_db();
        conn.execute_batch(
            "INSERT INTO caches(key,value,deadline,created_at) VALUES
            ('config:theme','dark',0,0), ('config:expired','kept',1,0),
            ('config:bad',x'80',0,0), ('other','hidden',0,0);",
        )
        .unwrap();
        let repo = CacheRepository::new(&conn);
        let mut entries = repo.configuration_entries().unwrap();
        entries.sort();
        assert_eq!(
            entries,
            [
                ("config:expired".into(), "kept".into()),
                ("config:theme".into(), "dark".into())
            ]
        );
        assert_eq!(repo.count().unwrap(), 4);
        conn.execute_batch("DROP TABLE caches").unwrap();
        assert!(repo.configuration_entries().is_err());
    }

    #[test]
    fn same_title_cleanup_escapes_url_and_keeps_other_keys() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        let book = r"fixture://a%_\b";
        for key in [
            format!("sameTitleRemoved:{book}:0"),
            format!("sameTitleRemoved:{book}:1"),
            r"sameTitleRemoved:fixture://aXY\b:0".into(),
            format!("sameTitleRemoved:{book}extra:0"),
            format!("other:{book}:0"),
        ] {
            repo.put(&key, "1", 0).unwrap();
        }
        assert_eq!(repo.delete_same_title_removed(book).unwrap(), 2);
        assert_eq!(repo.delete_same_title_removed(book).unwrap(), 0);
        assert_eq!(repo.count().unwrap(), 3);
        assert!(
            repo.contains_key(r"sameTitleRemoved:fixture://aXY\b:0")
                .unwrap()
        );
        assert!(
            repo.contains_key(&format!("sameTitleRemoved:{book}extra:0"))
                .unwrap()
        );
    }

    #[test]
    fn test_put_and_get() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        repo.put("key1", "value1", 0).unwrap();
        assert_eq!(repo.get("key1").unwrap(), Some("value1".to_string()));
    }

    #[test]
    fn test_get_nonexistent() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        assert_eq!(repo.get("missing").unwrap(), None);
    }

    #[test]
    fn test_put_overwrite() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        repo.put("key1", "v1", 0).unwrap();
        repo.put("key1", "v2", 0).unwrap();
        assert_eq!(repo.get("key1").unwrap(), Some("v2".to_string()));
    }

    #[test]
    fn test_delete() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        repo.put("key1", "value1", 0).unwrap();
        repo.delete("key1").unwrap();
        assert_eq!(repo.get("key1").unwrap(), None);
    }

    #[test]
    fn test_expired_entry_returns_none() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        // 插入一个已过期的条目（deadline 设为过去）
        conn.execute(
            "INSERT INTO caches (key, value, deadline, created_at) VALUES (?1, ?2, ?3, ?4)",
            params!["expired_key", "old_value", 1i64, 1i64],
        )
        .unwrap();
        assert_eq!(repo.get("expired_key").unwrap(), None);
        // 确认已被删除
        assert!(!repo.contains_key("expired_key").unwrap());
    }

    #[test]
    fn test_cleanup_expired() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        // 插入过期和未过期的条目
        conn.execute(
            "INSERT INTO caches (key, value, deadline, created_at) VALUES (?1, ?2, ?3, ?4)",
            params!["expired1", "v1", 1i64, 1i64],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO caches (key, value, deadline, created_at) VALUES (?1, ?2, ?3, ?4)",
            params!["expired2", "v2", 2i64, 1i64],
        )
        .unwrap();
        repo.put("permanent", "v3", 0).unwrap();
        let cleaned = repo.cleanup_expired().unwrap();
        assert_eq!(cleaned, 2);
        assert_eq!(repo.count().unwrap(), 1);
    }

    #[test]
    fn test_clear() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        repo.put("a", "1", 0).unwrap();
        repo.put("b", "2", 0).unwrap();
        repo.put("c", "3", 0).unwrap();
        repo.clear().unwrap();
        assert_eq!(repo.count().unwrap(), 0);
    }

    #[test]
    fn test_count() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        assert_eq!(repo.count().unwrap(), 0);
        repo.put("x", "1", 0).unwrap();
        repo.put("y", "2", 0).unwrap();
        assert_eq!(repo.count().unwrap(), 2);
    }

    #[test]
    fn test_contains_key() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        assert!(!repo.contains_key("k").unwrap());
        repo.put("k", "v", 0).unwrap();
        assert!(repo.contains_key("k").unwrap());
    }

    #[test]
    fn test_ttl_not_expired() {
        let conn = setup_db();
        let repo = CacheRepository::new(&conn);
        // TTL 3600秒，不应过期
        repo.put("ttl_key", "ttl_value", 3600).unwrap();
        assert_eq!(repo.get("ttl_key").unwrap(), Some("ttl_value".to_string()));
    }
}
