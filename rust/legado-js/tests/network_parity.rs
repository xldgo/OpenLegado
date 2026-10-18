//! 参考版 JsExtensions 的请求级超时、请求内容和重定向行为回归。
//! 使用真实 QuickJS 与有界本地 HTTP 服务，不依赖外网或 Flutter DLL。
#![cfg(feature = "quickjs")]

use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::sync::{
    Arc,
    atomic::{AtomicBool, AtomicUsize, Ordering},
};
use std::thread::JoinHandle;
use std::time::Duration;

use legado_js::QuickJsEngine;
use legado_js::engine::{JsEngine, JsValue};
use legado_js::sandbox::SandboxConfig;

struct Server {
    address: SocketAddr,
    stopped: Arc<AtomicBool>,
    requests: Arc<AtomicUsize>,
    worker: Option<JoinHandle<()>>,
}

impl Server {
    fn new(address: &str) -> Self {
        let listener = TcpListener::bind(address).expect("绑定回环HTTP服务");
        let address = listener.local_addr().unwrap();
        listener.set_nonblocking(true).unwrap();
        let stopped = Arc::new(AtomicBool::new(false));
        let requests = Arc::new(AtomicUsize::new(0));
        let stop = stopped.clone();
        let count = requests.clone();
        let worker = std::thread::spawn(move || {
            let mut workers = Vec::new();
            while !stop.load(Ordering::Acquire) {
                match listener.accept() {
                    Ok((socket, _)) => {
                        let count = count.clone();
                        workers.push(std::thread::spawn(move || serve(socket, &count)));
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        std::thread::sleep(Duration::from_millis(2));
                    }
                    Err(e) => panic!("HTTP服务接收失败：{e}"),
                }
            }
            for worker in workers {
                worker.join().unwrap();
            }
        });
        Self {
            address,
            stopped,
            requests,
            worker: Some(worker),
        }
    }

    fn url(&self, path: &str) -> String {
        format!("http://{}{path}", self.address)
    }
}

impl Drop for Server {
    fn drop(&mut self) {
        self.stopped.store(true, Ordering::Release);
        self.worker.take().unwrap().join().unwrap();
    }
}

fn serve(mut socket: TcpStream, requests: &AtomicUsize) {
    // Windows接受的socket可继承监听器的非阻塞模式；读完整HTTP请求前显式恢复阻塞。
    socket.set_nonblocking(false).unwrap();
    socket
        .set_read_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    socket
        .set_write_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    let mut head = Vec::new();
    let mut byte = [0];
    while !head.ends_with(b"\r\n\r\n") {
        if socket.read_exact(&mut byte).is_err() {
            return;
        }
        head.push(byte[0]);
        assert!(head.len() < 65536);
    }
    let head = String::from_utf8(head).unwrap();
    let first = head.lines().next().unwrap();
    let mut parts = first.split_whitespace();
    let method = parts.next().unwrap();
    let path = parts.next().unwrap();
    let header = |name: &str| {
        head.lines()
            .filter_map(|line| line.split_once(':'))
            .find(|(key, _)| key.eq_ignore_ascii_case(name))
            .map(|(_, value)| value.trim())
    };
    let length = header("Content-Length")
        .unwrap_or("0")
        .parse::<usize>()
        .unwrap();
    assert!(length < 1024 * 1024);
    let mut body = vec![0; length];
    if socket.read_exact(&mut body).is_err() {
        return;
    }
    requests.fetch_add(1, Ordering::AcqRel);
    if path == "/disconnect" {
        return;
    }
    let body = if path == "/slow" {
        std::thread::sleep(Duration::from_millis(1200));
        "SLOW-OK".to_string()
    } else {
        serde_json::json!({"method":method,"body":String::from_utf8(body).unwrap(),
            "marker":header("X-Marker"),"contentType":header("Content-Type")})
        .to_string()
    };
    let status = if path == "/redirect" {
        "302 Found"
    } else {
        "200 OK"
    };
    let location = if path == "/redirect" {
        "Location: /echo\r\n"
    } else {
        ""
    };
    let response = format!(
        "HTTP/1.1 {status}\r\n{location}Content-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        if method == "HEAD" { "" } else { &body }
    );
    // 超时后客户端已关闭连接；这属于测试的预期路径。
    let _ = socket.write_all(response.as_bytes());
}

