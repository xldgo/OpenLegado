//! 引擎变量存储与显式流程句柄，不拥有 VM 或宿主上下文。

use std::collections::HashMap;
use std::num::NonZeroUsize;
use std::sync::{Arc, Mutex, Weak};

use lru::LruCache;

/// 书籍变量保持既有裸键格式，避免宿主与解析器的键约定漂移。
pub fn book_var_key(book_url: &str, key: &str) -> String {
    format!("bookVar::{book_url}::{key}")
}

pub fn book_var_key_prefix(book_url: &str) -> String {
    format!("bookVar::{book_url}::")
}

pub fn book_type_key(book_url: &str) -> String {
    format!("bookType::{book_url}")
}

pub fn book_reverse_toc_key(book_url: &str) -> String {
    format!("bookReverseToc::{book_url}")
}

/// 与既有 VM 缓存相同的最近流程保留规模；逐出不使在途句柄失效。
pub const MAX_RETAINED_FLOWS: usize = 32;

/// 同一引擎共享的裸键，以及有界保留的流程状态。
pub struct VariableStore {
    pub(crate) values: Arc<Mutex<HashMap<String, String>>>,
    books: Mutex<HashMap<BookIdentity, HashMap<String, String>>>,
    flows: Mutex<FlowRegistry>,
}

/// URL 本身不标识来源；结构化键也避免含分隔符的两个 URL 相互碰撞。
#[derive(Clone, PartialEq, Eq, Hash)]
struct BookIdentity {
    source_url: String,
    book_url: String,
}

#[derive(Clone, PartialEq, Eq, Hash)]
enum FlowIdentity {
    Named(String),
    Source {
        purpose: String,
        source: String,
        key: String,
    },
    Book(BookIdentity),
}

struct FlowRegistry {
    recent: LruCache<FlowIdentity, Arc<FlowState>>,
    /// 逐出后仍在途的同键流程可以重新发现，Weak 不延长其生命周期。
    live: HashMap<FlowIdentity, Weak<FlowState>>,
}

#[derive(Default)]
struct FlowState {
    values: Mutex<HashMap<String, String>>,
    book_flags: Mutex<HashMap<BookIdentity, BookFlags>>,
}

#[derive(Default)]
struct BookFlags {
    book_type: Option<String>,
    reverse_toc: Option<String>,
}

/// 构造 book 绑定时的快照；变量持久归属与流程标志的生命周期不同。
#[derive(Default, Debug, PartialEq, Eq)]
pub struct BookOverlays {
    pub variables: HashMap<String, String>,
    pub book_type: Option<i32>,
    pub reverse_toc: Option<bool>,
}

impl Default for VariableStore {
    fn default() -> Self {
        Self {
            values: Default::default(),
            books: Default::default(),
            flows: Mutex::new(FlowRegistry {
                recent: LruCache::new(NonZeroUsize::new(MAX_RETAINED_FLOWS).unwrap()),
                live: HashMap::new(),
            }),
        }
    }
}

impl VariableStore {
    pub fn get_variable(&self, key: &str) -> Result<Option<String>, String> {
        Ok(self
            .values
            .lock()
            .map_err(|e| format!("Lock error: {e}"))?
            .get(key)
            .cloned())
    }

    pub fn set_variable(&self, key: &str, value: &str) -> Result<(), String> {
        self.values
            .lock()
            .map_err(|e| format!("Lock error: {e}"))?
            .insert(key.into(), value.into());
        Ok(())
    }

    pub fn remove_variable(&self, key: &str) -> Result<Option<String>, String> {
        Ok(self
            .values
            .lock()
            .map_err(|e| format!("Lock error: {e}"))?
            .remove(key))
    }

    /// 清除此引擎的持久变量，不改动其他流程正在使用的会话值和标志。
    pub fn clear_variables(&self) -> Result<(), String> {
        self.values
            .lock()
            .map_err(|e| format!("Lock error: {e}"))?
            .clear();
        self.books
            .lock()
            .map_err(|e| format!("书籍变量锁异常: {e}"))?
            .clear();
        Ok(())
    }

