use serde::{Deserialize, Serialize};

use crate::models::book_source::{lenient_opt_i32, lenient_opt_string};

/// 正文处理规则
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ContentRule {
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub content: Option<String>,
    /// 副文规则，拼接在正文后面或者获取歌词等
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "subContent",
        deserialize_with = "lenient_opt_string"
    )]
    pub sub_content: Option<String>,
    /// 有些网站只能在正文中获取标题
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "lenient_opt_string"
    )]
    pub title: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "nextContentUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub next_content_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "webJs",
        deserialize_with = "lenient_opt_string"
    )]
    pub web_js: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "sourceRegex",
        deserialize_with = "lenient_opt_string"
    )]
    pub source_regex: Option<String>,
    /// 替换规则
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replaceRegex",
        deserialize_with = "lenient_opt_string"
    )]
    pub replace_regex: Option<String>,
    /// 默认大小居中，FULL最大宽度
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "imageStyle",
        deserialize_with = "lenient_opt_string"
    )]
    pub image_style: Option<String>,
    /// 图片bytes二次解密js，返回解密后的bytes
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "imageDecode",
        deserialize_with = "lenient_opt_string"
    )]
    pub image_decode: Option<String>,
    /// 购买操作，js或者包含{{js}}的url
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "payAction",
        deserialize_with = "lenient_opt_string"
    )]
    pub pay_action: Option<String>,
    /// 监听到事件后执行的回调js代码
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "callBackJs",
        deserialize_with = "lenient_opt_string"
    )]
    pub call_back_js: Option<String>,
    /// 批量正文规则；当前仅解析和保留，不执行批量获取。— Codex + Rust
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "contentBatch",
        deserialize_with = "lenient_opt_string"
    )]
    pub content_batch: Option<String>,
    /// 最大批量数量；缺省/null表示未声明，不在解析层施加执行限制。
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "maxBatchSize",
        deserialize_with = "lenient_opt_i32"
    )]
    pub max_batch_size: Option<i32>,
}
