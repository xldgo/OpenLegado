//! 独立网络入口保留底层错误，且不改变协议请求与失败分类。

use std::{error::Error, time::Duration};

use legado_core::LegadoError;
use legado_net::{
    direct_link_upload::{DirectLinkUploader, UploadRule},
    remote_book::{RemoteBook, RemoteBookManager},
    rule_update_client::{RuleSubscription, fetch_subscription},
    webdav::{WebDavClient, WebDavConfig},
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
    task::JoinHandle,
};

#[derive(Clone, Copy, Debug)]
enum Operation {
    DavList,
    DavGet,
    DavPut,
    DavDelete,
    DavMkdir,
    DavConditionalPut,
    BookList,
    BookGet,
    BookPut,
    BookDelete,
    Subscription,
    Upload,
}

fn webdav(url: &str) -> WebDavClient {
    WebDavClient::new(WebDavConfig {
        url: url.to_owned(),
        username: "user".into(),
        password: "pass".into(),
        remote_dir: String::new(),
    })
}

fn network_message(error: LegadoError) -> String {
    match error {
        LegadoError::Network(message) => message,
        other => panic!("WebDAV 必须保持 Network 分类: {other:?}"),
    }
}

impl Operation {
    async fn run(self, url: &str) -> Result<(), String> {
        match self {
            Self::DavList => webdav(url)
                .list_dir("")
                .await
                .map(|_| ())
                .map_err(network_message),
            Self::DavGet => webdav(url)
                .get("")
                .await
                .map(|_| ())
                .map_err(network_message),
            Self::DavPut => webdav(url).put("", b"book").await.map_err(network_message),
            Self::DavDelete => webdav(url).delete("").await.map_err(network_message),
            Self::DavMkdir => webdav(url).mkdir("").await.map_err(network_message),
            Self::DavConditionalPut => webdav(url)
                .conditional_put("", b"book", Some("etag"))
                .await
                .map(|_| ())
                .map_err(network_message),
            Self::BookList => RemoteBookManager::new(url, "user", "pass")
                .get_remote_book_list(url)
                .await
                .map(|_| ()),
            Self::BookGet => RemoteBookManager::new(url, "user", "pass")
                .download_remote_book(&RemoteBook::from_file_info("book.txt", url, 128, None))
                .await
                .map(|_| ()),
            Self::BookPut => RemoteBookManager::new(url, "user", "pass")
                .upload_book(b"book", "book.txt")
                .await
                .map(|_| ()),
            Self::BookDelete => {
                RemoteBookManager::new(url, "user", "pass")
                    .delete_remote_book(url)
                    .await
            }
            Self::Subscription => fetch_subscription(&RuleSubscription {
                url: format!("{url}#requestWithoutUA"),
                name: "本机订阅".into(),
                sub_type: "bookSource".into(),
            })
            .await
            .map(|_| ()),
            Self::Upload => DirectLinkUploader::upload(
                &UploadRule {
                    upload_url: url.into(),
                    download_url_rule: "$.url".into(),
                    summary: String::new(),
                    compress: false,
                    expiry_date: 0,
                },
                "book",
            )
            .await
            .map(|_| ()),
        }
    }

    fn method(self) -> &'static str {
        match self {
            Self::DavList | Self::BookList => "PROPFIND",
            Self::DavGet | Self::BookGet | Self::Subscription => "GET",
            Self::DavPut | Self::DavConditionalPut | Self::BookPut => "PUT",
            Self::DavDelete | Self::BookDelete => "DELETE",
            Self::DavMkdir => "MKCOL",
            Self::Upload => "POST",
        }
    }

    fn prefix(self, url: &str, body_failure: bool) -> String {
        match self {
            Self::BookList if !body_failure => "PROPFIND 请求失败: ".into(),
            Self::BookGet if !body_failure => "下载失败: ".into(),
            Self::BookPut => "上传失败: ".into(),
            Self::BookDelete => "删除失败: ".into(),
            Self::Subscription if body_failure => "读取订阅响应失败: ".into(),
            Self::Subscription => format!("请求订阅失败 [{url}#requestWithoutUA]: "),
            _ => String::new(),
        }
    }
}

fn request_header<'a>(request: &'a str, name: &str) -> Option<&'a str> {
    request.lines().find_map(|line| {
        let (key, value) = line.split_once(':')?;
        key.eq_ignore_ascii_case(name).then(|| value.trim())
    })
}

async fn response_fixture(
    count: usize,
    response: &'static [u8],
) -> (String, JoinHandle<Vec<String>>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        let mut requests = Vec::new();
        for _ in 0..count {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut header = Vec::new();
            while !header.ends_with(b"\r\n\r\n") {
                header.push(socket.read_u8().await.unwrap());
                assert!(header.len() < 16384);
            }
            let header = String::from_utf8(header).unwrap();
            let length = request_header(&header, "Content-Length")
                .map(|value| value.parse::<usize>().unwrap())
                .unwrap_or(0);
            let mut body = vec![0; length];
            socket.read_exact(&mut body).await.unwrap();
            socket.write_all(response).await.unwrap();
            socket.shutdown().await.unwrap();
            requests.push(header);
        }
        requests
    });
    (url, server)
}

