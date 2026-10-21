use serde::{Deserialize, Serialize};

use crate::models::book_source::lenient_opt_string;

/// 书籍详情页规则
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct BookInfoRule {
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub init: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub name: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub author: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub intro: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub kind: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "lastChapter",
        deserialize_with = "lenient_opt_string"
    )]
    pub last_chapter: Option<String>,
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
        rename = "coverUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub cover_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "tocUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub toc_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "wordCount",
        deserialize_with = "lenient_opt_string"
    )]
    pub word_count: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "canReName",
        deserialize_with = "lenient_opt_string"
    )]
    pub can_re_name: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "downloadUrls",
        deserialize_with = "lenient_opt_string"
    )]
    pub download_urls: Option<String>,
}
