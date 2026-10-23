//! 当前格式完整校验后在数据库备份仓储内恢复，不保留开发阶段旧格式分支。
use super::*;
pub(super) fn restore(service: &BackupService, path: &str) -> LegadoResult<RestoreStats> {
    let bytes = fs::read(path)?;
    let data: BackupData = serde_json::from_slice(&bytes)
        .map_err(|e| LegadoError::Parser(format!("备份JSON结构错误: {e}")))?;
    let mut counts = service.with_database(|db| {
        legado_db::backup::BackupRepository::new(db.connection()).restore(&data)
    })?;
    // 只在完整业务事务提交后发布限速配置，不修改仍在运行的旧调用作用域。
    if let Some(registry) = &service.rates {
        for source in &data.collections["bookSources"] {
            if let Some(url) = source
                .get("bookSourceUrl")
                .and_then(serde_json::Value::as_str)
            {
                registry.refresh(
                    url,
                    source
                        .get("concurrentRate")
                        .and_then(serde_json::Value::as_str)
                        .unwrap_or(""),
                );
            }
        }
    }
    Ok(RestoreStats {
        books: counts.remove("books").unwrap_or(0),
        bookmarks: counts.remove("bookmarks").unwrap_or(0),
        replace_rules: counts.remove("replaceRules").unwrap_or(0),
        book_sources: counts.remove("bookSources").unwrap_or(0),
        rss_sources: counts.remove("rssSources").unwrap_or(0),
        read_records: counts.remove("readRecords").unwrap_or(0),
        additional: counts.into_iter().collect(),
    })
}
