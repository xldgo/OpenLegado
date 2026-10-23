use super::*;
use crate::repository::read_record_repository::ReadRecordRepository;

const HOUR: i64 = 3_600_000;
const BASE: i64 = 1_779_235_200_000;

fn database() -> Connection {
    let conn = Connection::open_in_memory().unwrap();
    crate::schema::init_schema(&conn).unwrap();
    conn
}
fn session(conn: &Connection, device: &str, start: i64, end: i64) {
    conn.execute(
        "INSERT INTO readRecordSession(deviceId,bookName,startTime,endTime)
         VALUES(?1,'小说',?2,?3)",
        rusqlite::params![device, BASE + start, BASE + end],
    )
    .unwrap();
}

#[test]
fn clips_real_sessions_sums_milliseconds_and_preserves_device_copies_without_writes() {
    let conn = database();
    let boundaries: Vec<_> = (0..=24).map(|h| BASE + h * HOUR).collect();
    assert_eq!(query_read_hourly(&conn, &boundaries).unwrap(), vec![0; 24]);
    session(&conn, "", -15 * 60_000, 15 * 60_000);
    session(&conn, "remote", -15 * 60_000, 15 * 60_000);
    session(&conn, "", 8 * HOUR + 45 * 60_000, 10 * HOUR + 15 * 60_000);
    session(&conn, "", 23 * HOUR + 50 * 60_000, 24 * HOUR + 20 * 60_000);
    session(&conn, "", 12 * HOUR, 12 * HOUR + 600);
    session(&conn, "", 12 * HOUR + 1000, 12 * HOUR + 1600);
    // 正好在边界外的会话不进入当天，也不重复计入相邻槽。
    session(&conn, "", -HOUR, 0);
    session(&conn, "", 24 * HOUR, 25 * HOUR);
    let repo = ReadRecordRepository::new(&conn);
    let before = repo.list_read_sessions().unwrap();
    let result = query_read_hourly(&conn, &boundaries).unwrap();
    let mut expected = vec![0; 24];
    for (hour, seconds) in [
        (0, 1800),
        (8, 900),
        (9, 3600),
        (10, 900),
        (12, 1),
        (23, 600),
    ] {
        expected[hour] = seconds;
    }
    assert_eq!(result, expected);
    assert_eq!(repo.list_read_sessions().unwrap(), before);
}

#[test]
fn uses_supplied_dst_boundaries() {
    let conn = database();
    session(&conn, "", -HOUR, 26 * HOUR);
    // 平台跳时后，相邻两个日历小时可映射到相同时间戳。
    let spring: Vec<_> = (0..=24)
        .map(|hour| BASE + (if hour <= 2 { hour } else { hour - 1 }) * HOUR)
        .collect();
    let mut expected = vec![3600; 24];
    expected[2] = 0;
    assert_eq!(query_read_hourly(&conn, &spring).unwrap(), expected);
    // 回拨日中，一个小时槽可包含两个真实小时，不以固定时长截断。
    let autumn: Vec<_> = (0..=24)
        .map(|hour| BASE + (if hour <= 1 { hour } else { hour + 1 }) * HOUR)
        .collect();
    expected.fill(3600);
    expected[1] = 7200;
    assert_eq!(query_read_hourly(&conn, &autumn).unwrap(), expected);
}
