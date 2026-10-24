//! 自动高亮规则的统一配置、预设、传输与匹配。
mod style;
pub use style::HighlightStyle;

mod transfer;
pub use transfer::{export_document, external_uuid, normalize_rule, parse_document, presets};

mod matcher;
pub use matcher::{HighlightMatch, match_text};

#[cfg(test)]
mod tests;
