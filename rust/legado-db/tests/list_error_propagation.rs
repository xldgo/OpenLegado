//! 正常查询不能以缺行集合掩盖数据库解析错误。
use legado_core::models::{Book, BookChapter, Bookmark};
use legado_db::{
    BookChapterRepository, BookRepository, BookmarkRepository, repository::Repository,
};
#[test]
fn chapter_and_bookmark_lists_fail_on_bad_rows_then_recover() {
    let db = legado_db::init_in_memory_database().unwrap();
    let conn = db.connection();
    BookRepository::new(conn)
        .insert(&Book {
            book_url: "book".into(),
            name: "书".into(),
            ..Book::default()
        })
        .unwrap();
    let chapters = BookChapterRepository::new(conn);
    chapters
        .insert(&BookChapter {
            book_url: "book".into(),
            url: "chapter".into(),
            title: "章".into(),
            ..BookChapter::default()
        })
        .unwrap();
    conn.execute_batch("UPDATE chapters SET isVolume='bad'")
        .unwrap();
    assert!(chapters.find_by_book_url("book").is_err());
    assert!(chapters.find_all().is_err());
    conn.execute_batch("UPDATE chapters SET isVolume=0")
        .unwrap();
    assert_eq!(chapters.find_all().unwrap().len(), 1);
    let marks = BookmarkRepository::new(conn);
    marks
        .insert(&Bookmark {
            book_name: "书".into(),
            ..Bookmark::default()
        })
        .unwrap();
    conn.execute_batch("UPDATE bookmarks SET chapterIndex='bad'")
        .unwrap();
    assert!(marks.get_by_book("书").is_err());
    conn.execute_batch("DELETE FROM bookmarks").unwrap();
    assert!(marks.get_by_book("书").unwrap().is_empty());
}
