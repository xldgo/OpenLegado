//! 请求策略只提供配置快照和可取消等待，不依赖数据库或抓取层。
//! — Codex + Bridge
#![cfg(feature = "quickjs")]

use std::{future::Future, num::NonZeroUsize, pin::Pin, sync::Arc};

pub type RequestWait<'a> = Pin<Box<dyn Future<Output = ()> + Send + 'a>>;

pub trait RequestGate: Send + Sync {
    fn acquire(&self) -> RequestWait<'_>;
}

pub trait HttpRequestPolicy: Send + Sync {
    fn snapshot(&self, source: Option<&str>) -> Result<RequestPolicySnapshot, String>;
}

pub struct RequestPolicySnapshot {
    pub concurrency: NonZeroUsize,
    pub gate: Option<Arc<dyn RequestGate>>,
}

impl Default for RequestPolicySnapshot {
    fn default() -> Self {
        Self {
            concurrency: NonZeroUsize::new(4).unwrap(),
            gate: None,
        }
    }
}

impl RequestPolicySnapshot {
    /// 等待不预留将来窗口；丢弃future即可取消。
    pub async fn acquire(&self, skip_rate_limit: bool) {
        if !skip_rate_limit && let Some(gate) = &self.gate {
            gate.acquire().await;
        }
    }
}
