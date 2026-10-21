use serde::{Deserialize, Serialize};

use crate::models::book_source::lenient_opt_string;

/// 目录页规则
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TocRule {
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "preUpdateJs",
        deserialize_with = "lenient_opt_string"
    )]
    pub pre_update_js: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "chapterList",
        deserialize_with = "lenient_opt_string"
    )]
    pub chapter_list: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "chapterName",
        deserialize_with = "lenient_opt_string"
    )]
    pub chapter_name: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "chapterUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub chapter_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "formatJs",
        deserialize_with = "lenient_opt_string"
    )]
    pub format_js: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "isVolume",
        deserialize_with = "lenient_opt_string"
    )]
    pub is_volume: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "isVip",
        deserialize_with = "lenient_opt_string"
    )]
    pub is_vip: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "isPay",
        deserialize_with = "lenient_opt_string"
    )]
    pub is_pay: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "updateTime",
        deserialize_with = "lenient_opt_string"
    )]
    pub update_time: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "nextTocUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub next_toc_url: Option<String>,
}
