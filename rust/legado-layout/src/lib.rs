//! 阅读布局纯计算；平台负责测量，核心负责断行、落位和分页。
//! 算法来源：HapeLee/legado-with-MD3 070ca1a9b2e491654f70c105bca9939968023940，GPL-3.0。

pub mod line_breaker;
pub mod model;
pub mod paginator;
mod unicode;
pub mod wire;

pub const SCHEMA_VERSION: u32 = 1;
pub const UPSTREAM_REVISION: &str = "070ca1a9b2e491654f70c105bca9939968023940";

#[derive(Debug, thiserror::Error)]
#[error("阅读布局输入无效：{0}")]
pub struct LayoutError(pub String);

pub type Result<T> = std::result::Result<T, LayoutError>;
