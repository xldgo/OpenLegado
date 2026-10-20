//! 音频缓存算法及实例下载行为回归。
use super::*;

static TEST_ENGINE: OnceLock<crate::EngineContext> = OnceLock::new();
static TEST_DIR_OVERRIDE: Mutex<Option<PathBuf>> = Mutex::new(None);
fn test_engine() -> &'static crate::EngineContext {
    TEST_ENGINE.get_or_init(|| crate::EngineContext::in_memory().unwrap())
}
fn ensure_test_db() -> &'static crate::EngineContext {
    test_engine()
}
fn with_database<F, R>(f: F) -> LegadoResult<R>
where
    F: FnOnce(&legado_db::Database) -> LegadoResult<R>,
{
    test_engine().storage().with_database(f)
}
fn test_runtime() -> &'static tokio::runtime::Runtime {
    static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap()
    })
}
fn block_on<F: std::future::Future>(future: F) -> F::Output {
    test_runtime().block_on(future)
}
fn context_for(
    engine: &crate::EngineContext,
    directory: PathBuf,
) -> LegadoResult<AudioDownloadContext> {
    let network = engine.network().clone();
    let js = engine.js_resources().clone();
    let rate = engine.rate_limiter();
    let login = engine.source_login_cache().clone();
    let factory = std::sync::Arc::new(move || {
        Ok(legado_fetcher::deps::FetcherDeps::new(network.client()?)
            .with_js_resources(js.clone())
            .with_rate_limiter(rate.clone())
            .with_login_header({
                let login = login.clone();
                std::sync::Arc::new(move |source| login.get_login_header(source))
            }))
    });
    AudioDownloadContext::new(
        engine.storage().clone(),
        engine.media().clone(),
        directory,
        factory,
        engine.tasks(),
        test_runtime().handle().clone(),
    )
}
fn cache_root() -> PathBuf {
    TEST_DIR_OVERRIDE
        .lock()
        .unwrap()
        .clone()
        .or_else(|| test_engine().media().audio_directory())
        .unwrap_or_else(|| std::env::temp_dir().join("legado-audio-cache"))
}
fn book_dir(book: &str) -> PathBuf {
    AudioCacheService::new(cache_root()).book_dir(book)
}
fn set_cache_dir(path: &str) {
    test_engine()
        .media()
        .set_audio_directory(Some(PathBuf::from(path)));
}
fn audio_cache_query(book: &str, index: i32, url: &str, title: &str) -> bool {
    AudioCacheService::new(cache_root()).audio_cache_query(book, index, url, title)
}
fn audio_cache_list(book: &str) -> Vec<i32> {
    AudioCacheService::new(cache_root()).audio_cache_list(book)
}
fn audio_cache_clear_chapter(book: &str, index: i32, url: &str, title: &str) -> i32 {
    AudioCacheService::new(cache_root()).audio_cache_clear_chapter(book, index, url, title)
}
fn audio_cache_clear_book(book: &str) -> i32 {
    AudioCacheService::new(cache_root()).audio_cache_clear_book(book)
}
fn audio_cache_cancel() -> LegadoResult<bool> {
    Ok(test_engine().media().cancel_audio())
}
fn audio_cache_download_with_client(
    client: &LegadoClient,
    book: &str,
    index: i32,
    url: &str,
    title: &str,
    play: &str,
) -> LegadoResult<String> {
    if kotlin_is_blank(book) {
        return Err(LegadoError::Ffi("书籍 URL 为空".into()));
    }
    audio_cache_download_in(
        &context_for(test_engine(), cache_root())?,
        client,
        book,
        index,
        url,
        title,
        play,
    )
}
fn audio_cache_download_in(
    context: &AudioDownloadContext,
    client: &LegadoClient,
    book: &str,
    index: i32,
    url: &str,
    title: &str,
    play: &str,
) -> LegadoResult<String> {
    Ok(serde_json::to_string(&download(
        context, client, book, index, url, title, play,
    )?)?)
}

use legado_core::models::BookSource;
use legado_db::repository::Repository;
use std::sync::atomic::AtomicUsize;
use std::time::Duration;

fn isolated_audio_engine() -> std::sync::Arc<crate::EngineContext> {
    let engine = std::sync::Arc::new(crate::EngineContext::in_memory().unwrap());
    engine
        .storage()
        .with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: "same-book".into(),
                name: "独立音频书".into(),
                origin: "same-source".into(),
                ..Default::default()
            })?;
            BookSourceRepository::new(db.connection()).insert(
                &legado_core::models::BookSource {
                    book_source_url: "same-source".into(),
                    book_source_name: "测试".into(),
                    ..Default::default()
                },
            )?;
            BookChapterRepository::new(db.connection()).insert(
                &legado_core::models::BookChapter {
                    book_url: "same-book".into(),
                    url: "same-chapter".into(),
                    title: "第一章".into(),
                    index: 0,
                    ..Default::default()
                },
            )?;
            Ok(())
        })
        .unwrap();
    engine
}

#[test]
fn isolated_real_audio_downloads_use_original_storage_and_directory() {
    use crate::test_http_fixture::Fixture;
    let fixture = Fixture::with_content_type(2, false, "audio/mpeg", |_| "ID3-audio".into());
    let first = isolated_audio_engine();
    let second = isolated_audio_engine();
    let client = test_client();
    let mut paths = Vec::new();
    for engine in [&first, &second] {
        let directory = engine.storage().data_directory("audio").unwrap();
        let context = context_for(engine, directory.clone()).unwrap();
        let output = audio_cache_download_in(
            &context,
            &client,
            "same-book",
            0,
            "same-chapter",
            "第一章",
            &format!("{}/audio.mp3", fixture.url),
        )
        .unwrap();
        let result: serde_json::Value = serde_json::from_str(&output).unwrap();
        let path = PathBuf::from(result["path"].as_str().unwrap());
        assert!(path.starts_with(&directory));
        assert_eq!(std::fs::read(&path).unwrap(), b"ID3-audio");
        assert!(PathBuf::from(format!("{}.complete", path.display())).exists());
        paths.push(path);
    }
    assert_ne!(paths[0], paths[1]);
    fixture.worker.join().unwrap();
    assert_eq!(first.tasks().active_count(), 0);
    assert_eq!(second.tasks().active_count(), 0);
}

