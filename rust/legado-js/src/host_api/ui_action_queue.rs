//! UI 动作按当前同步 JS 求值作用域收集，不使用跨线程共享队列。
use serde_json::Value;

#[derive(Default)]
struct Actions {
    values: Vec<Value>,
    refresh_explore: bool,
}
thread_local! {
    static CURRENT: std::cell::RefCell<Option<Actions>> = const { std::cell::RefCell::new(None) };
}

pub struct CollectedActions<R> {
    pub result: R,
    pub actions: Vec<Value>,
    pub refresh_explore: bool,
}

/// 保存并恢复外层作用域；正常返回与 panic 都不会污染下一次调用。
pub fn collect_actions<R>(operation: impl FnOnce() -> R) -> CollectedActions<R> {
    struct Guard(Option<Actions>);
    impl Drop for Guard {
        fn drop(&mut self) {
            CURRENT.with(|slot| *slot.borrow_mut() = self.0.take());
        }
    }
    let previous = CURRENT.with(|slot| slot.replace(Some(Actions::default())));
    let _guard = Guard(previous);
    let result = operation();
    let captured = CURRENT.with(|slot| slot.borrow_mut().take().unwrap_or_default());
    CollectedActions {
        result,
        actions: captured.values,
        refresh_explore: captured.refresh_explore,
    }
}

/// 不需要发现页刷新标志的宿主沿用原返回形态。
pub fn collect_local<R>(operation: impl FnOnce() -> R) -> (R, Vec<Value>) {
    let collected = collect_actions(operation);
    (collected.result, collected.actions)
}
pub fn is_collecting() -> bool {
    CURRENT.with(|slot| slot.borrow().is_some())
}
pub fn push_action(action: Value) {
    CURRENT.with(|slot| {
        if let Some(actions) = slot.borrow_mut().as_mut() {
            actions.values.push(action);
        }
    });
}
pub fn push_payload_json(payload: &str) {
    if !is_collecting() {
        return;
    }
    if let Ok(action) = serde_json::from_str(payload) {
        push_action(action);
    }
}
fn request_refresh_explore() {
    CURRENT.with(|slot| {
        if let Some(actions) = slot.borrow_mut().as_mut() {
            actions.refresh_explore = true;
        }
    });
}

/// SourceLoginJsExtensions 中途 UI 动作构造
pub mod source_login_ext {
    use super::push_action;
    use serde_json::json;

    pub fn refresh_book_info() {
        push_action(json!({ "action": "refreshBookInfo" }));
    }

    pub fn refresh_book_toc() {
        push_action(json!({ "action": "refreshBookToc" }));
    }

    pub fn refresh_content() {
        push_action(json!({ "action": "refreshContent" }));
    }

    pub fn copy_text(text: &str) {
        push_action(json!({ "action": "copyText", "text": text }));
    }

    pub fn clear_tts_cache() {
        push_action(json!({ "action": "clearTtsCache" }));
    }

    /// 对齐 Kotlin `SourceLoginJsExtensions.refreshExplore` / `reLoginView`
    pub fn refresh_explore() {
        super::request_refresh_explore();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn scopes_ignore_outside_actions_and_keep_nested_and_threaded_results_independent() {
        push_action(serde_json::json!({"action":"ignored"}));
        assert!(!is_collecting());
        let outer = collect_actions(|| {
            push_action(serde_json::json!({"action":"outer"}));
            let inner = collect_actions(|| {
                source_login_ext::refresh_explore();
                push_payload_json(r#"{"action":"inner"}"#);
            });
            assert!(inner.refresh_explore);
            assert_eq!(inner.actions[0]["action"], "inner");
            let other = std::thread::spawn(|| {
                collect_actions(|| {
                    source_login_ext::refresh_explore();
                    push_action(serde_json::json!({"action":"other"}));
                })
            })
            .join()
            .unwrap();
            assert!(other.refresh_explore);
            assert_eq!(other.actions[0]["action"], "other");
        });
        assert_eq!(outer.actions.len(), 1);
        assert_eq!(outer.actions[0]["action"], "outer");
        assert!(!outer.refresh_explore);
        assert!(!is_collecting());
    }
    #[test]
    fn panicking_inner_scope_restores_outer_actions_and_refresh_flag() {
        let outer = collect_actions(|| {
            push_action(serde_json::json!({"action":"before"}));
            source_login_ext::refresh_explore();
            assert!(
                std::panic::catch_unwind(|| collect_actions(|| {
                    push_action(serde_json::json!({"action":"discard"}));
                    panic!("测试作用域退出");
                }))
                .is_err()
            );
            push_action(serde_json::json!({"action":"after"}));
        });
        assert!(outer.refresh_explore);
        assert_eq!(outer.actions.len(), 2);
        assert_eq!(outer.actions[1]["action"], "after");
        assert!(!is_collecting());
    }
}
