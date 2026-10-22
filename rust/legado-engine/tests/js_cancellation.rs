//! 通过真实搜索入口观察取消后阻塞worker的实际退出。
#![cfg(feature = "quickjs")]
use legado_core::models::BookSource;
use legado_engine::{
    EngineContext,
    search_service::{SearchContext, search_single_source_owned},
};
use legado_fetcher::deps::FetcherDeps;
use std::{sync::Arc, time::Duration};

use legado_js::executor::QuickJsExecutor;
use legado_js::{
    JsEngine,
    cancellation::{CANCELLED, Scope},
};
use legado_parser::JsExecutor;

fn wait_started(engine: &EngineContext) {
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while !engine
        .js_resources()
        .http_resources()
        .cookies_for_url("https://cancel.test")
        .contains("started=yes")
    {
        assert!(std::time::Instant::now() < deadline, "JS尚未进入目标阶段");
        std::thread::sleep(Duration::from_millis(2));
    }
}

#[test]
fn main_js_serialization_cancel_releases_task_and_borrowed_bindings() {
    let engine = EngineContext::in_memory().unwrap();
    let config = legado_js::JsSourceConfig::new(
        "serialize-cancel".into(),
        r#"
function value(mode) {
    if(mode==='wait') { return {toJSON(){
        globalThis.retained='kept';
        java.setCookie('https://cancel.test','started=yes');
        while(true){}
    }}; }
    return [typeof book,globalThis.retained];
}"#
        .into(),
    );
    let task = Arc::new(engine.tasks().begin().unwrap());
    let weak = Arc::downgrade(&task);
    let resources = engine.js_resources().with_cancellation(task.clone());
    let mut source =
        legado_js::JsSourceEngine::new_quickjs_with_resources(config.clone(), &resources).unwrap();
    drop(resources);
    let (tx, rx) = std::sync::mpsc::channel();
    let worker = std::thread::spawn(move || {
        tx.send(source.call_function(
            "value",
            &[
                ("mode", legado_js::JsValue::from("wait")),
                ("book", legado_js::JsValue::from("old")),
            ],
        ))
        .unwrap();
    });
    wait_started(&engine);
    task.cancel();
    let result = rx.recv_timeout(Duration::from_secs(2)).unwrap();
    worker.join().unwrap();
    assert!(result.unwrap_err().to_string().contains(CANCELLED));
    drop(task);
    assert!(weak.upgrade().is_none(), "调用作用域不能延长取消任务寿命");
    let mut next =
        legado_js::JsSourceEngine::new_quickjs_with_resources(config, engine.js_resources())
            .unwrap();
    assert_eq!(
        next.call_function("value", &[("mode", legado_js::JsValue::from("read"))])
            .unwrap()
            .as_deref(),
        Some("[\"undefined\",\"kept\"]")
    );
}

#[test]
fn cached_and_fresh_executors_release_cancelled_tasks_and_keep_cache_reusable() {
    for lib in [
        None,
        Some(r#"{"lib":"globalThis.fromFresh=17;"}"#.to_string()),
    ] {
        let engine = EngineContext::in_memory().unwrap();
        let task = Arc::new(engine.tasks().begin().unwrap());
        let weak = Arc::downgrade(&task);
        let resources = engine.js_resources().with_cancellation(task.clone());
        let executor = QuickJsExecutor::new("https://cancel.test")
            .with_resources(resources)
            .with_js_lib(lib.clone());
        let (tx, rx) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            tx.send(executor.execute_js("globalThis.saved=7;java.setCookie('https://cancel.test','started=yes');while(true){}")).unwrap();
        });
        wait_started(&engine);
        task.cancel();
        let result = rx.recv_timeout(Duration::from_secs(2));
        worker.join().unwrap();
        assert!(result.unwrap().unwrap_err().contains(CANCELLED));
        drop(task);
        assert!(weak.upgrade().is_none(), "缓存VM仍强持旧任务");
        assert_eq!(engine.tasks().active_count(), 0);
        let next_task = engine.tasks().begin().unwrap();
        let next = QuickJsExecutor::new("https://cancel.test")
            .with_resources(engine.js_resources().with_cancellation(Arc::new(next_task)))
            .with_js_lib(lib.clone());
        assert_eq!(
            next.execute_js(if lib.is_some() {
                "fromFresh+1"
            } else {
                "saved+1"
            })
            .unwrap(),
            if lib.is_some() { "18" } else { "8" }
        );
    }
}

#[test]
fn queued_cached_execution_can_cancel_before_another_execution_unlocks() {
    let engine = EngineContext::in_memory().unwrap();
    let cached = engine
        .js_resources()
        .engine_cache()
        .get_or_create_with_resources("executor:queued", None, None, None, engine.js_resources())
        .unwrap()
        .engine;
    let held = cached.lock().unwrap();
    let task = Arc::new(engine.tasks().begin().unwrap());
    let executor = QuickJsExecutor::new("queued")
        .with_resources(engine.js_resources().with_cancellation(task.clone()));
    let (tx, rx) = std::sync::mpsc::channel();
    let worker = std::thread::spawn(move || {
        tx.send(executor.execute_js("1+1")).unwrap();
    });
    assert!(matches!(
        rx.recv_timeout(Duration::from_millis(30)),
        Err(std::sync::mpsc::RecvTimeoutError::Timeout)
    ));
    task.cancel();
    let result = rx.recv_timeout(Duration::from_secs(2));
    drop(held);
    worker.join().unwrap();
    assert!(result.unwrap().unwrap_err().contains(CANCELLED));
    assert_eq!(
        QuickJsExecutor::new("queued")
            .with_resources(engine.js_resources().clone())
            .execute_js("2+2")
            .unwrap(),
        "4"
    );
}

