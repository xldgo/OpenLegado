use super::*;
use crate::search_service::{SearchDepsFactory, SearchResources};
use crate::{EngineContext, SearchTasks};
use legado_core::web_book::{WebBookInfo, WebSearchResult};

pub(super) fn service(engine: &EngineContext, runtime: &tokio::runtime::Runtime) -> ReadingService {
    let js = engine.js_resources().clone();
    let web = engine.web_book_state().clone();
    let rate = engine.rate_limiter();
    let login = engine.source_login_cache().clone();
    let info = engine.source_info_map().clone();
    let prepare: SearchDepsFactory = Arc::new(move |client| {
        let login = login.clone();
        let info = info.clone();
        FetcherDeps::new(client)
            .with_js_resources(js.clone())
            .with_web_book_state(web.clone())
            .with_rate_limiter(rate.clone())
            .with_source_context(Arc::new(move |source| {
                legado_fetcher::source_setup::book_source_js_setup_script(
                    source,
                    &info.snapshot(&source.book_source_url),
                    login.get_login_header(&source.book_source_url).as_deref(),
                    login.get_login_info(&source.book_source_url).as_deref(),
                )
                .ok()
            }))
    });
    let factory = prepare.clone();
    let network = engine.network().clone();
    ReadingService::new(ReadingResources {
        storage: Some(engine.storage().clone()),
        deps: Some(Arc::new(move || Ok(factory(network.client()?)))),
        tasks: engine.tasks().clone(),
        runtime: runtime.handle().clone(),
        web_book: engine.web_book_state().clone(),
        js: engine.js_resources().clone(),
        search: SearchService::new(SearchResources {
            storage: Some(engine.storage().clone()),
            network: engine.network().clone(),
            searches: Arc::new(SearchTasks::new(engine.tasks().clone())),
            tasks: engine.tasks().clone(),
            runtime: runtime.handle().clone(),
            prepare,
        }),
        resolve_path: Arc::new(str::to_string),
    })
}

fn seed(engine: &EngineContext, source: &BookSource) {
    engine
        .storage()
        .with_database(|db| {
            BookSourceRepository::new(db.connection()).insert(source)?;
            BookRepository::new(db.connection()).insert(&Book {
                book_url: "https://same.test/book".into(),
                origin: source.book_source_url.clone(),
                name: "测试书".into(),
                toc_url: "https://same.test/toc".into(),
                dur_chapter_index: 42,
                ..Default::default()
            })?;
            BookChapterRepository::new(db.connection()).insert_batch(&[BookChapter {
                book_url: "https://same.test/book".into(),
                url: "https://same.test/old".into(),
                title: "第一章".into(),
                ..Default::default()
            }])?;
            Ok(())
        })
        .unwrap();
}

#[test]
fn processing_configuration_and_raw_cache_are_owned_by_each_reading_service() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let source = BookSource {
        book_source_url: "https://same.test".into(),
        enabled: true,
        ..Default::default()
    };
    seed(&first, &source);
    seed(&second, &source);
    let a = service(&first, &runtime);
    let b = service(&second, &runtime);
    let book = "https://same.test/book";
    let raw = "第一章\n測試正文";
    for (engine, marker) in [(&first, "甲"), (&second, "乙")] {
        engine
            .storage()
            .with_database(|db| {
                ReplaceRuleRepository::new(db.connection()).insert(&ReplaceRule {
                    pattern: "正文".into(),
                    replacement: marker.into(),
                    is_regex: false,
                    ..Default::default()
                })?;
                Ok(())
            })
            .unwrap();
        assert!(save_chapter_cache(
            engine.storage(),
            book,
            0,
            "第一章",
            "https://same.test/old",
            raw
        ));
    }
    a.set_chinese_convert_type(1);
    b.set_chinese_convert_type(0);
    a.toggle_same_title_removed(book, 0, false).unwrap();
    assert!(!a.get_same_title_removed(book, 0));
    assert!(b.get_same_title_removed(book, 0));
    assert_eq!(a.get_chinese_convert_type(), 1);
    assert_eq!(b.get_chinese_convert_type(), 0);
    let display_a = a.apply_content_processing_chapter(book, raw, "第一章", 0);
    let display_b = b.apply_content_processing_chapter(book, raw, "第一章", 0);
    assert!(display_a.contains("第一章") && display_a.contains("测试甲"));
    assert!(!display_b.contains("第一章") && display_b.contains("測試乙"));
    assert!(
        a.apply_content_processing_raw(book, raw, "第一章", Some(0))
            .contains("測試")
    );
    for base in [&a, &b] {
        let content = base.chapter_content().unwrap();
        let cached = content
            .read(
                ChapterRequest {
                    book_url: book,
                    chapter_url: "https://same.test/old",
                    source_url: &source.book_source_url,
                    chapter_index: 0,
                    chapter_title: "第一章",
                    chapter_variable: None,
                    known_chapter: true,
                },
                None,
            )
            .unwrap();
        assert_eq!(cached.content, raw);
    }
    drop(first);
    let task = a.resources.tasks.begin();
    assert!(task.is_err());
    assert!(b.resources.tasks.begin().is_ok());
}

