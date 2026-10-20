//! 图片宿主适配：书源文档解析与资源装配，业务委托Engine。
use legado_core::{LegadoError, LegadoResult, models::BookSource};
use legado_engine::image_service::ImageService;

/// 解密入口保留供宿主内部调用，不加载数据库或网络运行时。
pub fn decode_image_bytes(source: &BookSource, img_url: &str, bytes: &[u8]) -> Vec<u8> {
    ImageService::new(crate::engine_holder::js_resources())
        .decode_image_bytes(source, img_url, bytes)
}

pub fn fetch_image_with_decode(url: &str, source_json: &str) -> LegadoResult<Vec<u8>> {
    let source: BookSource = serde_json::from_str(source_json)
        .map_err(|e| LegadoError::Ffi(format!("书源 JSON 解析失败: {e}")))?;
    ImageService::new(crate::engine_holder::js_resources()).fetch_image_with_decode(
        url,
        &source,
        &crate::engine_holder::network(),
        crate::runtime::get_runtime().handle(),
    )
}

#[cfg(all(test, feature = "quickjs"))]
mod tests {
    use super::*;
    /// P2-19 回归面（2026-09-23 上游同步改写）：imageDecode 执行路径的
    /// `java.ajax` 必须携带**请求 URL 属域**的 cookie（上游语义：cookie
    /// 属于域名而非书源，读侧按请求 URL 属域取 `cookie_store::cookies_for_url`，
    /// 去掉书源 tag 维度）；不相关域名的 cookie 绝不携带（P2-19 核心不变式
    /// 保留）；旧「本源携带 / 跨源不泄漏」口径随用户裁决同步上游而改写。
    ///
    /// 机制：imageDecode 规则内 `java.ajax` 打到回环 cookie-记录服务器
    /// （std TcpListener，P2-17 同款模式），服务器把收到的 `Cookie` 请求头
    /// 记入共享状态；`decode_image_bytes` 内部 `with_current_source_tag` 绑定
    /// （本文件修复点）不再承载 cookie scope（保留供 global_headers / 书源
    /// 上下文）；回环域名键（127.0.0.1，IP 自键）与 js_executor P2-19 用例
    /// 共享，须持全局存储锁串行。
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_p219_image_decode_path_carries_request_domain_cookie() {
        use std::io::{Read, Write};
        use std::sync::{Arc, Mutex};

        let http = crate::engine_holder::js_resources()
            .http_resources()
            .clone();

        // 回环域名键（127.0.0.1）为进程级共享键，与 js_executor P2-19 用例串行
        let _lock = crate::test_support::GLOBAL_STORE_TEST_LOCK
            .lock()
            .unwrap_or_else(|p| p.into_inner());

        // 回环 cookie 记录服务器：记录收到的 Cookie 请求头（忽略请求 body）
        let seen: Arc<Mutex<Option<String>>> = Arc::new(Mutex::new(None));
        let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind 127.0.0.1:0");
        let addr = listener.local_addr().expect("local_addr");
        let seen_srv = seen.clone();
        std::thread::spawn(move || {
            for stream in listener.incoming().take(4) {
                let Ok(mut sock) = stream else { continue };
                let _ = sock.set_read_timeout(Some(std::time::Duration::from_secs(10)));
                let mut head: Vec<u8> = Vec::new();
                let mut byte = [0u8; 1];
                while !head.ends_with(b"\r\n\r\n") {
                    if sock.read_exact(&mut byte).is_err() {
                        break;
                    }
                    head.push(byte[0]);
                    if head.len() > 65_536 {
                        break;
                    }
                }
                let head_str = String::from_utf8_lossy(&head);
                let cookie = head_str.lines().find_map(|line| {
                    let (name, value) = line.split_once(':')?;
                    name.trim()
                        .eq_ignore_ascii_case("cookie")
                        .then(|| value.trim().to_string())
                });
                *seen_srv.lock().unwrap() = cookie;
                let body = r#"{"ok":1}"#;
                let resp = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                    body.len(),
                    body
                );
                let _ = sock.write_all(resp.as_bytes());
            }
        });

        // 书源上下文（引擎分桶 / with_current_source_tag 绑定）；cookie 取用不再按 tag
        const TAG: &str = "https://p219-img.example.com/";
        // 不相关域（other-site.com 与 127.0.0.1 属不同注册域）
        const OTHER_TAG: &str = "https://p219-img-other.other-site.com/";
        let url = format!("http://{addr}/echo");
        // 上游同步：携带的 cookie 键 = 请求 URL 归一域名键（127.0.0.1，IP 自键）
        http.cookies().clear(&url);
        http.cookies().clear(OTHER_TAG);
        http.set_cookie(&url, "p219_img_token=img-val-7c3e");
        http.set_cookie(OTHER_TAG, "p219_img_other=other-val-2d8a");
        let src: BookSource = serde_json::from_value(serde_json::json!({
            "bookSourceUrl": TAG,
            "bookSourceName": "t",
            "bookSourceType": 2,
            "searchUrl": "https://p219-img.example.com/search",
            "ruleSearch": {"bookList": ".x"},
            "ruleContent": {
                "content": ".x",
                // ajax 仅为副作用（验证 Cookie 头），规则仍返回原始 bytes。
                // `java.ajax` 桥接签名为 (options: String) —— 入参是 JSON 字符串
                // （非 JS 对象字面量），形态与 network.rs p219 用例一致。
                "imageDecode": format!(r#"java.ajax('{{"url":"{url}"}}'); result;"#)
            }
        }))
        .unwrap();

        let out = decode_image_bytes(&src, &url, &[0xAB, 0xCD]);
        assert_eq!(
            out,
            vec![0xAB, 0xCD],
            "imageDecode 正常返回原 bytes（ajax 仅为副作用）"
        );

        let got = seen.lock().unwrap().clone();
        assert!(
            got.as_deref()
                .unwrap_or_default()
                .contains("p219_img_token=img-val-7c3e"),
            "请求 URL 属域（127.0.0.1）cookie 必须携带，实际 Cookie 头: {got:?}"
        );
        assert!(
            !got.as_deref()
                .unwrap_or_default()
                .contains("p219_img_other"),
            "不相关域名的 cookie 绝不携带（P2-19 不变式），实际 Cookie 头: {got:?}"
        );

        http.cookies().clear(&url);
        http.cookies().clear(OTHER_TAG);
    }

