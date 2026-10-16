//! 搜索宿主的会话槽位，只持控制能力，不持根引擎或业务数据。

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, Weak};

use crate::{TaskGroup, TaskHandle, TaskScopeError};

#[derive(Default)]
struct State {
    next: u64,
    current: Weak<SearchSession>,
}

pub struct SearchTasks {
    tasks: TaskGroup,
    state: Mutex<State>,
}

impl SearchTasks {
    pub fn new(tasks: TaskGroup) -> Self {
        Self {
            tasks,
            state: Mutex::new(State::default()),
        }
    }

    /// 槽位先替换，旧发布段在锁外排空，避免槽位与发布门控相互等待。
    pub fn start(self: &Arc<Self>) -> Result<Arc<SearchSession>, TaskScopeError> {
        let (session, previous) = {
            let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            let next = state
                .next
                .checked_add(1)
                .ok_or(TaskScopeError::IdExhausted)?;
            let task = self.tasks.begin()?;
            let session = Arc::new(SearchSession {
                session_id: next,
                paused: Arc::new(AtomicBool::new(false)),
                task,
                owner: Arc::downgrade(self),
            });
            state.next = next;
            let previous = std::mem::replace(&mut state.current, Arc::downgrade(&session));
            (session, previous)
        };
        if let Some(previous) = previous.upgrade() {
            previous.cancel();
        }
        Ok(session)
    }

    pub fn current(&self) -> Option<Arc<SearchSession>> {
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .current
            .upgrade()
    }
}

impl Drop for SearchTasks {
    fn drop(&mut self) {
        // 槽位是弱引用，析构不等待计算，也不关闭宿主的兄弟任务。
        if let Some(current) = self
            .state
            .get_mut()
            .unwrap_or_else(|p| p.into_inner())
            .current
            .upgrade()
        {
            current.task.request_cancel();
        }
    }
}

pub struct SearchSession {
    /// 宿主内单调编号，仅用于日志，不属于搜索 JSON 协议。
    pub session_id: u64,
    /// 软暂停只阻止新源派发，不停止已发出的请求。
    pub paused: Arc<AtomicBool>,
    task: TaskHandle,
    owner: Weak<SearchTasks>,
}

impl SearchSession {
    pub fn task(&self) -> &TaskHandle {
        &self.task
    }

    pub fn is_cancelled(&self) -> bool {
        self.task.is_cancelled()
    }

    pub fn cancel(&self) {
        self.task.cancel();
    }

    pub fn set_paused(&self, paused: bool) {
        self.paused.store(paused, Ordering::SeqCst);
    }

    pub fn is_current(self: &Arc<Self>) -> bool {
        self.owner
            .upgrade()
            .and_then(|owner| owner.current())
            .is_some_and(|current| Arc::ptr_eq(&current, self))
    }

    pub fn finish(self: &Arc<Self>) {
        if let Some(owner) = self.owner.upgrade() {
            let mut state = owner.state.lock().unwrap_or_else(|p| p.into_inner());
            if state.current.ptr_eq(&Arc::downgrade(self)) {
                state.current = Weak::new();
            }
        }
    }

    /// 仅包裹短同步提交/事件，不得在闭包中取消自身或启动替代搜索。
    pub fn with_current<T>(self: &Arc<Self>, publish: impl FnOnce() -> T) -> Option<T> {
        self.task
            .with_active(|| self.is_current().then(publish))
            .flatten()
    }
}
