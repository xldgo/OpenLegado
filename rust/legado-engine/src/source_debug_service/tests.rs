use super::*;
use crate::test_http_fixture::Fixture;
use legado_db::repository::Repository;

#[test]
fn test_format_elapsed_zeroish() {
    let start = Instant::now();
    let s = format_elapsed(start);
    assert!(s.starts_with('['));
    assert!(s.contains(':'));
}

#[test]
fn test_debug_log_item_json() {
    let item = DebugLogItem {
        state: 1000,
        msg: "[00:01.000] ︽正文页解析完成".into(),
    };
    let json = serde_json::to_string(&item).unwrap();
    assert!(json.contains("\"state\":1000"));
    assert!(json.contains("正文页解析完成"));
}

#[test]
fn test_is_abs_url() {
    assert!(is_abs_url("https://example.com/book/1"));
    assert!(is_abs_url("HTTP://a.com"));
    assert!(!is_abs_url("斗破苍穹"));
    assert!(!is_abs_url("++https://a.com/toc"));
}

use crate::explore_service::ExploreResources;
use crate::{EngineContext, OperationSlot};
use std::time::Duration;

fn service_for_engine(engine: &EngineContext, slot: &Arc<OperationSlot>) -> SourceDebugService {
    let runtime = tokio::runtime::Handle::current();
    let js = engine.js_resources().clone();
    let web_book = engine.web_book_state().clone();
    let rates = engine.rate_limiter();
    let network = engine.network().clone();
    let login = engine.source_login_cache().clone();
    let info = engine.source_info_map().clone();
    let setup = Arc::new(move |source: &BookSource| {
        let tag = &source.book_source_url;
        legado_fetcher::source_setup::book_source_js_setup_script(
            source,
            &info.snapshot(tag),
            login.get_login_header(tag).as_deref(),
            login.get_login_info(tag).as_deref(),
        )
    });
    let deps_setup = setup.clone();
    let source_info = engine.source_info_map().clone();
    let storage = engine.storage().clone();
    let deps = Arc::new(move || {
        let storage = storage.clone();
        let setup = deps_setup.clone();
        Ok(FetcherDeps::new(network.client()?)
            .with_js_resources(js.clone())
            .with_web_book_state(web_book.clone())
            .with_rate_limiter(rates.clone())
            .with_source_context(Arc::new(move |source| setup(source).ok()))
            .with_book_variable(Arc::new(move |book| {
                storage
                    .with_database(|db| {
                        Ok(legado_db::BookRepository::new(db.connection())
                            .find_by_url(book)?
                            .and_then(|b| b.variable))
                    })
                    .ok()
                    .flatten()
            })))
    });
    SourceDebugService::new(SourceDebugResources {
        storage: Some(engine.storage().clone()),
        deps: Some(deps),
        info: source_info.clone(),
        slot: slot.clone(),
        runtime: runtime.clone(),
        explore: Arc::new(ExploreService::new(ExploreResources {
            js: engine.js_resources().clone(),
            info: source_info,
            tasks: engine.tasks().clone(),
            runtime,
            setup,
        })),
    })
}

fn run_for_engine(
    engine: &EngineContext,
    slot: &Arc<OperationSlot>,
    source_url: &str,
    logs: Arc<Mutex<Vec<serde_json::Value>>>,
) -> Arc<DebugRun> {
    let service = service_for_engine(engine, slot);
    Arc::new(DebugRun {
        source_url: source_url.into(),
        start: Instant::now(),
        operation: slot.start().unwrap(),
        storage: Some(engine.storage().clone()),
        deps: service.resources.deps.clone(),
        runtime: service.resources.runtime.clone(),
        explore: service.resources.explore.clone(),
        info: engine.source_info_map().clone(),
        on_log: Mutex::new(Box::new(move |item| {
            logs.lock()
                .unwrap()
                .push(serde_json::to_value(item).unwrap());
            Ok(())
        })),
    })
}

