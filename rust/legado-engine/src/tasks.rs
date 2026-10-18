//! 引擎/宿主任务的登记、取消与可等待关闭；不持有运行时或业务数据。

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, Weak};
use std::time::Duration;
use tokio::sync::Notify;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskScopeError {
    Closed,
    IdExhausted,
}

impl std::fmt::Display for TaskScopeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Closed => "任务组已关闭，不能登记新工作",
            Self::IdExhausted => "任务登记编号耗尽",
        })
    }
}

impl std::error::Error for TaskScopeError {}

struct Scope {
    id: u64,
    closed: AtomicBool,
}

#[derive(Default)]
struct State {
    next: u64,
    tasks: HashMap<u64, Weak<RegisteredTask>>,
}

impl State {
    fn next_id(&mut self) -> Result<u64, TaskScopeError> {
        self.next = self
            .next
            .checked_add(1)
            .ok_or(TaskScopeError::IdExhausted)?;
        Ok(self.next)
    }
}

#[derive(Default)]
struct Registry {
    state: Mutex<State>,
    changed: Notify,
}

/// 组只持任务登记数据；子组取消不会影响父组、兄弟组或其他引擎。
#[derive(Clone)]
pub struct TaskGroup {
    registry: Arc<Registry>,
    scopes: Vec<Arc<Scope>>,
}

impl Default for TaskGroup {
    fn default() -> Self {
        Self {
            registry: Arc::new(Registry::default()),
            scopes: vec![Arc::new(Scope {
                id: 0,
                closed: AtomicBool::new(false),
            })],
        }
    }
}

impl TaskGroup {
    pub fn is_closed(&self) -> bool {
        self.scopes
            .iter()
            .any(|scope| scope.closed.load(Ordering::Acquire))
    }

    pub fn same_scope(&self, other: &Self) -> bool {
        Arc::ptr_eq(&self.registry, &other.registry) && self.id() == other.id()
    }

    fn id(&self) -> u64 {
        self.scopes.last().expect("任务组必须包含根作用域").id
    }

    pub fn child(&self) -> Result<Self, TaskScopeError> {
        let mut state = self
            .registry
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        if self.is_closed() {
            return Err(TaskScopeError::Closed);
        }
        let mut scopes = self.scopes.clone();
        scopes.push(Arc::new(Scope {
            id: state.next_id()?,
            closed: AtomicBool::new(false),
        }));
        Ok(Self {
            registry: self.registry.clone(),
            scopes,
        })
    }

    /// 子任务/阻塞工作必须保留克隆凭据，最后一份释放后才算结束。
    pub fn begin(&self) -> Result<TaskHandle, TaskScopeError> {
        let mut state = self
            .registry
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        if self.is_closed() {
            return Err(TaskScopeError::Closed);
        }
        let id = state.next_id()?;
        let task = Arc::new(RegisteredTask {
            id,
            registry: self.registry.clone(),
            scopes: self.scopes.clone(),
            cancelled: Arc::new(AtomicBool::new(false)),
            changed: Notify::new(),
            publish: Mutex::new(()),
        });
        state.tasks.insert(id, Arc::downgrade(&task));
        Ok(TaskHandle(task))
    }

    fn contains(&self, task: &RegisteredTask) -> bool {
        task.scopes.iter().any(|scope| scope.id == self.id())
    }

    fn signal_cancel(&self) -> Vec<Arc<RegisteredTask>> {
        let snapshot: Vec<_> = {
            let state = self
                .registry
                .state
                .lock()
                .unwrap_or_else(|p| p.into_inner());
            self.scopes
                .last()
                .unwrap()
                .closed
                .store(true, Ordering::Release);
            state.tasks.values().cloned().collect()
        };
        // 升级弱引用也可能取得最后一个强引用；必须在登记锁外升级和释放。
        let tasks: Vec<_> = snapshot
            .into_iter()
            .filter_map(|task| task.upgrade())
            .filter(|task| self.contains(task))
            .collect();
        // 不持登记锁通知或等待发布门控，避免与最后一份凭据释放互锁。
        for task in &tasks {
            task.signal_cancel();
        }
        tasks
    }

    /// 请求取消，不等待发布段；用于析构兜底，不表示任务已结束。
    pub fn request_cancel(&self) {
        self.signal_cancel();
    }

