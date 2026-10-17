//! 收藏与已读使用同一存储，数据映射保留在宿主边界。
use super::*;
use legado_db::{RssReadRecordRepository, RssReadRecordRow, RssStarRecord, RssStarRepository};
impl RssService {
    pub fn get_rss_stars(&self) -> LegadoResult<Vec<RssStarRecord>> {
        self.with_database(|db| {
            let repo = RssStarRepository::new(db.connection());
            let records = repo.find_all()?;
            Ok(records)
        })
    }

    pub fn add_rss_star(&self, source_url: &str, title: &str, link: &str) -> LegadoResult<i64> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;

        // v101 新增字段（group/star_type/dur_pos）取默认值，函数签名保持不变
        let record = RssStarRecord {
            origin: source_url.to_string(),
            sort: "default".to_string(),
            title: title.to_string(),
            star_time: now,
            link: Some(link.to_string()),
            pub_date: None,
            description: None,
            content: None,
            image: None,
            variable: None,
            ..Default::default()
        };

        self.with_database(|db| {
            let repo = RssStarRepository::new(db.connection());
            repo.add_star(&record)?;
            Ok(now)
        })
    }

    pub fn delete_rss_star(&self, link: &str) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = RssStarRepository::new(db.connection());
            repo.remove_star(link)?;
            Ok(true)
        })
    }

    pub fn is_rss_starred(&self, link: &str) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = RssStarRepository::new(db.connection());
            repo.is_starred(link)
        })
    }

    pub fn mark_read(&self, origin: &str, title: &str, link: Option<&str>) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.mark_read(origin, title, link)
        })
    }

    pub fn is_read(&self, link: &str) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.is_read(link)
        })
    }

    pub fn is_read_by_title(&self, origin: &str, title: &str) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.is_read_by_title(origin, title)
        })
    }

    pub fn clear_read_records(&self) -> LegadoResult<()> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.clear_all()
        })
    }

    pub fn read_record_count(&self) -> LegadoResult<i64> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.count()
        })
    }

    pub fn list_records(&self, limit: Option<i32>) -> LegadoResult<Vec<RssReadRecordRow>> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.list_records(limit)
        })
    }

    pub fn list_records_by_origin(
        &self,
        origin: &str,
        limit: Option<i32>,
    ) -> LegadoResult<Vec<RssReadRecordRow>> {
        self.with_database(|db| {
            let repo = RssReadRecordRepository::new(db.connection());
            repo.list_records_by_origin(origin, limit)
        })
    }
}
