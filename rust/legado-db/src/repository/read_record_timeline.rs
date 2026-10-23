//! 时间线只读投影；展示跨度与原始会话计时、删除分离。— Codex + Rust
use super::{
    read_record_repository::ReadRecordRepository, read_record_sessions::ReadRecordSession,
};
use chrono::{Local, TimeZone};
use legado_core::{LegadoError, LegadoResult};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadRecordTimelineEntry {
    pub book_name: String,
    pub author: String,
    pub date: String,
    pub book_url: String,
    pub start_time: i64,
    pub end_time: i64,
    pub chapter_index: i32,
    pub session_ids: Vec<i64>,
}

impl ReadRecordRepository<'_> {
    pub fn list_read_timeline(&self, query: &str) -> LegadoResult<Vec<ReadRecordTimelineEntry>> {
        merge_sessions(self.list_read_sessions()?, query, &Local)
    }
}

fn merge_sessions<Tz: TimeZone>(
    mut sessions: Vec<ReadRecordSession>,
    query: &str,
    timezone: &Tz,
) -> LegadoResult<Vec<ReadRecordTimelineEntry>> {
    let needle = query.trim().to_lowercase();
    sessions.retain(|s| {
        s.end_time > s.start_time
            && (needle.is_empty()
                || s.book_name.to_lowercase().contains(&needle)
                || s.book_author.to_lowercase().contains(&needle))
    });
    sessions.sort_by_key(|s| (s.start_time, s.id));
    let mut rows: Vec<ReadRecordTimelineEntry> = Vec::new();
    let mut seen = HashMap::new();
    for session in sessions {
        let identity = (
            session.book_name.clone(),
            session.book_author.clone(),
            session.book_url.clone(),
            session.start_time,
            session.end_time,
            session.chapter_index,
        );
        if let Some(&index) = seen.get(&identity) {
            let row: &mut ReadRecordTimelineEntry = &mut rows[index];
            row.session_ids.push(session.id);
            continue;
        }
        let date = timezone
            .timestamp_millis_opt(session.start_time)
            .single()
            .ok_or_else(|| LegadoError::Internal("阅读会话开始时间超出支持范围".into()))?
            .date_naive()
            .format("%Y-%m-%d")
            .to_string();
        let index = match rows.last_mut() {
            Some(last)
                if last.date == date
                    && last.book_name == session.book_name
                    && last.author == session.book_author
                    && session.start_time.saturating_sub(last.end_time) <= 20 * 60 * 1000 =>
            {
                last.end_time = last.end_time.max(session.end_time);
                last.session_ids.push(session.id);
                rows.len() - 1
            }
            _ => {
                rows.push(ReadRecordTimelineEntry {
                    book_name: session.book_name,
                    author: session.book_author,
                    date,
                    book_url: session.book_url,
                    start_time: session.start_time,
                    end_time: session.end_time,
                    chapter_index: session.chapter_index,
                    session_ids: vec![session.id],
                });
                rows.len() - 1
            }
        };
        seen.insert(identity, index);
    }
    rows.reverse();
    Ok(rows)
}

#[cfg(test)]
mod tests;
