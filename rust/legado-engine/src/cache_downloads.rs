//! 实例章节下载队列；执行器只捕获数据能力，状态表不保活执行凭据。

use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex, Weak};

use legado_core::{LegadoError, LegadoResult};
use legado_db::{BookChapterRepository, BookRepository, CacheRepository};
use serde::{Deserialize, Serialize};

use crate::{StorageContext, TaskGroup, TaskHandle};

const PREFIX: &str = "cacheDownloadTask:";
const INDEX: &str = "cacheDownloadTaskIndex";
const NEXT: &str = "cacheDownloadNextId";

/// 执行器的正文/副内容提交必须使用传入凭据的 with_active；抓取不能放进发布门控。
pub type ChapterDownload = Arc<dyn Fn(&str, i32, &TaskHandle) -> LegadoResult<()> + Send + Sync>;
type Worker = Box<dyn FnOnce() + Send>;
type Spawner = Arc<dyn Fn(String, Worker) -> std::io::Result<()> + Send + Sync>;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CacheDownloadTask {
    pub task_id: u64,
    pub book_url: String,
    pub status: String,
    pub total: i32,
    pub completed: i32,
    pub failed: i32,
}

impl CacheDownloadTask {
    pub fn not_found(task_id: u64) -> Self {
        Self {
            task_id,
            book_url: String::new(),
            status: "notFound".into(),
            total: 0,
            completed: 0,
            failed: 0,
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Checkpoint {
    task_id: u64,
    book_url: String,
    start_chapter: i32,
    end_chapter: i32,
    total: i32,
    completed: i32,
    failed: i32,
    next_index: i32,
    status: String,
    #[serde(default)]
    failed_chapters: Vec<i32>,
}

impl Checkpoint {
    fn summary(&self) -> CacheDownloadTask {
        CacheDownloadTask {
            task_id: self.task_id,
            book_url: self.book_url.clone(),
            status: self.status.clone(),
            total: self.total,
            completed: self.completed,
            failed: self.failed,
        }
    }
}

struct Record {
    row: Mutex<Checkpoint>,
    running: Weak<TaskHandle>,
}

struct State {
    restored: bool,
    next: u64,
    records: HashMap<u64, Arc<Record>>,
}

pub struct CacheDownloads {
    storage: StorageContext,
    tasks: TaskGroup,
    execute: ChapterDownload,
    spawn: Spawner,
    /// 只串行恢复/创建，不持此锁执行章节抓取。
    assembly: Mutex<()>,
    /// 顺序化运行快照与取消终态；不持状态表锁进入 SQL。
    checkpoint: Mutex<()>,
    state: Mutex<State>,
}

impl CacheDownloads {
    pub fn new(storage: StorageContext, tasks: TaskGroup, execute: ChapterDownload) -> Self {
        Self {
            storage,
            tasks,
            execute,
            spawn: Arc::new(|name, worker| {
                std::thread::Builder::new()
                    .name(name)
                    .spawn(worker)
                    .map(drop)
            }),
            assembly: Mutex::new(()),
            checkpoint: Mutex::new(()),
            state: Mutex::new(State {
                restored: false,
                next: 1,
                records: HashMap::new(),
            }),
        }
    }

    fn persist(&self, row: &Checkpoint) -> LegadoResult<()> {
        let json = serde_json::to_string(row)?;
        let next = self.state.lock().unwrap_or_else(|p| p.into_inner()).next;
        self.storage.with_database(|db| {
            let conn = db.connection();
            let tx = rusqlite::Transaction::new_unchecked(
                conn,
                rusqlite::TransactionBehavior::Immediate,
            )
            .map_err(|e| LegadoError::Database(format!("下载快照事务开启失败: {e}")))?;
            let repo = CacheRepository::new(conn);
            repo.put(&format!("{PREFIX}{}", row.task_id), &json, 0)?;
            let mut ids: Vec<u64> = repo
                .get(INDEX)?
                .and_then(|s| serde_json::from_str(&s).ok())
                .unwrap_or_default();
            if !ids.contains(&row.task_id) {
                ids.push(row.task_id);
            }
            ids.sort_unstable();
            ids.dedup();
            repo.put(INDEX, &serde_json::to_string(&ids)?, 0)?;
            let persisted = repo
                .get(NEXT)?
                .and_then(|s| s.parse::<u64>().ok())
                .unwrap_or(1);
            repo.put(NEXT, &next.max(persisted).to_string(), 0)?;
            tx.commit()
                .map_err(|e| LegadoError::Database(format!("下载快照事务提交失败: {e}")))
        })
    }

    fn update(&self, record: &Record, update: impl FnOnce(&mut Checkpoint)) {
        let _checkpoint = self.checkpoint.lock().unwrap_or_else(|p| p.into_inner());
        let row = {
            let mut row = record.row.lock().unwrap_or_else(|p| p.into_inner());
            update(&mut row);
            row.clone()
        };
        if let Err(error) = self.persist(&row) {
            log::warn!("缓存下载快照保存失败: {error}");
        }
    }

    fn finish_cancelled(&self, record: &Record) {
        let _checkpoint = self.checkpoint.lock().unwrap_or_else(|p| p.into_inner());
        let row = {
            let mut row = record.row.lock().unwrap_or_else(|p| p.into_inner());
            // 已有终态不能被迟到收尾覆盖，也不因重复取消重建已被清掉的 KV。
            if row.status != "running" {
                return;
            }
            row.status = "cancelled".into();
            row.clone()
        };
        if let Err(error) = self.persist(&row) {
            log::warn!("取消断点保存失败: {error}");
        }
    }

    fn restore_locked(self: &Arc<Self>) -> LegadoResult<()> {
        if self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .restored
        {
            return Ok(());
        }
        let (rows, mut next) = self.storage.with_database(|db| {
            let repo = CacheRepository::new(db.connection());
            let next = repo
                .get(NEXT)?
                .and_then(|s| s.parse::<u64>().ok())
                .unwrap_or(1)
                .max(1);
            let ids: Vec<u64> = repo
                .get(INDEX)?
                .and_then(|s| serde_json::from_str(&s).ok())
                .unwrap_or_default();
            let mut rows = Vec::new();
            for id in ids {
                if let Some(json) = repo.get(&format!("{PREFIX}{id}"))?
                    && let Ok(row) = serde_json::from_str::<Checkpoint>(&json)
                {
                    rows.push(row);
                }
            }
            Ok((rows, next))
        })?;
        for row in &rows {
            next = next.max(
                row.task_id
                    .checked_add(1)
                    .ok_or_else(|| LegadoError::Ffi("下载任务编号耗尽".into()))?,
            );
        }
        {
            let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            state.next = state.next.max(next);
        }
        for mut row in rows {
            if row.status != "running" {
                continue;
            }
            if self
                .state
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .records
                .contains_key(&row.task_id)
            {
                continue;
            }
            row.next_index = row.next_index.max(row.start_chapter);
            let handle = Arc::new(
                self.tasks
                    .begin()
                    .map_err(|e| LegadoError::Ffi(e.to_string()))?,
            );
            let id = row.task_id;
            let record = Arc::new(Record {
                row: Mutex::new(row),
                running: Arc::downgrade(&handle),
            });
            self.state
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .records
                .insert(id, record.clone());
            self.launch(id, record, handle)?;
        }
        self.state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .restored = true;
        Ok(())
    }

    fn restore(self: &Arc<Self>) -> LegadoResult<()> {
        let _assembly = self.assembly.lock().unwrap_or_else(|p| p.into_inner());
        self.restore_locked()
    }

    fn launch(
        self: &Arc<Self>,
        id: u64,
        record: Arc<Record>,
        handle: Arc<TaskHandle>,
    ) -> LegadoResult<()> {
        let service = self.clone();
        let worker_record = record.clone();
        if let Err(error) = (self.spawn)(
            format!("cache-download-{id}"),
            Box::new(move || {
                // 凭据覆盖网络、CPU、状态收尾和最后一次断点保存。
                let panicked = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    service.run(&worker_record, &handle)
                }))
                .is_err();
                if panicked
                    && handle
                        .with_active(|| {
                            service.update(&worker_record, |row| row.status = "failed".into())
                        })
                        .is_none()
                {
                    service.finish_cancelled(&worker_record);
                }
            }),
        ) {
            self.update(&record, |row| row.status = "failed".into());
            return Err(LegadoError::Ffi(format!("下载线程启动失败: {error}")));
        }
        Ok(())
    }

