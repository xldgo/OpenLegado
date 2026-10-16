//! FFI 宿主的根实例持有者；首个成功初始化者发布实例，重复调用不切换数据库。

use std::sync::{Arc, Mutex, OnceLock};

use legado_core::{LegadoError, LegadoResult};
use legado_engine::{EngineContext, NetworkContext, SourceInfoMap, SourceLoginCache};
use legado_fetcher::rate_limit::RateLimiterRegistry;

static ENGINE: EngineHolder = EngineHolder::new();

struct EngineHolder {
    context: OnceLock<Arc<EngineContext>>,
    /// 初始化门控可跨建库和宿主配置；读取已发布实例不取此锁。
    initialization: Mutex<()>,
    rate_limiter: OnceLock<Arc<RateLimiterRegistry>>,
    network: OnceLock<Arc<NetworkContext>>,
    web_book: OnceLock<Arc<legado_fetcher::web_book_state::WebBookState>>,
    js: OnceLock<Arc<legado_js::JsResources>>,
    source_login: OnceLock<Arc<SourceLoginCache>>,
    source_info_map: OnceLock<Arc<SourceInfoMap>>,
    tasks: OnceLock<legado_engine::TaskGroup>,
    searches: OnceLock<Arc<legado_engine::SearchTasks>>,
    source_checks: OnceLock<Arc<legado_engine::OperationSlot>>,
    source_debug: OnceLock<Arc<legado_engine::OperationSlot>>,
    switches: OnceLock<Arc<legado_engine::SourceSwitchState>>,
    services: OnceLock<Arc<crate::service_host::ServiceHost>>,
    media: OnceLock<Arc<legado_engine::MediaState>>,
    cache_downloads: Mutex<Option<Arc<legado_engine::CacheDownloads>>>,
    download_manager: OnceLock<Arc<Mutex<legado_core::download_manager::DownloadManager>>>,
}

impl EngineHolder {
    const fn new() -> Self {
        Self {
            context: OnceLock::new(),
            initialization: Mutex::new(()),
            rate_limiter: OnceLock::new(),
            network: OnceLock::new(),
            web_book: OnceLock::new(),
            js: OnceLock::new(),
            source_login: OnceLock::new(),
            source_info_map: OnceLock::new(),
            tasks: OnceLock::new(),
            searches: OnceLock::new(),
            source_checks: OnceLock::new(),
            source_debug: OnceLock::new(),
            switches: OnceLock::new(),
            services: OnceLock::new(),
            media: OnceLock::new(),
            cache_downloads: Mutex::new(None),
            download_manager: OnceLock::new(),
        }
    }

