use super::*;
use crate::EngineContext;

fn service(
    engine: &EngineContext,
    runtime: &tokio::runtime::Runtime,
    name: &str,
) -> SourceCheckService {
    engine
        .storage()
        .with_database(|db| {
            BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: "https://same.test".into(),
                book_source_name: name.into(),
                enabled: false,
                ..Default::default()
            })
        })
        .unwrap();
    SourceCheckService::new(SourceCheckResources {
        storage: Some(engine.storage().clone()),
        network: engine.network().clone(),
        tasks: engine.tasks().clone(),
        slot: Arc::new(OperationSlot::new(engine.tasks().clone())),
        runtime: runtime.handle().clone(),
    })
}

#[test]
fn disabled_and_missing_sources_keep_order_and_cancellation_is_instance_local() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = service(&first, &runtime, "甲");
    let b = service(&second, &runtime, "乙");
    for (base, name) in [(&a, "甲"), (&b, "乙")] {
        let mut events = Vec::new();
        runtime.block_on(base.run_check_sources_selected(
            vec!["https://same.test".into(), "https://missing.test".into()],
            CheckerConfig::default(),
            |event| {
                events.push(event);
                Ok(())
            },
        ));
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].source_name, name);
        assert_eq!(
            (events[0].index, events[0].total, events[0].is_last),
            (0, 2, false)
        );
        assert_eq!(events[1].result.search_error.as_deref(), Some("书源不存在"));
        assert!(events[1].is_last);
    }
    let current_a = a.resources.slot.start().unwrap();
    let current_b = b.resources.slot.start().unwrap();
    a.cancel_check_sources();
    assert!(!current_a.is_active());
    assert!(current_b.is_active());
    let mut count = 0;
    runtime.block_on(a.run_check_sources_selected(
        vec!["https://same.test".into(), "https://missing.test".into()],
        CheckerConfig::default(),
        |_| {
            count += 1;
            Err("已关闭".into())
        },
    ));
    assert_eq!(count, 1);
    assert!(current_b.is_active());
    drop(first);
    assert!(
        a.check_source_entity(BookSource::default(), CheckerConfig::default())
            .is_err()
    );
    assert!(
        b.check_source_entity(BookSource::default(), CheckerConfig::default())
            .is_ok()
    );
}
