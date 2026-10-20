//! VM 内部的变量能力与按次守卫，数据算法由 variables 模块唯一实现。
use std::sync::{Arc, Mutex};

/// VM 内部的能力槽；只在上下文锁内切换，不作为引擎级“当前 flow”。
#[cfg(feature = "quickjs")]
#[derive(Clone)]
pub(crate) struct BoundVariables {
    slot: Arc<Mutex<crate::variables::VariableScope>>,
    source_login: Option<Arc<dyn crate::source_login::SourceLoginStore>>,
}

#[cfg(feature = "quickjs")]
impl BoundVariables {
    pub fn new(binding: crate::variables::VariableScope) -> Self {
        Self::with_source_login(binding, None)
    }

    pub fn with_source_login(
        binding: crate::variables::VariableScope,
        source_login: Option<Arc<dyn crate::source_login::SourceLoginStore>>,
    ) -> Self {
        Self {
            slot: Arc::new(Mutex::new(binding)),
            source_login,
        }
    }

    fn current(&self) -> crate::variables::VariableScope {
        self.slot.lock().unwrap_or_else(|p| p.into_inner()).clone()
    }

    /// 调用方必须持有本 VM 的上下文锁，不能把守卫带到异步等待中。
    pub fn bind(&self, scope: &crate::variables::VariableScope) -> VariableBindingGuard {
        let previous = std::mem::replace(
            &mut *self.slot.lock().unwrap_or_else(|p| p.into_inner()),
            scope.clone(),
        );
        VariableBindingGuard {
            slot: self.clone(),
            previous: Some(previous),
        }
    }

    pub fn get_variable(&self, key: &str) -> Result<Option<String>, String> {
        if let Some(store) = &self.source_login
            && let Some((kind, source)) = crate::source_login::parse_key(key)
        {
            return Ok(store.get(kind, source));
        }
        self.current().store().get_variable(key)
    }
    pub fn set_variable(&self, key: &str, value: &str) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        if let Some(store) = &self.source_login
            && let Some((kind, source)) = crate::source_login::parse_key(key)
        {
            store.put(kind, source, value);
            return Ok(());
        }
        self.current().store().set_variable(key, value)
    }
    pub fn remove_variable(&self, key: &str) -> Result<Option<String>, String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        if let Some(store) = &self.source_login
            && let Some((kind, source)) = crate::source_login::parse_key(key)
        {
            return Ok(store.remove(kind, source));
        }
        self.current().store().remove_variable(key)
    }
    pub fn clear_variables(&self) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        self.current().clear_variables()
    }
    pub fn put_flow_variable(&self, key: &str, value: &str) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        self.current().put_flow_variable(key, value)
    }
    pub fn get_flow_variable(&self, key: &str) -> Option<String> {
        if let Some(store) = &self.source_login
            && let Some((kind, source)) = crate::source_login::parse_key(key)
        {
            return store.get(kind, source);
        }
        self.current().get_flow_variable(key)
    }

    pub fn get_book_variable(&self, book_url: &str, key: &str) -> Result<Option<String>, String> {
        self.current().get_book_variable(book_url, key)
    }

    pub fn set_book_variable(&self, book_url: &str, key: &str, value: &str) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        self.current().set_book_variable(book_url, key, value)
    }

    pub fn remove_book_variable(&self, book_url: &str, key: &str) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        self.current().remove_book_variable(book_url, key)
    }

    pub fn set_book_type(&self, book_url: &str, value: &str) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        self.current().set_book_type(book_url, value)
    }

    pub fn set_book_reverse_toc(&self, book_url: &str, value: &str) -> Result<(), String> {
        crate::cancellation::check().map_err(|e| e.to_string())?;
        self.current().set_book_reverse_toc(book_url, value)
    }
}

#[cfg(feature = "quickjs")]
pub(crate) struct VariableBindingGuard {
    slot: BoundVariables,
    previous: Option<crate::variables::VariableScope>,
}

#[cfg(feature = "quickjs")]
impl Drop for VariableBindingGuard {
    fn drop(&mut self) {
        if let Some(previous) = self.previous.take() {
            *self.slot.slot.lock().unwrap_or_else(|p| p.into_inner()) = previous;
        }
    }
}
