//! 书源登录、章节购买与事件回调；资源来自宿主入口快照。
use crate::{SourceLoginCache, StorageContext};
use legado_core::{LegadoError, LegadoResult, models::BookSource};
use std::sync::Arc;

mod callback;
#[cfg(feature = "quickjs")]
mod js;
mod login_v1;
mod login_v2;
mod purchase;
pub use callback::SourceCallBackBtnResult;
pub use login_v2::{LoginActionV2Request, is_login_ui_v2};
pub use purchase::PayActionResult;

pub type SourceActionSetup = Arc<dyn Fn(&BookSource) -> LegadoResult<String> + Send + Sync>;

/// 仅持数据能力与脚本构造能力，不反向持有根引擎。
pub struct SourceActionResources {
    pub storage: Option<StorageContext>,
    pub js: Arc<legado_js::JsResources>,
    pub login: Arc<SourceLoginCache>,
    pub setup: SourceActionSetup,
}
pub struct SourceActionService {
    resources: SourceActionResources,
}
impl SourceActionService {
    pub fn new(resources: SourceActionResources) -> Self {
        Self { resources }
    }
    fn with_database<T>(
        &self,
        f: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.resources
            .storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(f)
    }
}

#[cfg(test)]
mod callback_tests;
#[cfg(test)]
mod tests;
