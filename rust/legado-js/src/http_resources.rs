//! VM 只捕获网络数据能力，不捕获拥有 VM 缓存的根对象。
#![cfg(feature = "quickjs")]

use legado_net::client::ClientTimeoutPolicy;
use legado_net::{CookiePersistence, CookieStore, LegadoClient, LegadoClientConfig};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

pub use crate::host_api::cookie_store::CookieAccess;

pub type SourceCookieJarLookup = Arc<dyn Fn(&str) -> Option<bool> + Send + Sync>;

// 缓存键可能携带认证信息，不派生Debug或输出到日志。
#[derive(Clone, PartialEq, Eq, Hash)]
struct RouteKey {
    index: usize,
    proxy: Option<String>,
    dns_addresses: Vec<std::net::IpAddr>,
}

const ROUTE_CACHE_CAPACITY: usize = 32;
struct Pools {
    revision: u64,
    clients: [Option<LegadoClient>; 12],
    routes: lru::LruCache<RouteKey, LegadoClient>,
}
impl Default for Pools {
    fn default() -> Self {
        Self {
            revision: 0,
            clients: Default::default(),
            routes: lru::LruCache::new(std::num::NonZeroUsize::new(ROUTE_CACHE_CAPACITY).unwrap()),
        }
    }
}

/// 各策略池共享同一罐；按需构建，构造不持槽位锁跨数据库预载。
pub struct HttpResources {
    request_policy: RwLock<Option<Arc<dyn crate::http_request_policy::HttpRequestPolicy>>>,
    hosts: Arc<legado_net::custom_hosts::CustomHosts>,
    store: Arc<RwLock<CookieStore>>,
    persistence: Option<Arc<dyn CookiePersistence>>,
    cookies: Arc<dyn CookieAccess>,
    lookup: SourceCookieJarLookup,
    headers: RwLock<HashMap<String, HashMap<String, String>>>,
    pools: RwLock<Pools>,
    fonts: crate::host_api::font_api::FontResources,
    files: crate::host_api::resource_files::ResourceFiles,
    file_operations: legado_core::write_coordinator::KeyedWriteCoordinator,
    js_libs: std::sync::Mutex<lru::LruCache<String, String>>,
}

impl Default for HttpResources {
    fn default() -> Self {
        Self::with_memory_cookie_store(Arc::new(RwLock::new(CookieStore::new())))
    }
}

impl HttpResources {
    /// 最小宿主共用已注入客户端的内存罐；持久化宿主应显式提供完整 CookieAccess。
    pub fn with_memory_cookie_store(store: Arc<RwLock<CookieStore>>) -> Self {
        Self::new(
            store.clone(),
            None,
            Arc::new(MemoryCookies(store)),
            Arc::new(|_| None),
        )
    }

    pub fn new(
        store: Arc<RwLock<CookieStore>>,
        persistence: Option<Arc<dyn CookiePersistence>>,
        cookies: Arc<dyn CookieAccess>,
        lookup: SourceCookieJarLookup,
    ) -> Self {
        Self {
            request_policy: RwLock::new(None),
            hosts: Arc::new(Default::default()),
            store,
            persistence,
            cookies,
            lookup,
            headers: Default::default(),
            pools: Default::default(),
            fonts: Default::default(),
            files: Default::default(),
            file_operations: Default::default(),
            js_libs: std::sync::Mutex::new(lru::LruCache::new(
                std::num::NonZeroUsize::new(64).unwrap(),
            )),
        }
    }

    pub fn with_custom_hosts(mut self, hosts: Arc<legado_net::custom_hosts::CustomHosts>) -> Self {
        self.hosts = hosts;
        self.reset_clients();
        self
    }

    /// 更新宿主策略而不重建VM/客户端；等待时不持有此锁。
    pub fn set_request_policy(
        &self,
        policy: Arc<dyn crate::http_request_policy::HttpRequestPolicy>,
    ) {
        *self
            .request_policy
            .write()
            .unwrap_or_else(|p| p.into_inner()) = Some(policy);
    }

    pub(crate) fn fonts(&self) -> &crate::host_api::font_api::FontResources {
        &self.fonts
    }

    pub(crate) fn file_cache_dir(&self) -> Result<std::path::PathBuf, String> {
        self.files.directory()
    }

    pub(crate) fn with_file_cache<T>(&self, url: &str, operation: impl FnOnce() -> T) -> T {
        self.file_operations.with_domain(url, operation)
    }