fn engine() -> QuickJsEngine {
    QuickJsEngine::new(SandboxConfig::default().with_allow_script_run(true)).unwrap()
}

fn eval(engine: &QuickJsEngine, url: &str, script: &str) -> String {
    engine
        .eval_with_bindings(script, &[("url", JsValue::String(url.to_string()))])
        .unwrap()
}

fn check_timeout(method: &str) {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let call = if method == "post" {
        "java.post(url,'正文',{ 'X-Marker':'timeout' },300)".to_string()
    } else {
        format!("java.{method}(url,{{'X-Marker':'timeout'}},300)")
    };
    let response = eval(
        &engine,
        &server.url("/slow"),
        &format!(
            "(function(){{try{{return JSON.stringify({{code:{call}.statusCode()}});}}catch(e){{return JSON.stringify({{error:String(e)}});}}}})()"
        ),
    );
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        1,
        "慢请求必须真正到达服务端"
    );
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert!(
        response["error"]
            .as_str()
            .is_some_and(|s| s.contains("Timeout")),
        "{method}必须抛出包含超时原因的异常，实际：{response}"
    );
    let code = eval(
        &engine,
        &server.url("/echo"),
        &format!("{call}.statusCode()"),
    );
    assert_eq!(code, "200", "超时后同一引擎和连接池应继续可用");
}

#[test]
fn get_honors_request_timeout() {
    check_timeout("get");
}
#[test]
fn head_honors_request_timeout() {
    check_timeout("head");
}
#[test]
fn post_honors_request_timeout() {
    check_timeout("post");
}

#[test]
fn requests_keep_body_headers_redirects_and_variable_lookup() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for method in ["get", "head", "post"] {
        let args = if method == "post" {
            "url,'甲乙',{'X-Marker':'kept'}"
        } else {
            "url,{'X-Marker':'kept'}"
        };
        for suffix in ["", ",null", ",undefined", ",5000", ",0"] {
            let response = eval(
                &engine,
                &server.url("/echo"),
                &format!(
                    "var r=java.{method}({args}{suffix});JSON.stringify({{code:r.statusCode(),body:r.body()}})"
                ),
            );
            let response: serde_json::Value = serde_json::from_str(&response).unwrap();
            assert_eq!(response["code"], 200, "{method} {suffix}");
            if method != "head" {
                let body: serde_json::Value =
                    serde_json::from_str(response["body"].as_str().unwrap()).unwrap();
                assert_eq!(body["method"], method.to_uppercase());
                assert_eq!(body["marker"], "kept");
                if method == "post" {
                    assert_eq!(body["body"], "甲乙");
                    assert_eq!(body["contentType"], "application/x-www-form-urlencoded");
                }
            }
        }
        assert_eq!(
            eval(
                &engine,
                &server.url("/redirect"),
                &format!(
                    "var r=java.{method}({args},5000);JSON.stringify([r.statusCode(),r.header('Location')])"
                )
            ),
            "[302,\"/echo\"]"
        );
    }
    assert_eq!(
        eval(
            &engine,
            "",
            "java.put('parity-key','变量');java.get('parity-key')"
        ),
        "变量"
    );
}

#[test]
fn invalid_jsoup_timeouts_fail_before_network_io() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for method in ["get", "head", "post"] {
        let args = if method == "post" {
            "url,'body',{}"
        } else {
            "url,{}"
        };
        for timeout in ["-1", "2147483648"] {
            let result = eval(
                &engine,
                &server.url("/echo"),
                &format!(
                    "(function(){{try{{java.{method}({args},{timeout});return '未拒绝';}}catch(e){{return '已拒绝';}}}})()"
                ),
            );
            assert_eq!(result, "已拒绝", "{method}应拒绝非法超时{timeout}");
        }
    }
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        0,
        "非法超时不得发出请求"
    );
}

