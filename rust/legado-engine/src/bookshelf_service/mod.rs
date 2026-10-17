//! 书架保存与阅读进度策略；仅捕获所属存储，不重找宿主根实例。
use crate::StorageContext;
use legado_core::{LegadoError, LegadoResult, models::Book};
use legado_db::{BookRepository, RoomImporter, repository::Repository};

pub struct BookshelfService {
    storage: Option<StorageContext>,
}
impl BookshelfService {
    pub fn new(storage: Option<StorageContext>) -> Self {
        Self { storage }
    }
    fn with_database<T>(
        &self,
        operation: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(operation)
    }
    pub fn list_books(&self) -> LegadoResult<Vec<Book>> {
        self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            // Task#125 P0：仅返回已入书架的书，过滤 notShelf 临时书（搜索/发现打开的在线书）
            repo.find_all_in_shelf()
        })
    }

    pub fn add_book_entity(&self, mut book: Book) -> LegadoResult<Book> {
        self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            // Task#125 P0：用原地 UPDATE 语义的 upsert，避免对已存在的临时书
            // 触发 INSERT OR REPLACE 级联删除其章节目录（转正/重复加入书架时安全）
            merge_source_fields(&repo, &mut book)?; // [B-2 / P2-8 P1-1] 书源字段防回退
            repo.update(&book)?;
            Ok(book)
        })
    }

    pub fn update_book_entity(&self, mut book: Book) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            merge_source_fields(&repo, &mut book)?; // [B-2] 陈旧快照不得撤销换源结果
            repo.update(&book)
        })
    }

    pub fn delete_book(&self, book_url: &str) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.delete_by_url(book_url)
        })
    }

    pub fn get_book(&self, book_url: &str) -> LegadoResult<Option<Book>> {
        self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.find_by_url(book_url)
        })
    }

    pub fn import_books(&self, json_array: &str) -> LegadoResult<i32> {
        self.with_database(|db| {
            let count = RoomImporter::import_books(db.connection(), json_array)?;
            Ok(count as i32)
        })
    }

    pub fn update_reading_progress(
        &self,
        book_url: &str,
        chapter_index: i32,
        chapter_pos: i32,
    ) -> LegadoResult<()> {
        const MAX_ATTEMPTS: u32 = 3;
        let mut attempt: u32 = 0;
        loop {
            attempt += 1;
            match self.write_reading_progress_once(book_url, chapter_index, chapter_pos) {
                Ok(()) => return Ok(()),
                Err(e) => {
                    let msg = e.to_string().to_lowercase();
                    let lock_error = msg.contains("locked") || msg.contains("busy");
                    if !lock_error || attempt >= MAX_ATTEMPTS {
                        return Err(e);
                    }
                    // [B-8] 退避 200ms / 400ms：等换源事务的写锁释放
                    std::thread::sleep(std::time::Duration::from_millis(200 * attempt as u64));
                }
            }
        }
    }

    fn write_reading_progress_once(
        &self,
        book_url: &str,
        chapter_index: i32,
        chapter_pos: i32,
    ) -> LegadoResult<()> {
        self.with_database(|db| {
            let conn = db.connection();
            let repo = BookRepository::new(conn);
            // 书籍必须存在：进度不写入不存在的书（对齐原实现「书籍不存在」错误）
            if repo.find_by_url(book_url)?.is_none() {
                return Err(legado_core::LegadoError::Database("书籍不存在".into()));
            }
            // [B-9] 越界保护：按既有目录收敛（目录为空时不收敛，仅保证非负）
            let chapter_repo = legado_db::BookChapterRepository::new(conn);
            let count = chapter_repo.count_by_book_url(book_url)?;
            let (clamped_index, chapter_title) = if count > 0 {
                let upper = (count - 1).min(i32::MAX as i64) as i32;
                let idx = chapter_index.clamp(0, upper);
                let title = chapter_repo
                    .find_by_book_url_and_index(book_url, idx)?
                    .map(|ch| ch.title);
                (idx, title)
            } else {
                (chapter_index.max(0), None)
            };
            let chapter_time = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_millis() as i64;
            // [B-3] 进度只走字段级 update_progress，不整行写（其他列不受影响）
            repo.update_progress(
                book_url,
                clamped_index,
                chapter_pos,
                chapter_title.as_deref(),
                chapter_time,
            )
        })
    }

    pub fn reorder_book_entities(&self, orders: &[(String, i32)]) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = BookRepository::new(db.connection());
            repo.update_orders(orders)
        })
    }
}

fn merge_source_fields(repo: &BookRepository<'_>, book: &mut Book) -> LegadoResult<()> {
    let Ok(Some(existing)) = repo.find_by_url(&book.book_url) else {
        return Ok(());
    };
    if !existing.origin.trim().is_empty() {
        book.origin = existing.origin;
    }
    if !existing.origin_name.trim().is_empty() {
        book.origin_name = existing.origin_name;
    }
    if !existing.toc_url.trim().is_empty() {
        book.toc_url = existing.toc_url;
    }
    if !existing.origin_book_url.trim().is_empty() {
        book.origin_book_url = existing.origin_book_url;
    }
    Ok(())
}

#[cfg(test)]
mod tests;