async fn assert_protocol_causes(operations: &[Operation], body_failure: bool) {
    // 第一条为原始 reqwest 的来源链参照，其余为正式协议入口。
    let response: &[u8] = if body_failure {
        b"HTTP/1.1 200 OK\r\nContent-Length: 128\r\nConnection: close\r\n\r\npartial"
    } else {
        b""
    };
    let (url, server) = response_fixture(operations.len() + 1, response).await;

    let raw_result = legado_net::tls::client_builder()
        .no_proxy()
        .timeout(Duration::from_secs(3))
        .build()
        .unwrap()
        .get(&url)
        .send()
        .await;
    let raw_error = if body_failure {
        raw_result.unwrap().bytes().await.unwrap_err()
    } else {
        raw_result.unwrap_err()
    };
    let mut cause: &dyn Error = &raw_error;
    while let Some(source) = cause.source() {
        cause = source;
    }
    let root = cause.to_string();
    assert!(!root.is_empty());
    assert_ne!(root, raw_error.to_string(), "夹具必须触发底层原因");

    let mut failures = Vec::new();
    for operation in operations {
        let message = operation.run(&url).await.expect_err("网络失败不能变成成功");
        assert!(
            message.starts_with(&operation.prefix(&url, body_failure)),
            "错误前缀改变: {operation:?}: {message}"
        );
        if !message.contains(&root) {
            failures.push(format!("{operation:?}: {message}"));
        }
    }
    let requests = server.await.unwrap();
    for (operation, request) in operations.iter().zip(requests.iter().skip(1)) {
        assert!(request.starts_with(&format!("{} ", operation.method())));
        if matches!(operation, Operation::Subscription | Operation::Upload) {
            assert_eq!(request_header(request, "Authorization"), None);
        } else {
            assert_eq!(
                request_header(request, "Authorization"),
                Some("Basic dXNlcjpwYXNz")
            );
        }
        if matches!(operation, Operation::Subscription) {
            assert_eq!(request_header(request, "User-Agent"), Some("null"));
        }
        if matches!(operation, Operation::DavConditionalPut) {
            assert_eq!(request_header(request, "If-Match"), Some("etag"));
        }
    }
    assert!(
        failures.is_empty(),
        "应保留底层原因 {root:?}: {failures:#?}"
    );
}

#[tokio::test]
async fn webdav_status_and_metadata_fallback_stay_unchanged() {
    tokio::time::timeout(Duration::from_secs(10), async {
        let (url, server) = response_fixture(
            1,
            b"HTTP/1.1 412 Precondition Failed\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
        )
        .await;
        assert!(
            !webdav(&url)
                .conditional_put("", b"book", Some("etag"))
                .await
                .unwrap()
        );
        server.await.unwrap();

        let (url, server) = response_fixture(
            1,
            b"HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
        )
        .await;
        assert_eq!(
            network_message(webdav(&url).put("", b"book").await.unwrap_err()),
            "WebDAV PUT 失败: HTTP 401 Unauthorized"
        );
        server.await.unwrap();

        let (url, server) = response_fixture(
            1,
            b"HTTP/1.1 200 OK\r\nContent-Length: 128\r\nConnection: close\r\n\r\npartial",
        )
        .await;
        assert_eq!(webdav(&url).get_file_info("").await, None);
        server.await.unwrap();
    })
    .await
    .expect("WebDAV 失败策略回归超时");
}

#[tokio::test]
async fn protocol_body_errors_preserve_causes() {
    tokio::time::timeout(
        Duration::from_secs(15),
        assert_protocol_causes(
            &[
                Operation::DavList,
                Operation::DavGet,
                Operation::BookList,
                Operation::BookGet,
                Operation::Subscription,
                Operation::Upload,
            ],
            true,
        ),
    )
    .await
    .expect("协议正文回归超时");
}

#[tokio::test]
async fn protocol_request_errors_preserve_causes() {
    tokio::time::timeout(
        Duration::from_secs(15),
        assert_protocol_causes(
            &[
                Operation::DavList,
                Operation::DavGet,
                Operation::DavPut,
                Operation::DavDelete,
                Operation::DavMkdir,
                Operation::DavConditionalPut,
                Operation::BookList,
                Operation::BookGet,
                Operation::BookPut,
                Operation::BookDelete,
                Operation::Subscription,
                Operation::Upload,
            ],
            false,
        ),
    )
    .await
    .expect("协议发送回归超时");
}
