//! 开库前的 FFI 抓取缓存应延续至开库后，并由内嵌 Web 服务复用。

use std::io::{Read, Write};
use std::time::Duration;

use legado_ffi::{
    api::{server_api, web_book},
    ffi::ffi::db_open,
    http_state, runtime,
};
use legado_net::LegadoClientConfig;
use serde_json::{Value, json};

struct StopServer;

impl Drop for StopServer {
    fn drop(&mut self) {
        server_api::server_stop();
    }
}

fn serve_pages(
    listener: std::net::TcpListener,
    body: String,
    count: usize,
) -> std::thread::JoinHandle<()> {
    std::thread::spawn(move || {
        for _ in 0..count {
            let (mut stream, _) = listener.accept().unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 1024];
            while !request.windows(4).any(|part| part == b"\r\n\r\n") {
                let count = stream.read(&mut buffer).unwrap();
                assert!(count > 0);
                request.extend_from_slice(&buffer[..count]);
            }
            write!(stream,
                "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            ).unwrap();
        }
    })
}

#[test]
fn early_ffi_cache_survives_database_open_and_is_reused_by_web() {
    http_state::reset_shared_client_with_config(LegadoClientConfig {
        no_proxy: true,
        ..Default::default()
    })
    .unwrap();

    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let origin = format!("http://{}", listener.local_addr().unwrap());
    let book_url = format!("{origin}/book");
    let more = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let more_url = format!("http://{}/more", more.local_addr().unwrap());
    let source = json!({
        "bookSourceUrl": origin,
        "bookSourceName": "跨宿主缓存夹具",
        "ruleBookInfo": {"name": "tag.h1@text"},
        "ruleToc": {
            "chapterList": "class.chapter",
            "chapterName": "text",
            "chapterUrl": "href",
            "nextTocUrl": "class.next@href"
        }
    });
    let source_json = source.to_string();
    // 首抓页保留原有每次请求的策略；仅 nextTocUrl 后续页走短时缓存。
    let primary = serve_pages(
        listener,
        format!(
            "<h1>缓存测试书</h1><a class=\"chapter\" href=\"{origin}/one\">第一章</a><a class=\"next\" href=\"{more_url}\">下一页</a>"
        ),
        3,
    );
    let cached = serve_pages(
        more,
        format!("<a class=\"chapter\" href=\"{origin}/two\">第二章</a>"),
        1,
    );

    let early: Value =
        serde_json::from_str(&web_book::webbook_chapters(&source_json, &book_url, "", "").unwrap())
            .unwrap();
    assert_eq!(early.as_array().unwrap().len(), 2);
    cached.join().unwrap();
    // 分页源站已关闭，后续完整目录必须来自本实例开库前保存的分页 HTML。
    db_open(":memory:".into()).unwrap();
    let after: Value =
        serde_json::from_str(&web_book::webbook_chapters(&source_json, &book_url, "", "").unwrap())
            .unwrap();
    assert_eq!(after, early);

    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    drop(listener);
    let _stop = StopServer;
    server_api::server_start(port).unwrap();
    runtime::block_on(async {
        let control = legado_net::tls::client_builder()
            .no_proxy()
            .timeout(Duration::from_secs(5))
            .build()
            .unwrap();
        let response = control
            .post(format!("http://127.0.0.1:{port}/api/webbook/chapters"))
            .json(&json!({"source": source, "book_url": book_url}))
            .send()
            .await
            .unwrap();
        let status = response.status();
        let body = response.text().await.unwrap();
        assert!(status.is_success(), "Web 复用缓存失败：{status} {body}");
        let chapters: Value = serde_json::from_str(&body).unwrap();
        assert_eq!(chapters["chapters"], early);
        assert_eq!(chapters["total"], 2);
    });
    primary.join().unwrap();
}
