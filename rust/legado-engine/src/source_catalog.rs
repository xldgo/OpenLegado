//! 显式存储能力下的启用书源筛选；无宿主全局发现。
use crate::StorageContext;
use legado_core::{LegadoError, LegadoResult, models::BookSource};

pub fn load_search_sources_selected_from(
    storage: Option<&StorageContext>,
    urls: &[String],
) -> LegadoResult<Vec<BookSource>> {
    let storage = storage
        .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?;
    let all = storage.with_database(|db| {
        crate::book_source_service::BookSourceService::new(db).list_enabled_sources()
    })?;
    Ok(if urls.is_empty() {
        all
    } else {
        all.into_iter()
            .filter(|source| urls.contains(&source.book_source_url))
            .collect()
    })
}
