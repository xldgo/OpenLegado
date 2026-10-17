//! 段评请求与应用结果；不依赖宿主传输DTO。
use legado_parser::review_rule_parser::ReviewDetailItem;
pub use legado_parser::review_rule_parser::ReviewSummaryResult as ReviewSummary;

/// 规则模板与 JS 正文共享上下文，实体不经过 JSON 往返。
#[derive(Debug, Clone, Default)]
pub struct ReviewRequest {
    pub chapter_url: String,
    pub para_index: String,
    pub para_data: String,
    pub detail_url: String,
    pub reply_url: String,
    pub review_id: String,
    pub book: Option<legado_core::models::Book>,
    pub chapter: Option<legado_core::models::BookChapter>,
}
impl ReviewRequest {
    pub(super) fn field(&self, key: &str) -> String {
        match key {
            "chapterUrl" => &self.chapter_url,
            "paraIndex" => &self.para_index,
            "paraData" => &self.para_data,
            "detailUrl" => &self.detail_url,
            "replyUrl" => &self.reply_url,
            "reviewId" => &self.review_id,
            _ => "",
        }
        .to_string()
    }
}

/// 段评详情与回复共用的应用结果；由各宿主映射为自身协议。
#[derive(Debug, Clone, Default)]
pub struct ReviewPage {
    pub items: Vec<ReviewDetailItem>,
    pub next_page_url: Option<String>,
    pub has_reply_url: bool,
}
