//! 音频文件缓存：显式目录及下载资源；保留完成标记、分片锁和块级取消规则。
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository};
use legado_net::{LegadoClient, LegadoRequest, Method};
use legado_parser::{AnalyzeUrl, TemplateContext};

const COMPLETE_SUFFIX: &str = ".complete";
const CACHE_FILE_PATTERN: &str =
    r"^([0-9]{5,})_([0-9a-f]{16})_.+_([0-9a-f]{16})_([0-9a-f]{8})\.([a-z0-9]{2,6})$";
const AUDIO_EXTENSIONS: &[&str] = &[
    "mp3", "m4a", "m4b", "aac", "ogg", "oga", "opus", "wav", "flac", "webm", "amr", "3gp",
];
const STALE_PARTIAL_AGE_MILLIS: u64 = 60 * 60 * 1000;
const TMP_PREFIX: &str = "tmp_";
const PART_SUFFIX: &str = ".part";
static RANDOM_COUNTER: AtomicU64 = AtomicU64::new(0);
static SCAN_FAIL_WARNED: AtomicBool = AtomicBool::new(false);
#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AudioCacheDownloadStatus {
    Installed,
    AlreadyCached,
}
#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioCacheDownload {
    pub status: AudioCacheDownloadStatus,
    pub path: String,
    pub size_bytes: u64,
    pub extension: String,
}
pub struct AudioCacheService {
    directory: PathBuf,
}
impl AudioCacheService {
    pub fn new(directory: PathBuf) -> Self {
        Self { directory }
    }
    /// 书级缓存目录（对齐原版 `AudioCacheManager.getBookFolder` L210：
    /// `book_{md5Encode16(bookUrl)}`，即时计算、无映射表）
    fn book_dir(&self, book_url: &str) -> PathBuf {
        self.directory.join(format!("book_{}", md5_mid16(book_url)))
    }
    /// 查询某章是否已缓存（契约 §2.47 `audioCacheQuery`，只读、幂等）
    ///
    /// `chapter_index` 不参与键计算（对齐原版：键只由 chapterUrl/title 决定），
    /// 保留形参以对齐冻结的 FFI 签名。任何 IO/解析失败一律返回 `false`，不抛异常。
    pub fn audio_cache_query(
        &self,
        book_url: &str,
        _chapter_index: i32,
        chapter_url: &str,
        chapter_title: &str,
    ) -> bool {
        let key16 = cache_key16(chapter_url, chapter_title);
        latest_committed_file(&self.book_dir(book_url), &key16).is_some()
    }
    /// 列出该书已缓存章节下标（契约 §2.47 `audioCacheList`，只读、幂等）
    ///
    /// 扫描书目录，按五段式正则解析章节序号与 key，仅收录通过
    /// `.complete` + `size > 0` 校验的条目；下标去重、升序。无缓存/失败返回空数组。
    pub fn audio_cache_list(&self, book_url: &str) -> Vec<i32> {
        let dir = self.book_dir(book_url);
        let files = read_dir_entries(&dir);
        let names: HashSet<&str> = files.iter().map(|(n, _)| n.as_str()).collect();
        let mut indexes = BTreeSet::new();
        let mut skipped = 0usize;
        for (name, meta) in &files {
            if name.ends_with(COMPLETE_SUFFIX) {
                continue; // 标记文件本身不是数据文件，不算「不匹配文件」
            }
            let Some(parsed) = parse_cache_file_name(name) else {
                skipped += 1;
                continue;
            };
            if is_committed(&names, name, meta) {
                indexes.insert(parsed.chapter_index);
            }
        }
        if skipped > 0 {
            log::debug!(
                "[audio_cache] 目录 {dir:?} 跳过 {skipped} 个不匹配五段式命名的文件（旧键/残留文件不读不迁移）"
            );
        }
        indexes.into_iter().collect()
    }
    /// 清理某章缓存（契约 §2.47 `audioCacheClearChapter`，幂等）
    ///
    /// 只删该 `key16` 下的音频文件、暂存部分文件与 `.complete` 标记（不触碰同目录
    /// 其他章节），返回**实际删除的数据文件数**（仅统计 dataTargets——数据文件与
    /// `tmp_*.part`，**不计 `.complete` 标记**，对齐原版 `removeCacheFiles:338-356`
    /// 的 `return dataTargets.size`；标记照删）。不存在/已删返回 `0`，IO 失败按
    /// 已删数返回，不抛异常。
    ///
    /// 与下载共用同一把 `(bookUrl, key16)` 章节分片锁（对齐原版
    /// `removeCachedChapter:92-105` 的 `chapterLock(bookUrl, key).withLock`——
    /// 原版该函数为 `suspend`，清理与在途下载互斥，避免互删对方产物）。
    /// 本函数为**阻塞实现**，FFI 侧经 spawn_blocking 包装为非阻塞
    /// （`audio_cache_clear_chapter` async 导出）：清理等待在途下载完成
    /// （最坏受下载自身时长约束），UI isolate 不被阻塞。
    pub fn audio_cache_clear_chapter(
        &self,
        book_url: &str,
        _chapter_index: i32,
        chapter_url: &str,
        chapter_title: &str,
    ) -> i32 {
        let key16 = cache_key16(chapter_url, chapter_title);
        let dir = self.book_dir(book_url);
        let chapter_shard = chapter_lock(book_url, &key16);
        let _chapter_guard = chapter_shard.lock().unwrap_or_else(|e| e.into_inner());
        remove_cache_files(&dir, &key16, None)
    }
    /// 清理该书全部缓存（契约 §2.47 `audioCacheClearBook`，幂等）
    ///
    /// 删除书级目录内全部文件（含 `.complete`），返回实际删除数（**仅统计数据
    /// 文件，`tmp_*.part` 计入、`.complete` 标记不计**——与单章清理同口径，对齐
    /// 原版 `removeCacheFiles` 的 dataTargets 计数语义）；书目录一并尝试移除
    /// （非空/被占用则忽略）。不跨书（目录按 `md5_16(bookUrl)` 隔离），不抛异常。
    pub fn audio_cache_clear_book(&self, book_url: &str) -> i32 {
        let dir = self.book_dir(book_url);
        let files = read_dir_entries(&dir);
        let mut deleted = 0i32;
        for (name, _meta) in &files {
            if name.ends_with(COMPLETE_SUFFIX) {
                continue; // 标记照删、不计入返回值
            }
            if fs::remove_file(dir.join(name)).is_ok() {
                deleted += 1;
            }
        }
        // 标记文件单独删（不计数）
        for (name, _meta) in &files {
            if name.ends_with(COMPLETE_SUFFIX) {
                let _ = fs::remove_file(dir.join(name));
            }
        }
        let _ = fs::remove_dir(&dir);
        deleted
    }
}
/// MD5 小写 hex 中段 16 字符（对齐原版 `MD5Utils.md5Encode16` = `hex[8..24)`，
/// 与 image_cache_api / legado-js `encoding::md5_encode_16` 同口径）
fn md5_mid16(input: &str) -> String {
    let hex = format!("{:x}", md5::compute(input));
    hex[8..24].to_string()
}

