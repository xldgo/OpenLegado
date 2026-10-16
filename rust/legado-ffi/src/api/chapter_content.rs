//! 固定存储/抓取能力的原文读取层；正文提交和媒体副内容共用任务门控。
use legado_core::cache_book::CachedChapter;
use legado_core::web_book::WebChapter;
use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository};
use legado_engine::{StorageContext, TaskHandle};
use std::sync::Arc;

#[derive(Clone)]
pub(crate) struct ChapterContent {
    pub storage: StorageContext,
    deps: super::web_book::CapturedFetcherFactory,
}
pub(crate) struct ChapterRequest<'a> {
    pub book_url: &'a str,
    pub chapter_url: &'a str,
    pub source_url: &'a str,
    pub chapter_index: i32,
    pub chapter_title: &'a str,
    pub chapter_variable: Option<&'a str>,
    pub known_chapter: bool,
}
pub(crate) struct RawChapter {
    pub content: String,
    pub title: String,
}

fn cancelled() -> LegadoError {
    LegadoError::Ffi("章节任务已取消".into())
}
fn publish<T>(task: Option<&TaskHandle>, write: impl FnOnce() -> T) -> LegadoResult<T> {
    match task {
        Some(task) => task.with_active(write).ok_or_else(cancelled),
        None => Ok(write()),
    }
}
impl ChapterContent {
    pub fn from_engine(engine: &legado_engine::EngineContext) -> Self {
        Self {
            storage: engine.storage().clone(),
            deps: super::web_book::deps_for_engine(engine),
        }
    }
    pub fn read(
        &self,
        request: ChapterRequest<'_>,
        task: Option<&TaskHandle>,
    ) -> LegadoResult<RawChapter> {
        if task.is_some_and(TaskHandle::is_cancelled) {
            return Err(cancelled());
        }
        let ChapterRequest {
            book_url,
            chapter_url,
            source_url,
            chapter_index,
            chapter_title,
            chapter_variable,
            known_chapter,
        } = request;
        // 1. 检查 DB 缓存
        // Task #16 P0：按 (book_url, chapter_url) 复合键查找，避免不同书籍共用
        // 相同 chapter_url 时命中他书缓存（正文张冠李戴）。
        let cached = self.storage.with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.get_by_book_and_chapter_url(book_url, chapter_url)
        })?;

        // [B-1] 空正文缓存行按 miss 处理（对齐上游 BookHelp.kt:271「内容为空
        // 直接返回」/ :557-559「空内容不入缓存」）：历史遗留的空行若按命中
        // 返回，该章节将永久空白、永不重抓
        let cached = cached.filter(|c| !c.content.trim().is_empty());

        if let Some(cached_chapter) = cached {
            // [P2-28b] 存量惰性自愈：缓存命中但该章 wordCount 为空（旧版本
            // 写入的缓存，早于回填链引入）时，按缓存正文长度补算回填**一次**
            // （回填成功后 wordCount 非空，后续命中不再写）。失败仅告警，
            // 不影响正文返回（对齐原版 writeText 的 best-effort 语义）
            let wc_missing = self
                .storage
                .with_database(|db| {
                    BookChapterRepository::new(db.connection())
                        .word_count_missing(book_url, chapter_url)
                })
                .unwrap_or(false);
            if wc_missing
                && let Err(e) = publish(task, || {
                    backfill_chapter_word_count(
                        &self.storage,
                        book_url,
                        chapter_url,
                        &cached_chapter.content,
                    )
                })?
            {
                log::warn!("章节字数自愈回填失败（已忽略，不影响阅读）: {e}");
            }
            return Ok(RawChapter {
                content: cached_chapter.content,
                title: cached_chapter.chapter_title,
            });
        }

        // 2. 缓存未命中，从网络获取
        let source = self
            .storage
            .with_database(|db| {
                let repo = BookSourceRepository::new(db.connection());
                repo.find_by_url(source_url)
            })?
            .ok_or_else(|| LegadoError::Database(format!("书源不存在: {source_url}")))?;

        // [T4 | RuleDataInterface] 内容链变量注入：book.variable ⊕ chapter.variable
        //（章节同名键优先，对齐原版 getVariable chapter → book 级联）。合并结果随
        // WebChapter 进入 get_content 的 AnalyzeUrl 变量表与解析上下文种子——
        // 此前内容链仅携带章节变量（R3），token/host 类书级变量在正文链全丢。
        let book_variable: Option<String> = self.storage.with_database(|db| {
            Ok(BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .and_then(|b| b.variable))
        })?;
        let merged_variable = legado_fetcher::web_book::merge_variables_json(
            book_variable.as_deref(),
            chapter_variable,
        );

        let web_chapter = WebChapter {
            index: chapter_index,
            title: chapter_title.to_string(),
            url: chapter_url.to_string(),
            is_vip: false,
            is_volume: false,
            variable: merged_variable,
            word_count: None,
        };

        if task.is_some_and(TaskHandle::is_cancelled) {
            return Err(cancelled());
        }
        let mut deps = (self.deps)()?.for_book(source_url, book_url);
        if let Some(task) = task
            && let Some(sink) = deps.media_sub_content.take()
        {
            let task = task.clone();
            deps.media_sub_content = Some(Arc::new(move |book, source, chapter, key, value| {
                task.with_active(|| sink(book, source, chapter, key, value));
            }));
        }
        let engine = legado_fetcher::web_book::build_engine(deps);
        let content =
            crate::runtime::block_on(async { engine.get_content(&source, &web_chapter).await })?;

        // 3. 抓取成功后写入 DB 缓存（对齐原版 BookContent.analyzeContent
        //    L207-209 `needSave → BookHelp.saveContent` 的「获取成功即写」时机）。
        //    写失败仅告警不传播——缓存写入失败不得导致阅读获取失败。
        // [B-12] 未知章节 URL（不在当前目录）不写缓存：上游按目录定位章节，
        // 回退 (0, "") 写出的 index=0 缓存行会污染目录云图标与后续读取
        if known_chapter {
            publish(task, || {
                save_chapter_cache(
                    &self.storage,
                    book_url,
                    chapter_index,
                    chapter_title,
                    chapter_url,
                    &content,
                )
            })?;
        }

        Ok(RawChapter {
            content,
            title: chapter_title.to_string(),
        })
    }
    pub fn download(&self, book: &str, index: i32, task: &TaskHandle) -> LegadoResult<()> {
        let chapter = self
            .storage
            .with_database(|db| {
                BookChapterRepository::new(db.connection()).find_by_book_url_and_index(book, index)
            })?
            .ok_or_else(|| LegadoError::Database(format!("章节 {index} 不存在")))?;
        if super::reader::is_local_book(book) {
            let path = std::path::Path::new(book);
            let resolved = if path.is_absolute() {
                path.to_path_buf()
            } else {
                self.storage
                    .path()
                    .and_then(std::path::Path::parent)
                    .map(|parent| parent.join(path))
                    .unwrap_or_else(|| path.to_path_buf())
            };
            let content = legado_book::LocalBook::get_chapter_content(
                &resolved.to_string_lossy(),
                &super::reader::chapter_to_local_info(&chapter),
            )?;
            publish(Some(task), || {
                super::cache_api::save_chapter_content_with_storage(
                    &self.storage,
                    book,
                    index,
                    &chapter.title,
                    &content,
                    &chapter.url,
                )
            })??;
        } else {
            let source = self
                .storage
                .with_database(|db| BookRepository::new(db.connection()).find_by_url(book))?
                .ok_or_else(|| LegadoError::Database(format!("书籍 {book} 不存在")))?
                .origin;
            if source.is_empty() {
                return Err(LegadoError::Database(format!(
                    "书籍 {book} 未配置书源（origin 为空）"
                )));
            }
            self.read(
                ChapterRequest {
                    book_url: book,
                    chapter_url: &chapter.url,
                    source_url: &source,
                    chapter_index: index,
                    chapter_title: &chapter.title,
                    chapter_variable: chapter.variable.as_deref(),
                    known_chapter: true,
                },
                Some(task),
            )?;
        }
        Ok(())
    }
}

