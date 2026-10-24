use super::*;
use crate::{
    CacheDownloads, EngineContext,
    reading_service::{ChapterCacheService, ChapterContent},
};
use legado_core::models::{Book, BookChapter, BookSource};
use legado_db::repository::Repository;
use std::{
    io::{Read, Write},
    net::TcpListener,
    sync::{
        Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

const PNG: &[u8] = &[
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0,
    0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 96, 0, 2, 0, 0, 5, 0, 1,
    122, 94, 171, 63, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
];

struct Server {
    base: String,
    requests: Arc<Mutex<Vec<String>>>,
    stop: Arc<AtomicBool>,
    thread: Option<std::thread::JoinHandle<()>>,
}
impl Server {
    fn new(reply: impl Fn(&str, usize) -> (u16, Vec<u8>) + Send + 'static) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let stop = Arc::new(AtomicBool::new(false));
        let requests = Arc::new(Mutex::new(Vec::new()));
        let (quit, observed) = (stop.clone(), requests.clone());
        let thread = std::thread::spawn(move || {
            while !quit.load(Ordering::Acquire) {
                let (mut stream, _) = match listener.accept() {
                    Ok(value) => value,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        std::thread::sleep(Duration::from_millis(2));
                        continue;
                    }
                    Err(error) => panic!("回环HTTP接受失败: {error}"),
                };
                stream
                    .set_read_timeout(Some(Duration::from_secs(3)))
                    .unwrap();
                let mut request = Vec::new();
                let mut byte = [0];
                while !request.ends_with(b"\r\n\r\n") {
                    assert_eq!(stream.read(&mut byte).unwrap(), 1);
                    request.push(byte[0]);
                }
                let request = String::from_utf8(request).unwrap();
                let count = {
                    let mut requests = observed.lock().unwrap();
                    requests.push(request.clone());
                    requests.len()
                };
                let (status, bytes) = reply(&request, count);
                // 取消HTTP后客户端会主动关闭，此处允许写入失败。
                let _ = write!(
                    stream,
                    "HTTP/1.1 {status} OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    bytes.len()
                );
                let _ = stream.write_all(&bytes);
            }
        });
        Self {
            base,
            requests,
            stop,
            thread: Some(thread),
        }
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        self.thread.take().unwrap().join().unwrap();
    }
}

fn fixture(
    base: &str,
    body: &str,
    decode: Option<&str>,
) -> (EngineContext, tokio::runtime::Runtime, String) {
    let engine = EngineContext::in_memory().unwrap();
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let book_url = format!("{base}/book");
    engine
        .storage()
        .with_database(|db| {
            let source: BookSource = serde_json::from_value(serde_json::json!({
                "bookSourceUrl":base,"bookSourceName":"离线漫画","bookSourceType":2,
                "header":{"X-Source":"source-token"},
                "ruleContent":{"content":".content@html","imageDecode":decode}
            }))?;
            BookSourceRepository::new(db.connection()).insert(&source)?;
            BookRepository::new(db.connection()).insert(&Book {
                book_url: book_url.clone(),
                origin: base.into(),
                book_type: book_type::IMAGE,
                ..Default::default()
            })?;
            BookChapterRepository::new(db.connection()).insert_batch(&[BookChapter {
                book_url: book_url.clone(),
                url: format!("{base}/chapter"),
                title: "第一章".into(),
                ..Default::default()
            }])?;
            Ok(())
        })
        .unwrap();
    assert!(crate::reading_service::save_chapter_cache(
        engine.storage(),
        &book_url,
        0,
        "第一章",
        &format!("{base}/chapter"),
        body
    ));
    (engine, runtime, book_url)
}

fn downloads(
    engine: &EngineContext,
    runtime: &tokio::runtime::Runtime,
    root: std::path::PathBuf,
) -> Arc<CacheDownloads> {
    let network = engine.network().clone();
    let js = engine.js_resources().clone();
    let factory = Arc::new(move || {
        Ok(legado_fetcher::deps::FetcherDeps::new(network.client()?).with_js_resources(js.clone()))
    });
    let content = ChapterContent::new(engine.storage().clone(), factory, runtime.handle().clone());
    let images = MangaCache::new(
        engine.storage().clone(),
        engine.network().clone(),
        engine.js_resources().clone(),
        runtime.handle().clone(),
    );
    let cache = ImageCacheService::new(root);
    Arc::new(CacheDownloads::new(
        engine.storage().clone(),
        engine.tasks().clone(),
        Arc::new(move |book, index, task| {
            content.download(book, index, task)?;
            images.download(book, index, task, &cache)
        }),
    ))
}
fn wait(service: &Arc<CacheDownloads>, id: u64) -> crate::CacheDownloadTask {
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        let task = service.progress(id).unwrap();
        if task.status != "running" {
            return task;
        }
        assert!(Instant::now() < deadline, "漫画下载未结束");
        std::thread::sleep(Duration::from_millis(2));
    }
}

