//! ReadRecord Repository - readRecord 表 CRUD

use std::collections::BTreeSet;

#[cfg(test)]
use chrono::Datelike;
use chrono::{Local, TimeZone};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};

use legado_core::{LegadoError, LegadoResult};

/// 阅读记录
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ReadRecord {
    /// 设备标识（v101 补齐 Room 基线 deviceId 列，当前单设备 Rust 侧固定空串）
    #[serde(default, rename = "deviceId")]
    pub device_id: String,
    pub book_name: String,
    /// 作者（同书名的多本书共用一条记录时，以作者集合形式合并存储）
    #[serde(default)]
    pub author: String,
    pub read_time: i64,
    /// 最后阅读时间戳（毫秒）
    #[serde(default, rename = "lastRead")]
    pub last_read: i64,
}

/// 单书每日明细记录
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct ReadRecordDetail {
    #[serde(default, rename = "deviceId")]
    pub device_id: String,
    #[serde(rename = "bookName")]
    pub book_name: String,
    #[serde(rename = "author")]
    pub author: String,
    pub date: String,
    #[serde(rename = "readTime")]
    pub read_time: i64,
    #[serde(default, rename = "lastRead")]
    pub last_read: i64,
}

/// 作者集合存储前缀（对齐上游 Kotlin `ReadRecordAuthors.PREFIX`）
///
/// author 列兼容纯文本旧记录：无前缀时为单一作者；
/// 多作者时存储为 `\u{1E}authors:` + JSON 字符串数组。
const AUTHORS_PREFIX: &str = "\u{1E}authors:";

/// 解码 author 列值为作者列表（对齐上游 `ReadRecordAuthors.decode`）
///
/// - 空白值返回空列表（上游返回 {""}，合并时会被非空过滤掉，等价）；
/// - 无前缀视为单一作者；
/// - 前缀后 JSON 解析失败时返回空列表（上游 getOrNull 后同样被过滤）。
///
/// 公开供上层构建阅读记录索引使用（如搜索结果阅读记录标识，
/// 对齐上游 `ReadRecordIndex.of` 对 author 列的解码）。
pub fn decode_read_record_authors(value: &str) -> Vec<String> {
    if value.trim().is_empty() {
        return Vec::new();
    }
    if let Some(json) = value.strip_prefix(AUTHORS_PREFIX) {
        serde_json::from_str::<Vec<String>>(json)
            .map(|arr| {
                let mut out: Vec<String> = Vec::new();
                for a in arr {
                    // 保持插入顺序并去重（上游 linkedSetOf 语义）
                    if !a.trim().is_empty() && !out.contains(&a) {
                        out.push(a);
                    }
                }
                out
            })
            .unwrap_or_default()
    } else {
        vec![value.to_string()]
    }
}

/// 合并两个 author 列值（对齐上游 `ReadRecordAuthors.merge`）
///
/// 取并集后去空白、去重并按字典序排序（上游 sortedSetOf）：
/// - 0 个作者 → 空字符串；
/// - 1 个作者 → 纯文本（兼容旧记录）；
/// - 多个作者 → `前缀 + JSON 数组`。
pub fn merge_read_record_authors(current: &str, incoming: &str) -> String {
    let mut set: BTreeSet<String> = BTreeSet::new();
    for author in decode_read_record_authors(current)
        .into_iter()
        .chain(decode_read_record_authors(incoming))
    {
        if !author.trim().is_empty() {
            set.insert(author);
        }
    }
    match set.len() {
        0 => String::new(),
        1 => set.into_iter().next().unwrap_or_default(),
        _ => {
            let arr: Vec<String> = set.into_iter().collect();
            format!(
                "{AUTHORS_PREFIX}{}",
                serde_json::to_string(&arr).unwrap_or_default()
            )
        }
    }
}

/// 阅读记录数据访问层
/// 一次累计阅读写入的会话上下文。— Codex
pub struct ReadingSessionInput<'a> {
    pub book_name: &'a str,
    pub author: &'a str,
    pub read_time_ms: i64,
    pub start_time_ms: Option<i64>,
    pub end_time_ms: Option<i64>,
    pub book_url: &'a str,
    pub chapter_index: i32,
}

pub struct ReadRecordRepository<'a> {
    pub(super) conn: &'a Connection,
}

