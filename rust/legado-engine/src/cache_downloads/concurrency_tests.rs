//! 真实线程与SQLite断点测试；通道控制完成顺序，不以耗时猜测并发。— Codex + Bridge
use super::*;
use crate::EngineContext;
use legado_core::models::{Book, BookChapter};
use legado_db::repository::Repository;
use std::sync::mpsc;
use std::time::Instant;

fn seed(engine: &EngineContext, book: &str, count: i32, concurrency: &str) {
    engine
        .storage()
        .with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: book.into(),
                name: book.into(),
                ..Default::default()
            })?;
            BookChapterRepository::new(db.connection()).insert_batch(
                &(0..count)
                    .map(|index| BookChapter {
                        book_url: book.into(),
                        url: format!("{book}/{index}"),
                        index,
                        title: format!("第{index}章"),
                        ..Default::default()
                    })
                    .collect::<Vec<_>>(),
            )?;
            CacheRepository::new(db.connection()).put("config:cacheBookThreadCount", concurrency, 0)
        })
        .unwrap();
}

fn wait_until(mut ready: impl FnMut() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(5);
    while !ready() {
        assert!(Instant::now() < deadline, "等待线程状态超时");
        std::thread::sleep(Duration::from_millis(1));
    }
}

fn row(service: &CacheDownloads, id: u64) -> Checkpoint {
    service
        .storage
        .with_database(|db| {
            Ok(serde_json::from_str(
                &CacheRepository::new(db.connection())
                    .get(&format!("{PREFIX}{id}"))?
                    .unwrap(),
            )
            .unwrap())
        })
        .unwrap()
}

#[test]
fn unordered_completion_has_bounded_frontier_and_resumes_without_skipping_holes() {
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, "book", 5, "2");
    let (started, ready) = mpsc::channel();
    let mut releases = Vec::new();
    let gates: Vec<_> = (0..5)
        .map(|_| {
            let (release, gate) = mpsc::channel();
            releases.push(release);
            Mutex::new(gate)
        })
        .collect();
    let service = Arc::new(CacheDownloads::new(
        engine.storage().clone(),
        engine.tasks().clone(),
        Arc::new(move |_, index, _| {
            started.send(index).unwrap();
            gates[index as usize]
                .lock()
                .unwrap()
                .recv_timeout(Duration::from_secs(5))
                .unwrap();
            Ok(())
        }),
    ));
    let id = service.start("book", 0, 4).unwrap();
    let mut initial = vec![
        ready.recv_timeout(Duration::from_secs(5)).unwrap(),
        ready.recv_timeout(Duration::from_secs(5)).unwrap(),
    ];
    initial.sort();
    assert_eq!(initial, [0, 1]);
    assert_eq!(service.chapters("book", false).unwrap(), [0, 1]);
    releases[1].send(()).unwrap();
    wait_until(|| row(&service, id).completed == 1);
    let saved = row(&service, id);
    assert_eq!(saved.next_index, 0);
    assert_eq!(saved.processed_ahead, [1]);
    assert_eq!(service.chapters("book", false).unwrap(), [0]);
    assert!(ready.try_recv().is_err());

    // 将真实持久化快照复制至新引擎，模拟进程重启；第1章已完成但第0章仍须重做。
    let restarted = EngineContext::in_memory().unwrap();
    seed(&restarted, "book", 5, "2");
    restarted
        .storage()
        .with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            repo.put(INDEX, &format!("[{id}]"), 0)?;
            repo.put(&format!("{PREFIX}{id}"), &serde_json::to_string(&saved)?, 0)
        })
        .unwrap();
    let calls = Arc::new(Mutex::new(Vec::new()));
    let observed = calls.clone();
    let resumed = Arc::new(CacheDownloads::new(
        restarted.storage().clone(),
        restarted.tasks().clone(),
        Arc::new(move |_, index, _| {
            observed.lock().unwrap().push(index);
            Ok(())
        }),
    ));
    wait_until(|| resumed.progress(id).unwrap().status != "running");
    let mut calls = calls.lock().unwrap().clone();
    calls.sort();
    assert_eq!(calls, [0, 2, 3, 4]);
    assert_eq!(resumed.progress(id).unwrap().completed, 5);
    assert_eq!(row(&resumed, id).next_index, 5);
    assert!(row(&resumed, id).processed_ahead.is_empty());
    service.cancel(id).unwrap();
    releases[0].send(()).unwrap();
    wait_until(|| engine.tasks().active_count() == 0);
    assert_eq!(service.progress(id).unwrap().status, "cancelled");
    assert_eq!(service.progress(id).unwrap().completed, 1);
}

