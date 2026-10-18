//! 按次执行取消能力；线程局部绑定只在同步JS调用栈内使用，异步等待显式持有快照。
//! — Codex + Bridge
use legado_core::{LegadoError, LegadoResult};
use std::{cell::RefCell, future::Future, marker::PhantomData, pin::Pin, rc::Rc, sync::Arc};

pub type CancelWait<'a> = Pin<Box<dyn Future<Output = ()> + Send + 'a>>;
pub trait JsCancellation: Send + Sync {
    fn is_cancelled(&self) -> bool;
    fn cancelled(&self) -> CancelWait<'_>;
}

/// 合成会话可同时受所属引擎任务与独立请求取消控制。
#[cfg(feature = "quickjs")]
pub fn combine(
    a: Option<Arc<dyn JsCancellation>>,
    b: Option<Arc<dyn JsCancellation>>,
) -> Option<Arc<dyn JsCancellation>> {
    struct Pair(Arc<dyn JsCancellation>, Arc<dyn JsCancellation>);
    impl JsCancellation for Pair {
        fn is_cancelled(&self) -> bool {
            self.0.is_cancelled() || self.1.is_cancelled()
        }
        fn cancelled(&self) -> CancelWait<'_> {
            Box::pin(async {
                let _ = futures::future::select(self.0.cancelled(), self.1.cancelled()).await;
            })
        }
    }
    match (a, b) {
        (Some(a), Some(b)) => Some(Arc::new(Pair(a, b))),
        (a, b) => a.or(b),
    }
}

thread_local! {
    static CURRENT: RefCell<Option<Arc<dyn JsCancellation>>> = const { RefCell::new(None) };
}

pub const CANCELLED: &str = "JS任务已取消";
pub fn error() -> LegadoError {
    LegadoError::JsEngine(CANCELLED.into())
}
pub fn current() -> Option<Arc<dyn JsCancellation>> {
    CURRENT.with(|slot| slot.borrow().clone())
}
pub fn is_cancelled() -> bool {
    CURRENT.with(|slot| {
        slot.borrow()
            .as_ref()
            .is_some_and(|control| control.is_cancelled())
    })
}
pub fn check() -> LegadoResult<()> {
    if is_cancelled() { Err(error()) } else { Ok(()) }
}

/// 不允许跨线程移动；无新能力时继承调用栈，嵌套显式能力在退出时恢复。
pub struct Scope {
    previous: Option<Option<Arc<dyn JsCancellation>>>,
    _thread: PhantomData<Rc<()>>,
}
impl Scope {
    pub fn enter(control: Option<Arc<dyn JsCancellation>>) -> Self {
        let previous = control.map(|control| CURRENT.with(|slot| slot.replace(Some(control))));
        Self {
            previous,
            _thread: PhantomData,
        }
    }
}
impl Drop for Scope {
    fn drop(&mut self) {
        if let Some(previous) = self.previous.take() {
            CURRENT.with(|slot| {
                slot.replace(previous);
            });
        }
    }
}

/// 排队中的缓存锁也能取消；未绑定任务时沿用阻塞锁，不新增常驻调度器。
#[cfg(feature = "quickjs")]
pub(crate) fn lock<T>(mutex: &std::sync::Mutex<T>) -> LegadoResult<std::sync::MutexGuard<'_, T>> {
    if current().is_none() {
        return mutex
            .lock()
            .map_err(|_| LegadoError::JsEngine("JS执行锁中毒".into()));
    }
    loop {
        check()?;
        match mutex.try_lock() {
            Ok(guard) => return Ok(guard),
            Err(std::sync::TryLockError::Poisoned(_)) => {
                return Err(LegadoError::JsEngine("JS执行锁中毒".into()));
            }
            Err(std::sync::TryLockError::WouldBlock) => {
                std::thread::sleep(std::time::Duration::from_millis(5))
            }
        }
    }
}
