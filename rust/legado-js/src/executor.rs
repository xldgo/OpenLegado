//! QuickJS 执行器适配器（P5 下沉：原 `legado-ffi/src/js_executor.rs` 的
//! `quickjs_impl` 模块整体随迁）
//!
//! 在 legado-js 内把 QuickJS 引擎（[`crate::QuickJsEngine`] + 引擎缓存
//! [`crate::engine_cache`]）适配为 legado-parser 期望的
//! [`legado_parser::JsExecutor`]，供规则解析链路（ffi 侧经
//! `legado_ffi::js_executor::QuickJsExecutor` re-export 使用）与 loginCheckJs
//! 内核（本 crate `login_check`）共用同一实现，消除双副本手工同步。
//!
//! 设计要点：
//! - 持有所属 `source_tag`、书源 jsLib 与显式执行资源；资源内缓存仅服务
//!   非词法脚本，顶层声明触发重声明错误时登记并回退一次性新引擎。
//! - 实现 `Send + Sync`，满足 `Arc<dyn JsExecutor>`。

use legado_parser::JsExecutor;

/// QuickJS 执行器适配器
///
/// 持有所属 `source_tag`、书源 jsLib 与执行资源；非词法脚本复用其缓存 VM，
/// 重声明脚本回退到新 VM。
/// 实现 `Send + Sync`，满足 `Arc<dyn JsExecutor>`。
pub struct QuickJsExecutor {
    source_tag: String,
    resources: std::sync::Arc<crate::JsResources>,
    /// 书源 jsLib（共享库代码，执行前先加载，对齐原版每次 eval 前注入）
    js_lib: Option<String>,
    /// 书源上下文 setup 脚本（source/cookie/__mountBookSourceApi 等，
    /// 供 URL 模板 {{js}} 里 jsLib 函数 `this.source`/`this.cookie`
    /// 访问）— 发现页修复（书山聚合书籍 URL session 缺失）
    setup_script: Option<String>,
}

impl QuickJsExecutor {
    /// 以指定 `source_tag` 创建执行器
    pub fn new(source_tag: &str) -> Self {
        Self {
            source_tag: source_tag.to_string(),
            resources: Default::default(),
            js_lib: None,
            setup_script: None,
        }
    }

    /// 同引擎的连续执行显式复用资源，默认构造不与其他执行器共享 VM。
    pub fn with_resources(mut self, resources: std::sync::Arc<crate::JsResources>) -> Self {
        self.resources = resources;
        self
    }

    /// 携带书源 jsLib 创建执行器
    ///
    /// [UI-fix 2026-08-10 | Reasonix] yckceo 书源（漫画/聚合源）模板
    /// 引用 jsLib 定义（Reload/getHosts 等），不注入则 URL 构建失败
    pub fn with_js_lib(mut self, js_lib: Option<String>) -> Self {
        self.js_lib = js_lib;
        self
    }

    /// 携带书源上下文 setup 脚本（source/cookie 绑定 + BookSource 方法）
    pub fn with_setup_script(mut self, setup_script: Option<String>) -> Self {
        self.setup_script = setup_script;
        self
    }
}

impl JsExecutor for QuickJsExecutor {
    fn read_variable(&self, key: &str) -> Option<String> {
        if let Some(value) = self.resources.read_login_variable(key) {
            return value;
        }
        // 普通变量与 flow 尚待成组切换；登录键不向旧全局表回退。
        match self.resources.variable_scope() {
            Some(scope) => scope.get_flow_variable(key),
            None => self.resources.variables().get_variable(key).ok().flatten(),
        }
    }

