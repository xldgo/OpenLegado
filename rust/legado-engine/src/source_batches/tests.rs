use super::*;
use crate::TaskGroup;

#[tokio::test]
async fn panic_during_creation_or_poll_keeps_source_identity_and_releases_tasks() {
    let tasks = TaskGroup::default();
    let task = tasks.begin().unwrap();
    let worker = task.clone();
    let sources = ["ok", "create", "poll", "opaque"].map(|name| BookSource {
        book_source_url: format!("fixture://{name}"),
        book_source_name: name.to_string(),
        ..Default::default()
    });
    let mut outcomes = Vec::new();
    drive_source_batches(
        sources.to_vec(),
        4,
        Duration::from_secs(5),
        &task,
        &Arc::new(AtomicBool::new(false)),
        move |source| {
            let worker = worker.clone();
            if source.book_source_name == "create" {
                std::panic::panic_any(String::from("timeout cancelled：创建 Future 的真实原因"));
            }
            async move {
                let _worker = worker;
                match source.book_source_name.as_str() {
                    "poll" => panic!("超时取消：轮询 Future 的真实原因"),
                    "opaque" => std::panic::panic_any(42_u8),
                    _ => Ok(vec!["正文结果"]),
                }
            }
        },
        |outcome| {
            assert_eq!(outcome.finished_count, outcomes.len() + 1);
            assert_eq!(outcome.total_count, 4);
            assert_eq!(outcome.is_last, outcome.finished_count == 4);
            outcomes.push(outcome);
            Ok(())
        },
    )
    .await;
    assert_eq!(outcomes.len(), 4);
    outcomes.sort_by_key(|o| o.index);
    for (index, (outcome, name)) in outcomes
        .iter()
        .zip(["ok", "create", "poll", "opaque"])
        .enumerate()
    {
        assert_eq!(outcome.index, index);
        assert_eq!(outcome.source_url, format!("fixture://{name}"));
        assert_eq!(outcome.source_name, name);
        if index == 0 {
            assert_eq!(outcome.result.as_ref().unwrap(), &["正文结果"]);
        } else {
            assert!(matches!(outcome.result, Err(LegadoError::Network(_))));
            if let Err(LegadoError::Network(message)) = &outcome.result {
                assert_eq!(
                    crate::search_service::classify_source_outcome(&Err(LegadoError::Network(
                        message.clone()
                    ))),
                    "parser_error"
                );
            }
            let message = outcome.result.as_ref().unwrap_err().to_string();
            assert!(message.contains("单源搜索崩溃"), "{message}");
            assert!(
                message.contains(match index {
                    1 => "创建 Future 的真实原因",
                    2 => "轮询 Future 的真实原因",
                    _ => "非文本 panic",
                }),
                "{message}"
            );
        }
    }
    assert!(!task.is_cancelled());
    assert_eq!(tasks.active_count(), 1);
    drop(task);
    assert_eq!(tasks.active_count(), 0);
    assert!(tasks.shutdown(Duration::from_secs(1)).await);
}
