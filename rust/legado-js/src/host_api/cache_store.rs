//! JS缓存由显式所有者持有；内存LRU、普通磁盘缓存与限期文件缓存独立。
use lru::LruCache;
use sha2::{Digest, Sha256};
use std::fs;
use std::num::NonZeroUsize;
use std::path::PathBuf;
use std::sync::Mutex;
#[cfg(test)]
use std::sync::OnceLock;
use std::sync::atomic::{AtomicBool, Ordering};
const MEMORY_CACHE_CAPACITY: usize = 1024;
pub const CACHE_DIR_ENV: &str = "LEGADO_JS_CACHE_DIR";
#[derive(serde::Serialize, serde::Deserialize)]
struct DiskCacheEntry {
    v: String,
    d: i64,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct FileCacheEntry {
    value: String,
    #[serde(deserialize_with = "file_cache_deadline")]
    expires_at: Option<i64>,
}

// 永久缓存也必须显式包含null期限；缺字段的损坏文件不能被当成永久。
fn file_cache_deadline<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> Result<Option<i64>, D::Error> {
    serde::Deserialize::deserialize(deserializer)
}

pub struct CacheStore {
    file_access: Mutex<()>,
    memory: Mutex<LruCache<String, String>>,
    directory: Mutex<Option<PathBuf>>,
    fallback: Option<PathBuf>,
    temporary: super::resource_files::ResourceFiles,
}
impl Default for CacheStore {
    fn default() -> Self {
        Self {
            file_access: Mutex::new(()),
            memory: Mutex::new(LruCache::new(
                NonZeroUsize::new(MEMORY_CACHE_CAPACITY).unwrap(),
            )),
            directory: Mutex::new(None),
            fallback: None,
            temporary: Default::default(),
        }
    }
}
impl CacheStore {
    pub fn set_cache_dir(&self, path: impl AsRef<std::path::Path>) {
        *self.directory.lock().unwrap_or_else(|p| p.into_inner()) =
            Some(path.as_ref().to_path_buf());
    }
    pub fn disk_dir(&self) -> Result<PathBuf, String> {
        #[cfg(test)]
        if self.fallback.is_some()
            && let Some(path) = TEST_DISK_DIR_OVERRIDE.lock().unwrap().clone()
        {
            return Ok(path);
        }
        #[cfg(not(test))]
        if let Ok(path) = std::env::var(CACHE_DIR_ENV)
            && !path.trim().is_empty()
        {
            return Ok(path.into());
        }
        if let Some(path) = self
            .directory
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .clone()
        {
            return Ok(path);
        }
        match &self.fallback {
            Some(path) => Ok(path.clone()),
            None => self.temporary.directory(),
        }
    }
    fn disk_path(&self, key: &str) -> Option<PathBuf> {
        Some(
            self.disk_dir()
                .ok()?
                .join(format!("{}.json", sha256_hex(key))),
        )
    }
    fn file_path(&self, key: &str) -> Option<PathBuf> {
        Some(self.disk_dir().ok()?.join("file").join(sha256_hex(key)))
    }
    /// 内存层写入（`putMemory`）
    pub fn put_memory(&self, key: &str, value: &str) {
        if let Ok(mut cache) = self.memory.lock() {
            cache.put(key.to_string(), value.to_string());
        }
    }

    /// 内存层读取（`getFromMemory`）
    pub fn get_from_memory(&self, key: &str) -> Option<String> {
        self.memory.lock().ok()?.get(key).cloned()
    }

    /// 内存层删除（`deleteMemory`）
    pub fn delete_memory(&self, key: &str) {
        if let Ok(mut cache) = self.memory.lock() {
            cache.pop(key);
        }
    }

