//! 阅读统计的类型化投影，不在桥接层重复聚合。— Codex + Bridge
#[derive(Debug, Clone)]
pub struct ReadRecordListRowDto {
    pub book_name: String,
    pub author: String,
    pub date: Option<String>,
    pub duration_ms: i64,
    pub last_read: i64,
}
impl From<legado_db::repository::read_record_list::ReadRecordListRow> for ReadRecordListRowDto {
    fn from(value: legado_db::repository::read_record_list::ReadRecordListRow) -> Self {
        Self {
            book_name: value.book_name,
            author: value.author,
            date: value.date,
            duration_ms: value.duration_ms,
            last_read: value.last_read,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReadRecordListDto {
    pub aggregate: Vec<ReadRecordListRowDto>,
    pub latest: Vec<ReadRecordListRowDto>,
    pub total_time_ms: i64,
}
impl From<legado_db::repository::read_record_list::ReadRecordList> for ReadRecordListDto {
    fn from(value: legado_db::repository::read_record_list::ReadRecordList) -> Self {
        Self {
            aggregate: value.aggregate.into_iter().map(Into::into).collect(),
            latest: value.latest.into_iter().map(Into::into).collect(),
            total_time_ms: value.total_time_ms,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum ReadRecordPeriodDto {
    Day,
    Week,
    Month,
    Year,
    All,
}
impl From<ReadRecordPeriodDto> for legado_db::repository::read_record_statistics::ReadRecordPeriod {
    fn from(value: ReadRecordPeriodDto) -> Self {
        match value {
            ReadRecordPeriodDto::Day => Self::Day,
            ReadRecordPeriodDto::Week => Self::Week,
            ReadRecordPeriodDto::Month => Self::Month,
            ReadRecordPeriodDto::Year => Self::Year,
            ReadRecordPeriodDto::All => Self::All,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReadBookRankingDto {
    pub book_name: String,
    pub author: String,
    pub read_time_ms: i64,
    pub cover_url: Option<String>,
}
impl From<legado_db::repository::read_record_statistics::ReadBookRanking> for ReadBookRankingDto {
    fn from(value: legado_db::repository::read_record_statistics::ReadBookRanking) -> Self {
        Self {
            book_name: value.book_name,
            author: value.author,
            read_time_ms: value.read_time_ms,
            cover_url: value.cover_url,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReadDayStatDto {
    pub date: String,
    pub seconds: i64,
    pub book_count: i32,
    pub top_book: ReadBookRankingDto,
}
impl From<legado_db::repository::read_record_statistics::ReadDayStat> for ReadDayStatDto {
    fn from(value: legado_db::repository::read_record_statistics::ReadDayStat) -> Self {
        Self {
            date: value.date,
            seconds: value.seconds,
            book_count: value.book_count,
            top_book: value.top_book.into(),
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReadChartPointDto {
    pub date: String,
    pub seconds: i64,
}
impl From<legado_db::repository::read_record_statistics::ReadChartPoint> for ReadChartPointDto {
    fn from(value: legado_db::repository::read_record_statistics::ReadChartPoint) -> Self {
        Self {
            date: value.date,
            seconds: value.seconds,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReadRecordStatisticsDto {
    pub total_time_ms: i64,
    pub reading_days: i32,
    pub total_books: i32,
    pub finished_books: i32,
    pub reading_books: i32,
    pub top_books: Vec<ReadBookRankingDto>,
    pub days: Vec<ReadDayStatDto>,
    pub chart: Vec<ReadChartPointDto>,
}
impl From<legado_db::repository::read_record_statistics::ReadRecordStatistics>
    for ReadRecordStatisticsDto
{
    fn from(value: legado_db::repository::read_record_statistics::ReadRecordStatistics) -> Self {
        Self {
            total_time_ms: value.total_time_ms,
            reading_days: value.reading_days,
            total_books: value.total_books,
            finished_books: value.finished_books,
            reading_books: value.reading_books,
            top_books: value.top_books.into_iter().map(Into::into).collect(),
            days: value.days.into_iter().map(Into::into).collect(),
            chart: value.chart.into_iter().map(Into::into).collect(),
        }
    }
}
