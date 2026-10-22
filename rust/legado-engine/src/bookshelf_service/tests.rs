use super::*;
use crate::EngineContext;
use legado_core::models::BookChapter;

#[test]
fn stale_saves_and_progress_keep_source_columns_chapters_and_storage_identity() {
    let a = EngineContext::in_memory().unwrap();
    let b = EngineContext::in_memory().unwrap();
    let first = BookshelfService::new(Some(a.storage().clone()));
    let second = BookshelfService::new(Some(b.storage().clone()));
    let book = Book {
        book_url: "same-book".into(),
        name: "甲".into(),
        origin: "new".into(),
        origin_name: "新源".into(),
        toc_url: "new/toc".into(),
        origin_book_url: "new/book".into(),
        ..Default::default()
    };
    first.add_book_entity(book.clone()).unwrap();
    second
        .add_book_entity(Book {
            name: "乙".into(),
            ..book.clone()
        })
        .unwrap();
    a.storage()
        .with_database(|db| {
            legado_db::BookChapterRepository::new(db.connection()).insert_batch(&[
                BookChapter {
                    book_url: book.book_url.clone(),
                    url: "one".into(),
                    title: "第一章".into(),
                    index: 0,
                    ..Default::default()
                },
                BookChapter {
                    book_url: book.book_url.clone(),
                    url: "two".into(),
                    title: "第二章".into(),
                    index: 1,
                    ..Default::default()
                },
            ])
        })
        .unwrap();
    first
        .update_reading_progress(&book.book_url, 99, 73)
        .unwrap();
    first
        .update_book_entity(Book {
            name: "改名".into(),
            origin: "old".into(),
            origin_name: "旧源".into(),
            toc_url: "old/toc".into(),
            origin_book_url: "old/book".into(),
            variable: Some(String::new()),
            ..book.clone()
        })
        .unwrap();
    let saved = first.get_book(&book.book_url).unwrap().unwrap();
    assert_eq!(
        (
            saved.origin,
            saved.origin_name,
            saved.toc_url,
            saved.origin_book_url
        ),
        (
            book.origin.clone(),
            book.origin_name.clone(),
            book.toc_url.clone(),
            book.origin_book_url.clone()
        )
    );
    assert_eq!((saved.dur_chapter_index, saved.dur_chapter_pos), (1, 73));
    assert_eq!(saved.dur_chapter_title.as_deref(), Some("第二章"));
    assert_eq!(second.get_book(&book.book_url).unwrap().unwrap().name, "乙");
    first
        .reorder_book_entities(&[(book.book_url.clone(), -7)])
        .unwrap();
    a.storage()
        .with_database(|db| {
            assert_eq!(
                legado_db::BookChapterRepository::new(db.connection())
                    .count_by_book_url(&book.book_url)?,
                2
            );
            Ok(())
        })
        .unwrap();
    first
        .update_reading_progress(&book.book_url, -9, 2)
        .unwrap();
    assert_eq!(
        first
            .get_book(&book.book_url)
            .unwrap()
            .unwrap()
            .dur_chapter_index,
        0
    );
    assert!(
        matches!(first.update_reading_progress("missing", 0, 0), Err(LegadoError::Database(e)) if e == "书籍不存在")
    );
    first.delete_book(&book.book_url).unwrap();
    assert!(first.get_book(&book.book_url).unwrap().is_none());
    assert!(second.get_book(&book.book_url).unwrap().is_some());
}

#[test]
fn failed_book_decode_aborts_save_and_lists_without_replacing_source() {
    let engine = EngineContext::in_memory().unwrap();
    let service = BookshelfService::new(Some(engine.storage().clone()));
    service
        .add_book_entity(Book {
            book_url: "broken".into(),
            name: "坏行".into(),
            origin: "current".into(),
            ..Book::default()
        })
        .unwrap();
    engine
        .storage()
        .with_database(|db| {
            db.connection()
                .execute_batch(
                    "UPDATE books SET totalChapterNum='not-a-number' WHERE bookUrl='broken'",
                )
                .unwrap();
            Ok(())
        })
        .unwrap();
    assert!(service.get_book("broken").is_err());
    assert!(service.list_books().is_err());
    assert!(
        service
            .update_book_entity(Book {
                book_url: "broken".into(),
                name: "坏行".into(),
                origin: "stale".into(),
                ..Book::default()
            })
            .is_err()
    );
    engine
        .storage()
        .with_database(|db| {
            let source: String = db
                .connection()
                .query_row(
                    "SELECT origin FROM books WHERE bookUrl='broken'",
                    [],
                    |row| row.get(0),
                )
                .unwrap();
            assert_eq!(source, "current");
            assert!(db.connection().is_autocommit());
            db.connection()
                .execute_batch("UPDATE books SET totalChapterNum=1 WHERE bookUrl='broken'")
                .unwrap();
            Ok(())
        })
        .unwrap();
    assert_eq!(service.list_books().unwrap().len(), 1);
}