#[test]
#[cfg(feature = "quickjs")]
fn offline_images_use_headers_and_decode_retry_only_missing_then_read_without_network() {
    let failed_once = Arc::new(AtomicBool::new(false));
    let fail = failed_once.clone();
    let server = Server::new(move |request, _| {
        let request = request.to_ascii_lowercase();
        assert!(request.contains("x-source: source-token"));
        assert!(request.contains("referer:"));
        if request.starts_with("get /b.png ") {
            assert!(request.contains("x-page: page-token"));
            if !fail.swap(true, Ordering::AcqRel) {
                return (500, "失败".as_bytes().to_vec());
            }
        }
        let mut encrypted = vec![42];
        encrypted.extend_from_slice(PNG);
        (200, encrypted)
    });
    let body = format!(
        r#"<img src='/a.png'><img src='{}/b.png,{{"headers":{{"X-Page":"page-token"}}}}'><img src="{}/a.png">"#,
        server.base, server.base
    );
    let (engine, runtime, book) = fixture(&server.base, &body, Some("result.slice(1)"));
    let root = engine.storage().data_directory("manga-images").unwrap();
    engine
        .storage()
        .with_database(|db| {
            db.connection()
                .execute(
                    "UPDATE chapters SET imgUrl = ?1 WHERE bookUrl = ?2",
                    [format!("{}/cover.png", server.base), book.clone()],
                )
                .map_err(|error| LegadoError::Database(error.to_string()))?;
            Ok(())
        })
        .unwrap();
    let service = downloads(&engine, &runtime, root.clone());
    let reader_cache = ChapterCacheService::new(Some(engine.storage().clone()))
        .with_image_cache(ImageCacheService::new(root.clone()));
    assert!(
        reader_cache
            .list_cached_chapter_urls(&book)
            .unwrap()
            .is_empty()
    );
    let task = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((task.completed, task.failed), (0, 1));
    assert_eq!(service.chapters(&book, true).unwrap(), [0]);
    assert!(reader_cache.list_cached_chapters(&book).unwrap().is_empty());
    let retry = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((retry.completed, retry.failed), (1, 0));
    assert!(service.chapters(&book, true).unwrap().is_empty());
    let requests = server.requests.lock().unwrap().clone();
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.starts_with("GET /a.png "))
            .count(),
        1
    );
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.starts_with("GET /b.png "))
            .count(),
        2
    );
    drop(server);
    assert_eq!(
        reader_cache.list_cached_chapter_urls(&book).unwrap(),
        [format!("{}/chapter", book.trim_end_matches("/book"))]
    );
    assert_eq!(
        ImageCacheService::new(root)
            .get_image_cache(&book, &format!("{}/a.png", book.trim_end_matches("/book")))
            .unwrap(),
        PNG
    );
    let again = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((again.completed, again.failed), (1, 0));
}

