use super::*;
#[test]
fn test_extract_version() {
    assert_eq!(
        extract_version(r#"{"version": "1.2.3", "data": []}"#),
        Some("1.2.3".to_string())
    );
    assert_eq!(extract_version(r#"[{"a": 1}]"#), None);
    assert_eq!(extract_version("not json"), None);
}

#[test]
fn stores_keep_full_records_and_update_failures_in_their_own_connection() {
    let first = crate::EngineContext::in_memory().unwrap();
    let second = crate::EngineContext::in_memory().unwrap();
    let mut input = RuleSubRecord {
        id: 9999,
        url: "https://subscription.test/shared".into(),
        name: "完整配置".into(),
        sub_type: "rssSource".into(),
        last_update: 7,
        version: "v1".into(),
        is_enabled: false,
        created_at: 99,
        custom_order: -3,
        auto_update: true,
        update_interval: 12,
        silent_update: true,
        js: Some("脚本".into()),
        show_rule: Some("显示规则".into()),
        source_url: Some("源".into()),
    };
    first.storage().with_database(|db| {
        let service = RuleSubscriptionService::new(db);
        assert!(service.save_sub(&input)?);
        let saved = service.find_by_url(&input.url)?.unwrap();
        assert_ne!(saved.id, input.id);
        input.id = saved.id;
        assert_eq!(saved, input);
        assert!(service.enabled_subs()?.is_empty());
        assert!(service.set_sub_enabled(saved.id, true)?);
        assert_eq!(service.enabled_subs()?.len(), 1);
        input.is_enabled = true;
        input.name = "更新".into();
        service.save_sub(&input)?;
        assert_eq!(service.require_sub(saved.id)?, input);
        service.update_sub_order(&[saved.id])?;
        assert_eq!(service.require_sub(saved.id)?.custom_order, 0);
        let update = VersionUpdate { id: saved.id, version: "v2".into(), timestamp: 1234 };
        service.update_version(&update)?;
        assert_eq!(service.require_sub(saved.id)?.last_update, 1234);
        db.connection().execute_batch("CREATE TRIGGER deny_subscription_version BEFORE UPDATE OF version ON ruleSubs BEGIN SELECT RAISE(FAIL, 'subscription-write-denied'); END;").unwrap();
        assert!(service.update_version(&update).is_err());
        assert_eq!(service.require_sub(saved.id)?.version, "v2");
        assert!(!service.set_sub_enabled(9999, true)?);
        assert!(service.delete_sub(saved.id)?);
        assert!(!service.delete_sub(saved.id)?);
        assert!(service.require_sub(saved.id).is_err());
        Ok(())
    }).unwrap();
    second
        .storage()
        .with_database(|db| {
            let service = RuleSubscriptionService::new(db);
            assert!(service.list_subs()?.is_empty());
            service.save_sub(&input)?;
            assert_eq!(service.list_subs()?[0].version, "v1");
            Ok(())
        })
        .unwrap();
}

#[tokio::test]
async fn checks_and_preparation_keep_hosts_interval_results_and_failure_stages() {
    use crate::test_http_fixture::Fixture;
    let fixture = Fixture::new(5, false, |request| {
        if request.starts_with("GET /same ") {
            r#"{"version":"v1"}"#.into()
        } else if request.starts_with("GET /empty ") {
            String::new()
        } else if request.starts_with("GET /valid ") {
            r#"[{"name":"规则","pattern":"a"},{"name":"规则","pattern":"b"}]"#.into()
        } else {
            "not-json".into()
        }
    });
    let hosts = Arc::new(CustomHosts::default());
    hosts
        .apply_custom_hosts(r#"{"localhost":"127.0.0.1"}"#)
        .unwrap();
    let base = fixture.url.replace("127.0.0.1", "localhost");
    let sub = RuleSubRecord {
        id: 11,
        name: "测试".into(),
        sub_type: "replaceRule".into(),
        url: format!("{base}/same#requestWithoutUA"),
        last_update: now_millis(),
        update_interval: 12,
        version: "v1".into(),
        ..Default::default()
    };
    let checked = check_update_with_interval(&sub, hosts.clone()).await;
    assert!(!checked.due_for_update);
    assert!(!checked.has_update);
    assert_eq!(checked.remote_version.as_deref(), Some("v1"));
    assert!(checked.error.is_none());
    let invalid = RuleSubRecord {
        url: format!("{base}/invalid"),
        ..sub.clone()
    };
    assert!(check_update(&invalid, hosts.clone()).await.has_update);
    let empty = RuleSubRecord {
        url: format!("{base}/empty"),
        ..sub.clone()
    };
    assert!(!check_update(&empty, hosts.clone()).await.has_update);
    let valid = RuleSubRecord {
        url: format!("{base}/valid"),
        ..sub.clone()
    };
    let ready = prepare_update(&valid, hosts.clone()).await;
    let update = ready.version_update().unwrap();
    assert_eq!(update.id, sub.id);
    assert_eq!(update.version, "");
    assert!(update.timestamp >= sub.last_update);
    let result = ready.into_response(&valid);
    assert!(result.success);
    assert_eq!(
        (
            result.items_added,
            result.items_updated,
            result.items_removed,
            result.total_items
        ),
        (1, 0, 0, 1)
    );
    let failed = prepare_update(&invalid, hosts).await;
    assert!(matches!(&failed, PreparedUpdate::MergeFailed(_)));
    assert!(failed.version_update().is_none());
    let result = failed.into_response(&invalid);
    assert!(!result.success);
    assert!(result.error.unwrap().contains("解析远程 JSON 失败"));
    let wrong = Arc::new(CustomHosts::default());
    wrong
        .apply_custom_hosts(r#"{"localhost":"127.0.0.2"}"#)
        .unwrap();
    let result = check_update(&valid, wrong.clone()).await;
    assert!(!result.has_update);
    assert!(result.error.is_some());
    let failed = prepare_update(&valid, wrong).await;
    assert!(matches!(&failed, PreparedUpdate::FetchFailed(_)));
    assert!(
        failed
            .into_response(&valid)
            .error
            .unwrap()
            .starts_with("拉取订阅失败:")
    );
    let mut requests = fixture.requests;
    let request = requests.recv().await.unwrap().to_ascii_lowercase();
    assert!(request.starts_with("get /same http/1.1"));
    assert!(request.contains("user-agent: null"));
    fixture.worker.join().unwrap();
}
