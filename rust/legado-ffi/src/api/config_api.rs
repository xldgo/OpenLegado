//! 配置管理 API
//!
//! 基于 caches 表实现应用配置的读写操作。

use legado_core::LegadoResult;
use legado_db::CacheRepository;

use crate::db_state::with_database;

/// 配置键前缀
const CONFIG_PREFIX: &str = "config:";

/// 获取指定配置项的值（不存在返回空字符串）
pub fn get_config(key: &str) -> LegadoResult<String> {
    with_database(|db| {
        let repo = CacheRepository::new(db.connection());
        let full_key = format!("{}{}", CONFIG_PREFIX, key);
        Ok(repo.get(&full_key)?.unwrap_or_default())
    })
}

/// 设置配置项
pub fn set_config(key: &str, value: &str) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = CacheRepository::new(db.connection());
        let full_key = format!("{}{}", CONFIG_PREFIX, key);
        repo.put(&full_key, value, 0)?; // ttl=0 永不过期
        Ok(true)
    })
}

/// 获取所有配置项（JSON 对象）
pub fn get_all_config() -> LegadoResult<std::collections::HashMap<String, String>> {
    with_database(|db| {
        let entries = CacheRepository::new(db.connection()).configuration_entries()?;
        Ok(entries
            .into_iter()
            .map(|(key, value)| {
                let short_key = key.strip_prefix(CONFIG_PREFIX).unwrap_or(&key);
                (short_key.to_string(), value)
            })
            .collect())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_crud() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 设置配置
        assert!(set_config("theme", "dark").unwrap());
        assert!(set_config("font_size", "16").unwrap());

        // 获取配置
        assert_eq!(get_config("theme").unwrap(), "dark");
        assert_eq!(get_config("font_size").unwrap(), "16");
        assert_eq!(get_config("nonexistent").unwrap(), "");

        // 获取所有配置
        let all = get_all_config().unwrap();
        assert!(all.contains_key("theme"));
        assert!(all.contains_key("font_size"));
    }
}
