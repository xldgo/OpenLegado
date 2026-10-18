//! 书源校验服务：有界并发并按输入顺序发布、明确实例资源与取消发布边界。
use crate::{NetworkContext, Operation, OperationSlot, StorageContext, TaskGroup};
use futures::{StreamExt, stream};
use legado_core::{LegadoError, LegadoResult, models::BookSource};
use legado_db::{BookSourceRepository, repository::Repository};
use legado_net::source_checker::{CheckResult, CheckerConfig, SourceChecker};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
pub struct SourceCheckResources {
    pub storage: Option<StorageContext>,
    pub network: Arc<NetworkContext>,
    pub tasks: TaskGroup,
    pub slot: Arc<OperationSlot>,
    pub runtime: tokio::runtime::Handle,
}
pub struct SourceCheckService {
    resources: SourceCheckResources,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckProgress {
    /// 当前书源索引（从 0 开始）
    pub index: usize,
    /// 书源总数
    pub total: usize,
    /// 是否为最后一条
    pub is_last: bool,
    /// 书源名称
    pub source_name: String,
    /// 该书源的校验结果
    pub result: CheckResult,
}

fn create_checker(network: &NetworkContext, config: CheckerConfig) -> LegadoResult<SourceChecker> {
    Ok(SourceChecker::with_config(
        Arc::new(network.client()?),
        config,
    ))
}

pub async fn run_checks_config<F>(
    sources: Vec<Option<BookSource>>,
    config: CheckerConfig,
    operation: &Arc<Operation>,
    network: &NetworkContext,
    concurrency: std::num::NonZeroUsize,
    mut on_result: F,
) where
    F: FnMut(CheckProgress) -> Result<(), String>,
{
    let total = sources.len();
    if total == 0 {
        return;
    }

    let checker = match create_checker(network, config) {
        Ok(c) => c,
        Err(e) => {
            log::error!("书源校验：共享 HTTP 客户端初始化失败: {e}");
            return;
        }
    };

    // 并行检查但保持既有输入索引/最后项协议，取消时直接丢弃全部在途future。
    let checker = &checker;
    let pending = stream::iter(sources.into_iter().enumerate())
        .map(|(index, source)| async move {
            let result = match source.as_ref() {
                Some(src) => checker.check_full(src).await,
                None => CheckResult {
                    source_url: String::new(),
                    search_ok: false,
                    toc_ok: false,
                    content_ok: false,
                    search_error: Some("书源不存在".to_string()),
                    toc_error: Some("skipped".to_string()),
                    content_error: Some("skipped".to_string()),
                    total_time_ms: 0,
                    captcha: None,
                    redirect: None,
                },
            };
            CheckProgress {
                index,
                total,
                is_last: index + 1 >= total,
                source_name: source
                    .as_ref()
                    .map(|s| s.book_source_name.clone())
                    .unwrap_or_default(),
                result,
            }
        })
        .buffered(concurrency.get());
    futures::pin_mut!(pending);
    loop {
        if !operation.is_active() {
            break;
        }
        let progress = tokio::select! {
            biased;
            _ = operation.task().cancelled() => break,
            progress = pending.next() => match progress { Some(progress)=>progress, None=>break },
        };
        {
            // sink 关闭（Err）时提前终止
            match operation.publish(|| on_result(progress)) {
                Some(Ok(())) => {}
                Some(Err(_)) => {
                    operation.cancel();
                    break;
                }
                None => break,
            }
        }
    }
}

pub fn load_check_sources_selected(
    storage: Option<&StorageContext>,
    urls: &[String],
) -> LegadoResult<Vec<Option<BookSource>>> {
    let storage = storage
        .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?;
    storage.with_database(|db| {
        let repo = BookSourceRepository::new(db.connection());
        if urls.is_empty() {
            return Ok(repo.find_all()?.into_iter().map(Some).collect());
        }
        urls.iter().map(|url| repo.find_by_url(url)).collect()
    })
}

impl SourceCheckService {
    pub fn new(resources: SourceCheckResources) -> Self {
        Self { resources }
    }
    pub fn check_source_entity(
        &self,
        source: BookSource,
        config: CheckerConfig,
    ) -> LegadoResult<CheckResult> {
        let task = self
            .resources
            .tasks
            .begin()
            .map_err(|e| LegadoError::Ffi(format!("书源校验任务不可用: {e}")))?;
        let checker = create_checker(&self.resources.network, config)?;
        self.resources.runtime.block_on(async move {
            let result = tokio::select! {
                biased;
                _ = task.cancelled() => return Err(LegadoError::Ffi("书源校验已取消".into())),
                result = checker.check_full(&source) => result,
            };
            task.with_active(|| result)
                .ok_or_else(|| LegadoError::Ffi("书源校验已取消".into()))
        })
    }
    pub async fn run_check_sources_selected<F>(
        &self,
        source_urls: Vec<String>,
        config: CheckerConfig,
        mut on_result: F,
    ) where
        F: FnMut(CheckProgress) -> Result<(), String>,
    {
        // 书源加载失败时以空流结束（Dart 侧表现为无结果）
        let slot = self.resources.slot.clone();
        let Ok(operation) = slot.start() else {
            return;
        };
        let _guard = operation.guard();
        let storage = self.resources.storage.clone();
        let network = self.resources.network.clone();
        let sources =
            load_check_sources_selected(storage.as_ref(), &source_urls).unwrap_or_default();
        let concurrency = match crate::request_settings::thread_count(storage.as_ref()) {
            Ok(value) => value,
            Err(error) => {
                log::error!("书源校验读取并发设置失败: {error}");
                return;
            }
        };
        run_checks_config(
            sources,
            config,
            &operation,
            &network,
            concurrency,
            &mut on_result,
        )
        .await;
    }
    pub fn cancel_check_sources(&self) {
        self.resources.slot.cancel();
    }
}

#[cfg(test)]
mod tests;