#[test]
fn fifo_shares_concurrency_snapshot_and_cancelled_queued_books_never_execute() {
    let engine = EngineContext::in_memory().unwrap();
    for book in ["first", "second", "third"] {
        seed(&engine, book, 3, "2");
    }
    let (started, ready) = mpsc::channel();
    let (release, gate) = mpsc::channel();
    let gate = Mutex::new(gate);
    let service = Arc::new(CacheDownloads::new(
        engine.storage().clone(),
        engine.tasks().clone(),
        Arc::new(move |book, index, _| {
            started.send((book.to_owned(), index)).unwrap();
            if book == "first" {
                gate.lock()
                    .unwrap()
                    .recv_timeout(Duration::from_secs(5))
                    .unwrap();
            }
            Ok(())
        }),
    ));
    let first = service.start("first", 0, 2).unwrap();
    for _ in 0..2 {
        assert_eq!(
            ready.recv_timeout(Duration::from_secs(5)).unwrap().0,
            "first"
        );
    }
    engine
        .storage()
        .with_database(|db| {
            CacheRepository::new(db.connection()).put("config:cacheBookThreadCount", "1", 0)
        })
        .unwrap();
    let second = service.start("second", 0, 2).unwrap();
    let third = service.start("third", 0, 2).unwrap();
    assert_eq!(service.state.lock().unwrap().records[&first].concurrency, 2);
    assert_eq!(
        service.state.lock().unwrap().records[&second].concurrency,
        1
    );
    assert!(service.chapters("second", false).unwrap().is_empty());
    service.cancel(second).unwrap();
    for _ in 0..3 {
        release.send(()).unwrap();
    }
    wait_until(|| service.progress(third).unwrap().status == "completed");
    wait_until(|| engine.tasks().active_count() == 0);
    let calls: Vec<_> = ready.try_iter().collect();
    assert!(calls.iter().all(|(book, _)| book != "second"));
    assert_eq!(calls.iter().filter(|(book, _)| book == "third").count(), 3);
    assert_eq!(service.progress(first).unwrap().completed, 3);
}

#[test]
fn ordinary_failures_continue_and_counters_equal_real_completed_attempts() {
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, "book", 10, "3");
    let service = Arc::new(CacheDownloads::new(
        engine.storage().clone(),
        engine.tasks().clone(),
        Arc::new(|_, index, _| {
            if index % 2 == 0 {
                Ok(())
            } else {
                Err(LegadoError::Network("失败夹具".into()))
            }
        }),
    ));
    let id = service.start("book", 0, 9).unwrap();
    wait_until(|| service.progress(id).unwrap().status != "running");
    let result = service.progress(id).unwrap();
    assert_eq!((result.completed, result.failed, result.total), (5, 5, 10));
    assert_eq!(service.chapters("book", true).unwrap(), [1, 3, 5, 7, 9]);
    assert!(service.chapters("book", false).unwrap().is_empty());
}

#[test]
fn configuration_is_bounded_and_read_errors_do_not_launch_fake_default_tasks() {
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, "book", 1, "1");
    let service = Arc::new(CacheDownloads::new(
        engine.storage().clone(),
        engine.tasks().clone(),
        Arc::new(|_, _, _| Ok(())),
    ));
    for (value, expected) in [
        ("1", 1),
        (" 3 ", 3),
        ("8", 8),
        ("16", 8),
        ("0", 8),
        ("-1", 8),
        ("bad", 8),
    ] {
        engine
            .storage()
            .with_database(|db| {
                CacheRepository::new(db.connection()).put("config:cacheBookThreadCount", value, 0)
            })
            .unwrap();
        assert_eq!(service.concurrency().unwrap(), expected);
    }
    service.restore().unwrap();
    engine
        .storage()
        .with_database(|db| {
            db.connection().execute_batch("DROP TABLE caches").unwrap();
            Ok(())
        })
        .unwrap();
    assert!(service.start("book", 0, 0).is_err());
    assert_eq!(engine.tasks().active_count(), 0);
}
