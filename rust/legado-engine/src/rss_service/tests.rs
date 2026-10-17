use super::*;
use crate::{EngineContext, test_http_fixture::Fixture};
use std::sync::Arc;

#[test]
fn source_and_reader_operations_keep_their_own_storage_and_do_not_retain_the_root() {
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    let weak = Arc::downgrade(&first);
    let a = RssService::new(Some(first.storage().clone()));
    let b = RssService::new(Some(second.storage().clone()));
    let url = "https://rss-service.test/feed";
    let source = RssSource {
        source_url: url.into(),
        source_name: "甲".into(),
        ..Default::default()
    };
    a.add_rss_source_entity(source.clone()).unwrap();
    b.add_rss_source_entity(RssSource {
        source_name: "乙".into(),
        ..source.clone()
    })
    .unwrap();
    a.update_rss_source_entity(RssSource {
        source_name: "甲更新".into(),
        ..source.clone()
    })
    .unwrap();
    assert_eq!(b.list_rss_sources().unwrap()[0].source_name, "乙");
    assert!(
        a.update_rss_source_entity(RssSource {
            source_url: "missing".into(),
            ..source.clone()
        })
        .is_err()
    );
    assert!(matches!(
        RssService::new(None).update_rss_source_entity(RssSource::default()),
        Err(LegadoError::Ffi(_))
    ));
    assert!(RssService::new(None).list_rss_sources().is_err());
    assert_eq!(
        a.import_rss_sources(vec![RssSource {
            source_url: "default".into(),
            source_group: Some("legado".into()),
            ..source.clone()
        }])
        .unwrap(),
        1
    );
    assert_eq!(a.delete_default_rss_sources().unwrap(), 1);
    assert_eq!(a.list_rss_sources().unwrap().len(), 1);
    let link = "https://rss-service.test/article";
    let time = a.add_rss_star(url, "甲收藏", link).unwrap();
    b.add_rss_star(url, "乙收藏", link).unwrap();
    a.mark_read(url, "甲已读", Some(link)).unwrap();
    b.mark_read(url, "乙已读", Some(link)).unwrap();
    drop(first);
    assert!(weak.upgrade().is_none());
    assert_eq!(a.get_rss_stars().unwrap()[0].star_time, time);
    assert_eq!(b.get_rss_stars().unwrap()[0].title, "乙收藏");
    a.clear_rss_articles(url).unwrap();
    assert!(a.is_read(link).unwrap());
    assert!(a.is_read_by_title(url, "甲已读").unwrap());
    assert_eq!(a.list_records(Some(1)).unwrap().len(), 1);
    assert_eq!(b.list_records_by_origin(url, None).unwrap().len(), 1);
    a.clear_read_records().unwrap();
    assert_eq!(a.read_record_count().unwrap(), 0);
    assert_eq!(b.read_record_count().unwrap(), 1);
    a.delete_rss_star(link).unwrap();
    assert!(!a.is_rss_starred(link).unwrap());
    assert!(b.is_rss_starred(link).unwrap());
    a.delete_rss_source(url).unwrap();
    assert!(a.list_rss_sources().unwrap().is_empty());
    assert_eq!(b.list_rss_sources().unwrap().len(), 1);
}

