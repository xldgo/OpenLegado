//! HTTP与云TTS共用的音频文件缓存及MIME映射。— Codex + Rust
//!
//! 请求求值和合成由Fetcher负责；本模块只负责缓存读写与音频类型工具。

use crate::error::{LegadoError, LegadoResult};
use std::path::{Path, PathBuf};

/// 合成音频缓存文件名前缀。
pub const SPEAK_CACHE_PREFIX: &str = "tts_";

/// Content-Type → 音频文件扩展名映射（无法识别时回退 `mp3`）
pub fn ext_from_content_type(content_type: &str) -> &'static str {
    let ct = content_type
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_lowercase();
    match ct.as_str() {
        "audio/mpeg" | "audio/mp3" => "mp3",
        "audio/wav" | "audio/x-wav" | "audio/wave" => "wav",
        "audio/aac" => "aac",
        "audio/mp4" | "audio/x-m4a" | "audio/m4a" => "m4a",
        "audio/ogg" | "application/ogg" => "ogg",
        "audio/amr" => "amr",
        "audio/flac" => "flac",
        _ => "mp3",
    }
}

/// 扩展名 → MIME 类型反查（缓存命中时用于回填 contentType）
pub fn content_type_from_ext(ext: &str) -> &'static str {
    match ext {
        "wav" => "audio/wav",
        "aac" => "audio/aac",
        "m4a" => "audio/mp4",
        "ogg" => "audio/ogg",
        "amr" => "audio/amr",
        "flac" => "audio/flac",
        _ => "audio/mpeg",
    }
}

/// 判断 Content-Type 是否为错误内容（对齐原版：json/text 响应体即报错信息）
pub fn is_error_content_type(content_type: &str) -> bool {
    let ct = content_type
        .split(';')
        .next()
        .unwrap_or("")
        .trim()
        .to_lowercase();
    ct == "application/json" || ct.starts_with("text/")
}

/// 缓存命中探测的扩展名集合（与 `ext_from_content_type` 的输出保持一致）
///
/// 只探测已知扩展名即可覆盖全部写入路径：`put` 的扩展名来自该映射，
/// 因此无需再扫描目录。
const CACHE_EXTENSIONS: [&str; 7] = ["mp3", "wav", "aac", "m4a", "ogg", "amr", "flac"];

/// 合成音频文件缓存：`{dir}/tts_{md5}.{ext}`
///
/// 文件系统即索引（对照原版 `hasSpeakFile` / `createSpeakFile` 目录扫描模式），
/// 进程重启后缓存仍然有效。
pub struct SpeakCache {
    dir: PathBuf,
}

impl SpeakCache {
    /// 创建缓存实例，目录不存在时自动创建
    pub fn new(dir: PathBuf) -> Self {
        if !dir.exists() {
            std::fs::create_dir_all(&dir).ok();
        }
        Self { dir }
    }

    /// 缓存目录
    pub fn dir(&self) -> &Path {
        &self.dir
    }

    /// 查找缓存文件，未命中返回 None；空文件视为未命中
    ///
    /// 评审修复（性能，高价值）：原实现 `read_dir` 遍历整个缓存目录并逐条
    /// `is_file()` + `metadata()`，每次合成都扫一遍（含纯缓存命中），目录越大
    /// 越慢，朗读期间形成持续的目录遍历 I/O。现按已知扩展名逐个探测：
    /// 最多 7 次 `metadata`，命中通常 1 次，与目录规模无关。
    ///
    /// 兼容性：`put` 只会写入 `ext_from_content_type` 产出的 7 种扩展名，
    /// 探测集合与之一致；`.part` 临时文件不再可能被误命中（旧实现仅按
    /// `tts_{key}.` 前缀匹配，文件名形如 `tts_{key}.mp3.part` 会被当作音频）。
    pub fn get(&self, key: &str) -> Option<PathBuf> {
        for ext in CACHE_EXTENSIONS {
            let path = self
                .dir
                .join(format!("{}{}.{}", SPEAK_CACHE_PREFIX, key, ext));
            match std::fs::metadata(&path) {
                Ok(meta) if meta.is_file() && meta.len() > 0 => return Some(path),
                _ => continue,
            }
        }
        None
    }

