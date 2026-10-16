//! 不同抓取实例使用相同 URL 时，HTML、书籍和章节关系不能串入另一实例。

use super::*;

fn fresh_deps() -> FetcherDeps {
    FetcherDeps::new(
        LegadoClient::new(legado_net::LegadoClientConfig {
            no_proxy: true,
            ..Default::default()
        })
        .unwrap(),
    )
}

fn chapter(index: i32, url: &str) -> WebChapter {
    WebChapter {
        index,
        title: format!("第{index}章"),
        url: url.into(),
        is_vip: false,
        is_volume: false,
        variable: None,
        word_count: None,
    }
}

#[test]
fn same_engine_sources_with_same_book_url_keep_their_own_metadata() {
    let deps = fresh_deps();
    let book = "https://shared.test/book";
    let current = "https://shared.test/chapter";
    for (source, name, author) in [
        ("source-a", "甲书", "作者甲"),
        ("source-b", "乙书", "作者乙"),
    ] {
        record_chapter_list_cache(
            &deps,
            book,
            source,
            "",
            name,
            author,
            &[chapter(0, current)],
        );
    }
    let a = lookup_book_meta_for_chapter(&deps.web_book, "source-a", current).unwrap();
    let b = lookup_book_meta_for_chapter(&deps.web_book, "source-b", current).unwrap();
    assert_eq!(a.name, "甲书");
    assert_eq!(a.author, "作者甲");
    assert_eq!(b.name, "乙书");
    assert_eq!(b.author, "作者乙");
    assert!(lookup_book_meta_for_chapter(&deps.web_book, "source-c", current).is_none());
}

#[cfg(feature = "quickjs")]
#[tokio::test]
async fn actual_content_requests_resolve_metadata_from_their_own_source() {
    use std::io::{Read, Write};
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let url = format!("http://{}/shared/chapter", listener.local_addr().unwrap());
    let book_url = "https://shared-content.test/book";
    let fixture = std::thread::spawn(move || {
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(10);
        for _ in 0..2 {
            let (mut stream, _) = loop {
                match listener.accept() {
                    Ok(accepted) => break accepted,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(std::time::Instant::now() < deadline, "正文请求未到达夹具");
                        std::thread::sleep(std::time::Duration::from_millis(5));
                    }
                    Err(error) => panic!("接受正文请求失败: {error}"),
                }
            };
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(std::time::Duration::from_secs(3)))
                .unwrap();
            let mut request = Vec::new();
            let mut chunk = [0; 1024];
            while !request.windows(4).any(|window| window == b"\r\n\r\n") {
                let size = stream.read(&mut chunk).unwrap();
                assert!(size > 0);
                request.extend_from_slice(&chunk[..size]);
            }
            stream
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 4\r\nConnection: close\r\n\r\nbody")
                .unwrap();
        }
    });
    let deps = fresh_deps();
    let chapter = chapter(0, &url);
    let sources: Vec<BookSource> = [
        ("source-a", "book-a", "author-a", "variable-a"),
        ("source-b", "book-b", "author-b", "variable-b"),
    ]
    .into_iter()
    .map(|(source_url, name, author, variable)| {
        let source = BookSource {
            book_source_url: source_url.to_string(),
            rule_content: Some(legado_core::models::rule::ContentRule {
                content: Some(
                    "@js:book.name + '|' + book.author + '|' + book.getVariable('key')".to_string(),
                ),
                ..Default::default()
            }),
            ..Default::default()
        };
        record_book_meta_from_info(
            &deps,
            source_url,
            book_url,
            &WebBookInfo {
                name: name.to_string(),
                author: author.to_string(),
                book_url: book_url.to_string(),
                toc_url: String::new(),
                cover_url: None,
                intro: None,
                categories: Vec::new(),
                last_chapter: None,
                word_count: None,
                kind: None,
                variable: Some(serde_json::json!({"key":variable}).to_string()),
                book_type: 8,
            },
        );
        // 目录本次没有新书名/变量时，只合并本来源的已有详情。
        record_chapter_list_cache(
            &deps,
            book_url,
            source_url,
            "",
            "",
            "",
            std::slice::from_ref(&chapter),
        );
        source
    })
    .collect();
    let fetcher = RealBookSourceFetcher::with_deps(deps);
    assert_eq!(
        fetcher.get_content(&sources[0], &chapter).await.unwrap(),
        "book-a|author-a|variable-a"
    );
    assert_eq!(
        fetcher.get_content(&sources[1], &chapter).await.unwrap(),
        "book-b|author-b|variable-b"
    );
    fixture.join().unwrap();
}

