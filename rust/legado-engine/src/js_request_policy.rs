//! JS只借用存储和源限流器，避免VM缓存回指根引擎。
use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookSourceRepository, CacheRepository, HttpTtsRepository, RssSourceRepository};
use legado_fetcher::rate_limit::RateLimiterRegistry;
use legado_js::http_request_policy::{
    HttpRequestPolicy, RequestGate, RequestPolicySnapshot, RequestWait,
};
use std::{collections::BTreeMap, sync::Arc};

pub(crate) struct DbJsRequestPolicy {
    pub storage: crate::StorageContext,
    pub rates: Arc<RateLimiterRegistry>,
}

struct SourceGate {
    rates: Arc<RateLimiterRegistry>,
    key: String,
    rate: String,
}

impl RequestGate for SourceGate {
    fn acquire(&self) -> RequestWait<'_> {
        Box::pin(self.rates.acquire_key(&self.key, &self.rate))
    }
}

impl HttpRequestPolicy for DbJsRequestPolicy {
    fn snapshot(&self, source: Option<&str>) -> Result<RequestPolicySnapshot, String> {
        // 整批读取一次，归还连接后才能等待网络或限流。
        let (concurrency, rate) = self
            .storage
            .with_database(|db| {
                let concurrency = crate::request_settings::from_database(db)?;
                let rate = source
                    .map(|key| source_rate(db, key))
                    .transpose()?
                    .flatten();
                Ok((concurrency, rate))
            })
            .map_err(|e| format!("读取JS请求策略失败: {e}"))?;
        let gate = source.zip(rate).map(|(key, rate)| {
            Arc::new(SourceGate {
                rates: self.rates.clone(),
                key: key.to_owned(),
                rate,
            }) as Arc<dyn RequestGate>
        });
        Ok(RequestPolicySnapshot { concurrency, gate })
    }
}

