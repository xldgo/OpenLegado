//! 字体脚本边界：真实对象持有Rust解析结果，缓存淘汰不撤销仍存活的对象。
//! — Codex + Bridge
use super::{
    font_api::{self, FontResources},
    query_ttf::QueryTtf,
    register::mount_dual,
    rule_request,
};
use crate::http_resources::HttpResources;
use legado_core::LegadoError;
use rquickjs::{
    Class, Ctx, FromJs, IntoJs, JsLifetime, Object, Value,
    class::{JsClass, Readable, Trace, Tracer},
};
use std::sync::Arc;

struct FontHandle(Arc<QueryTtf>);
impl<'js> Trace<'js> for FontHandle {
    fn trace<'a>(&self, _: Tracer<'a, 'js>) {}
}
// 安全性：仅包含不带生命周期的Rust Arc<QueryTtf>，无JS值或引擎借用；Changed与Self完全相同。
unsafe impl<'js> JsLifetime<'js> for FontHandle {
    type Changed<'to> = Self;
}
impl<'js> JsClass<'js> for FontHandle {
    const NAME: &'static str = "QueryTTF";
    type Mutable = Readable;
    fn constructor(_: &Ctx<'js>) -> rquickjs::Result<Option<rquickjs::function::Constructor<'js>>> {
        Ok(None)
    }
}

enum FontArg {
    Text(String),
    Bytes(Vec<u8>),
    None,
}
impl<'js> FromJs<'js> for FontArg {
    fn from_js(ctx: &Ctx<'js>, value: Value<'js>) -> rquickjs::Result<Self> {
        if value.is_string() {
            return Ok(Self::Text(String::from_js(ctx, value)?));
        }
        if rquickjs::TypedArray::<u8>::from_value(value.clone()).is_ok()
            || rquickjs::TypedArray::<i8>::from_value(value.clone()).is_ok()
        {
            return Ok(Self::Bytes(
                crate::quickjs_bytes::ByteArray::from_js(ctx, value)?.0,
            ));
        }
        // 上游Any只识别String与原生ByteArray；不对普通对象/数组执行ToString或JSON转换。
        Ok(Self::None)
    }
}
fn flag(ctx: &Ctx<'_>, values: &[Value<'_>], default: bool) -> rquickjs::Result<bool> {
    match values {
        [] => Ok(default),
        [value] => value
            .as_bool()
            .ok_or_else(|| rquickjs::Exception::throw_type(ctx, "字体开关必须为Boolean")),
        _ => Err(rquickjs::Exception::throw_type(
            ctx,
            "字体接口参数数量不匹配",
        )),
    }
}
fn local_path(text: &str) -> Option<&str> {
    if let Some(path) = text.strip_prefix("file://") {
        return Some(path);
    }
    if std::path::Path::new(text).is_absolute()
        || (text.as_bytes().get(1) == Some(&b':')
            && matches!(text.as_bytes().get(2), Some(b'/' | b'\\')))
    {
        return Some(text);
    }
    None
}
fn query<'js>(
    ctx: &Ctx<'js>,
    http: &HttpResources,
    input: FontArg,
    use_cache: bool,
    allow_file: bool,
) -> rquickjs::Result<Value<'js>> {
    let result = match input {
        FontArg::None => return Ok(Value::new_null(ctx.clone())),
        FontArg::Bytes(bytes) => http.fonts().query_bytes(&bytes, use_cache),
        FontArg::Text(text) => {
            if !font_api::is_remote(&text)
                && let Some(path) = local_path(&text)
            {
                if !allow_file {
                    return Err(rquickjs::Exception::throw_type(
                        ctx,
                        "未授权字体本地文件访问",
                    ));
                }
                let result = super::file_utils::read_file_bytes(path)
                    .and_then(|bytes| bytes.ok_or_else(|| "字体文件不存在".to_string()));
                result.and_then(|bytes| http.fonts().query_bytes(&bytes, use_cache))
            } else {
                http.fonts().query_ttf(
                    &|url| {
                        let evaluator = rule_request::ContextEvaluator::new(ctx.clone())
                            .map_err(|e| e.to_string())?;
                        rule_request::execute_bytes(&http.request(), url, &evaluator)
                    },
                    &text,
                    use_cache,
                )
            }
        }
    };
    let font = result.map_err(|error| rquickjs::Exception::throw_message(ctx, &error))?;
    Class::instance(ctx.clone(), FontHandle(font))?.into_js(ctx)
}
fn extract<'js>(ctx: &Ctx<'js>, value: Value<'js>) -> rquickjs::Result<Option<Arc<QueryTtf>>> {
    if value.is_null() || value.is_undefined() {
        return Ok(None);
    }
    let class = Class::<FontHandle>::from_js(ctx, value)?;
    let font = class.try_borrow()?.0.clone();
    Ok(Some(font))
}

