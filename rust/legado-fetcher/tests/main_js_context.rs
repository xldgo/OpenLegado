//! mainJs正式编排入口的对象与书源上下文回归。— Codex + Rust
#![cfg(feature = "quickjs")]

use legado_core::models::{Book, BookChapter, BookSource};
use legado_fetcher::web_book::build_js_orchestrator;
use legado_js::JsResources;
use serde_json::{Value, json};
use std::sync::Arc;

#[test]
fn source_context_is_ready_before_main_js_and_refreshes_with_configuration() {
    let resources = Arc::new(JsResources::default());
    let mut source = BookSource {
        book_source_url: "https://source.example".into(),
        book_source_name: "原名".into(),
        main_js: Some(
            r#"
var initialName = source.bookSourceName;
var source = { bookSourceUrl:'https://script.example' };
function getContent(chapter, book, nextChapterUrl) {
    sourceApi.put('token','kept');
    cache.put('main-js-cache','cached');
    cookie.setCookie('https://cookie.example','session=ok');
    return JSON.stringify({
        initialName:initialName, sourceName:sourceApi.bookSourceName,
        configuredUrl:source.bookSourceUrl, persistedUrl:sourceApi.getKey(),
        token:sourceApi.get('token'), cached:cache.get('main-js-cache'),
        cookie:cookie.getCookie('https://cookie.example','session')
    });
}
"#
            .into(),
        ),
        ..Default::default()
    };
    for name in ["原名", "新名"] {
        source.book_source_name = name.into();
        let mut engine = build_js_orchestrator(&resources, &source).unwrap().unwrap();
        let content = engine
            .get_content(&source, &BookChapter::default(), &Book::default(), None)
            .unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&content).unwrap(),
            json!({
                "initialName":name, "sourceName":name,
                "configuredUrl":"https://script.example",
                "persistedUrl":"https://source.example",
                "token":"kept", "cached":"cached", "cookie":"ok"
            })
        );
    }
    let other = Arc::new(JsResources::default());
    source.main_js = Some("function getContent(){return JSON.stringify([sourceApi.get('token'),cache.get('main-js-cache'),cookie.getCookie('https://cookie.example','session')]);}".into());
    let mut engine = build_js_orchestrator(&other, &source).unwrap().unwrap();
    let content = engine
        .get_content(&source, &BookChapter::default(), &Book::default(), None)
        .unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&content).unwrap(),
        json!(["", null, ""])
    );
}

#[test]
fn book_and_chapter_objects_reach_detail_toc_content_and_reviews() {
    let source = BookSource {
        book_source_url: "https://source.example".into(),
        main_js: Some(r#"
function getBookInfo(book){return {name:book.name,author:book.author};}
function getChapters(book){return [{title:book.name,url:book.bookUrl+'/1'}];}
function getContent(chapter,book,nextChapterUrl){
    return JSON.stringify({book:book.name,chapter:chapter.title,index:chapter.index,
        vip:chapter.isVip,volume:chapter.isVolume,bookUrl:book.bookUrl,
        groups:JSON.parse(book.variable).groups,next:nextChapterUrl,
        reverse:book.readConfig.reverseToc});
}
function getReviewSummary(chapter,book){return [{paraIndex:chapter.index,count:1,paraData:book.name}];}
function getReviewDetail(chapter,book,paraIndex,paraData,page){return {items:[],nextPageUrl:book.bookUrl+'/'+chapter.index+'/'+page};}
"#.into()),
        ..Default::default()
    };
    let book = Book {
        name: "书名😀".into(),
        author: "作者".into(),
        book_url: "https://source.example/book".into(),
        variable: Some(r#"{"groups":["一",2,true,null]}"#.into()),
        read_config: Some(legado_core::models::book::ReadConfig {
            reverse_toc: true,
            ..Default::default()
        }),
        ..Default::default()
    };
    let chapter = BookChapter {
        title: "章节😀".into(),
        url: "https://source.example/book/1".into(),
        index: 7,
        is_vip: true,
        ..Default::default()
    };
    let mut engine = build_js_orchestrator(&Arc::new(JsResources::default()), &source)
        .unwrap()
        .unwrap();
    let info = engine.get_book_info(&source, &book, false).unwrap();
    assert_eq!(info.name, book.name);
    assert_eq!(info.author.as_deref(), Some("作者"));
    let chapters = engine.get_chapter_list(&source, &book).unwrap();
    assert_eq!(chapters[0]["title"], book.name);
    assert_eq!(chapters[0]["url"], "https://source.example/book/1");
    for next in [None, Some("https://source.example/book/2")] {
        let content = engine.get_content(&source, &chapter, &book, next).unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&content).unwrap(),
            json!({
                "book":book.name,"chapter":chapter.title,"index":7,"vip":true,"volume":false,
                "bookUrl":book.book_url,"groups":["一",2,true,null],"next":next,"reverse":true
            })
        );
    }
    let summary = engine.get_review_summary(&book, &chapter).unwrap();
    assert_eq!(summary.counts, vec![(7, 1)]);
    let detail = engine
        .get_review_detail(&book, &chapter, 7, "段落", 2)
        .unwrap();
    assert_eq!(
        detail.next_page_url.as_deref(),
        Some("https://source.example/book/7/2")
    );
    let mut optional_source = source.clone();
    for (script, has_error) in [
        ("function unrelated(){}", false),
        (
            "function getReviewSummary(){return missingSummaryValue;}",
            true,
        ),
    ] {
        optional_source.main_js = Some(script.into());
        let mut engine = build_js_orchestrator(&Arc::new(JsResources::default()), &optional_source)
            .unwrap()
            .unwrap();
        let result = engine.get_review_summary(&book, &chapter);
        if has_error {
            assert!(
                result
                    .unwrap_err()
                    .to_string()
                    .contains("missingSummaryValue")
            );
        } else {
            assert!(result.unwrap().counts.is_empty());
        }
    }
}
