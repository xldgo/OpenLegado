//! 段评宿主适配：文档/DTO转换及资源装配，业务编排位于Engine。
use crate::content_dto::{ReviewPageDto, ReviewSummaryDto};
use legado_core::{LegadoError, LegadoResult, models::BookSource};
pub use legado_engine::review_service::ReviewRequest;
use legado_engine::review_service::{ReviewResources, ReviewService};

fn host_service() -> ReviewService {
    let engine = crate::engine_holder::current().ok();
    ReviewService::new(ReviewResources {
        network: engine
            .as_ref()
            .map(|e| e.network().clone())
            .unwrap_or_else(crate::engine_holder::network),
        js: engine
            .as_ref()
            .map(|e| e.js_resources().clone())
            .unwrap_or_else(crate::engine_holder::js_resources),
        runtime: crate::runtime::get_runtime().handle().clone(),
    })
}

fn parse_request(raw: &str) -> LegadoResult<ReviewRequest> {
    let v: serde_json::Value = serde_json::from_str(raw)?;
    let field = |k: &str| {
        v.get(k)
            .map(|v| match v {
                serde_json::Value::Null => String::new(),
                serde_json::Value::String(s) => s.clone(),
                v => v.to_string(),
            })
            .unwrap_or_default()
    };
    Ok(ReviewRequest {
        chapter_url: field("chapterUrl"),
        para_index: field("paraIndex"),
        para_data: field("paraData"),
        detail_url: field("detailUrl"),
        reply_url: field("replyUrl"),
        review_id: field("reviewId"),
        book: v
            .get("book")
            .map(|b| serde_json::from_value(b.clone()))
            .transpose()?,
        chapter: v
            .get("chapter")
            .map(|b| serde_json::from_value(b.clone()))
            .transpose()?,
    })
}

pub fn review_get_summary(source_json: &str, request_json: &str) -> LegadoResult<String> {
    let result = review_get_summary_entity(
        serde_json::from_str(source_json)?,
        parse_request(request_json)?,
    )?;
    serde_json::to_string(&result).map_err(LegadoError::Serialization)
}

pub fn review_get_summary_entity(
    source: BookSource,
    request: ReviewRequest,
) -> LegadoResult<ReviewSummaryDto> {
    host_service().get_summary(source, request).map(Into::into)
}

pub fn review_get_detail(source_json: &str, request_json: &str, page: i32) -> LegadoResult<String> {
    let result = review_get_detail_entity(
        serde_json::from_str(source_json)?,
        parse_request(request_json)?,
        page,
    )?;
    serde_json::to_string(&result).map_err(LegadoError::Serialization)
}

pub fn review_get_detail_entity(
    source: BookSource,
    request: ReviewRequest,
    page: i32,
) -> LegadoResult<ReviewPageDto> {
    host_service()
        .get_detail(source, request, page)
        .map(Into::into)
}

pub fn review_get_replies(
    source_json: &str,
    request_json: &str,
    page: i32,
) -> LegadoResult<String> {
    let result = review_get_replies_entity(
        serde_json::from_str(source_json)?,
        parse_request(request_json)?,
        page,
    )?;
    serde_json::to_string(&result).map_err(LegadoError::Serialization)
}

