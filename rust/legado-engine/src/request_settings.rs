//! 所属数据库的配置读取；连接在调度/网络等待前归还。
use crate::StorageContext;
use legado_core::LegadoResult;
use std::num::NonZeroUsize;
pub fn from_database(db: &legado_db::Database) -> LegadoResult<NonZeroUsize> {
    let value = legado_db::CacheRepository::new(db.connection()).get("config:threadCount")?;
    Ok(legado_core::request_settings::parse_thread_count(
        value.as_deref(),
    ))
}
pub fn thread_count(storage: Option<&StorageContext>) -> LegadoResult<NonZeroUsize> {
    storage.map_or_else(
        || Ok(legado_core::request_settings::parse_thread_count(None)),
        |storage| storage.with_database(from_database),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn values_are_isolated_and_read_failures_are_not_defaults() {
        let one = crate::EngineContext::in_memory().unwrap();
        let two = crate::EngineContext::in_memory().unwrap();
        one.storage()
            .with_database(|db| {
                legado_db::CacheRepository::new(db.connection()).put("config:threadCount", "3", 0)
            })
            .unwrap();
        let snapshot = thread_count(Some(one.storage())).unwrap();
        one.storage()
            .with_database(|db| {
                legado_db::CacheRepository::new(db.connection()).put("config:threadCount", "7", 0)
            })
            .unwrap();
        assert_eq!(snapshot.get(), 3);
        assert_eq!(thread_count(Some(one.storage())).unwrap().get(), 7);
        assert_eq!(thread_count(Some(two.storage())).unwrap().get(), 16);
        one.storage()
            .with_database(|db| {
                db.connection()
                    .execute_batch("DROP TABLE caches")
                    .map_err(|e| legado_core::LegadoError::Database(e.to_string()))
            })
            .unwrap();
        assert!(thread_count(Some(one.storage())).is_err());
        assert_eq!(thread_count(Some(two.storage())).unwrap().get(), 16);
    }
}
