//! VM 只捕获网络数据能力，不捕获拥有 VM 缓存的根对象。
#![cfg(feature = "quickjs")]

use legado_net::client::ClientTimeoutPolicy;
use legado_net::{CookiePersistence, CookieStore, LegadoClient, LegadoClientConfig};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

pub use crate::host_api::cookie_store::CookieAccess;

pub type SourceCookieJarLookup = Arc<dyn Fn(&str) -> Option<bool> + Send + Sync>;

#[derive(Default)]
struct Pools {
    revision: u64,
    clients: [Option<LegadoClient>; 12],
}

/// 各策略池共享同一罐；按需构建，构造不持槽位锁跨数据库预载。
pub struct HttpResources {
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
        crate::host_api::runtime_bridge::block_on(async {
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

    pub fn request_for(&self, source: Option<&str>) -> RequestResources<'_> {
        RequestResources {
            http: self,
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
        let policy_index = match timeout_policy {
            ClientTimeoutPolicy::Default => 0,
            ClientTimeoutPolicy::NoTotalTimeout => 1,
            ClientTimeoutPolicy::Unlimited => 2,
        };
        let index = usize::from(loopback) + usize::from(no_redirect) * 2 + policy_index * 4;
        loop {
            let revision = {
                let pools = self.pools.read().unwrap_or_else(|p| p.into_inner());
                if let Some(client) = &pools.clients[index] {
                    return Ok(client.clone());
                }
                pools.revision
            };
            let config = LegadoClientConfig {
                no_proxy: loopback,
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
            .map_err(|error| format!("build client error: {error}"))?;
            let mut pools = self.pools.write().unwrap_or_else(|p| p.into_inner());
            if pools.revision != revision {
                continue;
            }
            return Ok(pools.clients[index].get_or_insert(built).clone());
        }
    }

    pub fn reset_clients(&self) {
        let mut pools = self.pools.write().unwrap_or_else(|p| p.into_inner());
        pools.revision = pools.revision.wrapping_add(1);
        pools.clients = Default::default();
    }
}

/// 固定来源开关和头，不跨异步边界访问线程局部状态。
pub struct RequestResources<'a> {
    pub http: &'a HttpResources,
    pub cookie_jar_enabled: bool,
    pub headers: HashMap<String, String>,
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
