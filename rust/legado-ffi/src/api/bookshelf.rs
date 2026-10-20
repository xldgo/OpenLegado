//! 书架宿主入口：文档解析与Engine服务装配。
use legado_core::{LegadoResult, models::Book};
use legado_engine::bookshelf_service::BookshelfService;

fn service() -> BookshelfService {
    BookshelfService::new(
        crate::engine_holder::current()
            .ok()
            .map(|e| e.storage().clone()),
    )
}

pub fn list_books() -> LegadoResult<Vec<Book>> {
    service().list_books()
}

pub fn add_book_entity(book: Book) -> LegadoResult<Book> {
    service().add_book_entity(book)
}

pub fn update_book_entity(book: Book) -> LegadoResult<()> {
    service().update_book_entity(book)
}

pub fn delete_book(book_url: &str) -> LegadoResult<()> {
    service().delete_book(book_url)
}

pub fn get_book(book_url: &str) -> LegadoResult<Option<Book>> {
    service().get_book(book_url)
}

pub fn import_books(json_array: &str) -> LegadoResult<i32> {
    service().import_books(json_array)
}

pub fn update_reading_progress(
    book_url: &str,
    chapter_index: i32,
    chapter_pos: i32,
) -> LegadoResult<()> {
    service().update_reading_progress(book_url, chapter_index, chapter_pos)
}

pub fn reorder_book_entities(orders: &[(String, i32)]) -> LegadoResult<()> {
    service().reorder_book_entities(orders)
}

pub fn add_book(book_json: &str) -> LegadoResult<Book> {
    let book: Book = serde_json::from_str(book_json)
        .map_err(|e| legado_core::LegadoError::Ffi(format!("Book JSON 解析失败: {e}")))?;
    add_book_entity(book)
}

pub fn update_book(book_json: &str) -> LegadoResult<()> {
    let book: Book = serde_json::from_str(book_json)
        .map_err(|e| legado_core::LegadoError::Ffi(format!("Book JSON 解析失败: {e}")))?;
    update_book_entity(book)
}

pub fn reorder_books(orders_json: &str) -> LegadoResult<()> {
    #[derive(serde::Deserialize)]
    struct BookOrderItem {
        #[serde(rename = "bookUrl")]
        book_url: String,
        order: i32,
    }
    let items: Vec<BookOrderItem> = serde_json::from_str(orders_json)
        .map_err(|e| legado_core::LegadoError::Ffi(format!("排序 JSON 解析失败: {e}")))?;
    let orders: Vec<(String, i32)> = items.into_iter().map(|i| (i.book_url, i.order)).collect();
    reorder_book_entities(&orders)
}

#[cfg(test)]
mod tests {
    use crate::db_state::with_database;
    use legado_core::models::{Book, ReadConfig};
    use legado_db::BookRepository;
    use legado_db::repository::Repository;

    /// [漫画设置作用域 2026-10-01] `update_book`（Dart `updateBook` 的 FFI 入口）
    /// 全行回写必须保留 readConfig 书级字段 `mangaScrollMode` /
    /// `webtoonSidePaddingDp`（此前 Rust 类型化 ReadConfig 不含该键，会被
    /// serde 静默丢弃），且进度列按既有语义不被陈旧快照回滚。
    #[test]
    fn test_update_book_preserves_manga_scope_read_config() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://manga-scope-ffi.example.com/book/1";

        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.insert(&Book {
                book_url: book_url.to_string(),
                name: "书名".to_string(),
                author: "作者".to_string(),
                read_config: Some(ReadConfig {
                    reverse_toc: true,
                    daily_chapters: 7,
                    manga_scroll_mode: Some(2),
                    webtoon_side_padding_dp: Some(20),
                    ..ReadConfig::default()
                }),
                ..Book::default()
            })?;
            repo.update_progress(book_url, 5, 9, Some("第五章"), 1_700_000_000_000)?;
            Ok(())
        })
        .expect("初始数据写入失败");

        // Dart 侧 updateBook 载荷形态：书级字段更新 + 故意携带陈旧进度快照
        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "改名",
            "author": "作者",
            "type": 0,
            "durChapterIndex": 0,
            "durChapterPos": 0,
            "readConfig": {
                "reverseToc": true,
                "dailyChapters": 7,
                "mangaScrollMode": 3,
                "webtoonSidePaddingDp": 45
            }
        })
        .to_string();
        super::update_book(&book_json).expect("update_book 应成功");

        with_database(|db| {
            let repo = BookRepository::new(db.connection());
            let saved = repo.find_by_url(book_url)?.expect("书籍记录应仍存在");
            assert_eq!(saved.name, "改名");
            let rc = saved.read_config.expect("readConfig 应保留");
            assert_eq!(rc.manga_scroll_mode, Some(3), "书级翻页模式不得被静默丢弃");
            assert_eq!(
                rc.webtoon_side_padding_dp,
                Some(45),
                "书级侧边留白不得被静默丢弃"
            );
            assert!(rc.reverse_toc);
            assert_eq!(rc.daily_chapters, 7);
            // 进度列不回滚（唯一常规写入口仍是 update_progress）
            assert_eq!(saved.dur_chapter_index, 5);
            assert_eq!(saved.dur_chapter_pos, 9);
            assert_eq!(saved.dur_chapter_title.as_deref(), Some("第五章"));
            Ok(())
        })
        .expect("DB 终态断言失败");

        // 收尾清理（共享测试库不留固定行）
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete_by_url(book_url);
            Ok(())
        })
        .ok();
    }
}
