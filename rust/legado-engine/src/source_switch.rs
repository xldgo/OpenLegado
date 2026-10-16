//! 换源宿主的控制槽与预拉缓存，不持业务根或 FFI。
use crate::{Operation, OperationSlot, TaskGroup, TaskScopeError};
use legado_core::web_book::{WebBookInfo, WebChapter};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[derive(Clone)]
pub struct SwitchPrefetchEntry {
    pub info: Option<WebBookInfo>,
    pub chapters: Vec<WebChapter>,
}
#[derive(Default)]
struct Cache {
    entries: HashMap<(String, String), SwitchPrefetchEntry>,
    chapter_count: usize,
}
pub struct SourceSwitchState {
    pub searches: Arc<OperationSlot>,
    pub applies: Arc<OperationSlot>,
    tasks: TaskGroup,
    cache: Mutex<Cache>,
}
impl SourceSwitchState {
    pub fn new(tasks: TaskGroup) -> Self {
        Self {
            searches: Arc::new(OperationSlot::new(tasks.clone())),
            applies: Arc::new(OperationSlot::new(tasks.clone())),
            tasks,
            cache: Mutex::new(Cache::default()),
        }
    }
    pub fn tasks(&self) -> &TaskGroup {
        &self.tasks
    }
    pub fn start_search(&self) -> Result<Arc<Operation>, TaskScopeError> {
        let operation = self.searches.start()?;
        operation.publish(|| self.clear());
        Ok(operation)
    }
    pub fn clear(&self) {
        *self.cache.lock().unwrap_or_else(|p| p.into_inner()) = Cache::default();
    }
    pub fn insert(
        &self,
        source: &str,
        book: &str,
        info: Option<WebBookInfo>,
        chapters: Vec<WebChapter>,
    ) {
        let mut cache = self.cache.lock().unwrap_or_else(|p| p.into_inner());
        if cache.chapter_count.saturating_add(chapters.len()) > 30_000 {
            return;
        }
        cache.chapter_count += chapters.len();
        cache.entries.insert(
            (source.into(), book.into()),
            SwitchPrefetchEntry { info, chapters },
        );
    }
    pub fn get(&self, source: &str, book: &str) -> Option<SwitchPrefetchEntry> {
        self.cache
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .entries
            .get(&(source.into(), book.into()))
            .cloned()
    }
}