/// 对齐 Kotlin `Char.isWhitespace()`（Java `Character.isWhitespace`）：
/// Unicode 空白，但排除 NBSP 系（U+00A0 / U+2007 / U+202F）与 NEL U+0085
/// （后四者 Rust `char::is_whitespace()` 为 true 而 Java 为 false，逐字符纠偏）
fn kotlin_char_is_whitespace(c: char) -> bool {
    match c {
        '\u{00A0}' | '\u{2007}' | '\u{202F}' | '\u{0085}' => false,
        '\u{0009}'..='\u{000D}' | '\u{001C}'..='\u{001F}' => true,
        c => c.is_whitespace(),
    }
}

/// 对齐 Kotlin `String.isBlank()`（空串或全空白字符）
pub fn kotlin_is_blank(s: &str) -> bool {
    s.chars().all(kotlin_char_is_whitespace)
}

/// 章节缓存键（对齐原版 `AudioCacheKey.from(chapterUrl, chapterTitle)`）：
/// `md5Encode16(chapterUrl.ifBlank { chapterTitle })`——不 trim、大小写敏感。
/// 入参顺序便于与 FFI 面一致，`chapter_url` 为空/纯空白时退回标题。
pub fn cache_key16(chapter_url: &str, chapter_title: &str) -> String {
    let identity = if kotlin_is_blank(chapter_url) {
        chapter_title
    } else {
        chapter_url
    };
    md5_mid16(identity)
}

/// 五段式缓存文件名解析结果（title / playUrlHash / rev 三段不参与命中判定；
/// extension 供 `already_cached` 返回与安装流程复用）
#[derive(Debug, Clone, PartialEq, Eq)]
struct ParsedCacheFileName {
    /// 章节序号（正则第一段，`toIntOrNull` 溢出即视为不匹配）
    chapter_index: i32,
    /// 缓存键（正则第二段，小写 16 hex）
    key16: String,
    /// 扩展名（正则第五段，白名单内）
    extension: String,
}

/// 解析五段式缓存文件名（对齐原版 `AudioCachePolicy.parseFileName`）：
/// 正则不匹配 / 扩展名不在白名单 / 章节序号溢出 → `None`（跳过该文件）
fn parse_cache_file_name(name: &str) -> Option<ParsedCacheFileName> {
    let regex = CACHE_FILE_REGEX
        .get_or_init(|| regex::Regex::new(CACHE_FILE_PATTERN).ok())
        .as_ref()?;
    let caps = regex.captures(name)?;
    let chapter_index = caps.get(1)?.as_str().parse::<i32>().ok()?;
    let key16 = caps.get(2)?.as_str().to_string();
    let extension = caps.get(5)?.as_str();
    if extension != "audio" && !AUDIO_EXTENSIONS.contains(&extension) {
        return None;
    }
    Some(ParsedCacheFileName {
        chapter_index,
        key16,
        extension: extension.to_string(),
    })
}

/// 五段式正则（进程级编译一次；编译失败降级为不匹配——不可能失败，但避免 panic）
static CACHE_FILE_REGEX: OnceLock<Option<regex::Regex>> = OnceLock::new();

/// 一次性降级告警（目录扫描失败，不逐条刷屏）
fn warn_scan_fail_once(dir: &Path, err: &io::Error) {
    if SCAN_FAIL_WARNED
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
    {
        log::warn!(
            "[audio_cache] 目录扫描失败 {dir:?}: {err}（降级：查询/列举按无缓存处理，不影响在线播放；同类失败后续不再逐条记日志）"
        );
    }
}

