//! JS 执行资源的显式所有者；底层 crate 不查询宿主的全局引擎。

/// 同一引擎的规则执行器与 mainJs 共用此资源；独立实例默认隔离。
///
/// VM 缓存与数据变量分开持有，主书源、HTTP TTS 与字典携带显式流程。
/// 正式宿主的来源登录键直接访问注入的数据服务。
/// Cookie、主要网络入口和间接下载使用实例能力；其余宿主状态按计划收口。
#[derive(Clone)]
pub struct JsResources {
    variables: std::sync::Arc<crate::variables::VariableStore>,
    host: std::sync::Arc<crate::host_resources::JsHostResources>,
    scope: Option<crate::variables::VariableScope>,
    source_login: Option<std::sync::Arc<dyn crate::source_login::SourceLoginStore>>,
    #[cfg(feature = "quickjs")]
    http: std::sync::Arc<crate::http_resources::HttpResources>,
    #[cfg(feature = "quickjs")]
    cache: std::sync::Arc<crate::engine_cache::EngineCache>,
    #[cfg(feature = "quickjs")]
    lexical_scripts: std::sync::Arc<std::sync::Mutex<std::collections::HashSet<u64>>>,
}

impl Default for JsResources {
    fn default() -> Self {
        let variables = std::sync::Arc::new(crate::variables::VariableStore::default());
        Self {
            scope: Some(variables.unscoped()),
            variables,
            host: Default::default(),
            source_login: None,
            #[cfg(feature = "quickjs")]
            http: Default::default(),
            #[cfg(feature = "quickjs")]
            cache: Default::default(),
            #[cfg(feature = "quickjs")]
            lexical_scripts: Default::default(),
        }
    }
}

impl JsResources {
    #[cfg(feature = "quickjs")]
    pub fn with_http_resources(
        mut self,
        http: std::sync::Arc<crate::http_resources::HttpResources>,
    ) -> Self {
        self.http = http;
        self.cache = Default::default();
        self
    }

    #[cfg(feature = "quickjs")]
    pub fn http_resources(&self) -> &std::sync::Arc<crate::http_resources::HttpResources> {
        &self.http
    }
    pub fn with_host_resources(
        mut self,
        host: std::sync::Arc<crate::host_resources::JsHostResources>,
    ) -> Self {
        self.host = host;
        #[cfg(feature = "quickjs")]
        {
            self.cache = Default::default();
        }
        self
    }

    pub fn host_resources(&self) -> &std::sync::Arc<crate::host_resources::JsHostResources> {
        &self.host
    }

    /// 来源的独立流程；不改变其他调用已持有的会话句柄。
    pub fn for_source(&self, purpose: &str, source: &str, key: &str) -> std::sync::Arc<Self> {
        self.with_variable_scope(self.variables.source_flow(purpose, source, key))
    }

    /// 装配时固定登录服务；不暴露运行期全局替换槽。
    pub fn with_source_login_store(
        mut self,
        store: std::sync::Arc<dyn crate::source_login::SourceLoginStore>,
    ) -> Self {
        self.source_login = Some(store);
        // 新服务必须使用独立 VM 缓存，不能复用已捕获其他服务的回调。
        #[cfg(feature = "quickjs")]
        {
            self.cache = Default::default();
        }
        self
    }

    pub fn source_login_store(
        &self,
    ) -> Option<&std::sync::Arc<dyn crate::source_login::SourceLoginStore>> {
        self.source_login.as_ref()
    }

    /// 命中登录键但值缺失时仍权威返回 None，禁止向旧全局表回退。
    pub fn read_login_variable(&self, key: &str) -> Option<Option<String>> {
        let store = self.source_login.as_ref()?;
        let (kind, source) = crate::source_login::parse_key(key)?;
        Some(store.get(kind, source))
    }

    /// 解析器读者仅捕获数据能力，不能反向保留 VM 缓存。
    pub fn variable_reader(&self) -> legado_parser::VariableReader {
        let fallback = self.scope.as_ref().map_or_else(
            || self.variables.unscoped().reader(),
            |scope| scope.reader(),
        );
        let login = self.source_login.clone();
        std::sync::Arc::new(move |key| {
            if let Some(login) = &login
                && let Some((kind, source)) = crate::source_login::parse_key(key)
            {
                return login.get(kind, source);
            }
            fallback(key)
        })
    }

    /// fresh 及直接脚本入口共用装配；不改变普通变量尚未迁移的语义。
    #[cfg(feature = "quickjs")]
    pub fn create_engine(
        &self,
        config: crate::SandboxConfig,
    ) -> legado_core::LegadoResult<crate::QuickJsEngine> {
        crate::QuickJsEngine::new_with_capabilities(
            config,
            self.scope.clone(),
            self.source_login.clone(),
            Some(self.http.clone()),
            Some(self.host.clone()),
        )
    }

    /// 回调只捕获此数据能力，不捕获拥有 VM 缓存的根资源。
    pub fn variables(&self) -> std::sync::Arc<crate::variables::VariableStore> {
        self.variables.clone()
    }

    /// 新视图共享 VM 缓存和存储，但不共享“当前 flow”单槽。
    pub fn for_flow(&self, key: &str) -> std::sync::Arc<Self> {
        self.with_variable_scope(self.variables.flow(key))
    }

    /// 同来源同书籍的各阶段共用流程；书籍锚点不从普通流程名推断。
    pub fn for_book(&self, source_url: &str, book_url: &str) -> std::sync::Arc<Self> {
        self.with_variable_scope(self.variables.book_flow(source_url, book_url))
    }

    /// 只有同一数据所有者才共享缓存；外部存储同时隔离 VM 与词法回退记录。
    pub fn with_variable_scope(
        &self,
        scope: crate::variables::VariableScope,
    ) -> std::sync::Arc<Self> {
        #[cfg(feature = "quickjs")]
        let same_owner = std::sync::Arc::ptr_eq(&self.variables, scope.store());
        std::sync::Arc::new(Self {
            variables: scope.store().clone(),
            host: self.host.clone(),
            scope: Some(scope),
            source_login: self.source_login.clone(),
            #[cfg(feature = "quickjs")]
            http: self.http.clone(),
            #[cfg(feature = "quickjs")]
            cache: if same_owner {
                self.cache.clone()
            } else {
                Default::default()
            },
            #[cfg(feature = "quickjs")]
            lexical_scripts: if same_owner {
                self.lexical_scripts.clone()
            } else {
                Default::default()
            },
        })
    }

    pub fn variable_scope(&self) -> Option<&crate::variables::VariableScope> {
        self.scope.as_ref()
    }

    #[cfg(feature = "quickjs")]
    pub fn engine_cache(&self) -> &crate::engine_cache::EngineCache {
        &self.cache
    }

    #[cfg(feature = "quickjs")]
    pub(crate) fn is_lexical(&self, hash: u64) -> bool {
        self.lexical_scripts
            .lock()
            .map(|scripts| scripts.contains(&hash))
            .unwrap_or(false)
    }

    #[cfg(feature = "quickjs")]
    pub(crate) fn mark_lexical(&self, hash: u64) {
        if let Ok(mut scripts) = self.lexical_scripts.lock() {
            scripts.insert(hash);
        }
    }
}