    /// 返回后所有已进入的发布段均已退出；不得在发布段内重入取消/关闭。
    pub fn cancel(&self) {
        for task in self.signal_cancel() {
            let _publish = task.publish.lock().unwrap_or_else(|p| p.into_inner());
        }
    }

    /// 统计包括后代组在内的真实在途凭据，不清空尚未结束的登记。
    pub fn active_count(&self) -> usize {
        let snapshot: Vec<_> = self
            .registry
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .tasks
            .values()
            .cloned()
            .collect();
        snapshot
            .into_iter()
            .filter_map(|task| task.upgrade())
            .filter(|task| self.contains(task))
            .count()
    }

    /// 等待有界关闭，不阻塞 Tokio worker；超时不冒充关闭成功。
    pub async fn shutdown(&self, timeout: Duration) -> bool {
        // 异步关闭不等待同步发布锁；在途凭据覆盖发布段，下面异步等其全部释放。
        self.request_cancel();
        tokio::time::timeout(timeout, async {
            loop {
                let notified = self.registry.changed.notified();
                let mut notified = std::pin::pin!(notified);
                notified.as_mut().enable();
                if self.active_count() == 0 {
                    return;
                }
                notified.await;
            }
        })
        .await
        .is_ok()
    }
}

struct RegisteredTask {
    id: u64,
    registry: Arc<Registry>,
    scopes: Vec<Arc<Scope>>,
    cancelled: Arc<AtomicBool>,
    changed: Notify,
    publish: Mutex<()>,
}

impl RegisteredTask {
    fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
            || self
                .scopes
                .iter()
                .any(|scope| scope.closed.load(Ordering::Acquire))
    }

    fn signal_cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
        self.changed.notify_waiters();
    }
}

impl Drop for RegisteredTask {
    fn drop(&mut self) {
        self.registry
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .tasks
            .remove(&self.id);
        self.registry.changed.notify_waiters();
    }
}

/// 只包含任务能力，不捕获宿主、数据库、VM 或根 EngineContext。
#[derive(Clone)]
pub struct TaskHandle(Arc<RegisteredTask>);

impl legado_js::cancellation::JsCancellation for TaskHandle {
    fn is_cancelled(&self) -> bool {
        TaskHandle::is_cancelled(self)
    }
    fn cancelled(&self) -> legado_js::cancellation::CancelWait<'_> {
        Box::pin(TaskHandle::cancelled(self))
    }
}

impl TaskHandle {
    pub fn is_cancelled(&self) -> bool {
        self.0.is_cancelled()
    }

    /// 供现有 AtomicBool 轮询读取接线；取消须调用 cancel，不能自行写位而漏掉通知。
    pub fn cancellation_flag(&self) -> Arc<AtomicBool> {
        self.0.cancelled.clone()
    }

    /// 独立操作的入口所有者；丢弃时只通知取消，工作克隆仍登记到真实结束。
    pub fn guard(&self) -> TaskGuard {
        TaskGuard(self.clone())
    }

    pub fn cancel(&self) {
        self.request_cancel();
        let _publish = self.0.publish.lock().unwrap_or_else(|p| p.into_inner());
    }

    /// 所有者析构只通知，不在回调或析构线程等待发布门控。
    pub(crate) fn request_cancel(&self) {
        self.0.signal_cancel();
    }

    pub async fn cancelled(&self) {
        loop {
            let notified = self.0.changed.notified();
            let mut notified = std::pin::pin!(notified);
            notified.as_mut().enable();
            if self.is_cancelled() {
                return;
            }
            notified.await;
        }
    }

    /// 只包裹短同步提交/事件步骤，不跨 await，也不在闭包内取消或关闭所属任务组。
    pub fn with_active<T>(&self, publish: impl FnOnce() -> T) -> Option<T> {
        let _publish = self.0.publish.lock().unwrap_or_else(|p| p.into_inner());
        if self.is_cancelled() {
            None
        } else {
            Some(publish())
        }
    }
}

/// 一个入口的取消责任，不持根引擎，也不把工作克隆的寿命当作入口寿命。
pub struct TaskGuard(TaskHandle);
impl Drop for TaskGuard {
    fn drop(&mut self) {
        self.0.request_cancel();
    }
}