/// 列出目录内的普通文件 `(文件名, 元数据)`；目录不存在返回空；其他 IO 错误
/// 降级空列表 + 一次性告警（**不抛异常**）。非 UTF-8 文件名跳过（缓存文件名恒为 ASCII）。
fn read_dir_entries(dir: &Path) -> Vec<(String, fs::Metadata)> {
    let mut out = Vec::new();
    let entries = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return out,
        Err(e) => {
            warn_scan_fail_once(dir, &e);
            return out;
        }
    };
    for entry in entries.flatten() {
        let Ok(meta) = entry.metadata() else {
            continue;
        };
        if !meta.is_file() {
            continue;
        }
        if let Some(name) = entry.file_name().to_str() {
            out.push((name.to_string(), meta));
        }
    }
    out
}

/// 命中判定（对齐原版 `committedCacheFiles` L358-373）：
/// 音频文件 `size > 0` 且同名 `.complete` 标记存在
fn is_committed(names: &HashSet<&str>, name: &str, meta: &fs::Metadata) -> bool {
    if meta.len() == 0 {
        return false;
    }
    let marker = format!("{name}{COMPLETE_SUFFIX}");
    names.contains(marker.as_str())
}

/// 该书目录下指定 key 的最新已提交缓存数据文件（文件名 + 元数据）
/// （对齐原版 `findCachedFile` L201-203：`maxByOrNull { it.lastModified }`；
/// `lastModified` 不可得时按 UNIX_EPOCH 参与比较，不 panic）
fn latest_committed_file(dir: &Path, key16: &str) -> Option<(String, fs::Metadata)> {
    let files = read_dir_entries(dir);
    let names: HashSet<&str> = files.iter().map(|(n, _)| n.as_str()).collect();
    let mut best: Option<(String, SystemTime, fs::Metadata)> = None;
    for (name, meta) in &files {
        let Some(parsed) = parse_cache_file_name(name) else {
            continue;
        };
        if parsed.key16 != key16 || !is_committed(&names, name, meta) {
            continue;
        }
        let modified = meta.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        if best.as_ref().is_none_or(|(_, t, _)| modified > *t) {
            best = Some((name.clone(), modified, meta.clone()));
        }
    }
    best.map(|(name, _, meta)| (name, meta))
}

// ─── B2 写入面（契约 §2.48，对齐 AudioCacheManager.cacheChapter 132-199） ──────

/// ISO 控制符判定（对齐 Kotlin `Char.isISOControl`）：C0（U+0000..=U+001F）
/// 与 C1（U+007F..=U+009F）
fn is_iso_control(c: char) -> bool {
    matches!(c, '\u{0000}'..='\u{001F}' | '\u{007F}'..='\u{009F}')
}

/// 标题 → 安全文件名段（对齐原版 `AudioCachePolicy.buildFileName:79-87`）：
/// 非法文件名字符（`[\\/:*?"<>|]`，对齐 `AppPattern.fileNameRegex2:35`
/// / `StringExtensions.normalizeFileName:162-164`）替换 `_` → 去 ISO 控制符 →
/// trim（Kotlin `Char.isWhitespace` 语义，NBSP 不算）→ 去首尾 `_` → 空则
/// `"chapter"` → 截 40 字符 → 去尾部 `.`/空格 → 空则 `"chapter"`。
///
/// 已知边界：Kotlin `take(40)` 按 UTF-16 code unit 截断（非 BMP 字符可截出
/// 孤立代理项）；本实现按 Unicode scalar（`chars()`）截断以避免产出非法
/// UTF-8/文件名——仅当标题前 40 个 UTF-16 单元内含非 BMP 字符时与 Kotlin
/// 结果不同（章标题场景极罕见），登记为有意差异。
fn safe_title(chapter_title: &str) -> String {
    let replaced: String = chapter_title
        .chars()
        .map(|c| match c {
            '\\' | '/' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            other => other,
        })
        .collect();
    let filtered: String = replaced.chars().filter(|c| !is_iso_control(*c)).collect();
    let trimmed = filtered
        .trim_matches(kotlin_char_is_whitespace)
        .trim_matches('_');
    let non_blank = if kotlin_is_blank(trimmed) {
        "chapter".to_string()
    } else {
        trimmed.to_string()
    };
    let limited: String = non_blank.chars().take(40).collect();
    let trimmed_end = limited.trim_end_matches(['.', ' ']);
    if kotlin_is_blank(trimmed_end) {
        "chapter".to_string()
    } else {
        trimmed_end.to_string()
    }
}

/// URL → 音频扩展名（对齐原版 `AudioCachePolicy.extensionFromUrl:121-128`）：
/// 截 `?`/`#` 后取最后一个 `.` 之后部分小写；须 ∈ 音频扩展名白名单，否则 None。
/// 注：Kotlin `substringAfterLast('.', "")` 无 `.` 时为空串（Rust `rsplit` 会
/// 返回整串，故此处显式用 `rfind` 对齐）
fn extension_from_url(url: &str) -> Option<String> {
    let path = url
        .split('?')
        .next()
        .unwrap_or("")
        .split('#')
        .next()
        .unwrap_or("");
    let idx = path.rfind('.')?;
    let ext = path[idx + 1..].to_lowercase();
    AUDIO_EXTENSIONS.contains(&ext.as_str()).then_some(ext)
}

