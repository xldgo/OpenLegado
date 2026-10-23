use super::*;
use chrono::{FixedOffset, Utc};

fn session(id: i64, start: i64, end: i64) -> ReadRecordSession {
    ReadRecordSession {
        id,
        device_id: String::new(),
        book_name: "Novel".into(),
        book_author: "作者".into(),
        book_url: format!("book://{id}"),
        start_time: start,
        end_time: end,
        chapter_index: id as i32,
    }
}

#[test]
fn timeline_merges_twenty_minute_boundary_and_preserves_first_context() {
    let base = Utc
        .with_ymd_and_hms(2026, 10, 13, 12, 0, 0)
        .unwrap()
        .timestamp_millis();
    let rows = merge_sessions(
        vec![
            session(4, base + 42 * 60_000 + 1, base + 43 * 60_000),
            session(2, base + 21 * 60_000, base + 22 * 60_000),
            session(1, base, base + 60_000),
            // 重叠会话不能缩短已有终点，首项URL和章节不被后一项覆盖。
            session(3, base + 21 * 60_000 + 1, base + 21 * 60_000 + 2),
        ],
        " novel ",
        &Utc,
    )
    .unwrap();
    assert_eq!(rows.len(), 2);
    assert_eq!(rows[0].session_ids, [4]);
    let merged = &rows[1];
    assert_eq!(merged.session_ids, [1, 2, 3]);
    assert_eq!(merged.start_time, base);
    assert_eq!(merged.end_time, base + 22 * 60_000);
    assert_eq!(merged.book_url, "book://1");
    assert_eq!(merged.chapter_index, 1);
}

#[test]
fn timeline_uses_local_start_date_and_filters_before_merging() {
    let timezone = FixedOffset::east_opt(2 * 3600).unwrap();
    let midnight = timezone
        .with_ymd_and_hms(2026, 10, 14, 0, 0, 0)
        .unwrap()
        .timestamp_millis();
    let mut other_author = session(3, midnight + 1000, midnight + 2000);
    other_author.book_author = "不同".into();
    let mut other_book = session(4, midnight + 2000, midnight + 3000);
    other_book.book_name = "Other".into();
    other_book.book_author = "不同".into();
    let data = vec![
        session(1, midnight - 1000, midnight),
        session(2, midnight, midnight + 1000),
        other_author,
        other_book,
        session(5, midnight + 3000, midnight + 4000),
        session(6, midnight + 4000, midnight + 4000),
    ];
    let rows = merge_sessions(data.clone(), "", &timezone).unwrap();
    assert_eq!(rows.len(), 5);
    assert_eq!(rows.last().unwrap().date, "2026-10-13");
    assert_eq!(rows[0].date, "2026-10-14");
    // 忽略不匹配作者的中间项后，与现有界面一致，剩余相邻同书项可归并。
    let filtered = merge_sessions(data, "作者", &timezone).unwrap();
    assert_eq!(filtered.len(), 2);
    assert_eq!(filtered[0].session_ids, [2, 5]);
    assert_eq!(filtered.last().unwrap().session_ids, [1]);
}

#[test]
fn timeline_query_is_read_only_and_duplicate_devices_keep_every_delete_id() {
    let conn = rusqlite::Connection::open_in_memory().unwrap();
    crate::schema::init_schema(&conn).unwrap();
    let repository = ReadRecordRepository::new(&conn);
    let end = Local
        .with_ymd_and_hms(2026, 10, 13, 12, 0, 0)
        .unwrap()
        .timestamp_millis();
    repository
        .record_reading_time_with_session(
            crate::repository::read_record_repository::ReadingSessionInput {
                book_name: "Novel",
                author: "作者",
                read_time_ms: 1000,
                start_time_ms: Some(end - 1000),
                end_time_ms: Some(end),
                book_url: "book://1",
                chapter_index: 2,
            },
        )
        .unwrap();
    conn.execute("INSERT INTO readRecordSession(deviceId,bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex) SELECT 'remote',bookName,bookAuthor,bookUrl,startTime,endTime,chapterIndex FROM readRecordSession", []).unwrap();
    let original = repository.list_read_sessions().unwrap();
    let original_total = repository.find_all().unwrap()[0].read_time;
    let original_details = repository.list_all_details().unwrap();
    let rows = repository.list_read_timeline("作者").unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(
        rows[0].session_ids,
        original.iter().map(|s| s.id).collect::<Vec<_>>()
    );
    assert_eq!(repository.list_read_sessions().unwrap(), original);
    assert_eq!(repository.find_all().unwrap()[0].read_time, original_total);
    assert_eq!(repository.list_all_details().unwrap(), original_details);
    repository
        .delete_read_sessions(&rows[0].session_ids)
        .unwrap();
    assert!(repository.list_read_sessions().unwrap().is_empty());
    assert!(repository.list_all_details().unwrap().is_empty());
    assert!(repository.find_all().unwrap().is_empty());
}
