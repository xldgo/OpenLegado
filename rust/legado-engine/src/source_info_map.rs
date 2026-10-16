//! 发现参数按来源存储；同引擎的发现控件与抓取宿主共用此服务。

use std::collections::HashMap;
use std::sync::Mutex;

use legado_core::{LegadoError, LegadoResult};
use legado_db::CacheRepository;

use crate::StorageContext;

type InfoMap = HashMap<String, String>;

#[derive(Default)]
struct State {
    values: HashMap<String, InfoMap>,
    storage: Option<StorageContext>,
}

/// 操作门控覆盖回填、读改写及落库，数据锁只保护短暂内存访问。
/// 不持有 VM、服务端状态或根引擎；调用方不得先借数据库连接再访问本服务。
#[derive(Default)]
pub struct SourceInfoMap {
    operations: Mutex<()>,
    state: Mutex<State>,
}

impl SourceInfoMap {
    pub(crate) fn with_storage(storage: StorageContext) -> Self {
        Self {
            operations: Mutex::new(()),
            state: Mutex::new(State {
                storage: Some(storage),
                ..Default::default()
            }),
        }
    }

    /// 未开库时仅缓存真正写过的键；绑定时与数据库合并，早期修改优先。
    pub(crate) fn bind_storage(&self, storage: StorageContext) -> LegadoResult<()> {
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        let early = {
            let state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            if state.storage.is_some() {
                return Err(LegadoError::Internal("发现参数已经绑定数据库".into()));
            }
            state.values.clone()
        };
        let mut merged = HashMap::new();
        for (source, changes) in early {
            let mut values = Self::load(&storage, &source);
            values.extend(changes);
            Self::persist(&storage, &source, &values);
            merged.insert(source, values);
        }
        let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
        state.values = merged;
        state.storage = Some(storage);
        Ok(())
    }

    fn cached(&self, source: &str) -> Option<InfoMap> {
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .values
            .get(source)
            .cloned()
    }

    /// 调用方已经持操作门控；未开库的空快照不成为权威空表。
    fn snapshot_locked(&self, source: &str) -> InfoMap {
        if let Some(values) = self.cached(source) {
            return values;
        }
        let storage = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .storage
            .clone();
        let Some(storage) = storage else {
            return InfoMap::new();
        };
        let values = Self::load(&storage, source);
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .values
            .insert(source.into(), values.clone());
        values
    }

    pub fn snapshot(&self, source: &str) -> InfoMap {
        if let Some(values) = self.cached(source) {
            return values;
        }
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        self.snapshot_locked(source)
    }

    pub fn put(&self, source: &str, key: &str, value: &str) {
        self.update(source, key, value, false);
    }

    /// 检查与写入属于同一次操作；并发默认值不能覆盖已经设置的用户值。
    pub fn ensure_default(&self, source: &str, key: &str, value: &str) {
        self.update(source, key, value, true);
    }

    fn update(&self, source: &str, key: &str, value: &str, only_missing: bool) {
        let _operation = self.operations.lock().unwrap_or_else(|p| p.into_inner());
        let mut values = self.snapshot_locked(source);
        if only_missing && values.contains_key(key) {
            return;
        }
        values.insert(key.into(), value.into());
        let storage = {
            let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            state.values.insert(source.into(), values.clone());
            state.storage.clone()
        };
        if let Some(storage) = storage {
            Self::persist(&storage, source, &values);
        }
    }

    fn load(storage: &StorageContext, source: &str) -> InfoMap {
        storage
            .with_database(|db| {
                CacheRepository::new(db.connection()).get(&format!("infoMap_{source}"))
            })
            .ok()
            .flatten()
            .and_then(|json| serde_json::from_str(&json).ok())
            .unwrap_or_default()
    }

    fn persist(storage: &StorageContext, source: &str, values: &InfoMap) {
        // 字符串映射必可序列化；保留失败时仅内存的宽容语义。
        let result = serde_json::to_string(values)
            .map_err(LegadoError::Serialization)
            .and_then(|json| {
                storage.with_database(|db| {
                    CacheRepository::new(db.connection()).put(
                        &format!("infoMap_{source}"),
                        &json,
                        0,
                    )
                })
            });
        if let Err(error) = result {
            log::warn!("发现参数持久化降级为内存: {error}");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::EngineContext;
    use std::sync::{Arc, Barrier};

    fn persisted(engine: &EngineContext, source: &str) -> InfoMap {
        SourceInfoMap::load(engine.storage(), source)
    }

    #[test]
    fn early_empty_read_does_not_hide_database_and_early_keys_win() {
        let early = Arc::new(SourceInfoMap::default());
        assert!(early.snapshot("untouched").is_empty());
        early.put("source", "mode", "early");
        let engine = EngineContext::in_memory().unwrap();
        engine
            .storage()
            .with_database(|db| {
                let repo = CacheRepository::new(db.connection());
                repo.put("infoMap_source", r#"{"mode":"old","other":"kept"}"#, 0)?;
                repo.put("infoMap_untouched", r#"{"from":"database"}"#, 0)
            })
            .unwrap();
        let engine = engine.with_source_info_map(early.clone()).unwrap();
        assert!(Arc::ptr_eq(&early, engine.source_info_map()));
        let values = early.snapshot("source");
        assert_eq!(values["mode"], "early");
        assert_eq!(values["other"], "kept");
        assert_eq!(early.snapshot("untouched")["from"], "database");
        assert_eq!(persisted(&engine, "source"), values);
        assert!(early.bind_storage(engine.storage().clone()).is_err());
    }

    #[test]
    fn concurrent_different_keys_are_not_lost_in_memory_or_database() {
        let engine = EngineContext::in_memory().unwrap();
        let start = Arc::new(Barrier::new(17));
        let threads: Vec<_> = (0..16)
            .map(|index| {
                let service = engine.source_info_map().clone();
                let start = start.clone();
                std::thread::spawn(move || {
                    start.wait();
                    service.put("source", &index.to_string(), "value");
                    service.ensure_default("source", &index.to_string(), "wrong");
                })
            })
            .collect();
        start.wait();
        for thread in threads {
            thread.join().unwrap();
        }
        let values = engine.source_info_map().snapshot("source");
        assert_eq!(values.len(), 16);
        assert!(values.values().all(|value| value == "value"));
        assert_eq!(persisted(&engine, "source"), values);
    }

    #[test]
    fn failed_write_stays_visible_and_engines_are_independent_and_release() {
        let engine = EngineContext::in_memory().unwrap();
        let other = EngineContext::in_memory().unwrap();
        engine.source_info_map().put("source", "mode", "old");
        engine.storage().with_database(|db| {
            db.connection().execute_batch("CREATE TRIGGER reject_info_map BEFORE INSERT ON caches BEGIN SELECT RAISE(FAIL, 'fixture'); END;")
                .map_err(|error| LegadoError::Database(error.to_string()))
        }).unwrap();
        engine
            .source_info_map()
            .put("source", "mode", "memory-only");
        assert_eq!(persisted(&engine, "source")["mode"], "old");
        assert_eq!(
            engine.source_info_map().snapshot("source")["mode"],
            "memory-only"
        );
        assert!(other.source_info_map().snapshot("source").is_empty());
        let weak = Arc::downgrade(engine.source_info_map());
        drop(engine);
        assert!(weak.upgrade().is_none());
    }
}