#[test]
fn same_book_and_chapter_keys_keep_independent_metadata_and_next_pages() {
    let one = fresh_deps();
    let two = fresh_deps();
    let book = "https://same.test/book";
    let source = "https://same.test";
    let current = "https://same.test/chapter";
    record_chapter_list_cache(
        &one,
        book,
        source,
        "",
        "第一实例",
        "作者甲",
        &[chapter(0, current), chapter(1, "https://same.test/next-a")],
    );
    record_chapter_list_cache(
        &two,
        book,
        source,
        "",
        "第二实例",
        "作者乙",
        &[chapter(0, current), chapter(1, "https://same.test/next-b")],
    );
    assert_eq!(
        lookup_book_meta_for_chapter(&one.web_book, source, current)
            .unwrap()
            .name,
        "第一实例"
    );
    assert_eq!(
        lookup_book_meta_for_chapter(&two.web_book, source, current)
            .unwrap()
            .author,
        "作者乙"
    );
    assert_eq!(
        lookup_next_chapter_url(&one.web_book, source, current).as_deref(),
        Some("https://same.test/next-a")
    );
    assert_eq!(
        lookup_next_chapter_url(&two.web_book, source, current).as_deref(),
        Some("https://same.test/next-b")
    );
    assert!(lookup_book_meta_for_chapter(&one.web_book, "other-source", current).is_none());
}

#[test]
fn cloned_dependencies_share_cache_but_independent_dependencies_do_not() {
    let first = fresh_deps();
    let same = first.clone();
    let other = fresh_deps();
    cache_put_page_body(&first.web_book, "same-url", "只属于第一实例");
    assert_eq!(
        cache_get_page_body(&same.web_book, "same-url").as_deref(),
        Some("只属于第一实例")
    );
    assert!(cache_get_page_body(&other.web_book, "same-url").is_none());
    let weak = Arc::downgrade(&first.web_book);
    drop(first);
    assert!(weak.upgrade().is_some());
    drop(same);
    assert!(
        weak.upgrade().is_none(),
        "没有进程级缓存槽位继续持有已释放实例"
    );
}

#[test]
fn refresh_generation_only_changes_the_owning_instance() {
    let first = fresh_deps();
    let second = fresh_deps();
    let same = first.clone();
    bump_toc_fetch_epoch(&first.web_book);
    assert_eq!(current_toc_fetch_epoch(&same.web_book), 1);
    assert_eq!(current_toc_fetch_epoch(&second.web_book), 0);
}