    /// 写入缓存文件并返回路径（同键旧扩展名文件先清理，避免残留）
    pub fn put(&self, key: &str, ext: &str, bytes: &[u8]) -> LegadoResult<PathBuf> {
        use std::io::Write;
        use std::sync::atomic::{AtomicU64, Ordering};
        static NEXT: AtomicU64 = AtomicU64::new(0);
        if bytes.is_empty() {
            return Err(LegadoError::ContentEmpty("拒绝缓存空音频".into()));
        }
        std::fs::create_dir_all(&self.dir)?;
        let old = self.get(key);
        let path = self
            .dir
            .join(format!("{}{}.{}", SPEAK_CACHE_PREFIX, key, ext));
        let temp = self.dir.join(format!(
            ".tts_{}_{}_{}.part",
            key,
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        struct TempFile(PathBuf);
        impl Drop for TempFile {
            fn drop(&mut self) {
                let _ = std::fs::remove_file(&self.0);
            }
        }
        let mut file = std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temp)?;
        let cleanup = TempFile(temp.clone());
        file.write_all(bytes)?;
        // 性能（发热治理）：`sync_all` 会连 inode 元数据一起刷盘，朗读期间每段
        // 一次即形成稳定 fsync 开销。这里只需保证数据落盘后再 rename 发布，
        // `sync_data`（fdatasync）已足够；音频是可再生缓存，掉电最坏重合成。
        file.sync_data()?;
        drop(file);
        // 完整写入之后才发布；扫描不识别 .part 临时文件。
        std::fs::rename(&temp, &path)?;
        drop(cleanup);
        if let Some(old) = old
            && old != path
        {
            let _ = std::fs::remove_file(old);
        }
        Ok(path)
    }

    /// 清空全部合成缓存文件，返回删除数量
    pub fn clear(&self) -> usize {
        let mut removed = 0;
        let entries = match std::fs::read_dir(&self.dir) {
            Ok(entries) => entries,
            Err(_) => return 0,
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                let name = path.file_name().map(|n| n.to_string_lossy().to_string());
                if name.is_some_and(|n| n.starts_with(SPEAK_CACHE_PREFIX))
                    && std::fs::remove_file(&path).is_ok()
                {
                    removed += 1;
                }
            }
        }
        removed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "legado_tts_speak_test_{}_{}_{}",
            tag,
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).ok();
        dir
    }

    // ─── Content-Type 判定 ───────────────────────────────────

    #[test]
    fn test_ext_from_content_type() {
        assert_eq!(ext_from_content_type("audio/mpeg"), "mp3");
        assert_eq!(ext_from_content_type("audio/wav; charset=binary"), "wav");
        assert_eq!(ext_from_content_type("audio/x-m4a"), "m4a");
        assert_eq!(ext_from_content_type("application/octet-stream"), "mp3");
    }

    #[test]
    fn test_is_error_content_type() {
        assert!(is_error_content_type("application/json"));
        assert!(is_error_content_type("application/json; charset=utf-8"));
        assert!(is_error_content_type("text/html"));
        assert!(!is_error_content_type("audio/mpeg"));
        assert!(!is_error_content_type(""));
    }

    // ─── 缓存文件读写 ────────────────────────────────────────

    #[test]
    fn test_speak_cache_put_get_clear() {
        let dir = test_dir("cache");
        let cache = SpeakCache::new(dir.clone());
        assert!(cache.get("abc").is_none());

        let path = cache.put("abc", "mp3", b"ID3data").unwrap();
        assert!(path.exists());
        assert_eq!(cache.get("abc"), Some(path.clone()));

        // 原子替换后旧扩展名不能残留，临时文件不得被扫描命中。
        let updated = cache.put("abc", "wav", b"NEW_AUDIO").unwrap();
        assert!(!path.exists());
        assert_eq!(cache.get("abc"), Some(updated));
        assert!(cache.put("empty", "mp3", b"").is_err());
        std::fs::write(dir.join(".tts_incomplete.part"), b"partial").unwrap();
        assert!(cache.get("incomplete").is_none());
        // 空文件视为未命中
        let empty = dir.join("tts_emptykey.mp3");
        std::fs::write(&empty, b"").unwrap();
        assert!(cache.get("emptykey").is_none());

        // clear 删除所有 tts_ 前缀文件（含空文件）
        assert_eq!(cache.clear(), 2);
        assert!(cache.get("abc").is_none());
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn test_speak_cache_get_is_key_exact_and_never_returns_partial_files() {
        let dir = test_dir("probe");
        let cache = SpeakCache::new(dir.clone());

        // 无关文件与同前缀键不得误命中
        std::fs::write(dir.join("tts_abcdef.mp3"), b"other").unwrap();
        std::fs::write(dir.join("tts_partial.wav.part"), b"PARTIAL_AUDIO").unwrap();
        assert!(cache.get("abc").is_none());
        assert!(cache.get("partial").is_none());
        assert!(cache.get("abcdef").is_some());

        // 已知扩展名按 key 精确命中；空文件仍视为未命中
        let path = cache.put("probe-key", "wav", b"RIFFDATA").unwrap();
        assert_eq!(cache.get("probe-key"), Some(path));
        std::fs::write(dir.join("tts_empty.mp3"), b"").unwrap();
        assert!(cache.get("empty").is_none());

        std::fs::remove_dir_all(&dir).ok();
    }
}