#[test]
fn isolated_root_cancel_during_real_audio_request_leaves_no_installed_files() {
    use crate::test_http_fixture::Fixture;
    let mut fixture = Fixture::with_content_type(1, true, "audio/mpeg", |_| "ID3-audio".into());
    let engine = isolated_audio_engine();
    let storage = engine.storage().clone();
    let directory = storage.data_directory("audio").unwrap();
    let context = context_for(&engine, directory.clone()).unwrap();
    let tasks = engine.tasks().clone();
    let weak = std::sync::Arc::downgrade(&engine);
    let url = format!("{}/audio.mp3", fixture.url);
    let worker = std::thread::spawn(move || {
        audio_cache_download_in(
            &context,
            &test_client(),
            "same-book",
            0,
            "same-chapter",
            "第一章",
            &url,
        )
    });
    assert!(block_on(fixture.request()).starts_with("GET /audio.mp3 "));
    drop(engine);
    assert!(weak.upgrade().is_none());
    assert!(
        worker
            .join()
            .unwrap()
            .unwrap_err()
            .to_string()
            .contains("已取消")
    );
    fixture.release.send(()).unwrap();
    fixture.worker.join().unwrap();
    assert!(block_on(tasks.shutdown(Duration::from_secs(3))));
    let book_directory = directory.join(format!("book_{}", md5_mid16("same-book")));
    assert!(read_dir_entries(&book_directory).is_empty());
}

/// 测试串行锁：宿主目录/`TEST_DIR_OVERRIDE` 为进程级状态，
/// 并行测试互踩 → 触碰进程级目录状态的测试先持锁（对齐 image_cache 先例）
static TEST_LOCK: Mutex<()> = Mutex::new(());
static COUNTER: AtomicUsize = AtomicUsize::new(0);

/// 进程级唯一临时根目录（测试收尾 remove_dir_all 清理）
fn unique_root(tag: &str) -> PathBuf {
    let n = COUNTER.fetch_add(1, Ordering::Relaxed);
    std::env::temp_dir().join(format!(
        "legado-audio-cache-test-{}-{}-{}",
        std::process::id(),
        n,
        tag
    ))
}

fn set_test_root(dir: &Path) {
    if let Ok(mut guard) = TEST_DIR_OVERRIDE.lock() {
        *guard = Some(dir.to_path_buf());
    }
}

fn clear_test_root() {
    if let Ok(mut guard) = TEST_DIR_OVERRIDE.lock() {
        *guard = None;
    }
}

/// 写一个五段式数据文件（可选 `.complete` 标记）
fn write_cache_file(dir: &Path, name: &str, size: usize, marker: bool) -> PathBuf {
    fs::create_dir_all(dir).unwrap();
    let path = dir.join(name);
    fs::write(&path, vec![7u8; size]).unwrap();
    if marker {
        fs::write(dir.join(format!("{name}{COMPLETE_SUFFIX}")), b"1\nx\nx").unwrap();
    }
    path
}

/// 合法五段式文件名（key 为 hello 的 md5Encode16 向量）
fn valid_name(index: i32, key: &str, ext: &str) -> String {
    format!("{index:05}_{key}_某章节_bc964d2a0c9c9bf9_9f8e7d6c.{ext}")
}

const KEY_HELLO: &str = "bc4b2a76b9719d91";

// 键向量：与原版 MD5Utils.md5Encode16（hutool MD5 小写 hex [8,24)）逐字节对齐
#[test]
fn key_vectors() {
    assert_eq!(cache_key16("hello", "任意标题"), KEY_HELLO);
    assert_eq!(cache_key16("中文", "任意标题"), "9fcdcb3a067903d8");
    assert_eq!(
        cache_key16("https://example.com/ch/1.mp3", ""),
        "bc964d2a0c9c9bf9"
    );
    // 空串键 = md5("") 中段 16 字符（title 为空时 identity 为空串）
    assert_eq!(cache_key16("", ""), "8f00b204e9800998");
}

// ifBlank 语义：空白 URL 退回标题；不 trim、大小写敏感；NBSP 不算空白（Java 语义）
#[test]
fn key_if_blank_and_sensitivity() {
    assert_eq!(cache_key16("   ", "标题"), cache_key16("标题", "无关"));
    assert_eq!(cache_key16("\t\n", "标题"), cache_key16("标题", "无关"));
    // 不 trim：带空格的 URL 原样参与哈希
    assert_ne!(cache_key16(" abc ", "标题"), cache_key16("abc", "标题"));
    assert_ne!(cache_key16("ABC", "标题"), cache_key16("abc", "标题"));
    // NBSP（U+00A0）在 Kotlin/Java 中不是空白 → 不退回标题
    assert_ne!(cache_key16("\u{00A0}", "标题"), cache_key16("标题", "无关"));
    assert_eq!(cache_key16("\u{00A0}", "标题"), md5_mid16("\u{00A0}"));
}

// 五段式文件名解析（对齐原版 AudioCachePolicy.parseFileName）
#[test]
fn parse_five_segment_names() {
    let ok = parse_cache_file_name(&valid_name(42, KEY_HELLO, "mp3")).unwrap();
    assert_eq!(ok.chapter_index, 42);
    assert_eq!(ok.key16, KEY_HELLO);
    // 扩展名白名单：audio 与音频后缀均可
    assert!(parse_cache_file_name(&valid_name(1, KEY_HELLO, "audio")).is_some());
    assert!(parse_cache_file_name(&valid_name(1, KEY_HELLO, "flac")).is_some());
    // 章节序号 5 位起；4 位不匹配
    assert!(
        parse_cache_file_name("0042_bc4b2a76b9719d91_标题_bc964d2a0c9c9bf9_9f8e7d6c.mp3").is_none()
    );
    // 非音频扩展名不匹配
    assert!(parse_cache_file_name(&valid_name(1, KEY_HELLO, "txt")).is_none());
    // 大写 hex 不匹配（正则要求小写）
    assert!(
        parse_cache_file_name("00042_BC4B2A76B9719D91_标题_bc964d2a0c9c9bf9_9f8e7d6c.mp3")
            .is_none()
    );
    // 段数不足不匹配
    assert!(parse_cache_file_name("00042_bc4b2a76b9719d91_标题.mp3").is_none());
    // 序号溢出 i32 → 跳过
    assert!(
        parse_cache_file_name("99999999999_bc4b2a76b9719d91_标题_bc964d2a0c9c9bf9_9f8e7d6c.mp3")
            .is_none()
    );
    // 旧孤儿键命名不匹配（不读不迁移的天然屏障）
    assert!(parse_cache_file_name("-123456_0.audio").is_none());
}

