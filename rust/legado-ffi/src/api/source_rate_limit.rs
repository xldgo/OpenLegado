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

/// 书源保存成功后的限速配置刷新入口（宿主保存路径：source add/update/import 调用）
///
/// 走 [`RateLimiterRegistry::refresh`] 的保存侧分发：空 / `"0"`（忽略首尾
/// 空白）→ 移除既有 limiter（对齐原版「空即不限流」，保存显式 null/空串后
/// 不再沿用旧限速）；合法 rate → 原位刷新；非法 rate 与未注册 key → 不改动/
/// 不预创建。可在写库成功后无条件调用；写库失败不得调用（避免未落库的配置
/// 提前生效）。
pub(crate) fn refresh_source_rate_limit(source_url: &str, concurrent_rate: &str) {
    registry().refresh(source_url, concurrent_rate);
}

/// 按书源 `concurrentRate` 获取访问许可（空/"0"/非法 → 立即返回）
pub async fn acquire_source_rate_limit(source: &BookSource) {
    registry().acquire(source).await;
}
