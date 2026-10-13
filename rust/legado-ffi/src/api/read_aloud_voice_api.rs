//! 音色目录薄接口，平台发现由 Flutter 注入。
use legado_core::LegadoResult;
use legado_db::repository::read_aloud_voice_repository::{
    ReadAloudVoiceRepository, SystemVoiceEntry,
};
pub fn list() -> LegadoResult<String> {
    crate::db_state::with_database(|db| {
        Ok(serde_json::to_string(
            &ReadAloudVoiceRepository::new(db.connection()).list()?,
        )?)
    })
}
pub fn sync_system(engine: &str, json: &str) -> LegadoResult<()> {
    let entries: Vec<SystemVoiceEntry> = serde_json::from_str(json)?;
    crate::db_state::with_database(|db| {
        ReadAloudVoiceRepository::new(db.connection()).sync_system(engine, entries)
    })
}
pub fn set_flags(id: &str, enabled: bool, excluded: bool) -> LegadoResult<bool> {
    crate::db_state::with_database(|db| {
        ReadAloudVoiceRepository::new(db.connection()).set_flags(id, enabled, excluded)
    })
}
