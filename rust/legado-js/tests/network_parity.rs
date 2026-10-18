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

#[derive(Default)]
struct BatchMetrics {
    active: AtomicUsize,
    peak: AtomicUsize,
    cancelled: AtomicUsize,
}

struct Server {
    address: SocketAddr,
    stopped: Arc<AtomicBool>,
    requests: Arc<AtomicUsize>,
    worker: Option<JoinHandle<()>>,
    metrics: Arc<BatchMetrics>,
}

impl Server {
    fn new(address: &str) -> Self {
        let listener = TcpListener::bind(address).expect("绑定回环HTTP服务");
        let address = listener.local_addr().unwrap();
        listener.set_nonblocking(true).unwrap();
        let stopped = Arc::new(AtomicBool::new(false));
        let requests = Arc::new(AtomicUsize::new(0));
        let metrics = Arc::new(BatchMetrics::default());
        let observed = metrics.clone();
        let stop = stopped.clone();
        let count = requests.clone();
        let worker = std::thread::spawn(move || {
            let mut workers = Vec::new();
            while !stop.load(Ordering::Acquire) {
                match listener.accept() {
                    Ok((socket, _)) => {
                        let count = count.clone();
                        let metrics = observed.clone();
                        workers.push(std::thread::spawn(move || serve(socket, &count, &metrics)));
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
            metrics,
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

fn serve(mut socket: TcpStream, requests: &AtomicUsize, metrics: &BatchMetrics) {
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
    let request_number = requests.fetch_add(1, Ordering::AcqRel) + 1;
    if path == "/pending" {
        let _ =
            socket.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n");
        let mut probe = [0];
        let result = socket.read(&mut probe);
        if matches!(result, Ok(0))
            || result.as_ref().is_err_and(|error| {
                matches!(
                    error.kind(),
                    std::io::ErrorKind::ConnectionReset | std::io::ErrorKind::ConnectionAborted
                )
            })
        {
            metrics.cancelled.fetch_add(1, Ordering::AcqRel);
        }
        return;
    }
    if path == "/batch-error" {
        let deadline = std::time::Instant::now() + Duration::from_secs(2);
        while requests.load(Ordering::Acquire) < 4 && std::time::Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(2));
        }
        return;
    }
    if path.starts_with("/batch/") {
        let active = metrics.active.fetch_add(1, Ordering::AcqRel) + 1;
        metrics.peak.fetch_max(active, Ordering::AcqRel);
        let delay = path.rsplit('/').next().unwrap().parse::<u64>().unwrap();
        std::thread::sleep(Duration::from_millis(delay));
        metrics.active.fetch_sub(1, Ordering::AcqRel);
    }
    if path == "/disconnect" {
        return;
    }
    if path.starts_with("/gbk") {
        let text = if path == "/gbk-meta" {
            "<meta charset=gbk>中文"
        } else {
            "中文"
        };
        let (bytes, _, _) = encoding_rs::GBK.encode(text);
        let content_type = if path == "/gbk-header" {
            "text/plain; charset=gbk"
        } else if path == "/gbk-explicit" {
            "text/plain; charset=utf-8"
        } else {
            "text/html"
        };
        let head = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            bytes.len()
        );
        let _ = socket.write_all(head.as_bytes());
        let _ = socket.write_all(&bytes);
        return;
    }
    let body = if path == "/slow" {
        std::thread::sleep(Duration::from_millis(1200));
        "SLOW-OK".to_string()
    } else {
        serde_json::json!({"method":method,"path":path,"body":String::from_utf8(body).unwrap(),
            "marker":header("X-Marker"),"contentType":header("Content-Type"),
            "markerCount":head.lines().filter(|line| line.split_once(':').is_some_and(|(key,_)| key.eq_ignore_ascii_case("X-Marker"))).count()})
        .to_string()
    };
    let status = if path == "/redirect" {
        "302 Found"
    } else if path == "/retry" && request_number < 3 {
        "503 Service Unavailable"
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
    // URL 规则统一交给 AnalyzeUrl：未声明 Content-Type 的正文作表单编码。
    assert_eq!(response["body"], "%E7%94%B2%E4%B9%99");
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

#[test]
fn ajax_and_connect_share_rule_options_and_request_encoding() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for call in ["java.ajax(rule)", "java.connect(rule).body()"] {
        let script = format!(
            r#"var rule=url+',{{"method":"POST","body":"q=中文","charset":"gbk","headers":{{"X-Marker":"rule"}}}}'; {call}"#
        );
        let response = eval(&engine, &server.url("/echo"), &script);
        let response: serde_json::Value =
            serde_json::from_str(&response).expect("两入口都应得到正文JSON");
        assert_eq!(response["method"], "POST");
        assert_eq!(response["body"], "q=%D6%D0%CE%C4");
        assert_eq!(response["marker"], "rule");
    }
}

#[test]
fn current_vm_globals_and_nested_result_are_preserved() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        globalThis.result='外层结果';globalThis.makePath=function(){return '/echo';};
        var rule='@js: globalThis.nestedSeen = result; url';
        var body=java.ajax(rule);
        JSON.stringify([JSON.parse(body).method,result,typeof makePath,nestedSeen]);
    "#,
    );
    assert_eq!(
        response,
        "[\"GET\",\"外层结果\",\"function\",\"@js: globalThis.nestedSeen = result; url\"]"
    );
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var rule=url+',{"js":"java.ajax(url); result"}';
        var response=java.connect(rule);
        JSON.stringify([response.code(),result]);
    "#,
    );
    assert_eq!(response, "[200,\"外层结果\"]");
}

#[test]
fn rule_headers_override_case_insensitively_before_body_encoding() {
    use legado_js::host_api::current_source::with_current_source_tag;
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = with_current_source_tag(&server.url("/"), || {
        eval(
            &engine,
            &server.url("/echo"),
            r#"
        java.putGlobalHeaders(JSON.stringify({'X-Marker':'source','CONTENT-TYPE':'text/plain'}));
        var rule=url+',{"method":"POST","body":"中文","headers":{"x-marker":"rule"}}';
        java.connect(rule,{'X-MARKER':'explicit'}).body();
        "#,
        )
    });
    let body: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(
        body["body"], "中文",
        "初始 Content-Type 必须在表单编码判定前参与解析"
    );
    assert_eq!(body["marker"], "rule");
    assert_eq!(body["markerCount"], 1, "大小写不同的同名头不得重复发送");
    assert_eq!(body["contentType"], "text/plain");
    let response = with_current_source_tag(&server.url("/"), || {
        eval(
            &engine,
            &server.url("/echo"),
            "java.connect(url,{'X-MARKER':'explicit'}).body()",
        )
    });
    let body: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(body["marker"], "explicit");
    assert_eq!(body["markerCount"], 1);
}

#[test]
fn dynamic_content_type_prevents_stale_form_encoding() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var rule=url+','+JSON.stringify({method:'POST',body:'中文',
            js:"java.headerMapPut('CONTENT-TYPE','text/plain'); result"});
        java.connect(rule).body();
    "#,
    );
    let body: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(body["body"], "中文");
    assert_eq!(body["contentType"], "text/plain");
}

