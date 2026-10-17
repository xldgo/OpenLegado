use super::*;
fn decode_image_bytes(source: &BookSource, url: &str, bytes: &[u8]) -> Vec<u8> {
    ImageService::new(Default::default()).decode_image_bytes(source, url, bytes)
}
/// 复合图片 URL（url,{json headers}）拆分：真实 URL + 内嵌 headers
#[test]
fn test_split_composite_image_url() {
    // favcomic 风格：内嵌 User-Agent/Referer/x-requested-with
    let (url, headers) = split_composite_image_url(
        r#"https://cdn.favcomic.net/file/e-media/image/comic/1/1.webp,{"headers":{"User-Agent":"Mozilla/5.0","Referer":"https://cdn.favcomic.net/","x-requested-with":"XBrowser"}}"#,
    );
    assert_eq!(
        url,
        "https://cdn.favcomic.net/file/e-media/image/comic/1/1.webp"
    );
    assert_eq!(
        headers.get("User-Agent").map(|s| s.as_str()),
        Some("Mozilla/5.0")
    );
    assert_eq!(
        headers.get("Referer").map(|s| s.as_str()),
        Some("https://cdn.favcomic.net/")
    );
    assert_eq!(
        headers.get("x-requested-with").map(|s| s.as_str()),
        Some("XBrowser")
    );

    // 扁平 JSON 若不包裹 headers 字段则按 AnalyzeUrl 语义不解析 headers
    //（favcomic 实际使用 {"headers":{...}} 包裹格式，上方已覆盖）
    let (url2, _headers2) = split_composite_image_url(
        r#"https://img.example.com/1.jpg,{"Referer":"https://img.example.com/"}"#,
    );
    assert_eq!(url2, "https://img.example.com/1.jpg");

    // 无复合段：原样返回
    let (url3, headers3) = split_composite_image_url("https://img.example.com/2.jpg");
    assert_eq!(url3, "https://img.example.com/2.jpg");
    assert!(headers3.is_empty());
}

/// 无 imageDecode 规则时原样返回
#[test]
fn test_decode_no_rule_returns_original() {
    let src: BookSource = serde_json::from_str(
            r#"{"bookSourceUrl":"https://a.example.com","bookSourceName":"t","bookSourceType":0,"searchUrl":"https://a.example.com/search?q={{key}}","ruleSearch":{"bookList":".x"}}"#,
        )
        .unwrap();
    let out = decode_image_bytes(&src, "https://a.example.com/1.jpg", &[1, 2, 3]);
    assert_eq!(out, vec![1, 2, 3]);
}

/// 默认 Referer：无尾斜杠纯域名不得截成 https:
#[test]
fn test_default_referer_domain_only() {
    assert_eq!(
        default_referer_from_source_url("https://site.com"),
        Some("https://site.com/".to_string())
    );
    assert_eq!(
        default_referer_from_source_url("https://site.com/"),
        Some("https://site.com/".to_string())
    );
    assert_eq!(
        default_referer_from_source_url("https://site.com/path/page"),
        Some("https://site.com/path/".to_string())
    );
    assert_eq!(default_referer_from_source_url(""), None);
}

#[test]
fn test_looks_like_image_bytes() {
    assert!(looks_like_image_bytes(&[0xFF, 0xD8, 0xFF, 0xE0]));
    assert!(looks_like_image_bytes(&[0x89, 0x50, 0x4E, 0x47]));
    assert!(!looks_like_image_bytes(&[1, 2, 3, 4]));
    assert!(!looks_like_image_bytes(&[]));
}

/// imageDecode 规则 + jsLib 解密：bytes 注入为 Uint8Array，JS 按位翻转后返回
#[cfg(feature = "quickjs")]
#[test]
fn test_decode_with_js_lib_xor() {
    let src: BookSource = serde_json::from_str(
            r#"{
              "bookSourceUrl":"https://b.example.com",
              "bookSourceName":"t",
              "bookSourceType":2,
              "searchUrl":"https://b.example.com/search?q={{key}}",
              "ruleSearch":{"bookList":".x"},
              "jsLib":"function decode(b){var o=new Uint8Array(b.length);for(var i=0;i<b.length;i++){o[i]=b[i]^0xFF;}return o;}",
              "ruleContent":{"content":".x","imageDecode":"decode(result);"}
            }"#,
        )
        .unwrap();
    let out = decode_image_bytes(&src, "https://b.example.com/1.jpg", &[0xAA, 0x00, 0x7F]);
    assert_eq!(out, vec![0x55, 0xFF, 0x80]);
}

