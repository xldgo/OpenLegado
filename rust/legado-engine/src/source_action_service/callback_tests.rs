use super::*;
use crate::EngineContext;
use legado_core::models::{Book, BookChapter};
use legado_db::{
    BookChapterRepository, BookRepository, BookSourceRepository, repository::Repository,
};

fn prepare(engine: &EngineContext, url: &str, name: &str, script: &str) {
    engine
        .storage()
        .with_database(|db| {
            let source: BookSource = serde_json::from_value(serde_json::json!({
                "bookSourceUrl":url, "eventListener":true, "ruleContent":{"callBackJs":script}
            }))?;
            BookSourceRepository::new(db.connection()).insert(&source)?;
            BookRepository::new(db.connection()).insert(&Book {
                book_url: "https://callback-book.test".into(),
                name: name.into(),
                origin: url.into(),
                ..Default::default()
            })?;
            BookChapterRepository::new(db.connection()).insert_batch(&[BookChapter {
                book_url: "https://callback-book.test".into(),
                title: name.into(),
                index: 1,
                url: format!("{url}/chapter"),
                ..Default::default()
            }])?;
            Ok(())
        })
        .unwrap();
}

#[test]
fn callback_fallbacks_keep_original_query_order_and_feature_errors() {
    let engine = EngineContext::in_memory().unwrap();
    let service = super::tests::service(&engine);
    let tasks = engine.tasks();
    let book = "https://callback-book.test";
    assert!(
        matches!(service.source_call_back_btn(tasks, "click", book, None, None), Err(LegadoError::Database(e)) if e.contains("书籍不存在"))
    );
    engine
        .storage()
        .with_database(|db| {
            BookRepository::new(db.connection()).insert(&Book {
                book_url: book.into(),
                origin: "https://callback.test".into(),
                ..Default::default()
            })
        })
        .unwrap();
    // 缺源、监听关闭、空脚本依次短路；即使提供缺失章节也不执行JS。
    for source in [
        None,
        Some(
            serde_json::json!({"bookSourceUrl":"https://callback.test", "eventListener":false, "ruleContent":{"callBackJs":"true"}}),
        ),
        Some(
            serde_json::json!({"bookSourceUrl":"https://callback.test", "eventListener":true, "ruleContent":{"callBackJs":" "}}),
        ),
    ] {
        if let Some(source) = source {
            engine
                .storage()
                .with_database(|db| {
                    BookSourceRepository::new(db.connection())
                        .update(&serde_json::from_value(source)?)
                })
                .unwrap();
        }
        let out = service
            .source_call_back_btn(tasks, "click", book, Some(99), Some(""))
            .unwrap();
        assert!(!out.invoked && !out.js_true && out.raw.is_empty() && out.actions.is_empty());
        assert_eq!(tasks.active_count(), 0);
    }
    prepare(
        &engine,
        "https://callback.test",
        "书",
        "chapter === null && result === null && event === 'click'",
    );
    #[cfg(feature = "quickjs")]
    {
        let out = service
            .source_call_back_btn(tasks, "click", book, Some(99), None)
            .unwrap();
        assert!(out.invoked && out.js_true);
    }
    #[cfg(not(feature = "quickjs"))]
    assert!(
        service
            .source_call_back_btn(tasks, "click", book, None, None)
            .unwrap_err()
            .to_string()
            .contains("QuickJS engine not enabled")
    );
    tasks.cancel();
    assert!(matches!(
        service.source_call_back_btn(tasks, "click", "missing", None, None),
        Err(LegadoError::Ffi(_))
    ));
    assert_eq!(tasks.active_count(), 0);
}

#[cfg(feature = "quickjs")]
#[test]
fn callback_cancellation_keeps_worker_registered_and_other_instance_actions_intact() {
    use crate::test_http_fixture::Fixture;
    use std::time::Duration;
    let mut fixture = Fixture::new(1, true, |_| "继续".into());
    let first = Arc::new(EngineContext::in_memory().unwrap());
    let second = EngineContext::in_memory().unwrap();
    prepare(
        &first,
        &fixture.url,
        "甲",
        &format!(
            "java.copyText(book.name);java.ajax('{}');java.copyText('迟到动作');true",
            fixture.url
        ),
    );
    prepare(
        &second,
        &fixture.url,
        "乙",
        "java.copyText(event+':'+book.name+':'+chapter.title+':'+result+':'+java.getVariable('identity'));java.copyText('第二条');true",
    );
    first
        .network()
        .set_cookie(
            &legado_net::cookie_store::normalize_cookie_key(&fixture.url),
            "identity=first",
        )
        .unwrap();
    first
        .js_resources()
        .http_resources()
        .put_headers(&fixture.url, [("X-Instance".into(), "first".into())].into());
    second
        .js_resources()
        .variables()
        .set_variable("identity", "second")
        .unwrap();
    let tasks = first.tasks().clone();
    let running_tasks = tasks.clone();
    let a = super::tests::service(&first);
    let weak = Arc::downgrade(&first);
    let worker = std::thread::spawn(move || {
        let out = a.source_call_back_btn(
            &running_tasks,
            "click",
            "https://callback-book.test",
            Some(1),
            Some("😀"),
        );
        assert!(!legado_js::host_api::ui_action_queue::is_collecting());
        out
    });
    let runtime = tokio::runtime::Runtime::new().unwrap();
    let request = runtime.block_on(fixture.request()).to_ascii_lowercase();
    assert!(request.contains("identity=first") && request.contains("x-instance: first"));
    assert_eq!(tasks.active_count(), 1);
    // 根析构会关闭任务组，必须在确认工作进入HTTP后才释放根实例。
    drop(first);
    assert!(weak.upgrade().is_none());
    assert!(!runtime.block_on(tasks.shutdown(Duration::from_millis(10))));
    assert_eq!(tasks.active_count(), 1);
    let b = super::tests::service(&second);
    let out = b
        .source_call_back_btn(
            second.tasks(),
            "click",
            "https://callback-book.test",
            Some(1),
            Some("😀"),
        )
        .unwrap();
    assert!(out.invoked && out.js_true);
    assert_eq!(
        out.actions,
        vec![
            serde_json::json!({"action":"copyText","text":"click:乙:乙:😀:second"}),
            serde_json::json!({"action":"copyText","text":"第二条"}),
        ]
    );
    assert_eq!(second.tasks().active_count(), 0);
    fixture.release.send(()).unwrap();
    fixture.worker.join().unwrap();
    assert!(matches!(worker.join().unwrap(), Err(LegadoError::Ffi(e)) if e == "书源回调已取消"));
    assert!(runtime.block_on(tasks.shutdown(Duration::from_secs(1))));
    // 抛异常的脚本已收集动作不得泄入下一次成功调用。
    prepare(
        &second,
        &fixture.url,
        "乙",
        "java.copyText('失败动作');throw new Error('callback failed')",
    );
    assert!(
        b.source_call_back_btn(
            second.tasks(),
            "click",
            "https://callback-book.test",
            None,
            None
        )
        .is_err()
    );
    assert_eq!(second.tasks().active_count(), 0);
    prepare(
        &second,
        &fixture.url,
        "乙",
        "java.copyText(String(chapter)+':'+(result===''));'false'",
    );
    let out = b
        .source_call_back_btn(
            second.tasks(),
            "click",
            "https://callback-book.test",
            None,
            Some(""),
        )
        .unwrap();
    assert!(out.invoked && !out.js_true);
    assert_eq!(
        out.actions,
        vec![serde_json::json!({"action":"copyText","text":"null:true"})]
    );
    assert!(!legado_js::host_api::ui_action_queue::is_collecting());
}
