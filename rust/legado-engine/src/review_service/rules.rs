//! 规则书源段评：保持原请求构造、分页、Cookie和解析失败语义。
use super::*;
use legado_parser::{AnalyzeUrl, RequestMethod};
use std::collections::HashMap;

impl ReviewService {
    pub fn get_summary(
        &self,
        source: BookSource,
        request: ReviewRequest,
    ) -> LegadoResult<ReviewSummary> {
        if source.is_js_source() {
            return self.js_review_get_summary(&source, &request);
        }

        let empty = || Ok(ReviewSummary::default());

        let rule = match source.rule_review.as_ref() {
            Some(r) => r,
            None => return empty(),
        };
        let summary_url = rule
            .review_summary_url
            .as_deref()
            .unwrap_or("")
            .trim()
            .to_string();
        if !rule.enabled
            || summary_url.is_empty()
            || rule
                .summary_list_rule
                .as_deref()
                .unwrap_or("")
                .trim()
                .is_empty()
            || rule
                .summary_paragraph_index_rule
                .as_deref()
                .unwrap_or("")
                .trim()
                .is_empty()
            || rule
                .summary_count_rule
                .as_deref()
                .unwrap_or("")
                .trim()
                .is_empty()
        {
            return empty();
        }

        let chapter_url = request.chapter_url.clone();

        let analyze_url = AnalyzeUrl::parse(&summary_url, &HashMap::new(), 1)?;
        let final_url = {
            let raw = analyze_url.url().to_string();
            if raw.is_empty() {
                return Err(LegadoError::Internal("解析后段评摘要 URL 为空".into()));
            }
            if chapter_url.trim().is_empty() {
                raw
            } else {
                AnalyzeUrl::get_absolute_url(&chapter_url, &raw)
            }
        };

        let source_headers: Option<HashMap<String, String>> = source
            .header
            .as_ref()
            .and_then(|h| serde_json::from_str(h).ok());
        let mut headers = source_headers.unwrap_or_default();
        headers.extend(analyze_url.headers().clone());
        // 写侧 CookieJar 门控（批 2）：开启源补内部标记头（只补不覆盖；
        // 发送前由 legado-net 剥离、绝不出网）；读侧 cookie 注入不受影响。
        legado_fetcher::web_book::apply_cookie_jar_marker(&mut headers, &source);
        let headers_opt = if headers.is_empty() {
            None
        } else {
            Some(headers)
        };

        let method = analyze_url.method().clone();
        let post_body = analyze_url.request_body().to_string();
        let response = self
            .resources
            .runtime
            .block_on(async {
                let client = self.resources.network.client()?;
                match method {
                    RequestMethod::Post => client.post(&final_url, &post_body, headers_opt).await,
                    _ => client.get(&final_url, headers_opt).await,
                }
            })
            .map_err(|e| LegadoError::Network(format!("请求段评摘要失败: {e}")))?;

        if !response.is_success() {
            return Err(LegadoError::Network(format!(
                "HTTP {} for {}",
                response.status, final_url
            )));
        }

        let base_url = if response.url.is_empty() {
            final_url.clone()
        } else {
            response.url.clone()
        };
        let analyzer = self.construct_analyzer(
            response.body.clone(),
            base_url.clone(),
            &source.book_source_url,
        );
        let summary =
            legado_parser::review_rule_parser::parse_summary_with_analyzer(rule, &analyzer)
                .unwrap_or_default();

        Ok(ReviewSummary {
            counts: summary.counts,
            keys: summary.keys,
        })
    }
    pub fn get_detail(
        &self,
        source: BookSource,
        request: ReviewRequest,
        page: i32,
    ) -> LegadoResult<ReviewPage> {
        if source.is_js_source() {
            return self.js_review_get_detail(&source, &request, page);
        }

        let rule = source
            .rule_review
            .as_ref()
            .ok_or_else(|| LegadoError::Internal("书源未配置段评规则".into()))?;
        let detail_url_rule = rule
            .review_detail_url
            .as_deref()
            .unwrap_or("")
            .trim()
            .to_string();
        let detail_list = rule.detail_list_rule.as_deref().unwrap_or("").trim();
        let detail_content = rule.detail_content_rule.as_deref().unwrap_or("").trim();
        if !rule.enabled
            || detail_url_rule.is_empty()
            || detail_list.is_empty()
            || detail_content.is_empty()
        {
            return Err(LegadoError::Internal(
                "段评详情规则缺失（需 enabled/reviewDetailUrl/detailListRule/detailContentRule）"
                    .into(),
            ));
        }

        let field = |key: &str| request.field(key);
        let para_index = field("paraIndex");
        let para_data = field("paraData");
        let chapter_url = field("chapterUrl");
        let direct_url = field("detailUrl");
        let next_page_rule = rule
            .review_detail_next_page_url
            .as_deref()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty());

