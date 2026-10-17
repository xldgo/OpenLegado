//! 备份/恢复 API
//!
//! 提供数据库备份创建、恢复和备份文件列表功能。
//! 备份格式为 JSON，包含 books/bookmarks/replaceRules/bookSources/rssSources/readRecords。

use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

use legado_core::models::{Book, BookSource, Bookmark, RssSource};
use legado_core::{LegadoError, LegadoResult};
use legado_db::repository::Repository;
use legado_db::{
    BookRepository, BookSourceRepository, BookmarkRepository, ReadRecordRepository,
    ReplaceRuleRepository, RssSourceRepository,
};

use crate::db_state::with_database;

/// 备份数据结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupData {
    /// 备份版本
    #[serde(default = "default_version")]
    pub version: i32,
    /// 备份时间戳（毫秒）
    #[serde(default, rename = "backupTime")]
    pub backup_time: i64,
    /// 书籍列表
    #[serde(default)]
    pub books: Vec<serde_json::Value>,
    /// 书签列表
    #[serde(default)]
    pub bookmarks: Vec<serde_json::Value>,
    /// 替换规则列表
    #[serde(default, rename = "replaceRules")]
    pub replace_rules: Vec<serde_json::Value>,
    /// 书源列表
    #[serde(default, rename = "bookSources")]
    pub book_sources: Vec<serde_json::Value>,
    /// RSS 源列表
    #[serde(default, rename = "rssSources")]
    pub rss_sources: Vec<serde_json::Value>,
    /// 阅读记录列表
    #[serde(default, rename = "readRecords")]
    pub read_records: Vec<serde_json::Value>,
}

fn default_version() -> i32 {
    1
}

/// 恢复统计
#[derive(Debug, Clone, Serialize)]
pub struct RestoreStats {
    pub books: usize,
    pub bookmarks: usize,
    pub replace_rules: usize,
    pub book_sources: usize,
    pub rss_sources: usize,
    pub read_records: usize,
}

/// 创建备份到指定路径
///
/// 收集 books/bookmarks/replaceRules/bookSources/rssSources/readRecords，
/// 序列化为 JSON 写入文件，返回备份文件路径。
pub fn backup_create(path: &str) -> LegadoResult<String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;

    let backup_data = with_database(|db| {
        let conn = db.connection();

        // 收集书籍
        let book_repo = BookRepository::new(conn);
        let books: Vec<serde_json::Value> = book_repo
            .find_all()?
            .into_iter()
            .filter_map(|b| serde_json::to_value(&b).ok())
            .collect();

        // 收集书签
        let bookmark_repo = BookmarkRepository::new(conn);
        let bookmarks: Vec<serde_json::Value> = bookmark_repo
            .find_all()?
            .into_iter()
            .filter_map(|b| serde_json::to_value(&b).ok())
            .collect();

        // 收集替换规则
        let rule_repo = ReplaceRuleRepository::new(conn);
        let replace_rules: Vec<serde_json::Value> = rule_repo
            .find_all()?
            .into_iter()
            .filter_map(|r| serde_json::to_value(&r).ok())
            .collect();

        // 收集书源
        let source_repo = BookSourceRepository::new(conn);
        let book_sources: Vec<serde_json::Value> = source_repo
            .find_all()?
            .into_iter()
            .filter_map(|s| serde_json::to_value(&s).ok())
            .collect();

        // RSS 备份沿用实体字段类型与完整仓储映射。
        let rss_sources = collect_rss_sources(conn)?;

        // 收集阅读记录
        let record_repo = ReadRecordRepository::new(conn);
        let read_records: Vec<serde_json::Value> = record_repo
            .find_all()?
            .into_iter()
            .filter_map(|r| serde_json::to_value(&r).ok())
            .collect();

        Ok(BackupData {
            version: 1,
            backup_time: now,
            books,
            bookmarks,
            replace_rules,
            book_sources,
            rss_sources,
            read_records,
        })
    })?;

    // 确保目录存在
    if let Some(parent) = Path::new(path).parent() {
        fs::create_dir_all(parent).map_err(|e| {
            LegadoError::Io(std::io::Error::other(format!("创建备份目录失败: {e}")))
        })?;
    }

    // 写入文件
    let json = serde_json::to_string_pretty(&backup_data)
        .map_err(|e| LegadoError::Internal(format!("备份序列化失败: {e}")))?;
    fs::write(path, &json)
        .map_err(|e| LegadoError::Io(std::io::Error::other(format!("写入备份文件失败: {e}"))))?;

    Ok(path.to_string())
}