/// HLS 判定（对齐原版 `AudioCachePolicy.isHlsUrl:116-119`）：截 `?`/`#` 后
/// 以 `.m3u8`/`.m3u` 结尾（大小写不敏感）
fn is_hls_url(url: &str) -> bool {
    let path = url
        .split('?')
        .next()
        .unwrap_or("")
        .split('#')
        .next()
        .unwrap_or("");
    let lower = path.to_lowercase();
    lower.ends_with(".m3u8") || lower.ends_with(".m3u")
}

/// JSON 数组形态判定（对齐原版 `StringExtensions.isJsonArray:64-68`：
/// `trim()` 后首 `[` 尾 `]`）
fn is_json_array(s: &str) -> bool {
    let t = s.trim();
    t.starts_with('[') && t.ends_with(']')
}

/// playUrl 可缓存性校验（对齐原版 `AudioCachePolicy.requireCacheablePlayUrl:25-33`）：
/// 空 / JSON 数组多段 / HLS → Err（原文案，写入面上抛不降级）
fn require_cacheable_play_url(play_url: &str) -> LegadoResult<()> {
    if kotlin_is_blank(play_url) {
        return Err(LegadoError::Ffi("播放链接为空".into()));
    }
    if is_json_array(play_url) {
        return Err(LegadoError::Ffi("暂不支持缓存多段音频".into()));
    }
    if is_hls_url(play_url) {
        return Err(LegadoError::Ffi("暂不支持缓存 HLS 音频".into()));
    }
    Ok(())
}

/// 扩展名三级探测（对齐原版 `AudioCachePolicy.detectExtension:35-65`）：
/// Content-Type（截 `;`/trim/小写）→ 最终 URL 后缀 → playUrl 后缀 → 缺省
/// `"audio"`；Content-Type 含 `mpegurl` 或最终 URL 为 HLS → Err「暂不支持
/// 缓存 HLS 音频」（`:45-47`）。
fn detect_extension(
    content_type: Option<&str>,
    final_url: &str,
    play_url: &str,
) -> LegadoResult<String> {
    require_cacheable_play_url(play_url)?;
    let normalized =
        content_type.map(|ct| ct.split(';').next().unwrap_or("").trim().to_lowercase());
    if normalized
        .as_deref()
        .is_some_and(|ct| ct.contains("mpegurl"))
        || is_hls_url(final_url)
    {
        return Err(LegadoError::Ffi("暂不支持缓存 HLS 音频".into()));
    }
    let ext = match normalized.as_deref() {
        // Content-Type 缺失（None）：直接由 URL 三级兜底（对齐 Kotlin when 第一支）
        None => extension_from_url(final_url)
            .or_else(|| extension_from_url(play_url))
            .unwrap_or_else(|| "audio".to_string()),
        Some(ct) => {
            if ct.contains("mpeg") || ct.contains("mp3") {
                "mp3".to_string()
            } else if ct.contains("m4a") || ct.contains("mp4") {
                "m4a".to_string()
            } else if ct.contains("aac") {
                "aac".to_string()
            } else if ct.contains("ogg") {
                "ogg".to_string()
            } else if ct.contains("opus") {
                "opus".to_string()
            } else if ct.contains("wav") {
                "wav".to_string()
            } else if ct.contains("flac") {
                "flac".to_string()
            } else if ct.contains("webm") {
                "webm".to_string()
            } else if ct.contains("amr") {
                "amr".to_string()
            } else if ct.contains("3gpp") {
                "3gp".to_string()
            } else {
                extension_from_url(final_url)
                    .or_else(|| extension_from_url(play_url))
                    .unwrap_or_else(|| "audio".to_string())
            }
        }
    };
    Ok(ext)
}

/// 五段式文件名生成（对齐原版 `AudioCachePolicy.buildFileName:67-98`）：
/// `%05d_{key16}_{safeTitle}_{playUrlHash16}_{rev8}.{ext}`；
/// 各段先决条件不满足 → Err（对齐 Kotlin `require`，服务按章计 fail）
fn build_file_name(
    chapter_index: i32,
    key16: &str,
    chapter_title: &str,
    play_url_hash: &str,
    revision: &str,
    extension: &str,
) -> LegadoResult<String> {
    let is_hex = |s: &str, len: usize| {
        s.len() == len
            && s.chars()
                .all(|c| c.is_ascii_digit() || ('a'..='f').contains(&c))
    };
    if chapter_index < 0 {
        return Err(LegadoError::Ffi("章节序号非法".into()));
    }
    if !is_hex(play_url_hash, 16) {
        return Err(LegadoError::Ffi("playUrl 哈希非法".into()));
    }
    if !is_hex(revision, 8) {
        return Err(LegadoError::Ffi("修订号非法".into()));
    }
    if extension != "audio" && !AUDIO_EXTENSIONS.contains(&extension) {
        return Err(LegadoError::Ffi(format!("扩展名非法: {extension}")));
    }
    Ok(format!(
        "{:05}_{key16}_{safe_title}_{play_url_hash}_{revision}.{extension}",
        chapter_index,
        safe_title = safe_title(chapter_title),
    ))
}

/// `.complete` 元数据编码（对齐原版 `AudioCacheMetadata.encode:141-143`）：
/// UTF-8 三行 `1\n{md5_16(playUrl)}\n{playUrl}`
fn encode_metadata(play_url: &str) -> String {
    format!("1\n{}\n{}", md5_mid16(play_url), play_url)
}

