//! 所属引擎资源持有的 QuickJS VM 缓存。
//!
//! 缓存引擎只用于非词法脚本；调用方通过 Mutex 串行化同一引擎的 eval。

#![cfg(feature = "quickjs")]

use crate::engine::{JsEngine, QuickJsEngine};
use crate::host_api::quickjs_impl::{JSOUP_BRIDGE_JS, RESPONSE_BRIDGE_JS};
use crate::sandbox::SandboxConfig;
use legado_core::{LegadoError, LegadoResult};
use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, Mutex};

// [体检 §三.14] 与 SEARCH_CONCURRENCY=32 对齐:多源跨源并发时避免 LRU 抖动
// (缓存外的源每次 eval 仍需重挂 587KB jsLib,批次 A 收益会被打折)
/// 每份执行资源的缓存容量上限（LRU 驱逐阈值）。
pub const MAX_ENTRIES: usize = 32;
type SharedEngine = Arc<Mutex<QuickJsEngine>>;
/// 缓存取得的 VM 及其本次初始化结果；错误不从进程台账回读。
#[derive(Clone)]
pub struct CachedEngine {
    pub engine: SharedEngine,
    pub main_js_ok: Option<bool>,
    pub js_lib_error: Option<String>,
}

struct Entry {
    cached: CachedEngine,
    js_lib: String,
    setup_script: String,
    main_js: String,
    variable_owner: Option<std::sync::Weak<crate::variables::VariableStore>>,
    login_owner: Option<std::sync::Weak<dyn crate::source_login::SourceLoginStore>>,
    http_owner: Option<std::sync::Weak<crate::http_resources::HttpResources>>,
    host_owner: Option<std::sync::Weak<crate::host_resources::JsHostResources>>,
}
#[derive(Default)]
struct Store {
    entries: HashMap<String, Entry>,
    order: VecDeque<String>,
}

/// 同一资源内串行更新 LRU；缓存的 VM 不持有本缓存的强引用。
#[derive(Default)]
pub struct EngineCache {
    store: Mutex<Store>,
}

fn init_engine(
    key: &str,
    js_lib: &str,
    setup_script: &str,
    main_js: &str,
    capabilities: Capabilities<'_>,
) -> LegadoResult<CachedEngine> {
    let config = SandboxConfig::default()
        .with_allow_script_run(true)
        .with_memory_limit(64 * 1024 * 1024);
    let variables = capabilities.variables;
    // 缓存 VM 只持有裸存储及登录数据服务，不长期持有首个流程。
    let engine = QuickJsEngine::new_with_capabilities(
        config,
        variables.map(|scope| scope.store().unscoped()),
        capabilities.login.cloned(),
        capabilities.http.cloned(),
        capabilities.host.cloned(),
    )?;
    let eval = |code: &str| match variables {
        Some(scope) => engine.eval_with_variables(code, &[], scope),
        None => engine.eval(code),
    };
    let mut main_js_ok: Option<bool> = None;
    let mut js_lib_error = None;
    for (name, code) in [
        ("jsLib", js_lib),
        ("setup", setup_script),
        ("Response 桥", RESPONSE_BRIDGE_JS),
        ("Jsoup 桥", JSOUP_BRIDGE_JS),
        ("mainJs", main_js),
    ] {
        if code.is_empty() {
            continue;
        }
        match eval(code) {
            Ok(_) => {
                if name == "mainJs" {
                    main_js_ok = Some(true);
                }
            }
            Err(first_err) => {
                // 区分语法错误与运行时错误：仅对语法错误尝试 Rhino 宽容语法归一化后重试一次
                // （对齐原版 corejs-Rhino 的宽松解析，如 B 站 jsLib 的 let 参数影子重声明、
                // data..item_null 双点笔误）；运行时错误按原样降级（原版 evaluateJsLib
                // 无 catch，语义一致）。
                let mut recovered = false;
                if engine.check_syntax(code).is_err() {
                    let (normalized, changed) = crate::jslib_normalize::normalize(code);
                    if changed {
                        match eval(&normalized) {
                            Ok(_) => {
                                eprintln!(
                                    "[legado-js] 缓存引擎 {} {} 经 Rhino 宽容语法归一化后加载成功（原错误: {}）",
                                    key, name, first_err
                                );
                                recovered = true;
                            }
                            Err(e2) => eprintln!(
                                "[legado-js] 缓存引擎 {} {} 归一化后仍失败（降级继续）: {}",
                                key, name, e2
                            ),
                        }
                    }
                }
                if recovered {
                    if name == "mainJs" {
                        main_js_ok = Some(true);
                    }
                } else {
                    eprintln!(
                        "[legado-js] 缓存引擎 {} {} 加载失败（降级继续）: {}",
                        key, name, first_err
                    );
                    if name == "mainJs" {
                        main_js_ok = Some(false);
                    }
                    if name == "jsLib" {
                        js_lib_error = Some(first_err.to_string());
                        // 保留诊断台账；调用方的异常原因只使用本次返回结果。
                        crate::host_api::capability_ledger::record_jslib_load_failure(
                            key,
                            &first_err.to_string(),
                        );
                    }
                }
            }
        }
    }
    Ok(CachedEngine {
        engine: Arc::new(Mutex::new(engine)),
        main_js_ok,
        js_lib_error,
    })
}