#[test]
fn relative_templates_and_response_scripts_use_the_existing_vm() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/"),
        r#"
        globalThis.baseUrl=url; globalThis.result='外层';
        globalThis.makePath=function(){return '/echo';};
        var rule='{{makePath()}},{"bodyJs":"JSON.parse(result).path + java.getCurrentUrl()"}';
        var body=java.ajax(rule);
        JSON.stringify([body,baseUrl,result]);
    "#,
    );
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(response[0], format!("/echo{}", server.url("/echo")));
    assert_eq!(response[1], server.url("/"));
    assert_eq!(response[2], "外层");
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var body=java.ajax('@js: throw new Error("规则错误")');
        JSON.stringify([body.indexOf('规则错误')>=0,result,java.ajax(url).length>0]);
    "#,
    );
    assert_eq!(response, "[true,\"外层\",true]");
}

#[test]
fn nested_requests_restore_outer_url_headers_and_result_even_on_failure() {
    use legado_parser::analyze_url::{
        current_url, push_pending_request_header, set_current_url, take_pending_request_headers,
    };
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    set_current_url(Some("https://outer.example/".to_string()));
    push_pending_request_header("X-Outside".to_string(), "saved".to_string());
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        globalThis.result='原始结果';
        globalThis.failureRule='@js: throw new Error("inner failed")';
        var script="java.headerMapPut('X-Marker','outer');" +
            "java.ajax(url + ',{\"js\":\"java.headerMapPut(\\\"X-Marker\\\",\\\"inner\\\"); result\"}');" +
            "java.ajax(failureRule);" +
            "if(java.getCurrentUrl() !== url) throw new Error('外层 URL 丢失'); result";
        var rule=url+','+JSON.stringify({js:script});
        var response=java.connect(rule);
        JSON.stringify([response.body(),result]);
    "#,
    );
    let restored_url = current_url();
    let restored_headers = take_pending_request_headers();
    set_current_url(None);
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    let body: serde_json::Value = serde_json::from_str(response[0].as_str().unwrap())
        .unwrap_or_else(|error| panic!("响应不是正文 JSON：{error}；{response}"));
    assert_eq!(body["marker"], "outer");
    assert_eq!(response[1], "原始结果");
    assert_eq!(restored_url.as_deref(), Some("https://outer.example/"));
    assert_eq!(
        restored_headers,
        vec![("X-Outside".to_string(), "saved".to_string())]
    );
}