    pub fn list_variable_keys(&self) -> Result<Vec<String>, String> {
        Ok(self
            .values
            .lock()
            .map_err(|e| format!("Lock error: {e}"))?
            .keys()
            .cloned()
            .collect())
    }

    /// 独立调用不假定存在“当前书籍”。
    pub fn unscoped(self: &Arc<Self>) -> VariableScope {
        VariableScope {
            store: self.clone(),
            flow: None,
            book: None,
        }
    }

    /// 单次合成/请求的独立会话；裸键仍由此存储持有以保留 cache 语义。
    pub fn fresh_flow(self: &Arc<Self>, key: &str) -> VariableScope {
        VariableScope {
            store: self.clone(),
            flow: Some((
                FlowIdentity::Named(key.to_string()),
                Arc::new(FlowState::default()),
            )),
            book: None,
        }
    }

    /// 同键跨调用复用状态；开启 B 不修改 A 句柄或清空其变量。
    pub fn flow(self: &Arc<Self>, key: &str) -> VariableScope {
        self.registered_flow(FlowIdentity::Named(key.to_string()), None)
    }

    /// 来源流程使用结构化身份，不靠分隔符拼接用途/URL/查询。
    pub fn source_flow(self: &Arc<Self>, purpose: &str, source: &str, key: &str) -> VariableScope {
        self.registered_flow(
            FlowIdentity::Source {
                purpose: purpose.into(),
                source: source.into(),
                key: key.into(),
            },
            None,
        )
    }

    /// 详情、目录和正文按来源与书籍共享会话，原文取址点单独携带。
    pub fn book_flow(self: &Arc<Self>, source_url: &str, book_url: &str) -> VariableScope {
        let book = BookIdentity {
            source_url: source_url.to_string(),
            book_url: book_url.to_string(),
        };
        self.registered_flow(FlowIdentity::Book(book.clone()), Some(book))
    }

    fn registered_flow(
        self: &Arc<Self>,
        identity: FlowIdentity,
        book: Option<BookIdentity>,
    ) -> VariableScope {
        let mut flows = self.flows.lock().unwrap_or_else(|p| p.into_inner());
        let state = flows
            .recent
            .get(&identity)
            .cloned()
            .or_else(|| flows.live.get(&identity).and_then(Weak::upgrade))
            .unwrap_or_default();
        flows.recent.put(identity.clone(), state.clone());
        flows.live.retain(|_, weak| weak.strong_count() > 0);
        flows.live.insert(identity.clone(), Arc::downgrade(&state));
        VariableScope {
            store: self.clone(),
            flow: Some((identity, state)),
            book,
        }
    }
}

/// 一次执行携带的流程能力；仅引用数据，不引用拥有 VM 缓存的 JsResources。
#[derive(Clone)]
pub struct VariableScope {
    store: Arc<VariableStore>,
    flow: Option<(FlowIdentity, Arc<FlowState>)>,
    book: Option<BookIdentity>,
}

impl VariableScope {
    pub fn store(&self) -> &Arc<VariableStore> {
        &self.store
    }

    pub fn source_identity(&self) -> Option<&str> {
        if let Some(book) = &self.book {
            return Some(&book.source_url);
        }
        match self.flow.as_ref().map(|(identity, _)| identity) {
            Some(FlowIdentity::Source { source, .. }) => Some(source),
            _ => None,
        }
    }

    pub fn book_source(&self) -> Option<&str> {
        self.book.as_ref().map(|book| book.source_url.as_str())
    }

    pub fn book_anchor(&self) -> Option<&str> {
        self.book.as_ref().map(|book| book.book_url.as_str())
    }

    fn book_identity(&self, book_url: &str) -> Option<BookIdentity> {
        self.book.as_ref().map(|book| BookIdentity {
            source_url: book.source_url.clone(),
            book_url: book_url.to_string(),
        })
    }

    pub fn get_book_variable(&self, book_url: &str, key: &str) -> Result<Option<String>, String> {
        let Some(identity) = self.book_identity(book_url) else {
            return self.store.get_variable(&book_var_key(book_url, key));
        };
        Ok(self
            .store
            .books
            .lock()
            .map_err(|e| format!("书籍变量锁异常: {e}"))?
            .get(&identity)
            .and_then(|values| values.get(key).cloned()))
    }

