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
