//! 版本1备份先完整解析，再在同一事务内恢复；失败不留下部分业务数据。

use super::*;
use serde::de::DeserializeOwned;

struct RestoreData {
    books: Vec<Book>,
    bookmarks: Vec<Bookmark>,
    replace_rules: Vec<legado_core::models::ReplaceRule>,
    book_sources: Vec<BookSource>,
    rss_sources: Vec<RssSource>,
    read_records: Vec<legado_db::ReadRecord>,
}

impl RestoreData {
    fn parse(bytes: &[u8]) -> LegadoResult<Self> {
        if bytes.starts_with(b"PK\x03\x04") || bytes.starts_with(b"PK\x05\x06") {
            return Err(LegadoError::Parser(
                "暂不支持ZIP备份，请选择本项目生成的JSON备份".into(),
            ));
        }
        let value: serde_json::Value = serde_json::from_slice(bytes)
            .map_err(|e| LegadoError::Parser(format!("备份JSON解析失败: {e}")))?;
        let object = value
            .as_object()
            .ok_or_else(|| LegadoError::Parser("备份必须为JSON对象".into()))?;
        if object.get("version").and_then(serde_json::Value::as_i64) != Some(1) {
            return Err(LegadoError::Parser(
                "备份版本缺失或不受支持，当前仅支持版本1".into(),
            ));
        }
        if ![
            "books",
            "bookmarks",
            "replaceRules",
            "bookSources",
            "rssSources",
            "readRecords",
        ]
        .iter()
        .any(|key| object.contains_key(*key))
        {
            return Err(LegadoError::Parser("备份未包含可识别的业务数据集合".into()));
        }
        let backup: BackupData = serde_json::from_value(value)
            .map_err(|e| LegadoError::Parser(format!("备份结构错误: {e}")))?;
        Ok(Self {
            books: parse_rows(backup.books, "books")?,
            bookmarks: parse_rows(backup.bookmarks, "bookmarks")?,
            replace_rules: parse_rows(backup.replace_rules, "replaceRules")?,
            book_sources: parse_rows(backup.book_sources, "bookSources")?,
            rss_sources: parse_rows(backup.rss_sources, "rssSources")?,
            read_records: parse_rows(backup.read_records, "readRecords")?,
        })
    }
}

fn parse_rows<T: DeserializeOwned>(
    values: Vec<serde_json::Value>,
    collection: &str,
) -> LegadoResult<Vec<T>> {
    values
        .into_iter()
        .enumerate()
        .map(|(index, value)| {
            serde_json::from_value(value).map_err(|e| {
                LegadoError::Parser(format!("备份{collection}第{}项解析失败: {e}", index + 1))
            })
        })
        .collect()
}

fn write_rows<T>(
    values: &[T],
    collection: &str,
    mut insert: impl FnMut(&T) -> LegadoResult<()>,
) -> LegadoResult<usize> {
    for (index, value) in values.iter().enumerate() {
        insert(value).map_err(|e| {
            LegadoError::Database(format!("恢复{collection}第{}项失败: {e}", index + 1))
        })?;
    }
    Ok(values.len())
}

pub(super) fn restore(service: &BackupService, path: &str) -> LegadoResult<RestoreStats> {
    let bytes = fs::read(path).map_err(|e| {
        LegadoError::Io(std::io::Error::new(
            e.kind(),
            format!("读取备份文件失败: {e}"),
        ))
    })?;
    let data = RestoreData::parse(&bytes)?;
    service.with_database(|db| {
        let transaction = db
            .connection()
            .unchecked_transaction()
            .map_err(|e| LegadoError::Database(format!("开始备份恢复事务失败: {e}")))?;
        let conn = &transaction;
        let stats = RestoreStats {
            books: write_rows(&data.books, "books", |book| {
                BookRepository::new(conn).insert(book)
            })?,
            bookmarks: write_rows(&data.bookmarks, "bookmarks", |bookmark| {
                BookmarkRepository::new(conn).insert(bookmark).map(|_| ())
            })?,
            replace_rules: write_rows(&data.replace_rules, "replaceRules", |rule| {
                ReplaceRuleRepository::new(conn).insert(rule).map(|_| ())
            })?,
            book_sources: write_rows(&data.book_sources, "bookSources", |source| {
                BookSourceRepository::new(conn).insert(source)
            })?,
            rss_sources: write_rows(&data.rss_sources, "rssSources", |source| {
                insert_rss_source(conn, source)
            })?,
            read_records: write_rows(&data.read_records, "readRecords", |record| {
                ReadRecordRepository::new(conn).upsert_full(
                    &record.device_id,
                    &record.book_name,
                    &record.author,
                    record.read_time,
                    record.last_read,
                )
            })?,
        };
        transaction
            .commit()
            .map_err(|e| LegadoError::Database(format!("提交备份恢复事务失败: {e}")))?;
        Ok(stats)
    })
}
