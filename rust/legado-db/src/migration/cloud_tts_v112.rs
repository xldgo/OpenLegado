//! 云端元数据仅建表，不迁移或读取历史凭据。
use super::Migration;
use legado_core::{LegadoError, LegadoResult};
use rusqlite::Connection;
pub struct Migration111To112;
impl Migration for Migration111To112 {
    fn from_version(&self) -> u32 {
        111
    }
    fn to_version(&self) -> u32 {
        112
    }
    fn description(&self) -> &str {
        "新增独立云端朗读元数据"
    }
    fn up(&self, c: &Connection) -> LegadoResult<()> {
        c.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .map_err(|e| LegadoError::Database(e.to_string()))
    }
    fn down(&self, _: &Connection) -> LegadoResult<()> {
        Err(LegadoError::Database("云端配置不自动删除回退".into()))
    }
}
