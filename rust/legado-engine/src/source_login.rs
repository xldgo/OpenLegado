//! 来源登录缓存：同一引擎的原生宿主与 JS 共享内存和唯一持久化后端。

use std::collections::HashMap;
use std::sync::Mutex;

use legado_core::{LegadoError, LegadoResult};
use legado_db::CacheRepository;

use crate::StorageContext;

#[derive(Default)]
struct LoginState {
    /// None 是显式删除，不能因持久化失败或稍后绑定数据库而复活旧行。
    values: HashMap<String, Option<String>>,
    storage: Option<StorageContext>,
}

/// 回填和写入按服务串行，内存命中不等数据库；不持有宿主、VM 或根引擎。
/// 调用方不能先借用数据库连接再调用本服务，单连接池也须遵守此顺序。
#[derive(Default)]
pub struct SourceLoginCache {
    operations: Mutex<()>,
    state: Mutex<LoginState>,
}

impl SourceLoginCache {
    pub(crate) fn with_storage(storage: StorageContext) -> Self {
        Self {
            operations: Mutex::new(()),
            state: Mutex::new(LoginState {
                storage: Some(storage),
                ..Default::default()
            }),
        }
    }

    /// 首次开库接续早期值；后端发布与回写在同一门控下，不接受再次绑定。
    pub(crate) fn bind_storage(&self, storage: StorageContext) -> LegadoResult<()> {
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        let values = {
            let state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            if state.storage.is_some() {
                return Err(LegadoError::Internal("来源登录缓存已经绑定数据库".into()));
            }
            state.values.clone()
        };
        for (key, value) in &values {
            Self::persist(&storage, key, value.as_deref());
        }
        self.state.lock().unwrap_or_else(|p| p.into_inner()).storage = Some(storage);
        Ok(())
    }

    fn persist(storage: &StorageContext, key: &str, value: Option<&str>) {
        let result = storage.with_database(|db| {
            let repository = CacheRepository::new(db.connection());
            match value {
                Some(value) => repository.put(key, value, 0),
                None => repository.delete(key),
            }
        });
        if let Err(error) = result {
            // 不打印键值；登录头及用户信息可能包含凭据。
            log::warn!("来源登录缓存持久化降级为内存: {error}");
        }
    }

    fn get(&self, key: &str) -> Option<String> {
        if let Some(value) = self.cached(key) {
            return value;
        }
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        // 等待门控期间可能已经有写入/删除，不能用随后读出的旧行覆盖它。
        if let Some(value) = self.cached(key) {
            return value;
        }
        self.load_missing(key)
    }

    /// 调用方已持操作门控；数据锁只用于取后端与回填，不跨 SQL。
    fn load_missing(&self, key: &str) -> Option<String> {
        let storage = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .storage
            .clone()?;
        let value = storage
            .with_database(|db| CacheRepository::new(db.connection()).get(key))
            .ok()
            .flatten()?;
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .values
            .insert(key.to_string(), Some(value.clone()));
        Some(value)
    }

    fn put(&self, key: String, value: Option<String>) {
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        let storage = {
            let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            state.values.insert(key.clone(), value.clone());
            state.storage.clone()
        };
        if let Some(storage) = storage {
            Self::persist(&storage, &key, value.as_deref());
        }
    }

    fn take(&self, key: &str) -> Option<String> {
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        let previous = self.cached(key).unwrap_or_else(|| self.load_missing(key));
        let storage = {
            let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            state.values.insert(key.to_string(), None);
            state.storage.clone()
        };
        if let Some(storage) = storage {
            Self::persist(&storage, key, None);
        }
        previous
    }

    /// 外层 None 表示未读取，内层 None 表示删除；内存锁不跨数据库 I/O。
    fn cached(&self, key: &str) -> Option<Option<String>> {
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .values
            .get(key)
            .cloned()
    }

    pub fn get_login_header(&self, source_url: &str) -> Option<String> {
        self.get(&format!("loginHeader_{source_url}"))
    }

