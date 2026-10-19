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

/// 最小本地v4代理只转发一个GET；生产代码使用reqwest，不共享此测试实现。
fn socks4_fixture(
    target: SocketAddr,
    reject: bool,
) -> (SocketAddr, JoinHandle<std::io::Result<()>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    listener.set_nonblocking(true).unwrap();
    let worker = std::thread::spawn(move || {
        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        let mut socket = loop {
            match listener.accept() {
                Ok((socket, _)) => break socket,
                Err(e)
                    if e.kind() == std::io::ErrorKind::WouldBlock
                        && std::time::Instant::now() < deadline =>
                {
                    std::thread::sleep(Duration::from_millis(2))
                }
                Err(e) => return Err(e),
            }
        };
        socket.set_nonblocking(false)?;
        socket.set_read_timeout(Some(Duration::from_secs(2)))?;
        socket.set_write_timeout(Some(Duration::from_secs(2)))?;
        let mut request = [0; 9];
        socket.read_exact(&mut request)?;
        assert_eq!(&request[..2], &[4, 1], "必须发送真正的SOCKS4 CONNECT");
        assert_eq!(u16::from_be_bytes([request[2], request[3]]), target.port());
        assert_eq!(&request[4..8], &[127, 0, 0, 1]);
        assert_eq!(request[8], 0, "当前通道发送空USERID");
        socket.write_all(&[0, if reject { 91 } else { 90 }, 0, 0, 0, 0, 0, 0])?;
        if !reject {
            let mut upstream = TcpStream::connect_timeout(&target, Duration::from_secs(2))?;
            upstream.set_read_timeout(Some(Duration::from_secs(2)))?;
            upstream.set_write_timeout(Some(Duration::from_secs(2)))?;
            let mut head = Vec::new();
            while !head.ends_with(b"\r\n\r\n") {
                let mut byte = [0];
                socket.read_exact(&mut byte)?;
                head.push(byte[0]);
                assert!(head.len() < 65536);
            }
            upstream.write_all(&head)?;
            std::io::copy(&mut upstream, &mut socket)?;
        }
        Ok(())
    });
    (address, worker)
}

#[test]
fn socks4_rule_requests_use_v4_handshake_and_never_bypass_rejection() {
    let origin = Server::new("127.0.0.1:0");
    let engine = engine();
    let url = format!("http://localhost:{}/echo", origin.address.port());
    for reject in [false, true] {
        let (address, worker) = socks4_fixture(origin.address, reject);
        let rule = format!(
            "{url},{}",
            serde_json::json!({"proxy":format!("socks4://{address}"),"dnsIp":"127.0.0.1"})
        );
        let response = eval(&engine, &rule, "java.ajax(url,1000)");
        let handshake = worker.join().unwrap();
        assert!(
            handshake.is_ok(),
            "未完成v4握手：{handshake:?}，响应：{response}"
        );
        if reject {
            assert!(response.contains("[ERROR]"), "{response}");
        } else {
            let body: serde_json::Value = serde_json::from_str(&response).expect(&response);
            assert_eq!(body["path"], "/echo");
            assert_eq!(body["host"], format!("localhost:{}", origin.address.port()));
        }
        assert_eq!(
            origin.requests.load(Ordering::Acquire),
            1,
            "代理拒绝后不得直连源站"
        );
    }
}

#[test]
fn rule_dns_override_follows_cross_host_redirect_without_leaking() {
    let server = Server::new("127.0.0.1:0");
    // 本机DNS可能把.invalid也解析到回环；注入不同的默认地址，确定性检验覆盖是否泄漏。
    let hosts = Arc::new(legado_net::custom_hosts::CustomHosts::default());
    hosts
        .apply_custom_hosts(r#"{"second.invalid":"127.0.0.2"}"#)
        .unwrap();
    let http =
        Arc::new(legado_js::http_resources::HttpResources::default().with_custom_hosts(hosts));
    let resources = legado_js::JsResources::default().with_http_resources(http);
    let engine = resources
        .create_engine(SandboxConfig::default().with_allow_script_run(true))
        .unwrap();
    let url = format!("http://localhost:{}/redirect-host", server.address.port());
    let response = eval(
        &engine,
        &url,
        r#"
        var r=java.connect(url+',{"dnsIp":"::zz,127.0.0.1"}');
        JSON.stringify([r.code(),JSON.parse(r.body()).host,r.raw().request().url().toString()]);
    "#,
    );
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).unwrap(),
        serde_json::json!([
            200,
            format!("second.invalid:{}", server.address.port()),
            format!("http://second.invalid:{}/echo", server.address.port())
        ])
    );
    assert_eq!(server.requests.load(Ordering::Acquire), 2);
    // 未携带覆盖的后续请求使用注入的默认地址；服务只监听127.0.0.1，不得复用上一覆盖。
    let failure = eval(&engine, &url, "java.ajax(url,600)");
    assert!(failure.contains("[ERROR]"), "{failure}");
    assert_eq!(server.requests.load(Ordering::Acquire), 3);
}

#[test]
fn rule_proxy_routes_loopback_with_credentials_and_does_not_leak() {
    let origin = Server::new("127.0.0.1:0");
    let proxy = Server::new("127.0.0.1:0");
    let engine = engine();
    for proxy_url in [
        format!("http://user:pass@{}", proxy.address),
        format!("http://{}@user@pass", proxy.address),
    ] {
        let rule = format!(
            "{},{}",
            origin.url("/echo"),
            serde_json::json!({"proxy":proxy_url})
        );
        let response = eval(&engine, &rule, "java.connect(url).body()");
        let body: serde_json::Value = serde_json::from_str(&response).expect(&response);
        assert_eq!(body["path"], origin.url("/echo"));
        assert_eq!(body["proxyAuth"], "Basic dXNlcjpwYXNz");
        assert!(body["proxyHeader"].is_null());
    }
    assert_eq!(origin.requests.load(Ordering::Acquire), 0);
    let response = eval(&engine, &origin.url("/echo"), "java.connect(url).body()");
    let body: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(body["path"], "/echo");
    assert!(body["proxyAuth"].is_null());
    assert_eq!(origin.requests.load(Ordering::Acquire), 1);
    assert_eq!(proxy.requests.load(Ordering::Acquire), 2);
}

