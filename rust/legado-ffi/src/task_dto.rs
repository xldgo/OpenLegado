//! 下载快照及交互事件；业务任务身份与订阅生命周期分开。— Codex + Bridge

#[derive(Debug, Clone, Copy)]
pub enum CacheDownloadStatusDto {
    Running,
    Completed,
    Cancelled,
    Failed,
    NotFound,
}
#[derive(Debug, Clone)]
pub struct CacheDownloadTaskDto {
    pub task_id: u64,
    pub book_url: String,
    pub status: CacheDownloadStatusDto,
    pub total: i32,
    pub completed: i32,
    pub failed: i32,
}
impl TryFrom<legado_engine::CacheDownloadTask> for CacheDownloadTaskDto {
    type Error = legado_core::LegadoError;
    fn try_from(v: legado_engine::CacheDownloadTask) -> Result<Self, Self::Error> {
        let status = match v.status.as_str() {
            "running" => CacheDownloadStatusDto::Running,
            "completed" => CacheDownloadStatusDto::Completed,
            "cancelled" => CacheDownloadStatusDto::Cancelled,
            "failed" => CacheDownloadStatusDto::Failed,
            "notFound" => CacheDownloadStatusDto::NotFound,
            other => {
                return Err(legado_core::LegadoError::Ffi(format!(
                    "未知下载状态：{other}"
                )));
            }
        };
        Ok(Self {
            task_id: v.task_id,
            book_url: v.book_url,
            status,
            total: v.total,
            completed: v.completed,
            failed: v.failed,
        })
    }
}
#[derive(Debug, Clone, Copy)]
pub enum DownloadStatusDto {
    Pending,
    Downloading,
    Completed,
    Failed,
    Paused,
}
#[derive(Debug, Clone)]
pub struct DownloadTaskDto {
    pub id: String,
    pub book_url: String,
    pub chapter_url: String,
    pub chapter_title: String,
    pub chapter_index: i32,
    pub status: DownloadStatusDto,
    pub progress: f64,
    pub priority: i32,
    pub created_at: i64,
    pub completed_at: Option<i64>,
    pub error: Option<String>,
    pub fail_count: u32,
    pub downloaded_bytes: i64,
    pub max_retry_count: u32,
}
impl From<&legado_core::models::DownloadTask> for DownloadTaskDto {
    fn from(v: &legado_core::models::DownloadTask) -> Self {
        use legado_core::models::DownloadStatus;
        let status = match &v.status {
            DownloadStatus::Pending => DownloadStatusDto::Pending,
            DownloadStatus::Downloading => DownloadStatusDto::Downloading,
            DownloadStatus::Completed => DownloadStatusDto::Completed,
            DownloadStatus::Failed(_) => DownloadStatusDto::Failed,
            DownloadStatus::Paused => DownloadStatusDto::Paused,
        };
        Self {
            id: v.id.clone(),
            book_url: v.book_url.clone(),
            chapter_url: v.chapter_url.clone(),
            chapter_title: v.chapter_title.clone(),
            chapter_index: v.chapter_index,
            status,
            progress: v.progress,
            priority: v.priority,
            created_at: v.created_at,
            completed_at: v.completed_at,
            error: v.error.clone(),
            fail_count: v.fail_count,
            downloaded_bytes: v.downloaded_bytes,
            max_retry_count: v.max_retry_count,
        }
    }
}
#[derive(Debug, Clone)]
pub struct DownloadStatsDto {
    pub total: usize,
    pub pending: usize,
    pub downloading: usize,
    pub completed: usize,
    pub failed: usize,
    pub paused: bool,
}
impl From<legado_core::download_manager::DownloadStats> for DownloadStatsDto {
    fn from(v: legado_core::download_manager::DownloadStats) -> Self {
        Self {
            total: v.total,
            pending: v.pending,
            downloading: v.downloading,
            completed: v.completed,
            failed: v.failed,
            paused: v.paused,
        }
    }
}
#[derive(Debug, Clone)]
pub struct DebugLogDto {
    pub state: i32,
    pub msg: String,
}
impl From<crate::api::source_debug_api::DebugLogItem> for DebugLogDto {
    fn from(v: crate::api::source_debug_api::DebugLogItem) -> Self {
        Self {
            state: v.state,
            msg: v.msg,
        }
    }
}
#[derive(Debug, Clone)]
pub struct VerificationRequestDto {
    pub key: String,
    pub source_url: String,
    pub source_name: String,
    pub image_url: String,
    pub title: String,
    pub use_browser: bool,
    pub created_at_ms: u64,
}
impl From<legado_core::verification_channel::VerificationRequest> for VerificationRequestDto {
    fn from(v: legado_core::verification_channel::VerificationRequest) -> Self {
        Self {
            key: v.key,
            source_url: v.source_url,
            source_name: v.source_name,
            image_url: v.image_url,
            title: v.title,
            use_browser: v.use_browser,
            created_at_ms: v.created_at_ms,
        }
    }
}
#[derive(Debug, Clone)]
pub struct WebViewRequestDto {
    pub key: String,
    pub action: String,
    pub html: String,
    pub url: String,
    pub js: String,
    pub source_regex: String,
    pub override_url_regex: String,
    pub cache_first: bool,
    pub delay_time: i64,
    pub is_rule: bool,
    pub result: String,
    pub source_key: String,
    pub cookie: String,
    pub created_at_ms: u64,
    pub headers: std::collections::HashMap<String, String>,
}
impl From<legado_core::webview_channel::WebViewRequest> for WebViewRequestDto {
    fn from(v: legado_core::webview_channel::WebViewRequest) -> Self {
        Self {
            headers: v.headers,
            key: v.key,
            action: v.action,
            html: v.html,
            url: v.url,
            js: v.js,
            source_regex: v.source_regex,
            override_url_regex: v.override_url_regex,
            cache_first: v.cache_first,
            delay_time: v.delay_time,
            is_rule: v.is_rule,
            result: v.result,
            source_key: v.source_key,
            cookie: v.cookie,
            created_at_ms: v.created_at_ms,
        }
    }
}

/// 平台结果信封；错误与正常空结果分开。— Codex + Bridge
#[derive(Debug, Clone)]
pub struct WebViewResponseDto {
    pub result: String,
    pub final_url: String,
    pub error: Option<String>,
    pub cookies: std::collections::HashMap<String, String>,
}