    pub fn set_book_variable(&self, book_url: &str, key: &str, value: &str) -> Result<(), String> {
        let Some(identity) = self.book_identity(book_url) else {
            return self.store.set_variable(&book_var_key(book_url, key), value);
        };
        self.store
            .books
            .lock()
            .map_err(|e| format!("书籍变量锁异常: {e}"))?
            .entry(identity)
            .or_default()
            .insert(key.to_string(), value.to_string());
        Ok(())
    }

    pub fn remove_book_variable(&self, book_url: &str, key: &str) -> Result<(), String> {
        let Some(identity) = self.book_identity(book_url) else {
            return self
                .store
                .remove_variable(&book_var_key(book_url, key))
                .map(|_| ());
        };
        let mut books = self
            .store
            .books
            .lock()
            .map_err(|e| format!("书籍变量锁异常: {e}"))?;
        if let Some(values) = books.get_mut(&identity) {
            values.remove(key);
            if values.is_empty() {
                books.remove(&identity);
            }
        }
        Ok(())
    }

    pub fn set_book_type(&self, book_url: &str, value: &str) -> Result<(), String> {
        self.set_book_flag(book_url, value, true)
    }

    pub fn set_book_reverse_toc(&self, book_url: &str, value: &str) -> Result<(), String> {
        self.set_book_flag(book_url, value, false)
    }

    fn set_book_flag(&self, book_url: &str, value: &str, is_type: bool) -> Result<(), String> {
        let Some(identity) = self.book_identity(book_url) else {
            let key = if is_type {
                book_type_key(book_url)
            } else {
                book_reverse_toc_key(book_url)
            };
            return self.store.set_variable(&key, value);
        };
        // 书籍能力仅由 book_flow 构造，始终带有流程状态。
        let state = &self.flow.as_ref().expect("书籍能力必须属于流程").1;
        let mut flags = state
            .book_flags
            .lock()
            .map_err(|e| format!("书籍标志锁异常: {e}"))?;
        let flags = flags.entry(identity).or_default();
        let slot = if is_type {
            &mut flags.book_type
        } else {
            &mut flags.reverse_toc
        };
        *slot = Some(value.to_string());
        Ok(())
    }

    /// 读取侧和真实 JS 读写桥使用相同的来源及书籍键，不查询旧进程表。
    pub fn book_overlays(&self, book_url: &str) -> Result<BookOverlays, String> {
        let Some(identity) = self.book_identity(book_url) else {
            let prefix = book_var_key_prefix(book_url);
            let values = self
                .store
                .values
                .lock()
                .map_err(|e| format!("变量锁异常: {e}"))?;
            return Ok(BookOverlays {
                variables: values
                    .iter()
                    .filter_map(|(key, value)| {
                        key.strip_prefix(&prefix)
                            .filter(|key| !key.is_empty())
                            .map(|key| (key.to_string(), value.clone()))
                    })
                    .collect(),
                book_type: values
                    .get(&book_type_key(book_url))
                    .and_then(|value| value.trim().parse().ok()),
                reverse_toc: values
                    .get(&book_reverse_toc_key(book_url))
                    .map(|value| matches!(value.trim(), "true" | "1")),
            });
        };
        let mut variables = self
            .store
            .books
            .lock()
            .map_err(|e| format!("书籍变量锁异常: {e}"))?
            .get(&identity)
            .cloned()
            .unwrap_or_default();
        variables.remove("");
        let state = &self.flow.as_ref().expect("书籍能力必须属于流程").1;
        let flags = state
            .book_flags
            .lock()
            .map_err(|e| format!("书籍标志锁异常: {e}"))?;
        let flags = flags.get(&identity);
        Ok(BookOverlays {
            variables,
            book_type: flags
                .and_then(|flags| flags.book_type.as_ref())
                .and_then(|value| value.trim().parse().ok()),
            reverse_toc: flags
                .and_then(|flags| flags.reverse_toc.as_ref())
                .map(|value| matches!(value.trim(), "true" | "1")),
        })
    }

    pub fn put_flow_variable(&self, key: &str, value: &str) -> Result<(), String> {
        match &self.flow {
            Some((_, state)) => {
                state
                    .values
                    .lock()
                    .map_err(|e| format!("流程变量锁异常: {e}"))?
                    .insert(key.into(), value.into());
                Ok(())
            }
            None => self.store.set_variable(key, value),
        }
    }