    pub fn put_login_header(&self, source_url: &str, header: &str) {
        self.put(
            format!("loginHeader_{source_url}"),
            Some(header.to_string()),
        );
    }

    pub fn remove_login_header(&self, source_url: &str) {
        self.put(format!("loginHeader_{source_url}"), None);
    }

    pub fn get_login_info(&self, source_url: &str) -> Option<String> {
        self.get(&format!("userInfo_{source_url}"))
    }

    pub fn put_login_info(&self, source_url: &str, info: &str) {
        self.put(format!("userInfo_{source_url}"), Some(info.to_string()));
    }

    pub fn remove_login_info(&self, source_url: &str) {
        self.put(format!("userInfo_{source_url}"), None);
    }
}

impl legado_js::source_login::SourceLoginStore for SourceLoginCache {
    fn get(
        &self,
        kind: legado_js::source_login::SourceLoginKind,
        source_url: &str,
    ) -> Option<String> {
        match kind {
            legado_js::source_login::SourceLoginKind::Header => self.get_login_header(source_url),
            legado_js::source_login::SourceLoginKind::Info => self.get_login_info(source_url),
        }
    }

    fn put(&self, kind: legado_js::source_login::SourceLoginKind, source_url: &str, value: &str) {
        match kind {
            legado_js::source_login::SourceLoginKind::Header => {
                self.put_login_header(source_url, value)
            }
            legado_js::source_login::SourceLoginKind::Info => {
                self.put_login_info(source_url, value)
            }
        }
    }

