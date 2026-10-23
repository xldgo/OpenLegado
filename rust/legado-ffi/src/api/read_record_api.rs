//! 阅读记录 API
//!
//! 提供阅读记录的增删查操作，通过 ReadRecordRepository 访问数据库。

use legado_core::LegadoResult;
use legado_db::ReadRecordRepository;

use crate::db_state::with_database;

pub use crate::transfer_dto::{ReadRecordDetailDto, ReadRecordDto};

/// 获取所有阅读记录（按 readTime 降序）
pub fn get_read_records() -> LegadoResult<Vec<ReadRecordDto>> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        let records = repo.find_all()?;
        Ok(records
            .into_iter()
            .map(|r| ReadRecordDto {
                book_name: r.book_name,
                author: r.author,
                read_time: r.read_time,
                last_read: r.last_read,
                device_id: r.device_id,
            })
            .collect())
    })
}

/// 读取指定书籍的当前阅读时长；无记录时返回 0
pub fn get_read_time(book_name: &str) -> LegadoResult<i64> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        Ok(repo
            .get_record(book_name)?
            .map(|r| r.read_time)
            .unwrap_or(0))
    })
}

/// 按年查询每日单书阅读明细列表（毫秒）
pub fn get_read_record_details(year: i32) -> LegadoResult<Vec<ReadRecordDetailDto>> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        let details = repo.list_details_year(year)?;
        Ok(details.into_iter().map(ReadRecordDetailDto::from).collect())
    })
}

/// 查询全量历史每日单书阅读明细列表（毫秒）
pub fn get_all_read_record_details() -> LegadoResult<Vec<ReadRecordDetailDto>> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        let details = repo.list_all_details()?;
        Ok(details.into_iter().map(ReadRecordDetailDto::from).collect())
    })
}

/// 既有累计写入入口；新阅读器另外透传作者及有效阅读时段。
///
/// 同一事务写入累计记录、每日单书毫秒与日总秒数。日总数由当日所有明细毫秒
/// 统一取整，不随保存频率丢失小于一秒的增量；重复或更小的累计快照不入账。
pub fn upsert_read_record(book_name: &str, read_time: i64) -> LegadoResult<i64> {
    record_reading_time(book_name, "", read_time, None, None)
}

/// 记录阅读时间（支持作者与跨午夜时间段原子写入明细和日聚合）
pub fn record_reading_time(
    book_name: &str,
    author: &str,
    read_time_ms: i64,
    start_time_ms: Option<i64>,
    end_time_ms: Option<i64>,
) -> LegadoResult<i64> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        repo.record_reading_time(book_name, author, read_time_ms, start_time_ms, end_time_ms)
    })
}

/// 写入真实阅读会话及累计增量，副本URL与章节序号仅作为会话上下文。
pub fn record_reading_time_with_session(
    book_name: &str,
    author: &str,
    read_time_ms: i64,
    start_time_ms: Option<i64>,
    end_time_ms: Option<i64>,
    book_url: &str,
    chapter_index: i32,
) -> LegadoResult<i64> {
    with_database(|db| {
        ReadRecordRepository::new(db.connection()).record_reading_time_with_session(
            legado_db::repository::read_record_repository::ReadingSessionInput {
                book_name,
                author,
                read_time_ms,
                start_time_ms,
                end_time_ms,
                book_url,
                chapter_index,
            },
        )
    })
}

pub fn get_read_record_sessions() -> LegadoResult<Vec<legado_db::ReadRecordSession>> {
    with_database(|db| ReadRecordRepository::new(db.connection()).list_read_sessions())
}

pub fn get_read_record_timeline(
    query: &str,
) -> LegadoResult<Vec<crate::transfer_dto::ReadRecordTimelineDto>> {
    with_database(|db| {
        Ok(ReadRecordRepository::new(db.connection())
            .list_read_timeline(query)?
            .into_iter()
            .map(Into::into)
            .collect())
    })
}

pub fn delete_read_record_detail(name: &str, author: &str, date: &str) -> LegadoResult<bool> {
    with_database(|db| {
        ReadRecordRepository::new(db.connection()).delete_read_detail(name, author, date)
    })
}

pub fn delete_read_record_sessions(ids: &[i64]) -> LegadoResult<bool> {
    with_database(|db| ReadRecordRepository::new(db.connection()).delete_read_sessions(ids))
}