    /// 读取顺序：当前 flow → 裸键 → 显式指定来源和锚点的书籍变量。
    pub fn get_flow_variable(&self, key: &str) -> Option<String> {
        if let Some((_, state)) = &self.flow
            && let Some(value) = state
                .values
                .lock()
                .ok()
                .and_then(|values| values.get(key).cloned())
        {
            return Some(value);
        }
        if let Some(value) = self.store.get_variable(key).ok().flatten() {
            return Some(value);
        }
        self.book_anchor()
            .and_then(|book| self.get_book_variable(book, key).ok().flatten())
    }

    /// 清空当前能力的变量，不能把停止 A 扩散为清理 B 的会话。
    pub fn clear_variables(&self) -> Result<(), String> {
        self.store.clear_variables()?;
        if let Some((_, state)) = &self.flow {
            state
                .values
                .lock()
                .map_err(|e| format!("流程变量锁异常: {e}"))?
                .clear();
            state
                .book_flags
                .lock()
                .map_err(|e| format!("书籍标志锁异常: {e}"))?
                .clear();
        }
        Ok(())
    }

    pub fn reader(&self) -> legado_parser::VariableReader {
        let scope = self.clone();
        Arc::new(move |key| scope.get_flow_variable(key))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn source_flow_identity_is_structured_and_query_specific() {
        let store = Arc::new(VariableStore::default());
        let a = store.source_flow("search:a", "b", "same");
        a.put_flow_variable("key", "value").unwrap();
        for other in [
            store.source_flow("search", "a:b", "same"),
            store.source_flow("search:a", "b", "different"),
            store.source_flow("explore", "b", "same"),
        ] {
            assert_eq!(other.get_flow_variable("key"), None);
        }
        assert_eq!(
            store
                .source_flow("search:a", "b", "same")
                .get_flow_variable("key")
                .as_deref(),
            Some("value")
        );
        assert_eq!(a.source_identity(), Some("b"));
        assert_eq!(a.book_anchor(), None);
    }

    #[test]
    fn independent_stores_and_same_store_clones() {
        let one = Arc::new(VariableStore::default());
        let two = Arc::new(VariableStore::default());
        one.set_variable("key", "one").unwrap();
        two.set_variable("key", "two").unwrap();
        assert_eq!(
            one.clone().get_variable("key").unwrap().as_deref(),
            Some("one")
        );
        one.remove_variable("key").unwrap();
        assert_eq!(two.get_variable("key").unwrap().as_deref(), Some("two"));
    }

    #[test]
    fn flow_is_explicit_and_read_priority_is_preserved() {
        let store = Arc::new(VariableStore::default());
        let a = store.book_flow("source", "book-a");
        let b = store.book_flow("source", "book-b");
        a.set_book_variable("book-a", "key", "book").unwrap();
        assert_eq!(a.get_flow_variable("key").as_deref(), Some("book"));
        assert_eq!(b.get_flow_variable("key"), None);
        store.set_variable("key", "bare").unwrap();
        assert_eq!(a.get_flow_variable("key").as_deref(), Some("bare"));
        a.put_flow_variable("key", "flow-a").unwrap();
        b.put_flow_variable("key", "flow-b").unwrap();
        assert_eq!(a.get_flow_variable("key").as_deref(), Some("flow-a"));
        assert_eq!(b.get_flow_variable("key").as_deref(), Some("flow-b"));
        assert_eq!(
            store
                .book_flow("source", "book-a")
                .get_flow_variable("key")
                .as_deref(),
            Some("flow-a")
        );
        assert_eq!(
            store.unscoped().get_flow_variable("key").as_deref(),
            Some("bare")
        );
    }

    #[test]
    fn book_identity_keeps_source_and_anchor_separate_without_legacy_fallback() {
        let store = Arc::new(VariableStore::default());
        let a = store.book_flow("source:a", "same-book");
        let b = store.book_flow("source:b", "same-book");
        store
            .set_variable(&book_var_key("same-book", "key"), "old-bare")
            .unwrap();
        assert_eq!(a.book_anchor(), Some("same-book"));
        assert_eq!(store.flow("same-book").book_anchor(), None);
        assert_eq!(a.get_flow_variable("key"), None, "显式书籍不混读旧裸键");
        a.set_book_variable("same-book", "key", "a").unwrap();
        b.set_book_variable("same-book", "key", "b").unwrap();
        assert_eq!(a.get_flow_variable("key").as_deref(), Some("a"));
        assert_eq!(b.get_flow_variable("key").as_deref(), Some("b"));
        assert_eq!(
            store.flow("same-book").get_flow_variable("key"),
            None,
            "普通 flow 名即使与 bookUrl 相同也不能隐式读书籍覆盖"
        );
        assert_eq!(a.book_overlays("same-book").unwrap().variables["key"], "a");
        a.set_book_variable("same-book", "", "empty-key").unwrap();
        assert_eq!(
            a.get_book_variable("same-book", "").unwrap().as_deref(),
            Some("empty-key")
        );
        assert!(
            !a.book_overlays("same-book")
                .unwrap()
                .variables
                .contains_key(""),
            "绑定构造仍过滤空变量名，不改变既有 overlay 语义"
        );
        a.remove_book_variable("same-book", "key").unwrap();
        assert_eq!(a.get_flow_variable("key"), None);
        assert_eq!(b.get_flow_variable("key").as_deref(), Some("b"));

        let left = store.book_flow("source:a", "b:c");
        let right = store.book_flow("source:a:b", "c");
        left.put_flow_variable("key", "left").unwrap();
        left.set_book_variable("b:c", "key", "left-book").unwrap();
        assert_eq!(
            right.get_flow_variable("key"),
            None,
            "不同元组不得因分隔符碰撞"
        );
        assert_eq!(right.book_overlays("c").unwrap(), BookOverlays::default());
    }

    #[test]
    fn book_flags_belong_to_live_flow_while_variables_survive_flow_eviction() {
        let store = Arc::new(VariableStore::default());
        let live = store.book_flow("source", "book");
        live.set_book_variable("book", "key", "persistent").unwrap();
        live.set_book_type("book", " 64 ").unwrap();
        live.set_book_reverse_toc("book", "true").unwrap();
        live.put_flow_variable("temporary", "value").unwrap();
        for i in 0..MAX_RETAINED_FLOWS {
            store.book_flow("source", &format!("other-{i}"));
        }
        let reentered = store.book_flow("source", "book");
        assert_eq!(reentered.book_overlays("book").unwrap().book_type, Some(64));
        assert_eq!(
            reentered.book_overlays("book").unwrap().reverse_toc,
            Some(true)
        );
        assert_eq!(
            reentered.get_flow_variable("temporary").as_deref(),
            Some("value")
        );
        assert_eq!(
            store
                .book_flow("other-source", "book")
                .book_overlays("book")
                .unwrap(),
            BookOverlays::default()
        );
        drop(reentered);
        drop(live);
        for i in 0..MAX_RETAINED_FLOWS {
            store.flow(&format!("evict-{i}"));
        }
        let new_flow = store.book_flow("source", "book");
        let overlays = new_flow.book_overlays("book").unwrap();
        assert_eq!(overlays.variables["key"], "persistent");
        assert_eq!(overlays.book_type, None);
        assert_eq!(overlays.reverse_toc, None);
        assert_eq!(new_flow.get_flow_variable("temporary"), None);
        new_flow.set_book_type("book", "bad-type").unwrap();
        new_flow.set_book_reverse_toc("book", "0").unwrap();
        let overlays = new_flow.book_overlays("book").unwrap();
        assert_eq!(overlays.book_type, None);
        assert_eq!(overlays.reverse_toc, Some(false));
    }

    #[test]
    fn clearing_one_book_keeps_other_live_flows_and_other_engines() {
        let store = Arc::new(VariableStore::default());
        let other = Arc::new(VariableStore::default());
        let a = store.book_flow("source", "a");
        let b = store.book_flow("source", "b");
        let independent = other.book_flow("source", "a");
        for scope in [&a, &b, &independent] {
            let book = scope.book_anchor().unwrap();
            scope.set_book_variable(book, "key", "persistent").unwrap();
            scope.set_book_type(book, "32").unwrap();
            scope.put_flow_variable("key", "temporary").unwrap();
        }
        a.clear_variables().unwrap();
        assert_eq!(a.book_overlays("a").unwrap(), BookOverlays::default());
        assert_eq!(a.get_flow_variable("key"), None);
        let b_overlays = b.book_overlays("b").unwrap();
        assert!(b_overlays.variables.is_empty(), "清空作用于同引擎持久数据");
        assert_eq!(b_overlays.book_type, Some(32), "不能清除其他在途流程的标志");
        assert_eq!(b.get_flow_variable("key").as_deref(), Some("temporary"));
        assert_eq!(
            independent.book_overlays("a").unwrap().variables["key"],
            "persistent"
        );
    }

    #[test]
    fn flow_lru_is_bounded_without_revoking_live_handles() {
        let store = Arc::new(VariableStore::default());
        let live = store.flow("old");
        live.put_flow_variable("key", "in-flight").unwrap();
        for i in 0..MAX_RETAINED_FLOWS {
            store.flow(&format!("new-{i}"));
        }
        assert_eq!(store.flows.lock().unwrap().recent.len(), MAX_RETAINED_FLOWS);
        assert_eq!(live.get_flow_variable("key").as_deref(), Some("in-flight"));
        assert_eq!(
            store.flow("old").get_flow_variable("key").as_deref(),
            Some("in-flight")
        );
        drop(live);
        // 失去注册表强引用且没有在途句柄后，同键重新进入才创建空流程。
        for i in 0..MAX_RETAINED_FLOWS {
            store.flow(&format!("final-{i}"));
        }
        assert_eq!(store.flow("old").get_flow_variable("key"), None);
        assert!(store.flows.lock().unwrap().live.len() <= MAX_RETAINED_FLOWS);
    }

    #[test]
    fn reader_owns_only_its_data_and_releases_it() {
        let store = Arc::new(VariableStore::default());
        let weak = Arc::downgrade(&store);
        let flow = store.flow("book");
        flow.put_flow_variable("key", "value").unwrap();
        let reader = flow.reader();
        drop(flow);
        drop(store);
        assert_eq!(reader("key").as_deref(), Some("value"));
        drop(reader);
        assert!(weak.upgrade().is_none());
    }

    #[test]
    fn clearing_a_keeps_b_session_and_other_engines() {
        let store = Arc::new(VariableStore::default());
        let other = Arc::new(VariableStore::default());
        let a = store.flow("a");
        let b = store.flow("b");
        a.put_flow_variable("key", "a").unwrap();
        b.put_flow_variable("key", "b").unwrap();
        other.set_variable("key", "other").unwrap();
        a.clear_variables().unwrap();
        assert_eq!(a.get_flow_variable("key"), None);
        assert_eq!(b.get_flow_variable("key").as_deref(), Some("b"));
        assert_eq!(other.get_variable("key").unwrap().as_deref(), Some("other"));
    }
}

#[cfg(all(test, feature = "quickjs"))]
mod quickjs_tests {
    use super::*;
    use crate::sandbox::SandboxConfig;
    use crate::{JsEngine, QuickJsEngine};