impl<'a> ReadRecordRepository<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }

    /// 添加/更新阅读记录（主键冲突时替换）
    ///
    /// 说明：本方法签名保持不变（FFI 既有契约），deviceId/lastRead 依赖列默认值
    /// （''/0）；需要写入新字段时使用 [`upsert_full`]。
    pub fn upsert(&self, book_name: &str, read_time: i64) -> LegadoResult<()> {
        // 主键 (deviceId, bookName)；单设备 deviceId=''；保留 author/lastRead
        self.conn
            .execute(
                "INSERT INTO readRecord (deviceId, bookName, readTime)
                 VALUES ('', ?1, ?2)
                 ON CONFLICT(deviceId, bookName) DO UPDATE SET readTime = excluded.readTime",
                params![book_name, read_time],
            )
            .map_err(|e| LegadoError::Database(format!("更新阅读记录失败: {e}")))?;
        Ok(())
    }

    /// 添加/更新阅读记录（全字段版，覆盖 v101 新增的 deviceId/lastRead 列）
    ///
    /// 主键冲突时整行替换；author 不做合并（调用方自行处理）。
    pub fn upsert_full(
        &self,
        device_id: &str,
        book_name: &str,
        author: &str,
        read_time: i64,
        last_read: i64,
    ) -> LegadoResult<()> {
        self.conn
            .execute(
                "INSERT OR REPLACE INTO readRecord
                 (deviceId, bookName, author, readTime, lastRead)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![device_id, book_name, author, read_time, last_read],
            )
            .map_err(|e| LegadoError::Database(format!("更新阅读记录失败: {e}")))?;
        Ok(())
    }

    /// 更新指定书籍的最后阅读位置（lastRead 列，v101 新增）
    pub fn update_last_read(&self, book_name: &str, last_read: i64) -> LegadoResult<bool> {
        let affected = self
            .conn
            .execute(
                "UPDATE readRecord SET lastRead = ?1 WHERE bookName = ?2",
                params![last_read, book_name],
            )
            .map_err(|e| LegadoError::Database(format!("更新 lastRead 失败: {e}")))?;
        Ok(affected > 0)
    }

    /// 添加/更新阅读记录并合并作者（对齐上游 `ReadRecordDao.insert` 事务）
    ///
    /// 上游语义：同设备同书名共用一条记录，新记录的 author 与库内旧 author
    /// 通过 `ReadRecordAuthors.merge` 合并后再 REPLACE 写入，
    /// 避免同名书不同作者互相覆盖；readTime 以传入值为准。
    pub fn insert_with_author(
        &self,
        book_name: &str,
        author: &str,
        read_time: i64,
    ) -> LegadoResult<()> {
        // 1. 读取旧记录的 author（对应上游 getAuthor(deviceId, bookName)）
        let existing = self.get_author(book_name)?.unwrap_or_default();

        // 2. 作者集合并（对应上游 ReadRecordAuthors.merge）
        let merged = merge_read_record_authors(&existing, author);

        // 3. upsert 写入（主键含 deviceId；保留 lastRead）
        self.conn
            .execute(
                "INSERT INTO readRecord (deviceId, bookName, author, readTime)
                 VALUES ('', ?1, ?2, ?3)
                 ON CONFLICT(deviceId, bookName) DO UPDATE SET
                   author = excluded.author,
                   readTime = excluded.readTime",
                params![book_name, merged, read_time],
            )
            .map_err(|e| LegadoError::Database(format!("更新阅读记录失败: {e}")))?;
        Ok(())
    }

    /// 获取指定书籍的完整阅读记录（含 author，对齐上游 `ReadRecordDao.getRecord`）
    pub fn get_record(&self, book_name: &str) -> LegadoResult<Option<ReadRecord>> {
        let mut stmt = self
            .conn
            .prepare(
                "SELECT bookName, author, readTime, deviceId, lastRead
                 FROM readRecord WHERE bookName = ?1",
            )
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;

        let record = stmt
            .query_row(params![book_name], |row| {
                Ok(ReadRecord {
                    device_id: row.get(3)?,
                    book_name: row.get(0)?,
                    author: row.get(1)?,
                    read_time: row.get(2)?,
                    last_read: row.get(4)?,
                })
            })
            .optional()
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?;
        Ok(record)
    }

    /// 获取指定书籍记录的 author 列（对齐上游 `ReadRecordDao.getAuthor`）
    pub fn get_author(&self, book_name: &str) -> LegadoResult<Option<String>> {
        let author: Option<String> = self
            .conn
            .query_row(
                "SELECT author FROM readRecord WHERE bookName = ?1",
                params![book_name],
                |row| row.get(0),
            )
            .optional()
            .map_err(|e| LegadoError::Database(format!("查询 author 失败: {e}")))?;
        Ok(author)
    }

    /// 返回有阅读记录的书名列表（对齐上游 `ReadRecordDao.flowBooks` 的书名维度）
    ///
    /// 上游返回 distinct (bookName, author) 对；Rust 侧 readRecord 主键即 bookName，
    /// 天然去重，按 bookName 排序输出。
    pub fn list_books(&self) -> LegadoResult<Vec<String>> {
        let mut stmt = self
            .conn
            .prepare("SELECT bookName FROM readRecord ORDER BY bookName ASC")
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;

        let names = stmt
            .query_map([], |row| row.get::<_, String>(0))
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?
            .collect::<rusqlite::Result<Vec<_>>>()
            .map_err(|e| LegadoError::Database(format!("read_record_repository行解析失败: {e}")))?;
        Ok(names)
    }

    /// 获取所有阅读记录（按 readTime 降序）
    pub fn find_all(&self) -> LegadoResult<Vec<ReadRecord>> {
        let mut stmt = self
            .conn
            .prepare(
                "SELECT bookName, author, readTime, deviceId, lastRead
                 FROM readRecord ORDER BY readTime DESC",
            )
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;

        let rows = stmt
            .query_map([], |row| {
                Ok(ReadRecord {
                    device_id: row.get(3)?,
                    book_name: row.get(0)?,
                    author: row.get(1)?,
                    read_time: row.get(2)?,
                    last_read: row.get(4)?,
                })
            })
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?
            .collect::<rusqlite::Result<Vec<_>>>()
            .map_err(|e| LegadoError::Database(format!("read_record_repository行解析失败: {e}")))?;
        Ok(rows)
    }

    /// 获取指定书籍的阅读记录
    pub fn find_by_book_name(&self, book_name: &str) -> LegadoResult<Option<ReadRecord>> {
        self.get_record(book_name)
    }

    /// 删除指定书籍的阅读记录
    pub fn delete_by_book_name(&self, book_name: &str) -> LegadoResult<bool> {
        self.delete_records(book_name, None)
    }

    fn delete_records(&self, book_name: &str, author: Option<&str>) -> LegadoResult<bool> {
        self.ensure_detail_table()?;
        self.ensure_daily_table()?;
        self.ensure_session_table()?;
        crate::connection::in_transaction(self.conn, "删除阅读记录", |conn| {
            let dates: Vec<String> = conn
                .prepare("SELECT DISTINCT date FROM readRecordDetail WHERE bookName = ?1")
                .and_then(|mut stmt| stmt.query_map([book_name], |row| row.get(0))?.collect())
                .map_err(|e| LegadoError::Database(format!("查询删除日期失败: {e}")))?;
            let removed: i64 = conn.query_row("SELECT COALESCE(SUM(readTime), 0) FROM readRecordDetail WHERE bookName = ?1 AND (?2 IS NULL OR bookAuthor = ?2)", params![book_name, author], |row| row.get(0))
                .map_err(|e| LegadoError::Database(format!("查询待删除明细失败: {e}")))?;
            let detail_count = conn.execute("DELETE FROM readRecordDetail WHERE bookName = ?1 AND (?2 IS NULL OR bookAuthor = ?2)", params![book_name, author])
                .map_err(|e| LegadoError::Database(format!("删除明细失败: {e}")))?;
            conn.execute(
                "DELETE FROM readRecordSession WHERE bookName=?1 AND (?2 IS NULL OR bookAuthor=?2)",
                params![book_name, author],
            )
            .map_err(|e| LegadoError::Database(format!("删除会话失败: {e}")))?;
            let affected = if let Some(author) = author {
                let old: Option<String> = conn.query_row("SELECT author FROM readRecord WHERE bookName = ?1", [book_name], |row| row.get(0)).optional()
                    .map_err(|e| LegadoError::Database(format!("查询作者失败: {e}")))?;
                if let Some(old) = old {
                    let remaining: Vec<_> = decode_read_record_authors(&old).into_iter().filter(|a| a != author).collect();
                    if remaining.is_empty() && (old.is_empty() || old == author) {
                        conn.execute("DELETE FROM readRecord WHERE bookName = ?1", [book_name])
                    } else if detail_count > 0 {
                        let authors = remaining.iter().fold(String::new(), |value, a| merge_read_record_authors(&value, a));
                        conn.execute("UPDATE readRecord SET author = ?1, readTime = MAX(0, readTime - ?2) WHERE bookName = ?3", params![authors, removed, book_name])
                    } else { Ok(0) }
                } else { Ok(0) }
            } else { conn.execute("DELETE FROM readRecord WHERE bookName = ?1", [book_name]) }
                .map_err(|e| LegadoError::Database(format!("删除累计记录失败: {e}")))?;
            for date in dates {
                sync_daily_seconds(conn, &date)?;
            }
            Ok(affected > 0 || detail_count > 0)
        })
    }

    /// 清空所有阅读记录，返回删除的行数
    pub fn clear_all(&self) -> LegadoResult<usize> {
        self.ensure_detail_table()?;
        self.ensure_daily_table()?;
        self.ensure_session_table()?;
        crate::connection::in_transaction(self.conn, "清空阅读记录", |conn| {
            let affected = conn
                .execute("DELETE FROM readRecord", [])
                .map_err(|e| LegadoError::Database(format!("清空阅读记录失败: {e}")))?;
            conn.execute("DELETE FROM readRecordSession", [])
                .map_err(|e| LegadoError::Database(format!("清空会话失败: {e}")))?;
            conn.execute("DELETE FROM readRecordDetail", [])
                .map_err(|e| LegadoError::Database(format!("清空阅读明细失败: {e}")))?;
            conn.execute("DELETE FROM readRecordDaily", [])
                .map_err(|e| LegadoError::Database(format!("清空每日聚合失败: {e}")))?;
            Ok(affected)
        })
    }

    /// 获取阅读记录总数
    pub fn count(&self) -> LegadoResult<i64> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM readRecord", [], |row| row.get(0))
            .map_err(|e| LegadoError::Database(format!("计数查询失败: {e}")))?;
        Ok(count)
    }

    // ─── [热力图每日时长契约] 每日时长聚合（热力图"每日时长"模式数据源）────────

    /// 确保 readRecordDaily 表存在（CREATE TABLE IF NOT EXISTS，无数据迁移需求）
    pub(crate) fn ensure_daily_table(&self) -> LegadoResult<()> {
        self.conn
            .execute(
                "CREATE TABLE IF NOT EXISTS readRecordDaily (\
                 date TEXT PRIMARY KEY,\
                 durationSeconds INTEGER NOT NULL DEFAULT 0)",
                [],
            )
            .map_err(|e| LegadoError::Database(format!("创建 readRecordDaily 表失败: {e}")))?;
        Ok(())
    }

    /// 向指定日期累计阅读秒数（增量 upsert）
    ///
    /// 日期格式：`YYYY-MM-DD`（本地时区）。
    /// 独立日总累加入口；正式阅读器由原子明细路径同步日总数。
    pub fn add_daily_seconds(&self, date: &str, seconds: i64) -> LegadoResult<()> {
        self.ensure_daily_table()?;
        self.conn
            .execute(
                "INSERT INTO readRecordDaily (date, durationSeconds) VALUES (?1, ?2)\
                 ON CONFLICT(date) DO UPDATE SET durationSeconds = durationSeconds + ?2",
                params![date, seconds],
            )
            .map_err(|e| LegadoError::Database(format!("更新每日阅读时长失败: {e}")))?;
        Ok(())
    }

    /// 按年查询每日阅读时长列表（热力图"每日时长"模式数据源）
    ///
    /// 返回按日期升序排列的 (date, durationSeconds) 对。
    pub fn list_daily_year(&self, year: i32) -> LegadoResult<Vec<(String, i64)>> {
        self.ensure_daily_table()?;
        let first = format!("{year:04}-01-01");
        let last = format!("{year:04}-12-31");
        let mut stmt = self
            .conn
            .prepare(
                "SELECT date, durationSeconds FROM readRecordDaily \
                 WHERE date >= ?1 AND date <= ?2 ORDER BY date ASC",
            )
            .map_err(|e| LegadoError::Database(format!("准备每日时长查询失败: {e}")))?;
        let rows = stmt
            .query_map(params![first, last], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
            })
            .map_err(|e| LegadoError::Database(format!("查询每日时长失败: {e}")))?
            .collect::<rusqlite::Result<Vec<_>>>()
            .map_err(|e| LegadoError::Database(format!("read_record_repository行解析失败: {e}")))?;
        Ok(rows)
    }

    // ─── [单书每日明细与原子写入契约] ──────────────────────────

    /// 确保 readRecordDetail 表存在（CREATE TABLE IF NOT EXISTS）
    pub fn ensure_detail_table(&self) -> LegadoResult<()> {
        self.conn
            .execute_batch(crate::schema::CREATE_READ_RECORD_DETAIL)
            .map_err(|e| LegadoError::Database(format!("创建明细表失败: {e}")))?;
        Ok(())
    }

    /// 原子记录阅读时间
    ///
    /// 语义：
    /// 1. 在单个 SQLite 事务中完成；
    /// 2. 读取旧累计时长，计算 `delta = read_time_ms - old_read_time_ms`，若 `delta <= 0` 幂等返回；
    /// 3. 根据 `start_time` 与 `end_time` 检查本地午夜（00:00:00），跨午夜时分段拆分各天的毫秒数；
    /// 4. 原子更新：`readRecord`（累计值与 lastRead）、`readRecordDetail`（各日期单书明细累加毫秒）及 `readRecordDaily`（各日期整秒增量累加）；
    /// 5. 事务失败自动回滚。
    pub fn record_reading_time(
        &self,
        book_name: &str,
        author: &str,
        read_time_ms: i64,
        start_time_ms: Option<i64>,
        end_time_ms: Option<i64>,
    ) -> LegadoResult<i64> {
        self.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name,
                author,
                read_time_ms,
                start_time_ms,
                end_time_ms,
                book_url: "",
                chapter_index: 0,
            },
        )
    }

    /// 本次新增时段与累计/每日明细原子提交，不补造旧会话。
    pub fn record_reading_time_with_session(
        &self,
        input: ReadingSessionInput<'_>,
    ) -> LegadoResult<i64> {
        let ReadingSessionInput {
            book_name,
            author,
            read_time_ms,
            start_time_ms,
            end_time_ms,
            book_url,
            chapter_index,
        } = input;
        if read_time_ms < 0 {
            return Err(LegadoError::Internal("累计阅读时长不能为负数".into()));
        }
        self.ensure_detail_table()?;
        self.ensure_daily_table()?;
        self.ensure_session_table()?;
        // 在读取累计值前获取写锁，避免两个连接读取相同的旧值后重复入账。
        let transaction = if self.conn.is_autocommit() {
            Some(
                rusqlite::Transaction::new_unchecked(
                    self.conn,
                    rusqlite::TransactionBehavior::Immediate,
                )
                .map_err(|e| LegadoError::Database(format!("开始阅读记录事务失败: {e}")))?,
            )
        } else {
            None
        };
        let existing: Option<(i64, String, String)> = self
            .conn
            .query_row(
                "SELECT readTime, deviceId, author FROM readRecord WHERE bookName = ?1",
                [book_name],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
            .optional()
            .map_err(|e| LegadoError::Database(format!("读取累计记录失败: {e}")))?;
        let old_time = existing.as_ref().map(|r| r.0).unwrap_or(0);
        let delta = read_time_ms
            .checked_sub(old_time)
            .ok_or_else(|| LegadoError::Internal("阅读时长溢出".into()))?;
        if delta <= 0 {
            return Ok(old_time);
        }
        let now_ms = Local::now().timestamp_millis();
        let end = end_time_ms.unwrap_or(now_ms);
        let segments = split_reading_time_segments(delta, start_time_ms, Some(end))?;
        let (device_id, old_author) = existing.map(|(_, d, a)| (d, a)).unwrap_or_default();
        let merged_author = merge_read_record_authors(&old_author, author);
        self.conn.execute(
            "INSERT INTO readRecord (deviceId, bookName, author, readTime, lastRead)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(deviceId, bookName) DO UPDATE SET
               author = excluded.author, readTime = excluded.readTime, lastRead = excluded.lastRead",
            params![device_id, book_name, merged_author, read_time_ms, end])
            .map_err(|e| LegadoError::Database(format!("更新累计记录失败: {e}")))?;
        self.conn.execute(
            "INSERT INTO readRecordSession(deviceId,bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex)
             VALUES(?1,?2,?3,?4,?5,?6,?7)",
            params![device_id,book_name,author,book_url,end-delta,end,chapter_index.max(0)])
            .map_err(|e| LegadoError::Database(format!("写入阅读会话失败: {e}")))?;
        let mut segment_end = end - delta;
        for (date, duration) in segments {
            segment_end += duration;
            self.conn.execute(
                "INSERT INTO readRecordDetail (deviceId, bookName, bookAuthor, date, readTime, lastRead)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)
                 ON CONFLICT(deviceId, bookName, bookAuthor, date) DO UPDATE SET
                 readTime = readRecordDetail.readTime + excluded.readTime,
                 lastRead = MAX(readRecordDetail.lastRead, excluded.lastRead)",
                params![device_id, book_name, author, date, duration, segment_end])
                .map_err(|e| LegadoError::Database(format!("更新每日明细失败: {e}")))?;
            sync_daily_seconds(self.conn, &date)?;
        }
        if let Some(transaction) = transaction {
            transaction
                .commit()
                .map_err(|e| LegadoError::Database(format!("提交阅读记录失败: {e}")))?;
        }
        Ok(read_time_ms)
    }

    /// 按年查询每日单书明细列表（按日期升序、时长降序）
    pub fn list_details_year(&self, year: i32) -> LegadoResult<Vec<ReadRecordDetail>> {
        self.ensure_detail_table()?;
        let first = format!("{year:04}-01-01");
        let last = format!("{year:04}-12-31");
        let mut stmt = self
            .conn
            .prepare(
                "SELECT deviceId, bookName, bookAuthor, date, readTime, lastRead \
                 FROM readRecordDetail \
                 WHERE date >= ?1 AND date <= ?2 \
                 ORDER BY date ASC, readTime DESC",
            )
            .map_err(|e| LegadoError::Database(format!("准备按年明细查询失败: {e}")))?;

        let rows = stmt
            .query_map(params![first, last], |row| {
                Ok(ReadRecordDetail {
                    device_id: row.get(0)?,
                    book_name: row.get(1)?,
                    author: row.get(2)?,
                    date: row.get(3)?,
                    read_time: row.get(4)?,
                    last_read: row.get(5)?,
                })
            })
            .map_err(|e| LegadoError::Database(format!("查询按年明细失败: {e}")))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| LegadoError::Database(format!("读取明细失败: {e}")))?;
        Ok(rows)
    }

    /// 查询全量历史单书明细列表（按日期升序、时长降序）
    pub fn list_all_details(&self) -> LegadoResult<Vec<ReadRecordDetail>> {
        self.ensure_detail_table()?;
        let mut stmt = self
            .conn
            .prepare(
                "SELECT deviceId, bookName, bookAuthor, date, readTime, lastRead \
                 FROM readRecordDetail \
                 ORDER BY date ASC, readTime DESC",
            )
            .map_err(|e| LegadoError::Database(format!("准备全量明细查询失败: {e}")))?;

        let rows = stmt
            .query_map([], |row| {
                Ok(ReadRecordDetail {
                    device_id: row.get(0)?,
                    book_name: row.get(1)?,
                    author: row.get(2)?,
                    date: row.get(3)?,
                    read_time: row.get(4)?,
                    last_read: row.get(5)?,
                })
            })
            .map_err(|e| LegadoError::Database(format!("查询全量明细失败: {e}")))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| LegadoError::Database(format!("读取明细失败: {e}")))?;
        Ok(rows)
    }

    /// 级联删除指定书籍的阅读记录与明细
    ///
    /// 同一事务删除 `readRecord` 与 `readRecordDetail`。
    /// 精确删除一位作者的明细，累计表减去该作者时长并保留其他作者；同步受影响日总数。
    pub fn delete_by_book_and_author(&self, book_name: &str, author: &str) -> LegadoResult<bool> {
        self.delete_records(book_name, Some(author))
    }
}

