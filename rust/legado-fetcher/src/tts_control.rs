//! TTS 请求取消与同输入串行门禁，不持有数据库或 JS 引擎。
use legado_core::{LegadoError, LegadoResult};
use std::collections::HashMap;
use std::future::Future;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock, Weak};
use tokio::sync::{Mutex as AsyncMutex, Notify};

#[derive(Default, Clone)]
pub struct TtsCancellation {
    state: Arc<CancellationState>,
}

impl legado_js::cancellation::JsCancellation for TtsCancellation {
    fn is_cancelled(&self) -> bool {
        self.state.cancelled.load(Ordering::Acquire)
    }
    fn cancelled(&self) -> legado_js::cancellation::CancelWait<'_> {
        Box::pin(self.cancelled())
    }
}

#[derive(Default)]
struct CancellationState {
    cancelled: AtomicBool,
    notification: Notify,
}

impl TtsCancellation {
    pub fn cancel(&self) {
        self.state.cancelled.store(true, Ordering::Release);
        self.state.notification.notify_waiters();
    }

    pub fn check(&self) -> LegadoResult<()> {
        if self.state.cancelled.load(Ordering::Acquire) {
            Err(LegadoError::Ffi("TTS_CANCELLED".into()))
        } else {
            Ok(())
        }
    }

    async fn cancelled(&self) {
        let notified = self.state.notification.notified();
        tokio::pin!(notified);
        notified.as_mut().enable();
        if self.state.cancelled.load(Ordering::Acquire) {
            return;
        }
        notified.await;
    }

    pub async fn run<T>(&self, future: impl Future<Output = LegadoResult<T>>) -> LegadoResult<T> {
        self.check()?;
        tokio::select! {
            biased;
            _ = self.cancelled() => Err(LegadoError::Ffi("TTS_CANCELLED".into())),
            result = future => { self.check()?; result }
        }
    }
}

/// 仅相同缓存目录、相同合成输入串行；弱引用不会让每段锁永久留存。
pub fn synthesis_lock(directory: PathBuf, key: String) -> Arc<AsyncMutex<()>> {
    type Locks = HashMap<(PathBuf, String), Weak<AsyncMutex<()>>>;
    static LOCKS: OnceLock<Mutex<Locks>> = OnceLock::new();
    let mut locks = LOCKS
        .get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|p| p.into_inner());
    locks.retain(|_, weak| weak.strong_count() > 0);
    let entry = locks.entry((directory, key)).or_default();
    if let Some(lock) = entry.upgrade() {
        return lock;
    }
    let lock = Arc::new(AsyncMutex::new(()));
    *entry = Arc::downgrade(&lock);
    lock
}