    /// 磁盘写入（`put`）：saveTime 秒，0=永久（同步内存层），非零 → 清内存层
    ///
    /// P2-11 ②：写盘失败（目录创建 / 序列化 / `fs::write`）均记录失败原因，
    /// 并把新值**晋升内存层**（保留内存层语义：不 `delete_memory` 旧值、
    /// 直接写新值）——降级说明：同进程 `get` 仍可读该值、无 deadline 强制
    /// （内存层不过期）、`onlyDisk` 读不受影响（磁盘层为空）。成功路径不变：
    /// 先写盘，成功后再调内存层（deadline==0 → 同步内存；非零 → 清内存，
    /// 对齐上游 put 后 deleteMemory）。
    pub fn put(&self, key: &str, value: &str, save_time_secs: i64) -> bool {
        let deadline = if save_time_secs <= 0 {
            0
        } else {
            now_millis() + save_time_secs * 1000
        };
        let Some(path) = self.disk_path(key) else {
            self.put_memory(key, value);
            return false;
        };
        if let Some(parent) = path.parent()
            && let Err(e) = fs::create_dir_all(parent)
        {
            warn_once(&PUT_WRITE_FAIL_WARNED, || {
                eprintln!(
                    "[cache_store] 创建缓存目录失败 {:?}: {e}（降级保留内存层；同类失败后续不再逐条记日志）",
                    parent
                );
            });
            self.put_memory(key, value);
            return false;
        }
        let json = match serde_json::to_string(&DiskCacheEntry {
            v: value.to_string(),
            d: deadline,
        }) {
            Ok(j) => j,
            Err(e) => {
                warn_once(&PUT_WRITE_FAIL_WARNED, || {
                    eprintln!(
                        "[cache_store] 序列化失败 {key}: {e}（降级保留内存层；同类失败后续不再逐条记日志）"
                    );
                });
                self.put_memory(key, value);
                return false;
            }
        };
        if let Err(e) = fs::write(&path, json) {
            warn_once(&PUT_WRITE_FAIL_WARNED, || {
                eprintln!(
                    "[cache_store] 写盘失败 {key} ({path:?}): {e}（降级保留内存层；同类失败后续不再逐条记日志）"
                );
            });
            self.put_memory(key, value);
            return false;
        }
        if deadline == 0 {
            self.put_memory(key, value);
        } else {
            self.delete_memory(key);
        }
        true
    }

    /// 磁盘读取（`get`）：内存优先（only_disk 跳过），磁盘按 deadline 校验
    pub fn get(&self, key: &str, only_disk: bool) -> Option<String> {
        if !only_disk && let Some(v) = self.get_from_memory(key) {
            return Some(v);
        }
        let raw = fs::read_to_string(self.disk_path(key)?).ok()?;
        let entry: DiskCacheEntry = serde_json::from_str(&raw).ok()?;
        if entry.d == 0 || now_millis() <= entry.d {
            if entry.d == 0 {
                self.put_memory(key, &entry.v);
            }
            Some(entry.v)
        } else {
            if let Some(path) = self.disk_path(key) {
                let _ = fs::remove_file(path);
            }
            None
        }
    }

    /// 文件缓存只写磁盘；期限按秒持久化，0永久，负数已过期。
    pub fn put_file(&self, key: &str, value: &str, save_time_secs: i32) -> bool {
        self.put_file_at(key, value, save_time_secs, now_millis())
    }

