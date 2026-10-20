use super::*;

fn rss_fixture() -> RssSource {
    serde_json::from_str(r#"{
            "sourceUrl":"https://backup.test/rss", "sourceName":"完整源😀", "sourceIcon":"icon",
            "sourceGroup":"group", "sourceComment":"comment", "enabled":true,
            "variableComment":"variable", "jsLib":"var x=1;", "enabledCookieJar":true,
            "concurrentRate":"1000", "header":"{\"X-Test\":\"value\"}",
            "loginUrl":"login()", "loginUi":"[]", "loginCheckJs":"result", "coverDecodeJs":"result",
            "sortUrl":"sort", "singleUrl":true, "articleStyle":4,
            "ruleArticles":"article", "ruleNextPage":"next", "ruleTitle":"title", "rulePubDate":"date",
            "ruleDescription":"description", "ruleImage":"image", "ruleLink":"link", "ruleContent":"content",
            "contentWhitelist":"allow", "contentBlacklist":"deny", "shouldOverrideUrlLoading":"override",
            "style":"css", "enableJs":false, "loadWithBaseUrl":false, "injectJs":"inject",
            "preloadJs":"preload", "startHtml":"html", "startStyle":"style", "startJs":"script",
            "showWebLog":true, "lastUpdateTime":9007199254740993, "customOrder":7,
            "type":2, "preload":true, "cacheFirst":true, "searchUrl":"search"
        }"#).unwrap()
}

#[test]
fn rss_backup_serializes_entity_booleans_and_keeps_nullable_cookie_flag() {
    let db = legado_db::init_in_memory_database().unwrap();
    let repo = legado_db::RssSourceRepository::new(db.connection());
    let mut source = rss_fixture();
    for flag in [Some(true), Some(false), None] {
        source.enabled_cookie_jar = flag;
        repo.insert(&source).unwrap();
        let rows = collect_rss_sources(db.connection()).unwrap();
        let mut expected = serde_json::to_value(&source).unwrap();
        expected["enabledCookieJar"] = serde_json::to_value(flag).unwrap();
        assert_eq!(rows, vec![expected]);
        let restored: RssSource = serde_json::from_value(rows[0].clone()).unwrap();
        assert_eq!(restored.enabled_cookie_jar, flag);
    }
}

#[test]
fn rss_backup_rejects_unreadable_rows_instead_of_dropping_sources() {
    let db = legado_db::init_in_memory_database().unwrap();
    RssSourceRepository::new(db.connection())
        .insert(&rss_fixture())
        .unwrap();
    db.connection()
        .execute("UPDATE rssSources SET articleStyle = 'invalid'", [])
        .unwrap();
    assert!(collect_rss_sources(db.connection()).is_err());
}

#[test]
fn rss_restore_to_empty_database_preserves_all_entity_fields() {
    let db = legado_db::init_in_memory_database().unwrap();
    let source = rss_fixture();
    insert_rss_source(db.connection(), &source).unwrap();
    let rows = legado_db::RssSourceRepository::new(db.connection())
        .find_all()
        .unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(
        serde_json::to_value(&rows[0]).unwrap(),
        serde_json::to_value(&source).unwrap()
    );
}

#[test]
fn backup_file_roundtrip_keeps_all_six_collections_and_partial_restore_counts() {
    use std::sync::Arc;
    let source = Arc::new(crate::EngineContext::in_memory().unwrap());
    let target = crate::EngineContext::in_memory().unwrap();
    source
        .storage()
        .with_database(|db| {
            let conn = db.connection();
            BookRepository::new(conn).insert(&Book {
                book_url: "https://backup.test/book".into(),
                name: "备份书😀".into(),
                ..Default::default()
            })?;
            BookmarkRepository::new(conn).insert(&Bookmark {
                book_name: "备份书😀".into(),
                content: "书签正文".into(),
                ..Default::default()
            })?;
            BookSourceRepository::new(conn).insert(&BookSource {
                book_source_url: "https://backup.test/source".into(),
                ..Default::default()
            })?;
            ReplaceRuleRepository::new(conn).insert(&legado_core::models::ReplaceRule {
                name: "替换规则".into(),
                pattern: "广告".into(),
                ..Default::default()
            })?;
            insert_rss_source(conn, &rss_fixture())?;
            ReadRecordRepository::new(conn).upsert("备份书😀", 1234)?;
            Ok(())
        })
        .unwrap();
    let storage = source.storage().clone();
    let directory = storage.data_directory("backup").unwrap();
    let path = directory.join("完整备份😀.json");
    let exporter = BackupService::new(Some(storage.clone()));
    let importer = BackupService::new(Some(target.storage().clone()));
    let weak = Arc::downgrade(&source);
    drop(source);
    assert!(weak.upgrade().is_none(), "服务不应持有根引擎");
    exporter.backup_create(path.to_str().unwrap()).unwrap();
    let mut data: BackupData = serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
    assert_eq!(data.version, 1);
    assert!(data.backup_time > 0);
    assert_eq!(data.read_records[0]["book_name"], "备份书😀");
    assert_eq!(data.read_records[0]["read_time"], 1234);
    assert!(
        [
            &data.books,
            &data.bookmarks,
            &data.replace_rules,
            &data.book_sources,
            &data.rss_sources,
            &data.read_records
        ]
        .iter()
        .all(|items| items.len() == 1)
    );
    // 坏条目不妨碍同一文档中的有效数据恢复，统计仅计成功条目。
    data.books.push(serde_json::Value::Bool(false));
    fs::write(&path, serde_json::to_vec(&data).unwrap()).unwrap();
    let stats = importer.restore_backup(path.to_str().unwrap()).unwrap();
    assert_eq!(
        [
            stats.books,
            stats.bookmarks,
            stats.replace_rules,
            stats.book_sources,
            stats.rss_sources,
            stats.read_records
        ],
        [1; 6]
    );
    target
        .storage()
        .with_database(|db| {
            let conn = db.connection();
            assert_eq!(BookRepository::new(conn).find_all()?[0].name, "备份书😀");
            assert_eq!(
                BookmarkRepository::new(conn).find_all()?[0].content,
                "书签正文"
            );
            let records = ReadRecordRepository::new(conn).find_all()?;
            assert_eq!(records.len(), 1);
            assert_eq!(records[0].book_name, "备份书😀");
            assert_eq!(records[0].read_time, 1234);
            let rss = RssSourceRepository::new(conn)
                .find_all()
                .map_err(LegadoError::Database)?;
            assert_eq!(
                serde_json::to_value(&rss[0]).unwrap(),
                serde_json::to_value(rss_fixture()).unwrap()
            );
            Ok(())
        })
        .unwrap();
    fs::write(directory.join("忽略.txt"), "不是备份").unwrap();
    let files = exporter.list_backup_files(directory.to_str().unwrap());
    assert_eq!(files.len(), 1);
    assert_eq!(files[0].name, "完整备份😀.json");
    assert_eq!(files[0].size, fs::metadata(&path).unwrap().len());
    assert!(files[0].modified > 0);
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
        Err(LegadoError::Internal(_))
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
