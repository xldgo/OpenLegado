use super::js::convert_js_review_items;
use super::*;
use crate::EngineContext;

fn service(engine: &EngineContext, runtime: &tokio::runtime::Runtime) -> ReviewService {
    ReviewService::new(ReviewResources {
        network: engine.network().clone(),
        js: engine.js_resources().clone(),
        runtime: runtime.handle().clone(),
    })
}

#[test]
fn test_js_review_get_replies_empty_main_js_rejected() {
    // mainJs 为空的 JS 书源 → 明确错误（无编排器可构建）
    let source = BookSource {
        main_js: Some("   ".into()),
        ..Default::default()
    };
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = EngineContext::in_memory().unwrap();
    let service = service(&engine, &runtime);
    let err = service
        .js_review_get_replies(&source, &ReviewRequest::default(), 1)
        .unwrap_err();
    assert!(err.to_string().contains("mainJs"));
}

#[test]
fn test_convert_js_review_items_mapping() {
    use legado_js::js_source::js_source_review::ReviewDetailItem;
    let items = vec![ReviewDetailItem {
        id: Some("c1".into()),
        name: Some("用户A".into()),
        content: "好看".into(),
        avatar: Some("http://img.com/a.jpg".into()),
        badges: vec!["大佬".into()],
        replies: vec![ReviewDetailItem {
            id: Some("r1".into()),
            name: None,
            content: "同意".into(),
            avatar: None,
            badges: vec![],
            replies: vec![],
        }],
    }];
    let converted = convert_js_review_items(items);
    assert_eq!(converted.len(), 1);
    assert_eq!(converted[0].id.as_deref(), Some("c1"));
    assert_eq!(converted[0].content.as_deref(), Some("好看"));
    assert_eq!(converted[0].badges, vec!["大佬".to_string()]);
    // 嵌套回复递归转换且不再嵌套（扁平化已在解析层完成）
    assert_eq!(converted[0].replies.len(), 1);
    assert_eq!(converted[0].replies[0].content.as_deref(), Some("同意"));
    assert!(converted[0].image_url.is_none());
    assert!(converted[0].like_count.is_none());
}

#[test]
fn rule_requests_use_captured_network_and_keep_paging_headers_and_context() {
    use crate::test_http_fixture::Fixture;
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let mut fixture = Fixture::with_content_type(8, false, "application/json", |request| {
        let (name, count) = if request.contains("identity=first") {
            ("甲", 3)
        } else {
            ("乙", 5)
        };
        serde_json::json!({
            "items":[{"id":"review-1","idx":1,"count":count,"data":name,
                "content":name,"avatar":"/avatar.png"}], "next":"/next"
        })
        .to_string()
    });
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = Arc::new(EngineContext::in_memory().unwrap());
    first
        .network()
        .set_cookie("127.0.0.1", "identity=first")
        .unwrap();
    second
        .network()
        .set_cookie("127.0.0.1", "identity=second")
        .unwrap();
    let a = service(&first, &runtime);
    let b = service(&second, &runtime);
    let weak_a = Arc::downgrade(&first);
    let weak_b = Arc::downgrade(&second);
    drop(first);
    drop(second);
    assert!(weak_a.upgrade().is_none());
    assert!(weak_b.upgrade().is_none());

    let source: BookSource = serde_json::from_value(serde_json::json!({
        "bookSourceUrl":fixture.url,"header":"{\"X-Source\":\"header\",\"X-Merge\":\"source\"}",
        "enabledCookieJar":true,
        "ruleReview":{
            "enabled":true,"reviewSummaryUrl":"/summary",
            "summaryListRule":"$.items","summaryParagraphIndexRule":"$.idx",
            "summaryCountRule":"$.count","summaryParagraphDataRule":"$.data",
            "reviewDetailUrl":"/detail?idx={{paraIndex}}&data={{paraData}}&page={{page}},{\"method\":\"POST\",\"body\":\"payload\",\"headers\":{\"X-Merge\":\"option\"}}",
            "reviewDetailNextPageUrl":"$.next",
            "detailListRule":"$.items","detailIdRule":"$.id","detailAvatarRule":"$.avatar",
            "detailContentRule": if cfg!(feature="quickjs") {
                "@js:JSON.parse(result).content + ':' + java.getCookie('http://127.0.0.1')"
            } else { "$.content" },
            "reviewQuoteUrl":"/reply?review={{reviewId}}&page={{page}}",
            "replyListRule":"$.items","replyContentRule":"$.content","replyIdRule":"$.id"
        }
    })).unwrap();
    for (service, name, identity, count) in [(&a, "甲", "first", 3), (&b, "乙", "second", 5)] {
        let request = ReviewRequest {
            chapter_url: format!("{}/chapter", fixture.url),
            para_index: "7".into(),
            para_data: "token".into(),
            review_id: "r42".into(),
            ..Default::default()
        };
        let summary = service
            .get_summary(source.clone(), request.clone())
            .unwrap();
        assert_eq!(summary.counts.get(&1), Some(&count));
        assert_eq!(summary.keys.get(&1).map(String::as_str), Some(name));
        let detail = service
            .get_detail(source.clone(), request.clone(), 0)
            .unwrap();
        let expected = if cfg!(feature = "quickjs") {
            format!("{name}:identity={identity}")
        } else {
            name.into()
        };
        assert_eq!(detail.items[0].content.as_deref(), Some(expected.as_str()));
        assert_eq!(
            detail.items[0].avatar.as_deref(),
            Some(format!("{}/avatar.png", fixture.url).as_str())
        );
        assert_eq!(
            detail.next_page_url.as_deref(),
            Some(format!("{}/next", fixture.url).as_str())
        );
        assert!(detail.has_reply_url);
        let direct = service
            .get_detail(
                source.clone(),
                ReviewRequest {
                    detail_url: "/direct?chosen=1".into(),
                    ..request.clone()
                },
                2,
            )
            .unwrap();
        assert_eq!(direct.items.len(), 1);
        let replies = service.get_replies(source.clone(), request, 0).unwrap();
        assert_eq!(replies.items[0].content.as_deref(), Some(name));
        assert_eq!(
            replies.next_page_url.as_deref(),
            Some(format!("{}/reply?review=r42&page=2", fixture.url).as_str())
        );
        assert!(!replies.has_reply_url);

        let requests = runtime.block_on(async {
            let mut requests = Vec::new();
            for _ in 0..4 {
                requests.push(fixture.request().await);
            }
            requests
        });
        for request in &requests {
            let lower = request.to_ascii_lowercase();
            assert!(lower.contains(&format!("identity={identity}")), "{request}");
            assert!(lower.contains("x-source: header"), "{request}");
            assert!(
                !lower.contains(&format!(
                    "{}:",
                    legado_net::COOKIE_JAR_HEADER.to_ascii_lowercase()
                )),
                "{request}"
            );
        }
        assert!(requests[0].starts_with("GET /summary "));
        assert!(requests[1].starts_with("POST /detail?idx=7&data=token&page=1 "));
        assert!(requests[1].ends_with("\r\n\r\npayload"));
        assert!(requests[1].to_ascii_lowercase().contains("x-merge: option"));
        assert!(requests[2].starts_with("GET /direct?chosen=1 "));
        assert!(requests[3].starts_with("GET /reply?review=r42&page=1 "));
    }
    fixture.worker.join().unwrap();
}

