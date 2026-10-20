//! 本地书导入宿主适配：捕获路径与存储，编排归Engine服务。
use legado_book::BookMetadata;
use legado_core::LegadoResult;
use legado_engine::book_import_service::{BookImportResources, BookImportService};
pub use legado_engine::book_import_service::{DetectFormatResult, ImportResult};
use std::sync::Arc;
fn host_service() -> BookImportService {
    let storage = crate::engine_holder::current()
        .ok()
        .map(|e| e.storage().clone());
    let paths = storage.clone();
    BookImportService::new(BookImportResources {
        storage,
        resolve_path: Arc::new(move |book| {
            if book.contains("://") || std::path::Path::new(book).is_absolute() {
                return book.into();
            }
            paths
                .as_ref()
                .and_then(|s| s.path())
                .and_then(std::path::Path::parent)
                .map(|base| base.join(book).to_string_lossy().into_owned())
                .unwrap_or_else(|| book.into())
        }),
    })
}
pub fn detect_format(file_path: &str) -> LegadoResult<DetectFormatResult> {
    host_service().detect_format(file_path)
}
pub fn parse_metadata(file_path: &str) -> LegadoResult<BookMetadata> {
    host_service().parse_metadata(file_path)
}
pub fn import_local_book(file_path: &str) -> LegadoResult<ImportResult> {
    host_service().import_local_book(file_path)
}
#[cfg(test)]
use crate::db_state::with_database;
#[cfg(test)]
use legado_db::BookRepository;
#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::models::book::book_type;

    /// 在临时目录中程序化造一个 CBZ，返回文件路径
    fn make_cbz(dir_name: &str, file_name: &str, entries: &[(&str, &[u8])]) -> String {
        use std::io::Write as _;
        let dir = std::env::temp_dir().join(dir_name);
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let cbz_path = dir.join(file_name);
        let file = std::fs::File::create(&cbz_path).unwrap();
        let mut writer = zip::ZipWriter::new(file);
        let options = zip::write::SimpleFileOptions::default();
        for (name, data) in entries {
            writer.start_file(*name, options).unwrap();
            writer.write_all(data).unwrap();
        }
        writer.finish().unwrap();
        cbz_path.to_string_lossy().into_owned()
    }

    /// a) `.cbz` 导入：bookType = LOCAL(0x1000) | IMAGE_BIT(64)，origin 语义不变
    #[test]
    fn import_cbz_sets_local_image_bit() {
        let _db_guard = crate::db_state::ensure_test_db();
        let path = make_cbz(
            "legado_test_import_cbz",
            "本地漫画.cbz",
            &[("01.jpg", b"one"), ("02 续.png", b"two")],
        );

        let res = import_local_book(&path).unwrap();
        assert!(res.success, "导入失败: {:?}", res.error);
        let book = res.book.expect("成功时应有 book");
        assert_eq!(
            book.book_type,
            book_type::LOCAL | book_type::IMAGE_BIT,
            "cbz 应为 LOCAL|IMAGE_BIT"
        );
        assert_eq!(book.book_type, 0x1040);
        assert_ne!(
            book.book_type,
            book_type::IMAGE,
            "位域不得混用数值域 IMAGE=2"
        );
        assert_eq!(book.origin, book_type::LOCAL_TAG, "origin 仍为 loc_book");
        assert_eq!(book.book_url, path, "book_url 应存传入路径");
        assert_eq!(book.name, "本地漫画");

        // 收尾清理共享内存库
        with_database(|db| BookRepository::new(db.connection()).delete_by_url(&path)).unwrap();
        let _ = std::fs::remove_dir_all(std::env::temp_dir().join("legado_test_import_cbz"));
    }

    /// 回归：非 cbz 本地格式（txt）保持 LOCAL 无媒体位
    #[test]
    fn import_txt_keeps_local_without_image_bit() {
        let _db_guard = crate::db_state::ensure_test_db();
        let dir = std::env::temp_dir().join("legado_test_import_txt_regress");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let txt = dir.join("普通小说.txt");
        std::fs::write(&txt, "第一章 开始\n正文内容。\n").unwrap();
        let path = txt.to_string_lossy().into_owned();

        let res = import_local_book(&path).unwrap();
        assert!(res.success, "导入失败: {:?}", res.error);
        let book = res.book.expect("成功时应有 book");
        assert_eq!(book.book_type, book_type::LOCAL, "txt 应保持 LOCAL");
        assert_eq!(book.book_type & book_type::IMAGE_BIT, 0, "不应带图片位");

        with_database(|db| BookRepository::new(db.connection()).delete_by_url(&path)).unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }
}
