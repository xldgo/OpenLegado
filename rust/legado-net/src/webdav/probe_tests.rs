//! 只读探测使用真实本地HTTP，不访问外网或书籍数据。
use super::*;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

async fn request_headers(socket: &mut TcpStream) -> String {
    let mut bytes = Vec::new();
    while !bytes.ends_with(b"\r\n\r\n") {
        bytes.push(socket.read_u8().await.unwrap());
        assert!(bytes.len() < 16384);
    }
    String::from_utf8(bytes).unwrap()
}

fn config(url: String) -> WebDavConfig {
    WebDavConfig {
        url,
        username: "user".into(),
        password: " pass ".into(),
        remote_dir: "/must-not-be-created/".into(),
    }
}

#[tokio::test]
async fn probe_classifies_http_without_reading_body_or_accessing_sync_directory() {
    use WebDavProbeStatus::*;
    let cases = [
        (200, Success),
        (207, Success),
        (401, AuthenticationFailed),
        (403, AuthenticationFailed),
        (500, HttpFailed),
        (204, HttpFailed),
    ];
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/dav", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        let mut requests = Vec::new();
        for (code, _) in cases {
            let (mut socket, _) = listener.accept().await.unwrap();
            requests.push(request_headers(&mut socket).await);
            // 故意不发送声明的正文：测试配置只需响应头，不应等待XML或下载错误正文。
            socket
                .write_all(
                    format!(
                        "HTTP/1.1 {code} Test\r\nContent-Length: 1024\r\nConnection: close\r\n\r\n"
                    )
                    .as_bytes(),
                )
                .await
                .unwrap();
        }
        requests
    });
    for (index, (code, status)) in cases.into_iter().enumerate() {
        let mut config = config(url.clone());
        if index == 0 {
            config.username.clear();
            config.password.clear();
        }
        assert_eq!(
            WebDavClient::new(config).probe().await,
            WebDavProbeResult {
                status,
                status_code: Some(code)
            }
        );
    }
    let requests = server.await.unwrap();
    for (index, request) in requests.iter().enumerate() {
        assert!(
            request.starts_with("PROPFIND /dav HTTP/1.1\r\n"),
            "{request}"
        );
        let headers = request.to_ascii_lowercase();
        assert!(headers.contains("\r\ndepth: 0\r\n"));
        if index == 0 {
            assert!(!headers.contains("authorization:"));
        } else {
            assert!(request.contains("Basic dXNlcjogcGFzcyA="), "{request}");
        }
    }
}

#[tokio::test]
async fn probe_times_out_when_server_never_returns_headers() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    let (release, wait) = tokio::sync::oneshot::channel::<()>();
    let server = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        request_headers(&mut socket).await;
        let _ = wait.await;
    });
    let result = tokio::time::timeout(
        Duration::from_secs(7),
        WebDavClient::new(config(url)).probe(),
    )
    .await
    .unwrap();
    assert_eq!(
        result,
        WebDavProbeResult {
            status: WebDavProbeStatus::TimedOut,
            status_code: None
        }
    );
    let _ = release.send(());
    server.await.unwrap();
}

#[tokio::test]
async fn probe_distinguishes_invalid_address_from_transport_failure() {
    for url in ["dav.example.com", "http://", "file:///tmp/dav"] {
        assert_eq!(
            WebDavClient::new(config(url.into())).probe().await.status,
            WebDavProbeStatus::InvalidUrl
        );
    }
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        request_headers(&mut socket).await;
        // 请求已到达但响应前断开，不伪造成HTTP错误或认证失败。
    });
    assert_eq!(
        WebDavClient::new(config(url)).probe().await,
        WebDavProbeResult {
            status: WebDavProbeStatus::NetworkFailed,
            status_code: None
        }
    );
    server.await.unwrap();
}

#[tokio::test]
async fn mutations_check_http_failures_and_mkdir_accepts_existing_collection() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let client = WebDavClient::new(config(format!("http://{}", listener.local_addr().unwrap())));
    let server = tokio::spawn(async move {
        for (method, code) in ["MKCOL", "DELETE"]
            .into_iter()
            .flat_map(|method| [201, 405, 401, 500].map(|code| (method, code)))
        {
            let (mut socket, _) = listener.accept().await.unwrap();
            let request = request_headers(&mut socket).await;
            assert!(request.starts_with(&format!("{method} ")));
            socket
                .write_all(
                    format!(
                        "HTTP/1.1 {code} Test\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    )
                    .as_bytes(),
                )
                .await
                .unwrap();
        }
    });
    for expected in [true, true, false, false] {
        assert_eq!(client.mkdir("nested").await.is_ok(), expected);
    }
    for expected in [true, false, false, false] {
        assert_eq!(client.delete("old.zip").await.is_ok(), expected);
    }
    server.await.unwrap();
}
