//! 书源调试宿主适配：只装配实例能力及传输回调，编排归Engine服务。
use legado_engine::explore_service::{ExploreResources, ExploreService};
pub use legado_engine::source_debug_service::DebugLogItem;
use legado_engine::source_debug_service::{SourceDebugResources, SourceDebugService};
use legado_engine::{EngineContext, OperationSlot};
use std::sync::Arc;

fn service_for_engine(
    engine: Option<&EngineContext>,
    slot: Arc<OperationSlot>,
) -> SourceDebugService {
    let js = engine
        .map(|e| e.js_resources().clone())
        .unwrap_or_else(crate::engine_holder::js_resources);
    let info = engine
        .map(|e| e.source_info_map().clone())
        .unwrap_or_else(crate::engine_holder::source_info_map);
    let login = engine
        .map(|e| e.source_login_cache().clone())
        .unwrap_or_else(crate::engine_holder::source_login_cache);
    let tasks = engine
        .map(|e| e.tasks().clone())
        .unwrap_or_else(crate::engine_holder::task_group);
    let runtime = crate::runtime::get_runtime().handle().clone();
    let setup_info = info.clone();
    let explore = Arc::new(ExploreService::new(ExploreResources {
        js,
        info: info.clone(),
        tasks,
        runtime: runtime.clone(),
        setup: Arc::new(move |source| {
            super::source_js_bindings::book_source_js_setup_script_with_login_cache(
                source,
                &login,
                &setup_info,
            )
        }),
    }));
    SourceDebugService::new(SourceDebugResources {
        storage: engine.map(|e| e.storage().clone()),
        deps: engine.map(super::web_book::deps_for_engine),
        info,
        slot,
        runtime,
        explore,
    })
}

/// 取消宿主自己的当前调试，不影响校验或其他实例。
pub fn cancel_debug_book_source() {
    crate::engine_holder::source_debug().cancel();
}

/// 回调与依赖在入口捕获；worker执行中不再发现当前宿主。
pub async fn run_debug_book_source_stream<F>(source_url: String, key: String, on_log: F)
where
    F: FnMut(DebugLogItem) -> Result<(), String> + Send + 'static,
{
    let slot = crate::engine_holder::source_debug();
    let engine = crate::engine_holder::current().ok();
    let service = service_for_engine(engine.as_deref(), slot);
    drop(engine);
    service.run(source_url, key, on_log).await;
}

#[cfg(test)]
mod tests {
    use super::super::source_task_fixture::Fixture;
    use super::*;
    use legado_core::models::BookSource;
    use legado_db::{BookSourceRepository, repository::Repository};
    use std::{sync::Mutex, time::Duration};
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
    async fn abandoned_real_debug_keeps_blocking_worker_but_does_not_retain_root() {
        let mut fixture = Fixture::new(1, true, |_| {
            format!(
                "<div class='content'>https://cdn.example/late.mp4</div><div class='sub'>{}</div>",
                "迟到弹幕".repeat(3000)
            )
        });
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        seed(&engine, &fixture.url, "原源");
        let book = format!("{}/book", fixture.url);
        let chapter = format!("{}/chapter", fixture.url);
        engine
            .storage()
            .with_database(|db| {
                let repo = BookSourceRepository::new(db.connection());
                let mut source = repo.find_by_url(&fixture.url)?.unwrap();
                source.book_source_type = 4;
                repo.update(&source)?;
                legado_db::BookRepository::new(db.connection()).insert(
                    &legado_core::models::Book {
                        book_url: book.clone(),
                        origin: fixture.url.clone(),
                        name: "媒体书".into(),
                        ..Default::default()
                    },
                )?;
                legado_db::BookChapterRepository::new(db.connection()).insert_batch(&[
                    legado_core::models::BookChapter {
                        book_url: book.clone(),
                        url: chapter.clone(),
                        title: "第一章".into(),
                        ..Default::default()
                    },
                ])
            })
            .unwrap();
        let storage = engine.storage().clone();
        let weak = Arc::downgrade(&engine);
        let tasks = engine.tasks().clone();
        let slot = Arc::new(OperationSlot::new(tasks.clone()));
        let logs = Arc::new(Mutex::new(Vec::new()));
        let service = service_for_engine(Some(&engine), slot.clone());
        let output = logs.clone();
        let mut future = Box::pin(service.run(
            fixture.url.clone(),
            format!("--{}/chapter", fixture.url),
            move |item| {
                output
                    .lock()
                    .unwrap()
                    .push(serde_json::to_value(item).unwrap());
                Ok(())
            },
        ));
        tokio::select! { _ = fixture.request() => {}, _ = &mut future => panic!("请求应等待响应") }
        drop(future);
        let count = logs.lock().unwrap().len();
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(!tasks.shutdown(Duration::from_millis(20)).await);
        fixture.release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(5)).await);
        assert_eq!(logs.lock().unwrap().len(), count);
        assert!(slot.current().is_none());
        storage
            .with_database(|db| {
                let saved = legado_db::BookChapterRepository::new(db.connection())
                    .find_by_book_url_and_index(&book, 0)?
                    .unwrap();
                assert!(!saved.variable.unwrap_or_default().contains("danmaku"));
                Ok(())
            })
            .unwrap();
        let directory = storage.data_directory("ruleData").unwrap();
        assert!(
            legado_db::rule_big_data::RuleBigDataManager::new(&directory)
                .get_chapter_variable(&book, &chapter, "danmaku")
                .unwrap()
                .is_none()
        );
        fixture.worker.join().unwrap();
    }
}
