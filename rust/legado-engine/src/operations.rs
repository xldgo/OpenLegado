//! 可替换的实例操作槽：校验与调试分别持有，不发现进程当前任务。

use crate::{TaskGroup, TaskHandle, TaskScopeError};
use std::sync::{Arc, Mutex, Weak};

pub struct OperationSlot {
    tasks: TaskGroup,
    current: Mutex<Weak<Operation>>,
}

impl OperationSlot {
    pub fn new(tasks: TaskGroup) -> Self {
        Self {
            tasks,
            current: Mutex::new(Weak::new()),
        }
    }

    pub fn start(self: &Arc<Self>) -> Result<Arc<Operation>, TaskScopeError> {
        let (operation, previous) = {
            let mut current = self.current.lock().unwrap_or_else(|p| p.into_inner());
            let operation = Arc::new(Operation {
                task: self.tasks.begin()?,
                owner: Arc::downgrade(self),
            });
            let previous = std::mem::replace(&mut *current, Arc::downgrade(&operation));
            (operation, previous)
        };
        if let Some(previous) = previous.upgrade() {
            previous.cancel();
        }
        Ok(operation)
    }

    pub fn current(&self) -> Option<Arc<Operation>> {
        self.current
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .upgrade()
    }

    pub fn cancel(&self) {
        if let Some(current) = self.current() {
            current.cancel();
        }
    }
}

impl Drop for OperationSlot {
    fn drop(&mut self) {
        if let Some(current) = self
            .current
            .get_mut()
            .unwrap_or_else(|p| p.into_inner())
            .upgrade()
        {
            current.task.request_cancel();
        }
    }
}

pub struct Operation {
    task: TaskHandle,
    owner: Weak<OperationSlot>,
}

impl Operation {
    pub fn task(&self) -> &TaskHandle {
        &self.task
    }
    pub fn cancel(&self) {
        self.task.cancel();
    }
    pub fn is_active(self: &Arc<Self>) -> bool {
        !self.task.is_cancelled()
            && self
                .owner
                .upgrade()
                .and_then(|owner| owner.current())
                .is_some_and(|current| Arc::ptr_eq(&current, self))
    }
    pub fn finish(self: &Arc<Self>) {
        if let Some(owner) = self.owner.upgrade() {
            let mut current = owner.current.lock().unwrap_or_else(|p| p.into_inner());
            if current.ptr_eq(&Arc::downgrade(self)) {
                *current = Weak::new();
            }
        }
    }
    /// 同步发布段不得重入取消或替换；失败应在返回门控后处理。
    pub fn publish<T>(self: &Arc<Self>, callback: impl FnOnce() -> T) -> Option<T> {
        self.task
            .with_active(|| self.is_active().then(callback))
            .flatten()
    }
    pub fn guard(self: &Arc<Self>) -> OperationGuard {
        OperationGuard(self.clone())
    }
}

/// 异步入口被丢弃也撤销自身；阻塞 worker 的独立凭据继续登记实际寿命。
pub struct OperationGuard(Arc<Operation>);
impl Drop for OperationGuard {
    fn drop(&mut self) {
        self.0.task.request_cancel();
        self.0.finish();
    }
}