    pub fn start(self: &Arc<Self>, book: &str, start: i32, end: i32) -> LegadoResult<u64> {
        let _assembly = self.assembly.lock().unwrap_or_else(|p| p.into_inner());
        self.restore_locked()?;
        let existing: Vec<_> = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .records
            .values()
            .cloned()
            .collect();
        for record in existing {
            let row = record.row.lock().unwrap_or_else(|p| p.into_inner());
            if row.book_url == book && row.status == "running" {
                return Ok(row.task_id);
            }
        }
        let count = self.storage.with_database(|db| {
            if BookRepository::new(db.connection())
                .find_by_url(book)?
                .is_none()
            {
                return Err(LegadoError::Database(format!("书籍不存在: {book}")));
            }
            BookChapterRepository::new(db.connection()).count_by_book_url(book)
        })?;
        if count <= 0 {
            return Err(LegadoError::Database(format!(
                "书籍无章节目录，无法批量缓存: {book}"
            )));
        }
        let start = start.max(0);
        let end = end.min(count as i32 - 1);
        if end < start {
            return Err(LegadoError::Ffi(format!(
                "章节范围非法: start={start} > end={end}"
            )));
        }
        let handle = Arc::new(
            self.tasks
                .begin()
                .map_err(|e| LegadoError::Ffi(e.to_string()))?,
        );
        let id = {
            let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
            let id = state.next;
            state.next = id
                .checked_add(1)
                .ok_or_else(|| LegadoError::Ffi("下载任务编号耗尽".into()))?;
            id
        };
        let row = Checkpoint {
            task_id: id,
            book_url: book.into(),
            start_chapter: start,
            end_chapter: end,
            total: end - start + 1,
            completed: 0,
            failed: 0,
            next_index: start,
            status: "running".into(),
            failed_chapters: Vec::new(),
        };
        let record = Arc::new(Record {
            row: Mutex::new(row.clone()),
            running: Arc::downgrade(&handle),
        });
        handle
            .with_active(|| {
                {
                    let _checkpoint = self.checkpoint.lock().unwrap_or_else(|p| p.into_inner());
                    self.persist(&row)?;
                }
                self.state
                    .lock()
                    .unwrap_or_else(|p| p.into_inner())
                    .records
                    .insert(id, record.clone());
                self.launch(id, record, handle.clone())?;
                Ok(id)
            })
            .ok_or_else(|| LegadoError::Ffi("任务组已关闭".into()))?
    }

