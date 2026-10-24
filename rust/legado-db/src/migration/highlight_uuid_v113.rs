//! 高亮规则补稳定UUID，保留本地主键及既有规则。
use super::{Migration, add_column_if_not_exists, table_exists};
use legado_core::models::HighlightRule;
use legado_core::{LegadoError, LegadoResult};
use rusqlite::{Connection, params};

pub struct Migration112To113;

impl Migration for Migration112To113 {
    fn from_version(&self) -> u32 {
        112
    }
    fn to_version(&self) -> u32 {
        113
    }
    fn description(&self) -> &str {
        "高亮规则增加稳定UUID"
    }
    fn up(&self, conn: &Connection) -> LegadoResult<()> {
        if !table_exists(conn, "highlightRules")? {
            return Ok(());
        }
        add_column_if_not_exists(conn, "highlightRules", "uuid", "TEXT NOT NULL DEFAULT ''")?;
        let ids = conn
            .prepare("SELECT id FROM highlightRules WHERE uuid = ''")
            .and_then(|mut s| {
                s.query_map([], |r| r.get::<_, i64>(0))?
                    .collect::<rusqlite::Result<Vec<_>>>()
            })
            .map_err(|e| LegadoError::Database(format!("读取高亮规则标识失败：{e}")))?;
        for id in ids {
            conn.execute(
                "UPDATE highlightRules SET uuid=?1 WHERE id=?2",
                params![HighlightRule::new_uuid(), id],
            )
            .map_err(|e| LegadoError::Database(format!("补齐高亮规则标识失败：{e}")))?;
        }
        conn.execute_batch("CREATE UNIQUE INDEX IF NOT EXISTS index_highlight_rules_uuid ON highlightRules(uuid) WHERE uuid <> '';")
            .map_err(|e| LegadoError::Database(format!("创建高亮规则标识索引失败：{e}")))
    }
    fn down(&self, _: &Connection) -> LegadoResult<()> {
        Err(LegadoError::Database("稳定规则标识不自动删除回退".into()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn highlight_rule_migration_preserves_identity_and_content() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch("CREATE TABLE highlightRules(id INTEGER PRIMARY KEY, name TEXT); INSERT INTO highlightRules VALUES(42,'用户规则');").unwrap();
        Migration112To113.up(&conn).unwrap();
        let before: (String, String) = conn
            .query_row(
                "SELECT uuid,name FROM highlightRules WHERE id=42",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .unwrap();
        assert!(!before.0.is_empty());
        Migration112To113.up(&conn).unwrap();
        let after: (String, String) = conn
            .query_row(
                "SELECT uuid,name FROM highlightRules WHERE id=42",
                [],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .unwrap();
        assert_eq!(before, after);
        assert_eq!(after.1, "用户规则");
    }
}