    /// 真实站点链路：favcomic 图片下载 → jsLib decode → JPEG 头（需网络）
    #[cfg(feature = "quickjs")]
    #[test]
    #[ignore = "requires network access"]
    fn test_fetch_favcomic_image_decode_real() {
        let _db_guard = crate::db_state::ensure_test_db();
        let sources_json = std::fs::read_to_string("tests/fixtures/comic_source.json").unwrap();
        let sources: Vec<serde_json::Value> =
            serde_json::from_str(&sources_json).expect("书源 JSON 数组解析失败");
        let source_json = sources[0].to_string();
        let src: BookSource = serde_json::from_str(&source_json).expect("书源反序列化失败");
        crate::api::source::import_sources(&sources_json).expect("导入书源失败");

        // 搜索 → 目录 → 正文提取第一张图片 URL
        let keyword = "少女過激";
        let urls_json = format!(
            r#"["{}"]"#,
            sources[0]["bookSourceUrl"].as_str().unwrap_or_default()
        );
        let results = crate::api::search::search_books(keyword, &urls_json).unwrap();
        println!("===== [search] total={}", results.len());
        let mut img_url = String::new();
        for (_bi, first) in results.iter().enumerate().take(3) {
            println!("===== [book] {} {}", first.book_name, first.book_url);
            let toc = crate::api::reader::refresh_toc(&first.book_url, &first.source_url).unwrap();
            println!("===== [toc] chapters={}", toc.chapters.len());
            let ch = toc.chapters.first().expect("无章节");
            println!("===== [chapter] {} {}", ch.title, ch.url);
            // 诊断：直接下载章节页，检查 images 数据形态
            let raw = crate::runtime::block_on(async {
                let client = crate::http_state::shared_client().expect("shared client");
                client
                    .get_raw(&ch.url, None)
                    .await
                    .map(|r| String::from_utf8_lossy(&r.body).to_string())
            });
            let raw_html = match &raw {
                Ok(h) => h.clone(),
                Err(_) => String::new(),
            };
            if let Ok(html) = raw {
                if let Some(pos) = html.find("\"images\":") {
                    let end = html[pos..]
                        .find(']')
                        .map(|e| pos + e + 1)
                        .unwrap_or(pos + 20);
                    let after = html[end..].chars().take(8).collect::<String>();
                    println!(
                        "===== [images-ctx] webtoon={} after_arr={:?} head={:?}",
                        html.contains("\"webtoon\":1"),
                        after,
                        &html[pos..(pos + 90).min(html.len())]
                    );
                } else {
                    println!("===== [images-ctx] NOT FOUND len={}", html.len());
                }
            } else {
                println!("===== [raw-err]");
            }
            match crate::api::reader::get_chapter_content_full(&first.book_url, ch.index) {
                Ok(content) => {
                    println!(
                        "===== [content] len={} head={:?}",
                        content.len(),
                        &content[..content.len().min(120)]
                    );
                    // 取第一张图片 URL 做下载解码验证
                    if img_url.is_empty() {
                        for line in content.lines() {
                            if let Some(pos) = line.find("<img src=\"") {
                                let rest = &line[pos + 10..];
                                if let Some(end) = rest.find('"') {
                                    img_url = rest[..end].to_string();
                                    break;
                                }
                            }
                        }
                    }
                }
                Err(e) => {
                    println!("===== [content-err] {e}");
                    // 诊断：直接调 parse_content_page_with_js_lib 捕获真实错误
                    let rc = src.rule_content.as_ref();
                    let rule = rc.and_then(|r| r.content.as_deref()).unwrap_or("");
                    let diag = crate::js_executor::construct_analyzer_with_js_lib(
                        raw_html.clone(),
                        ch.url.clone(),
                        &first.source_url,
                        src.js_lib.as_deref(),
                    );
                    let list = diag.get_strings(rule);
                    println!(
                        "===== [parse-diag] {:?}",
                        list.as_ref().map(|v| (v.len(), v.first().map(|s| s.len())))
                    );
                }
            }
        }
        assert!(!img_url.is_empty(), "正文无 img URL");

        // 下载 + 解码
        let bytes = fetch_image_with_decode(&img_url, &source_json).unwrap();
        println!(
            "===== [decoded] len={} head={:02X?} url={}",
            bytes.len(),
            &bytes[..bytes.len().min(8)],
            img_url
        );
        // 解码后应为有效图片（JPEG FFD8 / PNG 8950 / GIF 4749）
        let is_image = bytes.len() > 4
            && (bytes[0] == 0xFF && bytes[1] == 0xD8
                || bytes[0] == 0x89 && bytes[1] == 0x50
                || bytes[0] == 0x47 && bytes[1] == 0x49);
        assert!(is_image, "解码后不是有效图片头");
    }
}
