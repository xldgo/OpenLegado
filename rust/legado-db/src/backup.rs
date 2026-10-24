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
    default_sql: Option<String>,
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
                default_sql: r.get(4)?,
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

/// 上游ZIP的显式字段映射。先构造独立快照；不在解析阶段写目标数据库。
pub fn from_upstream(files: &BTreeMap<String, Vec<u8>>) -> LegadoResult<(BackupData, Vec<String>)> {
    let memory = crate::init_in_memory_database()?;
    let conn = memory.connection();
    let mut data = BackupRepository::new(conn).export(0)?;
    let mut consumed = BTreeSet::new();
    let mut warnings = BTreeSet::new();
    if let Some(raw) = files.get("bookshelf.json") {
        let books: Vec<Book> = serde_json::from_slice(raw)?;
        data.collections.insert(
            "books".into(),
            books
                .into_iter()
                .map(|book| match serde_json::to_value(book)? {
                    Value::Object(v) => Ok(v),
                    _ => unreachable!(),
                })
                .collect::<LegadoResult<Vec<_>>>()?,
        );
        consumed.insert("bookshelf.json");
        warnings.insert("原版书籍中本项目尚未定义的扩展字段不承诺无损保留".into());
    }
    if let Some(raw) = files.get("bookSource.json") {
        let text = std::str::from_utf8(raw).map_err(|_| error("bookSource.json不是UTF-8"))?;
        let sources = legado_core::models::book_source::parse_source_array(text)?;
        for source in &sources {
            crate::BookSourceRepository::new(conn).insert(source)?;
        }
        data.collections.insert(
            "bookSources".into(),
            collect(conn, "bookSources", "book_sources")?,
        );
        consumed.insert("bookSource.json");
    }
    if let Some(raw) = files.get("highlightRule.json") {
        let text = std::str::from_utf8(raw).map_err(|_| error("highlightRule.json不是UTF-8"))?;
        let rules = legado_core::highlight_rules::parse_document(text)?;
        crate::HighlightRuleRepository::new(conn).import(&rules)?;
        data.collections.insert(
            "highlightRules".into(),
            collect(conn, "highlightRules", "highlightRules")?,
        );
        consumed.insert("highlightRule.json");
    }
    for (file, key) in [
        ("bookGroup.json", "bookGroups"),
        ("bookmark.json", "bookmarks"),
        ("replaceRule.json", "replaceRules"),
        ("rssSources.json", "rssSources"),
        ("rssStar.json", "rssStars"),
        ("sourceSub.json", "ruleSubs"),
        ("txtTocRule.json", "txtTocRules"),
        ("httpTTS.json", "httpTts"),
        ("dictRule.json", "dictRules"),
        ("keyboardAssists.json", "keyboardAssists"),
        ("searchHistory.json", "searchHistory"),
        ("readRecord.json", "readRecords"),
        ("readRecordDetail.json", "readRecordDetails"),
        ("readRecordSession.json", "readRecordSessions"),
        ("highlight.json", "highlights"),
        ("autoTask.json", "autoTasks"),
    ] {
        let Some(raw) = files.get(file) else {
            continue;
        };
        let records: Vec<Record> =
            serde_json::from_slice(raw).map_err(|e| error(format!("{file}结构错误: {e}")))?;
        let (_, table) = TABLES.iter().find(|(name, _)| *name == key).unwrap();
        let fields = columns(conn, table)?;
        let mut rows = Vec::new();
        for (index, mut input) in records.into_iter().enumerate() {
            if key == "readRecords" && !input.contains_key("author") {
                if let Some(value) = input.remove("bookAuthor") {
                    input.insert("author".into(), value);
                }
            }
            if key == "readRecordDetails" && !input.contains_key("lastRead") {
                if let Some(value) = input.remove("lastReadTime") {
                    input.insert("lastRead".into(), value);
                }
            }
            if key == "readRecordSessions" && !input.contains_key("chapterIndex") {
                if let Some(value) = input.remove("words") {
                    input.insert("chapterIndex".into(), value);
                }
            }
            if key == "bookmarks" && !input.contains_key("id") {
                if let Some(time) = input.get("time").cloned() {
                    input.insert("id".into(), time);
                }
            }
            let unknown = input
                .keys()
                .filter(|name| !fields.iter().any(|field| field.name == **name))
                .cloned()
                .collect::<Vec<_>>();
            if !unknown.is_empty() {
                warnings.insert(format!("{file}未恢复扩展字段：{}", unknown.join("、")));
            }
            let mut row = Record::new();
            for field in &fields {
                let value = if let Some(value) = input.get(&field.name) {
                    match (field.kind.as_str(), value) {
                        ("INTEGER", Value::Bool(v)) => Value::from(i32::from(*v)),
                        ("TEXT", Value::Null) => Value::Null,
                        ("TEXT", Value::String(v)) => Value::String(v.clone()),
                        ("TEXT", v) => Value::String(v.to_string()),
                        (_, v) => v.clone(),
                    }
                } else if let Some(default) = &field.default_sql {
                    let value: SqlValue = conn
                        .query_row(&format!("SELECT {default}"), [], |r| r.get(0))
                        .map_err(db)?;
                    match value {
                        SqlValue::Null => Value::Null,
                        SqlValue::Integer(v) => Value::from(v),
                        SqlValue::Real(v) => Value::from(v),
                        SqlValue::Text(v) => Value::String(v),
                        SqlValue::Blob(_) => return Err(error("不支持的字段默认值")),
                    }
                } else if !field.required && field.primary == 0 {
                    Value::Null
                } else if field.primary > 0 && field.name == "id" {
                    warnings.insert(format!(
                        "{file}无本项目ID，按文件顺序建立标识；冲突时整批拒绝"
                    ));
                    Value::from((index + 1) as i64)
                } else if field.kind == "TEXT" {
                    Value::String(String::new())
                } else {
                    Value::from(0)
                };
                sql_value(&value, field)
                    .map_err(|e| error(format!("{file}第{}项: {e}", index + 1)))?;
                row.insert(field.name.clone(), value);
            }
            rows.push(row);
        }
        data.collections.insert(key.into(), rows);
        consumed.insert(file);
    }
    // 日总数是明细的派生投影，单位为秒；不把毫秒直接写入日总表。
    let mut daily = BTreeMap::<String, i64>::new();
    for row in &data.collections["readRecordDetails"] {
        if let (Some(date), Some(time)) = (row["date"].as_str(), row["readTime"].as_i64()) {
            let total = daily.entry(date.into()).or_default();
            *total = total
                .checked_add(time)
                .ok_or_else(|| error("阅读明细时长溢出"))?;
        }
    }
    data.collections.insert(
        "readRecordDaily".into(),
        daily
            .into_iter()
            .map(|(date, time)| {
                Record::from_iter([
                    ("date".into(), Value::String(date)),
                    ("durationSeconds".into(), Value::from(time / 1000)),
                ])
            })
            .collect(),
    );
    if consumed.is_empty() {
        return Err(error("ZIP不是可识别的OpenLegado或原版备份"));
    }
    for name in files.keys() {
        if !consumed.contains(name.as_str()) {
            warnings.insert(format!("未恢复上游成员：{name}"));
        }
    }
    // 上游以作者区分累计记录；目标身份冲突必须拒绝，不能覆盖某一作者。
    BackupRepository::new(conn).validate(&data)?;
    Ok((data, warnings.into_iter().collect()))
}

#[cfg(test)]
mod tests;