/// 仅有 imageDecode、无 jsLib：规则内联仍应执行（不强制 jsLib）
#[cfg(feature = "quickjs")]
#[test]
fn test_decode_rule_only_without_js_lib() {
    let src: BookSource = serde_json::from_str(
            r#"{
              "bookSourceUrl":"https://c.example.com",
              "bookSourceName":"t",
              "bookSourceType":2,
              "searchUrl":"https://c.example.com/search?q={{key}}",
              "ruleSearch":{"bookList":".x"},
              "ruleContent":{"content":".x","imageDecode":"var o=new Uint8Array(result.length);for(var i=0;i<result.length;i++){o[i]=result[i]^0x0F;}o;"}
            }"#,
        )
        .unwrap();
    let out = decode_image_bytes(&src, "https://c.example.com/1.jpg", &[0x10, 0x20]);
    assert_eq!(out, vec![0x1F, 0x2F]);
}

/// 设备取证回归：51漫画真实 CDN 密文（非自造最小 JPEG）经同款 imageDecode 出 JPEG
///
/// 证据：`pic.xmbvxj.cn` 下载 len=346224 magic=4FE8…；桌面 AES/CBC/NoPadding
/// 解密后 FFD8 + PIL 可开。若 Android jniLibs 未重编含 createSymmetricCrypto 对象
/// 的 .so，实机仍会 FlutterImageDecoder 刷屏。— Reasonix
#[cfg(feature = "quickjs")]
#[test]
fn test_decode_51manga_real_ciphertext_fixture() {
    let fixture = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../legado-ffi/tests/fixtures/51manga_page_cipher.bin");
    if !fixture.is_file() {
        eprintln!("skip: 无设备密文夹具 {}", fixture.display());
        return;
    }
    let cipher = std::fs::read(&fixture).expect("read fixture");
    assert_eq!(cipher.len() % 16, 0);
    assert!(
        !looks_like_image_bytes(&cipher),
        "夹具应为密文，got magic={:02X?}",
        &cipher[..cipher.len().min(4)]
    );
    let image_decode = r#"function decryptImage(src) {
    const key = "102_53_100_57_54_53_100_102_55_53_51_51_54_50_55_48"
        .split("_").map(n => String.fromCharCode(parseInt(n))).join("");
    const iv  = "57_55_98_54_48_51_57_52_97_98_99_50_102_98_101_49"
        .split("_").map(n => String.fromCharCode(parseInt(n))).join("");
    const cipher = java.createSymmetricCrypto("AES/CBC/NoPadding", key, iv)
    return cipher.decrypt(src);
}
decryptImage(result);"#;
    let src: BookSource = serde_json::from_value(serde_json::json!({
        "bookSourceUrl": "https://51acgs.com",
        "bookSourceName": "51漫画",
        "bookSourceType": 2,
        "searchUrl": "https://51acgs.com/search",
        "ruleSearch": {"bookList": ".x"},
        "ruleContent": {"content": ".comics@img@html", "imageDecode": image_decode}
    }))
    .unwrap();
    let out = decode_image_bytes(&src, "https://pic.xmbvxj.cn/1.jpeg", &cipher);
    assert!(
        looks_like_image_bytes(&out),
        "真实密文解密后应有 JPEG 魔数，got {:02X?}",
        &out[..out.len().min(4)]
    );
    assert_eq!(&out[..2], &[0xFF, 0xD8]);
}

/// 离线对齐 51漫画 imageDecode：AES/CBC/NoPadding + createSymmetricCrypto.decrypt
/// （规则片段来自设备书源 https://51acgs.com，密文由同 key/iv 加密最小 JPEG）
#[cfg(feature = "quickjs")]
#[test]
fn test_decode_51manga_style_aes_nopadding_offline() {
    use legado_core::crypto::AesCrypto;

    // 最小 JPEG 头 + 填充到 16 字节对齐（NoPadding 要求）
    let plain = vec![
        0xFF, 0xD8, 0xFF, 0xD9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00,
    ];
    assert_eq!(plain.len() % 16, 0);
    let key = b"f5d965df75336270"; // 书源 key 码点串还原
    let iv = b"97b60394abc2fbe1";
    let cipher = AesCrypto::encrypt_cbc_nopadding(key, iv, &plain).expect("encrypt");

    let image_decode = r#"function decryptImage(src) {
    const key = "102_53_100_57_54_53_100_102_55_53_51_51_54_50_55_48"
        .split("_").map(n => String.fromCharCode(parseInt(n))).join("");
    const iv  = "57_55_98_54_48_51_57_52_97_98_99_50_102_98_101_49"
        .split("_").map(n => String.fromCharCode(parseInt(n))).join("");
    const cipher = java.createSymmetricCrypto("AES/CBC/NoPadding", key, iv)
    return cipher.decrypt(src);
}
decryptImage(result);"#;

    let src: BookSource = serde_json::from_value(serde_json::json!({
        "bookSourceUrl": "https://51acgs.com",
        "bookSourceName": "51漫画",
        "bookSourceType": 2,
        "searchUrl": "https://51acgs.com/search/result/comics?keyword={{key}}&page={{page}}",
        "ruleSearch": {"bookList": ".x"},
        "ruleContent": {"content": ".comics@img@html", "imageDecode": image_decode}
    }))
    .unwrap();

    let out = decode_image_bytes(&src, "https://pic.example.com/1.jpeg", &cipher);
    assert!(
        looks_like_image_bytes(&out),
        "51 规则解密后应有 JPEG 魔数，got {:02X?}",
        &out[..out.len().min(4)]
    );
    assert_eq!(&out[..2], &[0xFF, 0xD8]);
    let _ = plain; // 明文长度与密文一致即可，尾部 padding 保留
}