#[test]
fn rule_response_charset_redirect_retry_and_hex_options_are_applied() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for call in ["java.ajax(rule)", "java.connect(rule).body()"] {
        for (path, options, expected) in [
            ("/gbk-header", "{}", "中文"),
            ("/gbk-meta", "{}", "<meta charset=gbk>中文"),
            ("/gbk-explicit", r#"{"charset":"gbk"}"#, "中文"),
            ("/gbk-header", r#"{"type":"hex"}"#, "d6d0cec4"),
        ] {
            let response = eval(
                &engine,
                &server.url(path),
                &format!(
                    "var rule=url+','+{}; {call}",
                    serde_json::to_string(options).unwrap()
                ),
            );
            assert_eq!(response, expected, "{path} {call}");
        }
    }
    let response = eval(
        &engine,
        &server.url("/redirect"),
        r#"
        var r=java.connect(url+',{"followRedirects":false}');
        var followed=java.connect(url);
        JSON.stringify([r.code(),r.raw().header('Location'),JSON.parse(followed.body()).path]);
    "#,
    );
    assert_eq!(response, "[302,\"/echo\",\"/echo\"]");
    let server = Server::new("127.0.0.1:0");
    assert_eq!(
        eval(
            &engine,
            &server.url("/retry"),
            r#"java.connect(url+',{"retry":2}').code()"#
        ),
        "200"
    );
    assert_eq!(server.requests.load(Ordering::Acquire), 3);
}

#[test]
fn rule_timeout_is_used_unless_explicitly_overridden_and_unsupported_options_fail() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/slow"),
        r#"java.ajax(url+',{"timeout_ms":50}')"#,
    );
    assert!(
        response.contains("[ERROR]") && response.contains("Timeout"),
        "{response}"
    );
    for options in [
        r#"{"webView":true}"#,
        r#"{"dnsIp":"127.0.0.1"}"#,
        r#"{"proxy":"http://127.0.0.1:1"}"#,
    ] {
        let response = eval(
            &engine,
            &server.url("/echo"),
            &format!(
                "java.ajax(url+','+{})",
                serde_json::to_string(options).unwrap()
            ),
        );
        assert!(response.contains("暂不支持"), "{response}");
    }
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        1,
        "不支持的网络策略不得退化为普通HTTP请求"
    );
}

#[test]
fn batch_requests_return_ordered_response_objects_and_preserve_duplicates() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var rows=java.ajaxAll([url,url]);
        JSON.stringify([Array.isArray(rows),rows.length,
            rows.map(function(r){return [r.code(),JSON.parse(r.body()).path,r.raw().request().url(),r.callTime()>=0];})]);
    "#,
    );
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(response[0], true, "必须是JS响应数组，不能是JSON字符串");
    assert_eq!(response[1], 2);
    for item in response[2].as_array().unwrap() {
        assert_eq!(
            item,
            &serde_json::json!([200, "/echo", server.url("/echo"), true])
        );
    }
}

#[test]
fn batch_probe_uses_timeout_and_returns_diagnostics_without_aborting_other_items() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/"),
        r#"
        var rows=java.ajaxTestAll([url+'slow',url+'echo'],50,true);
        JSON.stringify(rows.map(function(r){return [r.code(),r.body(),r.callTime()];}));
    "#,
    );
    let response: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(response[0][0], 200, "失败保留上游合成StrResponse语义");
    assert!(response[0][1].as_str().unwrap().contains("Timeout"));
    assert_eq!(response[0][2], -1);
    assert_eq!(response[1][0], 200);
    assert!(response[1][2].as_i64().unwrap() >= 0);
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(response[1][1].as_str().unwrap()).unwrap()["path"],
        "/echo"
    );
}

#[test]
fn batch_results_keep_input_order_despite_completion_order_with_bounded_parallelism() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/"),
        r#"
        var paths=['batch/0/120','batch/1/20','batch/2/20','batch/3/20','batch/4/20','batch/5/20'];
        JSON.stringify(java.ajaxAll(paths.map(function(path){return url+path;}))
            .map(function(r){return JSON.parse(r.body()).path;}));
    "#,
    );
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).unwrap(),
        serde_json::json!([
            "/batch/0/120",
            "/batch/1/20",
            "/batch/2/20",
            "/batch/3/20",
            "/batch/4/20",
            "/batch/5/20"
        ])
    );
    let peak = server.metrics.peak.load(Ordering::Acquire);
    assert!(peak > 1 && peak <= 4, "必须实际并发且不超过4：{peak}");
}