/// 日总秒数统一由真实明细总毫秒取整，频繁保存不丢失小于一秒的增量。
fn sync_daily_seconds(conn: &Connection, date: &str) -> LegadoResult<()> {
    let total: i64 = conn
        .query_row(
            "SELECT COALESCE(SUM(readTime), 0) FROM readRecordDetail WHERE date = ?1",
            [date],
            |row| row.get(0),
        )
        .map_err(|e| LegadoError::Database(format!("汇总每日明细失败: {e}")))?;
    if total == 0 {
        conn.execute("DELETE FROM readRecordDaily WHERE date = ?1", [date])
    } else {
        conn.execute(
            "INSERT INTO readRecordDaily (date, durationSeconds) VALUES (?1, ?2)
                      ON CONFLICT(date) DO UPDATE SET durationSeconds = excluded.durationSeconds",
            params![date, total / 1000],
        )
    }
    .map_err(|e| LegadoError::Database(format!("同步每日秒数失败: {e}")))?;
    Ok(())
}

/// 使用有效增量对应的真实时段拆分本地自然日；缺少起点时从终点回推。
pub fn split_reading_time_segments(
    delta_ms: i64,
    start_time_ms: Option<i64>,
    end_time_ms: Option<i64>,
) -> LegadoResult<Vec<(String, i64)>> {
    if delta_ms <= 0 {
        return Ok(Vec::new());
    }
    let end = end_time_ms.unwrap_or_else(|| Local::now().timestamp_millis());
    let inferred_start = end
        .checked_sub(delta_ms)
        .ok_or_else(|| LegadoError::Internal("阅读时段溢出".into()))?;
    let start = start_time_ms.unwrap_or(inferred_start);
    if start > inferred_start {
        return Err(LegadoError::Internal("阅读时段短于有效阅读增量".into()));
    }
    // 累计快照重复/重叠时仅计入末尾尚未持久化的增量，避免再次分配之前已计入的部分。
    let mut cursor = inferred_start;
    let mut result = Vec::new();
    while cursor < end {
        let current = Local
            .timestamp_millis_opt(cursor)
            .single()
            .ok_or_else(|| LegadoError::Internal("阅读时间戳超出范围".into()))?;
        let date = current.date_naive();
        let next = date
            .succ_opt()
            .and_then(|d| d.and_hms_opt(0, 0, 0))
            .ok_or_else(|| LegadoError::Internal("阅读日期超出范围".into()))?;
        let midnight = match Local.from_local_datetime(&next) {
            chrono::LocalResult::Single(dt) => dt.timestamp_millis(),
            chrono::LocalResult::Ambiguous(a, b) => a.timestamp_millis().min(b.timestamp_millis()),
            chrono::LocalResult::None => {
                // 少数时区午夜进入夏令时，取下一自然日第一个有效时刻。
                (1..=1440)
                    .find_map(|minute| {
                        Local
                            .from_local_datetime(&(next + chrono::Duration::minutes(minute)))
                            .earliest()
                    })
                    .ok_or_else(|| LegadoError::Internal("无法定位本地自然日边界".into()))?
                    .timestamp_millis()
            }
        };
        if midnight <= cursor {
            return Err(LegadoError::Internal("无效自然日边界".into()));
        }
        let segment_end = end.min(midnight);
        result.push((date.format("%Y-%m-%d").to_string(), segment_end - cursor));
        cursor = segment_end;
    }
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_upsert_and_find() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.upsert("book1", 1000).unwrap();

        let record = repo.find_by_book_name("book1").unwrap();
        assert!(record.is_some());
        let r = record.unwrap();
        assert_eq!(r.book_name, "book1");
        assert_eq!(r.read_time, 1000);
    }

    #[test]
    fn test_upsert_replaces_existing() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.upsert("book1", 1000).unwrap();
        repo.upsert("book1", 2000).unwrap();

        assert_eq!(repo.count().unwrap(), 1);
        let r = repo.find_by_book_name("book1").unwrap().unwrap();
        assert_eq!(r.read_time, 2000);
    }

    #[test]
    fn test_find_all_ordered() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.upsert("book_a", 100).unwrap();
        repo.upsert("book_b", 300).unwrap();
        repo.upsert("book_c", 200).unwrap();

        let all = repo.find_all().unwrap();
        assert_eq!(all.len(), 3);
        assert_eq!(all[0].book_name, "book_b");
        assert_eq!(all[1].book_name, "book_c");
        assert_eq!(all[2].book_name, "book_a");
    }

    #[test]
    fn test_find_by_book_name_not_found() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        let result = repo.find_by_book_name("nonexistent").unwrap();
        assert!(result.is_none());
    }

    #[test]
    fn test_delete_by_book_name() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.upsert("book1", 1000).unwrap();
        repo.upsert("book2", 2000).unwrap();

        assert!(repo.delete_by_book_name("book1").unwrap());
        assert!(!repo.delete_by_book_name("book1").unwrap());
        assert_eq!(repo.count().unwrap(), 1);
    }

    #[test]
    fn test_clear_all() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.upsert("book1", 1000).unwrap();
        repo.upsert("book2", 2000).unwrap();
        repo.upsert("book3", 3000).unwrap();

        let deleted = repo.clear_all().unwrap();
        assert_eq!(deleted, 3);
        assert_eq!(repo.count().unwrap(), 0);
    }

    #[test]
    fn test_count() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        assert_eq!(repo.count().unwrap(), 0);
        repo.upsert("book1", 1000).unwrap();
        assert_eq!(repo.count().unwrap(), 1);
        repo.upsert("book2", 2000).unwrap();
        assert_eq!(repo.count().unwrap(), 2);
    }

    // ─── 作者合并逻辑（对齐上游 ReadRecordAuthors）──────────────

    /// 单作者 + 空值：保持纯文本，不进入集合编码
    #[test]
    fn test_merge_authors_plain_and_blank() {
        assert_eq!(merge_read_record_authors("", "作者A"), "作者A");
        assert_eq!(merge_read_record_authors("作者A", ""), "作者A");
        assert_eq!(merge_read_record_authors("", ""), "");
        // 空白字符串被过滤
        assert_eq!(merge_read_record_authors("   ", "作者A"), "作者A");
    }

    /// 同作者去重：仍为纯文本单作者
    #[test]
    fn test_merge_authors_dedup_single() {
        assert_eq!(merge_read_record_authors("作者A", "作者A"), "作者A");
    }

    /// 多作者合并：去重 + 排序 + 前缀编码
    #[test]
    fn test_merge_authors_multi_sorted() {
        let merged = merge_read_record_authors("作者B", "作者A");
        assert!(merged.starts_with(AUTHORS_PREFIX));
        let arr: Vec<String> =
            serde_json::from_str(merged.strip_prefix(AUTHORS_PREFIX).unwrap()).unwrap();
        // 排序后的作者集合
        assert_eq!(arr, vec!["作者A".to_string(), "作者B".to_string()]);
    }

    /// 集合值与纯文本混合合并，重复作者去重
    #[test]
    fn test_merge_authors_set_with_plain() {
        let set_value = format!("{AUTHORS_PREFIX}[\"作者A\",\"作者B\"]");
        let merged = merge_read_record_authors(&set_value, "作者B");
        // 仍为两个作者，去重后保持集合编码
        let arr: Vec<String> =
            serde_json::from_str(merged.strip_prefix(AUTHORS_PREFIX).unwrap()).unwrap();
        assert_eq!(arr, vec!["作者A".to_string(), "作者B".to_string()]);
    }

    /// 非法 JSON 集合值：解析失败时按空处理，不残留垃圾数据
    #[test]
    fn test_merge_authors_invalid_json_falls_back() {
        let bad = format!("{AUTHORS_PREFIX}not-json");
        assert_eq!(merge_read_record_authors(&bad, "作者C"), "作者C");
    }

    // ─── 带作者合并的 insert ──────────────────────────────────

    /// 同书名多次写入不同作者：作者合并存储，readTime 以新值为准，仅一条记录
    #[test]
    fn test_insert_with_author_merges() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.insert_with_author("同名书", "作者A", 100).unwrap();
        repo.insert_with_author("同名书", "作者B", 200).unwrap();

        assert_eq!(repo.count().unwrap(), 1);
        let record = repo.get_record("同名书").unwrap().unwrap();
        assert_eq!(record.read_time, 200);
        assert!(record.author.starts_with(AUTHORS_PREFIX));
        let arr: Vec<String> =
            serde_json::from_str(record.author.strip_prefix(AUTHORS_PREFIX).unwrap()).unwrap();
        assert_eq!(arr, vec!["作者A".to_string(), "作者B".to_string()]);
    }

    /// 同作者重复写入：不产生集合编码
    #[test]
    fn test_insert_with_author_same_author() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.insert_with_author("书", "作者A", 100).unwrap();
        repo.insert_with_author("书", "作者A", 300).unwrap();

        let record = repo.get_record("书").unwrap().unwrap();
        assert_eq!(record.author, "作者A");
        assert_eq!(record.read_time, 300);
    }

    /// get_author：存在/不存在两种情况
    #[test]
    fn test_get_author() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.insert_with_author("书", "作者A", 100).unwrap();
        assert_eq!(repo.get_author("书").unwrap().as_deref(), Some("作者A"));
        assert_eq!(repo.get_author("不存在").unwrap(), None);
    }

    /// list_books：返回有阅读记录的书名列表，按书名排序
    #[test]
    fn test_list_books() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        assert!(repo.list_books().unwrap().is_empty());

        repo.upsert("b书", 10).unwrap();
        repo.upsert("a书", 20).unwrap();
        repo.upsert("c书", 30).unwrap();

        assert_eq!(
            repo.list_books().unwrap(),
            vec!["a书".to_string(), "b书".to_string(), "c书".to_string()]
        );
    }

    /// get_record：旧接口 upsert 写入的记录 author 为空字符串，get_record 可正常读取
    #[test]
    fn test_get_record_legacy_row() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.upsert("legacy", 123).unwrap();
        let record = repo.get_record("legacy").unwrap().unwrap();
        assert_eq!(record.author, "");
        assert_eq!(record.read_time, 123);
        assert!(repo.get_record("none").unwrap().is_none());
    }

    // ─── v101 新字段（deviceId / lastRead）────────────────────

    /// 全字段写入后 get_record / find_all 均能完整读回
    #[test]
    fn test_upsert_full_new_fields_roundtrip() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.upsert_full("device-1", "书A", "作者A", 500, 42)
            .unwrap();

        let record = repo.get_record("书A").unwrap().unwrap();
        assert_eq!(record.device_id, "device-1");
        assert_eq!(record.book_name, "书A");
        assert_eq!(record.author, "作者A");
        assert_eq!(record.read_time, 500);
        assert_eq!(record.last_read, 42);

        let all = repo.find_all().unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].device_id, "device-1");
        assert_eq!(all[0].last_read, 42);
    }

    /// 旧接口 upsert 写入的记录：新字段回落列默认值（''/0）
    #[test]
    fn test_legacy_upsert_new_field_defaults() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.upsert("旧接口", 10).unwrap();
        let record = repo.get_record("旧接口").unwrap().unwrap();
        assert_eq!(record.device_id, "");
        assert_eq!(record.last_read, 0);
    }

    /// update_last_read：存在时更新成功，不存在时返回 false
    #[test]
    fn test_update_last_read() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.upsert("书B", 100).unwrap();
        assert!(repo.update_last_read("书B", 77).unwrap());
        assert_eq!(repo.get_record("书B").unwrap().unwrap().last_read, 77);
        assert!(!repo.update_last_read("不存在", 1).unwrap());
    }

    /// [热力图每日时长契约] add_daily_seconds：同日多次累加，按日累计
    #[test]
    fn test_daily_add_accumulates_same_date() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.add_daily_seconds("2026-08-29", 600).unwrap();
        repo.add_daily_seconds("2026-08-29", 900).unwrap();
        let rows = repo.list_daily_year(2026).unwrap();
        assert_eq!(rows, vec![("2026-08-29".to_string(), 1500)]);
    }

    /// [热力图每日时长契约] list_daily_year：跨年隔离 + 日期升序
    #[test]
    fn test_daily_list_year_filter_and_order() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.add_daily_seconds("2026-01-02", 100).unwrap();
        repo.add_daily_seconds("2026-08-29", 300).unwrap();
        repo.add_daily_seconds("2025-12-31", 999).unwrap();

        let rows = repo.list_daily_year(2026).unwrap();
        assert_eq!(
            rows,
            vec![
                ("2026-01-02".to_string(), 100),
                ("2026-08-29".to_string(), 300),
            ]
        );
        let rows_2025 = repo.list_daily_year(2025).unwrap();
        assert_eq!(rows_2025, vec![("2025-12-31".to_string(), 999)]);
        assert!(repo.list_daily_year(2024).unwrap().is_empty());
    }

    // ─── [单书每日明细与原子写入契约测试] ──────────────────────

    /// 同名不同作者隔离：readRecordDetail 区分不同作者，readRecord 主表合并存储
    #[test]
    fn test_detail_author_isolation_and_merge() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        // 作者甲读 1000ms
        repo.record_reading_time("斗破", "作者甲", 1000, None, None)
            .unwrap();
        // 作者乙读 2000ms（注意总时长为 2000ms，相对之前增量 +1000ms）
        repo.record_reading_time("斗破", "作者乙", 2000, None, None)
            .unwrap();

        let details = repo.list_all_details().unwrap();
        assert_eq!(details.len(), 2);
        let detail_a = details.iter().find(|d| d.author == "作者甲").unwrap();
        let detail_b = details.iter().find(|d| d.author == "作者乙").unwrap();
        assert_eq!(detail_a.read_time, 1000);
        assert_eq!(detail_b.read_time, 1000);

        // 主表作者合并
        let rec = repo.get_record("斗破").unwrap().unwrap();
        assert_eq!(rec.read_time, 2000);
        assert!(rec.author.starts_with(AUTHORS_PREFIX));
    }

    /// 重复保存幂等：delta <= 0 时不重复增加明细和日聚合
    #[test]
    fn test_record_reading_time_idempotent() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.record_reading_time("平凡的世界", "路遥", 5000, None, None)
            .unwrap();
        // 重复提交相同 read_time
        let ret = repo
            .record_reading_time("平凡的世界", "路遥", 5000, None, None)
            .unwrap();
        assert_eq!(ret, 5000);
        // 提交更小的 read_time（如时钟回退）
        let ret2 = repo
            .record_reading_time("平凡的世界", "路遥", 3000, None, None)
            .unwrap();
        assert_eq!(ret2, 5000);

        let details = repo.list_all_details().unwrap();
        assert_eq!(details.len(), 1);
        assert_eq!(details[0].read_time, 5000);
    }

    /// 跨午夜拆分：23:50:00 到次日 00:10:00 拆为两天的明细与日聚合
    #[test]
    fn test_record_reading_time_cross_midnight_split() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        // 构造本地时区跨午夜时间戳
        let d1 = Local.with_ymd_and_hms(2026, 10, 14, 23, 50, 0).unwrap();
        let d2 = Local.with_ymd_and_hms(2026, 10, 15, 0, 10, 0).unwrap();
        let start_ms = d1.timestamp_millis();
        let end_ms = d2.timestamp_millis();
        // 总共 20 分钟 = 1200_000 ms，前一天 10 分钟 = 600_000 ms，次日 10 分钟 = 600_000 ms
        let delta_ms = end_ms - start_ms;

        repo.record_reading_time("夜读", "李白", delta_ms, Some(start_ms), Some(end_ms))
            .unwrap();

        let details = repo.list_details_year(2026).unwrap();
        assert_eq!(details.len(), 2);
        assert_eq!(details[0].date, "2026-10-14");
        assert_eq!(details[0].read_time, 600_000);
        assert_eq!(
            details[0].last_read,
            Local
                .with_ymd_and_hms(2026, 10, 15, 0, 0, 0)
                .unwrap()
                .timestamp_millis()
        );
        assert_eq!(details[1].date, "2026-10-15");
        assert_eq!(details[1].read_time, 600_000);

        // 检查日聚合表 readRecordDaily（整秒）
        let daily = repo.list_daily_year(2026).unwrap();
        assert_eq!(daily.len(), 2);
        assert_eq!(daily[0].0, "2026-10-14");
        assert_eq!(daily[0].1, 600);
        assert_eq!(daily[1].0, "2026-10-15");
        assert_eq!(daily[1].1, 600);
    }

    /// 级联删除：delete_by_book_and_author 删除主表及明细表
    #[test]
    fn test_delete_by_book_and_author_cascade() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.record_reading_time("三体", "刘慈欣", 3000, None, None)
            .unwrap();
        assert_eq!(repo.list_all_details().unwrap().len(), 1);
        assert!(repo.get_record("三体").unwrap().is_some());

        let deleted = repo.delete_by_book_and_author("三体", "刘慈欣").unwrap();
        assert!(deleted);
        assert_eq!(repo.list_all_details().unwrap().len(), 0);
        assert!(repo.get_record("三体").unwrap().is_none());
    }

    /// 清空操作：clear_all 同时清空 readRecord, readRecordDetail, readRecordDaily
    #[test]
    fn test_clear_all_cascade_all_three_tables() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());

        repo.record_reading_time("书1", "作者1", 3000, None, None)
            .unwrap();
        repo.record_reading_time("书2", "作者2", 4000, None, None)
            .unwrap();

        assert_eq!(repo.count().unwrap(), 2);
        assert_eq!(repo.list_all_details().unwrap().len(), 2);
        assert!(!repo.list_daily_year(2026).unwrap().is_empty());

        repo.clear_all().unwrap();

        assert_eq!(repo.count().unwrap(), 0);
        assert_eq!(repo.list_all_details().unwrap().len(), 0);
        assert!(repo.list_daily_year(2026).unwrap().is_empty());
    }

    #[test]
    fn test_detail_subsecond_updates_and_delete_daily() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        let end = Local
            .with_ymd_and_hms(2026, 5, 1, 12, 0, 0)
            .unwrap()
            .timestamp_millis();
        for value in [400, 800, 1200] {
            repo.record_reading_time("甲", "作者", value, None, Some(end + value))
                .unwrap();
        }
        repo.record_reading_time("乙", "作者", 1500, None, Some(end + 1500))
            .unwrap();
        assert_eq!(repo.list_daily_year(2026).unwrap()[0].1, 2);
        repo.delete_by_book_name("甲").unwrap();
        assert_eq!(repo.list_daily_year(2026).unwrap()[0].1, 1);
        assert_eq!(repo.list_all_details().unwrap().len(), 1);
    }

    #[test]
    fn test_detail_transaction_failure_rolls_back() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.ensure_daily_table().unwrap();
        db.connection().execute_batch("CREATE TRIGGER fail_daily BEFORE INSERT ON readRecordDaily BEGIN SELECT RAISE(ABORT, '拒绝日总写入'); END;").unwrap();
        assert!(
            repo.record_reading_time("回滚", "作者", 5000, None, None)
                .is_err()
        );
        assert!(repo.get_record("回滚").unwrap().is_none());
        assert!(repo.list_all_details().unwrap().is_empty());
        assert!(
            repo.list_daily_year(Local::now().year())
                .unwrap()
                .is_empty()
        );
    }

    #[test]
    fn test_detail_invalid_interval_rejected_without_write() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        assert!(
            repo.record_reading_time("无效", "作者", 2000, Some(1000), Some(2000))
                .is_err()
        );
        assert!(repo.get_record("无效").unwrap().is_none());
        assert!(
            repo.record_reading_time("无效", "作者", -1, None, None)
                .is_err()
        );
    }

    #[test]
    fn test_detail_exact_midnight_and_author_delete() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        let end = Local
            .with_ymd_and_hms(2026, 1, 1, 0, 0, 0)
            .unwrap()
            .timestamp_millis();
        repo.record_reading_time("同名", "甲", 1000, None, Some(end))
            .unwrap();
        repo.record_reading_time("同名", "乙", 2000, None, Some(end + 1000))
            .unwrap();
        assert_eq!(repo.list_details_year(2025).unwrap()[0].read_time, 1000);
        assert_eq!(repo.list_details_year(2026).unwrap()[0].read_time, 1000);
        repo.delete_by_book_and_author("同名", "甲").unwrap();
        assert_eq!(repo.get_record("同名").unwrap().unwrap().read_time, 1000);
        assert_eq!(repo.list_all_details().unwrap()[0].author, "乙");
        assert!(repo.list_daily_year(2025).unwrap().is_empty());
    }

    #[test]
    fn test_detail_concurrent_duplicate_snapshots_are_idempotent() {
        use std::sync::{Arc, Barrier};
        let directory = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("target");
        std::fs::create_dir_all(&directory).unwrap();
        let path = directory.join(format!(
            "read-record-concurrent-{}.sqlite",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let db = crate::init_database(path.to_str().unwrap()).unwrap();
        let repo = ReadRecordRepository::new(db.connection());
        repo.ensure_detail_table().unwrap();
        repo.ensure_daily_table().unwrap();
        let barrier = Arc::new(Barrier::new(2));
        let end = Local
            .with_ymd_and_hms(2026, 1, 1, 12, 0, 0)
            .unwrap()
            .timestamp_millis();
        let handles: Vec<_> = (0..2)
            .map(|_| {
                let pool = db.pool().clone();
                let barrier = barrier.clone();
                std::thread::spawn(move || {
                    let conn = pool.get().unwrap();
                    barrier.wait();
                    ReadRecordRepository::new(&conn)
                        .record_reading_time("并发", "作者", 1000, None, Some(end))
                        .unwrap()
                })
            })
            .collect();
        for handle in handles {
            assert_eq!(handle.join().unwrap(), 1000);
        }
        assert_eq!(repo.get_record("并发").unwrap().unwrap().read_time, 1000);
        assert_eq!(repo.list_all_details().unwrap()[0].read_time, 1000);
        assert_eq!(repo.list_daily_year(2026).unwrap()[0].1, 1);
        drop(db);
        let _ = std::fs::remove_file(&path);
        let _ = std::fs::remove_file(format!("{}-wal", path.display()));
        let _ = std::fs::remove_file(format!("{}-shm", path.display()));
    }
}