// 命中三条件：key 匹配 + .complete 存在 + size > 0
#[test]
fn query_hit_requires_marker_and_nonzero_size() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("hit");
    set_test_root(&root);
    let dir = book_dir("https://a.com/book/1");
    let url = "hello";
    let title = "第一章";
    let name = valid_name(1, KEY_HELLO, "mp3");

    // 目录不存在 → false
    assert!(!audio_cache_query("https://a.com/book/1", 1, url, title));
    // 无标记 → false
    write_cache_file(&dir, &name, 16, false);
    assert!(!audio_cache_query("https://a.com/book/1", 1, url, title));
    // 有标记但 size=0 → false
    fs::remove_file(dir.join(&name)).unwrap();
    write_cache_file(&dir, &name, 0, true);
    assert!(!audio_cache_query("https://a.com/book/1", 1, url, title));
    // 有标记且 size>0 → true
    fs::remove_file(dir.join(&name)).unwrap();
    write_cache_file(&dir, &name, 16, true);
    assert!(audio_cache_query("https://a.com/book/1", 1, url, title));
    // 键不匹配（同 URL 不同章）→ false
    assert!(!audio_cache_query(
        "https://a.com/book/1",
        2,
        "hello2",
        title
    ));
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// 同名多条：取 lastModified 最新者
#[test]
fn latest_committed_prefers_newest() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("latest");
    set_test_root(&root);
    let dir = book_dir("https://a.com/book/2");
    let old_name = valid_name(3, KEY_HELLO, "mp3");
    let new_name = valid_name(3, KEY_HELLO, "m4a");
    let old_path = write_cache_file(&dir, &old_name, 8, true);
    let new_path = write_cache_file(&dir, &new_name, 8, true);
    let old_time = SystemTime::UNIX_EPOCH + Duration::from_secs(1_000_000);
    let new_time = SystemTime::UNIX_EPOCH + Duration::from_secs(2_000_000);
    // Windows 下 SetFileTime 需写权限句柄，故以 write 打开设置 mtime
    fs::OpenOptions::new()
        .write(true)
        .open(&old_path)
        .unwrap()
        .set_modified(old_time)
        .unwrap();
    fs::OpenOptions::new()
        .write(true)
        .open(&new_path)
        .unwrap()
        .set_modified(new_time)
        .unwrap();
    assert_eq!(
        latest_committed_file(&dir, KEY_HELLO).map(|(n, _)| n),
        Some(new_name.clone())
    );
    assert!(audio_cache_query(
        "https://a.com/book/2",
        3,
        "hello",
        "第一章"
    ));
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// 列举：仅已提交条目、下标去重升序；无标记/空文件/不匹配文件跳过
#[test]
fn list_sorted_unique_committed() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("list");
    set_test_root(&root);
    let dir = book_dir("https://a.com/book/3");
    write_cache_file(&dir, &valid_name(5, KEY_HELLO, "mp3"), 8, true);
    write_cache_file(&dir, &valid_name(2, KEY_HELLO, "mp3"), 8, true);
    write_cache_file(&dir, &valid_name(2, KEY_HELLO, "m4a"), 8, true); // 同章多版本 → 去重
    write_cache_file(&dir, &valid_name(7, KEY_HELLO, "mp3"), 8, false); // 无标记
    write_cache_file(&dir, &valid_name(9, KEY_HELLO, "mp3"), 0, true); // 空文件
    write_cache_file(&dir, "-123_legacy.audio", 8, false); // 旧键孤儿 → 跳过
    assert_eq!(audio_cache_list("https://a.com/book/3"), vec![2, 5]);
    // 无缓存的书 → 空
    assert!(audio_cache_list("https://a.com/book/other").is_empty());
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// 清理单章：只删该 key 的数据文件与标记；幂等；不触碰其他章节
#[test]
fn clear_chapter_isolated_and_idempotent() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("clear-chapter");
    set_test_root(&root);
    let dir = book_dir("https://a.com/book/4");
    let hit = valid_name(1, KEY_HELLO, "mp3");
    let other_key = md5_mid16("other-url");
    let other = valid_name(2, &other_key, "mp3");
    write_cache_file(&dir, &hit, 8, true);
    write_cache_file(&dir, &other, 8, true);
    // 删除数 = 数据文件（**不含** .complete 标记，契约 §2.47 口径修正）
    assert_eq!(
        audio_cache_clear_chapter("https://a.com/book/4", 1, "hello", "第一章"),
        1
    );
    assert!(!audio_cache_query(
        "https://a.com/book/4",
        1,
        "hello",
        "第一章"
    ));
    assert!(audio_cache_query(
        "https://a.com/book/4",
        2,
        "other-url",
        "第二章"
    ));
    // 幂等：再次清理返回 0
    assert_eq!(
        audio_cache_clear_chapter("https://a.com/book/4", 1, "hello", "第一章"),
        0
    );
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// 清理整书：全删（含标记）、目录移除；幂等；不跨书
#[test]
fn clear_book_all_and_idempotent() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("clear-book");
    set_test_root(&root);
    let dir_a = book_dir("https://a.com/book/A");
    let dir_b = book_dir("https://a.com/book/B");
    write_cache_file(&dir_a, &valid_name(1, KEY_HELLO, "mp3"), 8, true);
    write_cache_file(&dir_a, &valid_name(2, KEY_HELLO, "mp3"), 8, true);
    write_cache_file(&dir_b, &valid_name(1, KEY_HELLO, "mp3"), 8, true);
    // 删除数 = 两个数据文件（**不含** .complete 标记，契约 §2.47 口径修正）
    assert_eq!(audio_cache_clear_book("https://a.com/book/A"), 2);
    assert!(!dir_a.exists(), "书目录应一并移除");
    assert!(
        audio_cache_query("https://a.com/book/B", 1, "hello", "第一章"),
        "不得跨书清理"
    );
    assert_eq!(audio_cache_clear_book("https://a.com/book/A"), 0, "幂等");
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// 书级隔离：不同 bookUrl 目录不同、互不串缓存
#[test]
fn book_isolation() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("isolation");
    set_test_root(&root);
    write_cache_file(
        &book_dir("https://a.com/book/X"),
        &valid_name(1, KEY_HELLO, "mp3"),
        8,
        true,
    );
    assert!(audio_cache_query(
        "https://a.com/book/X",
        1,
        "hello",
        "第一章"
    ));
    assert!(!audio_cache_query(
        "https://a.com/book/Y",
        1,
        "hello",
        "第一章"
    ));
    assert!(audio_cache_list("https://a.com/book/Y").is_empty());
    assert_ne!(
        book_dir("https://a.com/book/X"),
        book_dir("https://a.com/book/Y")
    );
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// 失败降级：根目录被普通文件占用（目录扫描/删除失败）→ 不 panic，按无缓存处理
#[test]
fn failures_degrade_without_panic() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("degrade");
    fs::create_dir_all(root.parent().unwrap()).unwrap();
    fs::write(&root, b"i-am-a-file").unwrap();
    set_test_root(&root);
    assert!(!audio_cache_query(
        "https://a.com/book/1",
        1,
        "hello",
        "第一章"
    ));
    assert!(audio_cache_list("https://a.com/book/1").is_empty());
    assert_eq!(
        audio_cache_clear_chapter("https://a.com/book/1", 1, "hello", "第一章"),
        0
    );
    assert_eq!(audio_cache_clear_book("https://a.com/book/1"), 0);
    fs::remove_file(&root).ok();
    clear_test_root();
}

// set_cache_dir 注入：查询/列举/清理落注入目录
#[test]
fn injected_dir_used() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("injected");
    clear_test_root();
    set_cache_dir(root.to_str().unwrap());
    write_cache_file(
        &book_dir("https://a.com/book/5"),
        &valid_name(4, KEY_HELLO, "mp3"),
        8,
        true,
    );
    assert!(audio_cache_query(
        "https://a.com/book/5",
        4,
        "hello",
        "第一章"
    ));
    assert_eq!(audio_cache_list("https://a.com/book/5"), vec![4]);
    assert!(
        root.join(format!("book_{}", md5_mid16("https://a.com/book/5")))
            .exists()
    );
    // 删除数 = 数据文件（不含 .complete 标记）
    assert_eq!(audio_cache_clear_book("https://a.com/book/5"), 1);
    // 复位注入槽为 None（不污染其他测试）
    test_engine().media().set_audio_directory(None);
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

