use super::*;
use crate::{EngineContext, source_catalog::load_search_sources_selected_from};
use std::{sync::Arc, time::Duration};

fn source(url: &str, rate: &str) -> BookSource {
    serde_json::from_value(serde_json::json!({
        "bookSourceUrl": url, "bookSourceName": "完整书源", "enabled": true,
        "concurrentRate": rate, "header": "X-Source: yes", "jsLib": "const value = 1;",
        "variable": "私有变量", "ruleSearch": {"bookList": ".book", "name": ".name@text"},
        "ruleContent": {"content": ".body@text"}, "customOrder": -4,
        "loginUi": "[]", "enabledCookieJar": null
    }))
    .unwrap()
}

#[test]
fn entity_crud_and_catalog_preserve_fields_and_storage_identity() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = source("https://source.test/shared", "1/10000");
    let mut b = a.clone();
    b.book_source_name = "另一个实例".into();
    first
        .storage()
        .with_database(|db| {
            let service = BookSourceService::new(db);
            service
                .add_source(a.clone())?
                .publish(&first.rate_limiter());
            assert_eq!(
                serde_json::to_value(&service.list_sources()?[0]).unwrap(),
                serde_json::to_value(&a).unwrap()
            );
            service.set_source_variable(&a.book_source_url, "新变量")?;
            let changed = service.list_sources()?.remove(0);
            assert_eq!(changed.variable, "新变量");
            assert_eq!(changed.header, a.header);
            assert_eq!(changed.js_lib, a.js_lib);
            assert_eq!(
                serde_json::to_value(changed.rule_search).unwrap(),
                serde_json::to_value(&a.rule_search).unwrap()
            );
            service.set_source_enabled(&a.book_source_url, false)?;
            assert!(service.list_enabled_sources()?.is_empty());
            service.set_source_enabled(&a.book_source_url, true)?;
            assert!(matches!(
                service.set_source_variable("missing", "x"),
                Err(LegadoError::Internal(_))
            ));
            assert!(matches!(
                service.set_source_enabled("missing", true),
                Err(LegadoError::Database(_))
            ));
            Ok(())
        })
        .unwrap();
    second
        .storage()
        .with_database(|db| {
            let service = BookSourceService::new(db);
            assert!(service.list_sources()?.is_empty());
            service.add_source(b)?.publish(&second.rate_limiter());
            assert_eq!(service.list_sources()?[0].book_source_name, "另一个实例");
            Ok(())
        })
        .unwrap();
    let selected = load_search_sources_selected_from(
        Some(first.storage()),
        std::slice::from_ref(&a.book_source_url),
    )
    .unwrap();
    assert_eq!(selected.len(), 1);
    assert_eq!(selected[0].book_source_name, a.book_source_name);
    assert!(
        load_search_sources_selected_from(Some(first.storage()), &["missing".into()])
            .unwrap()
            .is_empty()
    );
    first
        .storage()
        .with_database(|db| BookSourceService::new(db).delete_source(&a.book_source_url))
        .unwrap();
    second
        .storage()
        .with_database(|db| {
            assert_eq!(BookSourceService::new(db).list_sources()?.len(), 1);
            Ok(())
        })
        .unwrap();
}

#[tokio::test]
async fn committed_write_publishes_only_to_the_requested_registry_without_retaining_root() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    let weak = Arc::downgrade(&first);
    let a = first.rate_limiter();
    let b = second.rate_limiter();
    let old = source("https://source.test/rate", "1/10000");
    first
        .storage()
        .with_database(|db| {
            BookSourceService::new(db)
                .add_source(old.clone())?
                .publish(&a);
            Ok(())
        })
        .unwrap();
    a.acquire(&old).await;
    b.acquire(&old).await;
    let mut updated = old.clone();
    updated.concurrent_rate = Some("3/10000".into());
    let pending = first
        .storage()
        .with_database(|db| BookSourceService::new(db).update_source(&updated))
        .unwrap();
    first
        .storage()
        .with_database(|db| {
            assert_eq!(
                BookSourceService::new(db).list_sources()?[0]
                    .concurrent_rate
                    .as_deref(),
                Some("3/10000")
            );
            Ok(())
        })
        .unwrap();
    assert!(
        tokio::time::timeout(Duration::from_millis(60), a.acquire(&old))
            .await
            .is_err()
    );
    drop(first);
    assert!(weak.upgrade().is_none());
    pending.publish(&a);
    assert!(
        tokio::time::timeout(Duration::from_millis(300), a.acquire(&old))
            .await
            .is_ok()
    );
    assert!(
        tokio::time::timeout(Duration::from_millis(60), b.acquire(&old))
            .await
            .is_err()
    );
}