#[test]
fn source_and_explicit_header_proxy_are_consumed_without_sending_control_headers() {
    use legado_js::host_api::current_source::with_current_source_tag;
    let origin = Server::new("127.0.0.1:0");
    let proxy = Server::new("127.0.0.1:0");
    let engine = engine();
    let proxy_url = format!("http://{}", proxy.address);
    let result = with_current_source_tag("https://source.invalid", || {
        eval(
            &engine,
            &origin.url("/echo"),
            &format!(
                r#"
        java.putGlobalHeaders(JSON.stringify({{proxy:{}}}));java.connect(url).body()
    "#,
                serde_json::to_string(&proxy_url).unwrap()
            ),
        )
    });
    let body: serde_json::Value = serde_json::from_str(&result).expect(&result);
    assert_eq!(body["path"], origin.url("/echo"));
    assert!(body["proxyHeader"].is_null());
    // ajax标准JSON扩展也要复用同一来源头/代理提取路径。
    let response = eval(
        &engine,
        &origin.url("/echo"),
        &format!(
            r#"
        var headers={{proxy:{}}};JSON.parse(java.ajax(JSON.stringify({{url:url,headers:headers}}))).body
    "#,
            serde_json::to_string(&proxy_url).unwrap()
        ),
    );
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).unwrap()["path"],
        origin.url("/echo")
    );
    for invalid in [
        "http://user:secret@broken",
        "socks4://user:secret@127.0.0.1:1080",
        "socks6://127.0.0.1:1080",
        "bad",
    ] {
        let rule = format!(
            "{},{}",
            origin.url("/echo"),
            serde_json::json!({"proxy":invalid})
        );
        let failure = eval(&engine, &rule, "java.ajax(url)");
        assert!(failure.contains("代理配置无效或协议不受支持"), "{failure}");
        assert!(!failure.contains("secret"));
    }
    assert_eq!(proxy.requests.load(Ordering::Acquire), 2);
    assert_eq!(
        origin.requests.load(Ordering::Acquire),
        0,
        "代理配置错误不得直连"
    );
}

#[test]
fn batch_dns_routes_are_isolated_and_cookie_state_is_shared_between_variants() {
    let one = Server::new("127.0.0.1:0");
    let two = Server::new(&format!("127.0.0.2:{}", one.address.port()));
    let engine = engine();
    let url = format!("http://localhost:{}/echo", one.address.port());
    let response = eval(
        &engine,
        &url,
        r#"
        var rules=['127.0.0.1','127.0.0.2','127.0.0.1','127.0.0.2'].map(function(ip){return url+','+JSON.stringify({dnsIp:ip});});
        JSON.stringify(java.ajaxAll(rules).map(function(r){return JSON.parse(r.body()).localIp;}))
    "#,
    );
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).unwrap(),
        serde_json::json!(["127.0.0.1", "127.0.0.2", "127.0.0.1", "127.0.0.2"])
    );
    assert_eq!(one.requests.load(Ordering::Acquire), 2);
    assert_eq!(two.requests.load(Ordering::Acquire), 2);
    let cookie_url = format!("http://localhost:{}/cookie", one.address.port());
    eval(
        &engine,
        &cookie_url,
        r#"java.connect(url+',{"dnsIp":"127.0.0.1","headers":{"CookieJar":"1"}}').code()"#,
    );
    let response = eval(&engine, &url, "java.connect(url).body()");
    let body: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert!(body["cookie"].as_str().unwrap().contains("routed=yes"));
    // 无效覆盖回落原DNS；不得把上一变体127.0.0.2带到这次请求。
    assert_eq!(
        eval(
            &engine,
            &url,
            r#"JSON.parse(java.connect(url+',{"dnsIp":"::zz"}').body()).localIp"#
        ),
        "127.0.0.1"
    );
}

#[test]
fn routed_request_retains_redirect_policy_timeout_and_active_cancellation() {
    let server = Server::new("127.0.0.1:0");
    let engine = Arc::new(engine());
    let url = format!("http://localhost:{}/redirect-host", server.address.port());
    assert_eq!(
        eval(
            &engine,
            &url,
            r#"java.connect(url+',{"dnsIp":"127.0.0.1","followRedirects":false}').code()"#
        ),
        "302"
    );
    let slow = format!("http://localhost:{}/slow", server.address.port());
    let failure = eval(
        &engine,
        &slow,
        r#"java.ajax(url+',{"dnsIp":"127.0.0.1"}',200)"#,
    );
    assert!(failure.contains("Timeout"), "{failure}");
    let token = Arc::new(Cancellation::default());
    let pending = format!("http://localhost:{}/pending", server.address.port());
    let code = format!(
        "java.ajax({}+',{{\"dnsIp\":\"127.0.0.1\"}}',0)",
        serde_json::to_string(&pending).unwrap()
    );
    let before = server.requests.load(Ordering::Acquire);
    let (worker, rx) = start_cancellable(&engine, &token, code);
    wait_for(|| server.requests.load(Ordering::Acquire) == before + 1);
    finish_cancelled(&token, worker, rx);
    wait_for(|| server.metrics.cancelled.load(Ordering::Acquire) == 1);
    assert_eq!(
        eval(&engine, &server.url("/echo"), "java.connect(url).code()"),
        "200"
    );
}

#[test]
fn dns_override_supports_ipv6_and_proxy_hostname_lookup() {
    let ipv6 = Server::new("[::1]:0");
    let engine = engine();
    let url = format!("http://localhost:{}/echo", ipv6.address.port());
    assert_eq!(
        eval(
            &engine,
            &url,
            r#"JSON.parse(java.connect(url+',{"dnsIp":"::1"}').body()).localIp"#
        ),
        "::1"
    );
    let proxy = Server::new("127.0.0.1:0");
    let target = "http://localhost:1/echo";
    let rule = format!(
        "{target},{}",
        serde_json::json!({"proxy":format!("http://proxy.invalid:{}",proxy.address.port()),"dnsIp":"127.0.0.1"})
    );
    let response = eval(&engine, &rule, "java.connect(url).body()");
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).expect(&response)["path"],
        target
    );
    assert_eq!(proxy.requests.load(Ordering::Acquire), 1);
}