#[tokio::test]
async fn same_url_fetches_distinct_bodies_and_reuses_only_its_own_cache() {
    use std::io::{Read, Write};
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}/same", listener.local_addr().unwrap());
    let fixture = std::thread::spawn(move || {
        for body in ["tenant-a", "tenant-b"] {
            let (mut stream, _) = listener.accept().unwrap();
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(std::time::Duration::from_secs(5)))
                .unwrap();
            let mut head = Vec::new();
            let mut buffer = [0; 1024];
            while !head.windows(4).any(|part| part == b"\r\n\r\n") {
                let count = stream.read(&mut buffer).unwrap();
                assert!(count > 0);
                head.extend_from_slice(&buffer[..count]);
            }
            let response = format!(
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            );
            stream.write_all(response.as_bytes()).unwrap();
        }
    });
    let one = RealBookSourceFetcher::with_deps(fresh_deps());
    let same = RealBookSourceFetcher::with_deps(one.deps().clone());
    let two = RealBookSourceFetcher::with_deps(fresh_deps());
    assert_eq!(
        one.fetch_simple_cached(&url, None, true).await.unwrap(),
        "tenant-a"
    );
    assert_eq!(
        two.fetch_simple_cached(&url, None, true).await.unwrap(),
        "tenant-b"
    );
    fixture.join().unwrap();
    // 源站已关闭，后续相同实例的成功返回必须来自各自缓存。
    assert_eq!(
        same.fetch_simple_cached(&url, None, true).await.unwrap(),
        "tenant-a"
    );
    assert_eq!(
        two.fetch_simple_cached(&url, None, true).await.unwrap(),
        "tenant-b"
    );
}

#[cfg(feature = "quickjs")]
#[test]
fn login_check_retry_uses_same_resource_without_cross_instance_vm_state() {
    let source = BookSource {
        book_source_url: "https://login-retry.test".into(),
        login_check_js: Some("globalThis.passes = (globalThis.passes || 0) + 1; passes === 1 ? false : ({code:200, body:'pass-' + passes})".into()),
        ..Default::default()
    };
    for _ in 0..2 {
        let deps = fresh_deps();
        let response = RealBookSourceFetcher::execute_login_check(
            &deps.js,
            &source,
            "initial",
            "https://login-retry.test/page",
            200,
        )
        .unwrap();
        assert_eq!(response.body, "pass-2");
    }
}

#[test]
fn real_toc_page_cache_is_partitioned_by_source_and_request_headers() {
    use std::{
        io::{Read, Write},
        time::{Duration, Instant},
    };
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let url = format!("http://{}/shared", listener.local_addr().unwrap());
    let fixture = std::thread::spawn(move || {
        let deadline = Instant::now() + Duration::from_secs(10);
        for body in ["source-a", "source-b", "new-auth"] {
            let (mut stream, _) = loop {
                match listener.accept() {
                    Ok(value) => break value,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "来源或请求头变化时必须真实抓取");
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(error) => panic!("夹具失败: {error}"),
                }
            };
            stream.set_nonblocking(false).unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut bytes = Vec::new();
            let mut chunk = [0; 1024];
            while !bytes.windows(4).any(|b| b == b"\r\n\r\n") {
                let n = stream.read(&mut chunk).unwrap();
                assert!(n > 0);
                bytes.extend_from_slice(&chunk[..n]);
            }
            write!(
                stream,
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            )
            .unwrap();
        }
    });
    let root = fresh_deps();
    let a = RealBookSourceFetcher::with_deps(root.for_source("toc", "source-a", &url));
    let b = RealBookSourceFetcher::with_deps(root.for_source("toc", "source-b", &url));
    crate::test_support::block_on(async {
        assert_eq!(
            a.fetch_toc_page_optional(&url, None)
                .await
                .unwrap()
                .as_deref(),
            Some("source-a")
        );
        assert_eq!(
            b.fetch_toc_page_optional(&url, None)
                .await
                .unwrap()
                .as_deref(),
            Some("source-b")
        );
        assert_eq!(
            a.fetch_toc_page_optional(&url, None)
                .await
                .unwrap()
                .as_deref(),
            Some("source-a")
        );
        let changed = HashMap::from([("Authorization".into(), "updated".into())]);
        assert_eq!(
            a.fetch_toc_page_optional(&url, Some(&changed))
                .await
                .unwrap()
                .as_deref(),
            Some("new-auth")
        );
        assert_eq!(
            a.fetch_toc_page_optional(&url, None)
                .await
                .unwrap()
                .as_deref(),
            Some("source-a")
        );
    });
    fixture.join().unwrap();
}