/// 从备份文件恢复
///
/// 读取 JSON 文件，逐条恢复各表数据，返回恢复统计。
pub fn backup_restore(path: &str) -> LegadoResult<String> {
    Ok(serde_json::to_string(&restore_backup(path)?)?)
}
/// 恢复文档与类型化统计共享同一执行链。
pub fn restore_backup(path: &str) -> LegadoResult<RestoreStats> {
    let content = fs::read_to_string(path)
        .map_err(|e| LegadoError::Io(std::io::Error::other(format!("读取备份文件失败: {e}"))))?;

    let backup: BackupData = serde_json::from_str(&content)
        .map_err(|e| LegadoError::Internal(format!("备份文件解析失败: {e}")))?;

    let stats = with_database(|db| {
        let conn = db.connection();
        let mut stats = RestoreStats {
            books: 0,
            bookmarks: 0,
            replace_rules: 0,
            book_sources: 0,
            rss_sources: 0,
            read_records: 0,
        };

        // 恢复书籍
        // 评审 W3：失败不再静默吞错——UNIQUE 撞名等写入失败记 warn 日志，
        // 便于排查「恢复数量少于备份数量」类问题（RestoreStats 仅含成功计数，
        // 失败不入统计以免变更 FFI 返回结构）
        let book_repo = BookRepository::new(conn);
        for value in &backup.books {
            if let Ok(book) = serde_json::from_value::<Book>(value.clone()) {
                match book_repo.insert(&book) {
                    Ok(()) => stats.books += 1,
                    Err(e) => log::warn!("恢复书籍失败（已跳过）: {} - {e}", book.book_url),
                }
            }
        }

        // 恢复书签
        let bookmark_repo = BookmarkRepository::new(conn);
        for value in &backup.bookmarks {
            if let Ok(bm) = serde_json::from_value::<Bookmark>(value.clone()) {
                match bookmark_repo.insert(&bm) {
                    Ok(_) => stats.bookmarks += 1,
                    Err(e) => log::warn!("恢复书签失败（已跳过）: {} - {e}", bm.book_name),
                }
            }
        }

        // 恢复替换规则
        let rule_repo = ReplaceRuleRepository::new(conn);
        for value in &backup.replace_rules {
            if let Ok(rule) =
                serde_json::from_value::<legado_core::models::ReplaceRule>(value.clone())
            {
                match rule_repo.insert(&rule) {
                    Ok(_) => stats.replace_rules += 1,
                    Err(e) => log::warn!("恢复替换规则失败（已跳过）: {} - {e}", rule.name),
                }
            }
        }

        // 恢复书源
        let source_repo = BookSourceRepository::new(conn);
        for value in &backup.book_sources {
            if let Ok(source) = serde_json::from_value::<BookSource>(value.clone()) {
                match source_repo.insert(&source) {
                    Ok(()) => stats.book_sources += 1,
                    Err(e) => {
                        log::warn!("恢复书源失败（已跳过）: {} - {e}", source.book_source_url)
                    }
                }
            }
        }

        // 恢复 RSS 源
        for (index, value) in backup.rss_sources.iter().enumerate() {
            match serde_json::from_value::<RssSource>(value.clone()) {
                Ok(source) => match insert_rss_source(conn, &source) {
                    Ok(()) => stats.rss_sources += 1,
                    Err(e) => {
                        log::warn!("恢复 RSS 源第{}项失败（已跳过）: {e}", index + 1)
                    }
                },
                Err(e) => log::warn!("解析 RSS 源第{}项失败（已跳过）: {e}", index + 1),
            }
        }

        // 恢复阅读记录
        let record_repo = ReadRecordRepository::new(conn);
        for value in &backup.read_records {
            if let Ok(record) =
                serde_json::from_value::<legado_core::models::ReadRecord>(value.clone())
            {
                match record_repo.upsert(&record.book_name, record.read_time) {
                    Ok(()) => stats.read_records += 1,
                    Err(e) => {
                        log::warn!("恢复阅读记录失败（已跳过）: {} - {e}", record.book_name)
                    }
                }
            }
        }

        Ok(stats)
    })?;

    Ok(stats)
}