pub(super) fn register<'js>(
    ctx: &Ctx<'js>,
    java: &Object<'js>,
    globals: &Object<'js>,
    http: &Arc<HttpResources>,
    allow_file: bool,
) -> Result<(), LegadoError> {
    mount_dual(
        java,
        globals,
        "queryTTF",
        {
            let http = http.clone();
            rquickjs::Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, input: FontArg, rest: rquickjs::function::Rest<Value<'js>>| {
                    let use_cache = flag(&ctx, &rest.0, true)?;
                    query(&ctx, &http, input, use_cache, allow_file)
                },
            )
        }
        .map_err(|e| LegadoError::JsEngine(e.to_string()))?,
    )?;
    mount_dual(
        java,
        globals,
        "queryBase64TTF",
        {
            let http = http.clone();
            rquickjs::Function::new(
                ctx.clone(),
                move |ctx: Ctx<'js>, input: super::coerce::RhinoOptStr| {
                    query(
                        &ctx,
                        &http,
                        input.0.map_or(FontArg::None, FontArg::Text),
                        true,
                        allow_file,
                    )
                },
            )
        }
        .map_err(|e| LegadoError::JsEngine(e.to_string()))?,
    )?;
    mount_dual(
        java,
        globals,
        "replaceFont",
        rquickjs::Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>,
                  text: super::coerce::RhinoStr,
                  error: Value<'js>,
                  correct: Value<'js>,
                  rest: rquickjs::function::Rest<Value<'js>>| {
                let filter = flag(&ctx, &rest.0, false)?;
                let error = extract(&ctx, error)?;
                let correct = extract(&ctx, correct)?;
                Ok::<_, rquickjs::Error>(FontResources::replace_font(
                    &text,
                    error.as_deref(),
                    correct.as_deref(),
                    filter,
                ))
            },
        )
        .map_err(|e| LegadoError::JsEngine(e.to_string()))?,
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn font_boundary_native_handle_is_released_after_gc_even_in_a_js_cycle() {
        let bytes = super::super::font_api::tests::build_minimal_ttf(
            &[super::super::font_api::tests::Segment {
                start: 65,
                end: 65,
                id_delta: -64,
            }],
            false,
        );
        let font = Arc::new(QueryTtf::parse(&bytes).unwrap());
        let weak = Arc::downgrade(&font);
        let runtime = rquickjs::Runtime::new().unwrap();
        let context = rquickjs::Context::full(&runtime).unwrap();
        context.with(|ctx| {
            let class = Class::instance(ctx.clone(), FontHandle(font)).unwrap();
            ctx.globals().set("font", class).unwrap();
            ctx.eval::<(), _>("font.self=font; font=null;").unwrap();
        });
        runtime.run_gc();
        assert!(weak.upgrade().is_none());
    }

    struct FontServer {
        url: String,
        requests: Arc<std::sync::Mutex<Vec<String>>>,
        stopped: Arc<std::sync::atomic::AtomicBool>,
        worker: Option<std::thread::JoinHandle<()>>,
    }
    impl FontServer {
        fn new() -> Self {
            use std::io::{Read, Write};
            use std::sync::atomic::{AtomicBool, Ordering};
            let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
            listener.set_nonblocking(true).unwrap();
            let url = format!("http://{}", listener.local_addr().unwrap());
            let requests = Arc::new(std::sync::Mutex::new(Vec::new()));
            let stopped = Arc::new(AtomicBool::new(false));
            let collected = requests.clone();
            let stop = stopped.clone();
            let bytes = super::super::font_api::tests::build_minimal_ttf(
                &[super::super::font_api::tests::Segment {
                    start: 0xE001,
                    end: 0xE001,
                    id_delta: 0x2000,
                }],
                false,
            );
            let worker = std::thread::spawn(move || {
                while !stop.load(Ordering::Acquire) {
                    let (mut socket, _) = match listener.accept() {
                        Ok(pair) => pair,
                        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            std::thread::sleep(std::time::Duration::from_millis(2));
                            continue;
                        }
                        Err(e) => panic!("字体HTTP夹具接收失败: {e}"),
                    };
                    socket.set_nonblocking(false).unwrap();
                    socket
                        .set_read_timeout(Some(std::time::Duration::from_secs(2)))
                        .unwrap();
                    socket
                        .set_write_timeout(Some(std::time::Duration::from_secs(2)))
                        .unwrap();
                    let mut head = Vec::new();
                    while !head.ends_with(b"\r\n\r\n") {
                        let mut byte = [0];
                        socket.read_exact(&mut byte).unwrap();
                        head.push(byte[0]);
                        assert!(head.len() < 65536);
                    }
                    let head = String::from_utf8(head).unwrap();
                    let length = head
                        .lines()
                        .filter_map(|line| line.split_once(':'))
                        .find(|(key, _)| key.eq_ignore_ascii_case("Content-Length"))
                        .map(|(_, value)| value.trim().parse::<usize>().unwrap())
                        .unwrap_or(0);
                    assert!(length < 65536);
                    let mut body = vec![0; length];
                    socket.read_exact(&mut body).unwrap();
                    let mut log = collected.lock().unwrap();
                    log.push(format!("{}{}", head, String::from_utf8(body).unwrap()));
                    let payload = if head.contains("/retry.ttf") && log.len() == 1 {
                        vec![0, 1]
                    } else {
                        bytes.clone()
                    };
                    drop(log);
                    write!(
                        socket,
                        "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                        payload.len()
                    )
                    .unwrap();
                    socket.write_all(&payload).unwrap();
                }
            });
            Self {
                url,
                requests,
                stopped,
                worker: Some(worker),
            }
        }
    }
    impl Drop for FontServer {
        fn drop(&mut self) {
            self.stopped
                .store(true, std::sync::atomic::Ordering::Release);
            self.worker.take().unwrap().join().unwrap();
        }
    }

    #[test]
    fn font_boundary_rules_share_post_headers_cookie_and_current_vm_without_cache_locks() {
        use super::super::current_source::with_current_source_tag;
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        use base64::Engine;
        let server = FontServer::new();
        let vm = QuickJsEngine::new(SandboxConfig::default().with_allow_script_run(true)).unwrap();
        let correct = super::super::font_api::tests::build_minimal_ttf(
            &[super::super::font_api::tests::Segment {
                start: 65,
                end: 65,
                id_delta: -64,
            }],
            false,
        );
        let good = base64::engine::general_purpose::STANDARD.encode(correct);
        let rule = format!(
            "{}/error.ttf,{}",
            server.url,
            serde_json::json!({"method":"POST","body":"{{java.queryBase64TTF(globalThis.good); 'payload'}}","headers":{"X-Marker":"{{'font'}}"},"type":"hex","bodyJs":"throw Error('不能做正文求值')"})
        );
        let rule_json = serde_json::to_string(&rule).unwrap();
        let script = format!(
            "globalThis.good={}; globalThis.result='outer'; java.putGlobalHeaders(JSON.stringify({{'X-Source':'source','Cookie':'session=font'}}));var error=queryTTF({rule_json});var correct=java.queryBase64TTF(good);JSON.stringify([java.replaceFont('\\uE001',error,correct),result]);",
            serde_json::to_string(&good).unwrap()
        );
        assert_eq!(
            with_current_source_tag(&server.url, || vm.eval(&script)).unwrap(),
            r#"["A","outer"]"#
        );
        with_current_source_tag(&server.url, || {
            vm.eval(&format!(
                "queryTTF({rule_json}); queryTTF({rule_json},false)"
            ))
        })
        .unwrap();
        assert_eq!(server.requests.lock().unwrap().len(), 2);
        for request in server.requests.lock().unwrap().iter() {
            assert!(request.starts_with("POST /error.ttf "));
            assert!(request.ends_with("payload"));
            let lower = request.to_ascii_lowercase();
            assert!(lower.contains("x-marker: font"));
            assert!(lower.contains("x-source: source"));
            assert!(lower.contains("cookie: session=font"));
        }
    }

    #[test]
    fn font_boundary_failed_download_parse_is_not_cached_and_retry_recovers() {
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        let server = FontServer::new();
        let vm = QuickJsEngine::new(SandboxConfig::default()).unwrap();
        let url = serde_json::to_string(&format!("{}/retry.ttf", server.url)).unwrap();
        assert!(vm.eval(&format!("queryTTF({url})")).is_err());
        assert_eq!(
            vm.eval(&format!("typeof queryTTF({url})")).unwrap(),
            "object"
        );
        assert_eq!(
            vm.eval(&format!("typeof queryTTF({url})")).unwrap(),
            "object"
        );
        assert_eq!(server.requests.lock().unwrap().len(), 2);
    }

    #[test]
    fn font_boundary_invalid_byte_views_throw_without_retaining_borrowed_buffers() {
        use crate::{JsEngine, QuickJsEngine, SandboxConfig};
        let vm = QuickJsEngine::new(SandboxConfig::default().with_allow_script_run(true)).unwrap();
        for prepare in [
            "var b=new ArrayBuffer(4,{maxByteLength:8}); var v=new Uint8Array(b,0,4);b.resize(1);",
            "var b=new ArrayBuffer(4);var v=new Uint8Array(b);b.transfer();",
        ] {
            assert_eq!(
                vm.eval(&format!(
                    "{prepare} try {{queryTTF(v);'bad'}} catch(e){{'caught'}}"
                ))
                .unwrap(),
                "caught"
            );
            assert_eq!(vm.eval("1+1").unwrap(), "2");
        }
    }
}
