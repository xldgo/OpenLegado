//! 任务生命周期测试只装配实例能力，不使用进程根或外部服务。
use legado_engine::{EngineContext, TaskGroup, TaskScopeError};
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};
use std::time::{Duration, Instant};

#[test]
fn child_and_single_task_cancel_do_not_cancel_siblings_or_another_engine() {
    let root = TaskGroup::default();
    let one = root.child().unwrap();
    let descendant = one.child().unwrap();
    let sibling = root.child().unwrap();
    let other = TaskGroup::default();
    let a = one.begin().unwrap();
    let b = descendant.begin().unwrap();
    let c = sibling.begin().unwrap();
    let d = other.begin().unwrap();
    a.cancel();
    assert!(a.is_cancelled());
    assert!(!b.is_cancelled());
    assert!(!one.is_closed());
    one.cancel();
    assert!(b.is_cancelled());
    assert!(descendant.is_closed());
    assert!(matches!(descendant.begin(), Err(TaskScopeError::Closed)));
    assert!(!c.is_cancelled());
    assert!(!d.is_cancelled());
    assert!(!root.is_closed());
    root.cancel();
    assert!(c.is_cancelled());
    assert!(!d.is_cancelled());
    assert!(root.child().is_err());
}

#[tokio::test]
async fn timeout_keeps_registration_until_the_last_clone_releases_it() {
    let root = TaskGroup::default();
    let child = root.child().unwrap();
    let task = child.begin().unwrap();
    let blocking = task.clone();
    let flag = task.cancellation_flag();
    drop(task);
    assert_eq!(root.active_count(), 1);
    assert!(!root.shutdown(Duration::from_millis(10)).await);
    assert!(flag.load(Ordering::Acquire));
    assert_eq!(root.active_count(), 1);
    assert!(child.begin().is_err());
    drop(blocking);
    assert_eq!(root.active_count(), 0);
    assert!(root.shutdown(Duration::from_secs(1)).await);
    assert!(root.shutdown(Duration::from_secs(1)).await);
}

#[test]
fn cancel_drains_entered_publication_and_rejects_every_later_publication() {
    let root = TaskGroup::default();
    let task = root.begin().unwrap();
    let published = Arc::new(AtomicUsize::new(0));
    let (started_tx, started_rx) = std::sync::mpsc::channel();
    let (release_tx, release_rx) = std::sync::mpsc::channel();
    let worker = task.clone();
    let count = published.clone();
    let publisher = std::thread::spawn(move || {
        worker.with_active(|| {
            started_tx.send(()).unwrap();
            release_rx.recv_timeout(Duration::from_secs(3)).unwrap();
            count.fetch_add(1, Ordering::SeqCst);
        })
    });
    started_rx.recv_timeout(Duration::from_secs(3)).unwrap();
    let cancelling = root.clone();
    let (closed_tx, closed_rx) = std::sync::mpsc::channel();
    let closer = std::thread::spawn(move || {
        cancelling.cancel();
        closed_tx.send(()).unwrap();
    });
    assert!(closed_rx.recv_timeout(Duration::from_millis(20)).is_err());
    release_tx.send(()).unwrap();
    assert_eq!(publisher.join().unwrap(), Some(()));
    closed_rx.recv_timeout(Duration::from_secs(3)).unwrap();
    closer.join().unwrap();
    assert!(
        task.with_active(|| published.fetch_add(1, Ordering::SeqCst))
            .is_none()
    );
    assert_eq!(published.load(Ordering::SeqCst), 1);
    assert!(task.cancellation_flag().load(Ordering::Acquire));
}

#[tokio::test(flavor = "current_thread")]
async fn async_shutdown_does_not_block_the_runtime_on_a_publication_lock() {
    let root = TaskGroup::default();
    let task = root.begin().unwrap();
    let (started_tx, started_rx) = std::sync::mpsc::channel();
    let (release_tx, release_rx) = std::sync::mpsc::channel();
    let worker = task.clone();
    let publisher = std::thread::spawn(move || {
        worker.with_active(|| {
            started_tx.send(()).unwrap();
            release_rx.recv_timeout(Duration::from_secs(3)).unwrap();
        })
    });
    started_rx.recv_timeout(Duration::from_secs(3)).unwrap();
    let start = Instant::now();
    assert!(!root.shutdown(Duration::from_millis(20)).await);
    assert!(
        start.elapsed() < Duration::from_secs(1),
        "异步关闭不应同步等待仍被占用的发布锁"
    );
    release_tx.send(()).unwrap();
    publisher.join().unwrap();
    drop(task);
    assert!(root.shutdown(Duration::from_secs(1)).await);
}

#[tokio::test]
async fn cancellation_wakes_waiters_and_successful_shutdown_waits_for_completion() {
    let root = TaskGroup::default();
    let task = root.begin().unwrap();
    let waiting = task.clone();
    let waiter = tokio::spawn(async move {
        waiting.cancelled().await;
    });
    task.cancel();
    drop(task);
    tokio::time::timeout(Duration::from_secs(1), waiter)
        .await
        .unwrap()
        .unwrap();
    assert!(root.shutdown(Duration::from_secs(1)).await);
}

#[tokio::test]
async fn child_shutdown_waits_only_for_its_own_tasks() {
    let root = TaskGroup::default();
    let child = root.child().unwrap();
    let child_task = child.begin().unwrap();
    let sibling = root.begin().unwrap();
    drop(child_task);
    assert!(child.shutdown(Duration::from_secs(1)).await);
    assert_eq!(root.active_count(), 1);
    assert!(!sibling.is_cancelled());
    drop(sibling);
    assert!(root.shutdown(Duration::from_secs(1)).await);
}

#[test]
fn engine_drop_signals_tasks_without_retaining_the_root_context() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak = Arc::downgrade(&engine);
    let group = engine.tasks().clone();
    let task = group.begin().unwrap();
    assert!(!task.is_cancelled());
    drop(engine);
    assert!(weak.upgrade().is_none());
    assert!(task.is_cancelled());
    assert!(group.begin().is_err());
}

#[test]
fn concurrent_registration_drop_and_snapshots_do_not_keep_registry_locked() {
    let root = TaskGroup::default();
    std::thread::scope(|threads| {
        for _ in 0..4 {
            let group = &root;
            threads.spawn(move || {
                for _ in 0..300 {
                    let task = group.begin().unwrap();
                    let copy = task.clone();
                    drop(task);
                    drop(copy);
                }
            });
        }
        for _ in 0..2 {
            let group = &root;
            threads.spawn(move || {
                for _ in 0..600 {
                    group.active_count();
                }
            });
        }
    });
    assert_eq!(root.active_count(), 0);
}

#[tokio::test]
async fn entry_guard_cancels_only_its_task_and_keeps_worker_clones_registered() {
    let tasks = TaskGroup::default();
    let worker = tasks.begin().unwrap();
    let sibling = tasks.begin().unwrap();
    let guard = worker.guard();
    drop(guard);
    assert!(worker.is_cancelled());
    assert!(!sibling.is_cancelled());
    assert!(!tasks.is_closed());
    assert_eq!(tasks.active_count(), 2);
    assert!(
        worker
            .with_active(|| panic!("已结束入口不能发布"))
            .is_none()
    );
    drop(sibling);
    assert!(!tasks.shutdown(Duration::from_millis(10)).await);
    drop(worker);
    assert!(tasks.shutdown(Duration::from_secs(1)).await);
}