/// `.complete` 元数据解码/校验（对齐原版 `AudioCacheMetadata.decode:145-152`）：
/// 恰好 3 行（limit=3，第 3 行保留含换行的 playUrl 原文）、版本为 `1`、
/// playUrl 非空白且 md5_16 匹配 → Some(playUrl)，否则 None
fn decode_metadata(metadata: &str) -> Option<String> {
    let parts: Vec<&str> = metadata.splitn(3, '\n').collect();
    if parts.len() != 3 || parts[0] != "1" {
        return None;
    }
    let play_url = parts[2];
    if !kotlin_is_blank(play_url) && md5_mid16(play_url) == parts[1] {
        Some(play_url.to_string())
    } else {
        None
    }
}

/// 完整文件判定（对齐原版 `AudioCachePolicy.isCompleteFile:112-114`）：
/// `actualSize > 0 && (expectedSize == None || actualSize == expectedSize)`
fn require_complete_size(actual: u64, expected: Option<u64>) -> LegadoResult<()> {
    if actual == 0 {
        return Err(LegadoError::Ffi("音频文件为空".into()));
    }
    if expected.is_some_and(|e| actual != e) {
        return Err(LegadoError::Ffi("音频文件不完整".into()));
    }
    Ok(())
}

/// 随机小写十六进制串（rev8 对齐原版 `UUID.randomUUID().toString()
/// .replace("-","").take(8)`；tmp 文件名 token 为 32 位）。用进程内计数器 +
/// 纳秒时钟 + 随机种子哈希合成——仅用于防并发同名，非密码学随机。
fn random_hex(len: usize) -> String {
    use std::hash::{BuildHasher, Hasher};
    let mut out = String::with_capacity(len + 16);
    while out.len() < len {
        let n = RANDOM_COUNTER.fetch_add(1, Ordering::Relaxed);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let mut hasher = std::collections::hash_map::RandomState::new().build_hasher();
        hasher.write_u128(nanos);
        hasher.write_u64(n);
        out.push_str(&format!("{:016x}", hasher.finish()));
    }
    out.truncate(len);
    out
}

/// 暂存部分文件判定（对齐原版 `AudioCacheManager.isTemporaryFile:385-389`：
/// `!isDir && name.startsWith("tmp_{key}_") && name.endsWith(".part")`）
fn is_temporary_file(name: &str, key16: &str) -> bool {
    name.starts_with(&format!("{TMP_PREFIX}{key16}_")) && name.ends_with(PART_SUFFIX)
}

/// 五段式数据文件判定（对齐原版 `isCacheFile:391-395`）
fn is_cache_file_name(name: &str, key16: &str) -> bool {
    parse_cache_file_name(name).is_some_and(|p| p.key16 == key16)
}

/// 陈旧未提交文件清理（对齐原版 `cleanupUncommittedFiles:302-314`）：
/// 本 key 下的 `tmp_*.part` 与无 `.complete` 的五段式文件，`lastModified`
/// 位于 `[1, now - 1h]` 区间者删除（lastModified 为 0/不可得者不删）。
/// 失败静默（写入流程随后自会处理）。
fn cleanup_uncommitted_files(dir: &Path, key16: &str) {
    let files = read_dir_entries(dir);
    let complete_names: HashSet<&str> = files
        .iter()
        .filter(|(n, _)| n.ends_with(COMPLETE_SUFFIX))
        .map(|(n, _)| n.strip_suffix(COMPLETE_SUFFIX).unwrap_or(n.as_str()))
        .collect();
    let now = SystemTime::now();
    let stale_before_ms = now
        .checked_sub(Duration::from_millis(STALE_PARTIAL_AGE_MILLIS))
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_millis())
        .unwrap_or(0);
    for (name, meta) in &files {
        let uncommitted = is_temporary_file(name, key16)
            || (is_cache_file_name(name, key16) && !complete_names.contains(name.as_str()));
        if !uncommitted {
            continue;
        }
        let modified_ms = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_millis())
            .unwrap_or(0);
        if modified_ms >= 1 && modified_ms <= stale_before_ms {
            let _ = fs::remove_file(dir.join(name));
        }
    }
}

/// 按 key 清理数据文件/暂存文件/标记（对齐原版
/// `removeCacheFiles:338-356`）：`except_name` 为本次新安装文件名（保留）；
/// 返回 **dataTargets 计数**——`tmp_*.part` 与五段式数据文件（不含 `.complete`），
/// 标记照删不计。
fn remove_cache_files(dir: &Path, key16: &str, except_name: Option<&str>) -> i32 {
    let files = read_dir_entries(dir);
    let mut data_targets: Vec<String> = Vec::new();
    let mut marker_targets: Vec<String> = Vec::new();
    for (name, _meta) in &files {
        let is_data = is_cache_file_name(name, key16) || is_temporary_file(name, key16);
        if is_data && except_name != Some(name.as_str()) {
            data_targets.push(name.clone());
        }
        if let Some(base) = name.strip_suffix(COMPLETE_SUFFIX)
            && except_name != Some(base)
            && is_cache_file_name(base, key16)
        {
            marker_targets.push(name.clone());
        }
    }
    let count = data_targets.len() as i32;
    for name in data_targets.into_iter().chain(marker_targets) {
        let _ = fs::remove_file(dir.join(name));
    }
    count
}

