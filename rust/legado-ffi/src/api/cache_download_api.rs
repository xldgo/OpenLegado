//! 缓存下载 FFI 适配；会话/恢复/快照与执行凭据由所属实例服务管理。
use legado_core::LegadoResult;
pub use legado_engine::CacheDownloadTask;
use legado_engine::{CacheDownloads, EngineContext};
use std::sync::Arc;

/// 装配只捕获数据能力，后台线程不强持根引擎。
pub(crate) fn chapter_download_for_engine(
    engine: &EngineContext,
) -> legado_engine::ChapterDownload {
    let content = super::chapter_content::from_engine(engine);
    let images = legado_engine::manga_cache::MangaCache::new(
        engine.storage().clone(),
        engine.network().clone(),
        engine.js_resources().clone(),
        crate::runtime::get_runtime().handle().clone(),
    );
    let media = engine.media().clone();
    Arc::new(move |book, index, task| {
        content.download(book, index, task)?;
        let cache = legado_engine::image_cache_service::ImageCacheService::new(
            super::image_cache_api::cache_root_for(&media),
        );
        images.download(book, index, task, &cache)
    })
}

pub(crate) fn downloads_for_engine(engine: &EngineContext) -> Arc<CacheDownloads> {
    Arc::new(CacheDownloads::new(
        engine.storage().clone(),
        engine.tasks().clone(),
        chapter_download_for_engine(engine),
    ))
}

