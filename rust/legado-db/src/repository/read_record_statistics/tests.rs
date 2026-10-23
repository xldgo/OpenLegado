use super::*;
fn detail(name: &str, author: &str, date: &str, ms: i64, last: i64) -> ReadRecordDetail {
    ReadRecordDetail {
        book_name: name.into(),
        author: author.into(),
        date: date.into(),
        read_time: ms,
        last_read: last,
        ..Default::default()
    }
}
#[test]
fn periods_use_daily_facts_and_all_uses_totals_without_inventing_history() {
    let details = vec![
        detail("甲", "甲作者", "2026-04-20", 3_600_000, 1),
        detail("丙", "丙作者", "2026-05-18", 1_800_000, 2),
        detail("乙", "乙作者", "2026-05-19", 3_600_000, 3),
        detail("乙", "乙作者", "2026-05-20", 5_400_000, 4),
    ];
    let records = vec![
        ("甲", "甲作者", 3_600_000),
        ("乙", "乙作者", 9_000_000),
        ("丙", "丙作者", 1_800_000),
    ]
    .into_iter()
    .map(|(n, a, t)| ReadRecord {
        book_name: n.into(),
        author: a.into(),
        read_time: t,
        ..Default::default()
    })
    .collect::<Vec<_>>();
    let shelf = vec![
        Book {
            name: "甲".into(),
            author: "甲作者".into(),
            total_chapter_num: 10,
            dur_chapter_index: 9,
            dur_chapter_pos: 1,
            ..Default::default()
        },
        Book {
            name: "乙".into(),
            author: "乙作者".into(),
            total_chapter_num: 10,
            dur_chapter_index: 9,
            dur_chapter_pos: 0,
            ..Default::default()
        },
    ];
    let reference = require_date("2026-05-20").unwrap();
    let week = compute(
        ReadRecordPeriod::Week,
        reference,
        details.clone(),
        records.clone(),
        shelf.clone(),
    );
    assert_eq!(
        (
            week.total_time_ms,
            week.reading_days,
            week.total_books,
            week.reading_books,
            week.finished_books
        ),
        (10_800_000, 3, 2, 2, 0)
    );
    assert_eq!(
        week.top_books
            .iter()
            .map(|b| b.book_name.as_str())
            .collect::<Vec<_>>(),
        ["乙", "丙"]
    );
    assert_eq!(week.chart.len(), 7);
    let month = compute(
        ReadRecordPeriod::Month,
        reference,
        details.clone(),
        records.clone(),
        shelf.clone(),
    );
    assert_eq!(month.chart.len(), 31);
    assert_eq!(month.total_time_ms, 10_800_000);
    let year = compute(
        ReadRecordPeriod::Year,
        reference,
        details.clone(),
        records.clone(),
        shelf.clone(),
    );
    assert_eq!(year.chart.len(), 12);
    assert_eq!(year.chart[3].seconds, 3600);
    assert_eq!(year.chart[4].seconds, 10800);
    let all = compute(
        ReadRecordPeriod::All,
        reference,
        details,
        records.clone(),
        shelf.clone(),
    );
    assert_eq!(
        (all.total_time_ms, all.total_books, all.finished_books),
        (14_400_000, 3, 1)
    );
    assert!(all.chart.is_empty());
    let missing = compute(ReadRecordPeriod::Week, reference, vec![], records, shelf);
    assert_eq!(missing.total_time_ms, 0);
    assert!(missing.top_books.is_empty());
    assert!(missing.days.is_empty());
}
#[test]
fn calendar_combines_devices_respects_author_and_recent_reading_ties() {
    let details = vec![
        detail("同名", "甲", "2026-01-01", 400, 1),
        detail("同名", "甲", "2026-01-01", 600, 1),
        detail("同名", "乙", "2026-01-01", 1000, 2),
        detail("跨年", "", "2025-12-29", 2000, 1),
        detail("无效", "甲", "2026-02-31", 9999, 1),
    ];
    let records = vec![
        ReadRecord {
            book_name: "同名".into(),
            author: "\u{1e}authors:[\"甲\",\"乙\"]".into(),
            read_time: 2000,
            ..Default::default()
        },
        ReadRecord {
            book_name: "跨年".into(),
            read_time: 2000,
            ..Default::default()
        },
    ];
    let shelf = vec![Book {
        name: "同名".into(),
        author: "乙".into(),
        cover_url: Some("乙封面".into()),
        ..Default::default()
    }];
    let result = compute(
        ReadRecordPeriod::Week,
        require_date("2026-01-01").unwrap(),
        details,
        records,
        shelf,
    );
    assert_eq!(
        (
            result.total_time_ms,
            result.reading_days,
            result.total_books,
            result.reading_books
        ),
        (4000, 2, 3, 3)
    );
    let day = &result.days[0];
    assert_eq!((day.seconds, day.book_count), (2, 2));
    assert_eq!(day.top_book.author, "乙");
    assert_eq!(day.top_book.cover_url.as_deref(), Some("乙封面"));
    assert_eq!(
        range(ReadRecordPeriod::Month, require_date("2024-02-15").unwrap())
            .1
            .to_string(),
        "2024-02-29"
    );
}
#[test]
fn day_query_has_no_top_ten_limit_and_does_not_change_stored_details() {
    let conn = Connection::open_in_memory().unwrap();
    crate::schema::init_schema(&conn).unwrap();
    let repo = ReadRecordRepository::new(&conn);
    repo.ensure_detail_table().unwrap();
    for i in 0..12 {
        conn.execute("INSERT INTO readRecordDetail(deviceId,bookName,bookAuthor,date,readTime,lastRead) VALUES('',?1,'甲','2026-10-13',?2,0)",rusqlite::params![format!("书{i}"),1000+i]).unwrap();
    }
    conn.execute("INSERT INTO readRecordDetail(deviceId,bookName,bookAuthor,date,readTime,lastRead) VALUES('remote','书0','甲','2026-10-13',2000,1)",[]).unwrap();
    let before = repo.list_all_details().unwrap();
    let books = query_books_for_day(&conn, "2026-10-13").unwrap();
    assert_eq!(books.len(), 12);
    assert_eq!(books[0].book_name, "书0");
    assert_eq!(books[0].read_time_ms, 3000);
    let overview = query_overview(&conn, ReadRecordPeriod::Day, "2026-10-13").unwrap();
    assert_eq!((overview.total_time_ms, overview.total_books), (14_066, 12));
    assert_eq!(overview.top_books.len(), 10);
    assert!(overview.chart.is_empty());
    assert_eq!(repo.list_all_details().unwrap(), before);
    assert!(query_books_for_day(&conn, "2026-10-14").unwrap().is_empty());
    assert!(query_overview(&conn, ReadRecordPeriod::Day, "2026-02-31").is_err());
}