    pub(crate) fn publish_file_cache(
        &self,
        name: &str,
        bytes: &[u8],
    ) -> Result<std::path::PathBuf, String> {
        self.files.publish(name, bytes)
    }

    pub(crate) fn download_font(&self, url: &str) -> Result<Vec<u8>, String> {
        crate::host_api::runtime_bridge::block_on_cancellable(async {
            let client = self
                .client_for_url(url, false)
                .map_err(|e| format!("build client error: {e}"))?;
            let response = client
                .get_raw(url, None)
                .await
                .map_err(|e| format!("download font error: {e}"))?;
            if !response.is_success() {
                return Err(format!("download font http status {}", response.status));
            }
            Ok(response.body)
        })
    }

    pub fn cookie_store(&self) -> &Arc<RwLock<CookieStore>> {
        &self.store
    }

    pub(crate) fn cached_js_lib(&self, key: &str) -> Option<String> {
        self.js_libs
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .get(key)
            .cloned()
    }

    pub(crate) fn cache_js_lib(&self, key: String, body: String) {
        self.js_libs
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .put(key, body);
    }

    pub fn client_for_url(&self, url: &str, no_redirect: bool) -> Result<LegadoClient, String> {
        self.client(crate::host_api::network::is_loopback_url(url), no_redirect)
    }
    pub fn cookies(&self) -> &Arc<dyn CookieAccess> {
        &self.cookies
    }

    /// 桥接和请求的空 URL 不携带 Cookie；getCookie 本身保持原键查询语义。
    pub fn cookies_for_url(&self, url: &str) -> String {
        if url.trim().is_empty() {
            String::new()
        } else {
            self.cookies.get(url)
        }
    }

    /// setCookie 保留空值，忽略无等号或空键；与原绑定批量写入口一致。
    pub fn set_cookie(&self, url: &str, cookie: &str) {
        if crate::cancellation::is_cancelled() {
            return;
        }
        let pairs: Vec<_> = cookie
            .split(';')
            .filter_map(|pair| {
                let (key, value) = pair.trim().split_once('=')?;
                let key = key.trim();
                (!key.is_empty()).then(|| format!("{key}={}", value.trim()))
            })
            .collect();
        if !pairs.is_empty() {
            self.cookies.set(url, &pairs.join("; "));
        }
    }

    /// replaceCookie 的既有语义跳过空新值，现存同名空值不因此被删除。
    pub fn replace_cookie(&self, url: &str, cookie: &str) {
        if crate::cancellation::is_cancelled() {
            return;
        }
        if url.trim().is_empty() || cookie.trim().is_empty() {
            return;
        }
        if self.cookies.get(url).trim().is_empty() {
            self.set_cookie(url, cookie);
        } else if let Some(value) = crate::host_api::cookie_store::map_to_cookie_str(
            &crate::host_api::cookie_store::cookie_str_to_map(cookie),
        ) {
            self.cookies.set(url, &value);
        }
    }

    pub fn put_headers(&self, source: &str, headers: HashMap<String, String>) {
        let mut values = self.headers.write().unwrap_or_else(|p| p.into_inner());
        if headers.is_empty() {
            values.remove(source);
        } else {
            values.insert(source.to_string(), headers);
        }
    }

    pub fn headers_for(&self, source: &str) -> HashMap<String, String> {
        self.headers
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .get(source)
            .cloned()
            .unwrap_or_default()
    }