/// 同源连续 decode 两次：每次新引擎，顶层 const 不 redeclaration
#[cfg(feature = "quickjs")]
#[test]
fn test_decode_twice_no_redeclaration() {
    let src: BookSource = serde_json::from_str(
        r#"{
              "bookSourceUrl":"https://d.example.com",
              "bookSourceName":"t",
              "bookSourceType":2,
              "searchUrl":"https://d.example.com/search?q={{key}}",
              "ruleSearch":{"bookList":".x"},
              "ruleContent":{"content":".x","imageDecode":"const k=1; result;"}
            }"#,
    )
    .unwrap();
    let service = ImageService::new(Default::default());
    let a = service.decode_image_bytes(&src, "https://d.example.com/1.jpg", &[1, 2]);
    let b = service.decode_image_bytes(&src, "https://d.example.com/2.jpg", &[3, 4]);
    assert_eq!(a, vec![1, 2]);
    assert_eq!(b, vec![3, 4]);
}

#[test]
fn decode_failure_and_empty_result_keep_original_bytes() {
    let service = ImageService::new(Default::default());
    for rule in ["throw new Error('解密失败');", "new Uint8Array(0);"] {
        let source: BookSource = serde_json::from_value(serde_json::json!({
            "bookSourceUrl": "https://image.test", "bookSourceName": "回退",
            "ruleContent": { "imageDecode": rule }
        }))
        .unwrap();
        assert_eq!(
            service.decode_image_bytes(&source, "https://image.test/p", &[1, 2, 255]),
            [1, 2, 255]
        );
    }
}

#[cfg(feature = "quickjs")]
#[test]
fn fetch_and_decode_use_supplied_network_and_js_resources() {
    use crate::{NetworkContext, test_http_fixture::Fixture};
    use std::sync::Arc;
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let mut fixture = Fixture::new(4, false, |_| "GIF8payload".into());
    let first = Arc::new(NetworkContext::default());
    let second = Arc::new(NetworkContext::default());
    // 这里只验证网络资源隔离，不调用要求数据库的显式持久化入口。
    first
        .cookie_store()
        .write()
        .unwrap()
        .set_cookies_from_string("127.0.0.1", "image_scope=first");
    second
        .cookie_store()
        .write()
        .unwrap()
        .set_cookies_from_string("127.0.0.1", "image_scope=second");
    let url = format!(
        "{}/page,{{\"headers\":{{\"X-Image\":\"embedded\"}}}}",
        fixture.url
    );
    let source: BookSource = serde_json::from_value(serde_json::json!({
        "bookSourceUrl": format!("{}/source", fixture.url), "bookSourceName": "资源归属",
        "header": "X-Image: source\nX-Keep: yes", "enabledCookieJar": false,
        "jsLib": "throw new Error('可选库失败仍执行内联解密');",
        "ruleContent": { "imageDecode": format!(
            "java.ajax({}); if (src !== {}) throw new Error('完整URL丢失'); result[4] = 88; result;",
            serde_json::to_string(&format!("{}/key", fixture.url)).unwrap(),
            serde_json::to_string(&url).unwrap()
        ) }
    }))
    .unwrap();
    for (network, expected, forbidden) in
        [(&first, "first", "second"), (&second, "second", "first")]
    {
        let js = legado_js::JsResources::default().with_http_resources(network.js_http_resources());
        let service = ImageService::new(Arc::new(js));
        assert_eq!(
            service
                .fetch_image_with_decode(&url, &source, network, runtime.handle())
                .unwrap(),
            b"GIF8Xayload"
        );
        let image = runtime.block_on(fixture.request()).to_ascii_lowercase();
        assert!(image.starts_with("get /page http/1.1"));
        assert!(image.contains("x-image: embedded"));
        assert!(image.contains("x-keep: yes"));
        assert!(image.contains(&format!("referer: {}/", fixture.url)));
        assert!(image.contains(&format!("image_scope={expected}")));
        assert!(!image.contains(&format!("image_scope={forbidden}")));
        let key = runtime.block_on(fixture.request()).to_ascii_lowercase();
        assert!(key.starts_with("get /key http/1.1"));
        assert!(key.contains(&format!("image_scope={expected}")));
        assert!(!key.contains(&format!("image_scope={forbidden}")));
    }
    fixture.worker.join().unwrap();
}
