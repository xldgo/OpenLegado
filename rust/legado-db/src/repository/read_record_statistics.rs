//! 阅读总览只读投影；累计、明细和书架各自保留原有数据归属。— Codex + Rust
use super::{
    book_repository::BookRepository,
    read_record_repository::{
        ReadRecord, ReadRecordDetail, ReadRecordRepository, decode_read_record_authors,
    },
};
use chrono::{Datelike, Days, NaiveDate};
use legado_core::{LegadoError, LegadoResult, models::Book};
use rusqlite::Connection;
use std::collections::{BTreeMap, HashMap, HashSet};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReadRecordPeriod {
    Day,
    Week,
    Month,
    Year,
    All,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadBookRanking {
    pub book_name: String,
    pub author: String,
    pub read_time_ms: i64,
    pub cover_url: Option<String>,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadDayStat {
    pub date: String,
    pub seconds: i64,
    pub book_count: i32,
    pub top_book: ReadBookRanking,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadChartPoint {
    pub date: String,
    pub seconds: i64,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadRecordStatistics {
    pub total_time_ms: i64,
    pub reading_days: i32,
    pub total_books: i32,
    pub finished_books: i32,
    pub reading_books: i32,
    pub top_books: Vec<ReadBookRanking>,
    pub days: Vec<ReadDayStat>,
    pub chart: Vec<ReadChartPoint>,
}
pub(super) fn date(value: &str) -> Option<NaiveDate> {
    let date = NaiveDate::parse_from_str(value, "%Y-%m-%d").ok()?;
    (value.len() == 10 && date.format("%Y-%m-%d").to_string() == value).then_some(date)
}
fn require_date(value: &str) -> LegadoResult<NaiveDate> {
    date(value).ok_or_else(|| LegadoError::Internal("统计日期必须为有效的YYYY-MM-DD".into()))
}
fn range(period: ReadRecordPeriod, reference: NaiveDate) -> (NaiveDate, NaiveDate) {
    use ReadRecordPeriod::*;
    match period {
        Day | All => (reference, reference),
        Week => {
            let start = reference - Days::new(reference.weekday().num_days_from_monday().into());
            (start, start + Days::new(6))
        }
        Month => {
            let start = reference.with_day(1).unwrap();
            let next = if reference.month() == 12 {
                NaiveDate::from_ymd_opt(reference.year() + 1, 1, 1).unwrap()
            } else {
                NaiveDate::from_ymd_opt(reference.year(), reference.month() + 1, 1).unwrap()
            };
            (start, next - Days::new(1))
        }
        Year => (
            NaiveDate::from_ymd_opt(reference.year(), 1, 1).unwrap(),
            NaiveDate::from_ymd_opt(reference.year(), 12, 31).unwrap(),
        ),
    }
}
#[derive(Default)]
struct DayBooks {
    books: Vec<ReadBookRanking>,
    positions: HashMap<(String, String), usize>,
}
fn group_days(mut details: Vec<ReadRecordDetail>, shelf: &[Book]) -> BTreeMap<NaiveDate, DayBooks> {
    details.sort_by(|a, b| b.date.cmp(&a.date).then(b.last_read.cmp(&a.last_read)));
    let covers: HashMap<_, _> = shelf
        .iter()
        .map(|b| ((b.name.as_str(), b.author.as_str()), b.cover_url.clone()))
        .collect();
    let mut days: BTreeMap<NaiveDate, DayBooks> = BTreeMap::new();
    for detail in details {
        if detail.read_time <= 0 {
            continue;
        }
        let Some(date) = date(&detail.date) else {
            continue;
        };
        let day = days.entry(date).or_default();
        let key = (detail.book_name.clone(), detail.author.clone());
        if let Some(&index) = day.positions.get(&key) {
            day.books[index].read_time_ms += detail.read_time;
        } else {
            let cover_url = covers
                .get(&(detail.book_name.as_str(), detail.author.as_str()))
                .cloned()
                .flatten();
            day.positions.insert(key, day.books.len());
            day.books.push(ReadBookRanking {
                book_name: detail.book_name,
                author: detail.author,
                read_time_ms: detail.read_time,
                cover_url,
            });
        }
    }
    days
}
pub fn query_overview(
    conn: &Connection,
    period: ReadRecordPeriod,
    reference: &str,
) -> LegadoResult<ReadRecordStatistics> {
    let reference = require_date(reference)?;
    let repo = ReadRecordRepository::new(conn);
    let details = repo.list_all_details()?;
    let records = repo.find_all()?;
    let shelf = BookRepository::new(conn).find_all_in_shelf()?;
    Ok(compute(period, reference, details, records, shelf))
}
pub fn query_books_for_day(conn: &Connection, value: &str) -> LegadoResult<Vec<ReadBookRanking>> {
    let target = require_date(value)?;
    let repo = ReadRecordRepository::new(conn);
    let shelf = BookRepository::new(conn).find_all_in_shelf()?;
    let mut groups = group_days(repo.list_details_year(target.year())?, &shelf);
    let mut books = groups.remove(&target).map(|d| d.books).unwrap_or_default();
    books.sort_by(|a, b| {
        b.read_time_ms
            .cmp(&a.read_time_ms)
            .then(a.book_name.cmp(&b.book_name))
            .then(a.author.cmp(&b.author))
    });
    Ok(books)
}
fn compute(
    period: ReadRecordPeriod,
    reference: NaiveDate,
    details: Vec<ReadRecordDetail>,
    records: Vec<ReadRecord>,
    shelf: Vec<Book>,
) -> ReadRecordStatistics {
    let (start, end) = range(period, reference);
    let days = group_days(details, &shelf);
    let mut period_books = DayBooks::default();
    let mut period_days = BTreeMap::new();
    let mut calendar = Vec::new();
    for (date, day) in days.iter().rev() {
        let total: i64 = day.books.iter().map(|b| b.read_time_ms).sum();
        // max_by会在相等时取后者；此处明确保留最后阅读优先的首项。
        let mut top = &day.books[0];
        for book in &day.books[1..] {
            if book.read_time_ms > top.read_time_ms {
                top = book;
            }
        }
        calendar.push(ReadDayStat {
            date: date.to_string(),
            seconds: total / 1000,
            book_count: day.books.len() as i32,
            top_book: top.clone(),
        });
        if period != ReadRecordPeriod::All && (*date < start || *date > end) {
            continue;
        }
        period_days.insert(*date, total);
        for book in &day.books {
            let key = (book.book_name.clone(), book.author.clone());
            if let Some(&index) = period_books.positions.get(&key) {
                period_books.books[index].read_time_ms += book.read_time_ms;
            } else {
                period_books.positions.insert(key, period_books.books.len());
                period_books.books.push(book.clone());
            }
        }
    }
    let latest: HashSet<_> = records
        .iter()
        .flat_map(|r| {
            // 空作者也是统计身份；仅作者集合编码走数据库的合并解码。
            let authors = if r.author.starts_with("\u{1e}authors:") {
                decode_read_record_authors(&r.author)
            } else {
                vec![r.author.clone()]
            };
            authors.into_iter().map(|a| (r.book_name.clone(), a))
        })
        .collect();
    let shelf: HashMap<_, _> = shelf
        .into_iter()
        .map(|b| ((b.name.clone(), b.author.clone()), b))
        .collect();
    let reading = period_books
        .positions
        .keys()
        .filter(|k| latest.contains(*k))
        .count();
    let finished = period_books
        .positions
        .keys()
        .filter(|k| {
            shelf.get(*k).is_some_and(|b| {
                b.total_chapter_num > 0
                    && b.dur_chapter_index >= b.total_chapter_num - 1
                    && b.dur_chapter_pos != 0
            })
        })
        .count();
    period_books
        .books
        .sort_by(|a, b| b.read_time_ms.cmp(&a.read_time_ms));
    let mut chart = Vec::new();
    if period == ReadRecordPeriod::Year {
        for month in 1..=12 {
            let total: i64 = period_days
                .iter()
                .filter(|(d, _)| d.month() == month)
                .map(|(_, v)| v)
                .sum();
            chart.push(ReadChartPoint {
                date: NaiveDate::from_ymd_opt(reference.year(), month, 1)
                    .unwrap()
                    .to_string(),
                seconds: total / 1000,
            });
        }
    } else if matches!(period, ReadRecordPeriod::Week | ReadRecordPeriod::Month) {
        let mut day = start;
        while day <= end {
            chart.push(ReadChartPoint {
                date: day.to_string(),
                seconds: period_days.get(&day).copied().unwrap_or(0) / 1000,
            });
            day = day + Days::new(1);
        }
    }
    ReadRecordStatistics {
        total_time_ms: if period == ReadRecordPeriod::All {
            records.iter().map(|r| r.read_time).sum()
        } else {
            period_days.values().sum()
        },
        reading_days: period_days.len() as i32,
        total_books: period_books.books.len() as i32,
        reading_books: reading as i32,
        finished_books: finished as i32,
        top_books: period_books.books.into_iter().take(10).collect(),
        days: calendar,
        chart,
    }
}
#[cfg(test)]
mod tests;
