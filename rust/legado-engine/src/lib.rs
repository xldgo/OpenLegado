//! 引擎资源装配层，不依赖 FFI、HTTP 服务或 Flutter。
//!
//! 数据库、书源限流、网络、抓取及 VM 缓存按实例共享；任务作用域已建立，正式任务接线与剩余宿主状态继续收口。

pub mod backup_service;
pub mod book_export_service;
pub mod book_import_service;
mod cache_downloads;
pub mod cover_service;
pub mod dictionary_service;
pub mod explore_service;
mod media;
mod network;
mod operations;
pub mod reading_service;
pub mod review_service;
mod rule_text;
pub mod search_service;
mod search_tasks;
pub mod source_batches;
pub mod source_catalog;
pub mod source_check_service;
pub mod source_debug_service;
mod source_info_map;
mod source_login;
mod source_switch;
pub mod source_switch_service;
mod storage;
mod tasks;
#[cfg(test)]
mod test_http_fixture;
pub mod webdav_service;

pub use cache_downloads::{CacheDownloadTask, CacheDownloads, ChapterDownload};
pub use media::{AudioTransfer, MediaState};
pub use network::{DbCookiePersistence, NetworkContext};
pub use operations::{Operation, OperationGuard, OperationSlot};
pub use search_tasks::{SearchSession, SearchTasks};
pub use source_info_map::SourceInfoMap;
pub use source_login::SourceLoginCache;
pub use source_switch::{SourceSwitchState, SwitchPrefetchEntry};
pub use storage::StorageContext;
pub use tasks::{TaskGroup, TaskGuard, TaskHandle, TaskScopeError};

use legado_core::LegadoResult;
use legado_db::Database;
use legado_fetcher::rate_limit::RateLimiterRegistry;
use std::sync::Arc;

/// 宿主持有并共享的引擎实例；业务调用只借用自身需要的能力。
pub struct EngineContext {
    storage: StorageContext,
    rate_limiter: Arc<RateLimiterRegistry>,
    network: Arc<NetworkContext>,
    web_book: Arc<legado_fetcher::web_book_state::WebBookState>,
    js: Arc<legado_js::JsResources>,
    source_login: Arc<SourceLoginCache>,
    source_info_map: Arc<SourceInfoMap>,
    tasks: TaskGroup,
    media: Arc<MediaState>,
    download_manager: Arc<std::sync::Mutex<legado_core::download_manager::DownloadManager>>,
}

impl EngineContext {
    /// 沿用数据库层的初始化、迁移与连接池配置。
    pub fn open(path: &str) -> LegadoResult<Self> {
        let db = legado_db::init_database(path)?;
        Ok(Self::from_database(db))
    }

    /// 接收宿主已初始化的数据库，立即归还其连接，不重新执行迁移。
    pub fn from_database(db: Database) -> Self {
        let storage = StorageContext::from_database(db);
        let network = Arc::new(NetworkContext::with_storage(storage.clone()));
        let source_login = Arc::new(SourceLoginCache::with_storage(storage.clone()));
        let source_info_map = Arc::new(SourceInfoMap::with_storage(storage.clone()));
        let js = legado_js::JsResources::default().with_source_login_store(source_login.clone());
        #[cfg(feature = "quickjs")]
        let js = js.with_http_resources(network.js_http_resources());
        Self {
            storage,
            rate_limiter: Arc::new(RateLimiterRegistry::new()),
            network,
            web_book: Arc::new(legado_fetcher::web_book_state::WebBookState::default()),
            js: Arc::new(js),
            source_login,
            source_info_map,
            tasks: TaskGroup::default(),
            media: Arc::new(MediaState::default()),
            download_manager: Arc::new(std::sync::Mutex::new(
                legado_core::download_manager::DownloadManager::new(3),
            )),
        }
    }

    /// 每个实例使用独立的单连接内存数据库，供嵌入和测试使用。
    pub fn in_memory() -> LegadoResult<Self> {
        Ok(Self::from_database(legado_db::init_in_memory_database()?))
    }

    pub fn storage(&self) -> &StorageContext {
        &self.storage
    }

    pub fn download_manager(
        &self,
    ) -> &Arc<std::sync::Mutex<legado_core::download_manager::DownloadManager>> {
        &self.download_manager
    }

