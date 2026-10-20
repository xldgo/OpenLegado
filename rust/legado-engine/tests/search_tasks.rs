use std::sync::Arc;
use std::time::Duration;

use legado_engine::{EngineContext, SearchTasks, TaskGroup, TaskScopeError};

#[test]
fn replacement_and_late_cleanup_are_owned_by_the_original_controller() {
    let tasks = TaskGroup::default();
    let first = Arc::new(SearchTasks::new(tasks.clone()));
    let other = Arc::new(SearchTasks::new(TaskGroup::default()));
    let a = first.start().unwrap();
    let independent = other.start().unwrap();
    let b = first.start().unwrap();
    assert!(a.is_cancelled());
    assert!(!independent.is_cancelled());
    assert_eq!(a.session_id, 1);
    assert_eq!(b.session_id, 2);
    assert_eq!(independent.session_id, 1);
    a.finish();
    assert!(b.is_current());
    assert!(independent.is_current());
    assert_eq!(a.with_current(|| panic!("旧会话不能发布")), None::<()>);
    assert_eq!(b.with_current(|| 42), Some(42));
    b.finish();
    assert!(first.current().is_none());
    assert!(independent.is_current());
    assert_eq!(tasks.active_count(), 2);
    drop(a);
    drop(b);
    assert_eq!(tasks.active_count(), 0);
}

#[tokio::test]
async fn shutdown_tracks_the_real_blocking_worker_after_the_collector_stops() {
    let engine = EngineContext::in_memory().unwrap();
    let tasks = engine.tasks().clone();
    let searches = Arc::new(SearchTasks::new(tasks.clone()));
    let session = searches.start().unwrap();
    let worker_task = session.task().clone();
    let (started, ready) = tokio::sync::oneshot::channel();
    let (release, wait) = std::sync::mpsc::channel();
    let worker = tokio::task::spawn_blocking(move || {
        let _task = worker_task;
        started.send(()).unwrap();
        wait.recv_timeout(Duration::from_secs(5)).unwrap();
    });
    ready.await.unwrap();
    session.cancel();
    session.finish();
    drop(session);
    assert!(!tasks.shutdown(Duration::from_millis(10)).await);
    assert_eq!(tasks.active_count(), 1);
    assert!(matches!(searches.start(), Err(TaskScopeError::Closed)));
    release.send(()).unwrap();
    worker.await.unwrap();
    assert!(tasks.shutdown(Duration::from_secs(1)).await);
}

#[tokio::test]
async fn root_drop_notifies_search_without_retaining_the_engine() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak = Arc::downgrade(&engine);
    let searches = Arc::new(SearchTasks::new(engine.tasks().clone()));
    let session = searches.start().unwrap();
    session.set_paused(true);
    drop(engine);
    assert!(weak.upgrade().is_none());
    tokio::time::timeout(Duration::from_secs(1), session.task().cancelled())
        .await
        .unwrap();
    assert!(
        session
            .with_current(|| panic!("根关闭后不能发布"))
            .is_none()
    );
    assert!(matches!(searches.start(), Err(TaskScopeError::Closed)));
}

#[test]
fn weak_slot_does_not_keep_finished_work_alive_or_cancel_siblings() {
    let tasks = TaskGroup::default();
    let sibling = tasks.begin().unwrap();
    let searches = Arc::new(SearchTasks::new(tasks.clone()));
    let first = searches.start().unwrap();
    drop(first);
    assert!(searches.current().is_none());
    assert_eq!(tasks.active_count(), 1);
    let second = searches.start().unwrap();
    drop(searches);
    assert!(second.is_cancelled());
    assert!(!sibling.is_cancelled());
    assert!(!tasks.is_closed());
}

#[test]
fn concurrent_starts_do_not_leave_a_live_replaced_session() {
    let searches = Arc::new(SearchTasks::new(TaskGroup::default()));
    let sessions = std::thread::scope(|scope| {
        let jobs: Vec<_> = (0..8)
            .map(|_| scope.spawn(|| searches.start().unwrap()))
            .collect();
        jobs.into_iter()
            .map(|job| job.join().unwrap())
            .collect::<Vec<_>>()
    });
    let current = searches.current().unwrap();
    for session in &sessions {
        if Arc::ptr_eq(session, &current) {
            assert!(!session.is_cancelled());
        } else {
            assert!(session.is_cancelled());
            session.finish();
        }
    }
    assert!(current.is_current());
}

#[test]
fn replacement_waits_for_entered_publication_without_holding_the_slot() {
    let searches = Arc::new(SearchTasks::new(TaskGroup::default()));
    let a = searches.start().unwrap();
    let (entered, ready) = std::sync::mpsc::channel();
    let (release, wait) = std::sync::mpsc::channel();
    std::thread::scope(|scope| {
        let publishing_session = a.clone();
        let publishing = scope.spawn(move || {
            publishing_session.with_current(|| {
                entered.send(()).unwrap();
                wait.recv_timeout(Duration::from_secs(5)).unwrap();
                assert!(
                    !publishing_session.is_current(),
                    "旧发布段内仍能读取槽位，不与替换者互锁"
                );
            })
        });
        ready.recv_timeout(Duration::from_secs(5)).unwrap();
        let (done, completed) = std::sync::mpsc::channel();
        let replacing_searches = searches.clone();
        let replacing = scope.spawn(move || {
            let b = replacing_searches.start().unwrap();
            done.send(()).unwrap();
            b
        });
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        while searches
            .current()
            .is_some_and(|current| Arc::ptr_eq(&a, &current))
        {
            assert!(std::time::Instant::now() < deadline, "替换者未发布新槽位");
            std::thread::yield_now();
        }
        assert!(
            completed.try_recv().is_err(),
            "旧发布未退出时替换入口不得报告结束"
        );
        release.send(()).unwrap();
        assert_eq!(publishing.join().unwrap(), Some(()));
        let b = replacing.join().unwrap();
        completed.recv_timeout(Duration::from_secs(5)).unwrap();
        assert!(b.is_current());
        assert!(
            a.with_current(|| panic!("替换后不得进入下一发布段"))
                .is_none()
        );
    });
}
