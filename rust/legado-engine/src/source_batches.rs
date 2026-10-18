//! 普通搜索与换源共用的有界批次调度；不依赖FFI或宿主槽位。
use crate::{SearchSession, TaskHandle};
use futures::StreamExt;
use legado_core::{LegadoError, LegadoResult, models::BookSource};
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};
use std::time::Duration;

#[cfg(test)]
mod tests;

/// 换源单源超时保持60秒。
pub const SWITCH_SOURCE_TIMEOUT: Duration = Duration::from_secs(60);

pub struct SourceBatchOutcome<T> {
    /// 书源在请求列表中的索引
    pub index: usize,
    pub source_url: String,
    pub source_name: String,
    /// 该源搜索结果（失败/超时/panic 均为 Err，不阻断其他源）
    pub result: LegadoResult<Vec<T>>,
    pub finished_count: usize,
    pub total_count: usize,
    pub is_last: bool,
}

/// 驱动一批书源搜索：受控在飞任务、单源超时、取消/暂停会话级门控。
///
/// - **隔离**：单源失败/panic 不影响其他源（各自 catch_unwind）。
/// - **并发（P0-3 复审 7.2）**：`sources` 作为待派发队列，任意时刻最多 `concurrency` 个在飞任务；
///   每有一个完成才派发下一个。不再「每源一个 tokio::spawn + semaphore 排队」——那会让大书源包
///   预创建与源数等量的排队任务，且取消时丢弃 FuturesUnordered 只是分离（detach）而非中止它们。
/// - **取消 / sink 关闭 / 会话替换**：显式 abort_all 并 drain 已启动 handle，确保在飞任务被终止、
///   其结果绝不进入流 / 状态 / 落库。
/// - **暂停**：门控发生在派发下一个源之前（调度层），未请求源不占用任何并发许可；已派发任务继续
///   完成（软挂起，对齐原版 SearchModel workingState 调度前门控）。
/// - **超时**：单源搜索超过 `per_source_timeout` 判为超时错误。
///
/// 换源旧入口仍使用显式布尔能力；正式搜索使用可通知的登记任务能力。
pub trait BatchCancellation: Sync {
    fn is_cancelled(&self) -> bool;
    fn cancel(&self);
    fn cancelled(&self) -> impl std::future::Future<Output = ()> + Send;
}