        let page = page.max(1);
        let url_rule = if !direct_url.trim().is_empty() {
            direct_url
        } else if page > 1 {
            next_page_rule
                .map(|s| s.to_string())
                .unwrap_or_else(|| detail_url_rule.clone())
        } else {
            detail_url_rule.clone()
        };

        let make_vars = |page_value: i32| {
            let mut vars = HashMap::new();
            vars.insert("paraIndex".to_string(), para_index.clone());
            vars.insert("paraData".to_string(), para_data.clone());
            vars.insert("page".to_string(), page_value.to_string());
            vars
        };

        let analyze_url = AnalyzeUrl::parse(&url_rule, &make_vars(page), page)?;
        let final_url = {
            let raw = analyze_url.url().to_string();
            if raw.is_empty() {
                return Err(LegadoError::Internal("解析后段评详情 URL 为空".into()));
            }
            if chapter_url.trim().is_empty() {
                raw
            } else {
                AnalyzeUrl::get_absolute_url(&chapter_url, &raw)
            }
        };

        let source_headers: Option<HashMap<String, String>> = source
            .header
            .as_ref()
            .and_then(|h| serde_json::from_str(h).ok());
        let mut headers = source_headers.unwrap_or_default();
        headers.extend(analyze_url.headers().clone());
        // 写侧 CookieJar 门控（批 2）：开启源补内部标记头（只补不覆盖；
        // 发送前由 legado-net 剥离、绝不出网）；读侧 cookie 注入不受影响。
        legado_fetcher::web_book::apply_cookie_jar_marker(&mut headers, &source);
        let headers_opt = if headers.is_empty() {
            None
        } else {
            Some(headers)
        };

        let method = analyze_url.method().clone();
        let post_body = analyze_url.request_body().to_string();
        let response = self
            .resources
            .runtime
            .block_on(async {
                let client = self.resources.network.client()?;
                match method {
                    RequestMethod::Post => client.post(&final_url, &post_body, headers_opt).await,
                    _ => client.get(&final_url, headers_opt).await,
                }
            })
            .map_err(|e| LegadoError::Network(format!("请求段评详情失败: {e}")))?;

        if !response.is_success() {
            return Err(LegadoError::Network(format!(
                "HTTP {} for {}",
                response.status, final_url
            )));
        }

        let base_url = if response.url.is_empty() {
            final_url.clone()
        } else {
            response.url.clone()
        };
        let analyzer = self.construct_analyzer(
            response.body.clone(),
            base_url.clone(),
            &source.book_source_url,
        );
        let detail_page = legado_parser::review_rule_parser::parse_detail_page_with_analyzer(
            rule,
            next_page_rule,
            &analyzer,
        );

        let has_reply_url = !rule
            .review_quote_url
            .as_deref()
            .unwrap_or("")
            .trim()
            .is_empty()
            && !rule
                .reply_list_rule
                .as_deref()
                .unwrap_or("")
                .trim()
                .is_empty()
            && !rule
                .reply_content_rule
                .as_deref()
                .unwrap_or("")
                .trim()
                .is_empty();

