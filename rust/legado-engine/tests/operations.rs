use legado_engine::{EngineContext, OperationSlot, TaskGroup};
use std::sync::{Arc, Barrier};
use std::time::Duration;

#[test]
fn replacement_cleanup_and_cancellation_stay_in_the_original_slot() {
    let tasks = TaskGroup::default();
    let checks = Arc::new(OperationSlot::new(tasks.clone()));
    let debug = Arc::new(OperationSlot::new(tasks.clone()));
    let other = Arc::new(OperationSlot::new(TaskGroup::default()));
    let old = checks.start().unwrap();
    let debug_run = debug.start().unwrap();
    let independent = other.start().unwrap();
    let new = checks.start().unwrap();
    old.finish();
    assert!(old.publish(|| panic!("旧任务不能发布")).is_none());
    assert!(new.is_active() && debug_run.is_active() && independent.is_active());
    checks.cancel();
    assert!(!new.is_active());
    assert!(debug_run.is_active() && independent.is_active());
    drop(checks);
    assert_eq!(tasks.active_count(), 3);
    drop(old);
    drop(new);
    drop(debug_run);
    assert_eq!(tasks.active_count(), 0);
}

#[test]
fn cancellation_waits_for_entered_publication_without_holding_the_slot_lock() {
    let slot = Arc::new(OperationSlot::new(TaskGroup::default()));
    let operation = slot.start().unwrap();
    let entered = Arc::new(Barrier::new(2));
    let release = Arc::new(Barrier::new(2));
    std::thread::scope(|scope| {
        scope.spawn(|| {
            operation.publish(|| {
                entered.wait();
                release.wait();
                assert!(slot.current().is_some());
            })
        });
        entered.wait();
        let (done, wait) = std::sync::mpsc::channel();
        let cancelling = slot.clone();
        scope.spawn(move || {
            cancelling.cancel();
            done.send(()).unwrap();
        });
        let deadline = std::time::Instant::now() + Duration::from_secs(2);
        while !operation.task().is_cancelled() {
            assert!(std::time::Instant::now() < deadline);
            std::thread::yield_now();
        }
        assert!(matches!(
            wait.try_recv(),
            Err(std::sync::mpsc::TryRecvError::Empty)
        ));
        release.wait();
        wait.recv_timeout(Duration::from_secs(2)).unwrap();
    });
    assert!(operation.publish(|| 1).is_none());
}

#[tokio::test]
async fn abandoned_collector_keeps_real_worker_registered_without_root_cycle() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak = Arc::downgrade(&engine);
    let tasks = engine.tasks().clone();
    let slot = Arc::new(OperationSlot::new(tasks.clone()));
    let operation = slot.start().unwrap();
    let guard = operation.guard();
    let worker_permit = operation.task().clone();
    drop(guard);
    drop(operation);
    drop(engine);
    assert!(weak.upgrade().is_none());
    assert!(slot.current().is_none());
    assert!(!tasks.shutdown(Duration::from_millis(10)).await);
    assert!(slot.start().is_err());
    drop(worker_permit);
    assert!(tasks.shutdown(Duration::from_secs(1)).await);
}

#[test]
fn concurrent_replacement_and_slot_drop_do_not_keep_operations_alive() {
    let tasks = TaskGroup::default();
    let slot = Arc::new(OperationSlot::new(tasks.clone()));
    let operations = std::thread::scope(|scope| {
        let workers: Vec<_> = (0..8)
            .map(|_| scope.spawn(|| slot.start().unwrap()))
            .collect();
        workers
            .into_iter()
            .map(|worker| worker.join().unwrap())
            .collect::<Vec<_>>()
    });
    assert_eq!(
        operations
            .iter()
            .filter(|operation| operation.is_active())
            .count(),
        1
    );
    drop(slot);
    assert!(operations.iter().all(|operation| !operation.is_active()));
    assert!(!tasks.is_closed());
    drop(operations);
    assert_eq!(tasks.active_count(), 0);
}