fn seed(engine: &EngineContext, url: &str, name: &str) {
    let source: BookSource = serde_json::from_value(serde_json::json!({
        "bookSourceUrl":url,"bookSourceName":name,
        "searchUrl":format!("{url}/search"),
        "ruleSearch":{"bookList":".book","name":".name@text","bookUrl":"a@href"},
        "ruleExplore":{"bookList":".book","name":".name@text","bookUrl":"a@href"},
        "ruleBookInfo":{"name":".name@text","author":".author@text","tocUrl":".toc@href"},
        "ruleToc":{"chapterList":".chapter","chapterName":"a@text","chapterUrl":"a@href"},
        "ruleContent":{"content":".content@text","subContent":".sub@text"}
    }))
    .unwrap();
    engine
        .storage()
        .with_database(|db| BookSourceRepository::new(db.connection()).insert(&source))
        .unwrap();
}

#[tokio::test]
async fn real_debug_steps_and_logs_use_only_the_original_engine_and_cookie() {
    let mut fixture = Fixture::new(8, false, |request| {
        let identity = if request.contains("identity=first") {
            "甲"
        } else {
            "乙"
        };
        if request.starts_with("GET /search ") {
            format!(
                "<div class='book'><span class='name'>{identity}书</span><a href='/book'>书</a></div>"
            )
        } else if request.starts_with("GET /book ") {
            format!(
                "<span class='name'>{identity}书</span><span class='author'>作者</span><a class='toc' href='/toc'>目录</a>"
            )
        } else if request.starts_with("GET /toc ") {
            "<div class='chapter'><a href='/chapter'>第一章</a></div>".into()
        } else {
            format!("<div class='content'>{identity}实例正文</div>")
        }
    });
    for (identity, name) in [("first", "甲源"), ("second", "乙源")] {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine, &fixture.url, name);
        engine
            .network()
            .set_cookie("127.0.0.1", &format!("identity={identity}"))
            .unwrap();
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let logs = Arc::new(Mutex::new(Vec::new()));
        let run = run_for_engine(&engine, &slot, &fixture.url, logs.clone());
        run_debug(run, "关键字".into()).await;
        {
            let logs = logs.lock().unwrap();
            assert!(
                logs.iter().any(|log| log["state"] == 1000),
                "没有完成正文调试: {logs:?}"
            );
            assert!(
                logs.iter()
                    .any(|log| log["msg"].as_str().unwrap().contains(name))
            );
            let expected = if identity == "first" {
                "甲实例正文"
            } else {
                "乙实例正文"
            };
            assert!(
                logs.iter()
                    .any(|log| log["msg"].as_str().unwrap().contains(expected))
            );
        }
        for _ in 0..4 {
            assert!(
                fixture
                    .request()
                    .await
                    .contains(&format!("identity={identity}"))
            );
        }
        assert_eq!(engine.tasks().active_count(), 0);
        assert!(slot.current().is_none());
    }
    fixture.worker.join().unwrap();
}

#[tokio::test]
async fn replaced_real_debug_cannot_publish_to_or_clear_the_next_session() {
    let mut fixture = Fixture::new(1, true, |_| "<div class='content'>迟到正文</div>".into());
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    seed(&engine, &fixture.url, "原源");
    let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
    let old_logs = Arc::new(Mutex::new(Vec::new()));
    let old = run_for_engine(&engine, &slot, &fixture.url, old_logs.clone());
    let mut future = Box::pin(run_debug(old.clone(), format!("--{}/chapter", fixture.url)));
    tokio::select! { _ = fixture.request() => {}, _ = &mut future => panic!("请求应等待响应") }
    let count = old_logs.lock().unwrap().len();
    let next_logs = Arc::new(Mutex::new(Vec::new()));
    let next = run_for_engine(&engine, &slot, &fixture.url, next_logs.clone());
    fixture.release.send(()).unwrap();
    tokio::time::timeout(Duration::from_secs(5), future)
        .await
        .unwrap();
    assert_eq!(old_logs.lock().unwrap().len(), count);
    assert!(next.operation.is_active());
    next.log_debug(None, "新会话仍可发布", 1, false);
    assert_eq!(next_logs.lock().unwrap().len(), 1);
    drop(old);
    next.operation.finish();
    drop(next);
    assert_eq!(engine.tasks().active_count(), 0);
    fixture.worker.join().unwrap();
}