/// 列出备份文件
///
/// 列出目录中的 .json 备份文件，返回 JSON 数组。
pub fn backup_list(dir: &str) -> String {
    serde_json::to_string(&list_backup_files(dir)).unwrap_or_else(|_| "[]".into())
}
pub fn list_backup_files(dir: &str) -> Vec<crate::business_dto::BackupFileDto> {
    let entries = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(_) => return Vec::new(),
    };

    let files: Vec<crate::business_dto::BackupFileDto> = entries
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.path()
                .extension()
                .map(|ext| ext == "json")
                .unwrap_or(false)
        })
        .filter_map(|e| {
            let path = e.path();
            let metadata = e.metadata().ok()?;
            let name = path.file_name()?.to_str()?.to_string();
            let size = metadata.len();
            let modified = metadata
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0);
            Some(crate::business_dto::BackupFileDto {
                name,
                path: path.to_str().unwrap_or_default().to_owned(),
                size,
                modified,
            })
        })
        .collect();

    files
}

/// 导入旧版（阅读 2.x）备份目录
///
/// 对齐 `ImportOldData.importUri`：扫描 `myBookShelf.json` / `myBookSource.json` /
/// `myBookReplaceRule.json`，字段映射后写入 DB。缺文件不致命，记入 messages。
pub fn import_old_data(dir: &str) -> LegadoResult<String> {
    let dir_path = Path::new(dir);
    if !dir_path.is_dir() {
        return Err(LegadoError::Io(std::io::Error::other(format!(
            "目录不存在或不可用: {dir}"
        ))));
    }

    let mut messages: Vec<String> = Vec::new();
    let mut books_n = 0usize;
    let mut sources_n = 0usize;
    let mut rules_n = 0usize;

    // 书架
    let shelf_path = dir_path.join("myBookShelf.json");
    if shelf_path.is_file() {
        match fs::read_to_string(&shelf_path) {
            Ok(json) => match with_database(|db| {
                let conn = db.connection();
                let book_repo = BookRepository::new(conn);
                let existing: std::collections::HashSet<String> = book_repo
                    .find_all()?
                    .into_iter()
                    .map(|b| b.book_url)
                    .collect();
                let books = legado_core::import_old::from_old_books(&json, &existing);
                let mut n = 0usize;
                for book in &books {
                    match book_repo.insert(book) {
                        Ok(()) => n += 1,
                        Err(e) => log::warn!("导入旧版书籍失败（已跳过）: {} - {e}", book.book_url),
                    }
                }
                Ok(n)
            }) {
                Ok(n) => {
                    books_n = n;
                    messages.push(format!("成功导入书架{n}"));
                }
                Err(e) => messages.push(format!("导入书架失败: {e}")),
            },
            Err(e) => messages.push(format!("导入书架失败: {e}")),
        }
    } else {
        messages.push("未找到 myBookShelf.json".to_string());
    }

    // 书源
    let source_path = dir_path.join("myBookSource.json");
    if source_path.is_file() {
        match fs::read_to_string(&source_path) {
            Ok(json) => match with_database(|db| {
                let conn = db.connection();
                let source_repo = BookSourceRepository::new(conn);
                let sources = legado_core::import_old::from_old_book_sources(&json);
                let mut n = 0usize;
                for source in &sources {
                    match source_repo.insert(source) {
                        Ok(()) => n += 1,
                        Err(e) => log::warn!(
                            "导入旧版书源失败（已跳过）: {} - {e}",
                            source.book_source_url
                        ),
                    }
                }
                Ok(n)
            }) {
                Ok(n) => {
                    sources_n = n;
                    messages.push(format!("成功导入书源{n}"));
                }
                Err(e) => messages.push(format!("导入源失败: {e}")),
            },
            Err(e) => messages.push(format!("导入源失败: {e}")),
        }
    } else {
        messages.push("未找到 myBookSource.json".to_string());
    }

    // 替换规则
    let rule_path = dir_path.join("myBookReplaceRule.json");
    if rule_path.is_file() {
        match fs::read_to_string(&rule_path) {
            Ok(json) => match with_database(|db| {
                let conn = db.connection();
                let rule_repo = ReplaceRuleRepository::new(conn);
                let rules = legado_core::import_old::from_old_replace_rules(&json);
                let mut n = 0usize;
                for rule in &rules {
                    match rule_repo.insert(rule) {
                        Ok(_) => n += 1,
                        Err(e) => log::warn!("导入旧版替换规则失败（已跳过）: {} - {e}", rule.name),
                    }
                }
                Ok(n)
            }) {
                Ok(n) => {
                    rules_n = n;
                    messages.push(format!("成功导入替换规则{n}"));
                }
                Err(e) => messages.push(format!("导入替换规则失败: {e}")),
            },
            Err(e) => messages.push(format!("导入替换规则失败: {e}")),
        }
    } else {
        messages.push("未找到替换规则".to_string());
    }

    let result = serde_json::json!({
        "books": books_n,
        "bookSources": sources_n,
        "replaceRules": rules_n,
        "messages": messages,
    });
    serde_json::to_string(&result)
        .map_err(|e| LegadoError::Internal(format!("统计序列化失败: {e}")))
}