fn backfill_chapter_word_count(
    storage: &StorageContext,
    book_url: &str,
    chapter_url: &str,
    content: &str,
) -> LegadoResult<u64> {
    // 原版字数 = Kotlin `String.length`（UTF-16 码元数）
    let word_count = super::reader::word_count_format(content.encode_utf16().count());
    if word_count.is_empty() {
        return Ok(0);
    }
    storage.with_database(|db| {
        BookChapterRepository::new(db.connection()).up_word_count(
            book_url,
            chapter_url,
            &word_count,
        )
    })
}

pub(crate) fn save_chapter_cache(
    storage: &StorageContext,
    book_url: &str,
    chapter_index: i32,
    chapter_title: &str,
    chapter_url: &str,
    content: &str,
) -> bool {
    // [B-1] 空内容不入缓存（对齐上游 BookHelp.kt:557-559）：杜绝空行入库后
    // 被读侧按命中返回、章节永久空白的缺陷链
    if content.trim().is_empty() {
        return false;
    }
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
    let result = storage.with_database(|db| {
        let repo = CacheBookRepository::new(db.connection());
        repo.insert(&cached_chapter)?;
        Ok(())
    });
    if let Err(e) = result {
        log::warn!("阅读缓存写入失败（已忽略，不影响阅读）: {e}");
        return false;
    }
    // 回填失败仅告警（对齐原版 writeText：回填属 best-effort，不得影响阅读）
    if let Err(e) = backfill_chapter_word_count(storage, book_url, chapter_url, content) {
        log::warn!("章节字数回填失败（已忽略，不影响阅读）: {e}");
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::models::{Book, BookChapter, BookSource};
    use legado_db::repository::Repository;
    use legado_engine::{CacheDownloads, EngineContext};
    use std::io::{Read, Write};
    use std::time::{Duration, Instant};

    fn seed(engine: &EngineContext, base: &str) -> String {
        let book = format!("{base}/book");
        let source: BookSource = serde_json::from_value(serde_json::json!({
            "bookSourceUrl":base,"bookSourceName":"下载隔离源","bookSourceType":4,
            "ruleContent":{"content":".content@text","subContent":".sub@text"}
        }))
        .unwrap();
        engine
            .storage()
            .with_database(|db| {
                BookSourceRepository::new(db.connection()).insert(&source)?;
                BookRepository::new(db.connection()).insert(&Book {
                    book_url: book.clone(),
                    origin: base.into(),
                    name: "下载书".into(),
                    ..Default::default()
                })?;
                BookChapterRepository::new(db.connection()).insert_batch(&[BookChapter {
                    book_url: book.clone(),
                    url: format!("{base}/chapter"),
                    title: "第一章".into(),
                    ..Default::default()
                }])
            })
            .unwrap();
        book
    }
    fn server(
        count: usize,
        ready: Option<std::sync::mpsc::Sender<()>>,
        gate: Option<std::sync::mpsc::Receiver<()>>,
    ) -> (String, std::thread::JoinHandle<()>) {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let job = std::thread::spawn(move || {
            for _ in 0..count {
                let deadline = Instant::now() + Duration::from_secs(10);
                let mut stream = loop {
                    match listener.accept() {
                        Ok((stream, _)) => break stream,
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            assert!(Instant::now() < deadline, "未收到下载请求");
                            std::thread::sleep(Duration::from_millis(2));
                        }
                        Err(e) => panic!("下载夹具连接失败: {e}"),
                    }
                };
                stream.set_nonblocking(false).unwrap();
                stream
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                let mut request = Vec::new();
                let mut byte = [0];
                while !request.ends_with(b"\r\n\r\n") {
                    assert_eq!(stream.read(&mut byte).unwrap(), 1);
                    request.push(byte[0]);
                    assert!(request.len() < 16384);
                }
                if let Some(ready) = &ready {
                    ready.send(()).unwrap();
                }
                if let Some(gate) = &gate {
                    gate.recv_timeout(Duration::from_secs(5)).unwrap();
                }
                let request = String::from_utf8(request).unwrap();
                let identity = if request.contains("identity=first") {
                    "first"
                } else if request.contains("identity=second") {
                    "second"
                } else {
                    "cancelled"
                };
                let body = format!(
                    "<html><div class='content'>https://cdn.example/{identity}.mp4</div><div class='sub'>{identity}{}</div></html>",
                    "x".repeat(11000)
                );
                write!(stream,"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
            }
        });
        (base, job)
    }
    fn wait(service: &Arc<CacheDownloads>, engine: &EngineContext, id: u64) {
        let deadline = Instant::now() + Duration::from_secs(10);
        loop {
            let progress = service.progress(id).unwrap();
            if progress.status != "running" && engine.tasks().active_count() == 0 {
                assert_eq!(progress.status, "completed");
                assert_eq!(progress.completed, 1);
                return;
            }
            assert!(Instant::now() < deadline, "真实下载未完成");
            std::thread::sleep(Duration::from_millis(2));
        }
    }

    #[test]
    fn real_downloads_share_no_cookie_body_metadata_or_large_media_file_between_instances() {
        let (base, server) = server(2, None, None);
        let first = EngineContext::in_memory().unwrap();
        let second = EngineContext::in_memory().unwrap();
        let mut directories = Vec::new();
        for (engine, identity) in [(&first, "first"), (&second, "second")] {
            let book = seed(engine, &base);
            engine
                .network()
                .set_cookie("127.0.0.1", &format!("identity={identity}"))
                .unwrap();
            let directory = engine
                .storage()
                .data_directory("explicit-rule-data")
                .unwrap();
            let previous =
                super::super::video_api::replace_test_rule_data_dir(Some(directory.clone()));
            let service = super::super::cache_download_api::downloads_for_engine(engine);
            super::super::video_api::replace_test_rule_data_dir(previous);
            let id = service.start(&book, 0, 0).unwrap();
            assert_eq!(id, 1);
            wait(&service, engine, id);
            let body = engine
                .storage()
                .with_database(|db| {
                    CacheBookRepository::new(db.connection())
                        .get_by_book_and_chapter_url(&book, &format!("{base}/chapter"))
                })
                .unwrap()
                .unwrap();
            assert!(body.content.contains(&format!("/{identity}.mp4")));
            assert!(!body.content.contains("xxxx"));
            let data = legado_db::rule_big_data::RuleBigDataManager::new(&directory)
                .get_chapter_variable(&book, &format!("{base}/chapter"), "danmaku")
                .unwrap()
                .unwrap();
            assert!(data.starts_with(identity));
            assert!(data.len() >= 11000);
            directories.push(directory);
            let checkpoint = engine
                .storage()
                .with_database(|db| {
                    legado_db::CacheRepository::new(db.connection()).get("cacheDownloadTask:1")
                })
                .unwrap()
                .unwrap();
            assert_eq!(
                serde_json::from_str::<serde_json::Value>(&checkpoint).unwrap()["status"],
                "completed"
            );
        }
        assert_ne!(directories[0], directories[1]);
        server.join().unwrap();
    }

    #[tokio::test]
    async fn cancelling_a_real_request_rejects_late_body_word_count_and_media_until_worker_exits() {
        let (started, ready) = std::sync::mpsc::channel();
        let (release, gate) = std::sync::mpsc::channel();
        let (base, server) = server(1, Some(started), Some(gate));
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        let book = seed(&engine, &base);
        let weak = Arc::downgrade(&engine);
        let storage = engine.storage().clone();
        let tasks = engine.tasks().clone();
        let service = super::super::cache_download_api::downloads_for_engine(&engine);
        let id = service.start(&book, 0, 0).unwrap();
        ready.recv_timeout(Duration::from_secs(5)).unwrap();
        assert!(service.cancel(id).unwrap());
        assert!(!tasks.shutdown(Duration::from_millis(20)).await);
        drop(engine);
        assert!(weak.upgrade().is_none());
        release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(5)).await);
        server.join().unwrap();
        storage
            .with_database(|db| {
                assert!(
                    CacheBookRepository::new(db.connection())
                        .get_by_book_and_chapter_url(&book, &format!("{base}/chapter"))?
                        .is_none()
                );
                let chapter = BookChapterRepository::new(db.connection())
                    .find_by_book_url_and_index(&book, 0)?
                    .unwrap();
                assert!(chapter.word_count.as_deref().unwrap_or("").is_empty());
                assert!(!chapter.variable.unwrap_or_default().contains("danmaku"));
                Ok(())
            })
            .unwrap();
        let directory = storage.data_directory("ruleData").unwrap();
        assert!(
            legado_db::rule_big_data::RuleBigDataManager::new(&directory)
                .get_chapter_variable(&book, &format!("{base}/chapter"), "danmaku")
                .unwrap()
                .is_none()
        );
        assert_eq!(service.progress(id).unwrap().status, "cancelled");
        assert_eq!(tasks.active_count(), 0);
    }

    #[test]
    fn cache_hit_never_initializes_network_and_keeps_the_cached_title() {
        let engine = EngineContext::in_memory().unwrap();
        let base = "http://cached-content.test";
        let book = seed(&engine, base);
        assert!(save_chapter_cache(
            engine.storage(),
            &book,
            0,
            "缓存标题",
            &format!("{base}/chapter"),
            "缓存原文"
        ));
        let access = ChapterContent {
            storage: engine.storage().clone(),
            deps: Arc::new(|| panic!("缓存命中不得创建网络客户端")),
        };
        let result = access
            .read(
                ChapterRequest {
                    book_url: &book,
                    chapter_url: &format!("{base}/chapter"),
                    source_url: base,
                    chapter_index: 0,
                    chapter_title: "目录新标题",
                    chapter_variable: None,
                    known_chapter: true,
                },
                None,
            )
            .unwrap();
        assert_eq!(result.content, "缓存原文");
        assert_eq!(result.title, "缓存标题");
    }
}
