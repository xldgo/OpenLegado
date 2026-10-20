//! 书源事件回调 FFI（对齐 Kotlin `SourceCallBack.callBackBtn`）
//!
//! 详情页/听书/阅读菜单自定义按钮等入口：执行 `contentRule.callBackJs`，
//! 注入 `event` / `book` / `chapter` / `result` / `java`（含 SourceLoginJsExtensions
//! 中途 UI）。无头引擎无法同步弹 Activity，经 `ui_action_queue` 收集副作用，
//! 由 Flutter `PlatformBridgeService` 回放。

use legado_core::LegadoResult;
pub use legado_engine::source_action_service::SourceCallBackBtnResult;

pub fn source_call_back_btn(
    event: &str,
    book_url: &str,
    chapter_index: Option<i32>,
    result: Option<&str>,
    _book_type: i32,
) -> LegadoResult<SourceCallBackBtnResult> {
    let tasks = crate::engine_holder::task_group();
    crate::source_action_host::service().source_call_back_btn(
        &tasks,
        event,
        book_url,
        chapter_index,
        result,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn call_back_btn_missing_book_errors() {
        let err = source_call_back_btn("clickCustomButton", "missing://book", None, None, 0);
        assert!(err.is_err());
    }
}