/// 导出完整实体；空 Cookie 标志显式保留，避免缺省值改变语义。
fn collect_rss_sources(conn: &rusqlite::Connection) -> LegadoResult<Vec<serde_json::Value>> {
    RssSourceRepository::new(conn)
        .find_all()
        .map_err(LegadoError::Database)?
        .into_iter()
        .map(|source| {
            let mut value = serde_json::to_value(&source)?;
            if source.enabled_cookie_jar.is_none() {
                value["enabledCookieJar"] = serde_json::Value::Null;
            }
            Ok(value)
        })
        .collect()
}

/// 与普通 RSS 写入共用完整字段映射。
fn insert_rss_source(conn: &rusqlite::Connection, source: &RssSource) -> LegadoResult<()> {
    RssSourceRepository::new(conn)
        .insert(source)
        .map(|_| ())
        .map_err(LegadoError::Database)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rss_fixture() -> RssSource {
        serde_json::from_str(r#"{
            "sourceUrl":"https://backup.test/rss", "sourceName":"完整源😀", "sourceIcon":"icon",
            "sourceGroup":"group", "sourceComment":"comment", "enabled":true,
            "variableComment":"variable", "jsLib":"var x=1;", "enabledCookieJar":true,
            "concurrentRate":"1000", "header":"{\"X-Test\":\"value\"}",
            "loginUrl":"login()", "loginUi":"[]", "loginCheckJs":"result", "coverDecodeJs":"result",
            "sortUrl":"sort", "singleUrl":true, "articleStyle":4,
            "ruleArticles":"article", "ruleNextPage":"next", "ruleTitle":"title", "rulePubDate":"date",
            "ruleDescription":"description", "ruleImage":"image", "ruleLink":"link", "ruleContent":"content",
            "contentWhitelist":"allow", "contentBlacklist":"deny", "shouldOverrideUrlLoading":"override",
            "style":"css", "enableJs":false, "loadWithBaseUrl":false, "injectJs":"inject",
            "preloadJs":"preload", "startHtml":"html", "startStyle":"style", "startJs":"script",
            "showWebLog":true, "lastUpdateTime":9007199254740993, "customOrder":7,
            "type":2, "preload":true, "cacheFirst":true, "searchUrl":"search"
        }"#).unwrap()
    }

    #[test]
    fn rss_backup_serializes_entity_booleans_and_keeps_nullable_cookie_flag() {
        let db = legado_db::init_in_memory_database().unwrap();
        let repo = legado_db::RssSourceRepository::new(db.connection());
        let mut source = rss_fixture();
        for flag in [Some(true), Some(false), None] {
            source.enabled_cookie_jar = flag;
            repo.insert(&source).unwrap();
            let rows = collect_rss_sources(db.connection()).unwrap();
            let mut expected = serde_json::to_value(&source).unwrap();
            expected["enabledCookieJar"] = serde_json::to_value(flag).unwrap();
            assert_eq!(rows, vec![expected]);
            let restored: RssSource = serde_json::from_value(rows[0].clone()).unwrap();
            assert_eq!(restored.enabled_cookie_jar, flag);
        }
    }

    #[test]
    fn rss_backup_rejects_unreadable_rows_instead_of_dropping_sources() {
        let db = legado_db::init_in_memory_database().unwrap();
        RssSourceRepository::new(db.connection())
            .insert(&rss_fixture())
            .unwrap();
        db.connection()
            .execute("UPDATE rssSources SET articleStyle = 'invalid'", [])
            .unwrap();
        assert!(collect_rss_sources(db.connection()).is_err());
    }

    #[test]
    fn rss_restore_to_empty_database_preserves_all_entity_fields() {
        let db = legado_db::init_in_memory_database().unwrap();
        let source = rss_fixture();
        insert_rss_source(db.connection(), &source).unwrap();
        let rows = legado_db::RssSourceRepository::new(db.connection())
            .find_all()
            .unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(
            serde_json::to_value(&rows[0]).unwrap(),
            serde_json::to_value(&source).unwrap()
        );
    }

    #[test]
    fn test_backup_create_and_restore() {
        let _db_guard = crate::db_state::ensure_test_db();

        let dir = std::env::temp_dir().join("legado_backup_test");
        let _ = fs::create_dir_all(&dir);
        let backup_path = dir.join("test_backup.json");
        let path_str = backup_path.to_str().unwrap();

        // 创建备份
        let result = backup_create(path_str);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), path_str);

        // 验证文件存在
        assert!(backup_path.exists());

        // 验证 JSON 格式
        let content = fs::read_to_string(&backup_path).unwrap();
        let data: BackupData = serde_json::from_str(&content).unwrap();
        assert_eq!(data.version, 1);
        assert!(data.backup_time > 0);

        // 恢复备份
        let restore_result = backup_restore(path_str);
        assert!(restore_result.is_ok());

        // 清理
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_backup_list() {
        let dir = std::env::temp_dir().join("legado_backup_list_test");
        let _ = fs::create_dir_all(&dir);

        // 创建测试文件
        let file1 = dir.join("backup1.json");
        let file2 = dir.join("backup2.json");
        let file3 = dir.join("not_backup.txt");
        fs::write(&file1, "{}").unwrap();
        fs::write(&file2, "{}").unwrap();
        fs::write(&file3, "text").unwrap();

        let result = backup_list(dir.to_str().unwrap());
        let list: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert_eq!(list.len(), 2);

        // 清理
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_backup_list_nonexistent_dir() {
        let result = backup_list("/nonexistent/path/that/does/not/exist");
        assert_eq!(result, "[]");
    }
}
