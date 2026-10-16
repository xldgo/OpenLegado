//! 宿主拥有监听句柄和启停锁；业务引擎只提供子任务组，不拥有 Tokio runtime。

use legado_core::{LegadoError, LegadoResult};
use legado_engine::TaskGroup;
use std::future::Future;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::Duration;
use tokio::runtime::Runtime;
use tokio::task::JoinHandle;

#[derive(Default)]
pub(crate) struct ServiceHost {
    pub web: ServiceSlot,
    pub mcp: ServiceSlot,
    pub state: Arc<legado_server::state::ServerServices>,
}

#[derive(Default)]
pub(crate) struct ServiceSlot {
    control: Mutex<()>,
    state: Mutex<Option<Running>>,
}

struct Running {
    port: u16,
    alive: Arc<AtomicBool>,
    scope: TaskGroup,
    handle: JoinHandle<()>,
}

/// 即使任务被 abort 或 panic，也只清理自身身份，不接触后一次启动的状态。
struct Completion(Arc<AtomicBool>);
impl Drop for Completion {
    fn drop(&mut self) {
        self.0.store(false, Ordering::Release);
    }
}

impl ServiceSlot {
    pub fn control(&self) -> MutexGuard<'_, ()> {
        self.control.lock().unwrap_or_else(|p| p.into_inner())
    }

    pub fn status(&self) -> (bool, u16) {
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .as_ref()
            .map(|run| {
                (
                    run.alive.load(Ordering::Acquire)
                        && !run.handle.is_finished()
                        && !run.scope.is_closed(),
                    run.port,
                )
            })
            .unwrap_or((false, 0))
    }

    /// 调用者持启停锁；绑定成功后才发布状态，spawn 前创建析构守卫。
    pub fn start<F, Fut>(
        &self,
        runtime: &Runtime,
        parent: &TaskGroup,
        port: u16,
        serve: F,
    ) -> LegadoResult<()>
    where
        F: FnOnce(TaskGroup) -> Fut,
        Fut: Future<Output = ()> + Send + 'static,
    {
        let scope = parent
            .child()
            .map_err(|e| LegadoError::Internal(e.to_string()))?;
        let permit = scope
            .begin()
            .map_err(|e| LegadoError::Internal(e.to_string()))?;
        let alive = Arc::new(AtomicBool::new(true));
        let completion = Completion(alive.clone());
        let future = serve(scope.clone());
        let cancellation = permit.clone();
        let handle = runtime.spawn(async move {
            let _completion = completion;
            let _permit = permit;
            tokio::select! {
                biased;
                _ = cancellation.cancelled() => {},
                _ = future => {},
            }
        });
        *self.state.lock().unwrap_or_else(|p| p.into_inner()) = Some(Running {
            port,
            alive,
            scope,
            handle,
        });
        Ok(())
    }

    /// 先拒绝新工作，再等监听器析构；在途请求单独有界等待，超时不清空登记。
    pub fn stop(&self, runtime: &Runtime) -> bool {
        let run = self.state.lock().unwrap_or_else(|p| p.into_inner()).take();
        let Some(run) = run else {
            return false;
        };
        let was_running = run.alive.load(Ordering::Acquire) && !run.handle.is_finished();
        run.scope.request_cancel();
        run.handle.abort();
        let _ = runtime.block_on(run.handle);
        if !runtime.block_on(run.scope.shutdown(Duration::from_secs(2))) {
            log::warn!(
                "服务端口 {} 已释放，仍有 {} 项工作正在退出",
                run.port,
                run.scope.active_count()
            );
        }
        was_running
    }
}

impl Drop for ServiceSlot {
    fn drop(&mut self) {
        if let Some(run) = self
            .state
            .get_mut()
            .unwrap_or_else(|p| p.into_inner())
            .take()
        {
            run.scope.request_cancel();
            run.handle.abort();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn independent_slots_stop_release_ports_and_restart_without_cancelling_siblings() {
        let runtime = Runtime::new().unwrap();
        let tasks = TaskGroup::default();
        let host = ServiceHost::default();
        let web = runtime
            .block_on(tokio::net::TcpListener::bind("127.0.0.1:0"))
            .unwrap();
        let web_port = web.local_addr().unwrap().port();
        let mcp = runtime
            .block_on(tokio::net::TcpListener::bind("127.0.0.1:0"))
            .unwrap();
        let mcp_port = mcp.local_addr().unwrap().port();
        host.web
            .start(&runtime, &tasks, web_port, move |_| async move {
                let _ = web.accept().await;
            })
            .unwrap();
        host.mcp
            .start(&runtime, &tasks, mcp_port, move |_| async move {
                let _ = mcp.accept().await;
            })
            .unwrap();
        assert!(host.web.status().0 && host.mcp.status().0);
        assert!(host.web.stop(&runtime));
        assert!(std::net::TcpListener::bind(("127.0.0.1", web_port)).is_ok());
        assert!(host.mcp.status().0);
        assert_eq!(tasks.active_count(), 1);
        let next = runtime
            .block_on(tokio::net::TcpListener::bind(("127.0.0.1", web_port)))
            .unwrap();
        host.web
            .start(&runtime, &tasks, web_port, move |_| async move {
                let _ = next.accept().await;
            })
            .unwrap();
        assert_eq!(host.web.status(), (true, web_port));
        assert!(host.web.stop(&runtime));
        assert!(!host.web.stop(&runtime));
        assert!(host.mcp.stop(&runtime));
        assert_eq!(tasks.active_count(), 0);
        assert!(std::net::TcpListener::bind(("127.0.0.1", mcp_port)).is_ok());
    }

    #[test]
    fn dropping_listener_owner_signals_without_blocking_and_preserves_actual_permits() {
        let runtime = Runtime::new().unwrap();
        let tasks = TaskGroup::default();
        let slot = ServiceSlot::default();
        let (entered, ready) = std::sync::mpsc::channel();
        let (release, wait) = std::sync::mpsc::channel();
        slot.start(&runtime, &tasks, 1234, move |scope| async move {
            let work = scope.begin().unwrap();
            tokio::task::spawn_blocking(move || {
                let _work = work;
                entered.send(()).unwrap();
                wait.recv().unwrap();
            })
            .await
            .unwrap();
        })
        .unwrap();
        ready.recv_timeout(Duration::from_secs(3)).unwrap();
        drop(slot);
        assert!(!runtime.block_on(tasks.shutdown(Duration::from_millis(20))));
        assert_eq!(tasks.active_count(), 1);
        release.send(()).unwrap();
        assert!(runtime.block_on(tasks.shutdown(Duration::from_secs(3))));
    }
}