/// 一次下载捕获原存储、目录、抓取资源和任务凭据，途中不重新发现宿主。
pub struct AudioDownloadContext {
    storage: crate::StorageContext,
    media: std::sync::Arc<crate::MediaState>,
    directory: PathBuf,
    factory: crate::reading_service::ReadingFetcherFactory,
    task: crate::TaskHandle,
    runtime: tokio::runtime::Handle,
}
impl AudioDownloadContext {
    pub fn new(
        storage: crate::StorageContext,
        media: std::sync::Arc<crate::MediaState>,
        directory: PathBuf,
        factory: crate::reading_service::ReadingFetcherFactory,
        tasks: &crate::TaskGroup,
        runtime: tokio::runtime::Handle,
    ) -> LegadoResult<Self> {
        Ok(Self {
            storage,
            media,
            directory,
            factory,
            runtime,
            task: tasks.begin().map_err(|e| LegadoError::Ffi(e.to_string()))?,
        })
    }

    fn wait<T>(
        &self,
        future: impl std::future::Future<Output = LegadoResult<T>>,
    ) -> LegadoResult<T> {
        self.runtime.block_on(async {
            tokio::select! {
                biased;
                _ = self.task.cancelled() => Err(LegadoError::Ffi("音频缓存下载已取消".into())),
                result = future => result,
            }
        })
    }
}

/// 章节锁分片数（对齐原版 `AudioCacheManager.chapterLocks:44`：`Array(16)`）
const CHAPTER_LOCK_SHARDS: usize = 16;

/// Java `String.hashCode()`（UTF-16 code unit 累加，`h = 31*h + c` 以 i32 截断），
/// 供分片索引与原版 `bookUrl.hashCode()` / `AudioCacheKey.hashCode()`
/// （即 16 hex 串的 `String.hashCode`）逐值对齐
fn java_string_hash(s: &str) -> i32 {
    let mut h: i32 = 0;
    for unit in s.encode_utf16() {
        h = h.wrapping_mul(31).wrapping_add(unit as i32);
    }
    h
}

/// 语义同 Java `Math.floorMod(x, m)`（m > 0，负值取非负余数）
fn java_floor_mod(x: i32, m: i32) -> i32 {
    x.rem_euclid(m)
}

/// 按 `(bookUrl, key16)` 取章节分片锁（对齐原版 `chapterLock:414-416`：
/// `chapterLocks[Math.floorMod(31 * bookUrl.hashCode() + key.hashCode(), 16)]`；
/// 同 key 同分片串行，异 key 最多 16 路并行——与原版碰撞粒度一致）。
///
/// 使用范围（原版对照）：
/// - 写入面：覆盖 `audio_cache_download_with_client` 的 ② 幂等检查 → ⑧ 失败
///   清理整段，对齐原版 `cacheChapter:117-118`
///   `chapterLock(...).withLock { cacheChapterLocked(...) }` 的临界区
///   （含 `cleanupUncommittedFiles` / 安装 / 写标记 / `removeCacheFiles`
///   步骤⑦，`AudioCacheManager.kt:139-199`）——修复同章并发两条下载互删
///   产物/在写 tmp 的静默缓存丢失。
/// - 清理面：覆盖 `audio_cache_clear_chapter` 整段（对齐原版
///   `removeCachedChapter:92-105` 同样取此锁的 `withLock`；原版为 suspend，
///   我方 FFI 经 spawn_blocking 异步化后语义等价：等待在途下载完成再清理，
///   不阻塞 UI isolate）。
fn chapter_lock(book_url: &str, key16: &str) -> &'static Mutex<()> {
    static CHAPTER_LOCKS: OnceLock<[Mutex<()>; CHAPTER_LOCK_SHARDS]> = OnceLock::new();
    let locks = CHAPTER_LOCKS.get_or_init(|| std::array::from_fn(|_| Mutex::new(())));
    let combined = 31i32
        .wrapping_mul(java_string_hash(book_url))
        .wrapping_add(java_string_hash(key16));
    &locks[java_floor_mod(combined, CHAPTER_LOCK_SHARDS as i32) as usize]
}