    fn current(&self) -> LegadoResult<Arc<EngineContext>> {
        self.context
            .get()
            .cloned()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))
    }

    fn initialize(
        &self,
        build: impl FnOnce() -> LegadoResult<EngineContext>,
        configure: impl FnOnce(),
    ) -> LegadoResult<bool> {
        let _initialization = self
            .initialization
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        if self.context.get().is_some() {
            return Ok(false);
        }
        let context = Arc::new(
            build()?
                .with_rate_limiter(self.rate_limiter())
                .with_network(self.network())?
                .with_web_book_state(self.web_book_state())
                .with_source_login_cache(self.source_login_cache())?
                .with_source_info_map(self.source_info_map())?
                .with_js_resources(self.js_resources())
                .with_download_manager(self.download_manager())
                .with_media_state(self.media())
                .with_task_group(self.task_group()),
        );
        // 初始化门控保证唯一写方；失败的构造不会发布路径或连接池。
        if self.context.set(context).is_err() {
            return Err(LegadoError::Internal("引擎实例被重复发布".into()));
        }
        // 沿用先发布可访问的 DB 实例、再恢复配置的顺序；Cookie 已在装配时绑定。
        // 配置内部读取实例不取初始化门控，不持槽位写锁进入数据库。
        configure();
        Ok(true)
    }

    fn rate_limiter(&self) -> Arc<RateLimiterRegistry> {
        self.rate_limiter
            .get_or_init(|| Arc::new(RateLimiterRegistry::new()))
            .clone()
    }

    fn media(&self) -> Arc<legado_engine::MediaState> {
        self.media
            .get_or_init(|| Arc::new(Default::default()))
            .clone()
    }

    fn task_group(&self) -> legado_engine::TaskGroup {
        self.tasks
            .get_or_init(legado_engine::TaskGroup::default)
            .clone()
    }

    fn searches(&self) -> Arc<legado_engine::SearchTasks> {
        self.searches
            .get_or_init(|| Arc::new(legado_engine::SearchTasks::new(self.task_group())))
            .clone()
    }

    fn operations(
        &self,
        slot: &OnceLock<Arc<legado_engine::OperationSlot>>,
    ) -> Arc<legado_engine::OperationSlot> {
        slot.get_or_init(|| Arc::new(legado_engine::OperationSlot::new(self.task_group())))
            .clone()
    }

    fn switches(&self) -> Arc<legado_engine::SourceSwitchState> {
        self.switches
            .get_or_init(|| Arc::new(legado_engine::SourceSwitchState::new(self.task_group())))
            .clone()
    }

    fn cache_downloads(&self) -> LegadoResult<Arc<legado_engine::CacheDownloads>> {
        let mut slot = self
            .cache_downloads
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        if let Some(service) = slot.as_ref() {
            return Ok(service.clone());
        }
        let engine = self.current()?;
        let service = crate::api::cache_download_api::downloads_for_engine(&engine);
        *slot = Some(service.clone());
        Ok(service)
    }

    fn download_manager(&self) -> Arc<Mutex<legado_core::download_manager::DownloadManager>> {
        self.download_manager
            .get_or_init(|| {
                Arc::new(Mutex::new(
                    legado_core::download_manager::DownloadManager::new(3),
                ))
            })
            .clone()
    }

    fn network(&self) -> Arc<NetworkContext> {
        self.network
            .get_or_init(|| Arc::new(NetworkContext::default()))
            .clone()
    }

    fn web_book_state(&self) -> Arc<legado_fetcher::web_book_state::WebBookState> {
        self.web_book
            .get_or_init(|| Arc::new(Default::default()))
            .clone()
    }

    fn js_resources(&self) -> Arc<legado_js::JsResources> {
        self.js
            .get_or_init(|| {
                let resources = legado_js::JsResources::default()
                    .with_source_login_store(self.source_login_cache());
                resources
                    .host_resources()
                    .cache
                    .set_cache_dir(std::env::temp_dir().join("legado-js-cache"));
                #[cfg(feature = "quickjs")]
                let resources = resources.with_http_resources(self.network().js_http_resources());
                Arc::new(resources)
            })
            .clone()
    }

    fn source_login_cache(&self) -> Arc<SourceLoginCache> {
        self.source_login
            .get_or_init(|| Arc::new(SourceLoginCache::default()))
            .clone()
    }

    fn source_info_map(&self) -> Arc<SourceInfoMap> {
        self.source_info_map
            .get_or_init(|| Arc::new(SourceInfoMap::default()))
            .clone()
    }
}

pub(crate) fn current() -> LegadoResult<Arc<EngineContext>> {
    ENGINE.current()
}

pub(crate) fn is_initialized() -> bool {
    ENGINE.context.get().is_some()
}

pub(crate) fn rate_limiter() -> Arc<RateLimiterRegistry> {
    ENGINE.rate_limiter()
}

pub(crate) fn network() -> Arc<NetworkContext> {
    ENGINE.network()
}

pub(crate) fn web_book_state() -> Arc<legado_fetcher::web_book_state::WebBookState> {
    ENGINE.web_book_state()
}

pub(crate) fn js_resources() -> Arc<legado_js::JsResources> {
    ENGINE.js_resources()
}

pub(crate) fn source_login_cache() -> Arc<SourceLoginCache> {
    ENGINE.source_login_cache()
}

pub(crate) fn source_info_map() -> Arc<SourceInfoMap> {
    ENGINE.source_info_map()
}

pub(crate) fn searches() -> Arc<legado_engine::SearchTasks> {
    ENGINE.searches()
}

pub(crate) fn task_group() -> legado_engine::TaskGroup {
    ENGINE.task_group()
}
pub(crate) fn source_checks() -> Arc<legado_engine::OperationSlot> {
    ENGINE.operations(&ENGINE.source_checks)
}
pub(crate) fn source_debug() -> Arc<legado_engine::OperationSlot> {
    ENGINE.operations(&ENGINE.source_debug)
}

pub(crate) fn switches() -> Arc<legado_engine::SourceSwitchState> {
    ENGINE.switches()
}

pub(crate) fn media() -> Arc<legado_engine::MediaState> {
    ENGINE.media()
}

pub(crate) fn services() -> Arc<crate::service_host::ServiceHost> {
    ENGINE
        .services
        .get_or_init(|| Arc::new(Default::default()))
        .clone()
}

pub(crate) fn cache_downloads() -> LegadoResult<Arc<legado_engine::CacheDownloads>> {
    ENGINE.cache_downloads()
}
pub(crate) fn download_manager() -> Arc<Mutex<legado_core::download_manager::DownloadManager>> {
    ENGINE.download_manager()
}

