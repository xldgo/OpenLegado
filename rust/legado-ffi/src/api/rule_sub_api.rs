//! 规则订阅宿主适配：连接与运行时装配、严格版本回写及原类型重导出。
use crate::db_state::with_database;
use legado_core::LegadoResult;
use legado_db::RuleSubRecord;
use legado_engine::rule_subscription_service::{self as service, RuleSubscriptionService};
pub use legado_engine::rule_subscription_service::{ApplyUpdateResponse, CheckUpdateResponse};

pub fn list_subs_db() -> LegadoResult<Vec<RuleSubRecord>> {
    with_database(|db| RuleSubscriptionService::new(db).list_subs())
}
pub fn save_sub_db(record: &RuleSubRecord) -> LegadoResult<bool> {
    with_database(|db| RuleSubscriptionService::new(db).save_sub(record))
}
pub fn delete_sub_db(id: i64) -> LegadoResult<bool> {
    with_database(|db| RuleSubscriptionService::new(db).delete_sub(id))
}
pub fn set_sub_enabled_db(id: i64, enabled: bool) -> LegadoResult<bool> {
    with_database(|db| RuleSubscriptionService::new(db).set_sub_enabled(id, enabled))
}
pub fn update_sub_order_db(ids: &[i64]) -> LegadoResult<bool> {
    with_database(|db| RuleSubscriptionService::new(db).update_sub_order(ids))
}
pub fn check_sub_update_db(id: i64) -> LegadoResult<CheckUpdateResponse> {
    let sub = with_database(|db| RuleSubscriptionService::new(db).require_sub(id))?;
    Ok(crate::runtime::block_on(
        service::check_update_with_interval(
            &sub,
            crate::engine_holder::network().custom_hosts().clone(),
        ),
    ))
}
pub fn apply_sub_update_db(id: i64) -> LegadoResult<ApplyUpdateResponse> {
    let sub = with_database(|db| RuleSubscriptionService::new(db).require_sub(id))?;
    let prepared = crate::runtime::block_on(service::prepare_update(
        &sub,
        crate::engine_holder::network().custom_hosts().clone(),
    ));
    if let Some(update) = prepared.version_update() {
        with_database(|db| RuleSubscriptionService::new(db).update_version(update))?;
    }
    Ok(prepared.into_response(&sub))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rule_sub_crud_db() {
        let _db_guard = crate::db_state::ensure_test_db();

        let record = RuleSubRecord {
            url: "https://example.com/ffi_crud.json".to_string(),
            name: "FFI订阅".to_string(),
            sub_type: "bookSource".to_string(),
            created_at: 1700000000000,
            auto_update: true,
            update_interval: 12,
            ..RuleSubRecord::default()
        };

        // Save（新增）
        assert!(save_sub_db(&record).unwrap());
        let inserted = list_subs_db()
            .unwrap()
            .into_iter()
            .find(|r| r.url == "https://example.com/ffi_crud.json")
            .unwrap();
        assert!(inserted.id > 0);
        assert!(inserted.auto_update);
        assert_eq!(inserted.update_interval, 12);

        // Save（更新）
        let mut updated = inserted.clone();
        updated.name = "FFI订阅-改".to_string();
        updated.silent_update = true;
        assert!(save_sub_db(&updated).unwrap());
        let after = list_subs_db()
            .unwrap()
            .into_iter()
            .find(|r| r.id == inserted.id)
            .unwrap();
        assert_eq!(after.name, "FFI订阅-改");
        assert!(after.silent_update);

        // SetEnabled
        assert!(set_sub_enabled_db(inserted.id, false).unwrap());
        let disabled = list_subs_db()
            .unwrap()
            .into_iter()
            .find(|r| r.id == inserted.id)
            .unwrap();
        assert!(!disabled.is_enabled);
        assert!(!set_sub_enabled_db(999_999_999, true).unwrap());

        // Delete
        assert!(delete_sub_db(inserted.id).unwrap());
        assert!(!delete_sub_db(inserted.id).unwrap());
    }

    #[test]
    fn test_rule_sub_update_order_db() {
        let _db_guard = crate::db_state::ensure_test_db();

        let mut ids = Vec::new();
        for i in 0..3 {
            let record = RuleSubRecord {
                url: format!("https://example.com/ffi_order_{i}.json"),
                name: format!("排序{i}"),
                created_at: 1700000000000,
                ..RuleSubRecord::default()
            };
            save_sub_db(&record).unwrap();
            let inserted = list_subs_db()
                .unwrap()
                .into_iter()
                .find(|r| r.url == record.url)
                .unwrap();
            ids.push(inserted.id);
        }

        // 反序拖拽
        ids.reverse();
        assert!(update_sub_order_db(&ids).unwrap());

        let all = list_subs_db().unwrap();
        let pos = |id: i64| all.iter().position(|r| r.id == id).unwrap();
        // ids[0] 应排在最前（按 custom_order）
        assert!(pos(ids[0]) < pos(ids[1]));
        assert!(pos(ids[1]) < pos(ids[2]));

        // 清理
        for id in &ids {
            delete_sub_db(*id).unwrap();
        }
    }

    #[test]
    fn test_check_sub_update_not_found() {
        let _db_guard = crate::db_state::ensure_test_db();
        let err = check_sub_update_db(999_999_999).unwrap_err();
        assert!(err.to_string().contains("未找到"));
    }

    #[test]
    fn test_apply_sub_update_not_found() {
        let _db_guard = crate::db_state::ensure_test_db();
        let err = apply_sub_update_db(999_999_999).unwrap_err();
        assert!(err.to_string().contains("未找到"));
    }

    #[test]
    fn test_check_sub_update_unreachable_url() {
        // 无效 URL：网络错误应体现在 error 字段而非抛出
        let _db_guard = crate::db_state::ensure_test_db();
        let record = RuleSubRecord {
            url: "http://127.0.0.1:1/nonexistent.json".to_string(),
            name: "不可达订阅".to_string(),
            created_at: 1700000000000,
            ..RuleSubRecord::default()
        };
        save_sub_db(&record).unwrap();
        let inserted = list_subs_db()
            .unwrap()
            .into_iter()
            .find(|r| r.url == record.url)
            .unwrap();

        let resp = check_sub_update_db(inserted.id).unwrap();
        assert!(!resp.has_update);
        assert!(resp.error.is_some());

        let apply = apply_sub_update_db(inserted.id).unwrap();
        assert!(!apply.success);
        assert!(apply.error.is_some());

        delete_sub_db(inserted.id).unwrap();
    }

    #[test]
    fn test_response_serialization() {
        let check = CheckUpdateResponse {
            id: 1,
            url: "u".into(),
            name: "n".into(),
            due_for_update: true,
            has_update: false,
            remote_version: Some("1.0".into()),
            error: None,
        };
        let json = serde_json::to_string(&check).unwrap();
        assert!(json.contains("dueForUpdate"));
        assert!(json.contains("hasUpdate"));
        assert!(json.contains("remoteVersion"));

        let apply = ApplyUpdateResponse {
            id: 1,
            url: "u".into(),
            success: true,
            items_added: 2,
            items_updated: 1,
            items_removed: 0,
            total_items: 3,
            error: None,
        };
        let json = serde_json::to_string(&apply).unwrap();
        assert!(json.contains("itemsAdded"));
        assert!(json.contains("totalItems"));
    }
    #[test]
    fn apply_update_keeps_strict_database_write_failure() {
        use std::{
            io::{Read, Write},
            net::TcpListener,
            time::Duration,
        };
        // DDL故障注入排除共享网络Cookie写入，按既有store→pool→DB锁序执行。
        let _store = crate::test_support::lock_global_store();
        let _pool = crate::test_support::lock_pool_tests();
        let _guard = crate::db_state::ensure_test_db();
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/strict", listener.local_addr().unwrap());
        let worker = std::thread::spawn(move || {
            let (mut socket, _) = listener.accept().unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            let mut byte = [0];
            while !request.ends_with(b"\r\n\r\n") {
                socket.read_exact(&mut byte).unwrap();
                request.push(byte[0]);
                assert!(request.len() < 16384);
            }
            let body = r#"[{"name":"规则"}]"#;
            write!(
                socket,
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            )
            .unwrap();
        });
        save_sub_db(&RuleSubRecord {
            url: url.clone(),
            version: "before".into(),
            sub_type: "replaceRule".into(),
            ..Default::default()
        })
        .unwrap();
        let saved = list_subs_db()
            .unwrap()
            .into_iter()
            .find(|r| r.url == url)
            .unwrap();
        with_database(|db| {
            db.connection().execute_batch("CREATE TRIGGER deny_ffi_subscription_version BEFORE UPDATE OF version ON ruleSubs BEGIN SELECT RAISE(FAIL, 'strict-subscription-write'); END;").unwrap();
            Ok(())
        }).unwrap();
        let result = apply_sub_update_db(saved.id);
        // 先清理触发器，再断言，避免失败污染同进程其他测试。
        with_database(|db| {
            db.connection()
                .execute_batch("DROP TRIGGER deny_ffi_subscription_version;")
                .unwrap();
            Ok(())
        })
        .unwrap();
        worker.join().unwrap();
        assert!(
            result
                .unwrap_err()
                .to_string()
                .contains("strict-subscription-write")
        );
        let after = list_subs_db()
            .unwrap()
            .into_iter()
            .find(|r| r.id == saved.id)
            .unwrap();
        assert_eq!(after.version, "before");
        delete_sub_db(saved.id).unwrap();
    }
}