// ─── B2 写入面（契约 §2.48）─────────────────────────────────────────────

/// 本地回环 HTTP 服务器（不联网）：按请求序号返回固定响应
struct ServerReply {
    status: u16,
    content_type: &'static str,
    body: Vec<u8>,
    /// 覆盖 Content-Length 声明（默认实际 body 长度）
    declared_len: Option<u64>,
}

impl ServerReply {
    fn ok(content_type: &'static str, body: Vec<u8>) -> Self {
        Self {
            status: 200,
            content_type,
            body,
            declared_len: None,
        }
    }
}

/// 启动一次性回环服务器（请求序号从 0 起；线程随测试进程退出）
fn spawn_server<F>(responder: F) -> (u16, std::sync::Arc<std::sync::atomic::AtomicUsize>)
where
    F: Fn(usize) -> ServerReply + Send + Sync + 'static,
{
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::atomic::AtomicUsize;

    let listener = TcpListener::bind("127.0.0.1:0").expect("绑定回环端口");
    let port = listener.local_addr().unwrap().port();
    let hits = std::sync::Arc::new(AtomicUsize::new(0));
    let hits_srv = std::sync::Arc::clone(&hits);
    let responder = std::sync::Arc::new(responder);
    std::thread::spawn(move || {
        let mut idx = 0usize;
        for stream in listener.incoming() {
            let Ok(mut sock) = stream else { continue };
            let reply = responder(idx);
            idx += 1;
            hits_srv.fetch_add(1, Ordering::SeqCst);
            // 读请求头至 \r\n\r\n（不解析请求体；本路径均为 GET）
            let mut head = Vec::new();
            let mut b = [0u8; 1];
            while let Ok(1) = sock.read(&mut b) {
                head.push(b[0]);
                if head.ends_with(b"\r\n\r\n") {
                    break;
                }
            }
            let reason = if (200..300).contains(&reply.status) {
                "OK"
            } else {
                "Error"
            };
            let mut out = format!("HTTP/1.1 {} {reason}\r\n", reply.status);
            out.push_str(&format!("Content-Type: {}\r\n", reply.content_type));
            out.push_str(&format!(
                "Content-Length: {}\r\n",
                reply.declared_len.unwrap_or(reply.body.len() as u64)
            ));
            out.push_str("Connection: close\r\n\r\n");
            let _ = sock.write_all(out.as_bytes());
            let _ = sock.write_all(&reply.body);
            let _ = sock.flush();
            let _ = sock.shutdown(std::net::Shutdown::Both);
        }
    });
    (port, hits)
}

/// 回环测试客户端（no_proxy：测试流量不得经系统/环境代理路由）
fn test_client() -> LegadoClient {
    LegadoClient::new(legado_net::LegadoClientConfig {
        no_proxy: true,
        ..legado_net::LegadoClientConfig::default()
    })
    .expect("构建测试 HTTP 客户端")
}

/// 插入音频书 + 书源 + 单章（测试 DB，唯一 bookUrl 隔离）
fn insert_audio_book(
    book_url: &str,
    source_url: &str,
    chapter_url: &str,
    chapter_title: &str,
    is_volume: bool,
) {
    with_database(|db| {
        let book = legado_core::models::Book {
            book_url: book_url.to_string(),
            // name 随 bookUrl 唯一：books 表有 (name, author) 唯一索引
            // （schema.rs:646），同名会被 INSERT OR REPLACE 顶掉
            name: format!("听书写入面测试-{book_url}"),
            author: String::new(),
            origin: source_url.to_string(),
            ..Default::default()
        };
        BookRepository::new(db.connection()).insert(&book)?;
        let source = BookSource {
            book_source_url: source_url.to_string(),
            book_source_name: "测试音频源".into(),
            ..BookSource::default()
        };
        BookSourceRepository::new(db.connection()).insert(&source)?;
        let chapter = legado_core::models::BookChapter {
            book_url: book_url.to_string(),
            index: 0,
            title: chapter_title.to_string(),
            url: chapter_url.to_string(),
            is_volume,
            ..Default::default()
        };
        BookChapterRepository::new(db.connection()).insert(&chapter)?;
        Ok(())
    })
    .unwrap();
}

