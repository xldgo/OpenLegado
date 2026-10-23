//! 备份宿主适配：装配所属存储，保留文档与DTO映射。
use legado_core::LegadoResult;
use legado_engine::backup_service::BackupService;
pub use legado_engine::backup_service::{BackupData, RestoreStats};
fn host_service() -> BackupService {
    match crate::engine_holder::current() {
        Ok(engine) => BackupService::new(Some(engine.storage().clone()))
            .with_rate_limiter(engine.rate_limiter()),
        Err(_) => BackupService::new(None),
    }
}
pub fn backup_create(path: &str) -> LegadoResult<String> {
    host_service().backup_create(path)
}
pub fn backup_restore(path: &str) -> LegadoResult<String> {
    Ok(serde_json::to_string(&restore_backup(path)?)?)
}
pub fn restore_backup(path: &str) -> LegadoResult<RestoreStats> {
    host_service().restore_backup(path)
}
pub fn backup_list(dir: &str) -> String {
    serde_json::to_string(&list_backup_files(dir)).unwrap_or_else(|_| "[]".into())
}
pub fn list_backup_files(dir: &str) -> Vec<crate::business_dto::BackupFileDto> {
    host_service()
        .list_backup_files(dir)
        .into_iter()
        .map(|file| crate::business_dto::BackupFileDto {
            name: file.name,
            path: file.path,
            size: file.size,
            modified: file.modified,
        })
        .collect()
}
pub fn import_old_data(dir: &str) -> LegadoResult<legado_engine::backup_service::OldImportResult> {
    host_service().import_old_data(dir)
}
#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
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
        assert_eq!(data.version, 2);
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