#[derive(Default)]
struct BatchMetrics {
    active: AtomicUsize,
    peak: AtomicUsize,
    cancelled: AtomicUsize,
}

#[derive(Default)]
struct Cancellation {
    flag: AtomicBool,
    changed: tokio::sync::Notify,
}
impl Cancellation {
    fn cancel(&self) {
        self.flag.store(true, Ordering::Release);
        self.changed.notify_waiters();
    }
}
impl legado_js::cancellation::JsCancellation for Cancellation {
    fn is_cancelled(&self) -> bool {
        self.flag.load(Ordering::Acquire)
    }
    fn cancelled(&self) -> legado_js::cancellation::CancelWait<'_> {
        Box::pin(async {
            loop {
                let notified = self.changed.notified();
                let mut notified = std::pin::pin!(notified);
                notified.as_mut().enable();
                if self.flag.load(Ordering::Acquire) {
                    return;
                }
                notified.await;
            }
        })
    }
}

fn wait_for(mut ready: impl FnMut() -> bool) {
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while !ready() {
        assert!(
            std::time::Instant::now() < deadline,
            "等待夹具进入目标阶段超时"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
}

fn start_cancellable(
    engine: &Arc<QuickJsEngine>,
    token: &Arc<Cancellation>,
    code: String,
) -> (
    JoinHandle<()>,
    std::sync::mpsc::Receiver<Result<String, String>>,
) {
    let engine = engine.clone();
    let token = token.clone();
    let (tx, rx) = std::sync::mpsc::channel();
    let worker = std::thread::spawn(move || {
        let _scope = legado_js::cancellation::Scope::enter(Some(token));
        tx.send(engine.eval(&code).map_err(|e| e.to_string()))
            .unwrap();
    });
    (worker, rx)
}

fn finish_cancelled(
    token: &Cancellation,
    worker: JoinHandle<()>,
    rx: std::sync::mpsc::Receiver<Result<String, String>>,
) {
    token.cancel();
    let result = rx.recv_timeout(Duration::from_secs(2));
    worker.join().unwrap();
    let error = result
        .expect("取消没有中断宿主等待")
        .expect_err("取消被转成普通成功响应");
    assert!(
        error.contains(legado_js::cancellation::CANCELLED),
        "{error}"
    );
    assert!(!error.contains("Timeout"), "取消不应误报网络超时");
}

#[test]
fn active_cancel_interrupts_send_and_body_without_becoming_ajax_error_text() {
    for (path, call) in [
        ("/pending", "java.ajax(url,0)"),
        ("/pending", "java.connect(url,{},0).body()"),
        ("/no-headers", "java.get(url,{},0).body()"),
        ("/no-headers", "java.head(url,{},0).body()"),
        ("/no-headers", "java.post(url,'',{},0).body()"),
    ] {
        let server = Server::new("127.0.0.1:0");
        let engine = Arc::new(engine());
        let token = Arc::new(Cancellation::default());
        let code = format!(
            "var url={};var result;try{{result={call}}}catch(e){{result='caught'}}java.put('after-cancel','bad');result",
            serde_json::to_string(&server.url(path)).unwrap()
        );
        let (worker, rx) = start_cancellable(&engine, &token, code);
        wait_for(|| server.requests.load(Ordering::Acquire) == 1);
        finish_cancelled(&token, worker, rx);
        wait_for(|| server.metrics.cancelled.load(Ordering::Acquire) == 1);
        assert_eq!(engine.eval("java.get('after-cancel')").unwrap(), "");
        assert_eq!(
            eval(&engine, &server.url("/echo"), "java.connect(url).code()"),
            "200"
        );
    }
}

#[test]
fn active_cancel_drops_probe_batch_inflight_and_unsent_items() {
    let server = Server::new("127.0.0.1:0");
    let engine = Arc::new(engine());
    let token = Arc::new(Cancellation::default());
    let code = format!(
        "var url={};java.ajaxTestAll([url,url,url,url,url,url,url,url],0,true)",
        serde_json::to_string(&server.url("/pending")).unwrap()
    );
    let (worker, rx) = start_cancellable(&engine, &token, code);
    wait_for(|| server.requests.load(Ordering::Acquire) == 4);
    finish_cancelled(&token, worker, rx);
    wait_for(|| server.metrics.cancelled.load(Ordering::Acquire) == 4);
    assert_eq!(server.requests.load(Ordering::Acquire), 4);
}

#[test]
fn active_cancel_releases_rate_wait_without_starting_http() {
    let server = Server::new("127.0.0.1:0");
    let engine = Arc::new(engine());
    let gate = Arc::new(Gate::default());
    gate.entered.store(1, Ordering::Release);
    engine.http_resources().set_request_policy(Arc::new(Policy {
        concurrency: AtomicUsize::new(2),
        gate: Some(gate.clone()),
    }));
    let token = Arc::new(Cancellation::default());
    let code = format!(
        "java.ajaxAll([{},{}])",
        serde_json::to_string(&server.url("/echo")).unwrap(),
        serde_json::to_string(&server.url("/echo")).unwrap()
    );
    let (worker, rx) = start_cancellable(&engine, &token, code);
    wait_for(|| gate.entered.load(Ordering::Acquire) == 3);
    finish_cancelled(&token, worker, rx);
    assert_eq!(gate.cancelled.load(Ordering::Acquire), 2);
    assert_eq!(server.requests.load(Ordering::Acquire), 0);
}

struct Policy {
    concurrency: AtomicUsize,
    gate: Option<Arc<Gate>>,
}

impl legado_js::http_request_policy::HttpRequestPolicy for Policy {
    fn snapshot(
        &self,
        _: Option<&str>,
    ) -> Result<legado_js::http_request_policy::RequestPolicySnapshot, String> {
        Ok(legado_js::http_request_policy::RequestPolicySnapshot {
            concurrency: std::num::NonZeroUsize::new(self.concurrency.load(Ordering::Acquire))
                .unwrap(),
            gate: self
                .gate
                .clone()
                .map(|g| g as Arc<dyn legado_js::http_request_policy::RequestGate>),
        })
    }
}

#[derive(Default)]
struct Gate {
    delay: Option<Duration>,
    entered: AtomicUsize,
    cancelled: AtomicUsize,
}

impl legado_js::http_request_policy::RequestGate for Gate {
    fn acquire(&self) -> legado_js::http_request_policy::RequestWait<'_> {
        Box::pin(async {
            let index = self.entered.fetch_add(1, Ordering::AcqRel);
            struct Waiting<'a>(&'a AtomicUsize, bool);
            impl Drop for Waiting<'_> {
                fn drop(&mut self) {
                    if !self.1 {
                        self.0.fetch_add(1, Ordering::AcqRel);
                    }
                }
            }
            let mut wait = Waiting(&self.cancelled, false);
            match self.delay {
                Some(delay) => tokio::time::sleep(delay).await,
                None if index > 0 => std::future::pending::<()>().await,
                None => (),
            }
            wait.1 = true;
        })
    }
}