#[derive(Clone, Copy, Default)]
struct Capabilities<'a> {
    variables: Option<&'a crate::variables::VariableScope>,
    login: Option<&'a Arc<dyn crate::source_login::SourceLoginStore>>,
    http: Option<&'a Arc<crate::http_resources::HttpResources>>,
    host: Option<&'a Arc<crate::host_resources::JsHostResources>>,
}

impl EngineCache {
    /// 获取带初始化上下文的缓存引擎；jsLib/setup 变化会重建对应条目。
    pub fn get_or_create(
        &self,
        key: &str,
        js_lib: Option<&str>,
        setup_script: Option<&str>,
        main_js: Option<&str>,
    ) -> LegadoResult<CachedEngine> {
        self.get_or_create_with_variables(key, js_lib, setup_script, main_js, None)
    }

    /// 缓存身份包含变量存储；流程身份不进入缓存键，每次执行单独绑定。
    pub fn get_or_create_with_variables(
        &self,
        key: &str,
        js_lib: Option<&str>,
        setup_script: Option<&str>,
        main_js: Option<&str>,
        variables: Option<&crate::variables::VariableScope>,
    ) -> LegadoResult<CachedEngine> {
        self.get_or_create_inner(
            key,
            js_lib,
            setup_script,
            main_js,
            Capabilities {
                variables,
                login: None,
                http: None,
                host: None,
            },
        )
    }

    /// 同时核对变量与登录服务身份；执行时只切换流程，不切换服务。
    pub fn get_or_create_with_resources(
        &self,
        key: &str,
        js_lib: Option<&str>,
        setup_script: Option<&str>,
        main_js: Option<&str>,
        resources: &crate::JsResources,
    ) -> LegadoResult<CachedEngine> {
        self.get_or_create_inner(
            key,
            js_lib,
            setup_script,
            main_js,
            Capabilities {
                variables: resources.variable_scope(),
                login: resources.source_login_store(),
                http: Some(resources.http_resources()),
                host: Some(resources.host_resources()),
            },
        )
    }