/// safeTitle 归一（对齐 AudioCachePolicy.kt:79-87 各边界）
#[test]
fn safe_title_normalization() {
    // 非法文件名字符替换 `_`（fileNameRegex2 不含 `.`，故 `.` 保留）；
    // 末尾 `?`→`_` 后被 trim('_') 去掉
    assert_eq!(safe_title("第一章:测试?"), "第一章_测试");
    assert_eq!(safe_title(r#"a\b/c*d"e<f>g|h"#), "a_b_c_d_e_f_g_h");
    assert_eq!(safe_title("第1.5章"), "第1.5章");
    // ISO 控制符去除（C0 + C1）
    assert_eq!(safe_title("a\u{0000}b\u{001F}c\u{007F}d\u{009F}e"), "abcde");
    // trim（Kotlin isWhitespace 语义）+ trim('_') 顺序
    assert_eq!(safe_title("  __标题__  "), "标题");
    assert_eq!(safe_title("__ 标题 __"), " 标题");
    // 空/全空白/全下划线 → chapter
    assert_eq!(safe_title(""), "chapter");
    assert_eq!(safe_title("   "), "chapter");
    assert_eq!(safe_title("___"), "chapter");
    // 截 40 字符后去尾部 `.`/空格；全被去除后回退 chapter
    let long = format!("{}..", "a".repeat(50));
    assert_eq!(safe_title(&long), "a".repeat(40));
    let dots = ".".repeat(45);
    assert_eq!(safe_title(&dots), "chapter");
    let mixed = format!("{}  ", "b".repeat(40));
    assert_eq!(safe_title(&mixed), "b".repeat(40));
    // NBSP 不属 Kotlin 空白 → 不被 trim 掉（Java 语义纠偏）
    assert_eq!(safe_title("\u{00A0}"), "\u{00A0}");
}

/// 扩展名三级探测与 HLS/多段拒绝（对齐 AudioCachePolicy.kt:25-65）
#[test]
fn extension_detection_and_rejections() {
    // playUrl 校验
    assert!(
        require_cacheable_play_url("")
            .unwrap_err()
            .to_string()
            .contains("播放链接为空")
    );
    assert!(require_cacheable_play_url("   ").is_err());
    assert!(
        require_cacheable_play_url("[{\"url\":\"a\"}]")
            .unwrap_err()
            .to_string()
            .contains("暂不支持缓存多段音频")
    );
    assert!(
        require_cacheable_play_url("https://x.com/a.M3U8?t=1")
            .unwrap_err()
            .to_string()
            .contains("暂不支持缓存 HLS 音频")
    );
    assert!(require_cacheable_play_url("https://x.com/a.m3u#frag").is_err());
    assert!(require_cacheable_play_url("https://x.com/a.mp3").is_ok());

    // Content-Type 优先映射
    assert_eq!(
        detect_extension(
            Some("audio/mpeg; charset=utf-8"),
            "https://x/a",
            "https://x/a"
        )
        .unwrap(),
        "mp3"
    );
    assert_eq!(
        detect_extension(Some("audio/mp4"), "https://x/a.m4b", "https://x/a.m4b").unwrap(),
        "m4a"
    );
    assert_eq!(
        detect_extension(Some("audio/x-flac"), "https://x/a", "https://x/a").unwrap(),
        "flac"
    );
    // Content-Type 缺失 → 最终 URL → playUrl → audio
    assert_eq!(
        detect_extension(None, "https://x.com/f.mp3?sign=1", "https://y/a").unwrap(),
        "mp3"
    );
    assert_eq!(
        detect_extension(None, "https://x.com/stream", "https://y.com/b.ogg#z").unwrap(),
        "ogg"
    );
    assert_eq!(
        detect_extension(None, "https://x.com/stream", "https://y/stream").unwrap(),
        "audio"
    );
    // Content-Type 存在但无已知子串（空串同）→ URL 兜底
    assert_eq!(
        detect_extension(Some(""), "https://x.com/f.aac", "https://y/a").unwrap(),
        "aac"
    );
    assert_eq!(
        detect_extension(
            Some("application/octet-stream"),
            "https://x.com/f",
            "https://y/a"
        )
        .unwrap(),
        "audio"
    );
    // HLS 拒绝：Content-Type 含 mpegurl / 最终 URL 为 m3u8
    assert!(
        detect_extension(
            Some("application/vnd.apple.mpegurl"),
            "https://x/a",
            "https://x/a"
        )
        .unwrap_err()
        .to_string()
        .contains("暂不支持缓存 HLS 音频")
    );
    assert!(detect_extension(None, "https://x/live.m3u8", "https://x/live").is_err());
    // URL 无点 → 不误判（substringAfterLast 缺省空串语义）
    assert_eq!(extension_from_url("https://x.com/stream"), None);
    assert_eq!(
        extension_from_url("https://x.com/a.MP3").as_deref(),
        Some("mp3")
    );
}

/// 五段式文件名与 `.complete` 元数据往返
#[test]
fn file_name_and_metadata_roundtrip() {
    let name = build_file_name(
        42,
        KEY_HELLO,
        "第一章",
        &md5_mid16("https://x/a.mp3"),
        "9f8e7d6c",
        "mp3",
    )
    .unwrap();
    assert!(name.starts_with("00042_bc4b2a76b9719d91_第一章_"));
    assert!(name.ends_with("_9f8e7d6c.mp3"));
    let parsed = parse_cache_file_name(&name).unwrap();
    assert_eq!(parsed.chapter_index, 42);
    assert_eq!(parsed.key16, KEY_HELLO);
    assert_eq!(parsed.extension, "mp3");
    // 先决条件不满足 → Err（对齐 Kotlin require）
    assert!(build_file_name(-1, KEY_HELLO, "t", &md5_mid16("x"), "9f8e7d6c", "mp3").is_err());
    assert!(build_file_name(1, KEY_HELLO, "t", "XYZ", "9f8e7d6c", "mp3").is_err());
    assert!(build_file_name(1, KEY_HELLO, "t", &md5_mid16("x"), "TOO_LONG_REV", "mp3").is_err());
    assert!(build_file_name(1, KEY_HELLO, "t", &md5_mid16("x"), "9f8e7d6c", "txt").is_err());

    // 元数据编解码：三行、md5 校验、限 3 段（playUrl 可含换行）
    let url = "https://x.com/a.mp3?q=1";
    let encoded = encode_metadata(url);
    assert_eq!(encoded.lines().count(), 3);
    assert_eq!(decode_metadata(&encoded).as_deref(), Some(url));
    assert!(decode_metadata("1\nbad\nx").is_none());
    assert!(decode_metadata("2\nx\ny").is_none());
    assert!(decode_metadata("1\nx\n").is_none());
    let two_line_url = "https://x/a\nb";
    assert_eq!(
        decode_metadata(&encode_metadata(two_line_url)).as_deref(),
        Some(two_line_url)
    );
}

/// 陈旧未提交清理：1 小时阈值 + 已提交文件豁免
#[test]
fn cleanup_stale_threshold() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("stale");
    set_test_root(&root);
    let key = KEY_HELLO;
    let dir = book_dir("https://a.com/book/stale");
    fs::create_dir_all(&dir).unwrap();
    let old = UNIX_EPOCH + Duration::from_secs(1_000_000);
    let recent = SystemTime::now();

    let stale_tmp = format!("tmp_{key}_abc.part");
    let fresh_tmp = format!("tmp_{key}_def.part");
    let stale_uncommitted = valid_name(1, key, "mp3");
    let fresh_uncommitted = valid_name(2, key, "mp3");
    let stale_committed = valid_name(3, key, "mp3");
    for name in [
        &stale_tmp,
        &fresh_tmp,
        &stale_uncommitted,
        &fresh_uncommitted,
        &stale_committed,
    ] {
        fs::write(dir.join(name), vec![7u8; 8]).unwrap();
    }
    fs::write(
        dir.join(format!("{stale_committed}{COMPLETE_SUFFIX}")),
        b"1\nx\nx",
    )
    .unwrap();
    for (name, t) in [
        (&stale_tmp, old),
        (&stale_uncommitted, old),
        (&stale_committed, old),
        (&fresh_tmp, recent),
        (&fresh_uncommitted, recent),
    ] {
        fs::OpenOptions::new()
            .write(true)
            .open(dir.join(name))
            .unwrap()
            .set_modified(t)
            .unwrap();
    }

    cleanup_uncommitted_files(&dir, key);
    assert!(!dir.join(&stale_tmp).exists(), "陈旧 tmp 应删除");
    assert!(
        !dir.join(&stale_uncommitted).exists(),
        "陈旧未提交五段式应删除"
    );
    assert!(dir.join(&stale_committed).exists(), "已提交文件不得删除");
    assert!(dir.join(&fresh_tmp).exists(), "未到 1 小时的 tmp 保留");
    assert!(
        dir.join(&fresh_uncommitted).exists(),
        "未到 1 小时的未提交文件保留"
    );
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// 前置校验：bookUrl/书籍/章节/分卷/书源/playUrl 全部门禁（不触网）
#[test]
fn download_validation_errors() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("download-validation");
    set_test_root(&root);
    let client = test_client();

    // bookUrl 空白
    assert!(
        audio_cache_download_with_client(&client, "  ", 0, "u", "t", "https://x/a.mp3")
            .unwrap_err()
            .to_string()
            .contains("书籍 URL 为空")
    );
    // 书籍不存在
    assert!(
        audio_cache_download_with_client(
            &client,
            "https://a.com/no-book",
            0,
            "u",
            "t",
            "https://x/a.mp3"
        )
        .unwrap_err()
        .to_string()
        .contains("书籍不存在")
    );
    // 章节不存在
    let book_url = "https://a.com/book/dl-val";
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );
    assert!(
        audio_cache_download_with_client(
            &client,
            book_url,
            9,
            "hello",
            "第一章",
            "https://x/a.mp3"
        )
        .unwrap_err()
        .to_string()
        .contains("章节 9 不存在")
    );
    // 分卷章节拒绝（原版文案）
    let vol_url = "https://a.com/book/dl-vol";
    insert_audio_book(
        vol_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        true,
    );
    assert!(
        audio_cache_download_with_client(&client, vol_url, 0, "hello", "第一章", "https://x/a.mp3")
            .unwrap_err()
            .to_string()
            .contains("分卷章节不支持缓存")
    );
    // playUrl 空 / JSON 多段 / HLS
    for (play, msg) in [
        ("", "播放链接为空"),
        ("[{\"url\":\"x\"}]", "暂不支持缓存多段音频"),
        ("https://x/live.m3u8", "暂不支持缓存 HLS 音频"),
    ] {
        let err = audio_cache_download_with_client(&client, book_url, 0, "hello", "第一章", play)
            .unwrap_err()
            .to_string();
        assert!(err.contains(msg), "playUrl={play:?} 应报 {msg}: {err}");
    }
    // 书源不在 DB（origin 指向未入库的书源 URL；不入书源行）
    let no_src_url = "https://a.com/book/dl-nosrc";
    with_database(|db| {
        let book = legado_core::models::Book {
            book_url: no_src_url.to_string(),
            name: "无书源测试".into(),
            origin: "https://source.example/never-inserted".into(),
            ..Default::default()
        };
        BookRepository::new(db.connection()).insert(&book)?;
        let chapter = legado_core::models::BookChapter {
            book_url: no_src_url.to_string(),
            index: 0,
            title: "第一章".into(),
            url: "hello".into(),
            ..Default::default()
        };
        BookChapterRepository::new(db.connection()).insert(&chapter)?;
        Ok(())
    })
    .unwrap();
    assert!(
        audio_cache_download_with_client(
            &client,
            no_src_url,
            0,
            "hello",
            "第一章",
            "https://x/a.mp3"
        )
        .unwrap_err()
        .to_string()
        .contains("书源不存在")
    );

    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// 幂等：已提交缓存直接 already_cached（不发网络请求）
#[test]
fn download_idempotent_already_cached() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("download-idem");
    set_test_root(&root);
    let book_url = "https://a.com/book/dl-idem";
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );
    let dir = book_dir(book_url);
    write_cache_file(&dir, &valid_name(0, KEY_HELLO, "mp3"), 2048, true);

    let out = audio_cache_download_with_client(
        &test_client(),
        book_url,
        0,
        "hello",
        "第一章",
        "https://x/a.mp3",
    )
    .unwrap();
    let json: serde_json::Value = serde_json::from_str(&out).unwrap();
    assert_eq!(json["status"], "already_cached");
    assert_eq!(json["sizeBytes"], 2048);
    assert_eq!(json["extension"], "mp3");
    assert!(json["path"].as_str().unwrap().ends_with(".mp3"));
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// 下载安装全链路：流式落盘 + rename 安装 + `.complete` 回读 + 旧版本清理 + 幂等
#[test]
fn download_installs_and_cleans_old_versions() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("download-install");
    set_test_root(&root);
    let body = vec![0xABu8; 64 * 1024];
    let (port, hits) =
        spawn_server(move |_i| ServerReply::ok("audio/mpeg; charset=utf-8", body.clone()));
    let book_url = "https://a.com/book/dl-install";
    let play_url = format!("http://127.0.0.1:{port}/media.mp3");
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );
    // 预置同 key 旧版本（未提交）+ tmp 残留：安装后应仅保留新文件
    let dir = book_dir(book_url);
    write_cache_file(&dir, &valid_name(0, KEY_HELLO, "m4a"), 8, false);
    fs::write(dir.join(format!("tmp_{KEY_HELLO}_old.part")), b"stale").unwrap();

    let out =
        audio_cache_download_with_client(&test_client(), book_url, 0, "hello", "第一章", &play_url)
            .unwrap();
    let json: serde_json::Value = serde_json::from_str(&out).unwrap();
    assert_eq!(json["status"], "installed");
    assert_eq!(json["sizeBytes"], 64 * 1024);
    assert_eq!(json["extension"], "mp3");
    let path = json["path"].as_str().unwrap();
    assert!(path.ends_with(".mp3"));
    assert_eq!(fs::metadata(path).unwrap().len(), 64 * 1024);
    // `.complete` 三行元数据 + 回读校验
    let marker = format!("{path}{COMPLETE_SUFFIX}");
    let meta = fs::read_to_string(&marker).unwrap();
    assert_eq!(meta, encode_metadata(&play_url));
    assert_eq!(decode_metadata(&meta).as_deref(), Some(play_url.as_str()));
    // 旧版本与 tmp 已清理，仅剩 1 数据 + 1 标记
    let names: Vec<String> = super::read_dir_entries(&dir)
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert_eq!(names.len(), 2, "目录应只剩新文件与标记: {names:?}");
    assert!(audio_cache_query(book_url, 0, "hello", "第一章"));
    assert_eq!(audio_cache_list(book_url), vec![0]);
    // 幂等：二次调用不再发请求
    let out2 =
        audio_cache_download_with_client(&test_client(), book_url, 0, "hello", "第一章", &play_url)
            .unwrap();
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&out2).unwrap()["status"],
        "already_cached"
    );
    assert_eq!(hits.load(Ordering::SeqCst), 1, "已缓存不得重下");

    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// 失败清理：HTTP 非 2xx / 空体 / 流中断后不留残file
