//! 共享应用状态

use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use tokio::sync::Mutex;

use legado_core::LegadoResult;
use legado_core::download_manager::DownloadManager;
use legado_db::Database;
use legado_engine::EngineContext;

/// 全局共享状态，通过 `Arc<AppState>` 在 axum 路由间共享
pub struct AppState {
    /// 与嵌入宿主共享引擎资源，服务自身不长期占用池连接。
    pub engine: Arc<EngineContext>,
    /// 本次服务的子组，重启不复用已关闭作用域。
    pub tasks: legado_engine::TaskGroup,
    /// 搜索取消标志（简化版，使用 AtomicBool）
    pub search_cancelled: Arc<AtomicBool>,
    /// 下载管理器
    pub download_manager: Arc<std::sync::Mutex<DownloadManager>>,
    pub services: Arc<ServerServices>,
}

impl AppState {
    pub fn new(engine: Arc<EngineContext>) -> Self {
        let tasks = engine.tasks().clone();
        let download_manager = engine.download_manager().clone();
        Self {
            engine,
            tasks,
            search_cancelled: Arc::new(AtomicBool::new(false)),
            download_manager,
            services: Arc::new(ServerServices::default()),
        }
    }

    pub fn with_services(mut self, services: Arc<ServerServices>) -> Self {
        self.services = services;
        self
    }

    pub fn with_tasks(mut self, tasks: legado_engine::TaskGroup) -> Self {
        self.tasks = tasks;
        self
    }

    /// 在工作派发前登记，阻塞闭包必须把凭据持有到实际返回。
    pub fn task(&self) -> LegadoResult<legado_engine::TaskHandle> {
        self.tasks
            .begin()
            .map_err(|e| legado_core::LegadoError::Internal(e.to_string()))
    }

    /// 同步抓取回调和已有阻塞任务短借连接。
    pub fn database(&self) -> LegadoResult<Database> {
        self.engine.storage().database()
    }

    /// 首次客户端构造可能预载数据库 Cookie，不在异步 worker 上等待池连接。
    pub async fn network_client(&self) -> LegadoResult<legado_net::LegadoClient> {
        let network = self.engine.network().clone();
        let task = self.task()?;
        tokio::task::spawn_blocking(move || {
            let _task = task;
            network.client()
        })
        .await
        .map_err(|error| {
            legado_core::LegadoError::Network(format!("网络客户端装配任务异常: {error}"))
        })?
    }

    pub async fn with_database<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&Database) -> T + Send + 'static,
    ) -> LegadoResult<T> {
        let task = self.task()?;
        self.engine
            .storage()
            .run(move |db| {
                task.with_active(|| operation(db))
                    .ok_or_else(|| legado_core::LegadoError::Internal("服务任务已取消".into()))
            })
            .await?
    }
}

/// 状态类型别名，方便在 handler 签名中使用
pub type SharedState = Arc<AppState>;

/// Web/MCP 的宿主会话数据共享一份，既不存进程全局，也不反向持根引擎。
pub struct ServerServices {
    pub debugger: Arc<legado_core::debug_session::Debugger>,
    pub read_aloud: crate::handlers::read_aloud_handler::SharedReadAloudState,
    pub auto_tasks: Mutex<Vec<legado_core::models::AutoTaskRule>>,
    pub toc_updater: Mutex<Arc<legado_core::toc_updater::TocUpdater>>,
    pub toc_stopped: AtomicBool,
}
impl Default for ServerServices {
    fn default() -> Self {
        Self {
            debugger: Arc::new(legado_core::debug_session::Debugger::new()),
            read_aloud: crate::handlers::read_aloud_handler::create_read_aloud_state(),
            auto_tasks: Mutex::new(Vec::new()),
            toc_updater: Mutex::new(Arc::new(legado_core::toc_updater::TocUpdater::new(4))),
            toc_stopped: AtomicBool::new(false),
        }
    }
}

#[cfg(test)]
mod lifecycle_tests {
    use super::*;
    use std::time::Duration;
    #[tokio::test]
    async fn detached_database_worker_keeps_registration_without_keeping_root() {
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        let weak = Arc::downgrade(&engine);
        let tasks = engine.tasks().child().unwrap();
        let state = Arc::new(AppState::new(engine.clone()).with_tasks(tasks.clone()));
        let (entered, mut ready) = tokio::sync::mpsc::unbounded_channel();
        let (release, wait) = std::sync::mpsc::channel();
        let operation = tokio::spawn(async move {
            state
                .with_database(move |db| {
                    entered.send(()).unwrap();
                    wait.recv().unwrap();
                    legado_db::CacheRepository::new(db.connection()).put("actual-worker", "done", 0)
                })
                .await
        });
        ready.recv().await.unwrap();
        operation.abort();
        let _ = operation.await;
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(!tasks.shutdown(Duration::from_millis(20)).await);
        assert_eq!(tasks.active_count(), 1);
        release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(2)).await);
    }

    #[tokio::test]
    async fn shared_host_keeps_sessions_but_independent_hosts_do_not_share_data() {
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        let host = Arc::new(ServerServices::default());
        let web = AppState::new(engine.clone()).with_services(host.clone());
        let mcp = AppState::new(engine).with_services(host);
        let other = AppState::new(Arc::new(EngineContext::in_memory().unwrap()));
        let id = web
            .services
            .debugger
            .create_session("source", "name", "key");
        assert!(mcp.services.debugger.get_session(&id).is_some());
        assert!(other.services.debugger.get_session(&id).is_none());
        web.download_manager.lock().unwrap().pause_all();
        assert!(mcp.download_manager.lock().unwrap().is_paused());
        assert!(!other.download_manager.lock().unwrap().is_paused());
    }
}