    fn execute_js(&self, js_code: &str) -> Result<String, String> {
        let _execution = crate::cancellation::Scope::enter(self.resources.cancellation().cloned());
        crate::cancellation::check().map_err(|e| e.to_string())?;
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        let hash = {
            let mut h = DefaultHasher::new();
            js_code.hash(&mut h);
            h.finish()
        };
        let is_lexical = self.resources.is_lexical(hash);
        let run_fresh = || -> Result<String, String> {
            let config = crate::sandbox::SandboxConfig::default()
                .with_allow_script_run(true)
                .with_memory_limit(64 * 1024 * 1024);
            let engine = self
                .resources
                .create_engine(config)
                .map_err(|e| format!("JS 引擎创建失败: {e}"))?;
            crate::host_api::current_source::with_current_source_tag(&self.source_tag, || {
                if let Some(lib) = &self.js_lib {
                    // cap 3（URL 映射 jsLib）：先探测 URL 映射形态（全字符串值
                    // 的 JSON 对象）→ 经加载器解析（共享客户端拉取 + 实例缓存 +
                    // 逐条降级台账登记），eval 拼接脚本；非 URL 映射形态照旧
                    // 走原始 eval 级联
                    let ledger_tag = format!("executor:{}", self.source_tag);
                    let is_url_map =
                        crate::host_api::jslib_loader::parse_js_lib_url_map(lib).is_some();
                    let url_map_script = crate::host_api::jslib_loader::resolve_js_lib_url_map(
                        self.resources.http_resources(),
                        lib,
                        &ledger_tag,
                        &|url| {
                            crate::host_api::jslib_loader::default_js_lib_fetcher(
                                self.resources.http_resources(),
                                url,
                            )
                        },
                    );
                    crate::cancellation::check().map_err(|e| e.to_string())?;
                    if is_url_map {
                        // 逐条拉取失败已在加载器内记台账（降级跳过该条，
                        // 仅依赖该 jsLib 的规则受影响）；全失败时脚本为 None，
                        // 直接跳过 eval（原始 JSON 非合法 JS，不回退原始级联）
                        if let Some(script) = &url_map_script
                            && let Err(e) = crate::JsEngine::eval(&engine, script)
                        {
                            // 队列④：登记台账后**带原因上抛**（对齐原版
                            // SharedJsScope.evaluateJsLib 失败直接抛，
                            // SharedJsScope.kt:251/:258）。此前静默降级会让
                            // 失败推迟到主脚本引用点，报出误导性
                            // `source is not defined`（iOS 实机 1/2 号根因链）
                            crate::cancellation::check().map_err(|e| e.to_string())?;
                            crate::host_api::capability_ledger::record_jslib_load_failure(
                                &ledger_tag,
                                &e.to_string(),
                            );
                            return Err(format!("jsLib 求值失败: {e}"));
                        }
                    } else if let Err(e) = crate::JsEngine::eval(&engine, lib) {
                        crate::cancellation::check().map_err(|e| e.to_string())?;
                        // 仅对语法错误尝试 Rhino 宽容语法归一化后重试一次（与 engine_cache
                        // 缓存路径一致；对齐原版 corejs-Rhino 宽松解析——B 站 jsLib 的
                        // let 参数影子重声明、data..item_null 双点笔误等）。
                        // 归一化仍失败 / 运行时错误：登记台账后带原因上抛（不再静默降级）
                        let recovered = if engine.check_syntax(lib).is_err() {
                            let (normalized, changed) = crate::jslib_normalize::normalize(lib);
                            if changed && crate::JsEngine::eval(&engine, &normalized).is_ok() {
                                eprintln!(
                                    "[legado-js] 书源 {} jsLib 经 Rhino 宽容语法归一化后加载成功（原错误: {e}）",
                                    self.source_tag
                                );
                                true
                            } else {
                                false
                            }
                        } else {
                            false
                        };
                        if !recovered {
                            eprintln!(
                                "[legado-js] 书源 {} jsLib 加载失败（带原因上抛）: {e}",
                                self.source_tag
                            );
                            // 队列④：jsLib 加载失败登记能力受限台账
                            // （键与缓存路径一致：executor:<source_tag>）
                            crate::host_api::capability_ledger::record_jslib_load_failure(
                                &ledger_tag,
                                &e.to_string(),
                            );
                            return Err(format!("jsLib 求值失败: {e}"));
                        }
                    }
                }
                crate::cancellation::check().map_err(|e| e.to_string())?;
                if let Some(setup) = &self.setup_script
                    && let Err(e) = crate::JsEngine::eval(&engine, setup)
                {
                    crate::cancellation::check().map_err(|e| e.to_string())?;
                    eprintln!(
                        "[legado-js] 书源 {} setup 加载失败（降级继续）: {e}",
                        self.source_tag
                    );
                }
                if let Err(e) = crate::JsEngine::eval(
                    &engine,
                    crate::host_api::quickjs_impl::RESPONSE_BRIDGE_JS,
                ) {
                    eprintln!(
                        "[legado-js] 书源 {} Response 桥重新注入失败（降级继续）: {e}",
                        self.source_tag
                    );
                }
                if let Err(e) =
                    crate::JsEngine::eval(&engine, crate::host_api::quickjs_impl::JSOUP_BRIDGE_JS)
                {
                    eprintln!(
                        "[legado-js] 书源 {} Jsoup 桥重新注入失败（降级继续）: {e}",
                        self.source_tag
                    );
                }
                crate::JsEngine::eval(&engine, js_code).map_err(|e| e.to_string())
            })
        };
        // URL 映射形态 jsLib（值为 URL 的 JSON 对象）一律走 fresh 路径：
        // 缓存路径 `engine_cache::init_engine` 对 jsLib 原样 eval，而映射 JSON
        // 不是合法 JS，会误报「jsLib 求值失败」——B1 硬上抛后该误报会被放大成
        // 整源失败。上游语义是逐条拉取 URL 映射（SharedJsScope.parseJsLibMap），
        // 故映射形态必须交给 fresh 路径的加载器（jslib_loader：拉取 + 实例缓存
        // + 逐条降级台账）。非映射形态仍走缓存路径。
        let js_lib_is_url_map = self
            .js_lib
            .as_deref()
            .map(|lib| crate::host_api::jslib_loader::parse_js_lib_url_map(lib).is_some())
            .unwrap_or(false);
        if is_lexical || js_lib_is_url_map {
            return run_fresh();
        }
        let key = format!("executor:{}", self.source_tag);
        let cached = self
            .resources
            .engine_cache()
            .get_or_create_with_resources(
                &key,
                self.js_lib.as_deref(),
                self.setup_script.as_deref(),
                None,
                &self.resources,
            )
            .map_err(|e| e.to_string())?;
        // 错误随缓存结果返回，另一实例的同名台账记录不能改写本次异常。
        if let Some(reason) = cached.js_lib_error {
            return Err(format!("jsLib 求值失败: {reason}"));
        }
        let result =
            crate::host_api::current_source::with_current_source_tag(&self.source_tag, || {
                crate::cancellation::lock(&cached.engine)
                    .map_err(|e| e.to_string())
                    .and_then(|engine| {
                        let result = match self.resources.variable_scope() {
                            Some(scope) => engine.eval_with_variables(js_code, &[], scope),
                            None => crate::JsEngine::eval(&*engine, js_code),
                        };
                        result.map_err(|e| e.to_string())
                    })
            });
        crate::cancellation::check().map_err(|e| e.to_string())?;
        match result {
            Err(e) if e.contains("redeclaration") || e.contains("already declared") => {
                self.resources.mark_lexical(hash);
                run_fresh()
            }
            other => other,
        }
    }

