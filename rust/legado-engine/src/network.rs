//! 每个引擎拥有的网络资源；持久化后端只绑定该实例的数据库。

use std::sync::{Arc, Mutex, OnceLock, RwLock};

use legado_core::{LegadoError, LegadoResult};
use legado_db::CookieRepository;
use legado_net::{CookiePersistence, CookieStore, LegadoClient, LegadoClientConfig};

use crate::StorageContext;

#[derive(Default)]
struct ClientSlot {
    revision: u64,
    client: Option<LegadoClient>,
}

/// 客户端与 Cookie 的共同所有者；不持有宿主或根 EngineContext，避免引用环。
pub struct NetworkContext {
    store: Arc<RwLock<CookieStore>>,
    persistence: Arc<DbCookiePersistence>,
    clients: RwLock<ClientSlot>,
    hosts: Arc<legado_net::custom_hosts::CustomHosts>,
}

impl Default for NetworkContext {
    fn default() -> Self {
        Self {
            store: Arc::new(RwLock::new(CookieStore::new())),
            persistence: Arc::new(DbCookiePersistence::default()),
            clients: RwLock::new(ClientSlot::default()),
            hosts: Arc::new(Default::default()),
        }
    }
}

impl NetworkContext {
    /// VM 与四组 JS 客户端捕获数据服务，不反向保留 EngineContext。
    #[cfg(feature = "quickjs")]
    pub fn js_http_resources(self: &Arc<Self>) -> Arc<legado_js::http_resources::HttpResources> {
        let persistence = self.persistence.clone();
        Arc::new(
            legado_js::http_resources::HttpResources::new(
                self.store.clone(),
                Some(self.persistence.clone()),
                self.clone(),
                Arc::new(move |source| {
                    persistence
                        .storage
                        .get()?
                        .with_database(|db| {
                            legado_db::BookSourceRepository::new(db.connection())
                                .find_by_url(source)
                        })
                        .ok()
                        .flatten()
                        .and_then(|source| source.enabled_cookie_jar)
                }),
            )
            .with_custom_hosts(self.hosts.clone()),
        )
    }
    pub(crate) fn with_storage(storage: StorageContext) -> Self {
        let network = Self::default();
        // Cookie API 可早于首次网络请求使用；发布实例前补齐其唯一罐。
        let _ = network.persistence.storage.set(storage);
        network.persistence.preload(&network.store);
        network
    }

    /// 将数据库初始化前的网络实例接到成功打开的库，只允许绑定一次。
    pub(crate) fn bind_storage(&self, storage: StorageContext) -> LegadoResult<()> {
        // 全域写通道同时覆盖预载和早期内存快照，避免清除后被旧快照回填。
        legado_net::cookie_store::write_coordinator(&self.store).with_all(|| {
            let _gate = self
                .persistence
                .gate
                .lock()
                .unwrap_or_else(|p| p.into_inner());
            self.persistence
                .storage
                .set(storage)
                .map_err(|_| LegadoError::Internal("网络实例已经绑定数据库".into()))?;
            // 内存 Cookie 优先；早期请求没有持久化的值在绑定时写回本实例。
            let existing = self
                .store
                .read()
                .unwrap_or_else(|p| p.into_inner())
                .to_persisted();
            for (domain, cookie) in existing {
                if let Err(error) = self.persistence.save_locked(&domain, &cookie) {
                    log::warn!("早期 Cookie 持久化失败: {error}");
                }
            }
            self.persistence.preload_locked(&self.store);
            Ok(())
        })
    }

    pub fn custom_hosts(&self) -> &Arc<legado_net::custom_hosts::CustomHosts> {
        &self.hosts
    }

    pub fn cookie_store(&self) -> &Arc<RwLock<CookieStore>> {
        &self.store
    }

    pub fn cookie_persistence(&self) -> Arc<DbCookiePersistence> {
        self.persistence.clone()
    }

    /// WebView 等显式写入同时更新共享 jar 和数据库。
    pub fn set_cookie(&self, domain: &str, cookie: &str) -> LegadoResult<()> {
        legado_net::cookie_store::write_coordinator(&self.store)
            .with_domain(domain, || self.set_cookie_locked(domain, cookie))
    }

    /// 内部已持域通道，不能重复取得不可重入的域锁。
    fn set_cookie_locked(&self, domain: &str, cookie: &str) -> LegadoResult<()> {
        {
            let mut jar = self.store.write().unwrap_or_else(|p| p.into_inner());
            let existing = jar.domain_cookie_string(domain);
            if let Some(merged) = CookieStore::merge_cookies_str(&existing, cookie) {
                jar.set_cookies_from_string(domain, &merged);
            }
        }
        self.persistence.save_merged(domain, cookie)
    }