    fn put_file_at(&self, key: &str, value: &str, save_time_secs: i32, now: i64) -> bool {
        let _access = self.file_access.lock().unwrap_or_else(|e| e.into_inner());
        let Some(path) = self.file_path(key) else {
            return false;
        };
        if let Some(parent) = path.parent()
            && let Err(e) = fs::create_dir_all(parent)
        {
            warn_once(&PUT_FILE_WRITE_FAIL_WARNED, || {
                eprintln!(
                    "[cache_store] 创建缓存目录失败 {:?}: {e}（纯磁盘 API 无内存层可降级；同类失败后续不再逐条记日志）",
                    parent
                );
            });
            return false;
        }
        // P2-11 ②：纯磁盘 API（file/ 子目录，不进内存层）——写失败无内存层
        // 可降级，仅记录失败原因（原 `.is_ok()` 静默吞错）；P2-15 剩项：
        // 限流为进程内首条（目录不合法时每次 `cache.putFile` 都会失败）
        let entry = FileCacheEntry {
            value: value.into(),
            expires_at: (save_time_secs != 0).then_some(now + i64::from(save_time_secs) * 1000),
        };
        let encoded = match serde_json::to_vec(&entry) {
            Ok(encoded) => encoded,
            Err(error) => {
                warn_once(&PUT_FILE_WRITE_FAIL_WARNED, || {
                    eprintln!("[cache_store] 文件缓存序列化失败: {error}");
                });
                return false;
            }
        };
        match fs::write(&path, encoded) {
            Ok(()) => true,
            Err(e) => {
                warn_once(&PUT_FILE_WRITE_FAIL_WARNED, || {
                    eprintln!(
                        "[cache_store] 写盘失败 {key} ({path:?}): {e}（同类失败后续不再逐条记日志）"
                    );
                });
                false
            }
        }
    }

    /// 文件缓存读取不进入内存层；只有超过截止毫秒才清除过期文件。
    pub fn get_file(&self, key: &str) -> Option<String> {
        self.get_file_at(key, now_millis())
    }

    fn get_file_at(&self, key: &str, now: i64) -> Option<String> {
        // 与同一所有者写入/删除串行，避免旧的过期读取误删刚覆盖的新值。
        let _access = self.file_access.lock().unwrap_or_else(|e| e.into_inner());
        let path = self.file_path(key)?;
        let entry: FileCacheEntry = serde_json::from_slice(&fs::read(&path).ok()?).ok()?;
        if entry.expires_at.is_some_and(|deadline| now > deadline) {
            let _ = fs::remove_file(path);
            None
        } else {
            Some(entry.value)
        }
    }

    /// 删除（磁盘 + 内存）
    pub fn delete(&self, key: &str) {
        if let Some(path) = self.disk_path(key) {
            let _ = fs::remove_file(path);
        }
        {
            let _access = self.file_access.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(path) = self.file_path(key) {
                let _ = fs::remove_file(path);
            }
        }
        self.delete_memory(key);
    }
}
fn sha256_hex(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let bytes = hasher.finalize();
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push_str(&format!("{b:02x}"));
    }
    out
}

fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

static PUT_WRITE_FAIL_WARNED: AtomicBool = AtomicBool::new(false);
static PUT_FILE_WRITE_FAIL_WARNED: AtomicBool = AtomicBool::new(false);
fn warn_once(flag: &AtomicBool, log: impl FnOnce()) -> bool {
    if flag
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
    {
        log();
        true
    } else {
        false
    }
}

