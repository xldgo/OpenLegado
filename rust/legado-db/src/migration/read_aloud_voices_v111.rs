//! 新增音色目录表，只建表，不导入或回填历史数据。
use super::Migration;
use legado_core::{LegadoError, LegadoResult};
use rusqlite::Connection;
pub struct Migration110To111;
impl Migration for Migration110To111 {
    fn from_version(&self) -> u32 {
        110
    }
    fn to_version(&self) -> u32 {
        111
    }
    fn description(&self) -> &str {
        "新增独立朗读音色目录"
    }
    fn up(&self, conn: &Connection) -> LegadoResult<()> {
        conn.execute_batch(crate::schema::CREATE_READ_ALOUD_VOICES)
            .map_err(|e| LegadoError::Database(e.to_string()))
    }
    fn down(&self, _: &Connection) -> LegadoResult<()> {
        Err(LegadoError::Database("音色目录不自动删除回退".into()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn additive_migration_does_not_backfill_or_modify_http_sources() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch("CREATE TABLE httpTTS(id INTEGER PRIMARY KEY,name TEXT,url TEXT); INSERT INTO httpTTS VALUES(1,'已有源','https://tts'); PRAGMA user_version=110;").unwrap();
        super::super::MigrationRegistry::new()
            .migrate_to_latest(&conn)
            .unwrap();
        assert_eq!(
            super::super::MigrationRegistry::current_version(&conn).unwrap(),
            crate::schema::SCHEMA_VERSION
        );
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM read_aloud_voices", [], |r| r.get(0))
            .unwrap();
        assert_eq!(count, 0);
        let url: String = conn
            .query_row("SELECT url FROM httpTTS WHERE id=1", [], |r| r.get(0))
            .unwrap();
        assert_eq!(url, "https://tts");
        Migration110To111.up(&conn).unwrap();
        assert_eq!(
            crate::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(&conn)
                .list()
                .unwrap()
                .len(),
            0
        );
    }
}
