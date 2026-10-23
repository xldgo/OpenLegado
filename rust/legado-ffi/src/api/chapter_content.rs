//! 原文读取宿主装配；执行与缓存写入位于Engine。
#[cfg(test)]
use legado_db::{BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository};
use legado_engine::reading_service::ChapterContent;
#[cfg(test)]
use legado_engine::reading_service::ChapterRequest;
#[cfg(test)]
pub(crate) use legado_engine::reading_service::save_chapter_cache;
pub(crate) fn from_engine(engine: &legado_engine::EngineContext) -> ChapterContent {
    ChapterContent::new(
        engine.storage().clone(),
        super::web_book::deps_for_engine(engine),
        crate::runtime::get_runtime().handle().clone(),
    )
}
#[cfg(test)]
use std::sync::Arc;
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
                let response = write!(
                    stream,
                    "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                if let Err(error) = response {
                    // 取消场景客户端可已断开；非取消或其他写入错误仍须失败。
                    assert!(
                        gate.is_some()
                            && matches!(
                                error.kind(),
                                std::io::ErrorKind::BrokenPipe
                                    | std::io::ErrorKind::ConnectionAborted
                                    | std::io::ErrorKind::ConnectionReset
                                    | std::io::ErrorKind::NotConnected
                            ),
                        "HTTP夹具响应失败: {error}"
                    );
                }
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
    async fn cancelling_a_real_request_finishes_before_response_and_rejects_late_writes() {
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
        // 取消能结束在途HTTP；不能要求工作线程等到服务端放行才退出。
        assert!(tasks.shutdown(Duration::from_secs(5)).await);
        drop(engine);
        assert!(weak.upgrade().is_none());
        release.send(()).unwrap();
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
        let access = ChapterContent::new(
            engine.storage().clone(),
            Arc::new(|| panic!("缓存命中不得创建网络客户端")),
            crate::runtime::get_runtime().handle().clone(),
        );
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