    fn engine(scope: VariableScope) -> QuickJsEngine {
        QuickJsEngine::new_with_variables(
            SandboxConfig::default().with_allow_script_run(true),
            scope,
        )
        .unwrap()
    }

    #[test]
    fn saved_callback_follows_this_eval_scope_and_error_restores_default() {
        let store = Arc::new(VariableStore::default());
        let a = store.flow("a");
        let b = store.flow("b");
        a.put_flow_variable("key", "a").unwrap();
        b.put_flow_variable("key", "b").unwrap();
        let vm = engine(store.unscoped());
        vm.eval("globalThis.savedGet = java.__lgStoreGet; globalThis.savedPut = java.__lgStorePut")
            .unwrap();
        assert_eq!(
            vm.eval_with_variables("savedGet('key')", &[], &a).unwrap(),
            "a"
        );
        assert_eq!(
            vm.eval_with_variables("savedPut('key','b-new');savedGet('key')", &[], &b)
                .unwrap(),
            "b-new"
        );
        assert!(
            vm.eval_with_variables("throw new Error('expected')", &[], &a)
                .is_err()
        );
        assert_eq!(
            vm.eval("savedGet('key')").unwrap(),
            "",
            "错误后恢复未绑定 flow 的默认能力"
        );
        assert_eq!(
            vm.eval_with_variables("savedGet('key')", &[], &a).unwrap(),
            "a"
        );
        let compiled = vm.compile("savedGet('key')").unwrap();
        assert_eq!(
            vm.execute_compiled_with_variables(&compiled, &[], &b)
                .unwrap(),
            "b-new"
        );
        assert_eq!(vm.eval("savedGet('key')").unwrap(), "");
    }

