use super::*;
use std::sync::atomic::{AtomicUsize, Ordering};

fn service(
    engine: &crate::EngineContext,
    runtime: &tokio::runtime::Runtime,
    marker: &'static str,
    calls: Arc<AtomicUsize>,
) -> SourceSwitchService {
    use legado_db::repository::Repository;
    engine
        .storage()
        .with_database(|db| {
            legado_db::BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: "https://same-source.test".into(),
                book_source_name: "测试源".into(),
                enabled: true,
                ..Default::default()
            })
        })
        .unwrap();
    SourceSwitchService::new(SwitchResources {
        storage: Some(engine.storage().clone()),
        factory: None,
        state: Arc::new(SourceSwitchState::new(engine.tasks().clone())),
        network: engine.network().clone(),
        web_book: engine.web_book_state().clone(),
        js: engine.js_resources().clone(),
        runtime: runtime.handle().clone(),
        search: Arc::new(move |request| {
            calls.fetch_add(1, Ordering::SeqCst);
            Box::pin(async move {
                assert!(request.task.is_some());
                assert_eq!(request.keyword, "测试书");
                Ok(vec![SearchCandidate {
                    source_url: request.source.book_source_url,
                    source_name: request.source.book_source_name,
                    book_url: "https://same-source.test/book".into(),
                    book_name: "测试书".into(),
                    author: "作者".into(),
                    latest_chapter: Some(marker.into()),
                    word_count: None,
                    chapter_word_count_text: None,
                    chapter_word_count: -1,
                    respond_time: -1,
                    origin_order: 0,
                    book_score: 0,
                    variable: Some(marker.into()),
                }])
            })
        }),
    })
}

#[test]
fn isolated_services_reuse_their_own_records_and_scores_without_nested_pool_borrows() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = crate::EngineContext::in_memory().unwrap();
    let second = crate::EngineContext::in_memory().unwrap();
    let first_calls = Arc::new(AtomicUsize::new(0));
    let second_calls = Arc::new(AtomicUsize::new(0));
    let a = service(&first, &runtime, "甲", first_calls.clone());
    let b = service(&second, &runtime, "乙", second_calls.clone());
    for (base, marker) in [(&a, "甲"), (&b, "乙")] {
        let active = base.clone().start_search().unwrap();
        let _guard = active.operation().unwrap().guard();
        let result = active
            .search_alternative_sources_selected(
                "测试书",
                "作者",
                &[],
                SwitchSearchOptions::default(),
            )
            .unwrap();
        assert_eq!(result.matches[0].variable.as_deref(), Some(marker));
        let cached = active
            .search_alternative_sources_selected(
                "测试书",
                "作者",
                &[],
                SwitchSearchOptions::default(),
            )
            .unwrap();
        assert_eq!(cached.matches[0].variable.as_deref(), Some(marker));
    }
    assert_eq!(first_calls.load(Ordering::SeqCst), 1);
    assert_eq!(second_calls.load(Ordering::SeqCst), 1);
    a.update_search_book_score("https://same-source.test/book", 1)
        .unwrap();
    let read_score = |engine: &crate::EngineContext| {
        engine
            .storage()
            .with_database(|db| {
                Ok((
                    legado_db::SearchBookRepository::new(db.connection())
                        .find_by_book_url("https://same-source.test/book")?
                        .unwrap()
                        .book_score,
                    legado_db::CacheRepository::new(db.connection())
                        .get("config:https://same-source.test")?,
                ))
            })
            .unwrap()
    };
    assert_eq!(read_score(&first), (1, Some("1".into())));
    assert_eq!(read_score(&second), (0, None));
    b.delete_search_book("https://same-source.test/book")
        .unwrap();
    assert!(
        b.delete_search_book("https://same-source.test/book")
            .is_err()
    );
    assert_eq!(read_score(&first).0, 1);
}

#[test]
fn cancelling_one_service_and_dropping_its_engine_do_not_cancel_the_other() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = crate::EngineContext::in_memory().unwrap();
    let second = crate::EngineContext::in_memory().unwrap();
    let a = service(&first, &runtime, "甲", Arc::new(AtomicUsize::new(0)));
    let b = service(&second, &runtime, "乙", Arc::new(AtomicUsize::new(0)));
    let active_a = a.clone().start_apply().unwrap();
    let active_b = b.start_apply().unwrap();
    a.cancel_apply();
    assert!(active_a.ensure_active().is_err());
    assert!(active_b.ensure_active().is_ok());
    let next_a = a.start_apply().unwrap();
    assert!(next_a.ensure_active().is_ok());
    drop(first);
    assert!(next_a.ensure_active().is_err());
    assert!(active_b.ensure_active().is_ok());
}