#[test]
fn batch_failure_cancels_inflight_bodies_and_does_not_start_the_whole_queue() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/"),
        r#"
        var paths=['pending','pending','pending','batch-error','echo','echo','echo','echo','echo','echo'];
        (function(){try{java.ajaxAll(paths.map(function(path){return url+path;}));return '错误被吞';}
            catch(e){return String(e);}})();
    "#,
    );
    assert!(response.contains("批量请求[3]"), "{response}");
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while server.metrics.cancelled.load(Ordering::Acquire) < 3
        && std::time::Instant::now() < deadline
    {
        std::thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        4,
        "未启动队列不得在失败后继续请求"
    );
    assert_eq!(
        server.metrics.cancelled.load(Ordering::Acquire),
        3,
        "在途正文的TCP连接必须实际释放"
    );
    assert_eq!(
        eval(&engine, &server.url("/echo"), "java.connect(url).code()"),
        "200",
        "失败后VM与连接池继续可用"
    );
}

#[test]
fn batch_dynamic_rules_and_response_scripts_restore_bindings_between_awaits() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/"),
        r#"
        globalThis.result='外层'; globalThis.baseUrl=url;
        var first=url+'batch/0/80,'+JSON.stringify({js:'result',bodyJs:'JSON.parse(result).path'});
        var second=url+'{{result === "外层" ? "echo" : "leaked"}},'+JSON.stringify({bodyJs:'JSON.parse(result).path'});
        var rows=java.ajaxAll([first,second]);
        JSON.stringify([rows.map(function(r){return r.body();}),result,baseUrl]);
    "#,
    );
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).unwrap(),
        serde_json::json!([["/batch/0/80", "/echo"], "外层", server.url("/")])
    );
}

#[test]
fn batch_probe_zero_overrides_rule_timeout_and_negative_timeout_prevents_network_io() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = eval(
        &engine,
        &server.url("/slow"),
        r#"
        var rule=url+',{"timeout_ms":20}';
        var rows=java.ajaxTestAll([rule],0);
        JSON.stringify([rows[0].body(),rows[0].callTime()>=0]);
    "#,
    );
    assert_eq!(response, "[\"SLOW-OK\",true]");
    let before = server.requests.load(Ordering::Acquire);
    assert_eq!(
        eval(
            &engine,
            &server.url("/echo"),
            r#"
        (function(){try{java.ajaxTestAll([url],-1);return false;}catch(e){return true;}})()
    "#
        ),
        "true"
    );
    assert_eq!(server.requests.load(Ordering::Acquire), before);
    for timeout in ["null", "undefined"] {
        assert_eq!(
            eval(
                &engine,
                &server.url("/echo"),
                &format!("java.ajaxTestAll([url],{timeout})[0].code()")
            ),
            "200"
        );
    }
}

#[test]
fn batch_bridge_reinjection_keeps_response_methods_available() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    for _ in 0..2 {
        engine
            .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
            .unwrap();
    }
    for call in ["java.ajaxAll([url])", "java.ajaxTestAll([url],1000)"] {
        assert_eq!(
            eval(
                &engine,
                &server.url("/echo"),
                &format!(
                    "var rows={call};JSON.stringify([rows[0].code(),JSON.parse(rows[0].body()).path]);"
                )
            ),
            "[200,\"/echo\"]"
        );
    }
}

#[test]
fn batch_rules_share_post_encoding_and_the_original_source_header_snapshot() {
    use legado_js::host_api::current_source::with_current_source_tag;
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let response = with_current_source_tag(&server.url("/"), || {
        eval(
            &engine,
            &server.url("/echo"),
            r#"
        java.putGlobalHeaders(JSON.stringify({'X-Marker':'before'}));
        var options={method:'POST',body:'q=中文',charset:'gbk',
            js:"java.putGlobalHeaders(JSON.stringify({'X-Marker':'after'})); result"};
        var rule=url+','+JSON.stringify(options);
        JSON.stringify(java.ajaxAll([rule,rule]).map(function(r){return JSON.parse(r.body());}));
    "#,
        )
    });
    let rows: serde_json::Value = serde_json::from_str(&response).unwrap();
    for row in rows.as_array().unwrap() {
        assert_eq!(row["method"], "POST");
        assert_eq!(row["body"], "q=%D6%D0%CE%C4");
        assert_eq!(row["marker"], "before");
    }
}
