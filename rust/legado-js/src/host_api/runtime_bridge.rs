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
/// 并设置thread_name便于崩溃诊断；当前Tokio也将thread_stack_size用于按需创建的blocking线程。
/// 正则仍须经过regex_safe预检，扩栈不替代输入防护。
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

/// 不支持的执行环境明确返回错误，不在单线程运行时阻塞其唯一驱动线程。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct UnsupportedRuntime;
impl std::fmt::Display for UnsupportedRuntime {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(
            "同步JS网络桥不能在Tokio单线程运行时执行，请使用多线程宿主或运行时之外的专用线程",
        )
    }
}
impl std::error::Error for UnsupportedRuntime {}
/// 同步桥只接受普通线程或多线程运行时；不移动QuickJS对象或创建每请求线程。
pub fn block_on<F: std::future::Future>(future: F) -> Result<F::Output, UnsupportedRuntime> {
    match tokio::runtime::Handle::try_current() {
        Ok(handle) if handle.runtime_flavor() == tokio::runtime::RuntimeFlavor::MultiThread => {
            Ok(tokio::task::block_in_place(|| {
                get_runtime().block_on(future)
            }))
        }
        Ok(_) => Err(UnsupportedRuntime),
        Err(_) => Ok(get_runtime().block_on(future)),
    }
}

pub(crate) trait CancelError {
    fn cancelled() -> Self;
    fn unsupported_runtime(error: UnsupportedRuntime) -> Self;
}
impl CancelError for String {
    fn unsupported_runtime(error: UnsupportedRuntime) -> Self {
        error.to_string()
    }
    fn cancelled() -> Self {
        crate::cancellation::CANCELLED.into()
    }
}
impl CancelError for legado_core::LegadoError {
    fn unsupported_runtime(error: UnsupportedRuntime) -> Self {
        Self::JsEngine(error.to_string())
    }
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
    .map_err(E::unsupported_runtime)?
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
        let result = block_on(async { 42 }).unwrap();
        assert_eq!(result, 42);
    }
}

#[cfg(test)]
mod environment_tests {
    use super::*;
    #[test]
    fn current_thread_is_rejected_before_polling_and_runtime_stays_usable() {
        let rt = Builder::new_current_thread().enable_all().build().unwrap();
        rt.block_on(async {
            let polled = std::cell::Cell::new(false);
            let result = block_on(async {
                polled.set(true);
                42
            });
            assert_eq!(result, Err(UnsupportedRuntime));
            assert!(!polled.get());
            tokio::task::yield_now().await;
        });
    }
    #[test]
    fn multi_thread_and_blocking_host_are_supported() {
        let rt = Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            assert_eq!(
                block_on(async {
                    tokio::task::yield_now().await;
                    42
                })
                .unwrap(),
                42
            );
            assert_eq!(
                tokio::task::spawn_blocking(|| block_on(async { 43 }).unwrap())
                    .await
                    .unwrap(),
                43
            );
        });
    }
    #[test]
    fn real_js_network_returns_catchable_error_instead_of_panicking() {
        use crate::engine::JsEngine;
        let vm = crate::engine::QuickJsEngine::new(
            crate::sandbox::SandboxConfig::default().with_allow_script_run(true),
        )
        .unwrap();
        let rt = Builder::new_current_thread().enable_all().build().unwrap();
        rt.block_on(async {
            let script = "try { java.get('http://127.0.0.1:1/never',{}); false } \
                          catch(e) { String(e).includes('单线程') }";
            assert_eq!(vm.eval(script).unwrap(), "true");
            assert_eq!(vm.eval("1+1").unwrap(), "2");
        });
    }
}