#[test]
fn closed_log_sink_cancels_only_its_own_session_without_reentrant_deadlock() {
    let engine = EngineContext::in_memory().unwrap();
    let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
    let operation = slot.start().unwrap();
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let _entered = runtime.enter();
    let service = service_for_engine(&engine, &slot);
    let run = DebugRun {
        source_url: "source".into(),
        start: Instant::now(),
        operation: operation.clone(),
        storage: None,
        deps: None,
        runtime: runtime.handle().clone(),
        explore: service.resources.explore.clone(),
        info: engine.source_info_map().clone(),
        on_log: Mutex::new(Box::new(|_| Err("sink 已关闭".into()))),
    };
    run.log_debug(None, "日志", 1, false);
    assert!(!operation.is_active());
    assert!(!engine.tasks().is_closed());
    run.log_debug(None, "迟到日志", 1, false);
    assert!(slot.start().unwrap().is_active());
}

#[tokio::test]
async fn debug_explore_uses_captured_dependencies_instead_of_the_ffi_host() {
    let mut fixture = Fixture::new(1, false, |_| {
        "<div class='book'><span class='name'>发现书</span><a href='/book'>书</a></div>".into()
    });
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, &fixture.url, "发现源");
    engine
        .network()
        .set_cookie("127.0.0.1", "identity=explore")
        .unwrap();
    let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
    let run = run_for_engine(
        &engine,
        &slot,
        &fixture.url,
        Arc::new(Mutex::new(Vec::new())),
    );
    let source = run.load_source(&fixture.url).unwrap();
    let json = serde_json::to_string(&source).unwrap();
    let url = format!("{}/explore", fixture.url);
    let result = tokio::task::spawn_blocking(move || run.explore_books(&json, &url))
        .await
        .unwrap()
        .unwrap();
    let books: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
    assert_eq!(books[0]["name"], "发现书");
    assert!(fixture.request().await.contains("identity=explore"));
    fixture.worker.join().unwrap();
}
#[tokio::test]
async fn worker_panic_reports_only_to_its_own_sink_and_releases_the_slot() {
    let engine = EngineContext::in_memory().unwrap();
    seed(&engine, "https://panic-debug.test", "异常源");
    let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
    let logs = Arc::new(Mutex::new(Vec::new()));
    let mut run = run_for_engine(&engine, &slot, "https://panic-debug.test", logs.clone());
    Arc::get_mut(&mut run).unwrap().deps = Some(Arc::new(|| panic!("调试任务异常夹具")));
    run_debug(run, "关键字".into()).await;
    assert!(
        logs.lock()
            .unwrap()
            .iter()
            .any(|log| log["state"] == -1
                && log["msg"].as_str().unwrap().starts_with("调试任务异常:"))
    );
    assert_eq!(engine.tasks().active_count(), 0);
    assert!(slot.current().is_none());
    assert!(slot.start().unwrap().is_active());
}
#[tokio::test]
async fn key_dispatch_executes_all_five_real_debug_routes() {
    for (route, count) in [(0, 4), (1, 3), (2, 2), (3, 1), (4, 4)] {
        let mut fixture = Fixture::new(count, false, |request| {
            if request.starts_with("GET /search ") || request.starts_with("GET /explore ") {
                "<div class='book'><span class='name'>测试书</span><a href='/book'>书</a></div>"
                    .into()
            } else if request.starts_with("GET /book ") {
                "<span class='name'>测试书</span><a class='toc' href='/toc'>目录</a>".into()
            } else if request.starts_with("GET /toc ") {
                "<div class='chapter'><a href='/chapter'>第一章</a></div>".into()
            } else {
                "<div class='content'>分流正文</div>".into()
            }
        });
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine, &fixture.url, "分流源");
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let logs = Arc::new(Mutex::new(Vec::new()));
        let key = match route {
            0 => "关键字".into(),
            1 => format!("{}/book", fixture.url),
            2 => format!("++{}/toc", fixture.url),
            3 => format!("--{}/chapter", fixture.url),
            _ => format!("分类::{}/explore", fixture.url),
        };
        let service = service_for_engine(&engine, &slot);
        let output = logs.clone();
        service
            .run(fixture.url.clone(), key, move |item| {
                output
                    .lock()
                    .unwrap()
                    .push(serde_json::to_value(item).unwrap());
                Ok(())
            })
            .await;
        {
            let messages = logs.lock().unwrap();
            assert!(
                messages.iter().any(|log| log["state"] == 1000),
                "入口 {route} 未完成: {messages:?}"
            );
        }
        for _ in 0..count {
            fixture.request().await;
        }
        fixture.worker.join().unwrap();
        assert_eq!(engine.tasks().active_count(), 0);
    }
}