    fn run(&self, record: &Record, handle: &TaskHandle) {
        loop {
            let row = record.row.lock().unwrap_or_else(|p| p.into_inner()).clone();
            if handle.is_cancelled() {
                self.finish_cancelled(record);
                return;
            }
            if row.next_index > row.end_chapter {
                if handle
                    .with_active(|| {
                        self.update(record, |row| {
                            row.status = if row.failed == row.total {
                                "failed"
                            } else {
                                "completed"
                            }
                            .into()
                        })
                    })
                    .is_some()
                {
                    return;
                }
                continue;
            }
            if handle
                .with_active(|| self.clear_failed(&row.book_url, row.next_index))
                .is_none()
            {
                continue;
            }
            let result = (self.execute)(&row.book_url, row.next_index, handle);
            if handle
                .with_active(|| {
                    self.update(record, |current| {
                        if result.is_ok() {
                            current.completed += 1;
                            current
                                .failed_chapters
                                .retain(|index| *index != row.next_index);
                        } else {
                            current.failed += 1;
                            current.failed_chapters.push(row.next_index);
                            current.failed_chapters.sort_unstable();
                            current.failed_chapters.dedup();
                        }
                        current.next_index = row.next_index + 1;
                    })
                })
                .is_none()
            {
                continue;
            }
        }
    }