#[test]
fn configured_batch_concurrency_applies_even_when_rate_is_skipped() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let policy = Arc::new(Policy {
        concurrency: AtomicUsize::new(2),
        gate: None,
    });
    engine.http_resources().set_request_policy(policy.clone());
    for (limit, call) in [
        (2, "java.ajaxAll(urls,true)"),
        (1, "java.ajaxTestAll(urls,1000,true)"),
    ] {
        policy.concurrency.store(limit, Ordering::Release);
        server.metrics.peak.store(0, Ordering::Release);
        let urls: Vec<_> = (0..6)
            .map(|i| server.url(&format!("/batch/{i}/50")))
            .collect();
        assert_eq!(
            eval(
                &engine,
                &server.url("/"),
                &format!(
                    "var urls={}; {call}.length",
                    serde_json::to_string(&urls).unwrap()
                )
            ),
            "6"
        );
        assert_eq!(server.metrics.peak.load(Ordering::Acquire), limit);
    }
}

#[test]
fn skip_rate_limit_is_explicit_and_probe_time_excludes_wait() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let gate = Arc::new(Gate {
        delay: Some(Duration::from_millis(180)),
        ..Default::default()
    });
    engine.http_resources().set_request_policy(Arc::new(Policy {
        concurrency: AtomicUsize::new(2),
        gate: Some(gate.clone()),
    }));
    let start = std::time::Instant::now();
    let time = eval(
        &engine,
        &server.url("/echo"),
        "java.ajaxTestAll([url],1000)[0].callTime()",
    )
    .parse::<u128>()
    .unwrap();
    assert!(start.elapsed().as_millis() >= time + 140);
    eval(
        &engine,
        &server.url("/echo"),
        "java.ajaxAll([url],false)[0].body()",
    );
    assert_eq!(gate.entered.load(Ordering::Acquire), 2);
    for call in [
        "java.ajaxAll([url],true)",
        "java.ajaxTestAll([url],1000,true)",
    ] {
        eval(&engine, &server.url("/echo"), call);
    }
    assert_eq!(
        gate.entered.load(Ordering::Acquire),
        2,
        "跳过源限流不应创建等待"
    );
    assert_eq!(gate.cancelled.load(Ordering::Acquire), 0);
}

#[test]
fn failed_batch_drops_rate_waiters_without_sending_queued_requests() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let gate = Arc::new(Gate::default());
    engine.http_resources().set_request_policy(Arc::new(Policy {
        concurrency: AtomicUsize::new(3),
        gate: Some(gate.clone()),
    }));
    let output = eval(
        &engine,
        &server.url("/disconnect"),
        "try {java.ajaxAll([url,url,url,url,url]); 'bad'} catch(e) {'cancelled'}",
    );
    assert_eq!(output, "cancelled");
    assert_eq!(server.requests.load(Ordering::Acquire), 1);
    assert_eq!(gate.entered.load(Ordering::Acquire), 3);
    assert_eq!(gate.cancelled.load(Ordering::Acquire), 2);
    assert_eq!(
        eval(
            &engine,
            &server.url("/echo"),
            "java.ajaxAll([url],true)[0].code()"
        ),
        "200"
    );
}

struct Server {
    address: SocketAddr,
    stopped: Arc<AtomicBool>,
    requests: Arc<AtomicUsize>,
    worker: Option<JoinHandle<()>>,
    metrics: Arc<BatchMetrics>,
}

#[test]
fn archive_read_remote_rules_keep_raw_bytes_and_current_context() {
    use legado_js::host_api::current_source::with_current_source_tag;
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    let rule = format!(
        "{},{}",
        server.url("/archive.zip"),
        serde_json::json!({
            "method":"POST", "body":"{{'payload'}}", "headers":{"X-Marker":"{{'archive'}}"},
            "type":"zip", "bodyJs":"throw new Error('不得作为文本求值')"
        })
    );
    let value = with_current_source_tag(&server.url("/"), || {
        eval(
            &engine,
            &rule,
            r#"
        java.putGlobalHeaders(JSON.stringify({'X-Source':'source','Cookie':'session=archive'}));
        globalThis.result='outer';
        var first=java.getZipStringContent(url,'request');
        var raw=Array.from(java.getZipByteArrayContent(url,'binary'));
        JSON.stringify([JSON.parse(first),raw,result]);
    "#,
        )
    });
    let value: serde_json::Value = serde_json::from_str(&value).unwrap();
    assert_eq!(value[0]["method"], "POST");
    assert_eq!(value[0]["body"], "payload");
    assert_eq!(value[0]["marker"], "archive");
    assert_eq!(value[0]["source"], "source");
    assert_eq!(value[0]["cookie"], "session=archive");
    assert_eq!(value[1], serde_json::json!([0, 128, 255]));
    assert_eq!(value[2], "outer");
    assert_eq!(
        eval(
            &engine,
            &server.url("/archive.zip"),
            "JSON.stringify(Array.from(java.getZipByteArrayContent('@js: url','binary')))"
        ),
        "[0,128,255]"
    );
    assert_eq!(server.requests.load(Ordering::Acquire), 3);
}