// 以下适配仅供既有原生单元测试共享夹具，生产 VM 不访问测试槽。
#[cfg(test)]
fn test_store() -> &'static CacheStore {
    static STORE: OnceLock<CacheStore> = OnceLock::new();
    STORE.get_or_init(|| CacheStore {
        directory: Mutex::new(None),
        fallback: Some(std::env::temp_dir().join("legado-js-cache")),
        ..Default::default()
    })
}
#[cfg(test)]
static CACHE_TEST_LOCK: Mutex<()> = Mutex::new(());
#[cfg(test)]
pub(crate) fn lock_cache_for_test() -> std::sync::MutexGuard<'static, ()> {
    CACHE_TEST_LOCK.lock().unwrap_or_else(|p| p.into_inner())
}
#[cfg(test)]
fn reset_write_fail_warned() {
    PUT_WRITE_FAIL_WARNED.store(false, Ordering::SeqCst);
    PUT_FILE_WRITE_FAIL_WARNED.store(false, Ordering::SeqCst);
}
#[cfg(test)]
static TEST_DISK_DIR_OVERRIDE: Mutex<Option<PathBuf>> = Mutex::new(None);
#[cfg(test)]
fn set_test_disk_dir_override(dir: Option<PathBuf>) {
    *TEST_DISK_DIR_OVERRIDE.lock().unwrap() = dir;
}
#[cfg(test)]
fn clear_cache_dir() {
    *test_store().directory.lock().unwrap() = None;
}
#[cfg(test)]
fn set_cache_dir(path: impl AsRef<std::path::Path>) {
    test_store().set_cache_dir(path);
}
#[cfg(test)]
fn disk_dir() -> PathBuf {
    test_store().disk_dir().unwrap()
}
#[cfg(test)]
fn disk_path(key: &str) -> PathBuf {
    test_store().disk_path(key).unwrap()
}
#[cfg(test)]
fn file_path(key: &str) -> PathBuf {
    test_store().file_path(key).unwrap()
}
#[cfg(test)]
fn put_memory(key: &str, value: &str) {
    test_store().put_memory(key, value)
}
#[cfg(test)]
fn get_from_memory(key: &str) -> Option<String> {
    test_store().get_from_memory(key)
}
#[cfg(test)]
fn delete_memory(key: &str) {
    test_store().delete_memory(key)
}
#[cfg(test)]
fn put(key: &str, value: &str, secs: i64) -> bool {
    test_store().put(key, value, secs)
}
#[cfg(test)]
fn get(key: &str, disk: bool) -> Option<String> {
    test_store().get(key, disk)
}
#[cfg(test)]
fn put_file(key: &str, value: &str) -> bool {
    test_store().put_file(key, value, 0)
}
#[cfg(test)]
fn get_file(key: &str) -> Option<String> {
    test_store().get_file(key)
}
#[cfg(test)]
fn delete(key: &str) {
    test_store().delete(key)
}
#[cfg(test)]
mod tests {
    use super::*;
    // Ordering 经 `use super::*` 引入（文件头 import），此处仅补 AtomicUsize
    use std::sync::atomic::AtomicUsize;

    static COUNTER: AtomicUsize = AtomicUsize::new(0);

    /// 进程级唯一临时根目录（注入目录测试用，测试收尾 remove_dir_all 清理）
    fn unique_root(tag: &str) -> PathBuf {
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        std::env::temp_dir().join(format!(
            "legado-js-cache-test-{}-{}-{}",
            std::process::id(),
            n,
            tag
        ))
    }

    fn unique_key(tag: &str) -> String {
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        format!("{}-{}-{}", std::process::id(), n, tag)
    }

    #[test]
    fn file_cache_ttl_deadline_survives_reopen_and_expires_only_after_boundary() {
        let owner = CacheStore::default();
        let directory = owner.disk_dir().unwrap();
        let first = CacheStore::default();
        first.set_cache_dir(&directory);
        let now = 1_700_000_000_000;
        assert!(first.put_file_at("key", "中文\n{正文}", 2, now));
        assert_eq!(
            first.get_file_at("key", now + 1999).as_deref(),
            Some("中文\n{正文}")
        );
        drop(first);
        let reopened = CacheStore::default();
        reopened.set_cache_dir(&directory);
        assert_eq!(
            reopened.get_file_at("key", now + 2000).as_deref(),
            Some("中文\n{正文}")
        );
        assert_eq!(reopened.get_file_at("key", now + 2001), None);
        assert!(!reopened.file_path("key").unwrap().exists());
    }

    #[test]
    fn file_cache_ttl_overwrites_deadline_and_keeps_file_layer_separate() {
        let cache = CacheStore::default();
        let now = 1_700_000_000_000;
        assert!(cache.put_file_at("key", "old", 1, now));
        assert!(cache.put_file_at("key", "permanent", 0, now + 500));
        assert_eq!(
            cache.get_file_at("key", now + 100_000).as_deref(),
            Some("permanent")
        );
        assert!(cache.get("key", true).is_none());
        assert!(cache.get_from_memory("key").is_none());
        assert!(cache.put_file_at("key", "new", 1, now + 100_000));
        assert_eq!(
            cache.get_file_at("key", now + 101_000).as_deref(),
            Some("new")
        );
        assert_eq!(cache.get_file_at("key", now + 101_001), None);
    }