    fn clear_failed(&self, book: &str, index: i32) {
        let records: Vec<_> = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .records
            .values()
            .cloned()
            .collect();
        for record in records {
            let mut row = record.row.lock().unwrap_or_else(|p| p.into_inner());
            if row.book_url == book {
                row.failed_chapters.retain(|value| *value != index);
            }
        }
    }

    pub fn cancel(self: &Arc<Self>, id: u64) -> LegadoResult<bool> {
        self.restore()?;
        let record = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .records
            .get(&id)
            .cloned();
        if let Some(record) = record {
            if let Some(handle) = record.running.upgrade() {
                handle.cancel();
            }
            self.finish_cancelled(&record);
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub fn progress(self: &Arc<Self>, id: u64) -> LegadoResult<CacheDownloadTask> {
        self.restore()?;
        if let Some(record) = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .records
            .get(&id)
            .cloned()
        {
            return Ok(record
                .row
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .summary());
        }
        Ok(self
            .storage
            .with_database(|db| {
                CacheRepository::new(db.connection()).get(&format!("{PREFIX}{id}"))
            })?
            .and_then(|json| serde_json::from_str::<Checkpoint>(&json).ok())
            .map(|row| row.summary())
            .unwrap_or_else(|| CacheDownloadTask::not_found(id)))
    }

    pub fn list(self: &Arc<Self>) -> LegadoResult<Vec<CacheDownloadTask>> {
        self.restore()?;
        let mut ids: Vec<u64> = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .records
            .keys()
            .copied()
            .collect();
        ids.extend(self.storage.with_database(|db| {
            Ok(CacheRepository::new(db.connection())
                .get(INDEX)?
                .and_then(|json| serde_json::from_str::<Vec<u64>>(&json).ok())
                .unwrap_or_default())
        })?);
        ids.sort_unstable();
        ids.dedup();
        ids.into_iter().map(|id| self.progress(id)).collect()
    }

    pub fn chapters(self: &Arc<Self>, book: &str, failed: bool) -> LegadoResult<Vec<i32>> {
        self.restore()?;
        let records: Vec<_> = self
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner())
            .records
            .values()
            .cloned()
            .collect();
        let mut indices = HashSet::new();
        for record in records {
            let row = record.row.lock().unwrap_or_else(|p| p.into_inner());
            if row.book_url != book {
                continue;
            }
            if failed {
                indices.extend(row.failed_chapters.iter().copied());
            } else if row.status == "running"
                && (row.start_chapter..=row.end_chapter).contains(&row.next_index)
            {
                indices.insert(row.next_index);
            }
        }
        let mut indices: Vec<_> = indices.into_iter().collect();
        indices.sort_unstable();
        Ok(indices)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::EngineContext;
    use legado_core::models::{Book, BookChapter};
    use legado_db::repository::Repository;
    use std::time::{Duration, Instant};

    fn seed(engine: &EngineContext) {
        engine
            .storage()
            .with_database(|db| {
                BookRepository::new(db.connection()).insert(&Book {
                    book_url: "book".into(),
                    name: "任务测试".into(),
                    ..Default::default()
                })?;
                BookChapterRepository::new(db.connection()).insert_batch(&[BookChapter {
                    book_url: "book".into(),
                    url: "chapter".into(),
                    title: "第一章".into(),
                    ..Default::default()
                }])
            })
            .unwrap();
    }
    fn wait(service: &Arc<CacheDownloads>, id: u64) -> CacheDownloadTask {
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            let result = service.progress(id).unwrap();
            if result.status != "running" && service.tasks.active_count() == 0 {
                return result;
            }
            assert!(Instant::now() < deadline, "下载未退出");
            std::thread::sleep(Duration::from_millis(2));
        }
    }

    #[test]
    fn terminal_cancel_does_not_resurrect_cleared_metadata() {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine);
        let service = Arc::new(CacheDownloads::new(
            engine.storage().clone(),
            engine.tasks().clone(),
            Arc::new(|_, _, _| Ok(())),
        ));
        let id = service.start("book", 0, 0).unwrap();
        assert_eq!(wait(&service, id).status, "completed");
        engine
            .storage()
            .with_database(|db| CacheRepository::new(db.connection()).clear())
            .unwrap();
        assert!(service.cancel(id).unwrap());
        assert!(
            engine
                .storage()
                .with_database(
                    |db| CacheRepository::new(db.connection()).get(&format!("{PREFIX}{id}"))
                )
                .unwrap()
                .is_none()
        );
        assert_eq!(service.progress(id).unwrap().status, "completed");
    }

