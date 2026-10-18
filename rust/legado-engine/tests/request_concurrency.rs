//! 真实网络/应用服务验证配置驱动的在途数量、快照与取消，不读取源码。
use legado_core::{
    models::{
        BookSource,
        rule::{SearchRule, TocRule},
    },
    web_book::BookSourceFetcher,
};
use legado_engine::search_service::{SearchResources, SearchService};
use legado_engine::source_switch_service::{
    SourceSwitchService, SwitchResources, SwitchSearchOptions,
};
use legado_engine::{EngineContext, OperationSlot, SearchTasks, SourceSwitchState};
use legado_fetcher::{deps::FetcherDeps, web_book::RealBookSourceFetcher};
use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};
use std::time::Duration;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
    sync::Semaphore,
};

struct Http {
    url: String,
    started: Arc<AtomicUsize>,
    active: Arc<AtomicUsize>,
    peak: Arc<AtomicUsize>,
    gate: Arc<Semaphore>,
    worker: tokio::task::JoinHandle<()>,
}
impl Http {
    async fn new() -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let started = Arc::new(AtomicUsize::new(0));
        let active = Arc::new(AtomicUsize::new(0));
        let peak = Arc::new(AtomicUsize::new(0));
        let gate = Arc::new(Semaphore::new(0));
        let (count, inflight, max, permit) =
            (started.clone(), active.clone(), peak.clone(), gate.clone());
        let worker = tokio::spawn(async move {
            let mut workers = tokio::task::JoinSet::new();
            loop {
                let Ok((mut socket, _)) = listener.accept().await else {
                    break;
                };
                let (count, inflight, max, permit) =
                    (count.clone(), inflight.clone(), max.clone(), permit.clone());
                workers.spawn(async move {
                    let mut head = Vec::new();
                    while !head.ends_with(b"\r\n\r\n") {
                        let mut byte = [0];
                        if socket.read_exact(&mut byte).await.is_err() { return; }
                        head.push(byte[0]);
                        assert!(head.len() < 16384);
                    }
                    let request = String::from_utf8(head).unwrap();
                    let path = request.split_whitespace().nth(1).unwrap();
                    struct Active(Arc<AtomicUsize>);
                    impl Drop for Active {
                        fn drop(&mut self) { self.0.fetch_sub(1, Ordering::SeqCst); }
                    }
                    let _active;
                    let body = if path == "/toc" {
                        concat!(
                            "<a class=chapter href=/c0>零</a>",
                            "<a class=next href=/page1>下一页</a>",
                            "<a class=next href=/page2>下一页</a>",
                            "<a class=next href=/page3>下一页</a>",
                        ).to_string()
                    } else {
                        let n = inflight.fetch_add(1, Ordering::SeqCst) + 1;
                        _active = Active(inflight);
                        max.fetch_max(n, Ordering::SeqCst);
                        count.fetch_add(1, Ordering::SeqCst);
                        let Ok(release) = permit.acquire().await else { return; };
                        release.forget();
                        format!(
                            r#"<div class=book><a class=name href="/book">测试书</a><span class=author>作者</span></div><a class=chapter href=/c{path}>章</a>"#
                        )
                    };
                    let response = format!(
                        "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(response.as_bytes()).await;
                });
                while workers.try_join_next().is_some() {}
            }
        });
        Self {
            url,
            started,
            active,
            peak,
            gate,
            worker,
        }
    }
    async fn started(&self, n: usize) {
        tokio::time::timeout(Duration::from_secs(5), async {
            while self.started.load(Ordering::SeqCst) < n {
                tokio::time::sleep(Duration::from_millis(2)).await;
            }
        })
        .await
        .expect("真实HTTP任务未进入预期并发");
    }
    async fn held(&self, n: usize) {
        self.started(n).await;
        tokio::time::sleep(Duration::from_millis(60)).await;
        assert_eq!(self.started.load(Ordering::SeqCst), n, "队列不应超额派发");
    }
}
impl Drop for Http {
    fn drop(&mut self) {
        self.gate.close();
        self.worker.abort();
    }
}
fn config(engine: &EngineContext, n: usize) {
    engine
        .storage()
        .with_database(|db| {
            legado_db::CacheRepository::new(db.connection()).put(
                "config:threadCount",
                &n.to_string(),
                0,
            )
        })
        .unwrap();
}
fn sources(engine: &EngineContext, url: &str) -> Vec<String> {
    let items: Vec<_> = (0..4)
        .map(|i| BookSource {
            book_source_url: format!("{url}/source{i}"),
            book_source_name: format!("源{i}"),
            enabled: true,
            search_url: Some(format!("{url}/search{i}")),
            rule_search: Some(SearchRule {
                book_list: Some(".book".into()),
                name: Some(".name".into()),
                author: Some(".author".into()),
                book_url: Some(".name@href".into()),
                ..Default::default()
            }),
            ..Default::default()
        })
        .collect();
    engine
        .storage()
        .with_database(|db| {
            legado_db::BookSourceRepository::new(db.connection()).insert_batch(&items)
        })
        .unwrap();
    items.into_iter().map(|s| s.book_source_url).collect()
}
fn search(engine: &EngineContext) -> SearchService {
    let js = engine.js_resources().clone();
    let rates = engine.rate_limiter();
    SearchService::new(SearchResources {
        storage: Some(engine.storage().clone()),
        network: engine.network().clone(),
        searches: Arc::new(SearchTasks::new(engine.tasks().clone())),
        tasks: engine.tasks().clone(),
        runtime: tokio::runtime::Handle::current(),
        prepare: Arc::new(move |client| {
            FetcherDeps::new(client)
                .with_js_resources(js.clone())
                .with_rate_limiter(rates.clone())
        }),
    })
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn search_concurrency_is_a_batch_snapshot_and_next_batch_reads_new_value() {
    let http = Http::new().await;
    let engine = EngineContext::in_memory().unwrap();
    let urls = sources(&engine, &http.url);
    config(&engine, 2);
    let service = search(&engine);
    let first = service.clone();
    let selected = urls.clone();
    let worker = tokio::task::spawn_blocking(move || {
        first.multi_source_search_selected("测试书", &selected)
    });
    http.held(2).await;
    config(&engine, 1);
    http.gate.add_permits(1);
    http.started(3).await;
    assert!(http.active.load(Ordering::SeqCst) <= 2);
    http.gate.add_permits(3);
    let results = worker.await.unwrap().unwrap();
    assert_eq!(results.len(), 4);
    assert_eq!(http.peak.load(Ordering::SeqCst), 2);
    http.peak.store(0, Ordering::SeqCst);
    let worker =
        tokio::task::spawn_blocking(move || service.search_books_selected("测试书", &urls));
    http.held(5).await;
    http.gate.add_permits(4);
    assert_eq!(worker.await.unwrap().unwrap().len(), 4);
    assert_eq!(http.peak.load(Ordering::SeqCst), 1);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn source_checks_use_config_preserve_order_and_cancel_without_dispatching_queue() {
    use legado_engine::source_check_service::{SourceCheckResources, SourceCheckService};
    let http = Http::new().await;
    let engine = EngineContext::in_memory().unwrap();
    let urls = sources(&engine, &http.url);
    config(&engine, 2);
    let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
    let service = SourceCheckService::new(SourceCheckResources {
        storage: Some(engine.storage().clone()),
        network: engine.network().clone(),
        tasks: engine.tasks().clone(),
        slot: slot.clone(),
        runtime: tokio::runtime::Handle::current(),
    });
    let worker = tokio::spawn(async move {
        let mut events = Vec::new();
        service
            .run_check_sources_selected(
                urls,
                legado_net::source_checker::CheckerConfig {
                    check_toc: false,
                    check_content: false,
                    ..Default::default()
                },
                |event| {
                    events.push(event);
                    Ok(())
                },
            )
            .await;
        events
    });
    http.held(2).await;
    http.gate.add_permits(4);
    let events = worker.await.unwrap();
    assert_eq!(events.len(), 4);
    assert!(
        events.iter().all(|event| event.result.search_ok),
        "{events:?}"
    );
    assert_eq!(
        events.iter().map(|event| event.index).collect::<Vec<_>>(),
        vec![0, 1, 2, 3]
    );
    assert!(events[3].is_last);
    assert_eq!(http.peak.load(Ordering::SeqCst), 2);
    // 第二批停止后只释放已入队请求，不再派发第三项或发布迟到结果。
    let selected = (0..4).map(|i| format!("{}/source{i}", http.url)).collect();
    let service = SourceCheckService::new(SourceCheckResources {
        storage: Some(engine.storage().clone()),
        network: engine.network().clone(),
        tasks: engine.tasks().clone(),
        slot: slot.clone(),
        runtime: tokio::runtime::Handle::current(),
    });
    let worker = tokio::spawn(async move {
        let mut events = Vec::new();
        service
            .run_check_sources_selected(
                selected,
                legado_net::source_checker::CheckerConfig {
                    check_toc: false,
                    check_content: false,
                    ..Default::default()
                },
                |event| {
                    events.push(event);
                    Ok(())
                },
            )
            .await;
        events
    });
    http.held(6).await;
    slot.cancel();
    assert!(worker.await.unwrap().is_empty());
    http.gate.add_permits(2);
    tokio::time::sleep(Duration::from_millis(40)).await;
    assert_eq!(http.started.load(Ordering::SeqCst), 6);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn toc_pages_use_injected_limit_and_keep_page_order() {
    let http = Http::new().await;
    let engine = EngineContext::in_memory().unwrap();
    config(&engine, 2);
    let snapshot = legado_engine::request_settings::thread_count(Some(engine.storage())).unwrap();
    let deps =
        FetcherDeps::new(engine.network().client().unwrap()).with_request_concurrency(snapshot);
    let source = BookSource {
        book_source_url: http.url.clone(),
        rule_toc: Some(TocRule {
            chapter_list: Some(".chapter".into()),
            chapter_name: Some("text".into()),
            chapter_url: Some("href".into()),
            next_toc_url: Some(".next@href".into()),
            ..Default::default()
        }),
        ..Default::default()
    };
    let url = format!("{}/toc", http.url);
    let worker = tokio::task::spawn_blocking(move || {
        tokio::runtime::Handle::current()
            .block_on(RealBookSourceFetcher::with_deps(deps).get_chapters(&source, &url))
    });
    http.held(2).await;
    config(&engine, 1);
    http.gate.add_permits(3);
    let chapters = worker.await.unwrap().unwrap();
    assert_eq!(chapters.len(), 4);
    assert!(chapters[1].url.contains("page1"));
    assert!(chapters[2].url.contains("page2"));
    assert!(chapters[3].url.contains("page3"));
    assert_eq!(http.peak.load(Ordering::SeqCst), 2);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn switch_search_uses_configured_concurrency() {
    let http = Http::new().await;
    let engine = EngineContext::in_memory().unwrap();
    let urls = sources(&engine, &http.url);
    config(&engine, 2);
    let service = SourceSwitchService::new(SwitchResources {
        storage: Some(engine.storage().clone()),
        factory: None,
        state: Arc::new(SourceSwitchState::new(engine.tasks().clone())),
        network: engine.network().clone(),
        web_book: engine.web_book_state().clone(),
        js: engine.js_resources().clone(),
        runtime: tokio::runtime::Handle::current(),
        search: Arc::new(|request| {
            Box::pin(async move {
                request
                    .client
                    .get(&request.source.search_url.unwrap(), None)
                    .await?;
                Ok(Vec::new())
            })
        }),
    })
    .start_search()
    .unwrap();
    let worker = tokio::task::spawn_blocking(move || {
        service.search_alternative_sources_selected(
            "测试书",
            "作者",
            &urls,
            SwitchSearchOptions {
                force_refresh: true,
                ..Default::default()
            },
        )
    });
    http.held(2).await;
    http.gate.add_permits(4);
    assert!(worker.await.unwrap().is_ok());
    assert_eq!(http.peak.load(Ordering::SeqCst), 2);
}