/// 删除指定书籍的阅读记录
pub fn delete_read_record(book_name: &str) -> LegadoResult<bool> {
    with_database(|db| ReadRecordRepository::new(db.connection()).delete_by_book_name(book_name))
}

/// 按书名和作者级联删除阅读记录与明细
pub fn delete_read_record_by_book_and_author(book_name: &str, author: &str) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        repo.delete_by_book_and_author(book_name, author)
    })
}

/// 清空所有阅读记录
pub fn clear_read_records() -> LegadoResult<bool> {
    with_database(|db| {
        let repo = ReadRecordRepository::new(db.connection());
        repo.clear_all()?;
        Ok(true)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_read_record_crud() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 添加记录
        let rt = upsert_read_record("测试书籍", 5000).unwrap();
        assert_eq!(rt, 5000);

        // 获取列表
        let records = get_read_records().unwrap();
        assert!(records.iter().any(|r| r.book_name == "测试书籍"));

        // 更新记录
        upsert_read_record("测试书籍", 8000).unwrap();
        let records = get_read_records().unwrap();
        let rec = records.iter().find(|r| r.book_name == "测试书籍").unwrap();
        assert_eq!(rec.read_time, 8000);

        // 删除记录
        assert!(delete_read_record("测试书籍").unwrap());
        let records = get_read_records().unwrap();
        assert!(!records.iter().any(|r| r.book_name == "测试书籍"));
    }

    /// [热力图每日时长契约] upsert 增量同步 readRecordDaily（热力图"每日时长"契约）：
    /// 无记录时增量 = 全量；已有时增量 = 差值；get_read_time 如实反映当前值。
    /// 单位口径（2026-09-11 修复）：readTime 为毫秒、readRecordDaily 契约为秒，
    /// 入账值按整秒差值折算（5000ms → 5s，3000ms 增量 → +3s）。
    #[test]
    fn test_upsert_syncs_daily_duration() {
        let _db_guard = crate::db_state::ensure_test_db();
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let year: i32 = today[..4].parse().unwrap();

        let before = daily_seconds_today(&today, year);

        // 无记录 → 增量为全量 5000ms = 5s
        upsert_read_record("每日聚合书", 5000).unwrap();
        assert_eq!(get_read_time("每日聚合书").unwrap(), 5000);
        // 已有 → 增量为差值 3000ms = 3s
        upsert_read_record("每日聚合书", 8000).unwrap();
        assert_eq!(get_read_time("每日聚合书").unwrap(), 8000);

        // 共享测试库中其他用例也会向当日累加，只断言本书两次增量（5s+3s=8s）均已入账
        let after = daily_seconds_today(&today, year);
        assert_eq!(
            after - before,
            8,
            "当日聚合应恰增 8 秒（5000ms+3000ms），实际增量: {}",
            after - before
        );
        // 查询不存在的书返回 0
        assert_eq!(get_read_time("无此书").unwrap(), 0);
    }

    /// 读取当日聚合秒数（无当日行返回 0）
    fn daily_seconds_today(today: &str, year: i32) -> i64 {
        with_database(|db| {
            let repo = ReadRecordRepository::new(db.connection());
            repo.list_daily_year(year)
        })
        .unwrap()
        .iter()
        .find(|(d, _)| d == today)
        .map(|(_, s)| *s)
        .unwrap_or(0)
    }

    /// 验证 get_read_record_details 与 get_all_read_record_details
    #[test]
    fn test_read_record_details_ffi_api() {
        let _db_guard = crate::db_state::ensure_test_db();
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let year: i32 = today[..4].parse().unwrap();

        // 记录一本测试书
        record_reading_time("FFI测试书", "作者测试", 6000, None, None).unwrap();

        let details_year = get_read_record_details(year).unwrap();
        assert!(
            details_year
                .iter()
                .any(|d| d.book_name == "FFI测试书" && d.author == "作者测试")
        );

        let all_details = get_all_read_record_details().unwrap();
        assert!(
            all_details
                .iter()
                .any(|d| d.book_name == "FFI测试书" && d.author == "作者测试")
        );

        // 带作者级联删除
        let deleted = delete_read_record_by_book_and_author("FFI测试书", "作者测试").unwrap();
        assert!(deleted);

        let all_details_after = get_all_read_record_details().unwrap();
        assert!(
            !all_details_after
                .iter()
                .any(|d| d.book_name == "FFI测试书" && d.author == "作者测试")
        );
    }
}
