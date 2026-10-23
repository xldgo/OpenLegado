use super::*;
use crate::{EngineContext, reading_service::save_chapter_cache};
use legado_core::models::{Book, BookChapter, ReplaceRule};
use legado_db::{ReplaceRuleRepository, repository::Repository};

const BOOK: &str = "https://same-export.test/book";

fn seed(storage: &StorageContext, marker: &str) {
    storage
        .with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: BOOK.into(),
                name: format!("测试{marker}"),
                author: "作者".into(),
                ..Default::default()
            })?;
            BookChapterRepository::new(db.connection()).insert_batch(&[
                BookChapter {
                    book_url: BOOK.into(),
                    url: "https://same-export.test/one".into(),
                    title: "第一章".into(),
                    index: 0,
                    ..Default::default()
                },
                BookChapter {
                    book_url: BOOK.into(),
                    url: "https://same-export.test/two".into(),
                    title: "第二章".into(),
                    index: 1,
                    ..Default::default()
                },
            ])?;
            ReplaceRuleRepository::new(db.connection()).insert(&ReplaceRule {
                pattern: "正文".into(),
                replacement: marker.into(),
                is_regex: false,
                ..Default::default()
            })?;
            Ok(())
        })
        .unwrap();
    for (index, title) in [(0, "第一章"), (1, "第二章")] {
        assert!(save_chapter_cache(
            storage,
            BOOK,
            index,
            title,
            if index == 0 {
                "https://same-export.test/one"
            } else {
                "https://same-export.test/two"
            },
            &format!("{title}\n測試正文")
        ));
    }
}

fn service(storage: Option<StorageContext>) -> BookExportService {
    BookExportService::new(BookExportResources {
        storage,
        image_fetcher: Arc::new(|_| panic!("文本导出不应请求图片")),
    })
}

fn text(result: ExportResult) -> String {
    assert!(result.success, "{:?}", result.error);
    String::from_utf8(result.data.unwrap()).unwrap()
}

#[test]
fn export_reuses_its_own_processing_and_keeps_raw_cache_unchanged() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    let weak = Arc::downgrade(&first);
    let storage = first.storage().clone();
    seed(&storage, "甲");
    seed(second.storage(), "乙");
    let content = ContentProcessing::new(Some(storage.clone()));
    content.set_chinese_convert_type(1);
    content.toggle_same_title_removed(BOOK, 0, false).unwrap();
    let a = service(Some(storage.clone()));
    let b = service(Some(second.storage().clone()));
    drop(first);
    assert!(weak.upgrade().is_none(), "导出不能持有整套引擎");

    let options = ExportOptions {
        start_chapter: Some(0),
        end_chapter: Some(0),
        file_name_template: Some("{name}-{author}".into()),
        ..Default::default()
    };
    let output = a.export_book(BOOK, "txt", false, &options).unwrap();
    assert_eq!(output.file_name.as_deref(), Some("测试甲-作者.txt"));
    let a_text = text(output);
    let b_text = text(b.export_book(BOOK, "txt", false, &options).unwrap());
    assert!(a_text.contains("测试甲"));
    assert!(
        a_text.matches("第一章").count() >= 2,
        "甲实例保留正文中的重复章名"
    );
    assert!(!a_text.contains("第二章"));
    assert!(b_text.contains("測試乙"));
    assert_eq!(b_text.matches("第一章").count(), 1, "乙实例仍删除重复章名");
    let preview = a.export_info(BOOK, "txt").unwrap();
    assert_eq!(preview.chapter_count, Some(2));
    storage
        .with_database(|db| {
            let cached = CacheBookRepository::new(db.connection()).get_by_book(BOOK)?;
            assert_eq!(cached.len(), 2);
            assert!(cached.iter().all(|c| c.content.contains("測試正文")));
            Ok(())
        })
        .unwrap();
}

#[test]
fn export_disables_resegment_even_when_book_enables_it() {
    let engine = EngineContext::in_memory().unwrap();
    seed(engine.storage(), "甲");
    engine
        .storage()
        .with_database(|db| {
            let repository = BookRepository::new(db.connection());
            let mut book = repository.find_by_url(BOOK)?.unwrap();
            book.read_config = Some(legado_core::models::ReadConfig {
                re_segment: true,
                ..Default::default()
            });
            repository.update(&book)
        })
        .unwrap();
    let raw = "前半\n后半。\n下一段。";
    assert!(save_chapter_cache(
        engine.storage(),
        BOOK,
        0,
        "第一章",
        "https://same-export.test/one",
        raw
    ));
    let output = text(
        service(Some(engine.storage().clone()))
            .export_book(
                BOOK,
                "txt",
                false,
                &ExportOptions {
                    start_chapter: Some(0),
                    end_chapter: Some(0),
                    ..Default::default()
                },
            )
            .unwrap(),
    );
    assert!(output.replace("\r\n", "\n").contains(raw));
}

#[test]
fn export_preserves_format_missing_book_and_uninitialized_errors() {
    let unavailable = service(None);
    assert!(unavailable.export_info(BOOK, "txt").is_err());
    let bad_format = unavailable
        .export_book(BOOK, "unknown", false, &ExportOptions::default())
        .unwrap();
    assert!(!bad_format.success);
    assert!(bad_format.error.unwrap().contains("不支持的导出格式"));
    let engine = EngineContext::in_memory().unwrap();
    let missing = service(Some(engine.storage().clone()))
        .export_book(BOOK, "txt", false, &ExportOptions::default())
        .unwrap();
    assert!(!missing.success);
    assert!(missing.error.unwrap().contains("书籍不存在"));
}

#[test]
fn pdf_images_use_the_injected_fetcher_with_an_absolute_chapter_url() {
    use std::sync::Mutex;
    let engine = EngineContext::in_memory().unwrap();
    seed(engine.storage(), "图");
    assert!(save_chapter_cache(
        engine.storage(),
        BOOK,
        0,
        "第一章",
        "https://same-export.test/one",
        r#"<img src="/page.png">"#
    ));
    let calls = Arc::new(Mutex::new(Vec::new()));
    let captured = calls.clone();
    let exporter = BookExportService::new(BookExportResources {
        storage: Some(engine.storage().clone()),
        image_fetcher: Arc::new(move |url| {
            captured.lock().unwrap().push(url.to_string());
            // 有效的单像素 RGB PNG，验证实际解码、嵌入和 PDF 输出。
            Ok(vec![
                137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0,
                1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 120, 156, 99,
                248, 207, 192, 0, 0, 3, 1, 1, 0, 201, 254, 146, 239, 0, 0, 0, 0, 73, 69, 78, 68,
                174, 66, 96, 130,
            ])
        }),
    });
    let output = exporter
        .export_book(
            BOOK,
            "pdf",
            false,
            &ExportOptions {
                end_chapter: Some(0),
                ..Default::default()
            },
        )
        .unwrap();
    if output.success {
        let bytes = output.data.unwrap();
        assert!(bytes.starts_with(b"%PDF"));
        assert_eq!(
            *calls.lock().unwrap(),
            ["https://same-export.test/page.png"]
        );
        eprintln!(
            "图片能力验证：PNG 已经解码并嵌入 PDF，共 {} 字节",
            bytes.len()
        );
    } else {
        eprintln!("图片能力验证受字体环境限制：{:?}", output.error);
        assert!(
            output.error.unwrap().contains("字体"),
            "仅允许环境缺少字体时无法输出 PDF"
        );
        assert!(calls.lock().unwrap().is_empty(), "字体检查应在图片请求之前");
    }
}
