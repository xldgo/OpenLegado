//! RSS已读宿主适配，操作委托所属实例服务。
use super::rss::host_service;
use legado_core::LegadoResult;
use legado_db::RssReadRecordRow;
pub fn mark_read(origin: &str, title: &str, link: Option<&str>) -> LegadoResult<()> {
    host_service().mark_read(origin, title, link)
}

pub fn is_read(link: &str) -> LegadoResult<bool> {
    host_service().is_read(link)
}

pub fn is_read_by_title(origin: &str, title: &str) -> LegadoResult<bool> {
    host_service().is_read_by_title(origin, title)
}

pub fn clear_all() -> LegadoResult<()> {
    host_service().clear_read_records()
}

pub fn count() -> LegadoResult<i64> {
    host_service().read_record_count()
}

pub fn list_records(limit: Option<i32>) -> LegadoResult<Vec<RssReadRecordRow>> {
    host_service().list_records(limit)
}

pub fn list_records_by_origin(
    origin: &str,
    limit: Option<i32>,
) -> LegadoResult<Vec<RssReadRecordRow>> {
    host_service().list_records_by_origin(origin, limit)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rss_read_record_crud() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 标记已读
        mark_read(
            "https://rss.example.com",
            "Test Article",
            Some("https://link.com/1"),
        )
        .unwrap();

        // 判断已读
        assert!(is_read("https://link.com/1").unwrap());
        assert!(!is_read("https://link.com/999").unwrap());

        // 按标题判断
        assert!(is_read_by_title("https://rss.example.com", "Test Article").unwrap());
        assert!(!is_read_by_title("https://rss.example.com", "Other").unwrap());

        // 计数
        let c = count().unwrap();
        assert!(c >= 1);

        // 列表
        let records = list_records(Some(10)).unwrap();
        assert!(records.iter().any(|r| r.title == "Test Article"));

        // 按 origin 列表
        mark_read("https://other.com", "Other", Some("https://link.com/2")).unwrap();
        let by_origin = list_records_by_origin("https://rss.example.com", None).unwrap();
        assert!(
            by_origin
                .iter()
                .all(|r| r.origin == "https://rss.example.com")
        );
        assert_eq!(by_origin.len(), 1);

        // 清空
        clear_all().unwrap();
        assert_eq!(count().unwrap(), 0);
    }
}