    #[test]
    fn file_cache_ttl_handles_negative_and_full_i32_range_without_zero_sentinel() {
        let cache = CacheStore::default();
        let now = 1_700_000_000_000;
        for seconds in [-1, i32::MIN, -1_700_000_000] {
            assert!(cache.put_file_at("key", "expired", seconds, now));
            assert!(cache.get_file_at("key", now).is_none());
        }
        assert!(cache.put_file_at("key", "long", i32::MAX, now));
        let end = now + i64::from(i32::MAX) * 1000;
        assert_eq!(cache.get_file_at("key", end).as_deref(), Some("long"));
        assert_eq!(cache.get_file_at("key", end + 1), None);
    }

    #[test]
    fn file_cache_ttl_delete_and_independent_owners_do_not_cross() {
        let one = CacheStore::default();
        let two = CacheStore::default();
        assert!(one.put_file("same", "one", 0));
        assert!(two.put_file("same", "two", 60));
        one.put_memory("same", "memory");
        assert!(one.put("same", "disk", 0));
        one.delete("same");
        assert!(one.get_file("same").is_none());
        assert!(one.get("same", false).is_none());
        assert!(one.get("same", true).is_none());
        assert_eq!(two.get_file("same").as_deref(), Some("two"));
    }

    #[test]
    fn file_cache_ttl_unstructured_or_corrupt_files_are_misses() {
        let cache = CacheStore::default();
        let path = cache.file_path("key").unwrap();
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        for data in [
            "原裸缓存",
            "{broken",
            r#"{"value":"v","expires_at":"bad"}"#,
            r#"{"value":"missing-deadline"}"#,
            r#"{"expires_at":null}"#,
        ] {
            fs::write(&path, data).unwrap();
            assert_eq!(cache.get_file("key"), None);
        }
        assert!(cache.put_file("key", "recreated", 0));
        assert_eq!(cache.get_file("key").as_deref(), Some("recreated"));
    }

    #[test]
    fn test_memory_roundtrip() {
        let _lock = lock_cache_for_test();
        let k = unique_key("mem");
        assert!(get_from_memory(&k).is_none());
        put_memory(&k, "v1");
        assert_eq!(get_from_memory(&k).as_deref(), Some("v1"));
        // 数字值（语料 cache.putMemory(k, Date.now())）以字符串存储
        put_memory(&k, "1726540800000");
        assert_eq!(get_from_memory(&k).as_deref(), Some("1726540800000"));
        delete_memory(&k);
        assert!(get_from_memory(&k).is_none());
    }

    #[test]
    fn test_put_get_permanent() {
        let _lock = lock_cache_for_test();
        let k = unique_key("perm");
        assert!(put(&k, "perm-value", 0));
        assert_eq!(get(&k, false).as_deref(), Some("perm-value"));
        // 永久缓存命中后回写内存层
        assert_eq!(get_from_memory(&k).as_deref(), Some("perm-value"));
        // onlyDisk 跳过内存层，直接读磁盘
        assert_eq!(get(&k, true).as_deref(), Some("perm-value"));
        delete(&k);
        assert!(get(&k, false).is_none());
        assert!(get(&k, true).is_none());
        assert!(get_from_memory(&k).is_none());
    }

    #[test]
    fn test_put_get_expired() {
        let _lock = lock_cache_for_test();
        let k = unique_key("expired");
        // saveTime=1 秒；等待过期后磁盘读取应 None 且文件被清理
        assert!(put(&k, "short", 1));
        std::thread::sleep(std::time::Duration::from_millis(1100));
        assert!(get(&k, true).is_none());
    }

