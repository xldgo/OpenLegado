use serde::{Deserialize, Serialize};

use crate::models::book_source::lenient_opt_string;

/// 段评规则
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ReviewRule {
    /// 段评URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "reviewUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub review_url: Option<String>,
    /// 段评发布者头像
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "avatarRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub avatar_rule: Option<String>,
    /// 段评内容
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "contentRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub content_rule: Option<String>,
    /// 段评发布时间
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "postTimeRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub post_time_rule: Option<String>,
    /// 获取段评回复URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "reviewQuoteUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub review_quote_url: Option<String>,
    /// 点赞URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "voteUpUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub vote_up_url: Option<String>,
    /// 点踩URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "voteDownUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub vote_down_url: Option<String>,
    /// 发送回复URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "postReviewUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub post_review_url: Option<String>,
    /// 发送回复段评URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "postQuoteUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub post_quote_url: Option<String>,
    /// 删除段评URL
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "deleteUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub delete_url: Option<String>,
    #[serde(default)]
    pub enabled: bool,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "reviewSummaryUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub review_summary_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "summaryListRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub summary_list_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "summaryParagraphIndexRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub summary_paragraph_index_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "summaryParagraphDataRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub summary_paragraph_data_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "summaryCountRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub summary_count_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "reviewDetailUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub review_detail_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "reviewDetailNextPageUrl",
        deserialize_with = "lenient_opt_string"
    )]
    pub review_detail_next_page_url: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "detailListRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub detail_list_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "detailIdRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub detail_id_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "detailAvatarRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub detail_avatar_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "detailNameRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub detail_name_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "detailBadgeRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub detail_badge_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "detailContentRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub detail_content_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replyListRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub reply_list_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replyIdRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub reply_id_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replyAvatarRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub reply_avatar_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replyNameRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub reply_name_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replyBadgeRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub reply_badge_rule: Option<String>,
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "replyContentRule",
        deserialize_with = "lenient_opt_string"
    )]
    pub reply_content_rule: Option<String>,
}