#[test]
fn archive_read_cancellation_interrupts_body_and_rate_wait() {
    let server = Server::new("127.0.0.1:0");
    let engine = Arc::new(engine());
    let token = Arc::new(Cancellation::default());
    let code = format!(
        "java.getZipByteArrayContent({},'entry')",
        serde_json::to_string(&server.url("/pending")).unwrap()
    );
    let (worker, rx) = start_cancellable(&engine, &token, code);
    wait_for(|| server.requests.load(Ordering::Acquire) == 1);
    finish_cancelled(&token, worker, rx);
    wait_for(|| server.metrics.cancelled.load(Ordering::Acquire) == 1);
    let gate = Arc::new(Gate::default());
    gate.entered.store(1, Ordering::Release);
    engine.http_resources().set_request_policy(Arc::new(Policy {
        concurrency: AtomicUsize::new(2),
        gate: Some(gate.clone()),
    }));
    let token = Arc::new(Cancellation::default());
    let code = format!(
        "java.get7zByteArrayContent({},'entry')",
        serde_json::to_string(&server.url("/archive.zip")).unwrap()
    );
    let (worker, rx) = start_cancellable(&engine, &token, code);
    wait_for(|| gate.entered.load(Ordering::Acquire) == 2);
    finish_cancelled(&token, worker, rx);
    assert_eq!(server.requests.load(Ordering::Acquire), 1);
    assert_eq!(gate.cancelled.load(Ordering::Acquire), 1);
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
    if path == "/archive.zip" {
        let mut writer = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
        let options = zip::write::SimpleFileOptions::default();
        writer.start_file("request", options).unwrap();
        writer.write_all(serde_json::json!({"method":method,"body":String::from_utf8(body).unwrap(),"marker":header("X-Marker"),"source":header("X-Source"),"cookie":header("Cookie")}).to_string().as_bytes()).unwrap();
        writer.start_file("binary", options).unwrap();
        writer.write_all(&[0, 128, 255]).unwrap();
        let bytes = writer.finish().unwrap().into_inner();
        let _ = write!(
            socket,
            "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            bytes.len()
        );
        let _ = socket.write_all(&bytes);
        return;
    }
    if path == "/pending" || path == "/no-headers" {
        if path == "/pending" {
            let _ = socket
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n");
        }
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
            "localIp":socket.local_addr().unwrap().ip().to_string(),"cookie":header("Cookie"),"host":header("Host"),"proxyAuth":header("Proxy-Authorization"),"proxyHeader":header("proxy"),
            "markerCount":head.lines().filter(|line| line.split_once(':').is_some_and(|(key,_)| key.eq_ignore_ascii_case("X-Marker"))).count()})
        .to_string()
    };
    let status = if matches!(path, "/redirect" | "/redirect-host") {
        "302 Found"
    } else if path == "/retry" && request_number < 3 {
        "503 Service Unavailable"
    } else {
        "200 OK"
    };
    let location = if path == "/redirect" {
        "Location: /echo\r\n".to_string()
    } else if path == "/redirect-host" {
        format!(
            "Location: http://second.invalid:{}/echo\r\n",
            socket.local_addr().unwrap().port()
        )
    } else {
        String::new()
    };
    let cookie = if path == "/cookie" {
        "Set-Cookie: routed=yes; Path=/\r\n"
    } else {
        ""
    };
    let response = format!(
        "HTTP/1.1 {status}\r\n{cookie}{location}Content-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
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
    // 先确认请求链已就绪，避免并行建VM/首次建池挤占短超时预算。
    eval(
        &engine,
        &server.url("/echo"),
        "java.get(url,{}).statusCode()",
    );
    let before = server.requests.load(Ordering::Acquire);
    let call = if method == "post" {
        "java.post(url,'正文',{ 'X-Marker':'timeout' },600)".to_string()
    } else {
        format!("java.{method}(url,{{'X-Marker':'timeout'}},600)")
    };
    let response = eval(
        &engine,
        &server.url("/slow"),
        &format!(
            "(function(){{try{{return JSON.stringify({{code:{call}.statusCode()}});}}catch(e){{return JSON.stringify({{error:String(e)}});}}}})()"
        ),
    );
    assert_eq!(
        server.requests.load(Ordering::Acquire) - before,
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
fn rule_timeout_and_missing_webview_host_do_not_fall_back_to_http() {
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
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"java.ajax(url+',{"webView":true}')"#,
    );
    assert!(
        response.contains("[ERROR]") && response.contains("当前宿主没有WebView执行订阅"),
        "{response}"
    );
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        1,
        "缺少WebView宿主时不得退化为普通HTTP请求"
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
    eval(&engine, &server.url("/echo"), "java.ajax(url)");
    let response = eval(
        &engine,
        &server.url("/"),
        r#"
        var rows=java.ajaxTestAll([url+'slow',url+'echo'],600,true);
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

#[test]
fn response_bridge_reinjection_preserves_single_requests_and_function_identity() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    engine.eval("globalThis.savedBridge=[java.connect,java.get,java.post,java.head,java.webView,java.ajaxAll,java.ajaxTestAll];java.put('bridge-key','变量');").unwrap();
    for _ in 0..3 {
        engine
            .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
            .unwrap();
    }
    assert_eq!(engine.eval("[java.connect,java.get,java.post,java.head,java.webView,java.ajaxAll,java.ajaxTestAll].every(function(f,i){return f===savedBridge[i];})").unwrap(),"true","未变化的包装必须复用，不应逐次叠加");
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var r=java.connect(url);
        var p=java.post(url,'正文',{'X-Marker':'kept'});
        JSON.stringify([r.code(),JSON.parse(r.body()).path,java.get('bridge-key'),
            java.get(url,{}).statusCode(),java.head(url,{}).statusCode(),JSON.parse(p.body()).body]);
    "#,
    );
    assert_eq!(response, "[200,\"/echo\",\"变量\",200,200,\"正文\"]");
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        4,
        "每次调用只发送一次请求"
    );
}

