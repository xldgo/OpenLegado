//! 音频书章节取址：按原顺序处理歌词、缓存与书源请求，不修改正文URL。
use crate::reading_service::ReadingFetcherFactory;
use crate::{StorageContext, TaskGroup};
use legado_core::{
    LegadoError, LegadoResult, cache_book::CachedChapter, models::BookChapter, web_book::WebChapter,
};
use legado_db::{
    BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository,
    rule_big_data::RuleBigDataManager,
};
use serde::Serialize;
/// 音频章节媒体取址结果（契约 §2.26 `getAudioChapterMedia`）
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioChapterMedia {
    pub chapter_index: i32,
    pub title: String,
    /// 可播媒体地址（WebBook.getContent 正文 trim）
    pub media_url: String,
    /// 章节页 URL（兼容旧 Dart fallback 字段名 `url`）
    #[serde(rename = "url")]
    pub chapter_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resource_url: Option<String>,
    pub is_volume: bool,
    pub from_cache: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lyric: Option<String>,
    pub source_url: String,
}

/// 解析章节歌词（chapter.variable JSON 中的 lyric 字段）
pub fn lyric_from_variable(variable: &Option<String>) -> Option<String> {
    let raw = variable.as_ref()?.trim();
    if raw.is_empty() {
        return None;
    }
    let v: serde_json::Value = serde_json::from_str(raw).ok()?;
    v.get("lyric")
        .and_then(|x| x.as_str())
        .map(|s| s.to_string())
        .filter(|s| !s.is_empty())
}
pub struct AudioBookService {
    pub storage: StorageContext,
    pub factory: ReadingFetcherFactory,
    pub runtime: tokio::runtime::Handle,
    pub tasks: TaskGroup,
    pub rule_data_directory: std::path::PathBuf,
}
impl AudioBookService {
    /// 解析章节歌词：variable 直存优先，未命中回退大数据文件（P2-2 收口）
    ///
    /// 对齐原版 `RuleDataInterface.getVariable`（`variableMap[key] ?: getBigVariable(key)`，
    /// `AudioPlay.kt:408` `chapter.getVariable("lyric")`）：歌词 ≥10000 字符时
    /// 写入侧（`put_media_sub_content`）与弹幕同链落 `RuleBigDataHelp` 文件，
    /// 读取侧必须补 File 回退，否则长歌词读不回。文件读失败降级无歌词（不抛）。
    fn lyric_for_chapter(&self, book_url: &str, chapter: &BookChapter) -> Option<String> {
        if let Some(inline) = lyric_from_variable(&chapter.variable) {
            return Some(inline);
        }
        let manager = RuleBigDataManager::new(&self.rule_data_directory);
        match manager.get_chapter_variable(book_url, &chapter.url, "lyric") {
            Ok(Some(content)) if !content.is_empty() => Some(content),
            Ok(_) => None,
            Err(e) => {
                log::warn!("[audio_lyric] 大数据歌词文件读取失败（降级无歌词）: {e}");
                None
            }
        }
    }