    /// 带 `result` 绑定的执行（上游 AnalyzeUrl.evalJS `bindings["result"]`
    /// 口径）：URL 选项 `{"js": ...}` / bodyJs 在 `result` 中拿到当前 URL。
    /// 非严格 eval 下裸 `result` 标识符经 globalThis 解析，前缀注入等价。
    fn execute_js_with_result(&self, js_code: &str, result_json: &str) -> Result<String, String> {
        let wrapped = format!("globalThis.result = {result_json};\n{js_code}");
        self.execute_js(&wrapped)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scoped_views_share_vm_but_keep_flow_and_variable_owner_separate() {
        let resources = crate::JsResources::default();
        let one = resources.for_flow("book-one");
        let two = resources.for_flow("book-two");
        let a = QuickJsExecutor::new("shared-tag").with_resources(one.clone());
        let b = QuickJsExecutor::new("shared-tag").with_resources(two.clone());
        a.execute_js("globalThis.savedRead = java.__lgStoreGet; globalThis.counter=1; java.__lgStorePut('key','one')").unwrap();
        assert_eq!(
            b.execute_js("typeof savedRead + ':' + savedRead('key')")
                .unwrap(),
            "function:"
        );
        b.execute_js("counter++; java.__lgStorePut('key','two')")
            .unwrap();
        assert_eq!(
            a.execute_js("counter + ':' + savedRead('key')").unwrap(),
            "2:one"
        );
        assert_eq!(b.execute_js("savedRead('key')").unwrap(), "two");
        let parser = legado_parser::AnalyzeRule::with_js_executor(
            String::new(),
            String::new(),
            std::sync::Arc::new(a),
        );
        assert_eq!(parser.get_string("@get:{key}").unwrap(), "one");
        // 另一存储的视图不能读前实例的 VM、词法回退记录或变量。
        let other_store = std::sync::Arc::new(crate::variables::VariableStore::default());
        let other = QuickJsExecutor::new("shared-tag")
            .with_resources(resources.with_variable_scope(other_store.flow("book-one")));
        assert_eq!(other.execute_js("typeof savedRead").unwrap(), "undefined");
    }

    #[test]
    fn scoped_cached_vm_does_not_keep_root_resources_in_a_cycle() {
        let root = std::sync::Arc::new(crate::JsResources::default());
        let weak_root = std::sync::Arc::downgrade(&root);
        let store = root.variables();
        let weak_store = std::sync::Arc::downgrade(&store);
        let view = root.for_flow("book");
        let executor = QuickJsExecutor::new("release-scoped").with_resources(view.clone());
        executor
            .execute_js("globalThis.savedRead=java.__lgStoreGet;java.__lgStorePut('key','value')")
            .unwrap();
        drop(root);
        drop(store);
        assert!(weak_root.upgrade().is_none(), "视图不应反向持有根资源");
        assert_eq!(executor.execute_js("savedRead('key')").unwrap(), "value");
        drop(view);
        drop(executor);
        assert!(
            weak_store.upgrade().is_none(),
            "VM 宿主回调应随最后一个缓存所有者释放"
        );
    }

    #[test]
    fn fresh_lexical_fallback_keeps_explicit_scope() {
        let resources = crate::JsResources::default();
        let a = QuickJsExecutor::new("lexical-flow").with_resources(resources.for_flow("a"));
        let b = QuickJsExecutor::new("lexical-flow").with_resources(resources.for_flow("b"));
        let code = "let marker='value';java.__lgStorePut('key',marker);marker";
        assert_eq!(a.execute_js(code).unwrap(), "value");
        assert_eq!(b.execute_js(code).unwrap(), "value");
        assert_eq!(a.read_variable("key").as_deref(), Some("value"));
        assert_eq!(b.read_variable("key").as_deref(), Some("value"));
    }

    #[test]
    fn same_tag_shares_vm_only_within_explicit_resources() {
        let one = std::sync::Arc::new(crate::JsResources::default());
        let two = std::sync::Arc::new(crate::JsResources::default());
        let first = QuickJsExecutor::new("same-source").with_resources(one.clone());
        first
            .execute_js("globalThis.ownerMarker = 'first'")
            .unwrap();
        let same = QuickJsExecutor::new("same-source").with_resources(one);
        assert_eq!(same.execute_js("ownerMarker").unwrap(), "first");
        let other = QuickJsExecutor::new("same-source").with_resources(two);
        assert_eq!(other.execute_js("typeof ownerMarker").unwrap(), "undefined");
        other
            .execute_js("globalThis.ownerMarker = 'second'")
            .unwrap();
        assert_eq!(same.execute_js("ownerMarker").unwrap(), "first");
    }

    #[test]
    fn standalone_executors_do_not_implicitly_share_vm() {
        let first = QuickJsExecutor::new("standalone");
        first.execute_js("globalThis.privateMarker = 1").unwrap();
        let other = QuickJsExecutor::new("standalone");
        assert_eq!(
            other.execute_js("typeof privateMarker").unwrap(),
            "undefined"
        );
    }

    #[test]
    fn another_instance_redeclaration_does_not_force_fresh_vm() {
        let one = QuickJsExecutor::new("lexical-isolation");
        let two = QuickJsExecutor::new("lexical-isolation");
        let script = "if(globalThis.blocked) throw new Error('already declared'); globalThis.calls=(globalThis.calls || 0) + 1; calls";
        one.execute_js("globalThis.blocked=true").unwrap();
        // 首实例触发重声明回退；回退到新 VM 后没有 blocked，返回 1。
        assert_eq!(one.execute_js(script).unwrap(), "1");
        two.execute_js("globalThis.calls=41").unwrap();
        assert_eq!(
            two.execute_js(script).unwrap(),
            "42",
            "另一实例不得被首实例的识别结果强制切换为新 VM"
        );
    }

    #[test]
    fn same_source_errors_remain_bound_to_own_cached_initialization() {
        let one = QuickJsExecutor::new("same-source-errors")
            .with_js_lib(Some("throw new Error('instance-one')".into()));
        let two = QuickJsExecutor::new("same-source-errors")
            .with_js_lib(Some("throw new Error('instance-two')".into()));
        assert!(one.execute_js("1").unwrap_err().contains("instance-one"));
        assert!(two.execute_js("1").unwrap_err().contains("instance-two"));
        // 两实例同名诊断台账已被后者覆盖，本次异常仍须来自第一份缓存结果。
        let error = one.execute_js("1").unwrap_err();
        assert!(error.contains("instance-one"), "{error}");
        assert!(!error.contains("instance-two"), "{error}");
    }

    #[test]
    fn executor_does_not_keep_resources_alive_through_cached_vm_callbacks() {
        let resources = std::sync::Arc::new(crate::JsResources::default());
        let weak = std::sync::Arc::downgrade(&resources);
        let executor = QuickJsExecutor::new("resource-release").with_resources(resources.clone());
        assert_eq!(
            executor
                .execute_js("java.md5Encode('hello').length > 0")
                .unwrap(),
            "true"
        );
        drop(resources);
        assert!(weak.upgrade().is_some());
        drop(executor);
        assert!(weak.upgrade().is_none());
    }

    /// 同一 executor 可连续执行多条脚本。
    #[test]
    fn test_quickjs_executor_reuse() {
        let executor = QuickJsExecutor::new("reuse_tag");
        let r1 = executor.execute_js("10 * 10").unwrap();
        let r2 = executor.execute_js("100 + 1").unwrap();
        assert_eq!(r1, "100");
        assert_eq!(r2, "101");
    }

    #[test]
    fn test_js_lib_persists_across_independent_executes() {
        let lib = Some("function persisted(){ return 'ok'; }".to_string());
        let first = QuickJsExecutor::new("persist_tag").with_js_lib(lib.clone());
        let second = QuickJsExecutor::new("persist_tag").with_js_lib(lib);
        assert_eq!(first.execute_js("persisted()").unwrap(), "ok");
        assert_eq!(second.execute_js("persisted()").unwrap(), "ok");
    }

    /// [P5 迁移] 顶层 const 重声明 → 回退每次新建引擎（词法脚本路径）。
    #[test]
    fn test_redeclaration_falls_back_to_fresh_engine() {
        let executor = QuickJsExecutor::new("redeclaration_tag");
        let script = "const regression_value = 41; regression_value + 1";
        assert_eq!(executor.execute_js(script).unwrap(), "42");
        assert_eq!(executor.execute_js(script).unwrap(), "42");
    }

    /// jsLib 求值失败 → 带原因上抛（对齐原版 SharedJsScope.evaluateJsLib
    /// 失败直接抛，SharedJsScope.kt:251/:258），不得静默降级后由主脚本引用点
    /// 报误导性 `xxx is not defined`（iOS 实机 1/2 号 source 失真的根因链）。
    /// 契约与红绿证据由集成测试 `tests/jslib_failure_visible.rs` 锁定
    /// （覆盖缓存路径 / fresh 路径 / 不使用库函数场景）。
    #[test]
    fn test_valid_jslib_still_loads_and_runs() {
        let executor = QuickJsExecutor::new("jslib_ok_tag")
            .with_js_lib(Some("function marker(){ return 'ok'; }".to_string()));
        assert_eq!(executor.execute_js("marker()").unwrap(), "ok");
    }

    #[test]
    fn test_completion_value_is_preserved_on_fast_path() {
        let executor = QuickJsExecutor::new("completion_tag");
        assert_eq!(executor.execute_js("1 + 2").unwrap(), "3");
        assert_eq!(executor.execute_js("var x = 7; result = x").unwrap(), "7");
    }

    #[test]
    fn test_cache_per_source_isolation_and_capacity() {
        let resources = std::sync::Arc::new(crate::JsResources::default());
        for i in 0..(crate::engine_cache::MAX_ENTRIES + 2) {
            let tag = format!("lru_tag_{i}");
            let lib = format!("function marker(){{ return {i}; }}");
            let executor = QuickJsExecutor::new(&tag)
                .with_resources(resources.clone())
                .with_js_lib(Some(lib));
            assert_eq!(executor.execute_js("marker()").unwrap(), i.to_string());
        }
        let newest = QuickJsExecutor::new("lru_tag_7")
            .with_resources(resources.clone())
            .with_js_lib(Some("function marker(){ return 7; }".into()));
        assert_eq!(newest.execute_js("marker()").unwrap(), "7");
        let oldest = QuickJsExecutor::new("lru_tag_0")
            .with_resources(resources.clone())
            .with_js_lib(Some("function marker(){ return 0; }".into()));
        assert_eq!(oldest.execute_js("marker()").unwrap(), "0");
        // 私有测试资源无需进程测试锁；LRU 驱逐由 engine_cache 的行为用例验证。
    }
}