    /// MCP 等非 JS 入口清除同一引擎的持久层和共享 jar。
    pub fn clear_cookie_domain(&self, domain: &str) -> LegadoResult<()> {
        legado_net::cookie_store::write_coordinator(&self.store).with_domain(domain, || {
            self.persistence.delete_rows(&[domain])?;
            self.store
                .write()
                .unwrap_or_else(|p| p.into_inner())
                .remove_domain(domain);
            Ok(())
        })
    }

    /// FFI 清除入口保留先清内存、后持久化及 DB 失败上抛的行为。
    pub fn clear_cookie_keys(&self, keys: &[&str]) -> LegadoResult<()> {
        legado_net::cookie_store::write_coordinator(&self.store).with_domains(keys, || {
            {
                let mut jar = self.store.write().map_err(|e| {
                    LegadoError::Internal(format!("CookieStore 写锁 poisoned: {e}"))
                })?;
                for key in keys {
                    jar.remove_domain(key);
                }
            }
            if self.persistence.storage.get().is_some() {
                self.persistence.delete_rows(keys)?;
            }
            Ok(())
        })
    }

    fn build_client(&self, mut config: LegadoClientConfig) -> LegadoResult<LegadoClient> {
        config.custom_hosts = Some(self.hosts.clone());
        LegadoClient::with_cookie_store(config, self.store.clone(), Some(self.persistence.clone()))
            .map_err(|e| LegadoError::Network(format!("初始化共享 HTTP 客户端失败: {e}")))
    }

    /// 构造和数据库回填均在槽位锁外进行，旧构造不能跨过 reset 覆盖新配置。
    pub fn client(&self) -> LegadoResult<LegadoClient> {
        loop {
            let revision = {
                let slot = self.clients.read().unwrap_or_else(|p| p.into_inner());
                if let Some(client) = &slot.client {
                    return Ok(client.clone());
                }
                slot.revision
            };
            let built = self.build_client(LegadoClientConfig::default())?;
            let mut slot = self.clients.write().unwrap_or_else(|p| p.into_inner());
            if slot.revision != revision {
                continue;
            }
            return Ok(slot.client.get_or_insert(built).clone());
        }
    }

    pub fn reset_client(&self) {
        let mut slot = self.clients.write().unwrap_or_else(|p| p.into_inner());
        slot.revision = slot.revision.wrapping_add(1);
        slot.client = None;
    }

    /// 失败保留原客户端；并发配置中，较早发起的构造不能覆盖较新的操作。
    pub fn reset_client_with_config(&self, config: LegadoClientConfig) -> LegadoResult<()> {
        self.replace_client(|| self.build_client(config))
    }

    fn replace_client(
        &self,
        build: impl FnOnce() -> LegadoResult<LegadoClient>,
    ) -> LegadoResult<()> {
        let revision = {
            let mut slot = self.clients.write().unwrap_or_else(|p| p.into_inner());
            slot.revision = slot.revision.wrapping_add(1);
            slot.revision
        };
        let client = build()?;
        let mut slot = self.clients.write().unwrap_or_else(|p| p.into_inner());
        if slot.revision == revision {
            slot.client = Some(client);
        }
        Ok(())
    }
}

impl legado_js::host_api::cookie_store::CookieAccess for NetworkContext {
    fn get(&self, url: &str) -> String {
        self.store
            .read()
            .unwrap_or_else(|p| p.into_inner())
            .cookies_for_key(url)
    }

    fn set(&self, url: &str, cookie: &str) {
        let domain = legado_net::cookie_store::normalize_cookie_key(url);
        legado_net::cookie_store::write_coordinator(&self.store).with_domain(&domain, || {
            // 短暂修改 jar 后才持久化；未开库时仍可继续使用内存。
            let changed = {
                let mut jar = self.store.write().unwrap_or_else(|p| p.into_inner());
                let before = jar.domain_cookie_string(&domain);
                jar.set_cookies_from_string(&domain, cookie);
                before != jar.domain_cookie_string(&domain)
            };
            if changed {
                self.persistence.save(&domain, cookie);
            }
        });
    }

    fn clear(&self, url: &str) {
        let domain = legado_net::cookie_store::normalize_cookie_key(url);
        legado_net::cookie_store::write_coordinator(&self.store).with_domains(
            &[&domain, url.trim()],
            || {
                {
                    let mut jar = self.store.write().unwrap_or_else(|p| p.into_inner());
                    jar.remove_domain(&domain);
                    jar.remove_domain(url.trim());
                }
                if self.persistence.storage.get().is_some()
                    && let Err(error) = self.persistence.delete_rows(&[&domain, url.trim()])
                {
                    log::warn!("JS Cookie 删除持久化失败: {error}");
                }
            },
        );
    }

