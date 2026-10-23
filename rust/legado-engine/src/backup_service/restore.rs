//! 当前格式完整校验后在数据库备份仓储内恢复，不保留开发阶段旧格式分支。
use super::*;
pub(super) fn restore(
    service: &BackupService,
    path: &str,
    options: &RestoreOptions,
) -> LegadoResult<BackupRestoreResult> {
    if options.ignore.iter().any(|key| {
        !["localBook", "threadCount", "coverConfig", "readConfig"].contains(&key.as_str())
    }) {
        return Err(LegadoError::Parser("未知恢复忽略项".into()));
    }
    let mut decoded = super::package::decode(path, options.password.as_deref())?;
    service.with_database(|db| {
        legado_db::backup::BackupRepository::new(db.connection()).validate(&decoded.data)
    })?;
    if options.ignore.contains("localBook") {
        decoded
            .data
            .collections
            .get_mut("books")
            .unwrap()
            .retain(|row| {
                let origin = row
                    .get("origin")
                    .and_then(serde_json::Value::as_str)
                    .unwrap_or("");
                let kind = row
                    .get("type")
                    .and_then(serde_json::Value::as_i64)
                    .unwrap_or(0);
                origin != "loc_book"
                    && !origin.starts_with(legado_core::models::book::book_type::WEB_DAV_TAG)
                    && kind & i64::from(legado_core::models::book::book_type::LOCAL) == 0
            });
    }
    if options.ignore.contains("threadCount") {
        decoded.data.config.remove("threadCount");
    }
    if options.ignore.contains("coverConfig") {
        decoded
            .data
            .collections
            .get_mut("coverRules")
            .unwrap()
            .clear();
    }
    if options.ignore.contains("readConfig") {
        decoded.data.config.retain(|key, _| {
            !key.starts_with("manga")
                && !key.starts_with("disableManga")
                && ![
                    "enableMangaEInk",
                    "enableMangaGray",
                    "hideMangaTitle",
                    "volumeKeyPage",
                    "reverseVolumeKeyPage",
                    "disableClickScroll",
                ]
                .contains(&key.as_str())
        });
    }
    let root = service
        .storage
        .as_ref()
        .ok_or_else(|| LegadoError::Database("数据库尚未初始化".into()))?
        .data_directory("backup_resources")?;
    let resources = super::package::restore_resources(&mut decoded, &root)?;
    let data = &decoded.data;
    let mut counts = service.with_database(|db| {
        legado_db::backup::BackupRepository::new(db.connection()).restore(data)
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
    resources.commit();
    if !data.collections["cloudTtsEngines"].is_empty()
        && !decoded.sensitive.contains_key("cloudTtsCredentials")
    {
        decoded
            .warnings
            .push("云TTS引擎已恢复，此备份未包含云端密钥，请重新配置".into());
    }
    Ok(BackupRestoreResult {
        stats: RestoreStats {
            books: counts.remove("books").unwrap_or(0),
            bookmarks: counts.remove("bookmarks").unwrap_or(0),
            replace_rules: counts.remove("replaceRules").unwrap_or(0),
            book_sources: counts.remove("bookSources").unwrap_or(0),
            rss_sources: counts.remove("rssSources").unwrap_or(0),
            read_records: counts.remove("readRecords").unwrap_or(0),
            additional: counts.into_iter().collect(),
        },
        preferences: decoded.preferences,
        sensitive: decoded.sensitive,
        warnings: decoded.warnings,
    })
}
