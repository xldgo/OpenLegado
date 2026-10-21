use serde::{Deserialize, Serialize};

use crate::models::book_source::lenient_opt_string;

/// 搜索结果处理规则
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SearchRule {
    /// 校验关键字
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "checkKeyWord",
        deserialize_with = "lenient_opt_string"
    )]
    pub check_key_word: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "bookList",
        deserialize_with = "lenient_opt_string"
    )]
    pub book_list: Option<String>,
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
        rename = "bookUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub book_url: Option<String>,
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
        rename = "wordCount",
        deserialize_with = "lenient_opt_string"
    )]
    pub word_count: Option<String>,
}
