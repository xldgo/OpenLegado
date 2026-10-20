use super::*;
use crate::EngineContext;
use std::sync::Arc;

fn service(storage: Option<StorageContext>, root: std::path::PathBuf) -> BookImportService {
    BookImportService::new(BookImportResources {
        storage,
        resolve_path: Arc::new(move |path| root.join(path).to_string_lossy().into_owned()),
    })
}

#[test]
fn relative_import_keeps_identifier_and_uses_its_own_files_and_storage() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    let weak = Arc::downgrade(&first);
    let a_storage = first.storage().clone();
    let b_storage = second.storage().clone();
    let a_dir = a_storage.data_directory("books").unwrap();
    let b_dir = b_storage.data_directory("books").unwrap();
    for dir in [&a_dir, &b_dir] {
        std::fs::create_dir_all(dir).unwrap();
        std::fs::write(dir.join("同书.txt"), "第一章 开始\n这是书籍正文。\n").unwrap();
    }
    let a = service(Some(a_storage.clone()), a_dir.parent().unwrap().into());
    let b = service(Some(b_storage.clone()), b_dir.parent().unwrap().into());
    drop(first);
    assert!(weak.upgrade().is_none(), "服务只持有必要资源，不保留根引擎");

    let id = "books/同书.txt";
    for importer in [&a, &b] {
        let result = importer.import_local_book(id).unwrap();
        assert!(result.success, "{:?}", result.error);
        let book = result.book.unwrap();
        assert_eq!(book.book_url, id);
        assert_eq!(book.origin_name, "同书.txt");
        assert_eq!(book.origin, legado_core::models::book::book_type::LOCAL_TAG);
        assert_eq!(book.book_type, legado_core::models::book::book_type::LOCAL);
    }
    a_storage
        .with_database(|db| BookRepository::new(db.connection()).delete_by_url(id))
        .unwrap();
    let still_exists = b_storage
        .with_database(|db| BookRepository::new(db.connection()).find_by_url(id))
        .unwrap();
    assert!(still_exists.is_some(), "删除甲库不能影响乙库");
    let path = b_dir.join("同书.txt");
    let path = path.to_str().unwrap();
    assert_eq!(b.detect_format(path).unwrap().path, path);
    assert_eq!(b.parse_metadata(path).unwrap().title, "同书");
}

#[test]
fn parse_and_database_failures_keep_their_original_result_categories() {
    let engine = EngineContext::in_memory().unwrap();
    let dir = engine.storage().data_directory("books").unwrap();
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("损坏.epub"), b"not an epub").unwrap();
    std::fs::write(dir.join("正常.txt"), "第一章\n正文\n").unwrap();
    let importer = service(None, dir);
    let broken = importer.import_local_book("损坏.epub").unwrap();
    assert!(!broken.success);
    assert!(broken.error.unwrap().contains("元数据解析失败"));
    let unavailable = importer.import_local_book("正常.txt").unwrap();
    assert!(!unavailable.success);
    assert!(unavailable.error.unwrap().contains("导入数据库失败"));
    assert!(importer.import_local_book("不存在.未知").is_err());
}
