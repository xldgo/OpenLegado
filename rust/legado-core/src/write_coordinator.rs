//! Cookie 实例写通道：闭包限定守卫生命周期，不泄漏 Arc 或伪造静态引用。

use std::collections::HashMap;
use std::sync::{Arc, Mutex, RwLock, Weak};

/// 逐域操作持屏障读锁，全量操作持写锁；域索引不拥有锁对象。
///
/// 锁序固定为屏障→索引（短暂）→排序后的域锁→存储/持久化。
/// 临界区只能做同步工作，不得再次进入本协调器。
#[derive(Debug, Default)]
pub struct KeyedWriteCoordinator {
    barrier: RwLock<()>,
    domains: Mutex<HashMap<String, Weak<Mutex<()>>>>,
}

impl KeyedWriteCoordinator {
    pub fn with_domain<T>(&self, domain: &str, operation: impl FnOnce() -> T) -> T {
        self.with_domains(&[domain], operation)
    }

    /// 多域删除去重排序，不能因调用方重复传入同一键而自锁。
    pub fn with_domains<T>(&self, domains: &[&str], operation: impl FnOnce() -> T) -> T {
        let _barrier = self.barrier.read().unwrap_or_else(|p| p.into_inner());
        let mut keys = domains.to_vec();
        keys.sort_unstable();
        keys.dedup();
        let locks: Vec<_> = {
            let mut index = self.domains.lock().unwrap_or_else(|p| p.into_inner());
            // 清理过期弱键，避免病态输入令索引永久增长；在途操作持 Arc，不会被逐出。
            if index.len() >= 64 {
                index.retain(|_, entry| entry.strong_count() != 0);
            }
            keys.into_iter()
                .map(|domain| {
                    if let Some(lock) = index.get(domain).and_then(Weak::upgrade) {
                        lock
                    } else {
                        let lock = Arc::new(Mutex::new(()));
                        index.insert(domain.to_string(), Arc::downgrade(&lock));
                        lock
                    }
                })
                .collect()
        };
        // locks 在所有守卫之后销毁；守卫引用始终指向本作用域持有的 Arc。
        let _guards: Vec<_> = locks
            .iter()
            .map(|lock| lock.lock().unwrap_or_else(|p| p.into_inner()))
            .collect();
        operation()
    }

    /// 屏障覆盖未知域；不依赖“先快照全部域”的易错窗口。
    pub fn with_all<T>(&self, operation: impl FnOnce() -> T) -> T {
        let _barrier = self.barrier.write().unwrap_or_else(|p| p.into_inner());
        operation()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Barrier, mpsc};
    use std::time::Duration;

    #[test]
    fn same_domain_read_modify_write_keeps_all_changes() {
        let writes = Arc::new(KeyedWriteCoordinator::default());
        let values = Arc::new(Mutex::new(Vec::new()));
        let start = Arc::new(Barrier::new(17));
        let threads: Vec<_> = (0..16)
            .map(|value| {
                let writes = writes.clone();
                let values = values.clone();
                let start = start.clone();
                std::thread::spawn(move || {
                    start.wait();
                    writes.with_domain("same", || {
                        let mut next = values.lock().unwrap().clone();
                        std::thread::yield_now();
                        next.push(value);
                        *values.lock().unwrap() = next;
                    });
                })
            })
            .collect();
        start.wait();
        for thread in threads {
            thread.join().unwrap();
        }
        let mut actual = values.lock().unwrap().clone();
        actual.sort_unstable();
        assert_eq!(actual, (0..16).collect::<Vec<_>>());
    }

    #[test]
    fn different_domains_and_independent_instances_do_not_block_each_other() {
        let writes = Arc::new(KeyedWriteCoordinator::default());
        let independent = Arc::new(KeyedWriteCoordinator::default());
        let (entered, ready) = mpsc::channel();
        let (release, wait) = mpsc::channel();
        let held = writes.clone();
        let thread = std::thread::spawn(move || {
            held.with_domain("one", || {
                entered.send(()).unwrap();
                wait.recv_timeout(Duration::from_secs(3)).unwrap();
            })
        });
        ready.recv_timeout(Duration::from_secs(3)).unwrap();
        let (done, result) = mpsc::channel();
        let other = std::thread::spawn(move || {
            writes.with_domain("two", || {
                independent.with_domain("one", || done.send(()).unwrap())
            });
        });
        let finished = result.recv_timeout(Duration::from_secs(2));
        release.send(()).unwrap();
        thread.join().unwrap();
        other.join().unwrap();
        finished.unwrap();
    }

    #[test]
    fn full_barrier_blocks_even_previously_unknown_domain() {
        let writes = Arc::new(KeyedWriteCoordinator::default());
        let (entered, ready) = mpsc::channel();
        let (release, wait) = mpsc::channel();
        let held = writes.clone();
        let thread = std::thread::spawn(move || {
            held.with_all(|| {
                entered.send(()).unwrap();
                wait.recv_timeout(Duration::from_secs(3)).unwrap();
            })
        });
        ready.recv_timeout(Duration::from_secs(3)).unwrap();
        let (attempt, attempted) = mpsc::channel();
        let (done, result) = mpsc::channel();
        let writer = std::thread::spawn(move || {
            attempt.send(()).unwrap();
            writes.with_domain("new-domain", || done.send(()).unwrap());
        });
        attempted.recv_timeout(Duration::from_secs(3)).unwrap();
        assert!(matches!(
            result.recv_timeout(Duration::from_millis(50)),
            Err(mpsc::RecvTimeoutError::Timeout)
        ));
        release.send(()).unwrap();
        result.recv_timeout(Duration::from_secs(3)).unwrap();
        thread.join().unwrap();
        writer.join().unwrap();
    }

    #[test]
    fn duplicate_domains_finish_and_unused_locks_are_reclaimed() {
        let writes = KeyedWriteCoordinator::default();
        let mut weak = None;
        writes.with_domains(&["z", "a", "z"], || {
            weak = writes.domains.lock().unwrap().get("z").cloned();
        });
        assert!(weak.unwrap().upgrade().is_none());
        for index in 0..1000 {
            writes.with_domain(&index.to_string(), || {});
        }
        assert!(writes.domains.lock().unwrap().len() <= 64);
        let weak = Arc::downgrade(&Arc::new(writes));
        assert!(weak.upgrade().is_none());
    }

    #[test]
    fn panic_releases_poisoned_locks_for_later_operations() {
        let writes = KeyedWriteCoordinator::default();
        assert!(
            std::panic::catch_unwind(|| writes.with_domain("domain", || panic!("夹具中断")))
                .is_err()
        );
        assert_eq!(writes.with_domain("domain", || 7), 7);
        assert!(std::panic::catch_unwind(|| writes.with_all(|| panic!("夹具全清中断"))).is_err());
        assert_eq!(writes.with_all(|| 8), 8);
    }
}