pub fn review_get_replies_entity(
    source: BookSource,
    request: ReviewRequest,
    page: i32,
) -> LegadoResult<ReviewPageDto> {
    host_service()
        .get_replies(source, request, page)
        .map(Into::into)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_review_get_summary_disabled_returns_empty() {
        let source = BookSource {
            rule_review: Some(legado_core::models::ReviewRule {
                enabled: false,
                review_summary_url: Some("http://example.com/summary".into()),
                summary_list_rule: Some("$.data".into()),
                summary_paragraph_index_rule: Some("$.idx".into()),
                summary_count_rule: Some("$.cnt".into()),
                ..Default::default()
            }),
            ..Default::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let result = review_get_summary(&source_json, "{}").unwrap();
        let payload: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert!(payload["counts"].as_object().unwrap().is_empty());
        assert!(payload["keys"].as_object().unwrap().is_empty());
    }

    #[test]
    fn test_review_get_detail_incomplete_rules() {
        let source = BookSource {
            rule_review: Some(legado_core::models::ReviewRule {
                enabled: true,
                review_detail_url: Some("http://example.com/detail".into()),
                // 缺 detailListRule/detailContentRule
                ..Default::default()
            }),
            ..Default::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let err = review_get_detail(&source_json, "{}", 1).unwrap_err();
        assert!(err.to_string().contains("段评详情规则缺失"));
    }

    #[test]
    fn test_review_get_replies_invalid_source_json() {
        let err = review_get_replies("not valid json", "{}", 1).unwrap_err();
        assert!(matches!(err, LegadoError::Serialization(_)));
    }

    #[test]
    fn test_review_get_replies_missing_rule() {
        let source_json = serde_json::to_string(&BookSource::default()).unwrap();
        let err = review_get_replies(&source_json, "{}", 1).unwrap_err();
        assert!(err.to_string().contains("段评规则"));
    }

    #[test]
    fn test_review_get_replies_incomplete_rules() {
        let source = BookSource {
            rule_review: Some(legado_core::models::ReviewRule {
                enabled: true,
                review_quote_url: Some("http://example.com/reply?page={{page}}".into()),
                // 缺 replyListRule/replyContentRule
                ..Default::default()
            }),
            ..Default::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let err = review_get_replies(&source_json, "{}", 1).unwrap_err();
        assert!(err.to_string().contains("段评回复规则缺失"));
    }

    #[test]
    fn test_review_get_replies_js_source_dispatched() {
        // Task #134：JS 书源不再拒绝，进入 JS 编排器分派路径；
        // 未启用 quickjs 时占位引擎报错（错误源自 JS 引擎而非"暂不支持"降级）
        let source = BookSource {
            main_js: Some("// js source".into()),
            ..Default::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let err = review_get_replies(&source_json, "{}", 1).unwrap_err();
        assert!(!err.to_string().contains("暂不支持"), "降级分支应已移除");
    }

    /// quickjs 真实引擎端到端：JS getReviewDetail 返回含嵌套回复的详情分页
    ///
    /// 注：Kotlin 原版 normalizeJsResult 对 Scriptable 对象自动 JSON.stringify；
    /// Rust QuickJsEngine 对象返回值降级为 Debug 格式（非 JSON），故测试 JS
    /// 显式 JSON.stringify（书源侧兼容写法）。该引擎层差异待专项对齐。
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_review_get_replies_js_source_quickjs_e2e() {
        let source = BookSource {
            main_js: Some(
                r#"
            function getReviewDetail(chapter, book, paraIndex, paraData, page) {
                return JSON.stringify({
                    items: [{
                        id: "c1", name: "用户A", content: paraData + ":" + paraIndex,
                        avatar: "/a.png", badge: "作者",
                        replies: [{ id: "r1", content: "一级回复" }]
                    }],
                    nextPageUrl: page < 2 ? "more" : null
                });
            }
            "#
                .to_string(),
            ),
            ..Default::default()
        };
        let source_json = serde_json::to_string(&source).unwrap();
        let request_json = serde_json::json!({
            "paraIndex": 3,
            "paraData": "token",
            "chapterUrl": "https://example.com/chap/1.html",
        })
        .to_string();

        let result = review_get_replies(&source_json, &request_json, 1).unwrap();
        let payload: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(payload["nextPageUrl"], serde_json::json!("more"));
        let items = payload["items"].as_array().unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0]["id"], "c1");
        assert_eq!(items[0]["content"], "token:3");
        assert_eq!(items[0]["avatar"], "https://example.com/a.png");
        let replies = items[0]["replies"].as_array().unwrap();
        assert_eq!(replies.len(), 1);
        assert_eq!(replies[0]["content"], "一级回复");

        // 第二页：nextPageUrl 为 null
        let result2 = review_get_replies(&source_json, &request_json, 2).unwrap();
        let payload2: serde_json::Value = serde_json::from_str(&result2).unwrap();
        assert!(payload2["nextPageUrl"].is_null());
    }
}
