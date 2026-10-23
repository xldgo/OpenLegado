//! 备份应用服务：文件及事务恢复使用所属实例的存储。
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

use crate::StorageContext;

mod restore;

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

/// 备份目录条目；FFI在边界映射为传输DTO。
#[derive(Debug, Clone)]
pub struct BackupFile {
    pub name: String,
    pub path: String,
    pub size: u64,
    pub modified: i64,
}
/// 既有旧版导入的应用统计，文档包装由宿主完成。
pub struct OldImportResult {
    pub books: usize,
    pub book_sources: usize,
    pub replace_rules: usize,
    pub messages: Vec<String>,
}
pub struct BackupService {
    storage: Option<StorageContext>,
}
impl BackupService {
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
    pub fn backup_create(&self, path: &str) -> LegadoResult<String> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;

        let backup_data = self.with_database(|db| {
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
        fs::write(path, &json).map_err(|e| {
            LegadoError::Io(std::io::Error::other(format!("写入备份文件失败: {e}")))
        })?;

        Ok(path.to_string())
    }

    pub fn restore_backup(&self, path: &str) -> LegadoResult<RestoreStats> {
        restore::restore(self, path)
    }

    pub fn list_backup_files(&self, dir: &str) -> Vec<BackupFile> {
        let entries = match fs::read_dir(dir) {
            Ok(entries) => entries,
            Err(_) => return Vec::new(),
        };

        let files: Vec<BackupFile> = entries
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
                Some(BackupFile {
                    name,
                    path: path.to_str().unwrap_or_default().to_owned(),
                    size,
                    modified,
                })
            })
            .collect();

        files
    }

    pub fn import_old_data(&self, dir: &str) -> LegadoResult<OldImportResult> {
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
                Ok(json) => match self.with_database(|db| {
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
                            Err(e) => {
                                log::warn!("导入旧版书籍失败（已跳过）: {} - {e}", book.book_url)
                            }
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
                Ok(json) => match self.with_database(|db| {
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
                Ok(json) => match self.with_database(|db| {
                    let conn = db.connection();
                    let rule_repo = ReplaceRuleRepository::new(conn);
                    let rules = legado_core::import_old::from_old_replace_rules(&json);
                    let mut n = 0usize;
                    for rule in &rules {
                        match rule_repo.insert(rule) {
                            Ok(_) => n += 1,
                            Err(e) => {
                                log::warn!("导入旧版替换规则失败（已跳过）: {} - {e}", rule.name)
                            }
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

        Ok(OldImportResult {
            books: books_n,
            book_sources: sources_n,
            replace_rules: rules_n,
            messages,
        })
    }
}

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

fn insert_rss_source(conn: &rusqlite::Connection, source: &RssSource) -> LegadoResult<()> {
    RssSourceRepository::new(conn)
        .insert(source)
        .map(|_| ())
        .map_err(LegadoError::Database)
}

#[cfg(test)]
mod tests;