    /// 仅在同步 JS 入口调用；异步路径只消费返回的快照。
    pub fn request(&self) -> RequestResources<'_> {
        self.request_for(crate::host_api::current_source::current_source_tag().as_deref())
    }

    pub fn request_with_webview(
        &self,
        manager: &Arc<legado_core::webview_channel::WebViewManager>,
    ) -> RequestResources<'_> {
        let mut request = self.request();
        request.webview = Some(manager.clone());
        request
    }

    pub fn request_for(&self, source: Option<&str>) -> RequestResources<'_> {
        RequestResources {
            http: self,
            webview: None,
            cancellation: crate::cancellation::current(),
            source: source.map(str::to_owned),
            cookie_jar_enabled: source.and_then(|source| (self.lookup)(source)) == Some(true),
            headers: source
                .map(|source| self.headers_for(source))
                .unwrap_or_default(),
        }
    }

    pub fn client(&self, loopback: bool, no_redirect: bool) -> Result<LegadoClient, String> {
        self.client_with_timeout_policy(loopback, no_redirect, ClientTimeoutPolicy::Default)
    }

    pub(crate) fn client_with_timeout_policy(
        &self,
        loopback: bool,
        no_redirect: bool,
        timeout_policy: ClientTimeoutPolicy,
    ) -> Result<LegadoClient, String> {
        self.routed_client(loopback, no_redirect, timeout_policy, None, Vec::new())
    }

    /// 配置按请求固定，建池不持锁跨Cookie预载；reset时丢弃过期构建结果。
    pub(crate) fn routed_client(
        &self,
        loopback: bool,
        no_redirect: bool,
        timeout_policy: ClientTimeoutPolicy,
        proxy: Option<legado_net::ProxyConfig>,
        dns_addresses: Vec<std::net::IpAddr>,
    ) -> Result<LegadoClient, String> {
        let policy_index = match timeout_policy {
            ClientTimeoutPolicy::Default => 0,
            ClientTimeoutPolicy::NoTotalTimeout => 1,
            ClientTimeoutPolicy::Unlimited => 2,
        };
        let index = usize::from(loopback) + usize::from(no_redirect) * 2 + policy_index * 4;
        let key = RouteKey {
            index,
            proxy: proxy.as_ref().map(|p| p.effective_url()),
            dns_addresses,
        };
        let routed = key.proxy.is_some() || !key.dns_addresses.is_empty();
        loop {
            let revision = {
                if routed {
                    let mut pools = self.pools.write().unwrap_or_else(|p| p.into_inner());
                    if let Some(client) = pools.routes.get(&key) {
                        return Ok(client.clone());
                    }
                    pools.revision
                } else {
                    let pools = self.pools.read().unwrap_or_else(|p| p.into_inner());
                    if let Some(client) = &pools.clients[index] {
                        return Ok(client.clone());
                    }
                    pools.revision
                }
            };
            let config = LegadoClientConfig {
                no_proxy: loopback,
                proxy: proxy.clone(),
                dns_addresses: key.dns_addresses.clone(),
                custom_hosts: Some(self.hosts.clone()),
                follow_redirects: !no_redirect,
                timeout_policy,
                ..Default::default()
            };
            let built = LegadoClient::with_cookie_store(
                config,
                self.store.clone(),
                self.persistence.clone(),
            )
            .map_err(|error| {
                if key.proxy.is_some() {
                    "请求代理客户端构建失败".to_string()
                } else {
                    format!("build client error: {error}")
                }
            })?;
            let mut pools = self.pools.write().unwrap_or_else(|p| p.into_inner());
            if pools.revision != revision {
                continue;
            }
            if routed {
                if let Some(client) = pools.routes.get(&key) {
                    return Ok(client.clone());
                }
                pools.routes.put(key, built.clone());
                return Ok(built);
            }
            return Ok(pools.clients[index].get_or_insert(built).clone());
        }
    }

    pub fn reset_clients(&self) {
        let mut pools = self.pools.write().unwrap_or_else(|p| p.into_inner());
        pools.revision = pools.revision.wrapping_add(1);
        pools.clients = Default::default();
        pools.routes.clear();
    }
}

/// 固定来源开关和头，不跨异步边界访问线程局部状态。
pub struct RequestResources<'a> {
    cancellation: Option<Arc<dyn crate::cancellation::JsCancellation>>,
    pub http: &'a HttpResources,
    pub webview: Option<Arc<legado_core::webview_channel::WebViewManager>>,
    pub source: Option<String>,
    pub cookie_jar_enabled: bool,
    pub headers: HashMap<String, String>,
}

impl RequestResources<'_> {
    pub(crate) fn webview_active_check(&self) -> Option<legado_core::webview_channel::ActiveCheck> {
        self.cancellation.clone().map(|control| {
            Arc::new(move || !control.is_cancelled()) as legado_core::webview_channel::ActiveCheck
        })
    }
    pub(crate) fn check_active(&self) -> legado_core::LegadoResult<()> {
        if self
            .cancellation
            .as_ref()
            .is_some_and(|control| control.is_cancelled())
        {
            Err(crate::cancellation::error())
        } else {
            Ok(())
        }
    }
    pub fn policy(&self) -> Result<crate::http_request_policy::RequestPolicySnapshot, String> {
        let policy = self
            .http
            .request_policy
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .clone();
        policy.map_or_else(
            || Ok(Default::default()),
            |policy| policy.snapshot(self.source.as_deref()),
        )
    }
}