    fn get_or_create_inner(
        &self,
        key: &str,
        js_lib: Option<&str>,
        setup_script: Option<&str>,
        main_js: Option<&str>,
        capabilities: Capabilities<'_>,
    ) -> LegadoResult<CachedEngine> {
        let variables = capabilities.variables;
        let lib = js_lib.unwrap_or("");
        let setup = setup_script.unwrap_or("");
        let main = main_js.unwrap_or("");
        let mut guard = self
            .store
            .lock()
            .map_err(|_| LegadoError::JsEngine("缓存锁中毒".into()))?;
        let same = guard
            .entries
            .get(key)
            .map(|e| {
                let same_owner = match (&e.variable_owner, variables) {
                    (None, None) => true,
                    (Some(owner), Some(scope)) => owner
                        .upgrade()
                        .is_some_and(|owner| Arc::ptr_eq(&owner, scope.store())),
                    _ => false,
                };
                let same_login = match (&e.login_owner, capabilities.login) {
                    (None, None) => true,
                    (Some(owner), Some(login)) => owner
                        .upgrade()
                        .is_some_and(|owner| Arc::ptr_eq(&owner, login)),
                    _ => false,
                };
                let same_http = match (&e.http_owner, capabilities.http) {
                    (None, None) => true,
                    (Some(owner), Some(http)) => owner
                        .upgrade()
                        .is_some_and(|owner| Arc::ptr_eq(&owner, http)),
                    _ => false,
                };
                let same_host = match (&e.host_owner, capabilities.host) {
                    (None, None) => true,
                    (Some(owner), Some(host)) => owner
                        .upgrade()
                        .is_some_and(|owner| Arc::ptr_eq(&owner, host)),
                    _ => false,
                };
                e.js_lib == lib
                    && e.setup_script == setup
                    && e.main_js == main
                    && same_owner
                    && same_login
                    && same_http
                    && same_host
            })
            .unwrap_or(false);
        if same {
            let entry = guard.entries.get(key).unwrap();
            let cached = entry.cached.clone();
            guard.order.retain(|k| k != key);
            guard.order.push_back(key.to_string());
            return Ok(cached);
        }
        guard.entries.remove(key);
        guard.order.retain(|k| k != key);
        let cached = init_engine(key, lib, setup, main, capabilities)?;
        guard.entries.insert(
            key.to_string(),
            Entry {
                cached: cached.clone(),
                js_lib: lib.to_string(),
                setup_script: setup.to_string(),
                main_js: main.to_string(),
                variable_owner: variables.map(|scope| Arc::downgrade(scope.store())),
                login_owner: capabilities.login.map(Arc::downgrade),
                http_owner: capabilities.http.map(Arc::downgrade),
                host_owner: capabilities.host.map(Arc::downgrade),
            },
        );
        guard.order.push_back(key.to_string());
        while guard.entries.len() > MAX_ENTRIES {
            if let Some(old) = guard.order.pop_front() {
                guard.entries.remove(&old);
            }
        }
        Ok(cached)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn different_variable_owners_cannot_reuse_same_cache_entry() {
        let cache = EngineCache::default();
        let one = Arc::new(crate::variables::VariableStore::default());
        let two = Arc::new(crate::variables::VariableStore::default());
        let a = one.flow("same-book");
        let b = two.flow("same-book");
        let first = cache
            .get_or_create_with_variables("same-tag", None, None, None, Some(&a))
            .unwrap()
            .engine;
        first
            .lock()
            .unwrap()
            .eval("globalThis.marker='one'")
            .unwrap();
        let second = cache
            .get_or_create_with_variables("same-tag", None, None, None, Some(&b))
            .unwrap()
            .engine;
        assert!(!Arc::ptr_eq(&first, &second));
        assert_eq!(
            second.lock().unwrap().eval("typeof marker").unwrap(),
            "undefined"
        );
        let same = cache
            .get_or_create_with_variables("same-tag", None, None, None, Some(&b))
            .unwrap()
            .engine;
        assert!(Arc::ptr_eq(&second, &same));
    }

    #[test]
    fn lru_never_exceeds_max() {
        let cache = EngineCache::default();
        // 插入量须超过上限才会触发 LRU 逐出（MAX_ENTRIES 8→32 后原 10 条不再越界）
        for i in 0..(MAX_ENTRIES + 2) {
            let _ = cache
                .get_or_create(&format!("cache-test-{i}"), None, None, None)
                .unwrap();
        }
        assert_eq!(cache.store.lock().unwrap().entries.len(), MAX_ENTRIES);
    }

    #[test]
    fn changing_initialization_scripts_rebuilds_entry() {
        let cache = EngineCache::default();
        let first = cache
            .get_or_create(
                "invalidate",
                Some("function marker(){ return 1; }"),
                None,
                None,
            )
            .unwrap()
            .engine;
        assert_eq!(first.lock().unwrap().eval("marker()").unwrap(), "1");
        let second = cache
            .get_or_create(
                "invalidate",
                Some("function marker(){ return 2; }"),
                None,
                None,
            )
            .unwrap()
            .engine;
        assert_eq!(second.lock().unwrap().eval("marker()").unwrap(), "2");
    }

    #[test]
    fn dropping_cache_releases_initialized_vm_and_host_callbacks() {
        let cache = EngineCache::default();
        let engine = cache
            .get_or_create("release", None, None, None)
            .unwrap()
            .engine;
        assert_eq!(
            engine
                .lock()
                .unwrap()
                .eval("java.md5Encode('hello').length > 0")
                .unwrap(),
            "true"
        );
        let weak = Arc::downgrade(&engine);
        drop(engine);
        assert!(weak.upgrade().is_some());
        drop(cache);
        assert!(weak.upgrade().is_none(), "宿主回调不得经全局缓存保活 VM");
    }

    #[test]
    fn lru_reuses_recent_vm_and_recreates_evicted_vm() {
        let cache = EngineCache::default();
        let first = cache.get_or_create("old", None, None, None).unwrap().engine;
        first
            .lock()
            .unwrap()
            .eval("globalThis.cachedMarker = 7")
            .unwrap();
        for i in 0..MAX_ENTRIES {
            cache
                .get_or_create(&format!("new-{i}"), None, None, None)
                .unwrap();
        }
        let recreated = cache.get_or_create("old", None, None, None).unwrap().engine;
        assert!(!Arc::ptr_eq(&first, &recreated));
        assert_eq!(
            recreated
                .lock()
                .unwrap()
                .eval("typeof cachedMarker")
                .unwrap(),
            "undefined"
        );
        let same = cache.get_or_create("old", None, None, None).unwrap().engine;
        assert!(Arc::ptr_eq(&same, &recreated));
    }
}
