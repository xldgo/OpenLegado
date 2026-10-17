//! 服务测试复用真实本地HTTP响应；不访问外网或进程宿主状态。
use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::{Arc, mpsc};
use std::time::{Duration, Instant};

pub(super) struct Fixture {
    pub url: String,
    pub requests: tokio::sync::mpsc::UnboundedReceiver<String>,
    pub release: mpsc::Sender<()>,
    pub worker: std::thread::JoinHandle<()>,
}
impl Fixture {
    pub fn new(
        count: usize,
        blocked: bool,
        body: impl Fn(&str) -> String + Send + Sync + 'static,
    ) -> Self {
        Self::with_content_type(count, blocked, "text/html; charset=utf-8", body)
    }
    pub fn with_content_type(
        count: usize,
        blocked: bool,
        content_type: &'static str,
        body: impl Fn(&str) -> String + Send + Sync + 'static,
    ) -> Self {
        Self::with_response_headers(count, blocked, content_type, &[], body)
    }
    pub fn with_response_headers(
        count: usize,
        blocked: bool,
        content_type: &'static str,
        headers: &[(&str, &str)],
        body: impl Fn(&str) -> String + Send + Sync + 'static,
    ) -> Self {
        let response_headers = headers
            .iter()
            .map(|(key, value)| format!("{key}: {value}\r\n"))
            .collect::<String>();
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        listener.set_nonblocking(true).unwrap();
        let (request, requests) = tokio::sync::mpsc::unbounded_channel();
        let (release, gate) = mpsc::channel();
        let body = Arc::new(body);
        let worker = std::thread::spawn(move || {
            for _ in 0..count {
                let deadline = Instant::now() + Duration::from_secs(10);
                let mut socket = loop {
                    match listener.accept() {
                        Ok((socket, _)) => break socket,
                        Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                            assert!(Instant::now() < deadline, "没有收到预期 HTTP 请求");
                            std::thread::sleep(Duration::from_millis(2));
                        }
                        Err(error) => panic!("HTTP 监听失败: {error}"),
                    }
                };
                socket.set_nonblocking(false).unwrap();
                socket
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                let mut data = Vec::new();
                let mut byte = [0];
                while !data.ends_with(b"\r\n\r\n") {
                    assert_eq!(socket.read(&mut byte).unwrap(), 1);
                    data.push(byte[0]);
                    assert!(data.len() < 16384);
                }
                let headers = String::from_utf8(data.clone()).unwrap();
                let body_length = headers
                    .lines()
                    .filter_map(|line| line.split_once(':'))
                    .find(|(name, _)| name.eq_ignore_ascii_case("content-length"))
                    .map(|(_, value)| value.trim().parse::<usize>().unwrap())
                    .unwrap_or(0);
                assert!(body_length <= 16384, "夹具请求体超出上限");
                let mut request_body = vec![0; body_length];
                socket.read_exact(&mut request_body).unwrap();
                data.extend_from_slice(&request_body);
                let data = String::from_utf8(data).unwrap();
                let response = body(&data);
                let _ = request.send(data);
                if blocked {
                    gate.recv_timeout(Duration::from_secs(10)).unwrap();
                }
                // 取消异步 HTTP future 后对端可以已经断开。
                let _ = write!(
                    socket,
                    "HTTP/1.1 200 OK\r\n{response_headers}Content-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{response}",
                    response.len()
                );
            }
        });
        Self {
            url,
            requests,
            release,
            worker,
        }
    }
    pub async fn request(&mut self) -> String {
        tokio::time::timeout(Duration::from_secs(5), self.requests.recv())
            .await
            .unwrap()
            .unwrap()
    }
}
