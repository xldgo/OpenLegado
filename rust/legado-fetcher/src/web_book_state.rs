//! 抓取缓存的实例资源；所有容量、TTL 和合并策略沿用现有抓取链。

use std::collections::HashMap;
use std::sync::{Mutex, atomic::AtomicU64};
use std::time::{Duration, Instant};

/// 同一引擎的 FetcherDeps 共享此资源；独立实例使用独立的缓存与刷新代数。
#[derive(Default)]
pub struct WebBookState {
    pub(crate) page_body: Mutex<PageBodyCache>,
    pub(crate) book_meta: Mutex<HashMap<(String, String), BookMeta>>,
    pub(crate) chapter_book: Mutex<HashMap<(String, String), String>>,
    pub(crate) next_chapter: Mutex<HashMap<(String, String), String>>,
    pub(crate) toc_epoch: AtomicU64,
}

/// 详情/目录短时 HTML 缓存（对齐原版 Book.infoHtml / Book.tocHtml 复用语义）
///
/// Flutter 信息页串行 `webbookInfo` → `webbookChapters` 时，原版在 analyzeBookInfo
/// 后把 body 写入 tocHtml，目录阶段不再二次 HTTP。无状态 FFI 无法携带 Book，
/// 故用 URL 键短 TTL 缓存承接同一次进入详情的重复拉页。
const PAGE_BODY_CACHE_TTL: Duration = Duration::from_secs(45);
const PAGE_BODY_CACHE_MAX: usize = 32;

#[derive(Default)]
pub(crate) struct PageBodyCache {
    entries: HashMap<String, (Instant, String)>,
}

impl PageBodyCache {
    pub(crate) fn get(&mut self, url: &str) -> Option<String> {
        let now = Instant::now();
        self.entries
            .retain(|_, (t, _)| now.duration_since(*t) < PAGE_BODY_CACHE_TTL);
        self.entries.get(url).map(|(_, b)| b.clone())
    }

    pub(crate) fn put(&mut self, url: &str, body: String) {
        let now = Instant::now();
        self.entries
            .retain(|_, (t, _)| now.duration_since(*t) < PAGE_BODY_CACHE_TTL);
        if self.entries.len() >= PAGE_BODY_CACHE_MAX {
            // 简单淘汰：丢掉最旧一条
            if let Some(oldest) = self
                .entries
                .iter()
                .min_by_key(|(_, (t, _))| *t)
                .map(|(k, _)| k.clone())
            {
                self.entries.remove(&oldest);
            }
        }
        self.entries.insert(url.to_string(), (now, body));
    }
}

/// book 绑定扩面元信息（P2-9 ②）
///
/// 对齐上游 `Book`/`BaseBook` 字段面（Book.kt:122/146-148/206-212、
/// BaseBook.kt:19-31）：无状态 FFI 无法跨调用携带 Book 对象，用来源＋URL 键
/// 当前引擎的缓存承接详情/目录阶段 → 正文阶段的元信息流转：
/// - `webbook_info` 记录详情信息（name/author/tocUrl/lastChapter/variable）
/// - `webbook_chapters` 记录目录（章节 URL → book URL 映射 + lastChapter）
/// - `webbook_content` 按章节 URL 反查 meta，构造带字段的 `book` 绑定
#[derive(Clone, Debug, Default)]
pub(crate) struct BookMeta {
    pub(crate) name: String,
    pub(crate) author: String,
    pub(crate) book_url: String,
    pub(crate) toc_url: String,
    pub(crate) last_chapter: String,
    /// 规则变量 JSON（Map<String,Any> 序列化字符串，如 `{"custom":"x"}`；
    /// 对齐 WebBookInfo.variable / Book.variable，RuleDataInterface.kt:7-34）
    pub(crate) variable: Option<String>,
}

/// book 元信息缓存容量（来源＋bookUrl 键；仅**新键**插入溢出时整体清空——降级
/// LRU 为全量淘汰，与 PageBodyCache 的简单淘汰策略一致）
pub(crate) const BOOK_META_CACHE_MAX: usize = 512;
/// (书源 URL, 章节 URL) 复合键 → book URL 映射缓存容量（仅**新键**插入
/// 溢出时整体清空）
pub(crate) const CHAPTER_BOOK_CACHE_MAX: usize = 8192;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn page_cache_keeps_existing_capacity_and_evicts_oldest_entry() {
        let mut cache = PageBodyCache::default();
        cache.entries.insert(
            "oldest".into(),
            (Instant::now() - Duration::from_secs(1), "old".into()),
        );
        for i in 0..PAGE_BODY_CACHE_MAX {
            cache.put(&format!("url-{i}"), format!("body-{i}"));
        }
        assert_eq!(cache.entries.len(), PAGE_BODY_CACHE_MAX);
        assert!(cache.get("oldest").is_none());
        assert_eq!(cache.get("url-31").as_deref(), Some("body-31"));
    }

    #[test]
    fn expired_page_body_is_not_returned_or_retained_on_write() {
        let mut cache = PageBodyCache::default();
        cache.entries.insert(
            "expired".into(),
            (Instant::now() - PAGE_BODY_CACHE_TTL, "old".into()),
        );
        assert!(cache.get("expired").is_none());
        cache.entries.insert(
            "expired-again".into(),
            (Instant::now() - PAGE_BODY_CACHE_TTL, "old".into()),
        );
        cache.put("new", "fresh".into());
        assert_eq!(cache.entries.len(), 1);
        assert_eq!(cache.get("new").as_deref(), Some("fresh"));
    }
}