#[test]
fn response_bridge_works_in_cached_and_fresh_executor_initialization() {
    use legado_js::executor::QuickJsExecutor;
    use legado_parser::JsExecutor;
    let server = Server::new("127.0.0.1:0");
    for fresh in [false, true] {
        // 空URL映射库选择生产fresh分支，不产生额外远端库请求。
        let executor = QuickJsExecutor::new(&server.url("/"))
            .with_setup_script(Some(
                "put('source_bridge-key','变量'); java.get=function(key){return get('source_'+key);}; globalThis.setupReady=true;".to_string(),
            ))
            .with_js_lib(fresh.then(|| "{}".to_string()));
        let script = format!(
            "globalThis.calls=(globalThis.calls||0)+1;JSON.stringify([java.connect({}).code(),java.get('bridge-key'),setupReady,calls])",
            serde_json::to_string(&server.url("/echo")).unwrap()
        );
        for turn in 1..=2 {
            let actual = executor
                .execute_js(&script)
                .expect("缓存与fresh初始化后均应能请求");
            assert_eq!(
                serde_json::from_str::<serde_json::Value>(&actual).unwrap(),
                serde_json::json!([200, "变量", true, if fresh { 1 } else { turn }])
            );
        }
    }
    assert_eq!(server.requests.load(Ordering::Acquire), 4);
}

#[test]
fn response_bridge_reinjection_accepts_setup_delegation_and_refreshes_backend_dependency() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    engine
        .eval(
            r#"
        globalThis.sourceConnect=java.connect;globalThis.sourceGet=java.get;
        globalThis.nativeNR=java.connectNR;
        globalThis.sourceBatch=java.ajaxAll;globalThis.sourceProbe=java.ajaxTestAll;
        java.ajaxAll=function(){return sourceBatch.apply(java,arguments);};
        java.ajaxTestAll=function(){return sourceProbe.apply(java,arguments);};
        globalThis.connectCalls=0;globalThis.getCalls=0;globalThis.nrCalls=0;
        java.connect=function(){connectCalls++;return sourceConnect.apply(java,arguments);};
        java.get=function(key){getCalls++;return sourceGet(key);};
        java.connectNR=function(){nrCalls++;return nativeNR.apply(java,arguments);};
        java.put('bridge-key','变量');
    "#,
        )
        .unwrap();
    for _ in 0..3 {
        engine
            .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
            .unwrap();
    }
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var r=java.connect(url);
        JSON.stringify([r.code(),JSON.parse(r.body()).path,java.get('bridge-key'),
            java.get(url,{}).statusCode(),connectCalls,getCalls,nrCalls,
            java.ajaxAll([url])[0].code(),java.ajaxTestAll([url],1000)[0].code()]);
    "#,
    );
    assert_eq!(response, "[200,\"/echo\",\"变量\",200,1,1,1,200,200]");
    assert_eq!(server.requests.load(Ordering::Acquire), 4);
}

#[test]
fn response_bridge_setup_delegation_preserves_headers_bodies_and_timeouts() {
    let server = Server::new("127.0.0.1:0");
    let engine = engine();
    engine.eval(r#"
        globalThis.savedConnect=java.connect;globalThis.savedPost=java.post;globalThis.savedHead=java.head;
        globalThis.hookCalls=0;
        java.connect=function(){hookCalls++;return savedConnect.apply(java,arguments);};
        java.post=function(){hookCalls++;return savedPost.apply(java,arguments);};
        java.head=function(){hookCalls++;return savedHead.apply(java,arguments);};
    "#).unwrap();
    for _ in 0..2 {
        engine
            .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
            .unwrap();
    }
    let response = eval(
        &engine,
        &server.url("/echo"),
        r#"
        var rows=[java.connect(url,{'X-Marker':'connect'},1000).body(),
            java.connect(url,'POST',{'X-Marker':'enhanced'},'正文',1000).body(),
            java.post(url,'正文',{'X-Marker':'post'},1000).body()];
        JSON.stringify([rows.map(function(body){var r=JSON.parse(body);return [r.marker,r.body,r.method];}),
            java.head(url,{},1000).statusCode(),hookCalls]);
    "#,
    );
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&response).unwrap(),
        serde_json::json!([
            [
                ["connect", "", "GET"],
                ["enhanced", "正文", "POST"],
                ["post", "正文", "POST"]
            ],
            200,
            4
        ])
    );
    let response = eval(
        &engine,
        &server.url("/slow"),
        r#"
        JSON.stringify([java.connect(url,{},40).body().indexOf('Timeout')>=0,
            (function(){try{java.post(url,'body',{},40);return false;}catch(e){return String(e).indexOf('Timeout')>=0;}})()]);
    "#,
    );
    assert_eq!(response, "[true,true]");
}

#[test]
fn response_bridge_rejects_unowned_response_shaped_objects_and_tracks_latest_backend() {
    let engine = engine();
    for override_script in [
        "java.connect=function(){return {body:function(){return '伪响应';},code:function(){return 200;}};};",
        "java.connect=function(){return {status_code:200,body:'伪响应',headers:{}};};",
        "java.connect=function(){return '损坏JSON';};",
    ] {
        engine.eval(override_script).unwrap();
        engine
            .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
            .unwrap();
        assert_eq!(engine.eval("(function(){try{java.connect('https://unused.test/');return false;}catch(e){return true;}})()").unwrap(),"true");
    }
    engine.eval("java.connectNR=function(){return JSON.stringify({status_code:201,body:'first',headers:{}});};").unwrap();
    engine
        .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
        .unwrap();
    assert_eq!(
        engine
            .eval("java.get('https://unused.test/',{}).body()")
            .unwrap(),
        "first"
    );
    engine.eval("java.connectNR=function(){return JSON.stringify({status_code:202,body:'second',headers:{}});};").unwrap();
    engine
        .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
        .unwrap();
    assert_eq!(
        engine
            .eval("java.get('https://unused.test/',{}).body()")
            .unwrap(),
        "second"
    );
    assert_eq!(
        engine
            .eval("java.head('https://unused.test/',{}).statusCode()")
            .unwrap(),
        "202"
    );
}

