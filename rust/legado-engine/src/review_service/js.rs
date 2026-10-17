//! JS书源段评：沿用同一编排器和嵌套条目映射。
use super::*;

impl ReviewService {
    pub(super) fn js_review_get_summary(
        &self,
        source: &BookSource,
        request: &ReviewRequest,
    ) -> LegadoResult<ReviewSummary> {
        let book = request.book.clone().unwrap_or_default();
        let mut chapter = request.chapter.clone().unwrap_or_default();
        if chapter.url.is_empty() {
            chapter.url = request.chapter_url.clone();
        }
        let mut orchestrator = self
            .build_js_orchestrator(source)?
            .ok_or_else(|| LegadoError::Internal("JS 书源 mainJs 为空，无法加载段评摘要".into()))?;

        let summary = self.resources.runtime.block_on(async {
            tokio::task::spawn_blocking(move || orchestrator.get_review_summary(&book, &chapter))
                .await
                .map_err(|e| LegadoError::Internal(format!("JS 段评摘要任务异常: {e}")))?
        })?;

        Ok(ReviewSummary {
            counts: summary.counts.into_iter().collect(),
            keys: summary.keys.into_iter().collect(),
        })
    }
    pub(super) fn js_review_get_detail(
        &self,
        source: &BookSource,
        request: &ReviewRequest,
        page: i32,
    ) -> LegadoResult<ReviewPage> {
        self.js_review_get_replies(source, request, page)
    }
    pub(super) fn js_review_get_replies(
        &self,
        source: &BookSource,
        request: &ReviewRequest,
        page: i32,
    ) -> LegadoResult<ReviewPage> {
        let book = request.book.clone().unwrap_or_default();
        let mut chapter = request.chapter.clone().unwrap_or_default();
        if chapter.url.is_empty() {
            chapter.url = request.chapter_url.clone();
        }
        let para_index = request.para_index.parse::<i64>().unwrap_or(0) as i32;
        let para_data = request.para_data.clone();
        let mut orchestrator = self
            .build_js_orchestrator(source)?
            .ok_or_else(|| LegadoError::Internal("JS 书源 mainJs 为空，无法加载段评回复".into()))?;

        // JS 分派：spawn_blocking 避免嵌套 runtime 死锁（同 webbook_search 模式）
        let detail_page = self.resources.runtime.block_on(async {
            tokio::task::spawn_blocking(move || {
                orchestrator.get_review_detail(&book, &chapter, para_index, &para_data, page)
            })
            .await
            .map_err(|e| LegadoError::Internal(format!("JS 段评回复任务异常: {e}")))?
        })?;

        // 转换为与规则路径兼容的响应格式（camelCase 契约，API_CONTRACT.md 已登记）
        let items = convert_js_review_items(detail_page.items);
        Ok(ReviewPage {
            items,
            next_page_url: detail_page.next_page_url,
            has_reply_url: false,
        })
    }
}

pub(super) fn convert_js_review_items(
    items: Vec<legado_js::js_source::js_source_review::ReviewDetailItem>,
) -> Vec<legado_parser::review_rule_parser::ReviewDetailItem> {
    items
        .into_iter()
        .map(|it| legado_parser::review_rule_parser::ReviewDetailItem {
            id: it.id,
            avatar: it.avatar,
            name: it.name,
            badges: it.badges,
            content: Some(it.content),
            image_url: None,
            audio_url: None,
            time: None,
            like_count: None,
            reply_count: None,
            replies: convert_js_review_items(it.replies),
        })
        .collect()
}