#[test]
fn failed_book_write_rolls_back_and_connection_remains_usable() {
    let engine = EngineContext::in_memory().unwrap();
    let service = BookshelfService::new(Some(engine.storage().clone()));
    service
        .add_book_entity(Book {
            book_url: "book".into(),
            name: "旧书".into(),
            ..Book::default()
        })
        .unwrap();
    engine.storage().with_database(|db|{db.connection().execute_batch("CREATE TRIGGER deny_save BEFORE UPDATE ON books BEGIN SELECT RAISE(ABORT,'denied'); END;").unwrap();Ok(())}).unwrap();
    assert!(
        service
            .update_book_entity(Book {
                book_url: "book".into(),
                name: "新书".into(),
                ..Book::default()
            })
            .is_err()
    );
    assert_eq!(service.get_book("book").unwrap().unwrap().name, "旧书");
    engine
        .storage()
        .with_database(|db| {
            assert!(db.connection().is_autocommit());
            db.connection()
                .execute_batch("DROP TRIGGER deny_save")
                .unwrap();
            Ok(())
        })
        .unwrap();
    service
        .update_book_entity(Book {
            book_url: "book".into(),
            name: "新书".into(),
            ..Book::default()
        })
        .unwrap();
    assert_eq!(service.get_book("book").unwrap().unwrap().name, "新书");
}

#[test]
fn database_error_messages_do_not_trigger_repeated_progress_writes() {
    let engine = EngineContext::in_memory().unwrap();
    let service = BookshelfService::new(Some(engine.storage().clone()));
    service
        .add_book_entity(Book {
            book_url: "book".into(),
            name: "书".into(),
            ..Book::default()
        })
        .unwrap();
    engine.storage().with_database(|db|{db.connection().execute_batch("CREATE TABLE attempt_counter(n);INSERT INTO attempt_counter VALUES(0);CREATE TRIGGER deny_progress BEFORE UPDATE OF durChapterIndex ON books BEGIN UPDATE attempt_counter SET n=n+1;SELECT RAISE(FAIL,'busy locked words only');END;").unwrap();Ok(())}).unwrap();
    let error = service.update_reading_progress("book", 0, 5).unwrap_err();
    assert!(!error.is_database_contention());
    engine
        .storage()
        .with_database(|db| {
            let count: i32 = db
                .connection()
                .query_row("SELECT n FROM attempt_counter", [], |r| r.get(0))
                .unwrap();
            assert_eq!(count, 1);
            Ok(())
        })
        .unwrap();
}

#[test]
fn can_update_command_changes_only_policy_on_latest_book() {
    let engine = EngineContext::in_memory().unwrap();
    let service = BookshelfService::new(Some(engine.storage().clone()));
    let book = Book {
        book_url: "update-policy".into(),
        name: "原书名".into(),
        book_type: 8 | 16,
        can_update: true,
        ..Default::default()
    };
    service.add_book_entity(book.clone()).unwrap();
    service
        .update_reading_progress(&book.book_url, 3, 87)
        .unwrap();
    service
        .update_book_entity(Book {
            name: "最新书名".into(),
            ..book.clone()
        })
        .unwrap();
    let disabled = service.set_can_update(&book.book_url, false).unwrap();
    assert!(!disabled.can_update);
    assert_eq!(disabled.book_type, 8);
    assert_eq!(disabled.name, "最新书名");
    assert_eq!(
        (disabled.dur_chapter_index, disabled.dur_chapter_pos),
        (3, 87)
    );
    assert_eq!(
        serde_json::to_value(service.get_book(&book.book_url).unwrap().unwrap()).unwrap(),
        serde_json::to_value(&disabled).unwrap()
    );
    let enabled = service.set_can_update(&book.book_url, true).unwrap();
    assert!(enabled.can_update);
    assert_eq!(enabled.book_type, 8);
    // 启用不会清除原有错误位；关闭才清除。
    service
        .update_book_entity(Book {
            can_update: false,
            book_type: 8 | 16,
            ..enabled
        })
        .unwrap();
    assert_eq!(
        service
            .set_can_update(&book.book_url, true)
            .unwrap()
            .book_type,
        8 | 16
    );
    assert!(service.set_can_update("missing-book", false).is_err());
    assert!(service.get_book("missing-book").unwrap().is_none());
}
