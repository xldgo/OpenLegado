//! 密码摘要操作在持有数据库锁时完成，避免并发改密绕过旧凭据验证。— Codex + Bridge
use legado_core::LegadoResult;
use legado_db::repository::privacy_credentials as credentials;
use crate::db_state::with_database;

pub fn has_password() -> LegadoResult<bool> {
    with_database(|db| credentials::has_password(db.connection()))
}
pub fn verify_password(password: &str) -> LegadoResult<bool> {
    with_database(|db| credentials::verify_password(db.connection(), password))
}
pub fn set_password(current: &str, password: &str) -> LegadoResult<bool> {
    with_database(|db| credentials::set_password(db.connection(), current, password))
}