#[test]
fn ipv6_loopback_requests_work_without_proxy() {
    let server = Server::new("[::1]:0");
    let engine = engine();
    assert_eq!(
        eval(
            &engine,
            &server.url("/echo"),
            "java.get(url,{}).statusCode()"
        ),
        "200"
    );
}

#[test]
fn ajax_options_and_connect_headers_keep_their_wire_values() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"java.ajax(url + ',{"method":"POST","body":"甲乙","headers":{"X-Marker":"ajax"}}')"#,
    );
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(response["method"], "POST");
    assert_eq!(response["body"], "甲乙");
    assert_eq!(response["marker"], "ajax");
    for header in [r#"'{"X-Marker":"connect"}'"#, r#"{'X-Marker':'connect'}"#] {
        let response = eval(
            &engine,
            &server.url("/echo"),
            &format!(
                "var r=java.connect(url,{header},5000);JSON.stringify([r.code(),JSON.parse(r.body()).marker])"
            ),
        );
        assert_eq!(response, "[200,\"connect\"]");
    }
}

#[test]
fn network_failures_keep_each_entrypoints_error_contract() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for method in ["get", "head", "post"] {
        let args = if method == "post" {
            "url,'内容',{}"
        } else {
            "url,{}"
        };
        let response = eval(
            &engine,
            &server.url("/disconnect"),
            &format!(
                "(function(){{try{{java.{method}({args});return '错误被吞';}}catch(e){{return String(e);}}}})()"
            ),
        );
        assert!(
            response.contains("connectNR request error"),
            "{method}错误原因丢失：{response}"
        );
    }
    let response = eval(&engine, &server.url("/disconnect"), "java.ajax(url)");
    assert!(
        response.contains("[ERROR]") && response.contains("ajax request error"),
        "{response}"
    );
    let response = eval(
        &engine,
        &server.url("/disconnect"),
        "var r=java.connect(url);JSON.stringify({body:r.body(),code:r.code(),url:r.raw().request().url()})",
    );
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(response["code"], 200, "遵循上游错误StrResponse的合成状态");
    assert!(
        response["body"]
            .as_str()
            .unwrap()
            .contains("connect request error"),
        "{response}"
    );
    assert_eq!(response["url"], server.url("/disconnect"));
    assert_eq!(
        eval(&engine, &server.url("/echo"), "java.connect(url).code()"),
        "200"
    );
}

#[test]
fn connect_rejects_invalid_timeout_without_sending_requests() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for timeout in ["-1", "2147483648"] {
        let response = eval(
            &engine,
            &server.url("/echo"),
            &format!("java.connect(url,'{{}}',{timeout}).body()"),
        );
        assert!(
            response.contains("[ERROR]") && response.contains("callTimeout"),
            "{response}"
        );
    }
    assert_eq!(server.requests.load(Ordering::Acquire), 0);
}

#[test]
fn explicit_zero_timeout_overrides_rule_budget() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/slow"),
        r#"java.ajax(url + ',{"timeout_ms":50}',0)"#,
    );
    assert_eq!(response, "SLOW-OK", "显式0必须覆盖规则内的50ms期限");
    assert_eq!(
        eval(
            &engine,
            &server.url("/slow"),
            "java.connect(url,'{}',0).body()"
        ),
        "SLOW-OK"
    );
}

#[test]
fn boxed_call_timeouts_keep_nullable_and_strict_number_inputs() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for timeout in ["'1000'", "NaN", "Infinity", "true"] {
        for call in [
            format!("java.ajax(url,{timeout})"),
            format!("java.connect(url,null,{timeout})"),
        ] {
            let result = eval(
                &engine,
                &server.url("/echo"),
                &format!("(function(){{try{{{call};return false;}}catch(e){{return true;}}}})()"),
            );
            assert_eq!(result, "true", "非法装箱超时不得被转换：{call}");
        }
    }
    assert_eq!(server.requests.load(Ordering::Acquire), 0);
    for timeout in ["null", "undefined", "5000"] {
        assert_eq!(
            eval(
                &engine,
                &server.url("/echo"),
                &format!("java.connect(url,null,{timeout}).code()")
            ),
            "200"
        );
    }
}
