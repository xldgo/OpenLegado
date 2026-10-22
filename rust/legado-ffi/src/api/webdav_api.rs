//! WebDAV宿主适配：配置文档、能力装配与同步结果包装。
use legado_core::LegadoResult;
use legado_engine::webdav_service::WebDavService;
use legado_net::webdav::WebDavConfig;
fn webdav_runtime_handle() -> LegadoResult<tokio::runtime::Handle> {
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        return Ok(handle);
    }
    // 不能只返回临时 Runtime 的 Handle：Runtime 随函数返回销毁后，IO 驱动也已关闭。
    Ok(crate::runtime::get_runtime().handle().clone())
}
fn host_service() -> LegadoResult<WebDavService> {
    let hosts = crate::engine_holder::network().custom_hosts().clone();
    Ok(WebDavService::new(hosts, webdav_runtime_handle()?))
}
/// 同步结果统计
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SyncResult {
    pub uploaded_count: usize,
    pub downloaded_count: usize,
    pub skipped_count: usize,
    pub conflict_count: usize,
    pub errors: Vec<String>,
    pub duration_ms: u64,
}

/// 冲突解决策略
#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub enum ConflictResolution {
    /// 保留远端版本
    KeepRemote,
    /// 使用本地版本
    UseLocal,
    /// 合并两份内容
    Merge,
    /// 用户手动选择
    Manual,
}

/// 同步选项
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SyncOptions {
    pub max_concurrent_uploads: usize,
    pub chunk_size_bytes: usize,
    pub max_retry_attempts: u32,
    pub initial_retry_delay_ms: u64,
    pub max_retry_delay_ms: u64,
}

pub fn webdav_probe(config_json: &str) -> LegadoResult<legado_net::webdav::WebDavProbeResult> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    Ok(host_service()?.webdav_probe(config))
}

pub fn webdav_list_dir(
    config_json: &str,
    path: &str,
) -> LegadoResult<Vec<legado_net::webdav::WebDavFileInfo>> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_list_dir(config, path)
}

pub fn webdav_upload(config_json: &str, path: &str, data: &str) -> LegadoResult<()> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_upload(config, path, data)
}

pub fn webdav_upload_file(
    config_json: &str,
    path: &str,
    local_file_path: &str,
) -> LegadoResult<()> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_upload_file(config, path, local_file_path)
}

pub fn webdav_download(config_json: &str, path: &str) -> LegadoResult<String> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_download(config, path)
}

pub fn webdav_download_file(
    config_json: &str,
    path: &str,
    local_file_path: &str,
) -> LegadoResult<()> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_download_file(config, path, local_file_path)
}

pub fn webdav_delete(config_json: &str, path: &str) -> LegadoResult<()> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_delete(config, path)
}

pub fn webdav_mkdir(config_json: &str, path: &str) -> LegadoResult<()> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_mkdir(config, path)
}

pub fn webdav_full_sync(
    config_json: &str,
    local_books_json: &str,
    local_sources_json: &str,
) -> LegadoResult<(String, String)> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败: {e}")))?;
    host_service()?.webdav_full_sync(config, local_books_json, local_sources_json)
}

pub fn webdav_incremental_sync(
    config_json: &str,
    local_books_json: &str,
    local_sources_json: &str,
    last_sync_time: Option<i64>,
) -> LegadoResult<String> {
    let config: WebDavConfig = serde_json::from_str(config_json)
        .map_err(|e| legado_core::LegadoError::Internal(format!("WebDAV 配置解析失败：{e}")))?;
    let (books, sources, sync_result) = host_service()?.webdav_incremental_sync(
        config,
        local_books_json,
        local_sources_json,
        last_sync_time,
    )?;
    serde_json::to_string(&serde_json::json!({
        "books": books,
        "sources": sources,
        "result": {
            "uploaded_count": sync_result.uploaded_count,
            "downloaded_count": sync_result.downloaded_count,
            "skipped_count": sync_result.skipped_count,
            "conflict_count": sync_result.conflict_count,
            "errors": sync_result.errors,
            "duration_ms": sync_result.duration_ms,
        },
    }))
    .map_err(|e| legado_core::LegadoError::Internal(format!("序列化失败：{e}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fallback_runtime_keeps_its_driver_alive_after_handle_return() {
        let handle = webdav_runtime_handle().unwrap();
        handle.block_on(async {
            tokio::time::sleep(std::time::Duration::from_millis(1)).await;
        });
    }

    /// Task #51：配置解析失败 → Internal 错误
    #[test]
    fn test_webdav_upload_file_bad_config() {
        let err = webdav_upload_file("{invalid json", "/remote/book.epub", "C:/tmp/x.epub")
            .expect_err("非法配置应报错");
        assert!(
            matches!(err, legado_core::LegadoError::Internal(_)),
            "配置解析失败应为 Internal 错误，实际: {err:?}"
        );
    }

    /// Task #51：本地文件不存在 → Io 错误
    #[test]
    fn test_webdav_upload_file_missing_file() {
        let config_json = serde_json::json!({
            "url": "https://dav.example.com",
            "username": "user",
            "password": "pass",
            "remote_dir": "/legado",
        })
        .to_string();
        let err = webdav_upload_file(
            &config_json,
            "/remote/book.epub",
            "__definitely_missing_file__.bin",
        )
        .expect_err("文件不存在应报错");
        assert!(
            matches!(err, legado_core::LegadoError::Io(_)),
            "文件不存在应为 Io 错误，实际: {err:?}"
        );
    }
}