#[test]
fn response_bridge_reuses_webview_adapter_and_normalizes_setup_replacement_once() {
    let engine = engine();
    engine
        .eval(
            r#"
        globalThis.webViewCalls=0;
        java.webView=function(html,url,js,cacheFirst){webViewCalls++;
            return JSON.stringify([html,url,js,cacheFirst,arguments.length]);};
    "#,
        )
        .unwrap();
    engine
        .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
        .unwrap();
    engine
        .eval("globalThis.savedWebView=java.webView;")
        .unwrap();
    for _ in 0..10 {
        engine
            .eval(legado_js::host_api::quickjs_impl::RESPONSE_BRIDGE_JS)
            .unwrap();
    }
    assert_eq!(engine.eval("java.webView===savedWebView").unwrap(), "true");
    assert_eq!(
        engine.eval("java.webView('正文')").unwrap(),
        "[\"正文\",null,null,null,4]"
    );
    assert_eq!(engine.eval("webViewCalls").unwrap(), "1");
}

#[test]
fn file_download_cache_returns_text_and_reloads_missing_or_expired_files() {
    let server = Server::new("127.0.0.1:0");
    let engine = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
    let url = server.url("/echo");
    assert_eq!(
        eval(&engine, &url, "JSON.parse(java.cacheFile(url)).path"),
        "/echo"
    );
    assert_eq!(
        eval(&engine, &url, "JSON.parse(cacheFile(url,1)).path"),
        "/echo"
    );
    assert_eq!(server.requests.load(Ordering::Acquire), 1, "命中不刷新期限");
    assert_eq!(
        eval(
            &engine,
            &url,
            "java.deleteFile(cache.get(java.md5Encode16(url))); JSON.parse(java.importScript(url)).path"
        ),
        "/echo"
    );
    assert_eq!(
        server.requests.load(Ordering::Acquire),
        2,
        "缓存目标丢失必须重下"
    );
    let expired = server.url("/echo?expired");
    for _ in 0..2 {
        assert_eq!(
            eval(&engine, &expired, "JSON.parse(cacheFile(url,-1)).path"),
            "/echo?expired"
        );
    }
    assert_eq!(server.requests.load(Ordering::Acquire), 4);
    let short = server.url("/echo?short");
    eval(&engine, &short, "cacheFile(url,1)");
    std::thread::sleep(Duration::from_millis(1100));
    eval(&engine, &short, "cacheFile(url,1)");
    assert_eq!(server.requests.load(Ordering::Acquire), 6);
}

#[test]
fn file_download_rules_keep_post_headers_cookie_and_raw_body() {
    use legado_js::host_api::current_source::with_current_source_tag;
    let server = Server::new("127.0.0.1:0");
    let engine = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
    let rule = format!(
        "{},{}",
        server.url("/echo"),
        serde_json::json!({"method":"POST","body":"{{'payload'}}","headers":{"X-Marker":"{{'download'}}"},"type":"txt","bodyJs":"throw Error('不应执行')"})
    );
    let output = with_current_source_tag(&server.url("/"), || {
        eval(
            &engine,
            &rule,
            r#"
        java.putGlobalHeaders(JSON.stringify({'Cookie':'session=file'}));
        globalThis.result='outer';
        var path=java.downloadFile('@js: url');
        var body=JSON.parse(java.readTxtFile(path));
        JSON.stringify([body,path.endsWith(java.md5Encode16('@js: url')+'.txt'),result,java.getFile(path).exists()]);
    "#,
        )
    });
    let value: serde_json::Value = serde_json::from_str(&output).unwrap();
    assert_eq!(value[0]["method"], "POST");
    assert_eq!(value[0]["body"], "payload");
    assert_eq!(value[0]["marker"], "download");
    assert_eq!(value[0]["cookie"], "session=file");
    assert_eq!(value[1], true);
    assert_eq!(value[2], "outer");
    assert_eq!(value[3], true);
    assert_eq!(server.requests.load(Ordering::Acquire), 1);
}

#[test]
fn file_download_hex_overload_and_local_import_obey_upstream_and_sandbox() {
    let server = Server::new("127.0.0.1:0");
    let engine = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
    let rule = format!(
        "{},{}",
        server.url("/unused"),
        serde_json::json!({"type":"js"})
    );
    assert_eq!(
        eval(
            &engine,
            &rule,
            r#"
        var path=downloadFile('7661722078203d20313b',url);
        JSON.stringify([java.importScript(path),importScript(path),path.endsWith(java.md5Encode16(url)+'.js'),typeof x]);
    "#
        ),
        r#"["var x = 1;","var x = 1;",true,"undefined"]"#
    );
    assert_eq!(
        eval(&engine, &server.url("/unused.js"), "downloadFile('00',url)"),
        ""
    );
    for script in [
        "importScript('../outside.js')",
        "java.importScript('missing-import.js')",
        "downloadFile('not-hex',url)",
        "downloadFile('00',url.replace('js','../escape'))",
        "java.cacheFile(url,undefined)",
        "cacheFile(url,null)",
        "cacheFile(url,NaN)",
        "cacheFile(url,2147483648)",
    ] {
        assert!(
            engine
                .eval_with_bindings(script, &[("url", JsValue::String(rule.clone()))])
                .is_err(),
            "{script}"
        );
        assert_eq!(engine.eval("1+1").unwrap(), "2");
    }
    assert_eq!(server.requests.load(Ordering::Acquire), 0);
    assert_eq!(
        eval(
            &engine,
            &rule,
            "var empty=downloadFile('202009',url); try {importScript(empty); 'bad'} catch(e) {'empty'}"
        ),
        "empty"
    );
    assert_eq!(
        QuickJsEngine::new(SandboxConfig::default())
            .unwrap()
            .eval("typeof java.cacheFile + ':' + typeof importScript")
            .unwrap(),
        "undefined:undefined"
    );
}