    fn clear_all(&self) {
        legado_net::cookie_store::write_coordinator(&self.store).with_all(|| {
            self.store
                .write()
                .unwrap_or_else(|p| p.into_inner())
                .clear();
            if self.persistence.storage.get().is_some()
                && let Err(error) = self.persistence.clear_rows()
            {
                log::warn!("JS Cookie 全清持久化失败: {error}");
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn late_configuration_cannot_overwrite_newer_client() {
        let network = NetworkContext::default();
        let (started_tx, started_rx) = std::sync::mpsc::channel();
        let (resume_tx, resume_rx) = std::sync::mpsc::channel();
        std::thread::scope(|scope| {
            let network = &network;
            let slow = scope.spawn(move || {
                network.replace_client(|| {
                    let old = network.build_client(LegadoClientConfig::default())?;
                    started_tx.send(()).unwrap();
                    resume_rx.recv().unwrap();
                    Ok(old)
                })
            });
            started_rx.recv().unwrap();
            network
                .reset_client_with_config(LegadoClientConfig::default())
                .unwrap();
            let latest = network.client().unwrap().client_id();
            resume_tx.send(()).unwrap();
            slow.join().unwrap().unwrap();
            assert_eq!(network.client().unwrap().client_id(), latest);
        });
    }

    #[test]
    fn failed_configuration_keeps_current_client_and_cookies() {
        let network = NetworkContext::default();
        let before = network.client().unwrap();
        network
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("config.test", "a=1");
        let config = LegadoClientConfig {
            user_agent: "invalid\nheader".into(),
            ..Default::default()
        };
        assert!(network.reset_client_with_config(config).is_err());
        assert_eq!(network.client().unwrap().client_id(), before.client_id());
        assert_eq!(
            before
                .cookie_store()
                .read()
                .unwrap()
                .get_key("config.test", "a")
                .as_deref(),
            Some("1")
        );
        network.reset_client();
        let after = network.client().unwrap();
        assert_ne!(after.client_id(), before.client_id());
        assert!(Arc::ptr_eq(before.cookie_store(), after.cookie_store()));
    }
}

/// Cookie 读改写与删除共用协调锁；后端可从纯内存阶段绑定一次 StorageContext。
#[derive(Default)]
pub struct DbCookiePersistence {
    storage: OnceLock<StorageContext>,
    gate: Mutex<()>,
}

impl DbCookiePersistence {
    fn storage(&self) -> LegadoResult<&StorageContext> {
        self.storage
            .get()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))
    }

    fn save_locked(&self, tag: &str, incoming: &str) -> LegadoResult<()> {
        self.storage()?.with_database(|db| {
            let transaction = db.immediate_transaction()?;
            let repo = CookieRepository::new(db.connection());
            let existing = repo.get_by_tag(tag)?.unwrap_or_default();
            let mut cookies = CookieStore::cookie_string_to_map(&existing);
            cookies.extend(CookieStore::cookie_string_to_map(incoming));
            let mut parts: Vec<_> = cookies
                .iter()
                .map(|(key, value)| format!("{key}={value}"))
                .collect();
            parts.sort();
            if !parts.is_empty() {
                repo.upsert(tag, &parts.join("; "))?;
            }
            transaction
                .commit()
                .map_err(|e| LegadoError::Database(e.to_string()))
        })
    }

    /// 调用者已持域写通道；不持有 jar 锁跨越本方法。
    pub fn save_merged(&self, tag: &str, incoming: &str) -> LegadoResult<()> {
        let _gate = self.gate.lock().unwrap_or_else(|p| p.into_inner());
        self.save_locked(tag, incoming)
    }

    /// 调用者已持对应域写通道；空集合不访问数据库。
    pub fn delete_rows(&self, tags: &[&str]) -> LegadoResult<()> {
        if tags.is_empty() {
            return Ok(());
        }
        let _gate = self.gate.lock().unwrap_or_else(|p| p.into_inner());
        self.storage()?.with_database(|db| {
            let transaction = db.immediate_transaction()?;
            let repo = CookieRepository::new(db.connection());
            for tag in tags {
                repo.delete_by_tag(tag)?;
            }
            transaction
                .commit()
                .map_err(|e| LegadoError::Database(e.to_string()))
        })
    }

    /// 调用者已持全域写通道。
    pub fn clear_rows(&self) -> LegadoResult<()> {
        let _gate = self.gate.lock().unwrap_or_else(|p| p.into_inner());
        self.storage()?
            .with_database(|db| CookieRepository::new(db.connection()).clear_all())
    }

    fn preload_locked(&self, store: &Arc<RwLock<CookieStore>>) {
        let entries = self.load_all();
        let mut jar = store.write().unwrap_or_else(|p| p.into_inner());
        for (domain, loaded) in entries {
            let existing = jar.domain_cookie_string(&domain);
            if let Some(merged) = CookieStore::merge_cookies_str(&loaded, &existing) {
                jar.set_cookies_from_string(&domain, &merged);
            }
        }
    }
}

impl CookiePersistence for DbCookiePersistence {
    fn load_all(&self) -> Vec<(String, String)> {
        let Some(storage) = self.storage.get() else {
            return Vec::new();
        };
        storage
            .with_database(|db| CookieRepository::new(db.connection()).find_all())
            .unwrap_or_else(|error| {
                log::warn!("加载持久化 Cookie 失败，继续使用内存: {error}");
                Vec::new()
            })
    }

    fn save(&self, tag: &str, cookie: &str) {
        // 数据库打开前保留纯内存行为；同一个后端绑定后自动启用持久化。
        if self.storage.get().is_none() {
            return;
        }
        if let Err(error) = self.save_merged(tag, cookie) {
            log::warn!("合并持久化 Cookie '{tag}' 写入失败: {error}");
        }
    }

    fn preload(&self, store: &Arc<RwLock<CookieStore>>) {
        legado_net::cookie_store::write_coordinator(store).with_all(|| {
            let _gate = self.gate.lock().unwrap_or_else(|p| p.into_inner());
            self.preload_locked(store);
        })
    }
}

#[cfg(test)]
mod hosts_instance_tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn native_and_js_clients_use_their_own_live_dns_instances() {
        let first = Arc::new(NetworkContext::default());
        let second = Arc::new(NetworkContext::default());
        // 只依赖 IPv4 回环，不要求操作系统额外配置地址别名或 IPv6。
        let one = TcpListener::bind("127.0.0.1:0").unwrap();
        let one_port = one.local_addr().unwrap().port();
        let two = TcpListener::bind("127.0.0.1:0").unwrap();
        let two_port = two.local_addr().unwrap().port();
        let threads: Vec<_> = [(one, "first"), (two, "second")].into_iter().map(|(listener, body)| {
            std::thread::spawn(move || {
                #[cfg(feature = "quickjs")] let requests = 2;
                #[cfg(not(feature = "quickjs"))] let requests = 1;
                for _ in 0..requests {
                    let (mut socket, _) = listener.accept().unwrap();
                    socket.set_read_timeout(Some(std::time::Duration::from_secs(5))).unwrap();
                    let mut bytes = Vec::new(); let mut byte = [0];
                    while !bytes.ends_with(b"\r\n\r\n") { assert_eq!(socket.read(&mut byte).unwrap(), 1); bytes.push(byte[0]); }
                    write!(socket,"HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len()).unwrap();
                }
            })
        }).collect();
        first
            .custom_hosts()
            .apply_custom_hosts(
                r#"{"engine-first.invalid":"127.0.0.1","same.invalid":"192.0.2.1"}"#,
            )
            .unwrap();
        second
            .custom_hosts()
            .apply_custom_hosts(
                r#"{"engine-second.invalid":"127.0.0.1","same.invalid":"192.0.2.2"}"#,
            )
            .unwrap();
        assert!(first.custom_hosts().apply_custom_hosts("[invalid").is_err());
        assert!(
            first
                .custom_hosts()
                .lookup_ips("engine-second.invalid")
                .is_none()
        );
        assert!(
            second
                .custom_hosts()
                .lookup_ips("engine-first.invalid")
                .is_none()
        );
        assert_ne!(
            first.custom_hosts().lookup_ips("same.invalid"),
            second.custom_hosts().lookup_ips("same.invalid")
        );
        for (network, host, port, expected) in [
            (&first, "engine-first.invalid", one_port, "first"),
            (&second, "engine-second.invalid", two_port, "second"),
        ] {
            network
                .reset_client_with_config(LegadoClientConfig {
                    no_proxy: true,
                    ..Default::default()
                })
                .unwrap();
            let url = format!("http://{host}:{port}/body");
            assert_eq!(
                network
                    .client()
                    .unwrap()
                    .get_raw(&url, None)
                    .await
                    .unwrap()
                    .body,
                expected.as_bytes()
            );
            #[cfg(feature = "quickjs")]
            {
                let js = network.js_http_resources();
                assert_eq!(
                    js.client(true, false)
                        .unwrap()
                        .get_raw(&url, None)
                        .await
                        .unwrap()
                        .body,
                    expected.as_bytes()
                );
            }
        }
        for thread in threads {
            thread.join().unwrap();
        }
    }
}