    /// 音频章节取址（对齐 `AudioPlay.loadRemotePlayUrl` + `contentLoadFinish`）
    ///
    /// 1. 查章节；卷章返回 `isVolume=true`、空 `mediaUrl`
    /// 2. DB `cached_chapters` 命中 → 缓存正文即播放 URL（fromCache=true）
    /// 3. 否则按 `book.origin` 调 WebBook.getContent（无正文规则回退章 URL）
    /// 4. 成功后写入缓存；**不做**文本替换/净化（URL 会被污染）
    pub fn get_audio_chapter_media(
        &self,
        book_url: &str,
        chapter_index: i32,
    ) -> LegadoResult<AudioChapterMedia> {
        let chapter = self
            .storage
            .with_database(|db| {
                let repo = BookChapterRepository::new(db.connection());
                repo.find_by_book_url_and_index(book_url, chapter_index)
            })?
            .ok_or_else(|| LegadoError::Database(format!("章节 {chapter_index} 不存在")))?;

        let lyric = self.lyric_for_chapter(book_url, &chapter);
        let resource_url = chapter.resource_url.clone();

        if chapter.is_volume {
            return Ok(AudioChapterMedia {
                chapter_index: chapter.index,
                title: chapter.title.clone(),
                media_url: String::new(),
                chapter_url: chapter.url.clone(),
                resource_url,
                is_volume: true,
                from_cache: false,
                lyric,
                source_url: String::new(),
            });
        }

        let book = self
            .storage
            .with_database(|db| {
                let repo = BookRepository::new(db.connection());
                repo.find_by_url(book_url)
            })?
            .ok_or_else(|| LegadoError::Database(format!("书籍 {book_url} 不存在")))?;

        let source_url = book.origin.clone();

        // 1) 内容缓存命中（阅读/听书 getContent 共享 cached_chapters）
        let cached = self.storage.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.get_by_book_and_chapter_url(book_url, &chapter.url)
        })?;
        if let Some(cached_chapter) = cached {
            let media_url = cached_chapter.content.trim().to_string();
            if !media_url.is_empty() {
                return Ok(AudioChapterMedia {
                    chapter_index: chapter.index,
                    title: chapter.title.clone(),
                    media_url,
                    chapter_url: chapter.url.clone(),
                    resource_url,
                    is_volume: false,
                    from_cache: true,
                    lyric,
                    source_url,
                });
            }
        }

        // 2) 无书源：回退 resourceUrl / 章节 URL（本地或异常数据）
        if source_url.is_empty() {
            let media_url = resource_url
                .as_ref()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| chapter.url.trim().to_string());
            return Ok(AudioChapterMedia {
                chapter_index: chapter.index,
                title: chapter.title.clone(),
                media_url,
                chapter_url: chapter.url.clone(),
                resource_url,
                is_volume: false,
                from_cache: false,
                lyric,
                source_url,
            });
        }

        let source = self
            .storage
            .with_database(|db| {
                let repo = BookSourceRepository::new(db.connection());
                repo.find_by_url(&source_url)
            })?
            .ok_or_else(|| LegadoError::Database(format!("书源不存在: {source_url}")))?;

        // [T4 | RuleDataInterface] 听书链同步内容链变量合并：book.variable ⊕
        // chapter.variable（章节优先），保证 token/host 类书级变量可达正文请求
        let book_variable: Option<String> = self.storage.with_database(|db| {
            Ok(BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .and_then(|b| b.variable))
        })?;
        let merged_variable = legado_fetcher::web_book::merge_variables_json(
            book_variable.as_deref(),
            chapter.variable.as_deref(),
        );

        let web_chapter = WebChapter {
            index: chapter.index,
            title: chapter.title.clone(),
            url: chapter.url.clone(),
            is_vip: chapter.is_vip,
            is_volume: chapter.is_volume,
            variable: merged_variable,
            word_count: None,
        };

        let task = self
            .tasks
            .begin()
            .map_err(|e| LegadoError::Ffi(e.to_string()))?;
        let mut deps = (self.factory)()?;
        if let Some(sink) = deps.media_sub_content.take() {
            let permit = task.clone();
            deps.media_sub_content = Some(std::sync::Arc::new(
                move |book, source, chapter, key, value| {
                    permit.with_active(|| sink(book, source, chapter, key, value));
                },
            ));
        }
        let engine = legado_fetcher::web_book::build_engine(
            deps.with_execution_lease(std::sync::Arc::new(task)),
        );
        let content = self
            .runtime
            .block_on(async { engine.get_content(&source, &web_chapter).await })?;
        let media_url = content.trim().to_string();
        if media_url.is_empty() {
            return Err(LegadoError::ContentEmpty("未获取到资源链接".into()));
        }

        // 写入缓存（对齐 needSave=true；失败仅告警）
        self.save_audio_content_cache(
            book_url,
            chapter.index,
            &chapter.title,
            &chapter.url,
            &media_url,
        );

        Ok(AudioChapterMedia {
            chapter_index: chapter.index,
            title: chapter.title,
            media_url,
            chapter_url: chapter.url,
            resource_url,
            is_volume: false,
            from_cache: false,
            lyric,
            source_url,
        })
    }

    fn save_audio_content_cache(
        &self,
        book_url: &str,
        chapter_index: i32,
        chapter_title: &str,
        chapter_url: &str,
        content: &str,
    ) {
        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);
        let cached_chapter = CachedChapter {
            id: 0,
            book_url: book_url.to_string(),
            chapter_index,
            chapter_title: chapter_title.to_string(),
            chapter_url: chapter_url.to_string(),
            content: content.to_string(),
            cached_at: now_ms,
            size_bytes: content.len() as i64,
        };
        if let Err(e) = self.storage.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.insert(&cached_chapter)?;
            Ok(())
        }) {
            log::warn!("音频章内容缓存写入失败（已忽略）: {e}");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{EngineContext, test_http_fixture::Fixture};
    use legado_core::models::{Book, BookSource, rule::ContentRule};
    use legado_db::repository::Repository;
    use std::sync::Arc;

    fn service(
        engine: &EngineContext,
        runtime: &tokio::runtime::Runtime,
        base: &str,
        tag: &str,
    ) -> AudioBookService {
        engine
            .storage()
            .with_database(|db| {
                BookRepository::new(db.connection()).insert(&Book {
                    book_url: "same-audio-book".into(),
                    name: "音频书".into(),
                    origin: base.into(),
                    ..Default::default()
                })?;
                BookChapterRepository::new(db.connection()).insert(&BookChapter {
                    book_url: "same-audio-book".into(),
                    url: format!("{base}/chapter"),
                    title: "第一集".into(),
                    index: 0,
                    variable: Some(format!(r#"{{"lyric":"{tag}"}}"#)),
                    ..Default::default()
                })?;
                BookSourceRepository::new(db.connection()).insert(&BookSource {
                    book_source_url: base.into(),
                    book_source_name: "取址测试".into(),
                    rule_content: Some(ContentRule {
                        content: Some("body@text".into()),
                        ..Default::default()
                    }),
                    ..Default::default()
                })?;
                Ok(())
            })
            .unwrap();
        engine
            .source_login_cache()
            .put_login_header(base, &format!(r#"{{"X-Instance":"{tag}"}}"#));
        let network = engine.network().clone();
        let js = engine.js_resources().clone();
        let rates = engine.rate_limiter();
        let login = engine.source_login_cache().clone();
        let web = engine.web_book_state().clone();
        AudioBookService {
            storage: engine.storage().clone(),
            runtime: runtime.handle().clone(),
            tasks: engine.tasks().clone(),
            rule_data_directory: engine.storage().data_directory("ruleData").unwrap(),
            factory: Arc::new(move || {
                let login = login.clone();
                Ok(legado_fetcher::deps::FetcherDeps::new(network.client()?)
                    .with_js_resources(js.clone())
                    .with_web_book_state(web.clone())
                    .with_rate_limiter(rates.clone())
                    .with_login_header(Arc::new(move |source| login.get_login_header(source))))
            }),
        }
    }

    #[test]
    fn chapter_media_uses_captured_instance_headers_lyrics_and_content_cache() {
        let mut fixture = Fixture::new(2, false, |_| {
            "<body>https://media.example/audio.mp3</body>".into()
        });
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap();
        let first = EngineContext::in_memory().unwrap();
        let second = EngineContext::in_memory().unwrap();
        let one = service(&first, &runtime, &fixture.url, "first");
        let two = service(&second, &runtime, &fixture.url, "second");
        for (service, tag) in [(&one, "first"), (&two, "second")] {
            let media = service
                .get_audio_chapter_media("same-audio-book", 0)
                .unwrap();
            assert_eq!(media.media_url, "https://media.example/audio.mp3");
            assert_eq!(media.lyric.as_deref(), Some(tag));
            assert!(!media.from_cache);
            let cached = service
                .get_audio_chapter_media("same-audio-book", 0)
                .unwrap();
            assert!(cached.from_cache);
            assert_eq!(cached.media_url, media.media_url);
        }
        let requests =
            runtime.block_on(async { [fixture.request().await, fixture.request().await] });
        assert!(requests[0].to_lowercase().contains("x-instance: first"));
        assert!(requests[1].to_lowercase().contains("x-instance: second"));
        fixture.worker.join().unwrap();
        assert_eq!(first.tasks().active_count(), 0);
        assert_eq!(second.tasks().active_count(), 0);
    }
}
