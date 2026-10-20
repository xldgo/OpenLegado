//! 真实阅读会话与对应每日/累计删除；不在界面生成历史时段。
use super::read_record_repository::{ReadRecordRepository, split_reading_time_segments};
use chrono::{Local, NaiveDate, TimeZone};
use legado_core::{LegadoError, LegadoResult};
use rusqlite::params;
use serde::{Deserialize, Serialize};

pub const CREATE_READ_SESSIONS: &str = "
CREATE TABLE IF NOT EXISTS readRecordSession (
 id INTEGER PRIMARY KEY AUTOINCREMENT, deviceId TEXT NOT NULL DEFAULT '',
 bookName TEXT NOT NULL, bookAuthor TEXT NOT NULL DEFAULT '',bookUrl TEXT NOT NULL DEFAULT '',
 startTime INTEGER NOT NULL,endTime INTEGER NOT NULL,chapterIndex INTEGER NOT NULL DEFAULT 0,
 CHECK(endTime>startTime),
 UNIQUE(deviceId,bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex)
);
CREATE INDEX IF NOT EXISTS idx_read_sessions_start ON readRecordSession(startTime);
CREATE INDEX IF NOT EXISTS idx_read_sessions_book ON readRecordSession(bookName,bookAuthor);
";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReadRecordSession {
    pub id: i64,
    pub device_id: String,
    pub book_name: String,
    #[serde(rename = "author")]
    pub book_author: String,
    pub book_url: String,
    pub start_time: i64,
    pub end_time: i64,
    pub chapter_index: i32,
}

fn db_error(e: rusqlite::Error) -> LegadoError {
    LegadoError::Database(format!("阅读会话操作失败: {e}"))
}

fn midnight(date: NaiveDate) -> LegadoResult<i64> {
    let base = date
        .and_hms_opt(0, 0, 0)
        .ok_or_else(|| LegadoError::Internal("无效阅读日期".into()))?;
    (0..=1440)
        .find_map(|minute| {
            Local
                .from_local_datetime(&(base + chrono::Duration::minutes(minute)))
                .earliest()
        })
        .map(|d| d.timestamp_millis())
        .ok_or_else(|| LegadoError::Internal("无法定位阅读日期边界".into()))
}

