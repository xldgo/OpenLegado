//! 书源 concurrentRate 固定窗口限流（G4，对齐 Kotlin ConcurrentRateLimiter）
//!
//! P5 子批 2a：限速表本体（`RateLimiterRegistry`）已下沉 `legado-fetcher`；
//! 本模块从宿主根持有者获取同一个引擎限流表。

use std::sync::Arc;

use legado_core::models::BookSource;

pub use legado_fetcher::rate_limit::RateLimiterRegistry;

/// FFI 启动资源与数据库上下文沿用同一个注册表，不另建限流窗口。
pub(crate) fn registry() -> Arc<RateLimiterRegistry> {
    crate::engine_holder::rate_limiter()
}

/// 按书源 `concurrentRate` 获取访问许可（空/"0"/非法 → 立即返回）
pub async fn acquire_source_rate_limit(source: &BookSource) {
    registry().acquire(source).await;
}