#[test]
fn download_failures_leave_no_residue() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("download-fail");
    set_test_root(&root);
    let book_url = "https://a.com/book/dl-fail";
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );
    let dir = book_dir(book_url);

    // HTTP 500 → 网络请求失败(500)
    let (port_500, _) = spawn_server(|_i| ServerReply {
        status: 500,
        content_type: "text/plain",
        body: b"boom".to_vec(),
        declared_len: None,
    });
    let err = audio_cache_download_with_client(
        &test_client(),
        book_url,
        0,
        "hello",
        "第一章",
        &format!("http://127.0.0.1:{port_500}/x.mp3"),
    )
    .unwrap_err()
    .to_string();
    assert!(err.contains("网络请求失败(500)"), "err={err}");

    // 空体（Content-Length: 0）→ 音频文件为空
    let (port_empty, _) = spawn_server(|_i| ServerReply::ok("audio/mpeg", Vec::new()));
    let err = audio_cache_download_with_client(
        &test_client(),
        book_url,
        0,
        "hello",
        "第一章",
        &format!("http://127.0.0.1:{port_empty}/x.mp3"),
    )
    .unwrap_err()
    .to_string();
    assert!(err.contains("音频文件为空"), "err={err}");

    // 声明 100 但只发 10（连接关闭）→ 读流失败，且无任何残file
    let (port_short, _) = spawn_server(|_i| ServerReply {
        status: 200,
        content_type: "audio/mpeg",
        body: vec![1u8; 10],
        declared_len: Some(100),
    });
    let err = audio_cache_download_with_client(
        &test_client(),
        book_url,
        0,
        "hello",
        "第一章",
        &format!("http://127.0.0.1:{port_short}/x.mp3"),
    )
    .unwrap_err()
    .to_string();
    assert!(!err.is_empty());

    // 三次失败后目录不得有任何残留（tmp/数据/标记）
    let names: Vec<String> = super::read_dir_entries(&dir)
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert!(names.is_empty(), "失败后不得残留文件: {names:?}");
    assert!(!audio_cache_query(book_url, 0, "hello", "第一章"));

    // 纯函数 size 校验分支（流中断以外的「不完整」判据）
    assert!(
        require_complete_size(0, None)
            .unwrap_err()
            .to_string()
            .contains("音频文件为空")
    );
    assert!(
        require_complete_size(10, Some(100))
            .unwrap_err()
            .to_string()
            .contains("音频文件不完整")
    );
    assert!(require_complete_size(100, Some(100)).is_ok());
    assert!(require_complete_size(10, None).is_ok());

    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// 取消：无在途返回 false；在途置位后流式拷贝中止并清理