#[test]
fn cancelled_initialization_does_not_publish_an_incomplete_cached_vm() {
    let engine = EngineContext::in_memory().unwrap();
    let lib = "if(java.getCookie('https://cancel.test','once')!='yes'){java.setCookie('https://cancel.test','once=yes;started=yes');while(true){}}globalThis.initialized=17;";
    let task = Arc::new(engine.tasks().begin().unwrap());
    let executor = QuickJsExecutor::new("init-cancel")
        .with_resources(engine.js_resources().with_cancellation(task.clone()))
        .with_js_lib(Some(lib.into()));
    let (tx, rx) = std::sync::mpsc::channel();
    let worker = std::thread::spawn(move || {
        tx.send(executor.execute_js("initialized")).unwrap();
    });
    wait_started(&engine);
    task.cancel();
    let result = rx.recv_timeout(Duration::from_secs(2));
    worker.join().unwrap();
    assert!(result.unwrap().unwrap_err().contains(CANCELLED));
    let next = QuickJsExecutor::new("init-cancel")
        .with_resources(engine.js_resources().clone())
        .with_js_lib(Some(lib.into()));
    assert_eq!(next.execute_js("initialized").unwrap(), "17");
}

#[test]
fn compiled_and_byte_evaluation_respond_to_root_close_and_restore_binding() {
    for bytes in [false, true] {
        let engine = EngineContext::in_memory().unwrap();
        let other = EngineContext::in_memory().unwrap();
        let unaffected = other.tasks().begin().unwrap();
        let task = Arc::new(engine.tasks().begin().unwrap());
        let vm = Arc::new(
            engine
                .js_resources()
                .create_engine(legado_js::SandboxConfig::default())
                .unwrap(),
        );
        let next_vm = vm.clone();
        let (tx, rx) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            let _scope = Scope::enter(Some(task));
            let script = "java.setCookie('https://cancel.test','started=yes');while(true){}";
            let result = if bytes {
                vm.eval_bytes(script, &[]).map(|_| String::new())
            } else {
                vm.execute_compiled(&vm.compile(script).unwrap())
            };
            tx.send(result.map_err(|e| e.to_string())).unwrap();
        });
        wait_started(&engine);
        engine.tasks().request_cancel();
        let result = rx.recv_timeout(Duration::from_secs(2));
        worker.join().unwrap();
        assert!(result.unwrap().unwrap_err().contains(CANCELLED));
        assert_eq!(next_vm.eval("1+1").unwrap(), "2");
        assert!(!unaffected.is_cancelled());
        assert_eq!(engine.tasks().active_count(), 0);
    }
}

#[test]
fn nested_bindings_restore_on_normal_exit_and_unwind() {
    let engine = EngineContext::in_memory().unwrap();
    let cancelled = Arc::new(engine.tasks().begin().unwrap());
    let live = Arc::new(engine.tasks().begin().unwrap());
    cancelled.cancel();
    let outer = Scope::enter(Some(cancelled));
    assert!(legado_js::cancellation::check().is_err());
    let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let _inner = Scope::enter(Some(live));
        assert!(legado_js::cancellation::check().is_ok());
        panic!("验证异常恢复");
    }));
    assert!(legado_js::cancellation::check().is_err());
    drop(outer);
    assert!(legado_js::cancellation::current().is_none());
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn cancelling_search_stops_the_actual_js_worker() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let task = engine.tasks().begin().unwrap();
    let context = SearchContext::new(
        FetcherDeps::new(engine.network().client().unwrap())
            .with_js_resources(engine.js_resources().clone()),
        None,
    )
    .with_task(task.clone());
    let source = BookSource {
        book_source_url: "https://cancel.test".into(),
        main_js: Some(
            "function search(){java.setCookie('https://cancel.test','started=yes');while(true){}}"
                .into(),
        ),
        ..Default::default()
    };
    let worker = tokio::spawn(async move {
        search_single_source_owned(context, &source, "小说", 1, false).await
    });
    tokio::time::timeout(Duration::from_secs(3), async {
        while !engine
            .js_resources()
            .http_resources()
            .cookies_for_url("https://cancel.test")
            .contains("started=yes")
        {
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
    })
    .await
    .expect("脚本未进入循环");
    task.cancel();
    drop(task);
    assert!(worker.await.unwrap().is_err());
    tokio::time::timeout(Duration::from_millis(400), async {
        while engine.tasks().active_count() != 0 {
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
    })
    .await
    .expect("搜索已返回但JS worker仍在运行");
}