    #[test]
    fn test_put_nonsync_clears_memory() {
        let _lock = lock_cache_for_test();
        let k = unique_key("memclear");
        put_memory(&k, "old");
        put(&k, "new", 3600);
        // 非永久 put 清除内存层（对齐上游 put 后 deleteMemory）
        assert!(get_from_memory(&k).is_none());
        // 磁盘层仍可读
        assert_eq!(get(&k, true).as_deref(), Some("new"));
        delete(&k);
    }

    #[test]
    fn test_file_roundtrip() {
        let _lock = lock_cache_for_test();
        let k = unique_key("file");
        assert!(put_file(&k, "file-value"));
        assert_eq!(get_file(&k).as_deref(), Some("file-value"));
        // putFile/getFile 不进内存层
        assert!(get_from_memory(&k).is_none());
        delete(&k);
        assert!(get_file(&k).is_none());
    }

    #[test]
    fn test_missing_key_returns_none() {
        let _lock = lock_cache_for_test();
        let k = unique_key("missing");
        assert!(get(&k, false).is_none());
        assert!(get(&k, true).is_none());
        assert!(get_file(&k).is_none());
        assert!(get_from_memory(&k).is_none());
    }

    /// P2-11 ②：注入目录 → put→get 命中（磁盘文件落注入目录，清理后回落缺省）
    ///
    /// 前置清理改用显式测试覆盖槽（[`set_test_disk_dir_override`]）而非
    /// `remove_var`：env 是进程级全局状态，并行测试中操作它是 UB。
    #[test]
    fn test_set_cache_dir_injected_hit() {
        let _lock = lock_cache_for_test();
        let root = unique_root("injected-hit");
        let injected = root.join("injected");
        let k = unique_key("inj");
        set_test_disk_dir_override(None);
        clear_cache_dir();
        set_cache_dir(&injected);
        assert_eq!(disk_dir(), injected);
        // 注入目录 → put→get 命中（永久值：内存/onlyDisk 双路）
        assert!(put(&k, "injected-value", 0));
        assert_eq!(get(&k, false).as_deref(), Some("injected-value"));
        // onlyDisk 跳过内存层，直接读注入目录下的磁盘文件
        assert_eq!(get(&k, true).as_deref(), Some("injected-value"));
        assert!(disk_path(&k).starts_with(&injected));
        delete(&k);
        clear_cache_dir();
        // 清除注入后回落缺省 temp 目录
        assert_eq!(disk_dir(), std::env::temp_dir().join("legado-js-cache"));
        let _ = fs::remove_dir_all(&root);
    }

    /// P2-11 ②：写盘失败 → 保留内存层（新值晋升内存层，同进程可读）
    ///
    /// 路径 A：注入目录指向普通文件 → `create_dir_all` 失败；
    /// 路径 B：注入目录存在但磁盘路径预建为目录 → `fs::write` 失败（EISDIR）；
    /// `put_file` 失败仅记日志（纯磁盘 API 无内存层可降级）。
    #[test]
    fn test_put_write_failure_keeps_memory() {
        let _lock = lock_cache_for_test();
        let root = unique_root("write-fail");
        let k1 = unique_key("wfail-a");
        let k2 = unique_key("wfail-b");
        let k3 = unique_key("wfail-c");
        set_test_disk_dir_override(None);
        fs::create_dir_all(&root).expect("临时根目录");

        // 路径 A：注入目录指向普通文件 → create_dir_all 失败
        let file_blocker = root.join("blocker.txt");
        fs::write(&file_blocker, "x").expect("blocker 文件");
        clear_cache_dir();
        set_cache_dir(&file_blocker);
        assert!(!put(&k1, "v1", 0));
        // 新值晋升内存层：同进程可读
        assert_eq!(get_from_memory(&k1).as_deref(), Some("v1"));
        assert_eq!(get(&k1, false).as_deref(), Some("v1"));
        // 磁盘层为空 → onlyDisk 读不受影响
        assert!(get(&k1, true).is_none());

        // 路径 B：注入目录存在，磁盘路径预建为目录 → fs::write 失败
        let injected = root.join("inj-b");
        clear_cache_dir();
        set_cache_dir(&injected);
        fs::create_dir_all(disk_path(&k2)).expect("磁盘路径预建为目录");
        assert!(!put(&k2, "v2", 0));
        assert_eq!(get_from_memory(&k2).as_deref(), Some("v2"));
        assert!(get(&k2, true).is_none());

        // put_file 失败路径：file 路径预建为目录 → 仅记日志，无内存层
        fs::create_dir_all(file_path(&k3)).expect("file 路径预建为目录");
        assert!(!put_file(&k3, "vf"));
        assert!(get_from_memory(&k3).is_none());
        assert!(get_file(&k3).is_none());

        // 收尾（P2-15 剩项：重置写失败告警标志，测试隔离）
        delete_memory(&k1);
        delete_memory(&k2);
        clear_cache_dir();
        reset_write_fail_warned();
        let _ = fs::remove_dir_all(&root);
    }