    #[test]
    fn same_vm_parallel_calls_bind_scope_under_its_context_lock() {
        let store = Arc::new(VariableStore::default());
        let vm = Arc::new(engine(store.unscoped()));
        let barrier = Arc::new(std::sync::Barrier::new(2));
        let handles: Vec<_> = ["a", "b"]
            .into_iter()
            .map(|key| {
                let vm = vm.clone();
                let barrier = barrier.clone();
                let scope = store.flow(key);
                std::thread::spawn(move || {
                    scope.put_flow_variable("key", key).unwrap();
                    barrier.wait();
                    for _ in 0..20 {
                        assert_eq!(
                            vm.eval_with_variables("java.__lgStoreGet('key')", &[], &scope)
                                .unwrap(),
                            key
                        );
                    }
                })
            })
            .collect();
        for handle in handles {
            handle.join().unwrap();
        }
        assert_eq!(vm.eval("java.__lgStoreGet('key')").unwrap(), "");
    }

    #[test]
    fn real_callbacks_and_parser_share_explicit_flow_without_another_books_values() {
        let store = Arc::new(VariableStore::default());
        let a = store.flow("book-a");
        let b = store.flow("book-b");
        let vm_a = engine(a.clone());
        let vm_b = engine(b.clone());
        vm_a.eval("java.__lgStorePut('key','a'); java.setVariable('shared','bare')")
            .unwrap();
        vm_b.eval("java.__lgStorePut('key','b')").unwrap();
        let parser = legado_parser::AnalyzeRule::new(String::new(), String::new())
            .with_variable_reader(a.reader());
        assert_eq!(parser.get_string("@get:{key}").unwrap(), "a");
        assert_eq!(vm_b.eval("java.__lgStoreGet('key')").unwrap(), "b");
        assert_eq!(vm_b.eval("getVariable('shared')").unwrap(), "bare");
        // 新 VM 相当于后续详情/目录/正文求值，仍携带同键句柄。
        assert_eq!(
            engine(store.flow("book-a"))
                .eval("java.__lgStoreGet('key')")
                .unwrap(),
            "a"
        );
        let isolated = engine(Arc::new(VariableStore::default()).flow("book-a"));
        assert_eq!(
            isolated
                .eval("getVariable('shared') + java.__lgStoreGet('key')")
                .unwrap(),
            ""
        );
    }