#[test]
fn cancel_aborts_inflight_download() {
    use std::io::Read as _;
    use std::io::Write as _;
    use std::net::TcpListener;

    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("download-cancel");
    set_test_root(&root);

    // 慢速服务器：每 30ms 发 32KB，共 64 块（≈2MB）——足够长以观测取消
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    std::thread::spawn(move || {
        for stream in listener.incoming() {
            let Ok(mut sock) = stream else { continue };
            let mut head = Vec::new();
            let mut b = [0u8; 1];
            while let Ok(1) = sock.read(&mut b) {
                head.push(b[0]);
                if head.ends_with(b"\r\n\r\n") {
                    break;
                }
            }
            let total = 64 * 32 * 1024u64;
            let _ = sock.write_all(
                format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nContent-Length: {total}\r\nConnection: close\r\n\r\n"
                )
                .as_bytes(),
            );
            let chunk = vec![9u8; 32 * 1024];
            for _ in 0..64 {
                if sock.write_all(&chunk).is_err() {
                    break;
                }
                let _ = sock.flush();
                std::thread::sleep(Duration::from_millis(30));
            }
            let _ = sock.shutdown(std::net::Shutdown::Both);
        }
    });

    // 无在途 → false（本测试持 TEST_LOCK，其他下载测试不会并发在途）
    assert!(!audio_cache_cancel().unwrap(), "无在途下载应返回 false");

    let book_url = "https://a.com/book/dl-cancel";
    let play_url = format!("http://127.0.0.1:{port}/slow.mp3");
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );
    let dir = book_dir(book_url);
    let worker = std::thread::spawn(move || {
        let client = test_client();
        audio_cache_download_with_client(&client, book_url, 0, "hello", "第一章", &play_url)
    });

    // 等待在途登记（下载线程在发起网络前即 +1）
    let mut waited_ms = 0u32;
    while test_engine().media().active_audio() == 0 && waited_ms < 3000 {
        std::thread::sleep(Duration::from_millis(10));
        waited_ms += 10;
    }
    assert_eq!(test_engine().media().active_audio(), 1, "在途计数应为 1");
    std::thread::sleep(Duration::from_millis(120));

    assert!(audio_cache_cancel().unwrap(), "置位时应快照到在途下载");
    let err = worker.join().unwrap().unwrap_err().to_string();
    assert!(err.contains("音频缓存下载已取消"), "err={err}");

    // 部分文件必须清理（无 tmp、无数据、无标记）
    let names: Vec<String> = super::read_dir_entries(&dir)
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert!(names.is_empty(), "取消后不得残留部分文件: {names:?}");
    assert_eq!(test_engine().media().active_audio(), 0, "在途计数应复位");

    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// P1-1：同 `(bookUrl, key16)` 并发下载被分片锁串行化——恰好一个
/// `installed`、一个 `already_cached`，最终缓存真实存在且可被读面命中，
/// 无残留 tmp。修复前：两任务各自越过幂等检查（慢速服务器拉长窗口）互删
/// 产物，双 `installed` 且第二个请求重下（hits=2）。
#[test]
fn concurrent_same_key_downloads_are_serialized() {
    use std::io::Read as _;
    use std::io::Write as _;
    use std::net::TcpListener;

    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("download-concurrent");
    set_test_root(&root);

    // 慢速服务器：32KB/块 × 64 块、每块 24ms（≈1.5s）——修复前第二个任务
    // 在第一个安装完成前即越过幂等检查并独立下载（互删对方 tmp/已装文件）；
    // 修复后第二个任务阻塞在分片锁上，解锁后幂等命中，全程仅 1 个请求
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let hits = std::sync::Arc::new(AtomicUsize::new(0));
    let hits_srv = std::sync::Arc::clone(&hits);
    std::thread::spawn(move || {
        for stream in listener.incoming() {
            let Ok(mut sock) = stream else { continue };
            hits_srv.fetch_add(1, Ordering::SeqCst);
            let mut head = Vec::new();
            let mut b = [0u8; 1];
            while let Ok(1) = sock.read(&mut b) {
                head.push(b[0]);
                if head.ends_with(b"\r\n\r\n") {
                    break;
                }
            }
            let total = 64 * 32 * 1024u64;
            let _ = sock.write_all(
                format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nContent-Length: {total}\r\nConnection: close\r\n\r\n"
                )
                .as_bytes(),
            );
            let chunk = vec![5u8; 32 * 1024];
            for _ in 0..64 {
                if sock.write_all(&chunk).is_err() {
                    break;
                }
                let _ = sock.flush();
                std::thread::sleep(Duration::from_millis(24));
            }
            let _ = sock.shutdown(std::net::Shutdown::Both);
        }
    });

    let book_url = "https://a.com/book/dl-concurrent";
    let play_url = format!("http://127.0.0.1:{port}/same.mp3");
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );

    // 两个线程同时对同一 (bookUrl, 章节 key) 发起下载
    let handles: Vec<_> = (0..2)
        .map(|_| {
            let play = play_url.clone();
            std::thread::spawn(move || {
                let client = test_client();
                audio_cache_download_with_client(&client, book_url, 0, "hello", "第一章", &play)
            })
        })
        .collect();
    let results: Vec<LegadoResult<String>> =
        handles.into_iter().map(|h| h.join().unwrap()).collect();

    let mut statuses = Vec::new();
    let mut paths = Vec::new();
    for r in &results {
        let out = r.as_ref().expect("并发下载均应成功返回");
        let json: serde_json::Value = serde_json::from_str(out).unwrap();
        statuses.push(json["status"].as_str().unwrap().to_string());
        paths.push(json["path"].as_str().unwrap().to_string());
    }
    statuses.sort();
    assert_eq!(
        statuses,
        vec!["already_cached", "installed"],
        "同 key 并发应收敛为一次实装 + 一次幂等命中（修复前为双 installed）"
    );
    assert_eq!(
        hits.load(Ordering::SeqCst),
        1,
        "第二个任务应在锁内幂等命中，不得重复发请求"
    );
    // 实装结果与幂等命中指向同一份文件，且文件真实存在
    assert_eq!(paths[0], paths[1], "already_cached 应指向 installed 的文件");
    assert!(
        std::path::Path::new(&paths[0]).exists(),
        "installed 返回的 path 必须真实存在（修复前可能已被对方清理）"
    );
    // 缓存可被读面命中（无静默丢失），无残留 tmp
    assert!(audio_cache_query(book_url, 0, "hello", "第一章"));
    assert_eq!(audio_cache_list(book_url), vec![0]);
    let names: Vec<String> = super::read_dir_entries(&book_dir(book_url))
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert_eq!(
        names.len(),
        2,
        "并发结束后目录应只剩 1 数据 + 1 标记: {names:?}"
    );
    assert!(
        names.iter().all(|n| !n.ends_with(PART_SUFFIX)),
        "不得残留 tmp: {names:?}"
    );

    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// 任务一（清理面取锁）：下载在途时清理同章必须**等待下载完成**再删
