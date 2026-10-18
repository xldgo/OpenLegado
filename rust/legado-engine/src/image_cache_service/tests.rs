use super::*;
use std::sync::atomic::AtomicUsize;
static COUNTER: AtomicUsize = AtomicUsize::new(0);
/// 进程级唯一临时根目录（测试收尾 remove_dir_all 清理）
fn unique_root(tag: &str) -> PathBuf {
    let n = COUNTER.fetch_add(1, Ordering::Relaxed);
    std::env::temp_dir().join(format!(
        "legado-image-cache-test-{}-{}-{}",
        std::process::id(),
        n,
        tag
    ))
}

// 存/取/命中：roundtrip
#[test]
fn save_get_roundtrip() {
    let root = unique_root("roundtrip");
    let service = ImageCacheService::new(root.clone());
    let bytes: Vec<u8> = (0..256u16).map(|i| (i % 251) as u8).collect();
    assert!(
        service.save_image_cache("https://a.com/book/1", "https://cdn.com/p1.webp", &bytes),
        "写入应成功"
    );
    let got = service.get_image_cache("https://a.com/book/1", "https://cdn.com/p1.webp");
    assert_eq!(got.as_deref(), Some(bytes.as_slice()), "命中应返回原字节");
    let _ = fs::remove_dir_all(&root);
}

// 未命中：全新目录 get 返回 None
#[test]
fn get_miss_returns_none() {
    let root = unique_root("miss");
    let service = ImageCacheService::new(root.clone());
    assert!(
        service
            .get_image_cache("https://a.com/book/9", "https://cdn.com/x.jpg")
            .is_none(),
        "未写入应未命中"
    );
    let _ = fs::remove_dir_all(&root);
}

// MD5 命名：文件落在 {root}/{bookdir}/images/{md5_mid16(url)}.{suffix}
#[test]
fn md5_naming_layout() {
    let root = unique_root("md5");
    let service = ImageCacheService::new(root.clone());
    let url = "https://cdn.com/img/page-001.webp?v=2";
    assert!(service.save_image_cache("https://a.com/book/7", url, b"png-bytes"));
    let hex = legado_core::crypto::md5_hex(url);
    let expected = root
        .join(book_dir_name("https://a.com/book/7"))
        .join(IMAGES_DIR)
        .join(format!("{}.webp", &hex[8..24]));
    assert!(
        expected.exists(),
        "文件应落在 MD5 中段 16 字符命名路径：{expected:?}"
    );
    assert_eq!(fs::read(&expected).unwrap(), b"png-bytes");
    let _ = fs::remove_dir_all(&root);
}

// 后缀推导（对齐原版 UrlUtil.getSuffix(src, "jpg")）
#[test]
fn suffix_rules() {
    assert_eq!(image_suffix("https://x.com/a/b.webp?q=1"), "webp");
    assert_eq!(image_suffix("https://x.com/a/b.PNG"), "PNG");
    assert_eq!(image_suffix("https://x.com/a/b?sig=abc.def"), "jpg");
    assert_eq!(image_suffix("https://x.com/a/b"), "jpg");
    assert_eq!(image_suffix("https://x.com/a/b.gif#frag"), "gif");
    // 后缀 >5 字符（5 字符合法）或含非法字符 → 缺省 jpg
    assert_eq!(image_suffix("https://x.com/a/b.tiffy"), "tiffy");
    assert_eq!(image_suffix("https://x.com/a/b.tiffy6"), "jpg");
    assert_eq!(image_suffix("https://x.com/a/b.tar.gz"), "gz");
    assert_eq!(image_suffix("https://x.com/a/b.a_b"), "jpg");
    // 末段以 . 结尾（空后缀）→ 缺省 jpg
    assert_eq!(image_suffix("https://x.com/a/b."), "jpg");
}

// 写失败降级：根目录被普通文件占用 → create_dir_all 失败
#[test]
fn write_fail_degrades_to_false() {
    let root = unique_root("writefail");
    fs::create_dir_all(root.parent().unwrap()).unwrap();
    fs::write(&root, b"i-am-a-file").unwrap();
    let service = ImageCacheService::new(root.clone());
    assert!(
        !service.save_image_cache("https://a.com/book/2", "https://cdn.com/y.jpg", b"x"),
        "根目录被文件占用时写入应降级 false（不抛异常）"
    );
    assert!(
        service
            .get_image_cache("https://a.com/book/2", "https://cdn.com/y.jpg")
            .is_none(),
        "写失败后读取应未命中"
    );
    fs::remove_file(&root).ok();
}

// 路径隔离：不同 bookUrl 互不串缓存
#[test]
fn path_isolation_by_book_url() {
    let root = unique_root("isolation");
    let service = ImageCacheService::new(root.clone());
    let url = "https://cdn.com/same.jpg";
    assert!(service.save_image_cache("https://a.com/book/A", url, b"bookA"));
    assert_eq!(
        service
            .get_image_cache("https://a.com/book/A", url)
            .as_deref(),
        Some(b"bookA".as_slice()),
        "书 A 应命中自己的缓存"
    );
    assert!(
        service
            .get_image_cache("https://a.com/book/B", url)
            .is_none(),
        "书 B 不得读到书 A 的缓存（目录按 bookUrl 隔离）"
    );
    // 两书目录名不同且各自含 md5_8 后缀
    assert_ne!(
        book_dir_name("https://a.com/book/A"),
        book_dir_name("https://a.com/book/B")
    );
    let _ = fs::remove_dir_all(&root);
}

// 超长 bookUrl：截断 + md5_8 后缀保证不同 URL 不同目录
#[test]
fn long_book_url_truncation_isolated() {
    let long_a = "https://site.example/very/long/path/".to_string() + &"a".repeat(200);
    let long_b = long_a.replace('a', "b");
    assert_ne!(
        book_dir_name(&long_a),
        book_dir_name(&long_b),
        "截断后 md5_8 后缀必须区分仅尾部不同的 bookUrl"
    );
}

#[test]
fn explicit_roots_isolate_same_keys_and_keep_empty_and_io_error_semantics() {
    let first_root = unique_root("first");
    let second_root = unique_root("second");
    let a = ImageCacheService::new(first_root.clone());
    let b = ImageCacheService::new(second_root.clone());
    assert!(a.save_image_cache("书", "https://image.test/p", b"first"));
    assert!(b.get_image_cache("书", "https://image.test/p").is_none());
    assert!(b.save_image_cache("书", "https://image.test/p", b"second"));
    assert_eq!(
        a.get_image_cache("书", "https://image.test/p").unwrap(),
        b"first"
    );
    assert_eq!(
        b.get_image_cache("书", "https://image.test/p").unwrap(),
        b"second"
    );
    assert!(a.save_image_cache("书", "empty", b""));
    assert_eq!(a.get_image_cache("书", "empty"), Some(vec![]));
    let path = a.image_file_path("书", "read-failure");
    fs::create_dir_all(&path).unwrap();
    assert!(a.get_image_cache("书", "read-failure").is_none());
    assert!(!a.save_image_cache("书", "read-failure", b"no"));
    fs::remove_dir_all(first_root).unwrap();
    fs::remove_dir_all(second_root).unwrap();
}

#[test]
fn md5_cache_filename_known_vector() {
    let service = ImageCacheService::new(PathBuf::from("cache"));
    let path = service.image_file_path("https://example.com/书/一", "https://example.com/书/一");
    assert_eq!(
        path,
        PathBuf::from("cache")
            .join("https___example.com_____250ab464")
            .join("images")
            .join("02d9fa1915061b5e.jpg")
    );
}
