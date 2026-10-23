use super::*;

fn detail(name: &str, author: &str, date: &str, time: i64, last: i64) -> ReadRecordDetail {
    ReadRecordDetail {
        book_name: name.into(),
        author: author.into(),
        date: date.into(),
        read_time: time,
        last_read: last,
        ..Default::default()
    }
}
fn record(name: &str, author: &str, time: i64, last: i64) -> ReadRecord {
    ReadRecord {
        book_name: name.into(),
        author: author.into(),
        read_time: time,
        last_read: last,
        ..Default::default()
    }
}

#[test]
fn list_combines_devices_dates_and_authors_without_fabricating_daily_history() {
    let details = vec![
        detail("同名", "甲", "2026-10-13", 1000, 2),
        detail("同名", "甲", "2026-10-13", 2000, 3),
        detail("同名", "乙", "2026-10-13", 4000, 4),
        detail("早期", "甲", "2025-12-31", 5000, 1),
        detail("同名", "甲", "2026-10-14", 6000, 5),
        detail("无效", "", "2026-02-31", 500, 1),
        detail("零时长", "", "2026-10-14", 0, 1),
    ];
    let records = vec![
        record("同名", "其他作者", 100_000, 9),
        record("累计独有", "Author", 3000, 6),
        record("无效", "", 1000, 8),
        record("零时长", "", 0, 8),
    ];
    let result = compute(details.clone(), records.clone(), "");
    assert_eq!(result.total_time_ms, 104_000);
    assert_eq!(result.aggregate.len(), 4);
    assert_eq!(
        (
            result.aggregate[0].date.as_deref(),
            result.aggregate[0].duration_ms
        ),
        (Some("2026-10-14"), 6000)
    );
    assert_eq!(result.aggregate[1].author, "乙");
    assert_eq!(result.aggregate[2].duration_ms, 3000);
    assert_eq!(
        result
            .latest
            .iter()
            .map(|r| (r.book_name.as_str(), r.author.as_str(), r.duration_ms))
            .collect::<Vec<_>>(),
        [
            ("累计独有", "Author", 3000),
            ("同名", "甲", 9000),
            ("同名", "乙", 4000),
            ("早期", "甲", 5000)
        ]
    );
    assert!(result.latest.iter().all(|r| r.date.is_none()));
    let searched = compute(details.clone(), records.clone(), "  aUtHoR  ");
    assert_eq!(searched.latest.len(), 1);
    assert!(searched.aggregate.is_empty());
    assert_eq!(searched.total_time_ms, 104_000);
    let author = compute(details, records, "甲");
    assert_eq!(author.aggregate.len(), 3);
    assert_eq!(author.latest.len(), 2);
}

#[test]
fn query_preserves_cumulative_author_encoding_and_does_not_write_or_reorder_ties() {
    let conn = Connection::open_in_memory().unwrap();
    crate::schema::init_schema(&conn).unwrap();
    let repo = ReadRecordRepository::new(&conn);
    repo.ensure_detail_table().unwrap();
    let encoded = "\u{1e}authors:[\"甲\",\"乙\"]";
    repo.upsert_full("a", "累计独有", encoded, 3000, 6).unwrap();
    repo.upsert_full("b", "累计独有", encoded, 4000, 9).unwrap();
    let records = repo.find_all().unwrap();
    let result = query_read_list(&conn, "甲").unwrap();
    assert_eq!(result.latest.len(), 1);
    assert_eq!(result.latest[0].author, encoded);
    assert_eq!(
        (result.latest[0].duration_ms, result.latest[0].last_read),
        (7000, 9)
    );
    assert!(result.aggregate.is_empty());
    assert_eq!(
        serde_json::to_value(repo.find_all().unwrap()).unwrap(),
        serde_json::to_value(records).unwrap()
    );
    assert!(repo.list_all_details().unwrap().is_empty());
    let rows = compute(
        vec![
            detail("先到", "", "2026-10-13", 10, 5),
            detail("后到", "", "2026-10-13", 20, 5),
        ],
        vec![],
        "",
    );
    assert_eq!(
        rows.aggregate
            .iter()
            .map(|r| r.book_name.as_str())
            .collect::<Vec<_>>(),
        ["先到", "后到"]
    );
}
