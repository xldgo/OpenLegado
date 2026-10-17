//! 朗读缓存目录、索引及活动租约；不依赖 Flutter 或数据库。
use crate::{LegadoError, LegadoResult};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::{Arc, Mutex, OnceLock, Weak},
    time::UNIX_EPOCH,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CacheContext {
    pub book_url: String,
    pub book_name: String,
    pub chapter_index: u32,
    pub chapter_title: String,
    pub paragraph_index: u32,
    pub text: String,
}
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CacheEntry {
    pub name: String,
    pub size_bytes: u64,
    pub modified_at_ms: u64,
    pub protected: bool,
    pub contexts: Vec<CacheContext>,
}
#[derive(Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ClearResult {
    pub removed_files: u64,
    pub removed_bytes: u64,
    pub skipped_files: u64,
}
#[derive(Default, Debug)]
struct State {
    requests: usize,
    pins: HashMap<PathBuf, usize>,
}
#[derive(Debug)]
pub struct TtsCache {
    dir: PathBuf,
    state: Mutex<State>,
}
pub struct CacheActivity {
    cache: Arc<TtsCache>,
}
#[derive(Debug)]
pub struct AudioLease {
    cache: Arc<TtsCache>,
    path: PathBuf,
}
impl Drop for CacheActivity {
    fn drop(&mut self) {
        self.cache
            .state
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .requests -= 1;
    }
}
impl Drop for AudioLease {
    fn drop(&mut self) {
        let mut state = self.cache.state.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(n) = state.pins.get_mut(&self.path) {
            *n -= 1;
            if *n == 0 {
                state.pins.remove(&self.path);
            }
        }
    }
}
fn invalid(message: &str) -> LegadoError {
    LegadoError::Ffi(message.into())
}
fn valid_name(name: &str) -> bool {
    name.starts_with("tts_")
        && name
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-.".contains(&b))
        && ["mp3", "wav", "aac", "m4a", "ogg", "amr", "flac"]
            .contains(&name.rsplit('.').next().unwrap_or(""))
}
impl TtsCache {
    pub fn open(dir: &Path) -> LegadoResult<Arc<Self>> {
        static CACHES: OnceLock<Mutex<HashMap<PathBuf, Weak<TtsCache>>>> = OnceLock::new();
        std::fs::create_dir_all(dir)?;
        let dir = dir.canonicalize()?;
        let mut caches = CACHES
            .get_or_init(Default::default)
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        caches.retain(|_, value| value.strong_count() > 0);
        if let Some(cache) = caches.get(&dir).and_then(Weak::upgrade) {
            return Ok(cache);
        }
        let cache = Arc::new(Self {
            dir: dir.clone(),
            state: Mutex::new(State::default()),
        });
        caches.insert(dir, Arc::downgrade(&cache));
        Ok(cache)
    }
    pub fn activity(self: &Arc<Self>) -> CacheActivity {
        self.state
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .requests += 1;
        CacheActivity {
            cache: self.clone(),
        }
    }
    pub fn pin(self: &Arc<Self>, path: &Path) -> LegadoResult<AudioLease> {
        let mut state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let path = self.checked_path(path)?;
        *state.pins.entry(path.clone()).or_default() += 1;
        Ok(AudioLease {
            cache: self.clone(),
            path,
        })
    }
    fn checked_path(&self, path: &Path) -> LegadoResult<PathBuf> {
        if std::fs::symlink_metadata(path)?.file_type().is_symlink() {
            return Err(invalid("朗读缓存不接受符号链接"));
        }
        let path = path.canonicalize()?;
        if path.parent() != Some(self.dir.as_path())
            || !path.is_file()
            || !path
                .file_name()
                .and_then(|s| s.to_str())
                .is_some_and(valid_name)
        {
            return Err(invalid("音频文件不属于当前朗读缓存目录"));
        }
        Ok(path)
    }
    fn index(&self, name: &str) -> PathBuf {
        self.dir.join(format!(".{name}.json"))
    }
    fn contexts(&self, name: &str) -> LegadoResult<Vec<CacheContext>> {
        let index = self.index(name);
        if std::fs::symlink_metadata(&index).is_ok_and(|m| m.file_type().is_symlink()) {
            return Err(invalid("缓存索引不接受符号链接"));
        }
        match std::fs::read(index) {
            Ok(bytes) => Ok(serde_json::from_slice(&bytes)?),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(vec![]),
            Err(e) => Err(e.into()),
        }
    }
    pub fn record(&self, path: &Path, context: CacheContext) -> LegadoResult<()> {
        let _state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let path = self.checked_path(path)?;
        if context.book_url.is_empty() {
            return Err(invalid("缓存书籍标识不能为空"));
        }
        let name = path.file_name().unwrap().to_str().unwrap();
        let mut contexts = self.contexts(name)?;
        contexts.retain(|c| {
            (c.book_url.as_str(), c.chapter_index, c.paragraph_index)
                != (
                    context.book_url.as_str(),
                    context.chapter_index,
                    context.paragraph_index,
                )
        });
        contexts.push(context);
        use std::sync::atomic::{AtomicU64, Ordering};
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let temp = self.dir.join(format!(
            ".{name}.{}_{}.index.part",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        let result = (|| -> LegadoResult<()> {
            use std::io::Write;
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&temp)?;
            file.write_all(&serde_json::to_vec(&contexts)?)?;
            // 性能（发热治理）：索引只是缓存管理页的附加元数据，不是播放依据；
            // 每次合成一段都 sync_all 会额外产生一次 fsync。这里只保证写完后
            // rename 发布，掉电最多丢一条索引，音频本身仍可正常播放。
            drop(file);
            std::fs::rename(&temp, self.index(name))?;
            Ok(())
        })();
        let _ = std::fs::remove_file(temp);
        result
    }
    fn entries(&self, state: &State) -> LegadoResult<Vec<CacheEntry>> {
        let mut result = vec![];
        for entry in std::fs::read_dir(&self.dir)? {
            let entry = entry?;
            let name = entry.file_name().to_string_lossy().into_owned();
            if !valid_name(&name) || !entry.file_type()?.is_file() {
                continue;
            }
            let meta = entry.metadata()?;
            if meta.len() == 0 {
                continue;
            }
            result.push(CacheEntry {
                contexts: self.contexts(&name)?,
                protected: state.requests > 0 || state.pins.contains_key(&entry.path()),
                size_bytes: meta.len(),
                modified_at_ms: meta
                    .modified()?
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as u64,
                name,
            });
        }
        result.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(result)
    }
    pub fn list(&self) -> LegadoResult<Vec<CacheEntry>> {
        let state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        self.entries(&state)
    }
    pub fn clear(
        &self,
        name: Option<&str>,
        before: Option<u64>,
        keep_book: Option<&str>,
        keep_chapter: Option<u32>,
    ) -> LegadoResult<ClearResult> {
        if name.is_some_and(|n| !valid_name(n)) {
            return Err(invalid("非法朗读缓存文件名"));
        }
        let state = self.state.lock().unwrap_or_else(|e| e.into_inner());
        let mut result = ClearResult::default();
        for entry in self.entries(&state)? {
            if name.is_some_and(|n| n != entry.name)
                || before.is_some_and(|b| entry.modified_at_ms >= b)
            {
                continue;
            }
            let keep = keep_book.zip(keep_chapter).is_some_and(|(book, chapter)| {
                entry
                    .contexts
                    .iter()
                    .any(|c| c.book_url == book && c.chapter_index == chapter)
            });
            if entry.protected || keep {
                result.skipped_files += 1;
                continue;
            }
            std::fs::remove_file(self.dir.join(&entry.name))?;
            match std::fs::remove_file(self.index(&entry.name)) {
                Ok(()) => (),
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => (),
                Err(e) => return Err(e.into()),
            }
            result.removed_files += 1;
            result.removed_bytes += entry.size_bytes;
        }
        Ok(result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};
    struct Fixture(PathBuf);
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }
    fn fixture() -> (Fixture, Arc<TtsCache>, PathBuf) {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let dir = std::env::temp_dir().join(format!(
            "tts-cache-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        let cache = TtsCache::open(&dir).unwrap();
        let path = cache.dir.join("tts_abc.mp3");
        std::fs::write(&path, b"audio").unwrap();
        (Fixture(dir), cache, path)
    }
    fn context(book: &str, chapter: u32) -> CacheContext {
        CacheContext {
            book_url: book.into(),
            book_name: "书".into(),
            chapter_index: chapter,
            chapter_title: "章".into(),
            paragraph_index: 0,
            text: "甲😀\"乙".into(),
        }
    }
    #[test]
    fn index_is_json_and_multiple_books_share_audio() {
        let (_f, cache, path) = fixture();
        cache.record(&path, context("a", 0)).unwrap();
        cache.record(&path, context("b", 1)).unwrap();
        let entries = cache.list().unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].contexts.len(), 2);
        assert_eq!(entries[0].size_bytes, 5);
        assert_eq!(entries[0].contexts[0].text, "甲😀\"乙");
        let reopened = TtsCache::open(&cache.dir).unwrap();
        assert!(Arc::ptr_eq(&cache, &reopened));
        drop(reopened);
        drop(cache);
        assert_eq!(
            TtsCache::open(path.parent().unwrap())
                .unwrap()
                .list()
                .unwrap()[0]
                .contexts
                .len(),
            2
        );
    }
    #[test]
    fn requests_and_playing_leases_protect_from_delete() {
        let (_f, cache, path) = fixture();
        let activity = cache.activity();
        assert_eq!(
            cache.clear(None, None, None, None).unwrap().skipped_files,
            1
        );
        let lease = cache.pin(&path).unwrap();
        drop(activity);
        assert_eq!(
            cache.clear(None, None, None, None).unwrap().skipped_files,
            1
        );
        drop(lease);
        assert_eq!(
            cache.clear(None, None, None, None).unwrap().removed_files,
            1
        );
    }
    #[test]
    fn expiry_current_chapter_temp_and_invalid_names() {
        let (_f, cache, path) = fixture();
        cache.record(&path, context("a", 0)).unwrap();
        std::fs::write(cache.dir.join(".tts_tmp.part"), b"writing").unwrap();
        assert_eq!(
            cache
                .clear(None, Some(u64::MAX), Some("a"), Some(0))
                .unwrap()
                .skipped_files,
            1
        );
        assert_eq!(
            cache
                .clear(None, Some(0), None, None)
                .unwrap()
                .removed_files,
            0
        );
        assert!(
            cache
                .clear(Some("../tts_abc.mp3"), None, None, None)
                .is_err()
        );
        assert_eq!(
            cache
                .clear(None, Some(u64::MAX), None, None)
                .unwrap()
                .removed_bytes,
            5
        );
        assert!(cache.dir.join(".tts_tmp.part").exists());
    }
    #[test]
    fn malformed_context_index_and_external_file_fail_closed() {
        let (_f, cache, path) = fixture();
        assert!(cache.record(&path, context("", 0)).is_err());
        let external = cache.dir.join("other.mp3");
        std::fs::write(&external, b"external").unwrap();
        assert!(cache.pin(&external).is_err());
        assert!(cache.record(&external, context("a", 0)).is_err());
        cache.record(&path, context("a", 0)).unwrap();
        cache.record(&path, context("a", 0)).unwrap();
        assert_eq!(cache.list().unwrap()[0].contexts.len(), 1);
        std::fs::write(cache.index("tts_abc.mp3"), b"broken").unwrap();
        assert!(cache.list().is_err());
        assert!(cache.clear(None, None, None, None).is_err());
        assert!(path.exists());
    }
    #[test]
    fn leases_are_reference_counted_and_indexes_do_not_enter_audio_list() {
        let (_f, cache, path) = fixture();
        let first = cache.pin(&path).unwrap();
        let second = cache.pin(&path).unwrap();
        cache.record(&path, context("a", 0)).unwrap();
        std::fs::write(cache.dir.join("tts_empty.mp3"), b"").unwrap();
        std::fs::write(cache.dir.join(".tts_stale.index.part"), b"stale").unwrap();
        assert_eq!(cache.list().unwrap().len(), 1);
        drop(first);
        assert_eq!(
            cache.clear(None, None, None, None).unwrap().skipped_files,
            1
        );
        drop(second);
        assert_eq!(
            cache.clear(None, None, None, None).unwrap().removed_files,
            1
        );
        assert!(!cache.index("tts_abc.mp3").exists());
    }
}
