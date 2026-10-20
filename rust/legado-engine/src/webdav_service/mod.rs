//! WebDAV应用服务：显式Hosts与宿主Handle，协议和同步算法复用Net。
use legado_core::LegadoResult;
use legado_net::{
    custom_hosts::CustomHosts,
    webdav::{BookSyncManager, SyncResult, WebDavClient, WebDavConfig, WebDavFileInfo},
};
use std::sync::Arc;
pub struct WebDavService {
    hosts: Arc<CustomHosts>,
    runtime: tokio::runtime::Handle,
}
impl WebDavService {
    pub fn new(hosts: Arc<CustomHosts>, runtime: tokio::runtime::Handle) -> Self {
        Self { hosts, runtime }
    }
    fn client(&self, config: WebDavConfig) -> WebDavClient {
        WebDavClient::with_custom_hosts(config, self.hosts.clone())
    }
    pub fn webdav_list_dir(
        &self,
        config: WebDavConfig,
        path: &str,
    ) -> LegadoResult<Vec<WebDavFileInfo>> {
        let client = self.client(config);

        let rt = &self.runtime;
        rt.block_on(client.list_dir(path))
    }

    pub fn webdav_upload(&self, config: WebDavConfig, path: &str, data: &str) -> LegadoResult<()> {
        let client = self.client(config);

        let rt = &self.runtime;
        rt.block_on(client.put(path, data.as_bytes()))
    }

    pub fn webdav_upload_file(
        &self,
        config: WebDavConfig,
        path: &str,
        local_file_path: &str,
    ) -> LegadoResult<()> {
        // 本地文件读取（不存在/无权限/读失败 → Io 错误）
        let bytes = std::fs::read(local_file_path).map_err(|e| {
            legado_core::LegadoError::Io(std::io::Error::new(
                e.kind(),
                format!("读取本地文件失败: {local_file_path}: {e}"),
            ))
        })?;

        let client = self.client(config);
        let rt = &self.runtime;
        // 所有权直传，避免 put(&bytes) 内部的 to_vec 二次拷贝（Task #55 F3）
        rt.block_on(client.put_owned(path, bytes))
    }

    pub fn webdav_download(&self, config: WebDavConfig, path: &str) -> LegadoResult<String> {
        let client = self.client(config);

        let rt = &self.runtime;
        let bytes = rt.block_on(client.get(path))?;
        String::from_utf8(bytes)
            .map_err(|e| legado_core::LegadoError::Internal(format!("Invalid UTF-8: {e}")))
    }

    pub fn webdav_download_file(
        &self,
        config: WebDavConfig,
        path: &str,
        local_file_path: &str,
    ) -> LegadoResult<()> {
        let client = self.client(config);

        let rt = &self.runtime;
        let bytes = rt.block_on(client.get(path))?;

        if let Some(parent) = std::path::Path::new(local_file_path).parent()
            && !parent.as_os_str().is_empty()
        {
            std::fs::create_dir_all(parent).map_err(|e| {
                legado_core::LegadoError::Io(std::io::Error::new(
                    e.kind(),
                    format!("创建父目录失败: {parent:?}: {e}"),
                ))
            })?;
        }
        std::fs::write(local_file_path, bytes).map_err(|e| {
            legado_core::LegadoError::Io(std::io::Error::new(
                e.kind(),
                format!("写入本地文件失败: {local_file_path}: {e}"),
            ))
        })?;
        Ok(())
    }

    pub fn webdav_delete(&self, config: WebDavConfig, path: &str) -> LegadoResult<()> {
        let client = self.client(config);

        let rt = &self.runtime;
        rt.block_on(client.delete(path))
    }

    pub fn webdav_mkdir(&self, config: WebDavConfig, path: &str) -> LegadoResult<()> {
        let client = self.client(config);

        let rt = &self.runtime;
        rt.block_on(client.mkdir(path))
    }

    pub fn webdav_full_sync(
        &self,
        config: WebDavConfig,
        local_books_json: &str,
        local_sources_json: &str,
    ) -> LegadoResult<(String, String)> {
        let client = self.client(config);
        let manager = BookSyncManager::new(client);

        let rt = &self.runtime;
        let (books, sources) =
            rt.block_on(manager.full_sync(local_books_json, local_sources_json))?;

        Ok((books, sources))
    }

    pub fn webdav_incremental_sync(
        &self,
        config: WebDavConfig,
        local_books_json: &str,
        local_sources_json: &str,
        last_sync_time: Option<i64>,
    ) -> LegadoResult<(String, String, SyncResult)> {
        let client = self.client(config);
        let manager = BookSyncManager::new(client);

        let rt = &self.runtime;
        let (books, sources, sync_result) = rt.block_on(manager.incremental_sync(
            local_books_json,
            local_sources_json,
            last_sync_time,
        ))?;

        Ok((books, sources, sync_result))
    }
}

#[cfg(test)]
mod tests;