    fn remove(
        &self,
        kind: legado_js::source_login::SourceLoginKind,
        source_url: &str,
    ) -> Option<String> {
        let prefix = match kind {
            legado_js::source_login::SourceLoginKind::Header => "loginHeader_",
            legado_js::source_login::SourceLoginKind::Info => "userInfo_",
        };
        self.take(&format!("{prefix}{source_url}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::EngineContext;
    use std::sync::Arc;

    fn db_value(engine: &EngineContext, key: &str) -> Option<String> {
        engine
            .storage()
            .with_database(|db| CacheRepository::new(db.connection()).get(key))
            .unwrap()
    }

    #[test]
    fn engines_keep_login_memory_and_database_independent() {
        let one = EngineContext::in_memory().unwrap();
        let two = EngineContext::in_memory().unwrap();
        let a = one.source_login_cache();
        let b = two.source_login_cache();
        a.put_login_header("source", "header-a");
        a.put_login_info("source", "user-a");
        b.put_login_header("source", "header-b");
        b.put_login_info("source", "user-b");
        a.remove_login_header("source");
        assert_eq!(a.get_login_header("source"), None);
        assert_eq!(b.get_login_header("source").as_deref(), Some("header-b"));
        assert_eq!(a.get_login_info("source").as_deref(), Some("user-a"));
        assert_eq!(db_value(&one, "loginHeader_source"), None);
        assert_eq!(
            db_value(&two, "loginHeader_source").as_deref(),
            Some("header-b")
        );
        assert_eq!(db_value(&one, "userInfo_source").as_deref(), Some("user-a"));
        b.remove_login_info("source");
        assert_eq!(db_value(&two, "userInfo_source"), None);
    }

    #[test]
    fn early_values_and_deletions_survive_first_database_binding() {
        let cache = Arc::new(SourceLoginCache::default());
        cache.put_login_header("source", "early");
        cache.remove_login_info("source");
        let engine = EngineContext::in_memory().unwrap();
        engine
            .storage()
            .with_database(|db| {
                let repository = CacheRepository::new(db.connection());
                repository.put("loginHeader_source", "old", 0)?;
                repository.put("userInfo_source", "old-user", 0)
            })
            .unwrap();
        let engine = engine.with_source_login_cache(cache.clone()).unwrap();
        assert!(Arc::ptr_eq(&cache, engine.source_login_cache()));
        assert_eq!(cache.get_login_header("source").as_deref(), Some("early"));
        assert_eq!(
            db_value(&engine, "loginHeader_source").as_deref(),
            Some("early")
        );
        assert_eq!(db_value(&engine, "userInfo_source"), None);
        let other = EngineContext::in_memory().unwrap();
        assert!(cache.bind_storage(other.storage().clone()).is_err());
        cache.put_login_info("source", "new-user");
        assert_eq!(
            db_value(&engine, "userInfo_source").as_deref(),
            Some("new-user")
        );
        assert_eq!(db_value(&other, "userInfo_source"), None);
    }

    #[test]
    fn missing_database_rows_are_not_negatively_cached() {
        let engine = EngineContext::in_memory().unwrap();
        let cache = engine.source_login_cache();
        assert_eq!(cache.get_login_header("later"), None);
        engine
            .storage()
            .with_database(|db| {
                CacheRepository::new(db.connection()).put("loginHeader_later", "later-value", 0)
            })
            .unwrap();
        assert_eq!(
            cache.get_login_header("later").as_deref(),
            Some("later-value")
        );
    }

    #[test]
    fn failed_delete_does_not_reload_old_persisted_value() {
        let engine = EngineContext::in_memory().unwrap();
        let cache = engine.source_login_cache();
        cache.put_login_info("source", "old-user");
        engine.storage().with_database(|db| {
            db.connection().execute_batch("CREATE TRIGGER reject_login_delete BEFORE DELETE ON caches WHEN OLD.key = 'userInfo_source' BEGIN SELECT RAISE(FAIL, '模拟删除失败'); END;")
                .map_err(|error| LegadoError::Database(error.to_string()))
        }).unwrap();
        cache.remove_login_info("source");
        assert_eq!(
            db_value(&engine, "userInfo_source").as_deref(),
            Some("old-user")
        );
        assert_eq!(
            cache.get_login_info("source"),
            None,
            "数据库失败不能让本实例删除的登录值复活"
        );
    }

    #[test]
    fn database_refill_cannot_overtake_a_later_delete() {
        let engine = EngineContext::in_memory().unwrap();
        engine
            .source_login_cache()
            .put_login_header("cached", "immediate");
        engine
            .storage()
            .with_database(|db| {
                CacheRepository::new(db.connection()).put("loginHeader_source", "old", 0)
            })
            .unwrap();
        let held_connection = engine.storage().database().unwrap();
        let cache = engine.source_login_cache().clone();
        let reader_cache = cache.clone();
        let reader = std::thread::spawn(move || reader_cache.get_login_header("source"));
        // 只有读者已进入服务并等待池连接后，才安排删除；不依赖固定 sleep 猜顺序。
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(2);
        while cache.operations.try_lock().is_ok() {
            assert!(std::time::Instant::now() < deadline, "读者未进入回填门控");
            std::thread::yield_now();
        }
        let (sender, receiver) = std::sync::mpsc::channel();
        let hit_cache = cache.clone();
        let hit_reader =
            std::thread::spawn(move || sender.send(hit_cache.get_login_header("cached")).unwrap());
        assert_eq!(
            receiver
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap()
                .as_deref(),
            Some("immediate"),
            "其他登录值的内存命中不能被数据库回填阻塞"
        );
        hit_reader.join().unwrap();
        let writer_cache = cache.clone();
        let writer = std::thread::spawn(move || writer_cache.remove_login_header("source"));
        drop(held_connection);
        assert_eq!(reader.join().unwrap().as_deref(), Some("old"));
        writer.join().unwrap();
        assert_eq!(cache.get_login_header("source"), None);
        assert_eq!(db_value(&engine, "loginHeader_source"), None);
    }

    #[test]
    fn cache_outlives_root_without_retaining_it_or_any_static_owner() {
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        let root = Arc::downgrade(&engine);
        let cache = engine.source_login_cache().clone();
        let weak = Arc::downgrade(&cache);
        cache.put_login_header("source", "retained");
        drop(engine);
        assert!(root.upgrade().is_none());
        assert_eq!(
            cache.get_login_header("source").as_deref(),
            Some("retained")
        );
        drop(cache);
        assert!(weak.upgrade().is_none());
    }
}