    pub fn with_download_manager(
        mut self,
        manager: Arc<std::sync::Mutex<legado_core::download_manager::DownloadManager>>,
    ) -> Self {
        self.download_manager = manager;
        self
    }

    pub fn media(&self) -> &Arc<MediaState> {
        &self.media
    }

    pub fn with_media_state(mut self, media: Arc<MediaState>) -> Self {
        self.media = media;
        self
    }

    pub fn tasks(&self) -> &TaskGroup {
        &self.tasks
    }

    /// 开库前已登记的宿主任务在发布根实例后仍属于同一任务组。
    pub fn with_task_group(mut self, tasks: TaskGroup) -> Self {
        if !self.tasks.same_scope(&tasks) {
            // 装配替换不让旧组继续接收工作；旧凭据仍自行登记直到实际结束。
            self.tasks.request_cancel();
            self.tasks = tasks;
        }
        self
    }

    pub fn network(&self) -> &Arc<NetworkContext> {
        &self.network
    }

    pub fn web_book_state(&self) -> &Arc<legado_fetcher::web_book_state::WebBookState> {
        &self.web_book
    }

    pub fn js_resources(&self) -> &Arc<legado_js::JsResources> {
        &self.js
    }

    pub fn source_login_cache(&self) -> &Arc<SourceLoginCache> {
        &self.source_login
    }

    pub fn source_info_map(&self) -> &Arc<SourceInfoMap> {
        &self.source_info_map
    }

    /// 发现控件可在开库前使用；成功建库后接续相同数据服务。
    pub fn with_source_info_map(mut self, service: Arc<SourceInfoMap>) -> LegadoResult<Self> {
        service.bind_storage(self.storage.clone())?;
        self.source_info_map = service;
        Ok(self)
    }

    /// 接续开库前的登录缓存；资源只能绑定本次成功初始化的数据库。
    pub fn with_source_login_cache(mut self, cache: Arc<SourceLoginCache>) -> LegadoResult<Self> {
        cache.bind_storage(self.storage.clone())?;
        self.source_login = cache;
        let resources = self.js.clone();
        self = self.with_js_resources(resources);
        Ok(self)
    }

    /// 开库前已有 JS 执行时，沿用原执行资源。
    pub fn with_js_resources(mut self, resources: Arc<legado_js::JsResources>) -> Self {
        let login: Arc<dyn legado_js::source_login::SourceLoginStore> = self.source_login.clone();
        self.js = if resources
            .source_login_store()
            .is_some_and(|store| Arc::ptr_eq(store, &login))
        {
            resources
        } else {
            Arc::new(resources.as_ref().clone().with_source_login_store(login))
        };
        #[cfg(feature = "quickjs")]
        {
            let cookies: Arc<dyn legado_js::http_resources::CookieAccess> = self.network.clone();
            if !Arc::ptr_eq(
                self.js.http_resources().cookie_store(),
                self.network.cookie_store(),
            ) || !Arc::ptr_eq(self.js.http_resources().cookies(), &cookies)
            {
                self.js = Arc::new(
                    self.js
                        .as_ref()
                        .clone()
                        .with_http_resources(self.network.js_http_resources()),
                );
            }
        }
        self
    }

    /// 开库前已发生抓取时，继续使用宿主已有的缓存实例。
    pub fn with_web_book_state(
        mut self,
        state: Arc<legado_fetcher::web_book_state::WebBookState>,
    ) -> Self {
        self.web_book = state;
        self
    }

    /// 宿主早于数据库访问网络时，成功建库后接续原来的 Cookie 和客户端。
    pub fn with_network(mut self, network: Arc<NetworkContext>) -> LegadoResult<Self> {
        network.bind_storage(self.storage.clone())?;
        self.network = network;
        let resources = self.js.clone();
        self = self.with_js_resources(resources);
        Ok(self)
    }

    /// 宿主初始化数据库前已使用限流能力时，沿用同一窗口。
    pub fn with_rate_limiter(mut self, registry: Arc<RateLimiterRegistry>) -> Self {
        self.rate_limiter = registry;
        self
    }

    pub fn rate_limiter(&self) -> Arc<RateLimiterRegistry> {
        self.rate_limiter.clone()
    }
}

impl Drop for EngineContext {
    fn drop(&mut self) {
        // 析构只发取消请求，不同步等待回调或销毁外部运行时。
        self.tasks.request_cancel();
    }
}
