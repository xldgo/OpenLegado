//! RSS 收藏管理 API
//!
//! 提供 RSS 文章收藏的增删查操作，通过 RssStarRepository 访问数据库。

use serde::Serialize;

use legado_core::LegadoResult;
use legado_db::RssStarRecord;

use super::rss::host_service;

/// RSS 收藏 DTO（可序列化）
#[derive(Debug, Clone, Serialize)]
pub struct RssStarDto {
    pub origin: String,
    pub sort: String,
    pub title: String,
    pub star_time: i64,
    pub link: Option<String>,
    pub pub_date: Option<String>,
    pub description: Option<String>,
    pub content: Option<String>,
    pub image: Option<String>,
    pub variable: Option<String>,
}

impl From<RssStarRecord> for RssStarDto {
    fn from(r: RssStarRecord) -> Self {
        Self {
            origin: r.origin,
            sort: r.sort,
            title: r.title,
            star_time: r.star_time,
            link: r.link,
            pub_date: r.pub_date,
            description: r.description,
            content: r.content,
            image: r.image,
            variable: r.variable,
        }
    }
}

pub fn get_rss_stars() -> LegadoResult<Vec<RssStarDto>> {
    Ok(host_service()
        .get_rss_stars()?
        .into_iter()
        .map(RssStarDto::from)
        .collect())
}

pub fn add_rss_star(source_url: &str, title: &str, link: &str) -> LegadoResult<i64> {
    host_service().add_rss_star(source_url, title, link)
}

pub fn delete_rss_star(link: &str) -> LegadoResult<bool> {
    host_service().delete_rss_star(link)
}

pub fn is_rss_starred(link: &str) -> LegadoResult<bool> {
    host_service().is_rss_starred(link)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rss_star_crud() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 添加收藏
        let ts = add_rss_star(
            "https://rss.example.com",
            "Test Article",
            "https://link.com/1",
        )
        .unwrap();
        assert!(ts > 0);

        // 判断已收藏
        assert!(is_rss_starred("https://link.com/1").unwrap());
        assert!(!is_rss_starred("https://link.com/999").unwrap());

        // 获取列表
        let stars = get_rss_stars().unwrap();
        assert!(stars.iter().any(|s| s.title == "Test Article"));

        // 删除收藏
        assert!(delete_rss_star("https://link.com/1").unwrap());
        assert!(!is_rss_starred("https://link.com/1").unwrap());
    }
}
