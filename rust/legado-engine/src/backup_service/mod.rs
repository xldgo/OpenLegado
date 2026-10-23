//! 备份应用服务：文件及事务恢复使用所属实例的存储。
//!
//! 提供数据库备份创建、恢复和备份文件列表功能。
//! 备份格式为 JSON，包含 books/bookmarks/replaceRules/bookSources/rssSources/readRecords。

use std::fs;
use std::path::Path;

use serde::Serialize;

use legado_core::{LegadoError, LegadoResult};
use legado_db::repository::Repository;
use legado_db::{BookRepository, BookSourceRepository, ReplaceRuleRepository};

use crate::StorageContext;

mod crypto;
mod package;
mod restore;
mod upstream;

pub use legado_db::backup::BackupData;

#[derive(Default)]
pub struct BackupOptions {
    pub preferences: serde_json::Map<String, serde_json::Value>,
    pub files: std::collections::BTreeMap<String, String>,
    pub sensitive: serde_json::Map<String, serde_json::Value>,
    pub password: Option<String>,
}
#[derive(Default)]
pub struct RestoreOptions {
    pub password: Option<String>,
    pub ignore: std::collections::BTreeSet<String>,
}
pub struct BackupRestoreResult {
    pub stats: RestoreStats,
    pub preferences: serde_json::Map<String, serde_json::Value>,
    pub sensitive: serde_json::Map<String, serde_json::Value>,
    pub warnings: Vec<String>,
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
    pub additional: std::collections::HashMap<String, usize>,
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
    rates: Option<std::sync::Arc<legado_fetcher::rate_limit::RateLimiterRegistry>>,
}
impl BackupService {
    pub fn new(storage: Option<StorageContext>) -> Self {
        Self {
            storage,
            rates: None,
        }
    }
    pub fn with_rate_limiter(
        mut self,
        rates: std::sync::Arc<legado_fetcher::rate_limit::RateLimiterRegistry>,
    ) -> Self {
        self.rates = Some(rates);
        self
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
    pub fn backup_create(&self, path: &str, options: &BackupOptions) -> LegadoResult<String> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;

        let backup_data = self.with_database(|db| {
            legado_db::backup::BackupRepository::new(db.connection()).export(now)
        })?;

        let bytes = package::encode(&backup_data, options)?;
        package::write_atomic(path, &bytes)?;

        Ok(path.to_string())
    }

    pub fn restore_backup(
        &self,
        path: &str,
        options: &RestoreOptions,
    ) -> LegadoResult<BackupRestoreResult> {
        restore::restore(self, path, options)
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
                    .map(|ext| ext == "zip")
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

#[cfg(test)]
mod tests;
