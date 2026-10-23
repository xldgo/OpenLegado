//! 应用业务快照的专用仓储；不复制整个数据库，不读取临时表和凭据表。
use crate::{BookRepository, CacheRepository, repository::Repository};
use legado_core::{LegadoError, LegadoResult, models::Book};
use rusqlite::{
    Connection, params_from_iter,
    types::{Value as SqlValue, ValueRef},
};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::collections::{BTreeMap, BTreeSet};

pub type Record = Map<String, Value>;
pub type Collections = BTreeMap<String, Vec<Record>>;
// 顺序同时定义恢复依赖；这里只包含用户业务数据，不根据输入动态增加表。
pub const TABLES: &[(&str, &str)] = &[
    ("bookGroups", "book_groups"),
    ("bookSources", "book_sources"),
    ("books", "books"),
    ("bookmarks", "bookmarks"),
    ("replaceRules", "replace_rules"),
    ("rssSources", "rssSources"),
    ("rssStars", "rssStars"),
    ("rssReadRecords", "rssReadRecords"),
    ("ruleSubs", "ruleSubs"),
    ("txtTocRules", "txtTocRules"),
    ("dictRules", "dictRules"),
    ("keyboardAssists", "keyboardAssists"),
    ("coverRules", "coverRules"),
    ("autoTasks", "auto_task_rules"),
    ("searchHistory", "search_keywords"),
    ("highlightRules", "highlightRules"),
    ("highlights", "highlights"),
    ("httpTts", "httpTTS"),
    ("cloudTtsEngines", "cloud_tts_engines"),
    ("readAloudVoices", "read_aloud_voices"),
    ("readRecords", "readRecord"),
    ("readRecordDetails", "readRecordDetail"),
    ("readRecordDaily", "readRecordDaily"),
    ("readRecordSessions", "readRecordSession"),
];
// Rust普通偏好的显式范围；JS任意键、会话、Token和其他缓存不由此导出。
pub const CONFIG_KEYS: &[&str] = &[
    "contentSplitMode",
    "contentSplitSymbols",
    "ttsFollowSys",
    "ttsSpeechRate",
    "ttsParagraphInterval",
    "readAloudDetachReminderEnabled",
    "mediaButtonPerNext",
    "audioPreDownloadNum",
    "ttsPreSynthesisConcurrency",
    "audioCacheCleanTime",
    "precisionSearch",
    "searchResultFilter",
    "searchScope",
    "searchGroup",
    "threadCount",
    "cacheBookThreadCount",
    "preDownloadNum",
    "preDownloadNumBackward",
    "replaceEnableDefault",
    "audioSkipOpenCredits",
    "audioSkipCloseCredits",
    "changeSourceCheckAuthor",
    "changeSourceLoadWordCount",
    "changeSourceLoadInfo",
    "changeSourceLoadToc",
    "mangaColorFilter",
    "mangaFooterConfig",
    "enableMangaEInk",
    "enableMangaGray",
    "mangaEInkThreshold",
    "mangaScrollMode",
    "mangaAutoReadSpeed",
    "mangaPageScaleType",
    "mangaSidePadding",
    "disableClickScroll",
    "disableMangaScale",
    "disableMangaPageAnim",
    "hideMangaTitle",
    "volumeKeyPage",
    "reverseVolumeKeyPage",
    "mangaLongClickSaveImage",
    "disableMangaCrossFade",
    "mangaBgColor",
    "mangaClickActions",
    "webServiceAutoStart",
    "autoTaskService",
    "mcpPort",
    "customHosts",
];
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackupData {
    pub format: String,
    pub version: i32,
    pub backup_time: i64,
    pub collections: Collections,
    pub config: BTreeMap<String, String>,
}
#[derive(Debug)]
struct Column {
    name: String,
    kind: String,
    required: bool,
    primary: i32,
}
fn error(message: impl Into<String>) -> LegadoError {
    LegadoError::Parser(message.into())
}
fn db(error: rusqlite::Error) -> LegadoError {
    LegadoError::Database(format!("业务备份操作失败: {error}"))
}
fn quote(name: &str) -> String {
    format!("\"{}\"", name.replace('"', "\"\""))
}
fn columns(conn: &Connection, table: &str) -> LegadoResult<Vec<Column>> {
    let mut stmt = conn
        .prepare(&format!("PRAGMA table_info({})", quote(table)))
        .map_err(db)?;
    let result = stmt
        .query_map([], |r| {
            Ok(Column {
                name: r.get(1)?,
                kind: r.get(2)?,
                required: r.get::<_, i32>(3)? != 0,
                primary: r.get(5)?,
            })
        })
        .map_err(db)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(db)?;
    if result.is_empty() {
        return Err(error(format!("备份所需表{table}不存在")));
    }
    Ok(result)
}
fn sql_value(value: &Value, column: &Column) -> LegadoResult<SqlValue> {
    if value.is_null() && !column.required && column.primary == 0 {
        return Ok(SqlValue::Null);
    }
    let converted = match column.kind.as_str() {
        "INTEGER" => value.as_i64().map(SqlValue::Integer),
        "REAL" => value.as_f64().map(SqlValue::Real),
        "TEXT" => value.as_str().map(|s| SqlValue::Text(s.into())),
        _ => None,
    };
    converted.ok_or_else(|| {
        error(format!(
            "字段{}必须为{}{}",
            column.name,
            column.kind,
            if column.required {
                "且不能为空"
            } else {
                ""
            }
        ))
    })
}
fn collect(conn: &Connection, key: &str, table: &str) -> LegadoResult<Vec<Record>> {
    if key == "books" {
        return BookRepository::new(conn)
            .find_all()?
            .into_iter()
            .map(|b| match serde_json::to_value(b)? {
                Value::Object(row) => Ok(row),
                _ => unreachable!(),
            })
            .collect();
    }
    let fields = columns(conn, table)?;
    let names = fields
        .iter()
        .map(|c| quote(&c.name))
        .collect::<Vec<_>>()
        .join(",");
    let mut stmt = conn
        .prepare(&format!(
            "SELECT {names} FROM {} ORDER BY rowid",
            quote(table)
        ))
        .map_err(db)?;
    let rows = stmt
        .query_map([], |row| {
            let mut record = Record::new();
            for (i, field) in fields.iter().enumerate() {
                let value = match row.get_ref(i)? {
                    ValueRef::Null => Value::Null,
                    ValueRef::Integer(n) => Value::from(n),
                    ValueRef::Real(n) => Value::from(n),
                    ValueRef::Text(s) => Value::String(
                        std::str::from_utf8(s)
                            .map_err(|e| {
                                rusqlite::Error::FromSqlConversionFailure(
                                    i,
                                    rusqlite::types::Type::Text,
                                    Box::new(e),
                                )
                            })?
                            .into(),
                    ),
                    ValueRef::Blob(_) => {
                        return Err(rusqlite::Error::InvalidColumnType(
                            i,
                            field.name.clone(),
                            rusqlite::types::Type::Blob,
                        ));
                    }
                };
                record.insert(field.name.clone(), value);
            }
            Ok(record)
        })
        .map_err(db)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(db)?;
    Ok(rows)
}