#[test]
fn feed_cache_and_cookie_write_gates_use_the_injected_instance() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a = RssService::new(Some(first.storage().clone()));
    let b = RssService::new(Some(second.storage().clone()));
    let mut fixture = Fixture::with_response_headers(
        3,
        false,
        "application/rss+xml",
        &[("Set-Cookie", "received=1; Path=/")],
        |request| {
            let title = if request.contains("identity=first") {
                "甲文章"
            } else {
                "乙文章"
            };
            format!(
                r#"<?xml version="1.0"?><rss version="2.0"><channel><title>测试订阅</title><item><title>{title}</title><link>https://rss-service.test/article</link><description>正文摘要</description></item></channel></rss>"#
            )
        },
    );
    let source = RssSource {
        source_url: fixture.url.clone(),
        cache_first: true,
        enabled_cookie_jar: Some(false),
        ..Default::default()
    };
    a.add_rss_source_entity(source.clone()).unwrap();
    b.add_rss_source_entity(RssSource {
        cache_first: false,
        enabled_cookie_jar: None,
        ..source.clone()
    })
    .unwrap();
    first
        .network()
        .set_cookie("127.0.0.1", "identity=first")
        .unwrap();
    second
        .network()
        .set_cookie("127.0.0.1", "identity=second")
        .unwrap();
    assert_eq!(
        a.fetch_rss_articles(&fixture.url, first.network(), runtime.handle())
            .unwrap()[0]
            .title,
        "甲文章"
    );
    assert!(
        !first
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_cookie_string(&fixture.url)
            .contains("received=1")
    );
    assert_eq!(
        a.fetch_rss_articles(&fixture.url, first.network(), runtime.handle())
            .unwrap()[0]
            .title,
        "甲文章"
    );
    assert_eq!(
        b.fetch_rss_articles(&fixture.url, second.network(), runtime.handle())
            .unwrap()[0]
            .title,
        "乙文章"
    );
    assert!(
        !second
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_cookie_string(&fixture.url)
            .contains("received=1")
    );
    a.clear_rss_articles(&fixture.url).unwrap();
    a.update_rss_source_entity(RssSource {
        enabled_cookie_jar: Some(true),
        ..source
    })
    .unwrap();
    assert_eq!(
        a.fetch_rss_articles(&fixture.url, first.network(), runtime.handle())
            .unwrap()[0]
            .title,
        "甲文章"
    );
    assert!(
        first
            .network()
            .cookie_store()
            .read()
            .unwrap()
            .get_cookie_string(&fixture.url)
            .contains("received=1")
    );
    let requests = runtime.block_on(async {
        let mut requests = Vec::new();
        for _ in 0..3 {
            requests.push(fixture.request().await);
        }
        requests
    });
    for (index, request) in requests.iter().enumerate() {
        let lower = request.to_ascii_lowercase();
        assert!(request.starts_with("GET / "));
        assert!(!lower.contains("cookiejar:"));
        assert!(lower.contains(if index == 1 {
            "identity=second"
        } else {
            "identity=first"
        }));
    }
    fixture.worker.join().unwrap();
}

#[test]
fn invalid_feed_fallback_stays_unicode_safe_and_cache_write_failure_is_nonfatal() {
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let engine = EngineContext::in_memory().unwrap();
    let service = RssService::new(Some(engine.storage().clone()));
    let mut fixture = Fixture::new(2, false, |_| "无效订阅😀".repeat(100));
    service
        .add_rss_source_entity(RssSource {
            source_url: fixture.url.clone(),
            cache_first: true,
            ..Default::default()
        })
        .unwrap();
    engine.storage().with_database(|db| {
        db.connection().execute_batch("CREATE TRIGGER reject_rss_cache BEFORE INSERT ON rssArticles BEGIN SELECT RAISE(FAIL, '拒绝缓存写入'); END;")
            .map_err(|e| LegadoError::Database(e.to_string()))
    }).unwrap();
    for _ in 0..2 {
        let articles = service
            .fetch_rss_articles(&fixture.url, engine.network(), runtime.handle())
            .unwrap();
        assert_eq!(articles.len(), 1);
        assert_eq!(articles[0].title, fixture.url);
        assert_eq!(articles[0].link, fixture.url);
        assert_eq!(
            articles[0].description.as_ref().unwrap().chars().count(),
            200
        );
        assert!(articles[0].pub_date.is_none());
        assert!(articles[0].image_url.is_none());
        assert!(runtime.block_on(fixture.request()).starts_with("GET / "));
    }
    fixture.worker.join().unwrap();
}