/// 单章流式下载；先校验，再在原分片锁下安装并发布完成标记。
/// 阻塞等待使用宿主注入的运行时，失败清理部分文件并返回错误。
pub fn download(
    context: &AudioDownloadContext,
    client: &LegadoClient,
    book_url: &str,
    chapter_index: i32,
    chapter_url: &str,
    chapter_title: &str,
    play_url: &str,
) -> LegadoResult<AudioCacheDownload> {
    let _guard = context.task.guard();
    // ① 前置校验
    if kotlin_is_blank(book_url) {
        return Err(LegadoError::Ffi("书籍 URL 为空".into()));
    }
    let book = context
        .storage
        .with_database(|db| BookRepository::new(db.connection()).find_by_url(book_url))?
        .ok_or_else(|| LegadoError::Database(format!("书籍不存在: {book_url}")))?;
    let chapter = context
        .storage
        .with_database(|db| {
            BookChapterRepository::new(db.connection())
                .find_by_book_url_and_index(book_url, chapter_index)
        })?
        .ok_or_else(|| LegadoError::Database(format!("章节 {chapter_index} 不存在")))?;
    if chapter.is_volume {
        return Err(LegadoError::Ffi("分卷章节不支持缓存".into()));
    }
    let source = context
        .storage
        .with_database(|db| BookSourceRepository::new(db.connection()).find_by_url(&book.origin))?
        .ok_or_else(|| LegadoError::Database(format!("书源不存在: {}", book.origin)))?;
    require_cacheable_play_url(play_url)?;

    let key16 = cache_key16(chapter_url, chapter_title);
    let dir = context
        .directory
        .join(format!("book_{}", md5_mid16(book_url)));

    // ②–⑧ 临界区：同 (bookUrl, key16) 分片锁串行（对齐原版 `chapterLock`
    // `AudioCacheManager.kt:44,117,414-416` 的 `withLock` 范围）。无锁时两条
    // 同章下载会互相删除对方在写 tmp / 已装文件与标记，双方均报 installed
    // 但缓存净丢失（P1-1）。
    let chapter_shard = chapter_lock(book_url, &key16);
    let _chapter_guard = chapter_shard.lock().unwrap_or_else(|e| e.into_inner());

    // ② 幂等：已提交缓存直接返回（对齐原版服务循环 `AudioCacheService.kt:216` 跳过语义）
    if let Some((name, meta)) = latest_committed_file(&dir, &key16) {
        let extension = parse_cache_file_name(&name)
            .map(|p| p.extension)
            .unwrap_or_else(|| "audio".to_string());
        return Ok(AudioCacheDownload {
            status: AudioCacheDownloadStatus::AlreadyCached,
            path: dir.join(&name).to_string_lossy().into_owned(),
            size_bytes: meta.len(),
            extension,
        });
    }

    // ③ 目录就绪 + 陈旧未提交文件清理
    fs::create_dir_all(&dir).map_err(|e| {
        LegadoError::Io(io::Error::new(
            e.kind(),
            format!("音频缓存目录不可用 {dir:?}: {e}"),
        ))
    })?;
    cleanup_uncommitted_files(&dir, &key16);

    // 取消代数快照 + 在途登记（覆盖从发起到清理的全部路径）
    let transfer = context.media.begin_audio();

    // ④ AnalyzeUrl 解析 + 书源请求头/Cookie 语义（对齐原版构造
    // `AnalyzeUrl(playUrl, source=bookSource, ruleData=book, chapter=chapter)`：
    // 变量表 = book.variable ⊕ chapter.variable（章节优先），内置书名/标题/作者
    // 经 parse_with_context 注入；headers 合并顺序复用 fetch_page 全链路——
    // 书源 header+登录头（parse_source_headers 已含 CookieJar 写侧标记）→
    // AnalyzeUrl 解析头 → 请求 URL 属域 JS cookie）
    let merged_variable = legado_fetcher::web_book::merge_variables_json(
        book.variable.as_deref(),
        chapter.variable.as_deref(),
    );
    let variables = legado_fetcher::web_book::chapter_url_variables(merged_variable.as_deref());
    let template_context = TemplateContext {
        book_name: Some(book.name.clone()),
        title: Some(chapter.title.clone()),
        author: Some(book.author.clone()),
        extra: HashMap::new(),
    };
    let analyze_url = AnalyzeUrl::parse_with_context(play_url, &variables, &template_context, 1)?;

    let mut deps = (context.factory)()?;
    deps.client = client.clone();
    let fetcher = legado_fetcher::web_book::RealBookSourceFetcher::with_deps(deps);
    let mut headers = fetcher.parse_source_headers(&source).unwrap_or_default();
    headers.extend(analyze_url.headers().clone());
    let cookie = client
        .cookie_store()
        .read()
        .unwrap_or_else(|p| p.into_inner())
        .cookies_for_key(analyze_url.url());
    legado_js::host_api::cookie_store::merge_cookie_string(&mut headers, &cookie);

    let body = analyze_url.request_body();
    let request = LegadoRequest {
        url: analyze_url.url().to_string(),
        method: match analyze_url.method() {
            legado_parser::RequestMethod::Post => Method::Post,
            legado_parser::RequestMethod::Head => Method::Head,
            legado_parser::RequestMethod::Get => Method::Get,
        },
        headers,
        body: if body.is_empty() {
            None
        } else {
            Some(body.to_string())
        },
        timeout: analyze_url.timeout().map(Duration::from_millis),
    };

    // urlOption followRedirects/retry 语义（对齐 analyze_request::send_with_options：
    // 不跟随走派生客户端；非 2xx/3xx 且 retry>0 时立即重发，至多 retry 次）
    let effective = if analyze_url.follow_redirects() == Some(false) {
        client.no_redirect_variant()?
    } else {
        client.clone()
    };
    let mut retries_remaining = analyze_url.retry();
    let mut response = loop {
        let resp = context.wait(effective.send_stream(&request))?;
        if (200..400).contains(&resp.status()) || retries_remaining == 0 {
            break resp;
        }
        retries_remaining -= 1;
    };
    if !response.is_success() {
        return Err(LegadoError::Network(format!(
            "网络请求失败({})",
            response.status()
        )));
    }

    // 扩展名三级探测（下载响应 Content-Type/最终 URL 或 HLS → 拒绝）
    let final_url = response.url().to_string();
    let extension = detect_extension(
        response.content_type().map(|s| s.as_str()),
        &final_url,
        play_url,
    )?;
    let expected_size = response.content_length().filter(|n| *n > 0);

    let revision = random_hex(8);
    let final_name = build_file_name(
        chapter_index,
        &key16,
        chapter_title,
        &md5_mid16(play_url),
        &revision,
        &extension,
    )?;
    let staged_path = dir.join(format!("tmp_{key16}_{revision}_{}.part", random_hex(32)));
    let final_path = dir.join(&final_name);
    let marker_path = dir.join(format!("{final_name}{COMPLETE_SUFFIX}"));

    let result: LegadoResult<u64> = (|| {
        // ④ 流式落盘（字节直写盘；块级取消检查对齐 copyCancellable:397-412）
        {
            let file = fs::File::create(&staged_path)?;
            let mut writer = io::BufWriter::new(file);
            loop {
                if transfer.is_cancelled() || context.task.is_cancelled() {
                    return Err(LegadoError::Ffi("音频缓存下载已取消".into()));
                }
                match context.wait(response.next_chunk())? {
                    None => break,
                    Some(chunk) => writer.write_all(&chunk)?,
                }
            }
            writer.flush()?;
            if transfer.is_cancelled() || context.task.is_cancelled() {
                return Err(LegadoError::Ffi("音频缓存下载已取消".into()));
            }
        }

        context
            .task
            .with_active(|| {
                transfer
                    .with_active(|| {
                        // ⑤ size 校验 + 安装（优先 rename，失败退整文件复制后复验）
                        let staged_len = fs::metadata(&staged_path)?.len();
                        require_complete_size(staged_len, expected_size)?;
                        let installed_len =
                            install_staged_file(&staged_path, &final_path, expected_size)?;

                        // ⑥ 写 `.complete` 并回读校验（校验失败删标记报错）
                        if transfer.is_cancelled() || context.task.is_cancelled() {
                            return Err(LegadoError::Ffi("音频缓存下载已取消".into()));
                        }
                        write_complete_marker(&marker_path, play_url)?;

                        // ⑦ 清理同 key 其他文件与标记（保留新安装文件；计数不参与返回值）
                        let _ = remove_cache_files(&dir, &key16, Some(&final_name));

                        Ok(installed_len)
                    })
                    .unwrap_or_else(|| Err(LegadoError::Ffi("音频缓存下载已取消".into())))
            })
            .unwrap_or_else(|| Err(LegadoError::Ffi("音频缓存下载已取消".into())))
    })();

    let installed_size = match result {
        Ok(size) => size,
        Err(e) => {
            // ⑧ 失败清理：已安装文件 + 标记 + tmp（对齐 :190-197）
            let _ = fs::remove_file(&final_path);
            let _ = fs::remove_file(&marker_path);
            let _ = fs::remove_file(&staged_path);
            return Err(e);
        }
    };
    Ok(AudioCacheDownload {
        status: AudioCacheDownloadStatus::Installed,
        path: final_path.to_string_lossy().into_owned(),
        size_bytes: installed_size,
        extension,
    })
}

