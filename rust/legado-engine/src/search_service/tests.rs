use super::*;
use crate::EngineContext;
use legado_core::models::rule::SearchRule;
use legado_db::repository::Repository;
use std::{
    io::{Read, Write},
    net::TcpListener,
};

#[test]
fn relative_search_urls_keep_the_host_and_inline_cover_data() {
    assert_eq!(
        resolve_url("cover.jpg", "https://example.com"),
        "https://example.com/cover.jpg"
    );
    assert_eq!(
        resolve_url("data:image/png;base64,AQI=", "https://example.com/search/"),
        "data:image/png;base64,AQI="
    );
    assert_eq!(resolve_url("", "https://example.com/search/"), "");
}

fn service(
    engine: &EngineContext,
    runtime: &tokio::runtime::Runtime,
    url: &str,
    marker: &str,
    read: bool,
) -> SearchService {
    engine
        .storage()
        .with_database(|db| {
            legado_db::BookSourceRepository::new(db.connection()).insert(&BookSource {
                book_source_url: url.into(),
                book_source_name: marker.into(),
                enabled: true,
                search_url: Some(format!("{url}/search?key=searchKey&page={{{{page}}}}")),
                rule_search: Some(SearchRule {
                    book_list: Some(".book".into()),
                    name: Some(".name".into()),
                    author: Some(".author".into()),
                    book_url: Some(".name@href".into()),
                    ..Default::default()
                }),
                ..Default::default()
            })?;
            legado_db::CacheRepository::new(db.connection()).put(
                "config:precisionSearch",
                if read { "true" } else { "false" },
                0,
            )?;
            if read {
                legado_db::ReadRecordRepository::new(db.connection()).insert_with_author(
                    "测试书",
                    "作者",
                    1,
                )?;
            }
            Ok(())
        })
        .unwrap();
    let js = engine.js_resources().clone();
    let web = engine.web_book_state().clone();
    let rate = engine.rate_limiter();
    SearchService::new(SearchResources {
        storage: Some(engine.storage().clone()),
        network: engine.network().clone(),
        searches: Arc::new(SearchTasks::new(engine.tasks().clone())),
        tasks: engine.tasks().clone(),
        runtime: runtime.handle().clone(),
        prepare: Arc::new(move |client| {
            FetcherDeps::new(client)
                .with_js_resources(js.clone())
                .with_web_book_state(web.clone())
                .with_rate_limiter(rate.clone())
        }),
    })
}

#[test]
fn independent_services_search_stream_and_persist_only_to_their_own_database() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    let server = std::thread::spawn(move || {
        listener.set_nonblocking(true).unwrap();
        for _ in 0..8 {
            let deadline = std::time::Instant::now() + Duration::from_secs(15);
            let mut stream = loop {
                match listener.accept() {
                    Ok((stream, _)) => break stream,
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(std::time::Instant::now() < deadline, "没有收到预期搜索请求");
                        std::thread::sleep(Duration::from_millis(2));
                    }
                    Err(e) => panic!("测试连接失败: {e}"),
                }
            };
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut head = Vec::new();
            let mut byte = [0];
            while !head.ends_with(b"\r\n\r\n") {
                assert_eq!(stream.read(&mut byte).unwrap(), 1);
                head.push(byte[0]);
                assert!(head.len() < 16384);
            }
            let body = r#"<div class="book"><a class="name" href="/book">测试书</a><span class="author">作者</span></div>"#;
            write!(stream,"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
        }
    });
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = service(&first, &runtime, &url, "甲", true);
    let b = service(&second, &runtime, &url, "乙", false);
    for (base, marker, read) in [(&a, "甲", true), (&b, "乙", false)] {
        assert_eq!(base.precision(), read);
        let results = base.search_books_selected("测试书", &[]).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].source_name, marker);
        assert_eq!(results[0].has_read_record, read);
        let results = base.multi_source_search_selected("测试书", &[]).unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].has_read_record, read);
        let mut batches = Vec::new();
        runtime.block_on(
            base.run_multi_stream_selected("测试书".into(), vec![], 2, |batch| {
                batches.push(batch);
                Ok(())
            }),
        );
        assert_eq!(batches.len(), 1);
        assert!(batches[0].is_last && batches[0].has_more);
        assert_eq!(batches[0].books[0].has_read_record, read);
        // 精搜是独立任务，不能替换当前普通搜索会话。
        let current = base.begin_search().unwrap();
        assert_eq!(
            base.precise_search_selected("测试书", "作者", &[])
                .unwrap()
                .name,
            "测试书"
        );
        assert!(current.is_current());
        assert!(!current.is_cancelled());
        current.finish();
    }
    for (engine, marker) in [(&first, "甲"), (&second, "乙")] {
        let saved = engine
            .storage()
            .with_database(|db| {
                legado_db::SearchBookRepository::new(db.connection())
                    .find_by_book_url(&format!("{url}/book"))
            })
            .unwrap()
            .unwrap();
        assert_eq!(saved.origin_name, marker);
    }
    server.join().unwrap();
}

#[test]
fn replacement_cancellation_and_engine_shutdown_do_not_cross_service_boundaries() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = service(&first, &runtime, "https://same.test", "甲", false);
    let b = service(&second, &runtime, "https://same.test", "乙", false);
    let old = a.begin_search().unwrap();
    let other = b.begin_search().unwrap();
    let next = a.begin_search().unwrap();
    assert!(old.is_cancelled());
    old.finish();
    assert!(next.is_current());
    a.pause_search();
    assert!(next.paused.load(std::sync::atomic::Ordering::Acquire));
    assert!(!other.paused.load(std::sync::atomic::Ordering::Acquire));
    a.resume_search();
    assert!(!next.paused.load(std::sync::atomic::Ordering::Acquire));
    a.cancel_search();
    assert!(next.is_cancelled());
    assert!(!other.is_cancelled());
    let fresh = a.begin_search().unwrap();
    drop(first);
    assert!(fresh.is_cancelled());
    assert!(!other.is_cancelled());
}