#[tokio::test]
async fn typed_and_room_imports_keep_formats_and_rollback_before_rate_publication() {
    for room in [false, true] {
        let engine = EngineContext::in_memory().unwrap();
        let registry = engine.rate_limiter();
        let old = source("https://source.test/atomic", "1/10000");
        engine
            .storage()
            .with_database(|db| {
                BookSourceService::new(db)
                    .add_source(old.clone())?
                    .publish(&registry);
                Ok(())
            })
            .unwrap();
        registry.acquire(&old).await;
        let mut updated = old.clone();
        updated.concurrent_rate = Some("3/10000".into());
        let bad = source("https://source.test/fail", "3/10000");
        let room_value = serde_json::json!({
            "bookSourceUrl": old.book_source_url, "bookSourceName": "Room书源", "concurrentRate": "3/10000",
            "ruleSearch": r#"{"bookList":".room"}"#, "variable": "Room不消费此字段"
        });
        let bad_room =
            serde_json::json!({"bookSourceUrl": bad.book_source_url, "bookSourceName": "失败"});
        engine.storage().with_database(|db| {
            db.connection().execute_batch("CREATE TRIGGER reject_source BEFORE INSERT ON book_sources WHEN NEW.bookSourceUrl = 'https://source.test/fail' BEGIN SELECT RAISE(FAIL, 'source-write-denied'); END;").unwrap();
            let service = BookSourceService::new(db);
            if room {
                assert!(service.import_room_sources(RoomSourceImport::new(&[&room_value, &bad_room])?).is_err());
            } else {
                assert!(service.import_sources(&[updated.clone(), bad]).is_err());
            }
            let saved = service.list_sources()?;
            assert_eq!(saved.len(), 1);
            assert_eq!(serde_json::to_value(&saved[0]).unwrap(), serde_json::to_value(&old).unwrap());
            db.connection().execute_batch("DROP TRIGGER reject_source;").unwrap();
            Ok(())
        }).unwrap();
        assert!(
            tokio::time::timeout(Duration::from_millis(60), registry.acquire(&old))
                .await
                .is_err()
        );
        if room {
            let saved = engine
                .storage()
                .with_database(|db| {
                    BookSourceService::new(db)
                        .import_room_sources(RoomSourceImport::new(&[&room_value])?)
                })
                .unwrap();
            assert_eq!(saved.publish(&registry), 1);
        } else {
            let saved = engine
                .storage()
                .with_database(|db| BookSourceService::new(db).import_sources(&[updated.clone()]))
                .unwrap();
            assert_eq!(saved.publish(&registry), 1);
        }
        assert!(
            tokio::time::timeout(Duration::from_millis(300), registry.acquire(&old))
                .await
                .is_ok()
        );
        engine
            .storage()
            .with_database(|db| {
                let saved = BookSourceService::new(db).list_sources()?.remove(0);
                assert_eq!(saved.concurrent_rate.as_deref(), Some("3/10000"));
                if room {
                    assert_eq!(
                        saved.rule_search.unwrap().book_list.as_deref(),
                        Some(".room")
                    );
                    // [SOURCE-PARSE-UNIFY-20261022] Room 路径改走统一解析 +
                    // 全列写入：`variable` 不再被丢弃（旧 SQL 未含该列）。
                    assert_eq!(saved.variable, "Room不消费此字段");
                } else {
                    assert_eq!(saved.variable, old.variable);
                    assert_eq!(
                        serde_json::to_value(saved.rule_search).unwrap(),
                        serde_json::to_value(old.rule_search).unwrap()
                    );
                }
                Ok(())
            })
            .unwrap();
    }
}
