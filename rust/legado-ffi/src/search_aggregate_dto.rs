//! 聚合只传决策字段；完整首条书籍元数据留在调用端。— Codex + Bridge
pub struct SearchAggregateInputDto {
    pub name: String,
    pub author: String,
    pub origin: String,
    pub kind: Option<String>,
    pub origins: Vec<String>,
    pub has_read_record: bool,
}
pub struct SearchAggregateRetainedDto {
    pub input_index: usize,
    pub representative_id: usize,
}
pub struct SearchAggregateResultDto {
    pub representative_id: usize,
    pub name: String,
    pub author: String,
    pub origins: Vec<String>,
    pub has_read_record: bool,
}