impl ReadRecordRepository<'_> {
    pub fn ensure_session_table(&self) -> LegadoResult<()> {
        self.conn
            .execute_batch(CREATE_READ_SESSIONS)
            .map_err(db_error)
    }
    pub fn list_read_sessions(&self) -> LegadoResult<Vec<ReadRecordSession>> {
        self.ensure_session_table()?;
        let mut statement=self.conn.prepare("SELECT id,deviceId,bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex FROM readRecordSession ORDER BY startTime,id").map_err(db_error)?;
        statement
            .query_map([], |r| {
                Ok(ReadRecordSession {
                    id: r.get(0)?,
                    device_id: r.get(1)?,
                    book_name: r.get(2)?,
                    book_author: r.get(3)?,
                    book_url: r.get(4)?,
                    start_time: r.get(5)?,
                    end_time: r.get(6)?,
                    chapter_index: r.get(7)?,
                })
            })
            .map_err(db_error)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(db_error)
    }
    pub fn delete_read_sessions(&self, ids: &[i64]) -> LegadoResult<bool> {
        self.ensure_session_table()?;
        self.ensure_detail_table()?;
        self.ensure_daily_table()?;
        crate::connection::in_transaction(self.conn, "删除阅读会话", |conn| {
            let mut changed = false;
            let ids: std::collections::BTreeSet<_> = ids.iter().copied().collect();
            let selected = self
                .list_read_sessions()?
                .into_iter()
                .filter(|s| ids.contains(&s.id))
                .collect::<Vec<_>>();
            for session in selected {
                let id = session.id;
                conn.execute("DELETE FROM readRecordSession WHERE id=?1", [id])
                    .map_err(db_error)?;
                let duration = session.end_time - session.start_time;
                for (date, time) in split_reading_time_segments(
                    duration,
                    Some(session.start_time),
                    Some(session.end_time),
                )? {
                    self.deduct_detail(
                        &session.book_name,
                        &session.book_author,
                        &date,
                        time,
                        &session.device_id,
                    )?;
                }
                self.deduct_total(&session.book_name, duration, &session.device_id)?;
                changed = true;
            }
            Ok(changed)
        })
    }
    pub fn delete_read_detail(&self, name: &str, author: &str, date: &str) -> LegadoResult<bool> {
        self.ensure_session_table()?;
        self.ensure_detail_table()?;
        self.ensure_daily_table()?;
        let parsed = NaiveDate::parse_from_str(date, "%Y-%m-%d")
            .map_err(|_| LegadoError::Internal("无效阅读日期".into()))?;
        if parsed.format("%Y-%m-%d").to_string() != date {
            return Err(LegadoError::Internal("日期格式必须为YYYY-MM-DD".into()));
        }
        let start = midnight(parsed)?;
        let end = midnight(
            parsed
                .succ_opt()
                .ok_or_else(|| LegadoError::Internal("日期超出范围".into()))?,
        )?;
        crate::connection::in_transaction(self.conn, "删除每日单书记录", |conn| {
            let mut statement=conn.prepare("SELECT deviceId,readTime FROM readRecordDetail WHERE bookName=?1 AND bookAuthor=?2 AND date=?3").map_err(db_error)?;
            let amounts: Vec<(String, i64)> = statement
                .query_map(params![name, author, date], |r| Ok((r.get(0)?, r.get(1)?)))
                .map_err(db_error)?
                .collect::<Result<Vec<_>, _>>()
                .map_err(db_error)?;
            if amounts.is_empty() {
                return Ok(false);
            }
            drop(statement);
            for session in self.list_read_sessions()?.into_iter().filter(|s| {
                s.book_name == name
                    && s.book_author == author
                    && s.start_time < end
                    && s.end_time > start
            }) {
                conn.execute("DELETE FROM readRecordSession WHERE id=?1", [session.id])
                    .map_err(db_error)?;
                for (left, right) in [
                    (session.start_time, session.end_time.min(start)),
                    (session.start_time.max(end), session.end_time),
                ] {
                    if right > left {
                        conn.execute("INSERT INTO readRecordSession(deviceId,bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex) VALUES(?1,?2,?3,?4,?5,?6,?7)",params![session.device_id,name,author,session.book_url,left,right,session.chapter_index]).map_err(db_error)?;
                    }
                }
            }
            for (device, duration) in amounts {
                self.deduct_detail(name, author, date, duration, &device)?;
                self.deduct_total(name, duration, &device)?;
            }
            Ok(true)
        })
    }
    fn deduct_detail(
        &self,
        name: &str,
        author: &str,
        date: &str,
        duration: i64,
        device: &str,
    ) -> LegadoResult<()> {
        self.conn.execute("UPDATE readRecordDetail SET readTime=MAX(0,readTime-?4) WHERE bookName=?1 AND bookAuthor=?2 AND date=?3 AND deviceId=?5",params![name,author,date,duration,device]).map_err(db_error)?;
        self.conn.execute("DELETE FROM readRecordDetail WHERE bookName=?1 AND bookAuthor=?2 AND date=?3 AND readTime<=0 AND deviceId=?4",params![name,author,date,device]).map_err(db_error)?;
        let parsed = NaiveDate::parse_from_str(date, "%Y-%m-%d")
            .map_err(|_| LegadoError::Internal("无效阅读日期".into()))?;
        let left = midnight(parsed)?;
        let right = midnight(
            parsed
                .succ_opt()
                .ok_or_else(|| LegadoError::Internal("日期超出范围".into()))?,
        )?;
        let last:Option<i64>=self.conn.query_row("SELECT MAX(MIN(endTime,?4)) FROM readRecordSession WHERE bookName=?1 AND bookAuthor=?2 AND endTime>?3 AND startTime<?4 AND deviceId=?5",params![name,author,left,right,device],|r|r.get(0)).map_err(db_error)?;
        if let Some(last) = last {
            self.conn.execute("UPDATE readRecordDetail SET lastRead=?4 WHERE bookName=?1 AND bookAuthor=?2 AND date=?3 AND deviceId=?5",params![name,author,date,last,device]).map_err(db_error)?;
        }
        let millis: i64 = self
            .conn
            .query_row(
                "SELECT COALESCE(SUM(readTime),0) FROM readRecordDetail WHERE date=?1",
                [date],
                |r| r.get(0),
            )
            .map_err(db_error)?;
        if millis == 0 {
            self.conn
                .execute("DELETE FROM readRecordDaily WHERE date=?1", [date])
                .map_err(db_error)?;
        } else {
            self.conn.execute("INSERT INTO readRecordDaily(date,durationSeconds) VALUES(?1,?2) ON CONFLICT(date) DO UPDATE SET durationSeconds=excluded.durationSeconds",params![date,millis/1000]).map_err(db_error)?;
        }
        Ok(())
    }
    fn deduct_total(&self, name: &str, duration: i64, device: &str) -> LegadoResult<()> {
        self.conn.execute("UPDATE readRecord SET readTime=MAX(0,readTime-?2),lastRead=COALESCE((SELECT MAX(lastRead) FROM readRecordDetail WHERE bookName=?1 AND deviceId=?3),0) WHERE bookName=?1 AND deviceId=?3",params![name,duration,device]).map_err(db_error)?;
        self.conn
            .execute(
                "DELETE FROM readRecord WHERE bookName=?1 AND readTime<=0 AND deviceId=?2",
                params![name, device],
            )
            .map_err(db_error)?;
        let mut statement=self.conn.prepare("SELECT DISTINCT bookAuthor FROM readRecordDetail WHERE bookName=?1 AND deviceId=?2").map_err(db_error)?;
        let authors: Vec<String> = statement
            .query_map(params![name, device], |r| r.get(0))
            .map_err(db_error)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(db_error)?;
        if !authors.is_empty() {
            let author = authors.iter().fold(String::new(), |value, a| {
                super::read_record_repository::merge_read_record_authors(&value, a)
            });
            self.conn
                .execute(
                    "UPDATE readRecord SET author=?3 WHERE bookName=?1 AND deviceId=?2",
                    params![name, device, author],
                )
                .map_err(db_error)?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn connection() -> rusqlite::Connection {
        let conn = rusqlite::Connection::open_in_memory().unwrap();
        crate::schema::init_schema(&conn).unwrap();
        conn
    }
    fn time(day: u32, hour: u32, minute: u32) -> i64 {
        Local
            .with_ymd_and_hms(2026, 10, day, hour, minute, 0)
            .single()
            .unwrap()
            .timestamp_millis()
    }
    #[test]
    fn read_sessions_delta_idempotent_and_context() {
        let conn = connection();
        let repo = ReadRecordRepository::new(&conn);
        let end = time(13, 12, 0);
        repo.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "甲",
                author: "作者",
                read_time_ms: 60000,
                start_time_ms: Some(end - 60000),
                end_time_ms: Some(end),
                book_url: "book://1",
                chapter_index: 3,
            },
        )
        .unwrap();
        repo.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "甲",
                author: "作者",
                read_time_ms: 60000,
                start_time_ms: Some(end - 60000),
                end_time_ms: Some(end),
                book_url: "book://1",
                chapter_index: 3,
            },
        )
        .unwrap();
        let sessions = repo.list_read_sessions().unwrap();
        assert_eq!(sessions.len(), 1);
        assert_eq!(sessions[0].book_url, "book://1");
        assert_eq!(sessions[0].chapter_index, 3);
        assert_eq!(sessions[0].end_time - sessions[0].start_time, 60000);
        repo.clear_all().unwrap();
        assert!(repo.list_read_sessions().unwrap().is_empty());
    }
    #[test]
    fn read_sessions_delete_day_crops_cross_midnight() {
        let conn = connection();
        let repo = ReadRecordRepository::new(&conn);
        let start = time(13, 23, 59);
        let end = time(14, 0, 1);
        repo.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "甲",
                author: "作者",
                read_time_ms: end - start,
                start_time_ms: Some(start),
                end_time_ms: Some(end),
                book_url: "b",
                chapter_index: 1,
            },
        )
        .unwrap();
        assert!(repo.delete_read_detail("甲", "作者", "2026-10-13").unwrap());
        let sessions = repo.list_read_sessions().unwrap();
        assert_eq!(sessions.len(), 1);
        assert_eq!(sessions[0].start_time, time(14, 0, 0));
        assert_eq!(sessions[0].end_time, end);
        assert_eq!(repo.find_all().unwrap()[0].read_time, 60000);
        let daily = repo.list_all_details().unwrap();
        assert_eq!(daily.len(), 1);
        assert_eq!(daily[0].date, "2026-10-14");
        assert!(
            repo.delete_read_sessions(&[sessions[0].id, sessions[0].id])
                .unwrap()
        );
        assert!(repo.find_all().unwrap().is_empty());
        assert!(repo.list_all_details().unwrap().is_empty());
    }
    #[test]
    fn read_sessions_delete_author_preserves_other_and_daily() {
        let conn = connection();
        let repo = ReadRecordRepository::new(&conn);
        let end = time(13, 12, 0);
        repo.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "同名",
                author: "甲",
                read_time_ms: 1000,
                start_time_ms: Some(end - 1000),
                end_time_ms: Some(end),
                book_url: "a",
                chapter_index: 1,
            },
        )
        .unwrap();
        repo.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "同名",
                author: "乙",
                read_time_ms: 3000,
                start_time_ms: Some(end),
                end_time_ms: Some(end + 2000),
                book_url: "b",
                chapter_index: 2,
            },
        )
        .unwrap();
        repo.delete_by_book_and_author("同名", "甲").unwrap();
        assert_eq!(repo.list_read_sessions().unwrap().len(), 1);
        assert_eq!(repo.list_read_sessions().unwrap()[0].book_author, "乙");
        assert_eq!(repo.find_all().unwrap()[0].read_time, 2000);
    }
    #[test]
    fn read_sessions_failure_rolls_back_all_tables() {
        let conn = connection();
        let repo = ReadRecordRepository::new(&conn);
        repo.ensure_detail_table().unwrap();
        repo.ensure_session_table().unwrap();
        conn.execute_batch("CREATE TRIGGER fail_read_detail BEFORE INSERT ON readRecordDetail BEGIN SELECT RAISE(ABORT,'故障注入'); END;").unwrap();
        let end = time(13, 12, 0);
        assert!(
            repo.record_reading_time_with_session(
                crate::repository::read_record_repository::ReadingSessionInput {
                    book_name: "甲",
                    author: "作者",
                    read_time_ms: 1000,
                    start_time_ms: Some(end - 1000),
                    end_time_ms: Some(end),
                    book_url: "a",
                    chapter_index: 1
                }
            )
            .is_err()
        );
        assert!(repo.find_all().unwrap().is_empty());
        assert!(repo.list_read_sessions().unwrap().is_empty());
    }
    #[test]
    fn read_sessions_delete_only_deducts_own_device() {
        let conn = connection();
        let repo = ReadRecordRepository::new(&conn);
        let end = time(13, 12, 0);
        repo.record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "甲",
                author: "作者",
                read_time_ms: 1000,
                start_time_ms: Some(end - 1000),
                end_time_ms: Some(end),
                book_url: "a",
                chapter_index: 1,
            },
        )
        .unwrap();
        let first = repo.list_read_sessions().unwrap()[0].id;
        conn.execute("INSERT INTO readRecord(deviceId,bookName,author,readTime,lastRead) VALUES('其他设备','甲','作者',2000,?1)",[end]).unwrap();
        conn.execute("INSERT INTO readRecordDetail(deviceId,bookName,bookAuthor,date,readTime,lastRead) VALUES('其他设备','甲','作者','2026-10-13',2000,?1)",[end]).unwrap();
        conn.execute("INSERT INTO readRecordSession(deviceId,bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex) VALUES('其他设备','甲','作者','b',?1,?2,1)",params![end-2000,end]).unwrap();
        repo.delete_read_sessions(&[first]).unwrap();
        assert_eq!(
            repo.list_all_details()
                .unwrap()
                .iter()
                .map(|d| d.read_time)
                .sum::<i64>(),
            2000
        );
        assert_eq!(
            repo.find_all()
                .unwrap()
                .iter()
                .map(|d| d.read_time)
                .sum::<i64>(),
            2000
        );
        assert_eq!(repo.list_read_sessions().unwrap()[0].device_id, "其他设备");
        repo.delete_read_detail("甲", "作者", "2026-10-13").unwrap();
        assert!(repo.find_all().unwrap().is_empty());
        assert!(repo.list_read_sessions().unwrap().is_empty());
    }
}
