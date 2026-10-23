use super::*;
use legado_core::models::Book;
use legado_db::BookRepository;

#[test]
fn current_backup_file_roundtrip_reports_all_collections_and_keeps_owner_boundary() {
    use std::sync::Arc;
    let source = Arc::new(crate::EngineContext::in_memory().unwrap());
    let target = crate::EngineContext::in_memory().unwrap();
    source
        .storage()
        .with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: "https://backup.test/book".into(),
                name: "文件备份😀".into(),
                ..Default::default()
            })
        })
        .unwrap();
    let exporter = BackupService::new(Some(source.storage().clone()));
    let directory = source.storage().data_directory("backup").unwrap();
    let path = directory.join("完整备份😀.json");
    let weak = Arc::downgrade(&source);
    drop(source);
    assert!(weak.upgrade().is_none());
    exporter.backup_create(path.to_str().unwrap()).unwrap();
    let document: BackupData = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
    assert_eq!(document.version, 2);
    let importer = BackupService::new(Some(target.storage().clone()));
    let stats = importer.restore_backup(path.to_str().unwrap()).unwrap();
    assert_eq!(stats.books, 1);
    assert_eq!(stats.additional.len(), legado_db::backup::TABLES.len() - 6);
    assert_eq!(
        exporter
            .list_backup_files(directory.to_str().unwrap())
            .len(),
        1
    );
}

#[test]
fn backup_errors_and_existing_old_import_messages_keep_their_categories() {
    let engine = crate::EngineContext::in_memory().unwrap();
    let dir = engine.storage().data_directory("old-import").unwrap();
    fs::create_dir_all(&dir).unwrap();
    let service = BackupService::new(Some(engine.storage().clone()));
    let empty = service.import_old_data(dir.to_str().unwrap()).unwrap();
    assert_eq!(
        [empty.books, empty.book_sources, empty.replace_rules],
        [0; 3]
    );
    assert_eq!(
        empty.messages,
        [
            "未找到 myBookShelf.json",
            "未找到 myBookSource.json",
            "未找到替换规则"
        ]
    );
    fs::write(
        dir.join("myBookShelf.json"),
        r#"[{"noteUrl":"https://old.test/book","bookInfoBean":{"name":"旧版书"}}]"#,
    )
    .unwrap();
    let imported = service.import_old_data(dir.to_str().unwrap()).unwrap();
    assert_eq!(imported.books, 1);
    assert_eq!(imported.messages[0], "成功导入书架1");
    assert_eq!(
        service
            .import_old_data(dir.to_str().unwrap())
            .unwrap()
            .books,
        0
    );
    assert!(matches!(
        service.restore_backup(dir.join("missing.json").to_str().unwrap()),
        Err(LegadoError::Io(_))
    ));
    let bad = dir.join("bad.json");
    fs::write(&bad, "{invalid").unwrap();
    assert!(matches!(
        service.restore_backup(bad.to_str().unwrap()),
        Err(LegadoError::Parser(_))
    ));
    assert!(matches!(
        BackupService::new(None).backup_create(bad.to_str().unwrap()),
        Err(LegadoError::Database(_))
    ));
    assert!(
        service
            .list_backup_files(dir.join("missing").to_str().unwrap())
            .is_empty()
    );
}