/// （对齐原版 `removeCachedChapter:92-105` 的 suspend + `chapterLock`
/// `withLock`），两者结果自洽：下载 `installed`，清理随后删除其安装产物
/// （返回 1），读面转为未命中，目录无残留 tmp/标记。
///
/// 修复前（清理不取锁，实测取证）：清理在下载流式写入期间删除在写
/// tmp（计数含 tmp 返回 1），下载随后安装 rename 失败报错 NotFound
/// ——两者互删不自洽（红）；加锁后清理等比等待，下载完整安装后清理
/// 再删除（绿）。
#[test]
fn clear_chapter_waits_inflight_download_and_wins() {
    use std::io::Read as _;
    use std::io::Write as _;
    use std::net::TcpListener;

    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let _db = ensure_test_db();
    let root = unique_root("clear-concurrent");
    set_test_root(&root);

    // 慢速服务器：32KB/块 × 64 块、每块 24ms（≈1.5s）——给清理一个
    // 确定的「下载持锁在途」窗口
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    std::thread::spawn(move || {
        for stream in listener.incoming() {
            let Ok(mut sock) = stream else { continue };
            let mut head = Vec::new();
            let mut b = [0u8; 1];
            while let Ok(1) = sock.read(&mut b) {
                head.push(b[0]);
                if head.ends_with(b"\r\n\r\n") {
                    break;
                }
            }
            let total = 64 * 32 * 1024u64;
            let _ = sock.write_all(
                format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: audio/mpeg\r\nContent-Length: {total}\r\nConnection: close\r\n\r\n"
                )
                .as_bytes(),
            );
            let chunk = vec![3u8; 32 * 1024];
            for _ in 0..64 {
                if sock.write_all(&chunk).is_err() {
                    break;
                }
                let _ = sock.flush();
                std::thread::sleep(Duration::from_millis(24));
            }
            let _ = sock.shutdown(std::net::Shutdown::Both);
        }
    });

    let book_url = "https://a.com/book/dl-clear-concurrent";
    let play_url = format!("http://127.0.0.1:{port}/slow.mp3");
    insert_audio_book(
        book_url,
        "https://source.example/audio",
        "hello",
        "第一章",
        false,
    );

    let play = play_url.clone();
    let worker = std::thread::spawn(move || {
        let client = test_client();
        audio_cache_download_with_client(&client, book_url, 0, "hello", "第一章", &play)
    });

    // 等待在途登记：下载在锁内、发起网络前 +1 → 此刻锁已被下载持有
    let mut waited_ms = 0u32;
    while test_engine().media().active_audio() == 0 && waited_ms < 3000 {
        std::thread::sleep(Duration::from_millis(10));
        waited_ms += 10;
    }
    assert_eq!(test_engine().media().active_audio(), 1, "下载应在途持锁");
    std::thread::sleep(Duration::from_millis(100));

    // 清理在分片锁上等待下载完成，随后删除其安装产物（返回数据文件数 1）
    let removed = audio_cache_clear_chapter(book_url, 0, "hello", "第一章");
    let out = worker.join().unwrap().expect("在途下载应成功完成");
    let json: serde_json::Value = serde_json::from_str(&out).unwrap();
    assert_eq!(json["status"].as_str().unwrap(), "installed");
    assert_eq!(
        removed, 1,
        "清理应删除下载安装的 1 个数据文件（.complete 标记照删不计）"
    );
    assert!(
        !audio_cache_query(book_url, 0, "hello", "第一章"),
        "清理后读面应未命中（无互删残留）"
    );
    assert!(audio_cache_list(book_url).is_empty());
    let names: Vec<String> = super::read_dir_entries(&book_dir(book_url))
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert!(names.is_empty(), "清理后不得残留 tmp/数据/标记: {names:?}");

    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}

/// P2-5 残态取证：目录仅剩孤儿 `.complete`（无同名数据文件）时，
/// `audio_cache_clear_chapter` 按冻结口径返回 `0`（仅统计数据文件），
/// 但标记照删——对齐原版 `removeCacheFiles:338-356`（标记照删）与
/// `hasCacheFiles:374-383`（含标记 → 原版 UI 报「已清除本章缓存」）。
/// Dart 提示由返回值 0 驱动 → 与原文案相反，已登记待裁决。
#[test]
fn clear_chapter_removes_orphan_marker_with_zero_count() {
    let _lock = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let root = unique_root("clear-orphan-marker");
    set_test_root(&root);
    let dir = book_dir("https://a.com/book/orphan");
    let name = valid_name(1, KEY_HELLO, "mp3");
    fs::create_dir_all(&dir).unwrap();
    fs::write(dir.join(format!("{name}{COMPLETE_SUFFIX}")), b"1\nx\nx").unwrap();

    assert_eq!(
        audio_cache_clear_chapter("https://a.com/book/orphan", 1, "hello", "第一章"),
        0,
        "冻结口径：返回值只统计数据文件（不含标记）"
    );
    assert!(
        !dir.join(format!("{name}{COMPLETE_SUFFIX}")).exists(),
        "孤儿标记应被删除（对齐原版 removeCacheFiles 标记照删）"
    );
    clear_test_root();
    let _ = fs::remove_dir_all(&root);
}
