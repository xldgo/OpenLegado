//! 搜索领域结果，与宿主传输适配解耦。
use super::*;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    /// 书源 URL
    pub source_url: String,
    /// 书源名称
    pub source_name: String,
    /// 书籍名称
    pub book_name: String,
    /// 作者
    pub author: String,
    /// 详情页 URL
    pub book_url: String,
    /// 最新章节
    pub latest_chapter: Option<String>,
    /// 简介
    pub intro: Option<String>,
    /// 封面 URL
    pub cover_url: Option<String>,
    /// 分类标签（对齐原版 ruleSearch.kind 解析，逗号分隔多标签）
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    /// 字数展示文本（对齐原版 ruleSearch.wordCount + `wordCountFormat`）
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub word_count: Option<String>,
    /// BookType 位标志（对齐原版 `bookSource.getBookType()`，源级多媒体类型）
    #[serde(default)]
    pub book_type: i32,
    /// 书源手动排序编号（对齐原版 BookList.kt:215 originOrder = customOrder；[P0-2 S4] 此前 DTO 转换恒写 0）
    #[serde(default, rename = "originOrder")]
    pub origin_order: i32,
    /// 是否有阅读记录（对齐上游 `SearchViewModel.hasReadRecord`，
    /// 加法式字段：无记录时恒为 false）
    #[serde(default, rename = "hasReadRecord")]
    pub has_read_record: bool,
    /// 阅读记录中的作者信息（仅在有阅读记录时附加，
    /// 多作者以顿号连接；无记录时缺省）
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "readRecordAuthor"
    )]
    pub read_record_author: Option<String>,
    /// 规则变量 JSON（换源 T5，2026-09-03）：搜索元素级解析期间 `@put`/
    /// `putVariable` 级联导出，随候选进入换源（对齐原版 SearchBook.toBook
    /// 复制 variable 语义，SearchBook.kt:134）
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub variable: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoverCandidate {
    /// 封面图片地址（必需）
    pub url: String,
    /// 图片宽度（像素，未知填 0）
    pub width: i32,
    /// 图片高度（像素，未知填 0）
    pub height: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchSourceBatch {
    /// 书源在请求列表中的索引（从 0 开始）
    pub source_index: usize,
    /// 书源 URL
    pub source_url: String,
    /// 书源名称
    pub source_name: String,
    /// 该书源命中的书籍列表（原版 `SearchBook` camelCase 序列化契约，
    /// 与 Dart 侧 `SearchBook.fromJson` 字段一一对应）
    pub books: Vec<CoreSearchBook>,
    /// 该书源搜索失败时的错误信息（成功为 None）
    pub error: Option<String>,
    /// 当前已完成（已推送批次）的书源数量
    pub finished_count: usize,
    /// 本次搜索的书源总数
    pub total_count: usize,
    /// 是否为最后一个批次（finished_count == total_count 时为 true）
    pub is_last: bool,
    /// 是否还有下一页可加载（累积值：任一已推送批次非空即 true，
    /// 对齐原版 SearchModel `hasMore = hasMore || items.isNotEmpty()`；批次B G-B-02）
    #[serde(default)]
    pub has_more: bool,
    /// 逐源错误八分类（任务书 B P2 项1，2026-09-19 加法式，零破坏）：
    /// `ok` / `empty` / `http_error` / `timeout` / `login_required` / `js_error` /
    /// `parser_error` / `cancelled`。
    /// 由批次组装单点（`run_multi_stream` 批次闭包经 `classify_source_outcome`）
    /// 对 `LegadoError` 变体映射；现有 `error` 字段及其语义保持不变（冻结约束），
    /// 不读该字段的旧调用方零破坏。`#[serde(default)]` 兼容历史批次反序列化
    /// （历史批次无此字段时回退空串；Rust 侧发出的批次恒为八类之一）。
    #[serde(default)]
    pub error_class: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnnotatedCandidate {
    /// 书籍名称
    pub book_name: String,
    /// 作者
    pub author: String,
    /// 封面 URL
    pub cover_url: Option<String>,
    /// 简介
    pub intro: Option<String>,
    /// 最新章节
    pub latest_chapter: Option<String>,
    /// 书源 URL
    pub source_url: String,
    /// 书源名称
    pub source_name: String,
    /// 书籍详情页 URL
    pub book_url: String,
    /// 相关性评分
    pub relevance_score: f64,
    /// 书源手动排序编号（对齐原版 BookList.kt:215 originOrder = customOrder；
    /// [STAGE4-P36] 补齐 multi_source_search 输出契约，与 search_books 同语义）
    #[serde(default, rename = "originOrder")]
    pub origin_order: i32,
    /// 是否有阅读记录
    #[serde(default, rename = "hasReadRecord")]
    pub has_read_record: bool,
    /// 阅读记录中的作者信息（无记录时缺省）
    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        rename = "readRecordAuthor"
    )]
    pub read_record_author: Option<String>,
    /// 规则变量 JSON（换源 T5 透传，additive）
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub variable: Option<String>,
}