    #[test]
    fn actual_bare_and_book_bridges_are_instance_scoped() {
        let one = Arc::new(VariableStore::default());
        let two = Arc::new(VariableStore::default());
        let a = engine(one.unscoped());
        let b = engine(two.unscoped());
        a.eval("put('plain','one'); setLocal('local','yes'); java.__lgBookVarSet('same-book','var','book-one'); java.__lgBookSetType('same-book','8'); java.__lgBookSetReverseToc('same-book','true')").unwrap();
        b.eval("setVariable('plain','two'); java.__lgBookVarSet('same-book','var','book-two')")
            .unwrap();
        assert_eq!(a.eval("get('plain') + ':' + getVariable('local') + ':' + java.__lgBookVarGet('same-book','var')").unwrap(), "one:yes:book-one");
        assert_eq!(
            b.eval("java.get('plain') + ':' + java.__lgBookVarGet('same-book','var')")
                .unwrap(),
            "two:book-two"
        );
        assert_eq!(
            one.get_variable(&book_type_key("same-book"))
                .unwrap()
                .as_deref(),
            Some("8")
        );
        assert_eq!(
            two.get_variable(&book_reverse_toc_key("same-book"))
                .unwrap(),
            None
        );
        assert_eq!(a.eval("removeVariable('plain')").unwrap(), "true");
        a.eval("java.__lgBookVarDel('same-book','var'); clearVariables()")
            .unwrap();
        assert_eq!(
            a.eval("getVariable('local') + java.__lgBookVarGet('same-book','var')")
                .unwrap(),
            ""
        );
        assert_eq!(b.eval("getVariable('plain')").unwrap(), "two");
    }