#[test]
fn manga_volume_is_skipped_without_fetching_and_text_cached_state_keeps_its_rules() {
    let (engine, runtime, book) = fixture("https://offline.invalid", "正文", None);
    engine
        .storage()
        .with_database(|db| {
            db.connection()
                .execute(
                    "UPDATE chapters SET isVolume = 1 WHERE bookUrl = ?1",
                    [&book],
                )
                .map_err(|error| LegadoError::Database(error.to_string()))?;
            CacheBookRepository::new(db.connection()).delete_by_book(&book)?;
            Ok(())
        })
        .unwrap();
    let root = engine.storage().data_directory("volume-images").unwrap();
    let service = downloads(&engine, &runtime, root.clone());
    let volume = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((volume.completed, volume.failed), (1, 0));
    assert!(!root.exists());
    engine
        .storage()
        .with_database(|db| {
            db.connection()
                .execute("UPDATE book_sources SET bookSourceType = 0", [])
                .map_err(|error| LegadoError::Database(error.to_string()))?;
            db.connection()
                .execute("UPDATE books SET type = 0", [])
                .map_err(|error| LegadoError::Database(error.to_string()))?;
            Ok(())
        })
        .unwrap();
    assert!(crate::reading_service::save_chapter_cache(
        engine.storage(),
        &book,
        0,
        "第一章",
        "https://offline.invalid/chapter",
        "文本正文"
    ));
    let cache = ChapterCacheService::new(Some(engine.storage().clone()))
        .with_image_cache(ImageCacheService::new(root));
    assert_eq!(
        cache.list_cached_chapter_urls(&book).unwrap(),
        ["https://offline.invalid/chapter"]
    );
}

#[test]
fn cancelled_image_response_is_not_written_and_does_not_start_next_image() {
    let (started, ready) = std::sync::mpsc::channel();
    let (release, gate) = std::sync::mpsc::channel();
    let server = Server::new(move |_, _| {
        started.send(()).unwrap();
        gate.recv_timeout(Duration::from_secs(5)).unwrap();
        (200, PNG.to_vec())
    });
    let body = format!(
        r#"<img src="{}/hold.png"><img src="{}/next.png">"#,
        server.base, server.base
    );
    let (engine, runtime, book) = fixture(&server.base, &body, None);
    let root = engine.storage().data_directory("cancel-images").unwrap();
    let service = downloads(&engine, &runtime, root.clone());
    let id = service.start(&book, 0, 0).unwrap();
    ready.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(service.cancel(id).unwrap());
    release.send(()).unwrap();
    assert_eq!(wait(&service, id).status, "cancelled");
    let deadline = Instant::now() + Duration::from_secs(5);
    while engine.tasks().active_count() != 0 {
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(server.requests.lock().unwrap().len(), 1);
    assert!(
        !ImageCacheService::new(root).has_image_cache(&book, &format!("{}/hold.png", server.base))
    );
}

#[test]
fn invalid_image_and_disk_failure_count_failed_until_retry_has_complete_images() {
    let server = Server::new(|_, count| {
        if count == 1 {
            (200, b"not an image".to_vec())
        } else {
            (200, PNG.to_vec())
        }
    });
    let body = format!(r#"<img src="{}/page.png">"#, server.base);
    let (engine, runtime, book) = fixture(&server.base, &body, None);
    let root = engine
        .storage()
        .data_directory("unwritable-images")
        .unwrap();
    let service = downloads(&engine, &runtime, root.clone());
    let task = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((task.completed, task.failed), (0, 1));
    assert!(!root.exists());
    std::fs::write(&root, "用文件阻挡缓存目录".as_bytes()).unwrap();
    let task = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((task.completed, task.failed), (0, 1));
    std::fs::remove_file(&root).unwrap();
    let task = wait(&service, service.start(&book, 0, 0).unwrap());
    assert_eq!((task.completed, task.failed), (1, 0));
    std::fs::remove_file(
        ImageCacheService::new(root.clone())
            .image_file_path(&book, &format!("{}/page.png", server.base)),
    )
    .unwrap();
    let cache = ChapterCacheService::new(Some(engine.storage().clone()))
        .with_image_cache(ImageCacheService::new(root));
    assert!(cache.list_cached_chapter_urls(&book).unwrap().is_empty());
}
