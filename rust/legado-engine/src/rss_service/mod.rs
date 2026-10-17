//! RSS应用服务：存储按实例归属，文章加载显式注入网络与运行时。
use crate::{NetworkContext, StorageContext};
use legado_core::models::RssSource;
use legado_core::{LegadoError, LegadoResult};
use legado_db::RssSourceRepository;
use serde::{Deserialize, Serialize};
mod articles;
mod records;
mod sources;
/// RSS 文章项
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RssArticle {
    /// 标题
    pub title: String,
    /// 链接
    pub link: String,
    /// 描述
    pub description: Option<String>,
    /// 发布日期
    pub pub_date: Option<String>,
    /// 图片 URL
    pub image_url: Option<String>,
}

pub struct RssService {
    storage: Option<StorageContext>,
}
impl RssService {
    pub fn new(storage: Option<StorageContext>) -> Self {
        Self { storage }
    }
    fn with_database<T>(
        &self,
        f: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(f)
    }
}
#[cfg(test)]
mod tests;