impl BatchCancellation for Arc<AtomicBool> {
    fn is_cancelled(&self) -> bool {
        self.load(Ordering::SeqCst)
    }
    fn cancel(&self) {
        self.store(true, Ordering::SeqCst);
    }
    async fn cancelled(&self) {
        while !self.is_cancelled() {
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    }
}

impl BatchCancellation for SearchSession {
    fn is_cancelled(&self) -> bool {
        self.is_cancelled()
    }
    fn cancel(&self) {
        self.cancel();
    }
    async fn cancelled(&self) {
        self.task().cancelled().await;
    }
}

impl BatchCancellation for TaskHandle {
    fn is_cancelled(&self) -> bool {
        self.is_cancelled()
    }
    fn cancel(&self) {
        self.cancel();
    }
    async fn cancelled(&self) {
        self.cancelled().await;
    }
}

/// 收集 future 本身被丢弃时也取消已派发源；阻塞工作由独立克隆凭据登记至退出。
struct AbortSources(Vec<tokio::task::AbortHandle>);
impl Drop for AbortSources {
    fn drop(&mut self) {
        for handle in &self.0 {
            handle.abort();
        }
    }
}

pub async fn drive_source_batches<F, Fut, T, G, C>(
    sources: Vec<BookSource>,
    concurrency: usize,
    per_source_timeout: Duration,
    cancel: &C,
    paused: &Arc<AtomicBool>,
    search_one: F,
    mut on_source: G,
) where
    F: Fn(BookSource) -> Fut + Send + Sync + 'static,
    Fut: std::future::Future<Output = LegadoResult<Vec<T>>> + Send + 'static,
    T: Send + 'static,
    G: FnMut(SourceBatchOutcome<T>) -> Result<(), String>,
    C: BatchCancellation + ?Sized,
{
    use futures::FutureExt;
    use std::panic::AssertUnwindSafe;

    let total = sources.len();
    if total == 0 {
        return;
    }

    // 待派发队列（index, source）；在飞任务数 ≤ concurrency
    let mut queue: std::collections::VecDeque<(usize, BookSource)> =
        sources.into_iter().enumerate().collect();
    let mut set = futures::stream::FuturesUnordered::new();
    // 保留每个在飞任务的 AbortHandle，取消 / sink 关闭时显式 abort_all + drain
    let mut aborts = AbortSources(Vec::new());

    let search_one = Arc::new(search_one);
    let concurrency = concurrency.max(1);

    let mut finished: usize = 0;
    'collect: loop {
        // 派发至多 concurrency 个在飞任务；暂停门控在派发前（不占许可）
        while set.len() < concurrency && !queue.is_empty() {
            if cancel.is_cancelled() {
                break 'collect;
            }
            if paused.load(Ordering::SeqCst) {
                // 调度层等待恢复或取消（未持有并发许可，对齐原版 workingState 门控位置）
                loop {
                    if cancel.is_cancelled() || !paused.load(Ordering::SeqCst) {
                        break;
                    }
                    tokio::select! {
                        _ = cancel.cancelled() => break,
                        _ = tokio::time::sleep(Duration::from_millis(50)) => {},
                    }
                }
                if cancel.is_cancelled() {
                    break 'collect;
                }
            }

            let (index, source) = queue.pop_front().unwrap();
            let search_one = Arc::clone(&search_one);
            let handle = tokio::spawn(async move {
                let source_url = source.book_source_url.clone();
                let source_name = source.book_source_name.clone();

                let outcome = tokio::time::timeout(
                    per_source_timeout,
                    // 创建 Future 也可能执行用户代码，必须与后续轮询一起进入捕获范围。
                    AssertUnwindSafe(async move { search_one(source).await }).catch_unwind(),
                )
                .await;

                let result = match outcome {
                    Ok(Ok(r)) => r,
                    Ok(Err(payload)) => {
                        let reason = payload
                            .downcast_ref::<String>()
                            .map(String::as_str)
                            .or_else(|| payload.downcast_ref::<&str>().copied())
                            .unwrap_or("非文本 panic");
                        Err(LegadoError::Network(format!(
                            "单源搜索崩溃: {reason}（已隔离，不影响其他源）"
                        )))
                    }
                    Err(_elapsed) => Err(LegadoError::Network(format!(
                        "搜索超时（{}s）",
                        per_source_timeout.as_secs()
                    ))),
                };

                (index, source_url, source_name, result)
            });
            aborts.0.push(handle.abort_handle());
            set.push(handle);
        }

        if set.is_empty() {
            break 'collect;
        }

        // 按完成顺序取下一个结果；与取消竞争 —— 取消置位后立即唤醒并 abort 在飞任务，
        // 不再等待最快下一个自然完成（否则在飞请求最长可能持续至单源超时）。
        let joined = tokio::select! {
            j = set.next() => match j {
                Some(j) => j,
                None => break 'collect,
            },
            _ = cancel.cancelled() => break 'collect,
        };
        // P0-3 复审 7.2：取消 / sink 关闭后不再把在飞结果交付 on_source（防旧会话残留）
        if cancel.is_cancelled() {
            break 'collect;
        }
        finished += 1;
        let (index, source_url, source_name, result) = match joined {
            Ok(v) => v,
            Err(e) => (
                0,
                String::new(),
                String::new(),
                Err(LegadoError::Network(format!("搜索任务异常: {e}"))),
            ),
        };

        let outcome = SourceBatchOutcome {
            index,
            source_url,
            source_name,
            result,
            finished_count: finished,
            total_count: total,
            is_last: finished >= total,
        };

        if on_source(outcome).is_err() {
            // sink 关闭 → 置位会话取消，停止收集（下方统一 abort_all + drain）
            cancel.cancel();
            break 'collect;
        }
    }

    // 取消 / sink 关闭 / 正常结束：显式 abort_all + drain 已启动 handle（P0-3 复审 7.2）
    for ah in &aborts.0 {
        ah.abort();
    }
    while set.next().await.is_some() {
        // drain：丢弃剩余在飞任务的结果，绝不进入流 / 状态 / 落库
    }
}
