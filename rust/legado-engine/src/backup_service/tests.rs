use super::*;
use legado_core::models::Book;
use legado_db::BookRepository;

#[test]
fn packaged_backup_restores_resources_and_credentials_only_after_validation() {
    use serde_json::{Value, json};
    use std::sync::Arc;
    for password in [None, Some("本地密码".to_owned())] {
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
        fs::create_dir_all(&directory).unwrap();
        let font = directory.join("自选.ttf");
        fs::write(&font, b"font fixture bytes").unwrap();
        let original = font.to_string_lossy().to_string();
        let mut options=BackupOptions {
            preferences:serde_json::from_value(json!({"reader_custom_fonts":[format!("Custom|{original}")],"unchanged":"{  \"a\": 1 }"})).unwrap(),
            files:std::collections::BTreeMap::from([(original.clone(),original.clone())]),password:password.clone(),..Default::default()
        };
        if password.is_some() {
            options
                .sensitive
                .insert("webDavPassword".into(), json!("凭据"));
        }
        let path = directory.join("备份.zip");
        let weak = Arc::downgrade(&source);
        drop(source);
        assert!(weak.upgrade().is_none());
        exporter
            .backup_create(path.to_str().unwrap(), &options)
            .unwrap();
        fs::remove_file(&font).unwrap();
        let importer = BackupService::new(Some(target.storage().clone()));
        if password.is_some() {
            assert!(
                importer
                    .restore_backup(
                        path.to_str().unwrap(),
                        &RestoreOptions {
                            password: Some("错误".into()),
                            ..Default::default()
                        }
                    )
                    .is_err()
            );
            let mut damaged = fs::read(&path).unwrap();
            let last = damaged.len() - 1;
            damaged[last] ^= 1;
            let altered = directory.join("损坏.zip");
            fs::write(&altered, damaged).unwrap();
            assert!(
                importer
                    .restore_backup(
                        altered.to_str().unwrap(),
                        &RestoreOptions {
                            password: password.clone(),
                            ..Default::default()
                        }
                    )
                    .is_err()
            );
            fs::remove_file(altered).unwrap();
        }
        target.storage().with_database(|db| {db.connection().execute_batch("CREATE TRIGGER refuse_backup BEFORE INSERT ON books BEGIN SELECT RAISE(ABORT,'拒绝写入'); END;").unwrap();Ok(())}).unwrap();
        let restore = RestoreOptions {
            password: password.clone(),
            ..Default::default()
        };
        assert!(
            importer
                .restore_backup(path.to_str().unwrap(), &restore)
                .is_err()
        );
        let resources = target.storage().data_directory("backup_resources").unwrap();
        assert_eq!(fs::read_dir(&resources).unwrap().count(), 0);
        target
            .storage()
            .with_database(|db| {
                assert!(BookRepository::new(db.connection()).find_all()?.is_empty());
                db.connection()
                    .execute_batch("DROP TRIGGER refuse_backup")
                    .unwrap();
                Ok(())
            })
            .unwrap();
        let result = importer
            .restore_backup(path.to_str().unwrap(), &restore)
            .unwrap();
        assert_eq!(result.stats.books, 1);
        assert_eq!(
            result.stats.additional.len(),
            legado_db::backup::TABLES.len() - 6
        );
        let entry = result.preferences["reader_custom_fonts"][0]
            .as_str()
            .unwrap();
        let (_, restored_path) = entry.split_once('|').unwrap();
        assert_ne!(restored_path, original);
        assert_eq!(fs::read(restored_path).unwrap(), b"font fixture bytes");
        assert_eq!(
            result.preferences["unchanged"],
            Value::String("{  \"a\": 1 }".into())
        );
        assert_eq!(
            result.sensitive.get("webDavPassword"),
            password
                .as_ref()
                .map(|_| &options.sensitive["webDavPassword"])
        );
        assert_eq!(
            exporter
                .list_backup_files(directory.to_str().unwrap())
                .len(),
            1
        );
    }
}

#[test]
fn upstream_zip_maps_known_entities_and_reports_unsupported_members() {
    use std::io::{Cursor, Write};
    let target = crate::EngineContext::in_memory().unwrap();
    let service = BackupService::new(Some(target.storage().clone()));
    let directory = target.storage().data_directory("upstream").unwrap();
    fs::create_dir_all(&directory).unwrap();
    let path = directory.join("原版.zip");
    let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
    for (name, content) in [
        (
            "bookshelf.json",
            r#"[{"bookUrl":"upstream-book","name":"原版书","author":"作者"}]"#,
        ),
        (
            "bookSource.json",
            r#"[{"bookSourceUrl":"source","bookSourceName":12,"enabled":"0"}]"#,
        ),
        ("readConfig.json", "[]"),
    ] {
        zip.start_file(name, zip::write::SimpleFileOptions::default())
            .unwrap();
        zip.write_all(content.as_bytes()).unwrap();
    }
    fs::write(&path, zip.finish().unwrap().into_inner()).unwrap();
    let result = service
        .restore_backup(path.to_str().unwrap(), &Default::default())
        .unwrap();
    assert_eq!(result.stats.books, 1);
    assert_eq!(result.stats.book_sources, 1);
    assert!(
        result
            .warnings
            .iter()
            .any(|w| w.contains("readConfig.json"))
    );
    target
        .storage()
        .with_database(|db| {
            let sources = BookSourceRepository::new(db.connection()).find_all()?;
            assert_eq!(sources[0].book_source_name, "12");
            assert!(!sources[0].enabled);
            Ok(())
        })
        .unwrap();
}

#[test]
fn invalid_zip_paths_and_missing_members_are_rejected_before_business_changes() {
    use std::io::{Cursor, Write};
    let target = crate::EngineContext::in_memory().unwrap();
    let service = BackupService::new(Some(target.storage().clone()));
    let directory = target.storage().data_directory("invalid-package").unwrap();
    fs::create_dir_all(&directory).unwrap();
    let path = directory.join("bad.zip");
    for entries in [vec![("../outside.txt",b"bad".as_slice())],vec![("manifest.json",br#"{"format":"openlegado","version":1,"backupTime":0,"config":{},"collections":["books"],"preferences":{},"sensitive":{},"resources":{}}"#.as_slice())]] {
        let mut zip=zip::ZipWriter::new(Cursor::new(Vec::new()));
        for (name,content) in entries {zip.start_file(name,zip::write::SimpleFileOptions::default()).unwrap();zip.write_all(content).unwrap();}
        fs::write(&path,zip.finish().unwrap().into_inner()).unwrap();
        assert!(service.restore_backup(path.to_str().unwrap(),&Default::default()).is_err());
    }
    target
        .storage()
        .with_database(|db| {
            assert!(BookRepository::new(db.connection()).find_all()?.is_empty());
            Ok(())
        })
        .unwrap();
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
        service.restore_backup(
            dir.join("missing.json").to_str().unwrap(),
            &Default::default()
        ),
        Err(LegadoError::Io(_))
    ));
    let bad = dir.join("bad.json");
    fs::write(&bad, "{invalid").unwrap();
    assert!(matches!(
        service.restore_backup(bad.to_str().unwrap(), &Default::default()),
        Err(LegadoError::Parser(_))
    ));
    assert!(matches!(
        BackupService::new(None).backup_create(bad.to_str().unwrap(), &Default::default()),
        Err(LegadoError::Database(_))
    ));
    assert!(
        service
            .list_backup_files(dir.join("missing").to_str().unwrap())
            .is_empty()
    );
}