#[test]
fn file_download_failures_throw_and_do_not_poison_cache_or_vm() {
    let server = Server::new("127.0.0.1:0");
    let engine = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
    for call in ["downloadFile", "java.cacheFile", "importScript"] {
        let script = format!("try {{{call}(url);'bad'}} catch(e) {{'caught'}}");
        assert_eq!(eval(&engine, &server.url("/disconnect"), &script), "caught");
        assert_eq!(
            eval(
                &engine,
                &server.url("/disconnect"),
                "String(cache.get(java.md5Encode16(url)))"
            ),
            "null"
        );
    }
    assert_eq!(eval(&engine, &server.url("/gbk"), "cacheFile(url)"), "中文");
    assert_eq!(server.requests.load(Ordering::Acquire), 4);
}

#[test]
fn file_download_cancel_stops_body_and_rate_wait_without_cache_publication() {
    let server = Server::new("127.0.0.1:0");
    for (index, call) in ["java.downloadFile", "cacheFile", "java.importScript"]
        .into_iter()
        .enumerate()
    {
        let engine = Arc::new(QuickJsEngine::new(SandboxConfig::permissive()).unwrap());
        let token = Arc::new(Cancellation::default());
        let code = format!(
            "{call}({})",
            serde_json::to_string(&server.url("/pending")).unwrap()
        );
        let (worker, rx) = start_cancellable(&engine, &token, code);
        wait_for(|| server.requests.load(Ordering::Acquire) == index + 1);
        finish_cancelled(&token, worker, rx);
        wait_for(|| server.metrics.cancelled.load(Ordering::Acquire) == index + 1);
        assert_eq!(
            eval(
                &engine,
                &server.url("/pending"),
                "String(cache.get(java.md5Encode16(url)))"
            ),
            "null"
        );
    }
    let engine = Arc::new(QuickJsEngine::new(SandboxConfig::permissive()).unwrap());
    let gate = Arc::new(Gate::default());
    gate.entered.store(1, Ordering::Release);
    engine.http_resources().set_request_policy(Arc::new(Policy {
        concurrency: AtomicUsize::new(1),
        gate: Some(gate.clone()),
    }));
    let token = Arc::new(Cancellation::default());
    let (worker, rx) = start_cancellable(
        &engine,
        &token,
        format!(
            "cacheFile({})",
            serde_json::to_string(&server.url("/echo")).unwrap()
        ),
    );
    wait_for(|| gate.entered.load(Ordering::Acquire) == 2);
    finish_cancelled(&token, worker, rx);
    assert_eq!(server.requests.load(Ordering::Acquire), 3);
    assert_eq!(gate.cancelled.load(Ordering::Acquire), 1);
}

#[test]
fn file_download_nested_local_import_and_cached_rules_keep_context() {
    let server = Server::new("127.0.0.1:0");
    let engine = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
    let text = hex::encode(server.url("/echo"));
    let local_rule = format!(
        "{},{}",
        server.url("/local"),
        serde_json::json!({"type":"txt"})
    );
    let path = eval(
        &engine,
        &local_rule,
        &format!(
            "downloadFile({},url)",
            serde_json::to_string(&text).unwrap()
        ),
    );
    let nested = format!(
        "@js: java.importScript({})",
        serde_json::to_string(&path).unwrap()
    );
    for _ in 0..2 {
        assert_eq!(
            eval(
                &engine,
                &nested,
                "globalThis.result='outer'; var text=JSON.parse(cacheFile(url)); JSON.stringify([text.path,result])"
            ),
            r#"["/echo","outer"]"#
        );
    }
    assert_eq!(server.requests.load(Ordering::Acquire), 1);
    assert_eq!(
        eval(
            &engine,
            &local_rule,
            "var path=downloadFile('d6d0cec4',url);importScript(path)"
        ),
        "中文"
    );
    for (url, suffix) in [
        (server.url("/file.PDF?q=1#x"), "PDF"),
        (format!("{}, {{}}", server.url("/file.txt")), "txt"),
        (server.url("/no-suffix"), "ext"),
    ] {
        let path = eval(&engine, &url, "downloadFile(url)");
        let expected = format!(
            "{}.{}",
            legado_js::host_api::encoding::md5_encode_16(&url),
            suffix
        );
        assert!(path.ends_with(&expected), "{path}");
        assert!(!std::path::Path::new(&path).is_absolute());
        assert!(
            legado_js::host_api::file_utils::resolve_safe_path(&path)
                .unwrap()
                .is_file()
        );
    }
}

#[test]
fn file_download_failed_publication_cleans_partial_and_can_retry() {
    use legado_js::host_api::{encoding, file_utils};
    let server = Server::new("127.0.0.1:0");
    let engine = QuickJsEngine::new(SandboxConfig::permissive()).unwrap();
    let probe_rule = format!(
        "{},{}",
        server.url("/probe"),
        serde_json::json!({"type":"bin"})
    );
    let probe = eval(&engine, &probe_rule, "downloadFile('00',url)");
    let directory = file_utils::resolve_safe_path(&probe)
        .unwrap()
        .parent()
        .unwrap()
        .to_path_buf();
    let url = server.url("/echo");
    let name = format!("{}.ext", encoding::md5_encode_16(&url));
    let blocked = directory.join(&name);
    std::fs::create_dir(&blocked).unwrap();
    assert_eq!(
        eval(&engine, &url, "try{cacheFile(url);'bad'}catch(e){'failed'}"),
        "failed"
    );
    assert!(!directory.join(format!("{name}.part")).exists());
    assert_eq!(
        eval(&engine, &url, "String(cache.get(java.md5Encode16(url)))"),
        "null"
    );
    std::fs::remove_dir(blocked).unwrap();
    assert_eq!(
        eval(&engine, &url, "JSON.parse(cacheFile(url)).path"),
        "/echo"
    );
    assert_eq!(server.requests.load(Ordering::Acquire), 2);
    assert_eq!(
        std::fs::read_dir(directory).unwrap().count(),
        2,
        "只保留探针和完整下载文件"
    );
}