struct MemoryCookies(Arc<RwLock<CookieStore>>);

/// 没有数据库的独立 VM 仍使用其请求池的同一罐，不生成另一个 JS 镜像。
impl CookieAccess for MemoryCookies {
    fn get(&self, url: &str) -> String {
        self.0
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .cookies_for_key(url)
    }
    fn set(&self, url: &str, cookie: &str) {
        let domain = legado_net::cookie_store::normalize_cookie_key(url);
        legado_net::cookie_store::write_coordinator(&self.0).with_domain(&domain, || {
            self.0
                .write()
                .unwrap_or_else(|p| p.into_inner())
                .set_cookies_from_string(&domain, cookie);
        });
    }
    fn clear(&self, url: &str) {
        let domain = legado_net::cookie_store::normalize_cookie_key(url);
        legado_net::cookie_store::write_coordinator(&self.0).with_domains(
            &[&domain, url.trim()],
            || {
                let mut jar = self.0.write().unwrap_or_else(|p| p.into_inner());
                jar.remove_domain(&domain);
                jar.remove_domain(url.trim());
            },
        );
    }
    fn clear_all(&self) {
        legado_net::cookie_store::write_coordinator(&self.0).with_all(|| {
            self.0.write().unwrap_or_else(|p| p.into_inner()).clear();
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::JsEngine;

    #[test]
    fn route_cache_is_bounded_reused_reset_and_owned_by_instance() {
        use ClientTimeoutPolicy::*;
        let resources = HttpResources::default();
        let route = || vec!["127.0.0.1".parse().unwrap()];
        let first = resources
            .routed_client(true, false, Default, None, route())
            .unwrap();
        let again = resources
            .routed_client(true, false, Default, None, route())
            .unwrap();
        assert_eq!(first.client_id(), again.client_id());
        assert!(Arc::ptr_eq(first.cookie_store(), resources.cookie_store()));
        for policy in [NoTotalTimeout, Unlimited] {
            let variant = resources
                .routed_client(true, false, policy, None, route())
                .unwrap();
            assert_ne!(first.client_id(), variant.client_id());
            assert!(Arc::ptr_eq(first.cookie_store(), variant.cookie_store()));
        }
        let other = HttpResources::default()
            .routed_client(true, false, Default, None, route())
            .unwrap();
        assert!(!Arc::ptr_eq(first.cookie_store(), other.cookie_store()));
        let proxy = |value: &str| Some(legado_net::parse_proxy_config(value).unwrap());
        let auth = resources
            .routed_client(
                true,
                false,
                Default,
                proxy("http://user:pass@127.0.0.1:8080"),
                Vec::new(),
            )
            .unwrap();
        let legacy = resources
            .routed_client(
                true,
                false,
                Default,
                proxy("http://127.0.0.1:8080@user@pass"),
                Vec::new(),
            )
            .unwrap();
        assert_eq!(auth.client_id(), legacy.client_id());
        let different = resources
            .routed_client(
                true,
                false,
                Default,
                proxy("http://user:other@127.0.0.1:8080"),
                Vec::new(),
            )
            .unwrap();
        assert_ne!(
            auth.client_id(),
            different.client_id(),
            "不同认证不能复用同一代理连接池"
        );
        assert!(Arc::ptr_eq(auth.cookie_store(), first.cookie_store()));
        for i in 2..=40 {
            resources
                .routed_client(
                    true,
                    false,
                    Default,
                    None,
                    vec![std::net::Ipv4Addr::new(127, 0, 0, i).into()],
                )
                .unwrap();
        }
        assert_eq!(
            resources.pools.read().unwrap().routes.len(),
            ROUTE_CACHE_CAPACITY
        );
        let rebuilt = resources
            .routed_client(true, false, Default, None, route())
            .unwrap();
        assert_ne!(first.client_id(), rebuilt.client_id());
        resources.reset_clients();
        assert!(resources.pools.read().unwrap().routes.is_empty());
        let reset = resources
            .routed_client(true, false, Default, None, route())
            .unwrap();
        assert_ne!(rebuilt.client_id(), reset.client_id());
        assert!(Arc::ptr_eq(first.cookie_store(), reset.cookie_store()));
    }

    #[test]
    fn timeout_policy_pools_reuse_and_reset_with_one_cookie_store() {
        let resources = HttpResources::default();
        let mut clients = Vec::new();
        for policy in [
            ClientTimeoutPolicy::Default,
            ClientTimeoutPolicy::NoTotalTimeout,
            ClientTimeoutPolicy::Unlimited,
        ] {
            for (loopback, no_redirect) in
                [(false, false), (true, false), (false, true), (true, true)]
            {
                let first = resources
                    .client_with_timeout_policy(loopback, no_redirect, policy)
                    .unwrap();
                let again = resources
                    .client_with_timeout_policy(loopback, no_redirect, policy)
                    .unwrap();
                assert_eq!(first.client_id(), again.client_id());
                assert!(Arc::ptr_eq(first.cookie_store(), resources.cookie_store()));
                assert!(clients.iter().all(|id| *id != first.client_id()));
                clients.push(first.client_id());
            }
        }
        resources.reset_clients();
        for policy in [
            ClientTimeoutPolicy::Default,
            ClientTimeoutPolicy::NoTotalTimeout,
            ClientTimeoutPolicy::Unlimited,
        ] {
            let next = resources
                .client_with_timeout_policy(true, true, policy)
                .unwrap();
            assert!(!clients.contains(&next.client_id()));
            assert!(Arc::ptr_eq(next.cookie_store(), resources.cookie_store()));
        }
    }

    #[test]
    fn headers_are_owned_by_source_and_instance_and_empty_write_removes_them() {
        let one = HttpResources::default();
        let two = HttpResources::default();
        one.put_headers("one", HashMap::from([("X-One".into(), "one".into())]));
        one.put_headers("two", HashMap::from([("X-Two".into(), "two".into())]));
        assert_eq!(one.headers_for("one").get("X-One").unwrap(), "one");
        assert!(!one.headers_for("one").contains_key("X-Two"));
        assert!(two.headers_for("one").is_empty());
        let snapshot = one.request_for(Some("one"));
        one.put_headers("one", HashMap::new());
        assert!(one.headers_for("one").is_empty());
        assert_eq!(snapshot.headers.get("X-One").unwrap(), "one");
    }

    #[test]
    fn same_variables_with_different_http_owner_rebuild_cached_vm() {
        let resources = crate::JsResources::default();
        let second = resources
            .clone()
            .with_http_resources(Arc::new(HttpResources::default()));
        let cache = crate::engine_cache::EngineCache::default();
        let first = cache
            .get_or_create_with_resources("source", None, None, None, &resources)
            .unwrap()
            .engine;
        first
            .lock()
            .unwrap()
            .eval("java.setCookie('https://cookie.test','a=one');globalThis.marker='one'")
            .unwrap();
        let next = cache
            .get_or_create_with_resources("source", None, None, None, &second)
            .unwrap()
            .engine;
        assert!(!Arc::ptr_eq(&first, &next));
        assert_eq!(
            next.lock()
                .unwrap()
                .eval("java.getCookie('https://cookie.test')+'|'+typeof marker")
                .unwrap(),
            "|undefined"
        );
    }

    #[test]
    fn standalone_vms_have_independent_cookies_and_preserve_native_input_rules() {
        let a = crate::QuickJsEngine::new(crate::SandboxConfig::default()).unwrap();
        let b = crate::QuickJsEngine::new(crate::SandboxConfig::default()).unwrap();
        a.eval("java.setCookie('https://cookie.test','a=one; empty=; bad; =bad; eq=x=y')")
            .unwrap();
        assert_eq!(
            a.eval("java.getCookie('https://cookie.test','eq')")
                .unwrap(),
            "x=y"
        );
        assert_eq!(
            a.eval("java.getCookie('https://cookie.test','bad')")
                .unwrap(),
            ""
        );
        assert_eq!(b.eval("java.getCookie('https://cookie.test')").unwrap(), "");
        a.eval("java.replaceCookie('https://cookie.test','a=; other=new')")
            .unwrap();
        assert_eq!(
            a.eval("java.getCookie('https://cookie.test','a')").unwrap(),
            "one"
        );
        assert!(
            a.http_resources()
                .cookies()
                .get("https://cookie.test")
                .contains("empty=")
        );
        assert_eq!(
            a.eval("java.removeCookie('https://cookie.test')").unwrap(),
            ""
        );
        assert_eq!(a.eval("java.getCookie('https://cookie.test')").unwrap(), "");
    }
}
