//! 记录列表的业务归并与摘要，保留现有明细/累计各自口径。— Codex + Rust
use super::{
    read_record_repository::{ReadRecord, ReadRecordDetail, ReadRecordRepository},
    read_record_statistics::date,
};
use legado_core::LegadoResult;
use rusqlite::Connection;
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadRecordListRow {
    pub book_name: String,
    pub author: String,
    pub date: Option<String>,
    pub duration_ms: i64,
    pub last_read: i64,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadRecordList {
    pub aggregate: Vec<ReadRecordListRow>,
    pub latest: Vec<ReadRecordListRow>,
    pub total_time_ms: i64,
}
#[derive(Default)]
struct Rows {
    values: Vec<ReadRecordListRow>,
    positions: HashMap<(String, String, Option<String>), usize>,
}
impl Rows {
    fn add(&mut self, mut row: ReadRecordListRow) {
        let key = (row.book_name.clone(), row.author.clone(), row.date.clone());
        row.last_read = row.last_read.max(0);
        if let Some(&index) = self.positions.get(&key) {
            let old = &mut self.values[index];
            old.duration_ms += row.duration_ms;
            old.last_read = old.last_read.max(row.last_read);
        } else {
            self.positions.insert(key, self.values.len());
            self.values.push(row);
        }
    }
    fn sorted(mut self) -> Vec<ReadRecordListRow> {
        self.values
            .sort_by(|a, b| b.date.cmp(&a.date).then(b.last_read.cmp(&a.last_read)));
        self.values
    }
}
pub fn query_read_list(conn: &Connection, query: &str) -> LegadoResult<ReadRecordList> {
    let repository = ReadRecordRepository::new(conn);
    Ok(compute(
        repository.list_all_details()?,
        repository.find_all()?,
        query,
    ))
}
fn compute(
    details: Vec<ReadRecordDetail>,
    records: Vec<ReadRecord>,
    query: &str,
) -> ReadRecordList {
    let needle = query.trim().to_lowercase();
    let matches = |name: &str, author: &str| {
        needle.is_empty()
            || name.to_lowercase().contains(&needle)
            || author.to_lowercase().contains(&needle)
    };
    let mut aggregate = Rows::default();
    let mut latest = Rows::default();
    // 依据原始明细是否有同名书决定回退，不因搜索或日期过滤补入累计记录。
    let with_details: HashSet<_> = details.iter().map(|d| d.book_name.as_str()).collect();
    for detail in &details {
        if detail.read_time <= 0
            || date(&detail.date).is_none()
            || !matches(&detail.book_name, &detail.author)
        {
            continue;
        }
        let row = ReadRecordListRow {
            book_name: detail.book_name.clone(),
            author: detail.author.clone(),
            date: Some(detail.date.clone()),
            duration_ms: detail.read_time,
            last_read: detail.last_read,
        };
        aggregate.add(row.clone());
        latest.add(ReadRecordListRow { date: None, ..row });
    }
    for record in &records {
        if !with_details.contains(record.book_name.as_str())
            && matches(&record.book_name, &record.author)
        {
            latest.add(ReadRecordListRow {
                book_name: record.book_name.clone(),
                author: record.author.clone(),
                date: None,
                duration_ms: record.read_time,
                last_read: record.last_read,
            });
        }
    }
    ReadRecordList {
        aggregate: aggregate.sorted(),
        latest: latest.sorted(),
        total_time_ms: records.iter().map(|r| r.read_time).sum(),
    }
}

#[cfg(test)]
mod tests;