fn source_rate(db: &legado_db::Database, key: &str) -> LegadoResult<Option<String>> {
    if let Some(id) = key
        .strip_prefix("httpTts:")
        .and_then(|id| id.parse::<i64>().ok())
    {
        let configured = HttpTtsRepository::new(db.connection())
            .find_by_id(id)?
            .and_then(|source| source.concurrent_rate);
        let state = CacheRepository::new(db.connection())
            .get(&format!("ttsSourceState_{key}"))?
            .map(|value| serde_json::from_str::<BTreeMap<String, String>>(&value))
            .transpose()?;
        return Ok(state
            .and_then(|state| state.get("concurrentRate").cloned())
            .or(configured));
    }
    if let Some(source) = BookSourceRepository::new(db.connection()).find_by_url(key)? {
        return Ok(source.concurrent_rate);
    }
    Ok(RssSourceRepository::new(db.connection())
        .find_by_url(key)
        .map_err(LegadoError::Database)?
        .and_then(|source| source.concurrent_rate))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::EngineContext;
    use legado_js::JsEngine;
    use std::time::Duration;

    fn config(engine: &EngineContext, value: &str) {
        engine
            .storage()
            .with_database(|db| {
                CacheRepository::new(db.connection()).put("config:threadCount", value, 0)
            })
            .unwrap();
    }

    #[test]
    fn concurrency_is_owned_by_engine_and_snapshot_is_stable() {
        let one = EngineContext::in_memory().unwrap();
        let two = EngineContext::in_memory().unwrap();
        let request = one.js_resources().http_resources().request_for(None);
        assert_eq!(request.policy().unwrap().concurrency.get(), 16);
        config(&one, "2");
        let before = request.policy().unwrap();
        config(&one, "7");
        assert_eq!(before.concurrency.get(), 2);
        assert_eq!(request.policy().unwrap().concurrency.get(), 7);
        assert_eq!(
            two.js_resources()
                .http_resources()
                .request_for(None)
                .policy()
                .unwrap()
                .concurrency
                .get(),
            16
        );
        for invalid in ["0", "-1", "bad", "257", "2147483648"] {
            config(&one, invalid);
            assert_eq!(request.policy().unwrap().concurrency.get(), 16);
        }
    }

    #[tokio::test]
    async fn source_kinds_share_the_registry_but_engines_remain_isolated() {
        let one = EngineContext::in_memory().unwrap();
        let two = EngineContext::in_memory().unwrap();
        for engine in [&one, &two] {
            engine
                .storage()
                .with_database(|db| {
                    BookSourceRepository::new(db.connection()).insert_batch(&[
                        legado_core::models::BookSource {
                            book_source_url: "book-key".into(),
                            concurrent_rate: Some("1/10000".into()),
                            ..Default::default()
                        },
                    ])?;
                    RssSourceRepository::new(db.connection())
                        .insert(&legado_core::models::RssSource {
                            source_url: "rss-key".into(),
                            concurrent_rate: Some("1/10000".into()),
                            ..Default::default()
                        })
                        .map_err(LegadoError::Database)?;
                    let id = HttpTtsRepository::new(db.connection())
                        .insert("test", "https://tts.test")?;
                    CacheRepository::new(db.connection()).put(
                        &format!("ttsSourceState_httpTts:{id}"),
                        r#"{"concurrentRate":"1/10000"}"#,
                        0,
                    )?;
                    Ok(())
                })
                .unwrap();
        }
        let id = one
            .storage()
            .with_database(|db| Ok(HttpTtsRepository::new(db.connection()).find_all()?[0].id))
            .unwrap();
        for key in [
            "book-key".to_string(),
            "rss-key".to_string(),
            format!("httpTts:{id}"),
        ] {
            one.rate_limiter().acquire_key(&key, "1/10000").await;
            let before = one
                .js_resources()
                .http_resources()
                .request_for(Some(&key))
                .policy()
                .unwrap();
            assert!(
                tokio::time::timeout(Duration::from_millis(25), before.acquire(false))
                    .await
                    .is_err()
            );
            tokio::time::timeout(Duration::from_millis(100), before.acquire(true))
                .await
                .unwrap();
        }
        let isolated = two
            .js_resources()
            .http_resources()
            .request_for(Some("book-key"))
            .policy()
            .unwrap();
        tokio::time::timeout(Duration::from_millis(100), isolated.acquire(false))
            .await
            .unwrap();
    }

    #[tokio::test]
    async fn replacement_registry_and_tts_override_apply_without_rebuilding_vm() {
        let engine = EngineContext::in_memory().unwrap();
        let vm = engine
            .js_resources()
            .create_engine(legado_js::SandboxConfig::default())
            .unwrap();
        let registry = Arc::new(RateLimiterRegistry::new());
        let engine = engine.with_rate_limiter(registry.clone());
        let id = engine
            .storage()
            .with_database(|db| {
                let id =
                    HttpTtsRepository::new(db.connection()).insert("test", "https://tts.test")?;
                db.connection()
                    .execute(
                        "UPDATE httpTTS SET concurrentRate='1/10000' WHERE id=?1",
                        [id],
                    )
                    .map_err(|e| LegadoError::Database(e.to_string()))?;
                Ok(id)
            })
            .unwrap();
        let key = format!("httpTts:{id}");
        registry.acquire_key(&key, "1/10000").await;
        let snapshot = vm
            .http_resources()
            .request_for(Some(&key))
            .policy()
            .unwrap();
        assert!(
            tokio::time::timeout(Duration::from_millis(25), snapshot.acquire(false))
                .await
                .is_err()
        );
        engine
            .storage()
            .with_database(|db| {
                CacheRepository::new(db.connection()).put(
                    &format!("ttsSourceState_{key}"),
                    r#"{"concurrentRate":"0"}"#,
                    0,
                )
            })
            .unwrap();
        let snapshot = vm
            .http_resources()
            .request_for(Some(&key))
            .policy()
            .unwrap();
        tokio::time::timeout(Duration::from_millis(100), snapshot.acquire(false))
            .await
            .unwrap();
    }

    #[test]
    fn database_failure_is_not_silently_treated_as_unlimited() {
        let engine = EngineContext::in_memory().unwrap();
        engine
            .storage()
            .with_database(|db| {
                db.connection()
                    .execute_batch("DROP TABLE caches")
                    .map_err(|e| LegadoError::Database(e.to_string()))
            })
            .unwrap();
        let request = engine.js_resources().http_resources().request_for(None);
        let Err(error) = request.policy() else {
            panic!("数据库失败被吞掉")
        };
        assert!(error.contains("caches"));
        assert_eq!(
            engine
                .js_resources()
                .create_engine(legado_js::SandboxConfig::default())
                .unwrap()
                .eval("1+1")
                .unwrap(),
            "2"
        );
    }
}
