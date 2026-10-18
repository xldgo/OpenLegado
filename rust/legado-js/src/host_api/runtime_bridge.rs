//! tokio 运行时桥接层
//!
//! JS 宿主函数在独立 OS 线程同步执行，通过此桥接层
//! 调用 legado-net 的异步 LegadoClient（基于 reqwest/tokio）。

use std::sync::OnceLock;
use tokio::runtime::{Builder, Runtime};

/// 全局共享 tokio Runtime（懒初始化）
static RUNTIME: OnceLock<Runtime> = OnceLock::new();

/// 获取或创建全局 tokio Runtime
///
/// 任务 #60 ②：原 `Runtime::new()` 无 thread_name 且 worker 栈为默认约 2MB，
/// 是搜索崩溃（regex-syntax 深递归击穿 worker 栈）的主要宿主。
/// 改为 Builder 显式配置：worker 栈扩到 8MB（对齐原版 JVM 线程栈水位）
/// + thread_name 便于崩溃诊断。tokio blocking 池为按需创建无法配置栈，
///   其风险由 regex_safe 非递归预检兜底。
pub fn get_runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        Builder::new_multi_thread()
            .enable_all()
            .thread_name("legado-js-worker")
            .thread_stack_size(8 * 1024 * 1024)
            .build()
            .expect("Failed to create tokio runtime")
    })
}

/// 在 JS 线程中同步执行异步操作
///
/// # 安全约束
/// 此函数只能在非 tokio worker 线程中调用（即 JS 专用 OS 线程）。
/// 在 tokio worker 中调用 block_on 会导致死锁。
pub fn block_on<F: std::future::Future>(future: F) -> F::Output {
    match tokio::runtime::Handle::try_current() {
        // 已在 tokio runtime 内（探索/搜索等 async 上下文内执行书源 JS →
        // java.ajax 等网络调用）：用 block_in_place 让出当前 worker 后
        // 再驱动 legado-js runtime，避免嵌套 Runtime::block_on 触发
        // "Cannot start a runtime from within a runtime"（七猫四合一书源
        // 点分类报错根因；要求外层 runtime 为 multi-thread，legado-ffi
        // runtime 满足）。— DeepSeek Harness + Bridge（2026-08-15）
        Ok(_) => tokio::task::block_in_place(|| get_runtime().block_on(future)),
        Err(_) => get_runtime().block_on(future),
    }
}

pub(crate) trait CancelError {
    fn cancelled() -> Self;
}
impl CancelError for String {
    fn cancelled() -> Self {
        crate::cancellation::CANCELLED.into()
    }
}
impl CancelError for legado_core::LegadoError {
    fn cancelled() -> Self {
        crate::cancellation::error()
    }
}

/// 进入异步驱动前固定本次取消能力，不在异步轮询时重新读取TLS。
pub(crate) fn block_on_cancellable<F, T, E>(future: F) -> Result<T, E>
where
    F: std::future::Future<Output = Result<T, E>>,
    E: CancelError,
{
    let control = crate::cancellation::current();
    block_on(async move {
        let Some(control) = control else {
            return future.await;
        };
        if control.is_cancelled() {
            return Err(E::cancelled());
        }
        let result = match futures::future::select(control.cancelled(), Box::pin(future)).await {
            futures::future::Either::Left(_) => Err(E::cancelled()),
            futures::future::Either::Right((result, _)) => result,
        };
        if control.is_cancelled() {
            Err(E::cancelled())
        } else {
            result
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_runtime_creation() {
        let rt = get_runtime();
        // 验证 runtime 可用：能在其上执行简单任务
        let result = rt.block_on(async { 1 + 1 });
        assert_eq!(result, 2);
    }

    #[test]
    fn test_block_on_simple() {
        let result = block_on(async { 42 });
        assert_eq!(result, 42);
    }
}
