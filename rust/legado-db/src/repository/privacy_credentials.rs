//! 隐私密码仅保存随机盐 Argon2id 摘要，不参与普通配置导出。— Codex + Bridge
use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier, password_hash::SaltString};
use rand_core::{OsRng, RngCore};
use rusqlite::{Connection, OptionalExtension, params};
use legado_core::{LegadoError, LegadoResult};

pub const CREATE_PRIVACY_CREDENTIALS: &str = "CREATE TABLE IF NOT EXISTS privacy_credentials (
    id INTEGER PRIMARY KEY CHECK(id=1), password_hash TEXT NOT NULL
);";

fn stored_hash(conn: &Connection) -> LegadoResult<Option<String>> {
    conn.query_row("SELECT password_hash FROM privacy_credentials WHERE id=1", [], |r| r.get(0))
        .optional().map_err(|e| LegadoError::Database(format!("读取隐私凭据失败: {e}")))
}
pub fn has_password(conn: &Connection) -> LegadoResult<bool> { Ok(stored_hash(conn)?.is_some()) }
pub fn verify_password(conn: &Connection, password: &str) -> LegadoResult<bool> {
    let Some(hash) = stored_hash(conn)? else { return Ok(false); };
    let parsed = PasswordHash::new(&hash).map_err(|_| LegadoError::Internal("隐私凭据损坏".into()))?;
    Ok(Argon2::default().verify_password(password.as_bytes(), &parsed).is_ok())
}
pub fn set_password(conn: &Connection, current: &str, password: &str) -> LegadoResult<bool> {
    if password.len() > 1024 || current.len() > 1024 {
        return Err(LegadoError::Internal("密码过长".into()));
    }
    if has_password(conn)? && !verify_password(conn, current)? { return Ok(false); }
    if password.is_empty() {
        conn.execute("DELETE FROM privacy_credentials WHERE id=1", [])
            .map_err(|e| LegadoError::Database(format!("清除隐私凭据失败: {e}")))?;
    } else {
        let mut salt = [0_u8; 16];
        OsRng.try_fill_bytes(&mut salt).map_err(|_| LegadoError::Internal("系统随机数不可用".into()))?;
        let salt = SaltString::encode_b64(&salt).map_err(|_| LegadoError::Internal("生成密码盐失败".into()))?;
        let hash = Argon2::default().hash_password(password.as_bytes(), &salt)
            .map_err(|_| LegadoError::Internal("生成隐私凭据失败".into()))?.to_string();
        conn.execute("INSERT INTO privacy_credentials(id,password_hash) VALUES(1,?1)
            ON CONFLICT(id) DO UPDATE SET password_hash=excluded.password_hash", params![hash])
            .map_err(|e| LegadoError::Database(format!("保存隐私凭据失败: {e}")))?;
    }
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn password_change_and_clear_require_old_credential() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(CREATE_PRIVACY_CREDENTIALS).unwrap();
        assert!(!verify_password(&conn, "").unwrap());
        assert!(set_password(&conn, "", "测试口令").unwrap());
        let hash = stored_hash(&conn).unwrap().unwrap();
        assert!(hash.starts_with("$argon2id$"));
        assert!(!hash.contains("测试口令"));
        assert!(!set_password(&conn, "错误", "新口令").unwrap());
        assert!(!set_password(&conn, "错误", "").unwrap());
        assert!(verify_password(&conn, "测试口令").unwrap());
        assert!(set_password(&conn, "测试口令", "新口令").unwrap());
        assert!(!verify_password(&conn, "测试口令").unwrap());
        assert!(set_password(&conn, "新口令", "").unwrap());
        assert!(!has_password(&conn).unwrap());
    }
}