    /// P2-11 ②：目录解析优先级（测试构建：显式覆盖槽 > 注入 > 缺省 temp；
    /// 生产构建为 env > 注入 > 缺省，cfg(not(test)) 路径逐字节未动）
    ///
    /// 原用例经 `set_var`/`remove_var` 操作进程级 env 验证「env 优先级最高」，
    /// 现替换为测试覆盖槽（[`set_test_disk_dir_override`]）验证同构的
    /// 「显式覆盖 > 注入 > 缺省」优先级——消除并行测试的 env 全局状态污染。
    #[test]
    fn test_cache_dir_priority_and_default() {
        let _lock = lock_cache_for_test();
        let root = unique_root("priority");
        let env_dir = root.join("env-dir");
        let injected = root.join("injected-dir");
        let k = unique_key("prio");
        set_test_disk_dir_override(None);
        clear_cache_dir();

        // 未注入且未覆盖 → 现状行为：回落 <temp_dir>/legado-js-cache，往返仍可用
        assert_eq!(disk_dir(), std::env::temp_dir().join("legado-js-cache"));
        assert!(put(&k, "default-value", 0));
        assert_eq!(get(&k, false).as_deref(), Some("default-value"));
        delete(&k);

        // 显式覆盖槽优先级最高（同时存在注入时也优先覆盖槽）
        set_test_disk_dir_override(Some(env_dir.clone()));
        set_cache_dir(&injected);
        assert_eq!(disk_dir(), env_dir);

        // 清除覆盖槽后注入目录生效
        set_test_disk_dir_override(None);
        assert_eq!(disk_dir(), injected);

        set_test_disk_dir_override(None);
        clear_cache_dir();
        let _ = fs::remove_dir_all(&root);
    }

    /// P2-15 剩项 ④：写失败告警限流——进程内首条失败记录（返回 true），
    /// 后续同类失败静默（返回 false）；`put`/`putFile` 两标志互独立；
    /// 重置后（测试隔离）可再次首条触发
    #[test]
    fn test_write_fail_warned_once() {
        let _lock = lock_cache_for_test();
        reset_write_fail_warned();
        assert!(warn_once(&PUT_WRITE_FAIL_WARNED, || {}), "首条失败应记录");
        assert!(
            !warn_once(&PUT_WRITE_FAIL_WARNED, || {}),
            "后续同类失败应静默"
        );
        // putFile 标志与 put 标志互独立
        assert!(warn_once(&PUT_FILE_WRITE_FAIL_WARNED, || {}));
        assert!(!warn_once(&PUT_FILE_WRITE_FAIL_WARNED, || {}));
        // 重置后（测试隔离）可再次首条触发
        reset_write_fail_warned();
        assert!(warn_once(&PUT_WRITE_FAIL_WARNED, || {}));
        // 收尾：两标志保持已消费态（无其他测试依赖其首条语义）
    }
}