#[cfg(feature = "quickjs")]
#[tokio::test]
async fn main_js_content_and_explore_share_only_the_original_cookie_capability() {
    let url = "https://same-debug.test";
    for identity in ["甲实例", "乙实例"] {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine, url, "JS 调试源");
        engine
            .network()
            .set_cookie(url, &format!("identity={identity}"))
            .unwrap();
        engine.storage().with_database(|db| {
            let repo = BookSourceRepository::new(db.connection());
            let mut source = repo.find_by_url(url)?.unwrap();
            source.main_js = Some(r#"
                function getContent(chapter,book,nextChapterUrl) { return java.getCookie('https://same-debug.test'); }
                function explore(url,page) { return [{name:java.getCookie('https://same-debug.test'),bookUrl:'https://same-debug.test/book'}]; }
            "#.into());
            repo.update(&source)
        }).unwrap();
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let logs = Arc::new(Mutex::new(Vec::new()));
        let run = run_for_engine(&engine, &slot, url, logs.clone());
        run_debug(run, format!("--{url}/chapter")).await;
        assert!(logs.lock().unwrap().iter().any(|log| log["state"] == 1000));
        assert!(
            logs.lock()
                .unwrap()
                .iter()
                .any(|log| log["msg"].as_str().unwrap().contains(identity))
        );
        let run = run_for_engine(&engine, &slot, url, Arc::new(Mutex::new(Vec::new())));
        let source = serde_json::to_string(&run.load_source(url).unwrap()).unwrap();
        let result = tokio::task::spawn_blocking(move || {
            run.explore_books(&source, "https://same-debug.test/explore")
        })
        .await
        .unwrap()
        .unwrap();
        let books: Vec<serde_json::Value> = serde_json::from_str(&result).unwrap();
        assert!(books[0]["name"].as_str().unwrap().contains(identity));
        assert_eq!(engine.tasks().active_count(), 0);
    }
}

#[tokio::test]
async fn public_service_cancel_and_closed_sink_keep_other_instances_active() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let a_slot = Arc::new(OperationSlot::new(first.tasks().clone()));
    let b_slot = Arc::new(OperationSlot::new(second.tasks().clone()));
    let a = service_for_engine(&first, &a_slot);
    let b = service_for_engine(&second, &b_slot);
    let a_operation = a_slot.start().unwrap();
    let b_operation = b_slot.start().unwrap();
    a.cancel();
    assert!(!a_operation.is_active());
    assert!(b_operation.is_active());
    drop(a_operation);

    // 已关闭回调只消费第一条失败事件，不回查其他实例的数据库或取消槽。
    let events = Arc::new(Mutex::new(Vec::new()));
    let output = events.clone();
    a.run(
        "https://missing-debug.test".into(),
        "关键字".into(),
        move |item| {
            output.lock().unwrap().push(item);
            Err("回调已关闭".into())
        },
    )
    .await;
    assert_eq!(events.lock().unwrap().len(), 1);
    assert_eq!(events.lock().unwrap()[0].state, -1);
    assert!(events.lock().unwrap()[0].msg.contains("未找到书源"));
    assert!(a_slot.current().is_none());
    assert_eq!(first.tasks().active_count(), 0);
    assert!(b_operation.is_active());
    b.cancel();
    assert!(!b_operation.is_active());
}
