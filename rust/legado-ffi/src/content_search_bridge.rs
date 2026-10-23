//! 正文搜索仅桥接任务和批次，业务读取/匹配在Engine。— Codex + Bridge
use crate::{
    ffi::{BridgeError, StreamRequest},
    frb_generated::StreamSink,
};
use legado_engine::reading_service::{ContentSearchOptions, ContentSearchScope};

pub enum ContentSearchScopeDto {
    Current,
    Cached,
    Network,
}
pub struct ContentSearchHitDto {
    pub source_start: usize,
    pub source_end: usize,
    pub snippet: String,
    pub highlight_start: usize,
    pub highlight_end: usize,
}
pub struct ContentSearchBatchDto {
    pub chapter_index: Option<i32>,
    pub chapter_title: String,
    pub hits: Vec<ContentSearchHitDto>,
    pub scanned: usize,
    pub total: usize,
    pub error: Option<String>,
    pub limit_reached: bool,
}
pub struct ContentSearchOptionsDto {
    pub book_url: String,
    pub query: String,
    pub use_regex: bool,
    pub use_replace: bool,
    pub scope: ContentSearchScopeDto,
    pub current_chapter_index: i32,
}
pub async fn content_search(
    options: ContentSearchOptionsDto,
    request: &StreamRequest,
    sink: StreamSink<ContentSearchBatchDto>,
) -> Result<(), BridgeError> {
    let service = crate::api::reader::host_service();
    let task = service.begin_content_search()?;
    let _guard = task.guard();
    let worker_task = task.clone();
    let options = ContentSearchOptions {
        book_url: options.book_url,
        query: options.query,
        use_regex: options.use_regex,
        use_replace: options.use_replace,
        current_chapter_index: options.current_chapter_index,
        scope: match options.scope {
            ContentSearchScopeDto::Current => ContentSearchScope::Current,
            ContentSearchScopeDto::Cached => ContentSearchScope::Cached,
            ContentSearchScopeDto::Network => ContentSearchScope::Network,
        },
    };
    let mut worker = tokio::task::spawn_blocking(move || {
        service.search_content(options, &worker_task, |batch| {
            sink.add(ContentSearchBatchDto {
                chapter_index: batch.chapter_index,
                chapter_title: batch.chapter_title,
                scanned: batch.scanned,
                total: batch.total,
                error: batch.error,
                limit_reached: batch.limit_reached,
                hits: batch
                    .hits
                    .into_iter()
                    .map(|h| ContentSearchHitDto {
                        source_start: h.source_start,
                        source_end: h.source_end,
                        snippet: h.snippet,
                        highlight_start: h.highlight_start,
                        highlight_end: h.highlight_end,
                    })
                    .collect(),
            })
            .is_ok()
        })
    });
    let result = tokio::select! { biased;
        _ = request.wait_cancelled() => {
            task.cancel();
            worker.await
        },
        result = &mut worker => result,
    };
    result.map_err(|e| BridgeError {
        message: format!("正文搜索任务异常: {e}"),
    })??;
    Ok(())
}
