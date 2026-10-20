//! 书源脚本动作的宿主装配，不执行登录或购买业务。
use legado_engine::source_action_service::{SourceActionResources, SourceActionService};
use std::sync::Arc;

pub(crate) fn service() -> SourceActionService {
    let storage = crate::engine_holder::current()
        .ok()
        .map(|e| e.storage().clone());
    let login = crate::engine_holder::source_login_cache();
    let setup_login = login.clone();
    let info = crate::engine_holder::source_info_map();
    SourceActionService::new(SourceActionResources {
        storage,
        js: crate::engine_holder::js_resources(),
        login,
        setup: Arc::new(move |source| {
            crate::api::source_js_bindings::book_source_js_setup_script_with_login_cache(
                source,
                &setup_login,
                &info,
            )
        }),
    })
}