struct TocFetcher {
    storage: StorageContext,
    title: Option<&'static str>,
}
impl BookSourceFetcher for TocFetcher {
    async fn search(&self, _: &BookSource, _: &str, _: i32) -> LegadoResult<Vec<WebSearchResult>> {
        unreachable!()
    }
    async fn get_book_info(&self, _: &BookSource, _: &str) -> LegadoResult<WebBookInfo> {
        unreachable!()
    }
    async fn get_chapters(&self, _: &BookSource, _: &str) -> LegadoResult<Vec<WebChapter>> {
        self.storage.with_database(|db| {
            db.connection()
                .execute(
                    "UPDATE books SET durChapterIndex=99 WHERE bookUrl=?1",
                    ["https://same.test/book"],
                )
                .map_err(|e| LegadoError::Database(e.to_string()))?;
            Ok(())
        })?;
        Ok(self
            .title
            .map(|title| WebChapter {
                index: 0,
                title: title.into(),
                url: "https://same.test/new".into(),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            })
            .into_iter()
            .collect())
    }
    async fn get_content(&self, _: &BookSource, _: &WebChapter) -> LegadoResult<String> {
        unreachable!()
    }
}
#[test]
fn toc_refresh_preserves_progress_and_clears_only_its_own_stale_cache() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let source = BookSource {
        book_source_url: "https://same.test".into(),
        enabled: true,
        ..Default::default()
    };
    seed(&first, &source);
    seed(&second, &source);
    let a = service(&first, &runtime);
    let b = service(&second, &runtime);
    let book = "https://same.test/book";
    for engine in [&first, &second] {
        assert!(save_chapter_cache(
            engine.storage(),
            book,
            0,
            "第一章",
            "https://same.test/old",
            "原文"
        ));
    }
    let fetcher = WebBookEngine::new(TocFetcher {
        storage: first.storage().clone(),
        title: Some("新目录"),
    });
    let chapters = a
        .refresh_toc_with_fetcher(book, &source.book_source_url, &fetcher)
        .unwrap();
    assert_eq!(chapters.chapters[0].title, "新目录");
    assert_eq!(b.get_chapters(book).unwrap().chapters[0].title, "第一章");
    for (engine, progress, has_cache) in [(&first, 99, false), (&second, 42, true)] {
        engine
            .storage()
            .with_database(|db| {
                let book = BookRepository::new(db.connection())
                    .find_by_url(book)?
                    .unwrap();
                assert_eq!(book.dur_chapter_index, progress);
                let cached = legado_db::CacheBookRepository::new(db.connection())
                    .get_by_book_and_chapter_url(
                        "https://same.test/book",
                        "https://same.test/old",
                    )?;
                assert_eq!(cached.is_some(), has_cache);
                Ok(())
            })
            .unwrap();
    }
    let empty = WebBookEngine::new(TocFetcher {
        storage: first.storage().clone(),
        title: None,
    });
    assert_eq!(
        a.refresh_toc_with_fetcher(book, &source.book_source_url, &empty)
            .unwrap()
            .chapters[0]
            .title,
        "新目录"
    );
}

#[cfg(feature = "quickjs")]
#[test]
fn pre_update_hooks_use_instance_search_and_details_without_changing_the_book_key() {
    use legado_core::models::rule::{BookInfoRule, SearchRule, TocRule};
    use std::{
        io::{Read, Write},
        net::TcpListener,
        time::{Duration, Instant},
    };
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let base = format!("http://{}", listener.local_addr().unwrap());
    let server = std::thread::spawn(move || {
        listener.set_nonblocking(true).unwrap();
        for _ in 0..4 {
            let deadline = Instant::now() + Duration::from_secs(15);
            let mut stream = loop {
                match listener.accept() {
                    Ok((stream, _)) => break stream,
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "未收到钩子请求");
                        std::thread::sleep(Duration::from_millis(2));
                    }
                    Err(e) => panic!("测试连接失败: {e}"),
                }
            };
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut data = Vec::new();
            let mut byte = [0];
            while !data.ends_with(b"\r\n\r\n") {
                assert_eq!(stream.read(&mut byte).unwrap(), 1);
                data.push(byte[0]);
                assert!(data.len() < 16384);
            }
            let request = String::from_utf8(data).unwrap().to_lowercase();
            let identity = if request.contains("x-identity: first") {
                "first"
            } else if request.contains("x-identity: second") {
                "second"
            } else {
                panic!("未携带所属源请求头: {request}")
            };
            let body = format!(
                r#"<div class="book"><a class="name" href="/new/book">{identity}</a><span class="author">作者</span></div><a class="toc" href="/new/toc">目录</a>"#
            );
            write!(stream,"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
        }
    });
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    for (engine, identity) in [(&first, "first"), (&second, "second")] {
        let source = BookSource {
            book_source_url: base.clone(),
            enabled: true,
            header: Some(serde_json::json!({"X-Identity":identity}).to_string()),
            search_url: Some(format!("{base}/search?key=searchKey")),
            rule_search: Some(SearchRule {
                book_list: Some(".book".into()),
                name: Some(".name".into()),
                author: Some(".author".into()),
                book_url: Some(".name@href".into()),
                ..Default::default()
            }),
            rule_book_info: Some(BookInfoRule {
                name: Some(".name".into()),
                author: Some(".author".into()),
                toc_url: Some(".toc@href".into()),
                ..Default::default()
            }),
            rule_toc: Some(TocRule {
                pre_update_js: Some("java.reGetBook();".into()),
                ..Default::default()
            }),
            ..Default::default()
        };
        seed(engine, &source);
        let mut book = Book {
            book_url: "https://same.test/book".into(),
            name: identity.into(),
            author: "作者".into(),
            dur_chapter_index: 42,
            ..Default::default()
        };
        let reading = service(engine, &runtime);
        reading.run_pre_update_js(&source, &mut book).unwrap();
        assert_eq!(book.book_url, "https://same.test/book");
        assert_eq!(book.origin_book_url, format!("{base}/new/book"));
        assert_eq!(book.toc_url, format!("{base}/new/toc"));
        assert_eq!(book.name, identity);
        assert_eq!(book.dur_chapter_index, 42);
    }
    server.join().unwrap();
}