    #[test]
    fn cached_book_callbacks_follow_each_flow_and_parser_uses_the_same_anchor() {
        use legado_parser::{AnalyzeRule, JsExecutor};
        let resources = Arc::new(crate::JsResources::default());
        let weak = Arc::downgrade(&resources.variables());
        let a = resources.for_book("source-a", "same-book");
        let b = resources.for_book("source-b", "same-book");
        let c = resources.for_book("source-a", "other-book");
        let executor =
            |view| crate::executor::QuickJsExecutor::new("same-cache-tag").with_resources(view);
        let ea = executor(a.clone());
        let eb = executor(b.clone());
        let ec = executor(c.clone());
        // 同一缓存 VM 保存的原生函数引用不能永久捕获第一个书源/书籍。
        ea.execute_js("globalThis.saveBook=java.__lgBookVarSet;globalThis.readBook=java.__lgBookVarGet;saveBook('same-book','key','a');java.__lgBookSetType('same-book','64')").unwrap();
        eb.execute_js(
            "saveBook('same-book','key','b');java.__lgBookSetReverseToc('same-book','true')",
        )
        .unwrap();
        ec.execute_js("saveBook('other-book','key','c')").unwrap();
        assert_eq!(ea.execute_js("readBook('same-book','key')").unwrap(), "a");
        assert_eq!(eb.execute_js("readBook('same-book','key')").unwrap(), "b");
        assert_eq!(ec.execute_js("readBook('other-book','key')").unwrap(), "c");
        assert_eq!(
            a.variable_scope()
                .unwrap()
                .book_overlays("same-book")
                .unwrap()
                .book_type,
            Some(64)
        );
        assert_eq!(
            b.variable_scope()
                .unwrap()
                .book_overlays("same-book")
                .unwrap()
                .book_type,
            None
        );
        assert_eq!(
            b.variable_scope()
                .unwrap()
                .book_overlays("same-book")
                .unwrap()
                .reverse_toc,
            Some(true)
        );
        let parser = AnalyzeRule::with_js_executor(String::new(), String::new(), Arc::new(ea));
        assert_eq!(parser.get_string("@get:{key}").unwrap(), "a");
        let direct_content = executor(resources.for_book("source-b", "same-book"));
        assert_eq!(
            direct_content
                .execute_js("java.__lgStoreGet('key')")
                .unwrap(),
            "b",
            "正文独立取得自己的书籍能力，无需先设置全局当前书籍"
        );
        eb.execute_js("java.__lgBookVarDel('same-book','key')")
            .unwrap();
        assert_eq!(
            direct_content
                .execute_js("java.__lgStoreGet('key')")
                .unwrap(),
            ""
        );
        assert_eq!(parser.get_string("@get:{key}").unwrap(), "a");
        let independent =
            executor(Arc::new(crate::JsResources::default()).for_book("source-a", "same-book"));
        assert_eq!(
            independent
                .execute_js("java.__lgBookVarGet('same-book','key')")
                .unwrap(),
            ""
        );
        drop((a, b, c, eb, ec, parser, direct_content, resources));
        assert!(weak.upgrade().is_none(), "变量桥和缓存之间不得形成强引用环");
    }

    #[test]
    fn vm_callbacks_release_their_variable_store() {
        let store = Arc::new(VariableStore::default());
        let weak = Arc::downgrade(&store);
        let vm = engine(store.flow("book"));
        vm.eval("java.__lgStorePut('key','value')").unwrap();
        drop(store);
        assert!(weak.upgrade().is_some());
        drop(vm);
        assert!(
            weak.upgrade().is_none(),
            "真实宿主回调不得把变量表或 VM 留在引用环内"
        );
    }
}
