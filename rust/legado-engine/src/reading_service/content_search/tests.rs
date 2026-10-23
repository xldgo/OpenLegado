use super::*;
use crate::{EngineContext, test_http_fixture::Fixture};
use legado_db::{
    BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository,
    ReplaceRuleRepository, repository::Repository,
};
use std::sync::{Arc, Mutex};
use std::time::Duration;

fn seed(engine: &EngineContext, base: &str, count: usize) {
    engine
        .storage()
        .with_database(|db| {
            let source = serde_json::from_value(serde_json::json!({
                "bookSourceUrl": base, "bookSourceName":"正文搜索测试源",
                "ruleContent":{"content":".content@text"}
            }))?;
            BookSourceRepository::new(db.connection()).insert(&source)?;
            BookRepository::new(db.connection()).insert(&Book {
                book_url: "book".into(),
                origin: base.into(),
                name: "测试书".into(),
                ..Default::default()
            })?;
            BookChapterRepository::new(db.connection()).insert_batch(
                &(0..count)
                    .map(|i| BookChapter {
                        book_url: "book".into(),
                        url: format!("{base}/c{i}"),
                        title: format!("章{i}"),
                        index: i as i32,
                        ..Default::default()
                    })
                    .collect::<Vec<_>>(),
            )?;
            ReplaceRuleRepository::new(db.connection()).insert(&ReplaceRule {
                pattern: "关键词".into(),
                replacement: "净化词".into(),
                is_regex: false,
                ..Default::default()
            })?;
            Ok(())
        })
        .unwrap();
}
fn options(scope: ContentSearchScope) -> ContentSearchOptions {
    ContentSearchOptions {
        book_url: "book".into(),
        query: "关键词".into(),
        use_regex: false,
        use_replace: false,
        scope,
        current_chapter_index: 0,
    }
}
fn collect(service: &ReadingService, options: ContentSearchOptions) -> Vec<ContentSearchBatch> {
    let task = service.begin_content_search().unwrap();
    let _guard = task.guard();
    let mut batches = vec![];
    service
        .search_content(options, &task, |batch| {
            batches.push(batch);
            true
        })
        .unwrap();
    batches
}
#[test]
fn scopes_processing_progress_limits_and_local_files_use_real_content() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = EngineContext::in_memory().unwrap();
    let base = "https://cached.invalid";
    seed(&engine, base, 5);
    let service = super::super::tests::service(&engine, &runtime);
    for i in [0, 2] {
        assert!(save_chapter_cache(
            engine.storage(),
            "book",
            i,
            &format!("章{i}"),
            &format!("{base}/c{i}"),
            "关键词"
        ));
    }
    let cached = collect(&service, options(ContentSearchScope::Cached));
    assert_eq!(
        cached
            .iter()
            .filter_map(|b| b.chapter_index)
            .collect::<Vec<_>>(),
        vec![0, 2]
    );
    assert_eq!(
        cached.iter().map(|b| b.scanned).collect::<Vec<_>>(),
        vec![0, 1, 3]
    );
    assert!(cached.iter().all(|b| b.total == 5 && b.error.is_none()));
    assert_eq!(cached.iter().map(|b| b.hits.len()).sum::<usize>(), 2);
    let mut request = options(ContentSearchScope::Current);
    request.query = "净化词".into();
    request.use_replace = true;
    let processed = collect(&service, request);
    assert_eq!(processed[1].hits[0].snippet, "净化词");
    assert!(
        collect(
            &service,
            ContentSearchOptions {
                query: "净化词".into(),
                ..options(ContentSearchScope::Current)
            }
        )[1]
        .hits
        .is_empty()
    );
    // 回调模拟用户刚清掉缓存；非当前章不得改为联网。
    let task = service.begin_content_search().unwrap();
    let mut indices = vec![];
    service
        .search_content(options(ContentSearchScope::Cached), &task, |batch| {
            if batch.chapter_index == Some(0) {
                ChapterCacheService::new(Some(engine.storage().clone()))
                    .clear_chapter_cache("book", 2)
                    .unwrap();
            }
            if let Some(index) = batch.chapter_index {
                indices.push(index);
                if index == 2 {
                    assert!(batch.hits.is_empty() && batch.error.is_none());
                }
            }
            true
        })
        .unwrap();
    assert_eq!(indices, vec![0, 2]);
    for i in 0..5 {
        assert!(save_chapter_cache(
            engine.storage(),
            "book",
            i,
            &format!("章{i}"),
            &format!("{base}/c{i}"),
            &"关键词 ".repeat(60)
        ));
    }
    let limited = collect(&service, options(ContentSearchScope::Network));
    assert_eq!(limited.iter().map(|b| b.hits.len()).sum::<usize>(), 200);
    assert_eq!(limited.last().unwrap().chapter_index, Some(3));
    assert!(limited.last().unwrap().limit_reached);
    let invalid = collect(
        &service,
        ContentSearchOptions {
            book_url: "不存在".into(),
            query: "[".into(),
            use_regex: true,
            ..options(ContentSearchScope::Network)
        },
    );
    assert!(invalid.is_empty());
    let path =
        std::env::temp_dir().join(format!("legado-content-search-{}.txt", std::process::id()));
    std::fs::write(&path, "第一章 测试\n本地关键词\n").unwrap();
    engine
        .storage()
        .with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: path.to_string_lossy().into_owned(),
                name: "本地书".into(),
                ..Default::default()
            })
        })
        .unwrap();
    let local = collect(
        &service,
        ContentSearchOptions {
            book_url: path.to_string_lossy().into_owned(),
            ..options(ContentSearchScope::Network)
        },
    );
    std::fs::remove_file(path).unwrap();
    assert!(local.iter().any(|b| !b.hits.is_empty()));
}
#[test]
fn network_scans_extract_text_and_continue_after_one_chapter_error() {
    let mut fixture = Fixture::new(3, false, |request| {
        if request.starts_with("GET /c1 ") {
            "<div class='content'></div>".into()
        } else {
            "<div class='content'>真实关键词</div>".into()
        }
    });
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, &fixture.url, 3);
    let service = super::super::tests::service(&engine, &runtime);
    let batches = collect(&service, options(ContentSearchScope::Network));
    assert_eq!(
        batches
            .iter()
            .filter_map(|b| b.chapter_index)
            .collect::<Vec<_>>(),
        vec![0, 1, 2]
    );
    assert_eq!(batches.iter().map(|b| b.hits.len()).sum::<usize>(), 2);
    assert!(batches[2].error.is_some());
    assert!(batches[1].hits[0].snippet.contains("真实关键词"));
    for i in 0..3 {
        assert!(
            runtime
                .block_on(fixture.request())
                .starts_with(&format!("GET /c{i} "))
        );
    }
    fixture.worker.join().unwrap();
}
#[test]
fn cancelling_waiting_http_rejects_cache_and_events_without_cancelling_siblings() {
    let mut fixture = Fixture::new(1, true, |_| "<div class='content'>关键词</div>".into());
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, &fixture.url, 2);
    let service = super::super::tests::service(&engine, &runtime);
    let task = service.begin_content_search().unwrap();
    let sibling = service.begin_content_search().unwrap();
    let events = Arc::new(Mutex::new(Vec::new()));
    let output = events.clone();
    let worker_task = task.clone();
    let worker = std::thread::spawn(move || {
        let _guard = worker_task.guard();
        service.search_content(options(ContentSearchScope::Network), &worker_task, |b| {
            output.lock().unwrap().push(b);
            true
        })
    });
    assert!(runtime.block_on(fixture.request()).starts_with("GET /c0 "));
    task.cancel();
    let (finished, wait) = std::sync::mpsc::channel();
    std::thread::spawn(move || finished.send(worker.join().unwrap()).unwrap());
    wait.recv_timeout(Duration::from_secs(5))
        .expect("未等待HTTP响应就应结束取消")
        .unwrap();
    assert!(!sibling.is_cancelled());
    assert_eq!(
        events.lock().unwrap().len(),
        1,
        "只有初始进度，不发布取消章节"
    );
    engine
        .storage()
        .with_database(|db| {
            assert!(
                CacheBookRepository::new(db.connection())
                    .get_by_book_and_chapter_url("book", &format!("{}/c0", fixture.url))?
                    .is_none()
            );
            Ok(())
        })
        .unwrap();
    fixture.release.send(()).unwrap();
    fixture.worker.join().unwrap();
    assert_eq!(events.lock().unwrap().len(), 1);
}