pub fn cache_download_start(
    book_url: &str,
    start_chapter: i32,
    end_chapter: i32,
) -> LegadoResult<u64> {
    crate::engine_holder::cache_downloads()?.start(book_url, start_chapter, end_chapter)
}
pub fn cache_download_progress(task_id: u64) -> LegadoResult<CacheDownloadTask> {
    if !crate::engine_holder::is_initialized() {
        return Ok(CacheDownloadTask::not_found(task_id));
    }
    crate::engine_holder::cache_downloads()?.progress(task_id)
}
pub fn cache_download_cancel(task_id: u64) -> LegadoResult<bool> {
    if !crate::engine_holder::is_initialized() {
        return Ok(false);
    }
    crate::engine_holder::cache_downloads()?.cancel(task_id)
}
pub fn cache_download_list() -> LegadoResult<Vec<CacheDownloadTask>> {
    if !crate::engine_holder::is_initialized() {
        return Ok(Vec::new());
    }
    crate::engine_holder::cache_downloads()?.list()
}
pub fn cache_download_running_chapters(book_url: &str) -> LegadoResult<Vec<i32>> {
    if !crate::engine_holder::is_initialized() {
        return Ok(Vec::new());
    }
    crate::engine_holder::cache_downloads()?.chapters(book_url, false)
}
pub fn cache_download_failed_chapters(book_url: &str) -> LegadoResult<Vec<i32>> {
    if !crate::engine_holder::is_initialized() {
        return Ok(Vec::new());
    }
    crate::engine_holder::cache_downloads()?.chapters(book_url, true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db_state::with_database;
    use legado_db::{BookChapterRepository, BookRepository};

    /// 未知任务：progress 返回 notFound，cancel 返回 false
    #[test]
    fn test_unknown_task() {
        let progress = cache_download_progress(u64::MAX).unwrap();
        assert_eq!(progress.status, "notFound");
        assert!(!cache_download_cancel(u64::MAX).unwrap());
    }

    /// 书籍不存在 / 无章节目录 → 报错
    #[test]
    fn test_start_validation() {
        let _db_guard = crate::db_state::ensure_test_db();
        let err = cache_download_start("http://no-such-book.example.com", 0, 10).unwrap_err();
        assert!(err.to_string().contains("书籍不存在"));
    }

    /// 本地 TXT 书批量下载：抓取链路走本地解析（无网络依赖），
    /// 完成后缓存可读、进度与终态正确
    #[test]
    fn test_local_book_batch_download() {
        let _db_guard = crate::db_state::ensure_test_db();
        crate::api::cache_api::clear_cache().unwrap();

        // 构造本地 TXT 文件 + 入库书与章节目录
        let dir = std::env::temp_dir().join("legado_r7_test");
        std::fs::create_dir_all(&dir).unwrap();
        let txt_path = dir.join("r7_batch.txt");
        std::fs::write(
            &txt_path,
            "第一章 开始\n\n这是第一章的正文内容。\n\n第二章 继续\n\n这是第二章的正文内容。\n\n第三章 结束\n\n这是第三章的正文内容。\n",
        )
        .unwrap();
        let book_url = txt_path.to_string_lossy().to_string();

        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "批量缓存测试",
            "author": "",
            "origin": "loc_book"
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();

        // 本地书章节目录由解析器懒加载入库（真实 start/end 偏移）
        let list = crate::api::reader::get_chapters(&book_url).unwrap();
        assert_eq!(list.total, 3, "TXT 应解析出 3 章");

        // 创建任务（全范围）
        let task_id = cache_download_start(&book_url, 0, 100).unwrap();
        let progress = cache_download_progress(task_id).unwrap();
        assert_eq!(progress.total, 3, "end 应按末章截断");

        // 等待 worker 完成（本地解析极快，轮询上限 5s）
        let final_progress = loop {
            let p = cache_download_progress(task_id).unwrap();
            if p.status != "running" {
                break p;
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
        };
        assert_eq!(final_progress.status, "completed", "任务应完成");
        assert_eq!(final_progress.completed + final_progress.failed, 3);

        // 任务列表包含该任务
        let list = cache_download_list().unwrap();
        assert!(list.iter().any(|t| t.task_id == task_id));

        // 取消已终态任务幂等返回 true
        assert!(cache_download_cancel(task_id).unwrap());

        // 清理
        with_database(|db| {
            let conn = db.connection();
            BookChapterRepository::new(conn).delete_by_book_url(&book_url)?;
            BookRepository::new(conn).delete_by_url(&book_url)
        })
        .unwrap();
        crate::api::cache_api::clear_cache().unwrap();
        let _ = std::fs::remove_file(&txt_path);
    }

    /// 取消机制：创建后立即取消，任务不应跑完全量（对照 CHECK_CANCELLED 语义）
    #[test]
    fn test_cancel_flag_set() {
        let _db_guard = crate::db_state::ensure_test_db();
        // 复用 test_local_book_batch_download 之外的独立书
        let dir = std::env::temp_dir().join("legado_r7_cancel_test");
        std::fs::create_dir_all(&dir).unwrap();
        let txt_path = dir.join("r7_cancel.txt");
        let mut content = String::new();
        for i in 0..20 {
            // 正文行不以「第X章」开头，避免被章节切分正则误判为标题行
            content.push_str(&format!("第{i}章 标题\n\n这是第{i}章的正文。\n\n"));
        }
        std::fs::write(&txt_path, &content).unwrap();
        let book_url = txt_path.to_string_lossy().to_string();

        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "取消测试",
            "author": "",
            "origin": "loc_book"
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();

        // 本地书章节目录由解析器懒加载入库
        let list = crate::api::reader::get_chapters(&book_url).unwrap();
        assert_eq!(list.total, 20, "TXT 应解析出 20 章");

        let task_id = cache_download_start(&book_url, 0, 19).unwrap();
        // 立即取消
        assert!(cache_download_cancel(task_id).unwrap());

        // 等待终态
        let final_progress = loop {
            let p = cache_download_progress(task_id).unwrap();
            if p.status != "running" {
                break p;
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
        };
        assert_eq!(
            final_progress.status, "cancelled",
            "取消后任务应进入 cancelled 终态"
        );
        assert!(
            final_progress.completed + final_progress.failed < 20,
            "取消后不应跑完全量章节"
        );

        // 清理
        with_database(|db| {
            let conn = db.connection();
            BookChapterRepository::new(conn).delete_by_book_url(&book_url)?;
            BookRepository::new(conn).delete_by_url(&book_url)
        })
        .unwrap();
        let _ = std::fs::remove_file(&txt_path);
    }

    /// P2-29：在途章集合 = 运行中任务的 next_index（区间内）；
    /// 终态后清空；无关书恒空；零写入（只读）
    #[test]
    fn test_running_chapters() {
        let _db_guard = crate::db_state::ensure_test_db();
        crate::api::cache_api::clear_cache().unwrap();

        // 200 章本地 TXT：保证 worker 运行窗口足够长，可稳定观测在途态
        let dir = std::env::temp_dir().join("legado_p229_running_test");
        std::fs::create_dir_all(&dir).unwrap();
        let txt_path = dir.join("p229_running.txt");
        let mut content = String::new();
        for i in 0..200 {
            content.push_str(&format!("第{i}章 标题\n\n这是第{i}章的正文。\n\n"));
        }
        std::fs::write(&txt_path, &content).unwrap();
        let book_url = txt_path.to_string_lossy().to_string();

        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "在途章查询测试",
            "author": "",
            "origin": "loc_book"
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();

        let list = crate::api::reader::get_chapters(&book_url).unwrap();
        assert_eq!(list.total, 200, "TXT 应解析出 200 章");

        let task_id = cache_download_start(&book_url, 0, 199).unwrap();

        // 运行中：在途章集合非空且恒在 [0, 199] 内
        let mut seen = 0usize;
        loop {
            let running = cache_download_running_chapters(&book_url).unwrap();
            if !running.is_empty() {
                assert!(
                    running.iter().all(|&i| (0..=199).contains(&i)),
                    "在途章应位于任务闭区间内: {running:?}"
                );
                seen += 1;
            }
            let p = cache_download_progress(task_id).unwrap();
            if p.status != "running" {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
        assert!(seen > 0, "任务运行期间应观测到非空在途章集合");

        // 终态：在途章集合清空（next_index 越出区间 / 状态非 running）
        assert!(
            cache_download_running_chapters(&book_url)
                .unwrap()
                .is_empty(),
            "任务终态后不应再有在途章"
        );
        // 无关书籍恒空
        assert!(
            cache_download_running_chapters("http://unrelated.example.com/book")
                .unwrap()
                .is_empty(),
            "无活跃任务的书籍应返回空集合"
        );

        // 清理
        with_database(|db| {
            let conn = db.connection();
            BookChapterRepository::new(conn).delete_by_book_url(&book_url)?;
            BookRepository::new(conn).delete_by_url(&book_url)
        })
        .unwrap();
        crate::api::cache_api::clear_cache().unwrap();
        let _ = std::fs::remove_file(&txt_path);
    }

    /// 轮询等待任务进入终态（上限 5s）
    fn wait_terminal(task_id: u64) -> CacheDownloadTask {
        for _ in 0..200 {
            let p = cache_download_progress(task_id).unwrap();
            if p.status != "running" {
                return p;
            }
            std::thread::sleep(std::time::Duration::from_millis(25));
        }
        panic!("任务超时未进入终态");
    }

    /// 构造本地 TXT 书并解析章节目录（返回 book_url 与入库章节）
    fn make_local_txt_book(
        dir_name: &str,
        file_name: &str,
        book_name: &str,
        chapter_count: usize,
    ) -> (String, Vec<legado_core::models::BookChapter>) {
        let dir = std::env::temp_dir().join(dir_name);
        std::fs::create_dir_all(&dir).unwrap();
        let txt_path = dir.join(file_name);
        let mut content = String::new();
        for i in 0..chapter_count {
            content.push_str(&format!("第{i}章 标题\n\n这是第{i}章的正文。\n\n"));
        }
        std::fs::write(&txt_path, &content).unwrap();
        let book_url = txt_path.to_string_lossy().to_string();
        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": book_name,
            "author": "",
            "origin": "loc_book"
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).unwrap();
        let chapters = crate::api::reader::get_chapters(&book_url).unwrap();
        assert_eq!(chapters.total, chapter_count as i32, "TXT 章节数应匹配");
        let rows = with_database(|db| {
            BookChapterRepository::new(db.connection()).find_by_book_url(&book_url)
        })
        .unwrap();
        (book_url, rows)
    }

    /// §2.43.8：失败记入集合（成功不入）、按书查询升序去重、重试/任务启动
    /// 取章清空（跨任务）、无任务书空集合、重复查询纯读
    #[test]
    fn test_failed_chapters_recorded_and_cleared_on_retry() {
        let _db_guard = crate::db_state::ensure_test_db();
        crate::api::cache_api::clear_cache().unwrap();

        let (book_url, chapters) = make_local_txt_book(
            "legado_p2438_failed_test",
            "p2438_failed.txt",
            "失败章查询测试",
            3,
        );

        // 删除第 0 章行 → 该章抓取必然失败（本地章节不存在），其余章成功。
        // 注意：删后 count=2，任务 0..2 的 end 会按末章截断为 1，
        // 恰好覆盖「缺失的第 0 章 + 正常第 1 章」
        let missing: Vec<_> = chapters.iter().filter(|c| c.index == 0).cloned().collect();
        assert_eq!(missing.len(), 1);
        // [B-7] delete_by_book_url 事务外为 no-op，须包 unchecked_transaction
        with_database(|db| {
            let conn = db.connection();
            let repo = BookChapterRepository::new(conn);
            let tx = conn
                .unchecked_transaction()
                .map_err(|e| legado_core::LegadoError::Database(format!("开启事务失败: {e}")))?;
            repo.delete_by_book_url(&book_url)?;
            let kept: Vec<_> = chapters.into_iter().filter(|c| c.index != 0).collect();
            repo.insert_batch_no_tx(&kept)?;
            tx.commit()
                .map_err(|e| legado_core::LegadoError::Database(format!("提交事务失败: {e}")))?;
            Ok(())
        })
        .unwrap();

        let task_id = cache_download_start(&book_url, 0, 2).unwrap();
        let final_progress = wait_terminal(task_id);
        assert_eq!(final_progress.status, "completed");
        assert_eq!(final_progress.completed, 1, "一章应成功（第 1 章）");
        assert_eq!(final_progress.failed, 1, "一章应失败（第 0 章）");

        // 失败记入集合：仅第 0 章（成功章不入集）；重复查询结果恒定（纯读）
        assert_eq!(
            cache_download_failed_chapters(&book_url).unwrap(),
            vec![0],
            "失败章集合应为升序 [0]"
        );
        assert_eq!(cache_download_failed_chapters(&book_url).unwrap(), vec![0]);
        // 无任务书籍恒空
        assert!(
            cache_download_failed_chapters("http://no-task-book.example.com")
                .unwrap()
                .is_empty(),
            "无任务书籍应返回空集合"
        );

        // 恢复第 0 章行 → 新任务重试该章：取章即清失败标记（任务启动清空/
        // 重试移除，跨任务清除），成功后集合为空
        with_database(|db| BookChapterRepository::new(db.connection()).insert_batch(&missing))
            .unwrap();
        let task2 = cache_download_start(&book_url, 0, 0).unwrap();
        let p2 = wait_terminal(task2);
        assert_ne!(task2, task_id, "终态任务不应复用，应新建任务");
        assert_eq!(p2.status, "completed");
        assert_eq!(p2.failed, 0);
        assert!(
            cache_download_failed_chapters(&book_url)
                .unwrap()
                .is_empty(),
            "重试成功后失败集合应清空（跨任务清除）"
        );

        // 清理
        with_database(|db| {
            let conn = db.connection();
            BookChapterRepository::new(conn).delete_by_book_url(&book_url)?;
            BookRepository::new(conn).delete_by_url(&book_url)
        })
        .unwrap();
        crate::api::cache_api::clear_cache().unwrap();
        let _ = std::fs::remove_file(&book_url);
    }
}
