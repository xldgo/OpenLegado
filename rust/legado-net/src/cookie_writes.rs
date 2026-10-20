//! Cookie 写通道使用共享的纯同步原语，默认 JS 档不引入网络依赖。
pub use legado_core::write_coordinator::KeyedWriteCoordinator as CookieWriteCoordinator;
