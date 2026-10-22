use super::*;
use crate::{EngineContext, test_http_fixture::Fixture};
use std::sync::Mutex;

fn config(url: &str) -> WebDavConfig {
    WebDavConfig {
        url: url.into(),
        username: "user".into(),
        password: "pass".into(),
        remote_dir: "/books/".into(),
    }
}

#[test]
fn file_operations_keep_bytes_authentication_paths_and_captured_resources() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak = Arc::downgrade(&engine);
    let dir = engine.storage().data_directory("webdav").unwrap();
    std::fs::create_dir_all(&dir).unwrap();
    let storage = engine.storage().clone();
    let service = WebDavService::new(
        engine.network().custom_hosts().clone(),
        runtime.handle().clone(),
    );
    drop(engine);
    assert!(weak.upgrade().is_none());
    let content = "书籍😀\0\r\n原始字节";
    let uploaded = Arc::new(Mutex::new(String::new()));
    let remote = uploaded.clone();
    let mut fixture = Fixture::with_content_type(
        7,
        false,
        "application/octet-stream",
        move |request| {
            if request.starts_with("PUT ") {
                *remote.lock().unwrap() = request.split_once("\r\n\r\n").unwrap().1.into();
                String::new()
            } else if request.starts_with("PROPFIND ") {
                r#"<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"><d:response><d:href>/books/book.txt</d:href><d:propstat><d:prop><d:displayname>book.txt</d:displayname><d:getcontentlength>9007199254740993</d:getcontentlength><d:resourcetype/></d:prop></d:propstat></d:response></d:multistatus>"#.into()
            } else {
                remote.lock().unwrap().clone()
            }
        },
    );
    let input = dir.join("上传😀.bin");
    let output = dir.join("新目录/下载😀.bin");
    let missing = dir.join("不存在.bin");
    let error = service
        .webdav_upload_file(
            config(&fixture.url),
            "missing.bin",
            missing.to_str().unwrap(),
        )
        .unwrap_err();
    let legado_core::LegadoError::Io(error) = error else {
        panic!("本地缺失文件应返回 IO 错误");
    };
    assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
    assert!(error.to_string().contains(missing.to_str().unwrap()));
    std::fs::write(&input, content).unwrap();
    service
        .webdav_upload_file(config(&fixture.url), "book.bin", input.to_str().unwrap())
        .unwrap();
    service
        .webdav_download_file(config(&fixture.url), "book.bin", output.to_str().unwrap())
        .unwrap();
    assert_eq!(std::fs::read(&output).unwrap(), content.as_bytes());
    service
        .webdav_upload(config(&fixture.url), "book.txt", "文本上传")
        .unwrap();
    assert_eq!(
        service
            .webdav_download(config(&fixture.url), "book.txt")
            .unwrap(),
        "文本上传"
    );
    service
        .webdav_mkdir(config(&fixture.url), "folder")
        .unwrap();
    service
        .webdav_delete(config(&fixture.url), "book.bin")
        .unwrap();
    let entries = service.webdav_list_dir(config(&fixture.url), "").unwrap();
    assert_eq!(entries[0].size, 9_007_199_254_740_993);
    assert_eq!(entries[0].path, "/books/book.txt");
    for expected in [
        "PUT /books/book.bin",
        "GET /books/book.bin",
        "PUT /books/book.txt",
        "GET /books/book.txt",
        "MKCOL /books/folder",
        "DELETE /books/book.bin",
        "PROPFIND /books/",
    ] {
        let request = runtime.block_on(fixture.request());
        assert!(request.starts_with(expected), "{request}");
        assert!(
            request
                .to_ascii_lowercase()
                .contains("authorization: basic dxnlcjpwyxnz")
        );
    }
    fixture.worker.join().unwrap();
    drop(storage);
}

#[test]
fn sync_delegation_preserves_remote_documents_and_incremental_upload_counts() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let service = WebDavService::new(Arc::new(CustomHosts::default()), runtime.handle().clone());
    let mut fixture = Fixture::with_content_type(8, false, "application/xml", |request| {
        if request.starts_with("GET /books/bookshelf.json") {
            "远端书架文档".into()
        } else if request.starts_with("GET /books/sources.json") {
            "远端书源文档".into()
        } else if request.starts_with("PROPFIND ") {
            r#"<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"/>"#.into()
        } else {
            String::new()
        }
    });
    let documents = service
        .webdav_full_sync(config(&fixture.url), "本地书架文档", "本地书源文档")
        .unwrap();
    assert_eq!(documents, ("远端书架文档".into(), "远端书源文档".into()));
    let (books, sources, result) = service
        .webdav_incremental_sync(config(&fixture.url), "本地书架文档", "本地书源文档", None)
        .unwrap();
    assert_eq!(books, "本地书架文档");
    assert_eq!(sources, "本地书源文档");
    assert_eq!(
        [
            result.uploaded_count,
            result.downloaded_count,
            result.skipped_count,
            result.conflict_count
        ],
        [2, 0, 0, 0]
    );
    assert!(result.errors.is_empty());
    for expected in [
        "MKCOL /books/",
        "PUT /books/bookshelf.json",
        "PUT /books/sources.json",
        "GET /books/bookshelf.json",
        "GET /books/sources.json",
        "PROPFIND /books/",
        "PUT /books//bookshelf.json",
        "PUT /books//sources.json",
    ] {
        let request = runtime.block_on(fixture.request());
        assert!(request.starts_with(expected), "{request}");
    }
    fixture.worker.join().unwrap();
}