/// 暂存文件安装（对齐原版 `installStagedFile:232-264`）：优先同目录 rename，
/// 失败退整文件流式复制（块级取消检查）后复验 size；失败删除目标并上抛。
/// 返回安装后文件大小。
fn install_staged_file(
    staged_path: &Path,
    final_path: &Path,
    expected_size: Option<u64>,
) -> LegadoResult<u64> {
    match fs::rename(staged_path, final_path) {
        Ok(()) => {
            let len = fs::metadata(final_path)?.len();
            if let Err(e) = require_complete_size(len, expected_size) {
                let _ = fs::remove_file(final_path);
                return Err(e);
            }
            Ok(len)
        }
        Err(_) => {
            // SAF rename 失败（跨卷/被占用等）：整文件复制后复验
            let installed: LegadoResult<u64> = (|| {
                let mut input = fs::File::open(staged_path)?;
                let output = fs::File::create(final_path)?;
                let mut writer = io::BufWriter::new(output);
                io::copy(&mut input, &mut writer)?;
                writer.flush()?;
                let len = fs::metadata(final_path)?.len();
                require_complete_size(len, expected_size)?;
                Ok(len)
            })();
            match installed {
                Ok(len) => {
                    let _ = fs::remove_file(staged_path);
                    Ok(len)
                }
                Err(e) => {
                    let _ = fs::remove_file(final_path);
                    Err(e)
                }
            }
        }
    }
}

/// 写 `.complete` 标记并回读校验（对齐原版 `createCompleteMarker:266-281`）：
/// UTF-8 三行 `1\n{md5_16(playUrl)}\n{playUrl}`；写后 `decode == playUrl`
/// 否则删标记并 Err「音频缓存完成标记校验失败」
fn write_complete_marker(marker_path: &Path, play_url: &str) -> LegadoResult<()> {
    let write_result = (|| -> io::Result<()> {
        let mut file = fs::File::create(marker_path)?;
        file.write_all(encode_metadata(play_url).as_bytes())?;
        file.flush()
    })();
    if let Err(e) = write_result {
        let _ = fs::remove_file(marker_path);
        return Err(LegadoError::Io(e));
    }
    let read_back = fs::read_to_string(marker_path)
        .ok()
        .and_then(|s| decode_metadata(&s));
    if read_back.as_deref() != Some(play_url) {
        let _ = fs::remove_file(marker_path);
        return Err(LegadoError::Ffi("音频缓存完成标记校验失败".into()));
    }
    Ok(())
}

// ─── 测试 ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
#[path = "audio_cache_tests.rs"]
mod tests;