    #[test]
    fn late_worker_panic_cannot_overwrite_the_cancelled_checkpoint() {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine);
        let (started, ready) = std::sync::mpsc::channel();
        let (release, gate) = std::sync::mpsc::channel();
        let gate = Mutex::new(gate);
        let service = Arc::new(CacheDownloads::new(
            engine.storage().clone(),
            engine.tasks().clone(),
            Arc::new(move |_, _, _| {
                started.send(()).unwrap();
                gate.lock()
                    .unwrap()
                    .recv_timeout(Duration::from_secs(5))
                    .unwrap();
                panic!("取消后的异常夹具");
            }),
        ));
        let id = service.start("book", 0, 0).unwrap();
        ready.recv_timeout(Duration::from_secs(5)).unwrap();
        service.cancel(id).unwrap();
        release.send(()).unwrap();
        assert_eq!(wait(&service, id).status, "cancelled");
        let row = engine
            .storage()
            .with_database(|db| CacheRepository::new(db.connection()).get(&format!("{PREFIX}{id}")))
            .unwrap()
            .unwrap();
        assert_eq!(
            serde_json::from_str::<Checkpoint>(&row).unwrap().status,
            "cancelled"
        );
    }

    #[test]
    fn concurrent_starts_share_one_worker_and_keep_atomic_task_index() {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine);
        let (release, receiver) = std::sync::mpsc::channel();
        let receiver = Mutex::new(receiver);
        let service = Arc::new(CacheDownloads::new(
            engine.storage().clone(),
            engine.tasks().clone(),
            Arc::new(move |_, _, _| {
                receiver
                    .lock()
                    .unwrap()
                    .recv_timeout(Duration::from_secs(5))
                    .unwrap();
                Ok(())
            }),
        ));
        let ids = std::thread::scope(|scope| {
            (0..8)
                .map(|_| scope.spawn(|| service.start("book", 0, 0).unwrap()))
                .collect::<Vec<_>>()
                .into_iter()
                .map(|job| job.join().unwrap())
                .collect::<Vec<_>>()
        });
        assert!(ids.iter().all(|id| *id == ids[0]));
        assert_eq!(service.tasks.active_count(), 1);
        release.send(()).unwrap();
        assert_eq!(wait(&service, ids[0]).completed, 1);
        let restarted = Arc::new(CacheDownloads::new(
            engine.storage().clone(),
            engine.tasks().clone(),
            Arc::new(|_, _, _| Ok(())),
        ));
        let next = restarted.start("book", 0, 0).unwrap();
        assert!(next > ids[0]);
        wait(&restarted, next);
        assert_eq!(restarted.list().unwrap().len(), 2);
        let ids: Vec<u64> = engine
            .storage()
            .with_database(|db| {
                Ok(serde_json::from_str(
                    &CacheRepository::new(db.connection()).get(INDEX)?.unwrap(),
                )
                .unwrap())
            })
            .unwrap();
        assert_eq!(ids, vec![1, 2]);
    }

    #[tokio::test]
    async fn cancellation_rejects_late_payload_keeps_checkpoint_and_real_worker_lifetime() {
        let engine = Arc::new(EngineContext::in_memory().unwrap());
        seed(&engine);
        let weak = Arc::downgrade(&engine);
        let storage = engine.storage().clone();
        let write = storage.clone();
        let tasks = engine.tasks().clone();
        let (started, ready) = tokio::sync::oneshot::channel();
        let started = Mutex::new(Some(started));
        let (release, receiver) = std::sync::mpsc::channel();
        let receiver = Mutex::new(receiver);
        let service = Arc::new(CacheDownloads::new(
            storage.clone(),
            tasks.clone(),
            Arc::new(move |_, _, task| {
                started.lock().unwrap().take().unwrap().send(()).unwrap();
                receiver
                    .lock()
                    .unwrap()
                    .recv_timeout(Duration::from_secs(5))
                    .unwrap();
                task.with_active(|| {
                    write.with_database(|db| {
                        CacheRepository::new(db.connection()).put("late-body", "禁止写入", 0)
                    })
                })
                .ok_or_else(|| LegadoError::Ffi("已取消".into()))?
            }),
        ));
        let id = service.start("book", 0, 0).unwrap();
        ready.await.unwrap();
        assert!(service.cancel(id).unwrap());
        assert_eq!(service.progress(id).unwrap().status, "cancelled");
        assert!(!tasks.shutdown(Duration::from_millis(10)).await);
        drop(engine);
        assert!(weak.upgrade().is_none());
        assert!(service.start("book", 0, 0).is_err());
        release.send(()).unwrap();
        assert!(tasks.shutdown(Duration::from_secs(1)).await);
        let (body, row) = storage
            .with_database(|db| {
                let repo = CacheRepository::new(db.connection());
                Ok((repo.get("late-body")?, repo.get(&format!("{PREFIX}{id}"))?))
            })
            .unwrap();
        assert!(body.is_none());
        let row: Checkpoint = serde_json::from_str(&row.unwrap()).unwrap();
        assert_eq!(row.next_index, 0);
        assert_eq!(row.completed, 0);
        assert_eq!(row.failed, 0);
        assert_eq!(row.status, "cancelled");
    }

    #[test]
    fn spawn_and_initial_checkpoint_failures_leave_no_running_registration() {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine);
        let mut service = CacheDownloads::new(
            engine.storage().clone(),
            engine.tasks().clone(),
            Arc::new(|_, _, _| Ok(())),
        );
        service.spawn = Arc::new(|_, _| Err(std::io::Error::other("线程失败夹具")));
        let service = Arc::new(service);
        assert!(
            service
                .start("book", 0, 0)
                .unwrap_err()
                .to_string()
                .contains("下载线程启动失败")
        );
        assert_eq!(service.progress(1).unwrap().status, "failed");
        assert_eq!(engine.tasks().active_count(), 0);
        let other = EngineContext::in_memory().unwrap();
        seed(&other);
        other.storage().with_database(|db|db.connection().execute_batch("CREATE TRIGGER reject_task BEFORE INSERT ON caches WHEN NEW.key LIKE 'cacheDownload%' BEGIN SELECT RAISE(FAIL,'拒绝快照'); END;").map_err(|e|LegadoError::Database(e.to_string()))).unwrap();
        let service = Arc::new(CacheDownloads::new(
            other.storage().clone(),
            other.tasks().clone(),
            Arc::new(|_, _, _| Ok(())),
        ));
        assert!(service.start("book", 0, 0).is_err());
        assert_eq!(other.tasks().active_count(), 0);
        assert!(service.list().unwrap().is_empty());
        other
            .storage()
            .with_database(|db| {
                db.connection()
                    .execute_batch("DROP TRIGGER reject_task")
                    .map_err(|e| LegadoError::Database(e.to_string()))
            })
            .unwrap();
        assert_eq!(
            wait(&service, service.start("book", 0, 0).unwrap()).status,
            "completed"
        );
    }

    #[test]
    fn failed_restore_retries_and_resumes_only_from_the_original_checkpoint() {
        let engine = EngineContext::in_memory().unwrap();
        seed(&engine);
        let calls = Arc::new(Mutex::new(Vec::new()));
        let work = calls.clone();
        let service = Arc::new(CacheDownloads::new(
            engine.storage().clone(),
            engine.tasks().clone(),
            Arc::new(move |_, index, _| {
                work.lock().unwrap().push(index);
                Ok(())
            }),
        ));
        engine
            .storage()
            .with_database(|db| {
                db.connection()
                    .execute_batch("ALTER TABLE caches RENAME TO saved_caches")
                    .map_err(|e| LegadoError::Database(e.to_string()))
            })
            .unwrap();
        assert!(service.list().is_err());
        engine.storage().with_database(|db|{
            db.connection().execute_batch("ALTER TABLE saved_caches RENAME TO caches").map_err(|e|LegadoError::Database(e.to_string()))?;
            let repo=CacheRepository::new(db.connection());
            repo.put(INDEX,"[7]",0)?;
            repo.put(&format!("{PREFIX}7"),r#"{"taskId":7,"bookUrl":"book","startChapter":0,"endChapter":1,"total":2,"completed":1,"failed":0,"nextIndex":1,"status":"running"}"#,0)
        }).unwrap();
        assert_eq!(wait(&service, 7).completed, 2);
        assert_eq!(*calls.lock().unwrap(), vec![1]);
        let before = engine
            .storage()
            .with_database(|db| CacheRepository::new(db.connection()).get(&format!("{PREFIX}7")))
            .unwrap();
        assert!(service.chapters("unknown", true).unwrap().is_empty());
        assert_eq!(before,engine.storage().with_database(|db|CacheRepository::new(db.connection()).get(&format!("{PREFIX}7"))).unwrap());
        let checkpoint: Checkpoint = serde_json::from_str(before.as_ref().unwrap()).unwrap();
        assert!(checkpoint.failed_chapters.is_empty());
        assert_eq!(serde_json::to_value(checkpoint).unwrap()["nextIndex"], 2);
    }

    #[test]
    fn separate_instances_can_use_the_same_id_without_sharing_cancellation_or_failures() {
        let first = EngineContext::in_memory().unwrap();
        let second = EngineContext::in_memory().unwrap();
        seed(&first);
        seed(&second);
        let a = Arc::new(CacheDownloads::new(
            first.storage().clone(),
            first.tasks().clone(),
            Arc::new(|_, _, _| Err(LegadoError::Network("失败夹具".into()))),
        ));
        let b = Arc::new(CacheDownloads::new(
            second.storage().clone(),
            second.tasks().clone(),
            Arc::new(|_, _, _| Ok(())),
        ));
        let aid = a.start("book", 0, 0).unwrap();
        let bid = b.start("book", 0, 0).unwrap();
        assert_eq!(aid, bid);
        assert_eq!(wait(&a, aid).status, "failed");
        assert_eq!(wait(&b, bid).status, "completed");
        assert_eq!(a.chapters("book", true).unwrap(), vec![0]);
        assert!(b.chapters("book", true).unwrap().is_empty());
        a.cancel(aid).unwrap();
        assert_eq!(b.progress(bid).unwrap().status, "completed");
        let retry = Arc::new(CacheDownloads::new(
            first.storage().clone(),
            first.tasks().clone(),
            Arc::new(|_, _, _| Ok(())),
        ));
        assert_eq!(
            wait(&retry, retry.start("book", 0, 0).unwrap()).status,
            "completed"
        );
    }
}