pub struct BackupRepository<'a> {
    conn: &'a Connection,
}
impl<'a> BackupRepository<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }
    pub fn export(&self, now: i64) -> LegadoResult<BackupData> {
        // 每日表可能尚无首次统计，初始化由现有仓储负责。
        crate::ReadRecordRepository::new(self.conn).ensure_daily_table()?;
        let tx = self.conn.unchecked_transaction().map_err(db)?;
        let collections = TABLES
            .iter()
            .map(|(key, table)| Ok(((*key).into(), collect(&tx, key, table)?)))
            .collect::<LegadoResult<Collections>>()?;
        let mut config = BTreeMap::new();
        for key in CONFIG_KEYS {
            if let Some(value) = CacheRepository::new(&tx).get(&format!("config:{key}"))? {
                config.insert((*key).into(), value);
            }
        }
        let data = BackupData {
            format: "openlegado".into(),
            version: 2,
            backup_time: now,
            collections,
            config,
        };
        self.validate(&data)?;
        tx.commit().map_err(db)?;
        Ok(data)
    }
    pub fn validate(&self, data: &BackupData) -> LegadoResult<()> {
        if data.format != "openlegado" || data.version != 2 {
            return Err(error("备份格式或版本不受支持，当前需要OpenLegado版本2备份"));
        }
        crate::ReadRecordRepository::new(self.conn).ensure_daily_table()?;
        if data.collections.len() != TABLES.len()
            || TABLES
                .iter()
                .any(|(k, _)| !data.collections.contains_key(*k))
        {
            return Err(error("业务备份集合缺失或包含未知集合"));
        }
        if data
            .config
            .keys()
            .any(|k| !CONFIG_KEYS.contains(&k.as_str()))
        {
            return Err(error("备份包含未授权的配置键"));
        }
        for (key, table) in TABLES {
            let fields = columns(self.conn, table)?;
            let mut identities = BTreeSet::new();
            for (index, record) in data.collections[*key].iter().enumerate() {
                let check = (|| {
                    let identity = if *key == "books" {
                        let book: Book = serde_json::from_value(Value::Object(record.clone()))?;
                        if book.book_url.is_empty() {
                            return Err(error("书籍缺少bookUrl"));
                        }
                        let normalized = serde_json::to_value(&book)?;
                        if record.len() != normalized.as_object().map_or(0, Map::len)
                            || record.keys().any(|key| normalized.get(key).is_none())
                        {
                            return Err(error("书籍包含未知字段"));
                        }
                        Value::String(book.book_url)
                    } else {
                        if record.len() != fields.len()
                            || fields.iter().any(|c| !record.contains_key(&c.name))
                        {
                            return Err(error("字段缺失或包含未知字段"));
                        }
                        for field in &fields {
                            sql_value(&record[&field.name], field)?;
                        }
                        let mut primary =
                            fields.iter().filter(|c| c.primary > 0).collect::<Vec<_>>();
                        primary.sort_by_key(|c| c.primary);
                        Value::Array(primary.iter().map(|c| record[&c.name].clone()).collect())
                    };
                    if !identities.insert(serde_json::to_string(&identity)?) {
                        return Err(error("重复主键"));
                    }
                    Ok(())
                })();
                check.map_err(|e| error(format!("备份{key}第{}项无效: {e}", index + 1)))?;
            }
        }
        Ok(())
    }
    pub fn restore(&self, data: &BackupData) -> LegadoResult<BTreeMap<String, usize>> {
        self.validate(data)?;
        let tx = self.conn.unchecked_transaction().map_err(db)?;
        let mut counts = BTreeMap::new();
        for (key, table) in TABLES {
            let fields = columns(&tx, table)?;
            let names = fields
                .iter()
                .map(|c| quote(&c.name))
                .collect::<Vec<_>>()
                .join(",");
            let placeholders = vec!["?"; fields.len()].join(",");
            let mut primary = fields.iter().filter(|c| c.primary > 0).collect::<Vec<_>>();
            primary.sort_by_key(|c| c.primary);
            let keys = primary
                .iter()
                .map(|c| quote(&c.name))
                .collect::<Vec<_>>()
                .join(",");
            let assignments = fields
                .iter()
                .filter(|c| c.primary == 0)
                .map(|c| format!("{0}=excluded.{0}", quote(&c.name)))
                .collect::<Vec<_>>()
                .join(",");
            let sql = format!(
                "INSERT INTO {} ({names}) VALUES ({placeholders}) ON CONFLICT ({keys}) DO UPDATE SET {assignments}",
                quote(table)
            );
            for (index, record) in data.collections[*key].iter().enumerate() {
                let result = if *key == "books" {
                    let book: Book = serde_json::from_value(Value::Object(record.clone()))?;
                    BookRepository::new(&tx).insert(&book)
                } else {
                    let values = fields
                        .iter()
                        .map(|c| sql_value(&record[&c.name], c))
                        .collect::<LegadoResult<Vec<_>>>()?;
                    tx.execute(&sql, params_from_iter(values))
                        .map(|_| ())
                        .map_err(db)
                };
                result.map_err(|e| {
                    LegadoError::Database(format!("恢复{key}第{}项失败: {e}", index + 1))
                })?;
            }
            counts.insert((*key).into(), data.collections[*key].len());
        }
        for (key, value) in &data.config {
            CacheRepository::new(&tx).put(&format!("config:{key}"), value, 0)?;
        }
        tx.commit()
            .map_err(|e| LegadoError::Database(format!("提交备份恢复事务失败: {e}")))?;
        Ok(counts)
    }
}

#[cfg(test)]
mod tests;