pub(crate) fn initialize(
    build: impl FnOnce() -> LegadoResult<EngineContext>,
    configure: impl FnOnce(),
) -> LegadoResult<bool> {
    ENGINE.initialize(build, configure)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Barrier;
    use std::sync::atomic::{AtomicUsize, Ordering};

    #[test]
    fn early_check_and_debug_slots_keep_identity_and_scope_after_first_open() {
        let holder = EngineHolder::new();
        let checks = holder.operations(&holder.source_checks);
        let debug = holder.operations(&holder.source_debug);
        let check = checks.start().unwrap();
        let debugging = debug.start().unwrap();
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        assert!(Arc::ptr_eq(
            &checks,
            &holder.operations(&holder.source_checks)
        ));
        assert!(Arc::ptr_eq(
            &debug,
            &holder.operations(&holder.source_debug)
        ));
        assert_eq!(holder.current().unwrap().tasks().active_count(), 2);
        checks.cancel();
        assert!(!check.is_active());
        assert!(debugging.is_active());
        drop(holder);
        assert!(!debugging.is_active());
        assert!(debug.start().is_err());
    }

    #[test]
    fn early_search_is_registered_in_the_published_engine_without_a_root_cycle() {
        let holder = EngineHolder::new();
        let searches = holder.searches();
        let early = searches.start().unwrap();
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        assert!(Arc::ptr_eq(&searches, &holder.searches()));
        assert_eq!(holder.current().unwrap().tasks().active_count(), 1);
        assert!(!early.is_cancelled());
        assert!(
            !holder
                .initialize(|| panic!("重复开库不能清空搜索"), || {})
                .unwrap()
        );
        let weak = Arc::downgrade(&holder.current().unwrap());
        drop(holder);
        assert!(weak.upgrade().is_none());
        assert!(early.is_cancelled());
        assert!(searches.start().is_err());
    }

    #[test]
    fn early_tasks_survive_failed_initialization_and_keep_their_scope_after_open() {
        let holder = EngineHolder::new();
        let early = holder.task_group();
        let task = early.begin().unwrap();
        assert!(
            holder
                .initialize(
                    || Err(LegadoError::Internal("任务初始化失败夹具".into())),
                    || {}
                )
                .is_err()
        );
        assert!(!early.is_closed());
        assert!(!task.is_cancelled());
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        assert!(early.same_scope(holder.current().unwrap().tasks()));
        assert_eq!(holder.current().unwrap().tasks().active_count(), 1);
        assert!(
            !holder
                .initialize(|| panic!("重复开库不得重新装配任务组"), || {})
                .unwrap()
        );
        assert!(!task.is_cancelled());
        drop(holder);
        assert!(task.is_cancelled());
        assert!(early.is_closed());
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn early_js_http_resources_keep_identity_cookie_and_callbacks_after_open() {
        use legado_js::JsEngine;
        let holder = EngineHolder::new();
        let resources = holder.js_resources();
        let http = resources.http_resources().clone();
        let vm = resources
            .create_engine(legado_js::SandboxConfig::default())
            .unwrap();
        vm.eval("java.setCookie('https://early-cookie.test/read','session=early')")
            .unwrap();
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        let engine = holder.current().unwrap();
        assert!(Arc::ptr_eq(&http, engine.js_resources().http_resources()));
        assert!(Arc::ptr_eq(
            http.cookie_store(),
            engine.network().cookie_store()
        ));
        assert!(
            engine
                .storage()
                .with_database(|db| legado_db::CookieRepository::new(db.connection())
                    .get_by_tag("early-cookie.test"))
                .unwrap()
                .unwrap()
                .contains("session=early")
        );
        engine
            .network()
            .set_cookie("early-cookie.test", "session=updated")
            .unwrap();
        assert_eq!(
            vm.eval("java.getCookie('https://early-cookie.test/read','session')")
                .unwrap(),
            "updated"
        );
    }

    #[test]
    fn early_info_map_service_keeps_identity_after_database_open() {
        let holder = EngineHolder::new();
        let early = holder.source_info_map();
        early.put("source", "mode", "early");
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        let context = holder.current().unwrap();
        assert!(Arc::ptr_eq(&early, context.source_info_map()));
        assert_eq!(
            context.source_info_map().snapshot("source")["mode"],
            "early"
        );
        holder
            .initialize(|| panic!("重复开库不构造新实例"), || {})
            .unwrap();
        assert!(Arc::ptr_eq(
            &early,
            holder.current().unwrap().source_info_map()
        ));
    }

    #[test]
    fn early_source_login_cache_keeps_identity_and_binds_only_on_first_open() {
        let holder = EngineHolder::new();
        let early = holder.source_login_cache();
        early.put_login_header("source", "early-header");
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        let context = holder.current().unwrap();
        assert!(Arc::ptr_eq(&early, context.source_login_cache()));
        assert_eq!(
            context
                .storage()
                .with_database(|db| {
                    legado_db::CacheRepository::new(db.connection()).get("loginHeader_source")
                })
                .unwrap()
                .as_deref(),
            Some("early-header")
        );
        assert!(
            !holder
                .initialize(|| panic!("不能重复建库"), || panic!("不能重复配置"))
                .unwrap()
        );
        assert!(Arc::ptr_eq(
            &early,
            holder.current().unwrap().source_login_cache()
        ));
        early.put_login_info("source", "later-user");
        assert_eq!(
            context
                .source_login_cache()
                .get_login_info("source")
                .as_deref(),
            Some("later-user")
        );
    }

    #[test]
    fn failed_initialization_leaves_holder_empty_and_allows_retry() {
        let holder = EngineHolder::new();
        assert!(holder.current().is_err());
        let result = holder.initialize(
            || Err(LegadoError::Database("建库失败".into())),
            || panic!("构造失败不得运行宿主配置"),
        );
        assert!(result.is_err());
        assert!(holder.current().is_err());
        let configured = AtomicUsize::new(0);
        assert!(
            holder
                .initialize(EngineContext::in_memory, || {
                    let context = holder.current().unwrap();
                    context.storage().with_database(|_| Ok(())).unwrap();
                    configured.fetch_add(1, Ordering::Relaxed);
                })
                .unwrap()
        );
        let first = holder.current().unwrap();
        assert!(
            !holder
                .initialize(
                    || panic!("重复调用不应构造新库"),
                    || panic!("重复调用不应再次配置"),
                )
                .unwrap()
        );
        assert!(Arc::ptr_eq(&first, &holder.current().unwrap()));
        assert_eq!(configured.load(Ordering::Relaxed), 1);
    }

    #[test]
    fn early_http_client_keeps_identity_and_can_persist_after_database_open() {
        use legado_net::CookiePersistence;
        let holder = EngineHolder::new();
        let network = holder.network();
        let cache = holder.web_book_state();
        let early = network.client().unwrap();
        early
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("startup.test", "early=1");
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        let engine = holder.current().unwrap();
        assert!(Arc::ptr_eq(&network, engine.network()));
        assert!(Arc::ptr_eq(&cache, engine.web_book_state()));
        assert_eq!(
            early.client_id(),
            engine.network().client().unwrap().client_id()
        );
        early
            .cookie_persistence()
            .unwrap()
            .save("startup.test", "after=2");
        assert_eq!(
            network.cookie_persistence().load_all(),
            vec![("startup.test".to_owned(), "after=2; early=1".to_owned())]
        );
    }

    #[test]
    fn concurrent_initialization_builds_and_configures_only_once() {
        let holder = EngineHolder::new();
        let barrier = Barrier::new(8);
        let builds = AtomicUsize::new(0);
        let configured = AtomicUsize::new(0);
        std::thread::scope(|scope| {
            for _ in 0..8 {
                scope.spawn(|| {
                    barrier.wait();
                    holder
                        .initialize(
                            || {
                                builds.fetch_add(1, Ordering::Relaxed);
                                EngineContext::in_memory()
                            },
                            || {
                                configured.fetch_add(1, Ordering::Release);
                            },
                        )
                        .unwrap();
                    assert_eq!(configured.load(Ordering::Acquire), 1);
                });
            }
        });
        assert_eq!(builds.load(Ordering::Relaxed), 1);
        assert!(holder.current().is_ok());
    }

    #[tokio::test]
    async fn initialization_preserves_rate_window_used_before_database_open() {
        let holder = EngineHolder::new();
        let early = holder.rate_limiter();
        let source = legado_core::models::BookSource {
            book_source_url: "https://early-rate.test".into(),
            concurrent_rate: Some("1/10000".into()),
            ..Default::default()
        };
        early.acquire(&source).await;
        holder.initialize(EngineContext::in_memory, || {}).unwrap();
        let current = holder.current().unwrap().rate_limiter();
        assert!(Arc::ptr_eq(&early, &current));
        assert!(
            tokio::time::timeout(
                std::time::Duration::from_millis(30),
                current.acquire(&source)
            )
            .await
            .is_err()
        );
    }
}