        Ok(ReviewPage {
            items: detail_page.items,
            next_page_url: detail_page.next_page_url,
            has_reply_url,
        })
    }
    pub fn get_replies(
        &self,
        source: BookSource,
        request: ReviewRequest,
        page: i32,
    ) -> LegadoResult<ReviewPage> {
        // JS 书源分支（Task #134）：复用 JS 编排器调用 getReviewDetail 实现按需加载，
        // 移除旧版"暂不支持"降级（对标 Kotlin ReviewDetailDialog 的 isJsSource 分支）
        if source.is_js_source() {
            return self.js_review_get_replies(&source, &request, page);
        }

        let rule = source
            .rule_review
            .as_ref()
            .ok_or_else(|| LegadoError::Internal("书源未配置段评规则".into()))?;
        let quote_url_rule = rule
            .review_quote_url
            .as_deref()
            .unwrap_or("")
            .trim()
            .to_string();
        let reply_list_rule = rule.reply_list_rule.as_deref().unwrap_or("").trim();
        let reply_content_rule = rule.reply_content_rule.as_deref().unwrap_or("").trim();
        // 对标 Kotlin hasReplyUrl 判定：enabled + reviewQuoteUrl + replyListRule + replyContentRule
        if !rule.enabled
            || quote_url_rule.is_empty()
            || reply_list_rule.is_empty()
            || reply_content_rule.is_empty()
        {
            return Err(LegadoError::Internal(
                "段评回复规则缺失（需 enabled/reviewQuoteUrl/replyListRule/replyContentRule）"
                    .into(),
            ));
        }

        let field = |key: &str| request.field(key);
        let review_id = field("reviewId");
        let para_index = field("paraIndex");
        let para_data = field("paraData");
        let chapter_url = field("chapterUrl");
        let direct_url = field("replyUrl");

        // 直连 URL 优先（翻页场景可直接传上一页解析出的 URL）
        let url_rule = if direct_url.trim().is_empty() {
            quote_url_rule.clone()
        } else {
            direct_url
        };

        let page = page.max(1);
        let make_vars = |page_value: i32| {
            let mut vars = HashMap::new();
            vars.insert("paraIndex".to_string(), para_index.clone());
            vars.insert("paraData".to_string(), para_data.clone());
            vars.insert("reviewId".to_string(), review_id.clone());
            vars.insert("page".to_string(), page_value.to_string());
            vars
        };

        let analyze_url = AnalyzeUrl::parse(&url_rule, &make_vars(page), page)?;
        // 对标 Kotlin AnalyzeUrl(baseUrl = chapter.url)：相对 URL 以章节 URL 补全
        let final_url = {
            let raw = analyze_url.url().to_string();
            if raw.is_empty() {
                return Err(LegadoError::Internal("解析后回复 URL 为空".into()));
            }
            if chapter_url.trim().is_empty() {
                raw
            } else {
                AnalyzeUrl::get_absolute_url(&chapter_url, &raw)
            }
        };

        // 合并请求头：书源全局 header + AnalyzeUrl 解析出的 header
        let source_headers: Option<HashMap<String, String>> = source
            .header
            .as_ref()
            .and_then(|h| serde_json::from_str(h).ok());
        let mut headers = source_headers.unwrap_or_default();
        headers.extend(analyze_url.headers().clone());
        // 写侧 CookieJar 门控（批 2）：开启源补内部标记头（只补不覆盖；
        // 发送前由 legado-net 剥离、绝不出网）；读侧 cookie 注入不受影响。
        legado_fetcher::web_book::apply_cookie_jar_marker(&mut headers, &source);
        let headers_opt = if headers.is_empty() {
            None
        } else {
            Some(headers)
        };

        // 发起HTTP请求，复用本次服务捕获的网络能力。
        let method = analyze_url.method().clone();
        let post_body = analyze_url.request_body().to_string();
        let response = self
            .resources
            .runtime
            .block_on(async {
                let client = self.resources.network.client()?;
                match method {
                    RequestMethod::Post => client.post(&final_url, &post_body, headers_opt).await,
                    _ => client.get(&final_url, headers_opt).await,
                }
            })
            .map_err(|e| LegadoError::Network(format!("请求段评回复失败: {e}")))?;

        if !response.is_success() {
            return Err(LegadoError::Network(format!(
                "HTTP {} for {}",
                response.status, final_url
            )));
        }

        // 解析回复列表（quickjs 特性下注入 JS 执行器以支持 @js: 规则）
        let base_url = if response.url.is_empty() {
            final_url.clone()
        } else {
            response.url.clone()
        };
        let analyzer = self.construct_analyzer(
            response.body.clone(),
            base_url.clone(),
            &source.book_source_url,
        );
        let replies =
            legado_parser::review_rule_parser::parse_reply_page_with_analyzer(rule, &analyzer)?;

        // 分页：回复非空时按 page+1 重新渲染 URL 规则得到下一页 URL；
        // 若 URL 不随页码变化（无分页占位符）则返回 null。
        let next_page_url = if replies.is_empty() {
            None
        } else {
            AnalyzeUrl::parse(&url_rule, &make_vars(page + 1), page + 1)
                .ok()
                .map(|a| {
                    let raw = a.url().to_string();
                    if chapter_url.trim().is_empty() {
                        raw
                    } else {
                        AnalyzeUrl::get_absolute_url(&chapter_url, &raw)
                    }
                })
                .filter(|u| !u.is_empty() && u != &final_url)
        };

        Ok(ReviewPage {
            items: replies,
            next_page_url,
            has_reply_url: false,
        })
    }
}