#[cfg(feature = "quickjs")]
#[test]
fn js_summary_detail_and_replies_share_only_their_own_resources() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let source=BookSource {
        book_source_url:"https://same-review.test".into(),
        main_js:Some(r#"
            function getReviewSummary(chapter,book) {
                chapter=JSON.parse(chapter); book=JSON.parse(book);
                return JSON.stringify([{paraIndex:2,count:3,paraData:java.getCookie('https://same-review.test')+':'+book.name+':'+chapter.url}]);
            }
            function getReviewDetail(chapter,book,index,data,page) {
                chapter=JSON.parse(chapter); book=JSON.parse(book);
                return JSON.stringify({items:[{id:'c1',name:book.name,content:java.getCookie('https://same-review.test')+':'+chapter.url+':'+index+':'+data,
                    badge:'作者',replies:[{id:'r1',content:'回复'}]}],nextPageUrl:page<2?'more':null});
            }
        "#.into()),..Default::default()
    };
    for (engine, identity) in [(&first, "first"), (&second, "second")] {
        engine
            .network()
            .set_cookie("https://same-review.test", &format!("identity={identity}"))
            .unwrap();
        let service = service(engine, &runtime);
        let request = ReviewRequest {
            chapter_url: "https://same-review.test/chapter".into(),
            para_index: "2".into(),
            para_data: "正文😀".into(),
            book: Some(legado_core::models::Book {
                name: "实例书".into(),
                ..Default::default()
            }),
            ..Default::default()
        };
        let summary = service
            .get_summary(source.clone(), request.clone())
            .unwrap();
        assert_eq!(summary.counts.get(&2), Some(&3));
        assert_eq!(
            summary.keys.get(&2),
            Some(&format!(
                "identity={identity}:实例书:https://same-review.test/chapter"
            ))
        );
        let detail = service
            .get_detail(source.clone(), request.clone(), 1)
            .unwrap();
        assert_eq!(
            detail.items[0].content.as_deref(),
            Some(format!("identity={identity}:https://same-review.test/chapter:2:正文😀").as_str())
        );
        assert_eq!(detail.items[0].badges, vec!["作者"]);
        assert_eq!(detail.items[0].replies[0].content.as_deref(), Some("回复"));
        assert_eq!(detail.next_page_url.as_deref(), Some("more"));
        let reply = service.get_replies(source.clone(), request, 2).unwrap();
        assert_eq!(reply.items[0].content, detail.items[0].content);
        assert!(reply.next_page_url.is_none());
        assert!(!reply.has_reply_url);
    }
}
