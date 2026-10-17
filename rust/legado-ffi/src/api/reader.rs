//! 阅读宿主适配：捕获数据能力、解析本地路径并委托Engine服务。
#[cfg(test)]
use crate::db_state::with_database;
use legado_core::LegadoResult;
#[cfg(test)]
use legado_core::{
    LegadoError, cache_book::CachedChapter, models::ReplaceRule, web_book::WebChapter,
};
#[cfg(test)]
use legado_core::{
    models::BookChapter,
    web_book::{BookSourceFetcher, WebBookEngine},
};
#[cfg(test)]
use legado_db::{
    BookChapterRepository, BookRepository, BookSourceRepository, CacheBookRepository,
    ReplaceRuleRepository, repository::Repository,
};
pub use legado_engine::reading_service::{
    ChapterListResponse, can_remove_same_title, chapter_to_local_info, is_local_book,
    word_count_format,
};
use legado_engine::reading_service::{ReadingResources, ReadingService};
#[cfg(test)]
use legado_engine::reading_service::{
    chinese_convert_direction, convert_title_by_type, process_content_with_rules_inner,
};
use std::sync::Arc;
/// 只在宿主入口装配一次，不让异步闭包回查根实例。
pub(crate) fn host_service() -> ReadingService {
    let engine = crate::engine_holder::current().ok();
    let storage = engine.as_ref().map(|e| e.storage().clone());
    let paths = storage.clone();
    ReadingService::new(ReadingResources {
        storage,
        deps: engine.as_ref().map(|e| super::web_book::deps_for_engine(e)),
        tasks: crate::engine_holder::task_group(),
        runtime: crate::runtime::get_runtime().handle().clone(),
        web_book: crate::engine_holder::web_book_state(),
        js: crate::engine_holder::js_resources(),
        search: super::search::service_for_engine(engine.as_deref()),
        resolve_path: Arc::new(move |book| {
            if book.contains("://") || std::path::Path::new(book).is_absolute() {
                return book.into();
            }
            paths
                .as_ref()
                .and_then(|s| s.path())
                .and_then(std::path::Path::parent)
                .map(|base| base.join(book).to_string_lossy().into_owned())
                .unwrap_or_else(|| book.into())
        }),
    })
}

pub fn get_chinese_convert_type() -> i32 {
    host_service().get_chinese_convert_type()
}

pub fn set_chinese_convert_type(convert_type: i32) {
    host_service().set_chinese_convert_type(convert_type)
}

pub fn get_same_title_removed(book_url: &str, chapter_index: i32) -> bool {
    host_service().get_same_title_removed(book_url, chapter_index)
}

pub fn toggle_same_title_removed(
    book_url: &str,
    chapter_index: i32,
    enable: bool,
) -> LegadoResult<()> {
    host_service().toggle_same_title_removed(book_url, chapter_index, enable)
}

pub fn get_chapters(book_url: &str) -> LegadoResult<ChapterListResponse> {
    host_service().get_chapters(book_url)
}

pub fn get_chapter_content(book_url: &str, chapter_index: i32) -> LegadoResult<String> {
    host_service().get_chapter_content(book_url, chapter_index)
}

pub fn get_chapter_content_raw(book_url: &str, chapter_index: i32) -> LegadoResult<String> {
    host_service().get_chapter_content_raw(book_url, chapter_index)
}

pub fn fetch_chapter_content(
    book_url: &str,
    chapter_url: &str,
    source_url: &str,
) -> LegadoResult<String> {
    host_service().fetch_chapter_content(book_url, chapter_url, source_url)
}

pub fn get_chapter_content_full(book_url: &str, chapter_index: i32) -> LegadoResult<String> {
    host_service().get_chapter_content_full(book_url, chapter_index)
}

pub fn apply_content_processing(book_url: &str, raw_content: &str, chapter_title: &str) -> String {
    host_service().apply_content_processing(book_url, raw_content, chapter_title)
}

pub fn apply_content_processing_chapter(
    book_url: &str,
    raw_content: &str,
    chapter_title: &str,
    chapter_index: i32,
) -> String {
    host_service().apply_content_processing_chapter(
        book_url,
        raw_content,
        chapter_title,
        chapter_index,
    )
}

pub fn apply_content_processing_raw(
    book_url: &str,
    raw_content: &str,
    chapter_title: &str,
    chapter_index: Option<i32>,
) -> String {
    host_service().apply_content_processing_raw(book_url, raw_content, chapter_title, chapter_index)
}

pub fn refresh_toc(book_url: &str, source_url: &str) -> LegadoResult<ChapterListResponse> {
    // P1-2 入口收口：本入口执行 preUpdate JS + ruleBookInfo/ruleToc（变量桥
    // 读写）→ 先切 flow scope（键 = book_url，与 webbook_info/chapters 同键），
    // 防上一流程的残留 scope 串读/误清
    // 生产入口：构建真实 engine 后委托核心逻辑（fetcher 泛型化便于单测注入脚本化 fetcher）
    let engine = super::web_book::build_engine()?;
    host_service().refresh_toc_with_fetcher(book_url, source_url, &engine)
}

#[cfg(test)]
fn refresh_toc_with_fetcher<F: BookSourceFetcher>(
    book_url: &str,
    source_url: &str,
    engine: &WebBookEngine<F>,
) -> LegadoResult<ChapterListResponse> {
    host_service().refresh_toc_with_fetcher(book_url, source_url, engine)
}

#[cfg(test)]
fn save_chapter_cache(
    book_url: &str,
    chapter_index: i32,
    chapter_title: &str,
    chapter_url: &str,
    content: &str,
) -> bool {
    crate::engine_holder::current().is_ok_and(|engine| {
        super::chapter_content::save_chapter_cache(
            engine.storage(),
            book_url,
            chapter_index,
            chapter_title,
            chapter_url,
            content,
        )
    })
}

#[cfg(test)]
fn process_content_with_rules(
    raw_content: &str,
    chapter_title: &str,
    rules: &[ReplaceRule],
    book_name: &str,
) -> String {
    process_content_with_rules_inner(
        raw_content,
        chapter_title,
        rules,
        book_name,
        true,
        None,
        true,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use legado_core::models::BookSource;
    use legado_core::models::rule::ContentRule;

    /// 初始化测试数据库并持锁（返回串行锁守卫，测试必须绑定到变量）
    fn setup_db_and_source(source_url: &str) -> std::sync::MutexGuard<'static, ()> {
        let db_guard = crate::db_state::ensure_test_db();
        insert_test_source(source_url);
        db_guard
    }

    /// 插入测试书源
    fn insert_test_source(source_url: &str) {
        with_database(|db| {
            let repo = BookSourceRepository::new(db.connection());
            let source = BookSource {
                book_source_url: source_url.to_string(),
                book_source_name: "测试书源".to_string(),
                search_url: Some(format!("{source_url}/search?q={{key}}")),
                rule_content: Some(ContentRule {
                    content: Some("css(.content).html".to_string()),
                    ..ContentRule::default()
                }),
                ..BookSource::default()
            };
            repo.insert(&source)?;
            Ok(())
        })
        .unwrap();
    }

    // ─── [cbz 批 B | 2026-10-03] 本地漫画白名单与懒解析链路 ────────────────

    /// c) `is_local_book` 白名单含 `.cbz`；`.zip` 仍为 false（压缩容器回归）
    #[test]
    fn is_local_book_includes_cbz_excludes_zip() {
        // cbz（大小写不敏感）
        assert!(is_local_book("/books/本地漫画.cbz"));
        assert!(is_local_book("/books/COMIC.CBZ"));
        // .zip 保持压缩容器语义：不在本地书白名单（回归）
        assert!(!is_local_book("/books/archive.zip"));
        assert!(!is_local_book("/books/ARCHIVE.ZIP"));
        // 既有白名单回归
        assert!(is_local_book("/books/a.epub"));
        assert!(is_local_book("/books/a.txt"));
        assert!(is_local_book("/books/a.text"));
        assert!(is_local_book("/books/a.mobi"));
        assert!(is_local_book("/books/a.azw"));
        assert!(is_local_book("/books/a.azw3"));
        assert!(is_local_book("/books/a.pdf"));
        assert!(!is_local_book("/books/a.umd"));
        assert!(!is_local_book("/books/a.epub.bak"));
    }

    /// `.cbz` 加入白名单后端到端：懒解析目录（1 章、url 置空）→ 正文为
    /// `cbz://` 条目行（批 A `CbzFile` 接线回归；cbz_api 单测另验字节读取）
    #[test]
    fn cbz_local_book_lazy_toc_and_content_end_to_end() {
        use std::io::Write as _;
        use std::sync::atomic::{AtomicUsize, Ordering};
        static CTR: AtomicUsize = AtomicUsize::new(0);
        let n = CTR.fetch_add(1, Ordering::SeqCst);
        let dir = std::env::temp_dir().join(format!("legado_cbz_e2e_{}_{}", std::process::id(), n));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let cbz_path = dir.join("本地 漫画.cbz");
        {
            let file = std::fs::File::create(&cbz_path).unwrap();
            let mut writer = zip::ZipWriter::new(file);
            let options = zip::write::SimpleFileOptions::default();
            for (name, data) in [
                ("02.jpg", b"page-two".as_slice()),
                ("01 封面.jpg", b"page-one".as_slice()),
                ("readme.txt", b"ignored".as_slice()),
            ] {
                writer.start_file(name, options).unwrap();
                writer.write_all(data).unwrap();
            }
            writer.finish().unwrap();
        }
        let book_url = cbz_path.to_string_lossy().into_owned();

        let _db_guard = crate::db_state::ensure_test_db();
        // books 行（书架入口语义；懒加载分支会同步 B-13b 派生字段）
        let book_json = serde_json::json!({
            "bookUrl": book_url,
            "name": "本地 漫画",
            "origin": "loc_book"
        })
        .to_string();
        crate::api::bookshelf::add_book(&book_json).expect("本地漫画入库");

        // 懒解析：整包 1 章、章节 url 置空、标题 = 文件名去扩展名
        let chapters = get_chapters(&book_url).expect("cbz 章节懒解析");
        assert_eq!(chapters.total, 1, "CBZ 整包应固定 1 章");
        assert_eq!(chapters.chapters[0].url, "", "CBZ 章节 url 应置空");
        assert_eq!(chapters.chapters[0].title, "本地 漫画");

        // 正文：自然排序的 cbz:// 行列表（仅图片条目）
        let content = get_chapter_content(&book_url, 0).expect("cbz 正文");
        let lines: Vec<&str> = content.lines().collect();
        assert_eq!(lines.len(), 2, "content={content}");
        assert_eq!(lines[0], "cbz://01 封面.jpg");
        assert_eq!(lines[1], "cbz://02.jpg");
        assert!(!content.contains("readme.txt"));

        // 收尾清理：章节行 + 书行 + 文件
        with_database(|db| {
            BookChapterRepository::new(db.connection()).delete_by_book_url(&book_url)?;
            BookRepository::new(db.connection()).delete_by_url(&book_url)?;
            Ok(())
        })
        .unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }

    // ─── [iOS 视角F C1] 本地书「相对可迁移标识」读写回环 ─────────────────────

    /// 相对标识使用实际数据库所在目录还原路径，不另改全局路径。
    #[test]
    fn local_book_relative_identifier_roundtrip() {
        let _db_guard = crate::db_state::ensure_test_db();
        let db_path = crate::db_state::current_db_path().unwrap();
        let base = std::path::Path::new(&db_path).parent().unwrap();
        let relative = format!("books/relative_roundtrip_{}/sample.txt", std::process::id());
        let file = base.join(&relative);
        let books = file.parent().unwrap();
        std::fs::create_dir_all(books).unwrap();
        std::fs::write(&file, "第一章\n正文一\n\n第二章\n正文二\n").unwrap();

        let res = crate::api::book_import::import_local_book(&relative).unwrap();
        assert!(res.success, "导入失败: {:?}", res.error);
        assert_eq!(res.book.as_ref().unwrap().book_url, relative);
        let chapters = get_chapters(&relative).unwrap();
        assert!(chapters.total >= 1, "相对标识应能解析出章节");
        let content = get_chapter_content(&relative, 0).unwrap();
        assert!(!content.trim().is_empty(), "应能读到正文");
        assert_eq!(
            crate::db_state::current_db_path().as_deref(),
            Some(db_path.as_str())
        );

        with_database(|db| {
            BookChapterRepository::new(db.connection()).delete_by_book_url(&relative)?;
            BookRepository::new(db.connection()).delete_by_url(&relative)?;
            Ok(())
        })
        .unwrap();
        let _ = std::fs::remove_dir_all(books);
    }

    // ─── refresh_toc 测试 ───────────────────────────────────────────────────

    /// 网络测试：需要真实网络访问，CI 中忽略
    #[test]
    #[ignore = "requires network access"]
    fn test_refresh_toc_success() {
        // refresh_toc 入口执行 begin_book_flow（切 flow scope）→ 触碰全局
        // store，持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let source_url = "https://toc-test.example.com";
        let book_url = "https://toc-test.example.com/book/1";
        let _db_guard = setup_db_and_source(source_url);

        let resp = refresh_toc(book_url, source_url).unwrap();
        assert!(resp.total >= 0);
    }

    #[test]
    fn test_refresh_toc_source_not_found() {
        // P2-1：refresh_toc 入口在 DB 查询前执行 begin_book_flow（切
        // flow scope，清旧前缀）→ 触碰全局 store 状态，须与其它 store
        // 测试串行（共享 crate 级 test_support 锁）；结尾复位 flow scope
        let _lock = crate::test_support::lock_global_store();
        let _db_guard = setup_db_and_source("https://other.example.com");
        let err = refresh_toc("https://x.com/book", "https://nonexistent.example.com").unwrap_err();
        assert!(err.to_string().contains("书源不存在"));
    }

    /// refresh_toc 占位落库须打 NOT_SHELF，书架 list 不可见（Task#125）
    #[test]
    fn test_refresh_toc_placeholder_not_on_shelf() {
        use legado_core::models::book::book_type;
        use legado_db::BookRepository;

        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://placeholder-not-shelf.example.com/book/1";

        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: "https://src.example.com".to_string(),
                origin_name: "测试书源".to_string(),
                book_type: book_type::NOT_SHELF,
                ..legado_core::models::Book::default()
            };
            book_repo.insert(&book)?;
            let saved = book_repo.find_by_url(book_url)?.unwrap();
            assert_ne!(saved.book_type & book_type::NOT_SHELF, 0);
            let shelf = book_repo.find_all_in_shelf()?;
            assert!(!shelf.iter().any(|b| b.book_url == book_url));
            Ok(())
        })
        .unwrap();
    }

    /// 网络测试：需要真实网络访问，CI 中忽略
    #[test]
    #[ignore = "requires network access"]
    fn test_refresh_toc_saves_to_db() {
        // refresh_toc 入口执行 begin_book_flow（切 flow scope）→ 触碰全局
        // store，持 crate 级 test_support 锁串行防串表
        let _lock = crate::test_support::lock_global_store();
        let source_url = "https://toc-db-test.example.com";
        let book_url = "https://toc-db-test.example.com/book/2";
        let _db_guard = setup_db_and_source(source_url);

        let resp = refresh_toc(book_url, source_url).unwrap();
        assert!(resp.total >= 0);
    }

    // ─── [P2-2] 存量坏 tocUrl 自愈测试 ─────────────────────────────────────

    /// [P2-2] 脚本化目录 fetcher：按 URL 返回预置章节（未命中 → 空列表），
    /// 记录每次 get_chapters 请求 URL 供断言
    struct ScriptedTocFetcher {
        chapters_by_url: Vec<(String, Vec<WebChapter>)>,
        requested: std::sync::Arc<std::sync::Mutex<Vec<String>>>,
        /// [P2-1 复审] 自愈回写调用点回归测试：在首次抓取（坏 tocUrl）时模拟刷新窗口
        /// （抓取前快照读取之后、tocUrl 回写之前）发生的「并发进度写入」——把该书的
        /// durChapterIndex 置为 7。单列 update_toc_url 只触碰 tocUrl 不会覆盖它；若调用点
        /// 退回旧的全行 update 形式，抓取前快照里的 0 会覆盖掉 7（丢更新）。仅自愈测试置
        /// Some，其它测试置 None 不受影响。
        seed_progress_book_url: Option<String>,
    }

    impl BookSourceFetcher for ScriptedTocFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<legado_core::web_book::WebBookInfo> {
            Err(LegadoError::Internal("mock: get_book_info unused".into()))
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            let mut req = self.requested.lock().unwrap_or_else(|e| e.into_inner());
            let is_first_fetch = req.is_empty();
            req.push(book_url.to_string());
            drop(req);

            // [P2-1 复审] 模拟刷新窗口内的「并发进度写入」：只在首次抓取（坏 tocUrl）播种，
            // 避开重试抓取，确保落在「快照读取之后、tocUrl 回写之前」的丢更新窗口内。
            if is_first_fetch && let Some(burl) = &self.seed_progress_book_url {
                let _ = with_database(|db| {
                    use rusqlite::params;
                    db.connection()
                        .execute(
                            "UPDATE books SET durChapterIndex = 7 WHERE bookUrl = ?1",
                            params![burl],
                        )
                        .map_err(|e| {
                            LegadoError::Database(format!("播种 durChapterIndex 失败: {e}"))
                        })?;
                    Ok(())
                });
            }

            Ok(self
                .chapters_by_url
                .iter()
                .find(|(u, _)| u == book_url)
                .map(|(_, c)| c.clone())
                .unwrap_or_default())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }
    }

    /// [P2-2] 存量坏 tocUrl 自愈：首抓按坏 tocUrl 未解析到章节 → 按书籍页
    /// 取址点（originBookUrl）重试一次；成功则持久化新 tocUrl，后续刷新直达
    #[test]
    fn test_refresh_toc_self_heals_bad_toc_url() {
        use std::sync::{Arc, Mutex};

        let book_url = "https://p2-2-heal.example.com/book/1";
        let source_url = "https://p2-2-heal-src.example.com";
        let bad_toc = "https://p2-2-heal.example.com/old-toc";
        let detail_url = "https://p2-2-heal-src.example.com/book/1";

        let _db_guard = setup_db_and_source(source_url);
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                origin_name: "测试书源".to_string(),
                name: "自愈书".to_string(),
                toc_url: bad_toc.to_string(),
                origin_book_url: detail_url.to_string(),
                ..legado_core::models::Book::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let requested = Arc::new(Mutex::new(Vec::new()));
        let fetcher = ScriptedTocFetcher {
            chapters_by_url: vec![
                (bad_toc.to_string(), vec![]),
                (
                    detail_url.to_string(),
                    vec![WebChapter {
                        index: 0,
                        title: "第一章".to_string(),
                        url: format!("{detail_url}/c1"),
                        is_vip: false,
                        is_volume: false,
                        variable: None,
                        word_count: None,
                    }],
                ),
            ],
            requested: Arc::clone(&requested),
            seed_progress_book_url: Some(book_url.to_string()),
        };
        let engine = WebBookEngine::new(fetcher);
        let resp = refresh_toc_with_fetcher(book_url, source_url, &engine).expect("自愈刷新应成功");
        assert_eq!(resp.total, 1, "重试后应解析到 1 个章节");

        let reqs = requested.lock().unwrap_or_else(|e| e.into_inner()).clone();
        assert_eq!(
            reqs,
            vec![bad_toc.to_string(), detail_url.to_string()],
            "应先按坏 tocUrl 抓取，再按书籍页取址点重试"
        );

        // 新 tocUrl 已持久化（对齐既有 update 语义）
        with_database(|db| {
            let saved = BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .expect("书籍记录应仍存在");
            assert_eq!(saved.toc_url, detail_url, "成功地址应持久化为新 tocUrl");
            // [P2-1 复审] 调用点回归检测：刷新窗口内并发写入的进度列
            // （durChapterIndex=7，由 get_chapters 首次抓取时播种）必须保留。
            // 单列 update_toc_url 只触碰 tocUrl；若调用点退回旧的全行 update 形式，
            // 抓取前 37 列快照里的 0 会覆盖 7 → 本断言失败。
            assert_eq!(
                saved.dur_chapter_index, 7,
                "刷新窗口内并发写入的进度列（durChapterIndex=7）不得被抓取前全行快照覆盖"
            );
            Ok(())
        })
        .expect("DB 断言失败");

        // 收尾清理，避免污染共享测试库
        with_database(|db| {
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            let _ = BookRepository::new(db.connection()).delete(book_url);
            Ok(())
        })
        .ok();
    }

    /// [P2-2] tocUrl 与 originBookUrl 均为空时，首抓地址即入参 bookUrl（书籍页
    /// 取址点的最终回退），不存在「坏值重试」对象 → 不得重复抓取；仍为空时
    /// 走既有空结果保护（无既有章节 → 可读错误）
    #[test]
    fn test_refresh_toc_no_duplicate_retry_when_toc_url_empty() {
        use std::sync::{Arc, Mutex};

        let book_url = "https://p2-2-noretry.example.com/book/1";
        let source_url = "https://p2-2-noretry-src.example.com";

        let _db_guard = setup_db_and_source(source_url);
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                origin_name: "测试书源".to_string(),
                name: "无重试书".to_string(),
                ..legado_core::models::Book::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let requested = Arc::new(Mutex::new(Vec::new()));
        let fetcher = ScriptedTocFetcher {
            chapters_by_url: vec![(book_url.to_string(), vec![])],
            requested: Arc::clone(&requested),
            seed_progress_book_url: None,
        };
        let engine = WebBookEngine::new(fetcher);
        let err = refresh_toc_with_fetcher(book_url, source_url, &engine)
            .expect_err("未解析到章节且无既有目录应返回可读错误");
        assert!(
            err.to_string().contains("未从书源解析到任何章节"),
            "应走既有空结果保护的可读错误文案"
        );

        let reqs = requested.lock().unwrap_or_else(|e| e.into_inner()).clone();
        assert_eq!(
            reqs,
            vec![book_url.to_string()],
            "取址点与首抓地址相同时不得重复重试"
        );

        // 收尾清理
        with_database(|db| {
            let _ = BookRepository::new(db.connection()).delete(book_url);
            Ok(())
        })
        .ok();
    }

    /// [目录派生字段同步] refresh_toc 成功后 books 行 totalChapterNum/
    /// latestChapterTitle 同步为新目录值（红态：刷新前 999/「旧最新章节」；
    /// 修复前第 4 步事务只删章+插章+清缓存，派生字段不触碰 → 书架「共 N 章」
    /// 与详情页「最新·…」保持旧值）。真实 origin 书籍走单列 UPDATE 写器
    /// （B-3 安全：不写进度列——播种 durChapterIndex=42 断言不被覆盖）。
    #[test]
    fn test_refresh_toc_syncs_toc_derived_fields() {
        use std::sync::{Arc, Mutex};

        let book_url = "https://toc-sync.example.com/book/1";
        let source_url = "https://toc-sync-src.example.com";
        let toc_url = "https://toc-sync.example.com/toc";

        let _db_guard = setup_db_and_source(source_url);
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                origin_name: "测试书源".to_string(),
                name: "同步书".to_string(),
                toc_url: toc_url.to_string(),
                // 红态播种：陈旧的目录派生字段 + 进度列（B-3 回归哨兵）
                total_chapter_num: 999,
                latest_chapter_title: Some("旧最新章节".to_string()),
                dur_chapter_index: 42,
                ..legado_core::models::Book::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let requested = Arc::new(Mutex::new(Vec::new()));
        let fetcher = ScriptedTocFetcher {
            chapters_by_url: vec![(
                toc_url.to_string(),
                (0..4)
                    .map(|i| WebChapter {
                        index: i,
                        title: format!("新目录第{i}章"),
                        url: format!("{toc_url}/c{i}"),
                        is_vip: false,
                        is_volume: false,
                        variable: None,
                        word_count: None,
                    })
                    .collect(),
            )],
            requested: Arc::clone(&requested),
            seed_progress_book_url: None,
        };
        let engine = WebBookEngine::new(fetcher);
        let resp = refresh_toc_with_fetcher(book_url, source_url, &engine).expect("目录刷新应成功");
        assert_eq!(resp.total, 4, "应解析到 4 个章节");

        with_database(|db| {
            let saved = BookRepository::new(db.connection())
                .find_by_url(book_url)?
                .expect("书籍记录应仍存在");
            assert_eq!(
                saved.total_chapter_num, 4,
                "totalChapterNum 应同步为新目录章数（不得保留旧值 999）"
            );
            assert_eq!(
                saved.latest_chapter_title.as_deref(),
                Some("新目录第3章"),
                "latestChapterTitle 应同步为新目录末章标题（不得保留旧值）"
            );
            assert_eq!(
                saved.dur_chapter_index, 42,
                "进度列（durChapterIndex=42）不得被派生字段同步覆盖（B-3）"
            );
            Ok(())
        })
        .expect("DB 断言失败");

        // 收尾清理
        with_database(|db| {
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            let _ = BookRepository::new(db.connection()).delete(book_url);
            Ok(())
        })
        .ok();
    }

    // ─── [P2-12] 目录刷新变量链测试（2026-09-18） ───────────────────────────

    /// [P2-12] 脚本化目录 fetcher（变量表版）：捕获
    /// `get_chapters_with_hints_and_vars` 收到的变量表并返回预置章节
    struct ScriptedTocFetcherWithVars {
        vars_requested:
            std::sync::Arc<std::sync::Mutex<Vec<std::collections::HashMap<String, String>>>>,
    }

    impl BookSourceFetcher for ScriptedTocFetcherWithVars {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<legado_core::web_book::WebBookInfo> {
            Err(LegadoError::Internal("mock: get_book_info unused".into()))
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            Ok(Vec::new())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }

        async fn get_chapters_with_hints_and_vars(
            &self,
            _source: &BookSource,
            _book_url: &str,
            known_toc_url: Option<&str>,
            _book_name_hint: Option<&str>,
            variables: &std::collections::HashMap<String, String>,
        ) -> LegadoResult<Vec<WebChapter>> {
            self.vars_requested
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push(variables.clone());
            Ok(vec![WebChapter {
                index: 0,
                title: "第一章".to_string(),
                url: known_toc_url
                    .map(|u| format!("{u}/c1"))
                    .unwrap_or_else(|| "https://p212.example.com/c1".to_string()),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            }])
        }
    }

    /// [P2-12] 刷新目录：DB `books.variable`（working_book.variable，
    /// preUpdateJs 钩子后已持久化的用户值）必须传入 fetcher 变量表——
    /// 修复前回归：refresh_toc 两处抓取变量表恒空 → 目录/详情模板
    /// `{{svid}}`/`{{tok}}` 展开为空 → 请求错误地址（服务端 400）
    #[test]
    fn test_refresh_toc_passes_db_variables_to_fetcher() {
        use std::sync::{Arc, Mutex};

        let book_url = "https://p212.example.com/r1vb/detail?vid={{svid}}";
        let source_url = "https://p212-src.example.com";
        let toc_url = "https://p212.example.com/r1vb/toc?tok={{tok}}";
        let var_json = r#"{"svid":"VID123","tok":"TK777"}"#;

        let _db_guard = setup_db_and_source(source_url);
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                origin_name: "测试书源".to_string(),
                name: "P12变量书".to_string(),
                toc_url: toc_url.to_string(),
                origin_book_url: book_url.to_string(),
                variable: Some(var_json.to_string()),
                ..legado_core::models::Book::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let vars_requested = Arc::new(Mutex::new(Vec::new()));
        let fetcher = ScriptedTocFetcherWithVars {
            vars_requested: Arc::clone(&vars_requested),
        };
        let engine = WebBookEngine::new(fetcher);
        let resp =
            refresh_toc_with_fetcher(book_url, source_url, &engine).expect("携变量目录刷新应成功");
        assert_eq!(resp.total, 1, "应解析到 1 个章节");

        let vars = vars_requested
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone();
        assert_eq!(
            vars.len(),
            1,
            "刷新应恰好抓取一次目录（变量表正确时无坏址重试）"
        );
        assert_eq!(
            vars[0].get("svid").map(String::as_str),
            Some("VID123"),
            "svid 应自 DB books.variable 传入 fetcher（修复前恒空表）"
        );
        assert_eq!(
            vars[0].get("tok").map(String::as_str),
            Some("TK777"),
            "tok 应自 DB books.variable 传入 fetcher（修复前恒空表）"
        );

        // 收尾清理，避免污染共享测试库
        with_database(|db| {
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            let _ = BookRepository::new(db.connection()).delete(book_url);
            Ok(())
        })
        .ok();
    }

    // ─── [bookUrl 脏值修正 2026-10-05] 目录抓取链身份/取址点分离测试 ────────

    /// 捕获 refresh_toc 传给 fetcher 的（取址点, 书籍主键）二元组
    struct KeyCapturingTocFetcher {
        captured: std::sync::Arc<std::sync::Mutex<Vec<(String, String)>>>,
    }

    impl BookSourceFetcher for KeyCapturingTocFetcher {
        async fn search(
            &self,
            _source: &BookSource,
            _query: &str,
            _page: i32,
        ) -> LegadoResult<Vec<legado_core::web_book::WebSearchResult>> {
            Err(LegadoError::Internal("mock: search unused".into()))
        }

        async fn get_book_info(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<legado_core::web_book::WebBookInfo> {
            Err(LegadoError::Internal("mock: get_book_info unused".into()))
        }

        async fn get_chapters(
            &self,
            _source: &BookSource,
            _book_url: &str,
        ) -> LegadoResult<Vec<WebChapter>> {
            // 旧调用形态（未传书籍主键）落到这里：返回空让红态可见
            Ok(Vec::new())
        }

        async fn get_content(
            &self,
            _source: &BookSource,
            _chapter: &WebChapter,
        ) -> LegadoResult<String> {
            Err(LegadoError::Internal("mock: content unused".into()))
        }

        async fn get_chapters_with_book_key_and_vars(
            &self,
            _source: &BookSource,
            book_url: &str,
            book_key: &str,
            _known_toc_url: Option<&str>,
            _book_name_hint: Option<&str>,
            _variables: &std::collections::HashMap<String, String>,
        ) -> LegadoResult<Vec<WebChapter>> {
            self.captured
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .push((book_url.to_string(), book_key.to_string()));
            Ok(vec![WebChapter {
                index: 0,
                title: "第一章".to_string(),
                url: format!("{book_url}/c1"),
                is_vip: false,
                is_volume: false,
                variable: None,
                word_count: None,
            }])
        }
    }

    /// [bookUrl 脏值修正] 刷新目录链（入库书）：fetcher 收到的取址点必须是
    /// DB `books.tocUrl`、书籍主键必须是 DB `books.bookUrl`——修复前旧调用只
    /// 传 fetch_url（tocUrl）当 book_url，meta 缓存把 tocUrl 记成“书籍取址点”
    /// → 正文阶段 (书源, 章节) 反查拿到脏值交弹幕 sink（B1 落库侧兜底）。
    #[test]
    fn test_refresh_toc_passes_book_key_not_fetch_url() {
        use std::sync::{Arc, Mutex};

        let book_url = "https://bookkey-not-fetch.example.com/book/1";
        let source_url = "https://bookkey-not-fetch-src.example.com";
        let toc_url = "https://bookkey-not-fetch.example.com/toc-page";

        let _db_guard = setup_db_and_source(source_url);
        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                origin_name: "测试书源".to_string(),
                name: "主键书".to_string(),
                toc_url: toc_url.to_string(),
                ..legado_core::models::Book::default()
            })?;
            Ok(())
        })
        .expect("初始数据写入失败");

        let captured = Arc::new(Mutex::new(Vec::new()));
        let fetcher = KeyCapturingTocFetcher {
            captured: Arc::clone(&captured),
        };
        let engine = WebBookEngine::new(fetcher);
        let resp = refresh_toc_with_fetcher(book_url, source_url, &engine).expect("目录刷新应成功");
        assert_eq!(resp.total, 1, "应解析到 1 个章节");

        let got = captured.lock().unwrap_or_else(|e| e.into_inner()).clone();
        assert_eq!(
            got,
            vec![(toc_url.to_string(), book_url.to_string())],
            "刷新链须向 fetcher 传（取址点 = DB tocUrl, 主键 = DB bookUrl）两个值；\
             修复前只传取址点当 book_url → meta 缓存 bookUrl 脏值"
        );

        // 收尾清理，避免污染共享测试库
        with_database(|db| {
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            let _ = BookRepository::new(db.connection()).delete(book_url);
            Ok(())
        })
        .ok();
    }

    // ─── fetch_chapter_content 测试 ──────────────────────────────────────────

    /// 网络测试：需要真实网络访问，CI 中忽略
    #[test]
    #[ignore = "requires network access"]
    fn test_fetch_chapter_content_success() {
        let source_url = "https://content-test.example.com";
        let book_url = "https://content-test.example.com/book/1";
        let chapter_url = format!("{book_url}/chapter/0");
        let _db_guard = setup_db_and_source(source_url);

        let content = fetch_chapter_content(book_url, &chapter_url, source_url).unwrap();
        assert!(!content.is_empty());
    }

    /// 网络测试：需要真实网络访问，CI 中忽略
    #[test]
    #[ignore = "requires network access"]
    fn test_fetch_chapter_content_cache_hit() {
        let source_url = "https://cache-test.example.com";
        let book_url = "https://cache-test.example.com/book/1";
        let chapter_url = "https://cache-test.example.com/ch/99";
        let _db_guard = setup_db_and_source(source_url);

        // 第一次调用：从网络获取并缓存
        let content1 = fetch_chapter_content(book_url, chapter_url, source_url).unwrap();
        assert!(!content1.is_empty());

        // 第二次调用：应命中缓存，返回相同内容
        let content2 = fetch_chapter_content(book_url, chapter_url, source_url).unwrap();
        assert_eq!(content1, content2);
    }

    // ─── 阅读获取成功后写入缓存测试（Task #26）─────────────────────

    /// 阅读获取成功后缓存写入生效：save_chapter_cache 写入 cached_chapters，
    /// 复合键可查、目录页云图标数据源 list_cached_chapter_urls 可见，
    /// 重复写入（同章再次阅读）覆盖不报错
    #[test]
    fn test_save_chapter_cache_after_successful_fetch() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://cache-write-t26.example.com/book/1";
        let chapter_url = "https://cache-write-t26.example.com/ch/4";

        // 前置：该章未缓存（目录页空心云）
        let before = with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.get_by_book_and_chapter_url(book_url, chapter_url)
        })
        .unwrap();
        assert!(before.is_none());

        // 抓取成功后写缓存（fetch_chapter_content_inner 同一时机）
        save_chapter_cache(book_url, 4, "第四章", chapter_url, "第四章正文");

        // 复合键命中（目录页实心云）
        let cached = with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.get_by_book_and_chapter_url(book_url, chapter_url)
        })
        .unwrap()
        .expect("阅读获取成功后应写入缓存");
        assert_eq!(cached.content, "第四章正文");
        assert_eq!(cached.chapter_index, 4);
        assert_eq!(cached.chapter_title, "第四章");

        // 目录页云图标数据源可见
        let urls = crate::api::cache_api::list_cached_chapter_urls(book_url).unwrap();
        assert!(urls.contains(&chapter_url.to_string()));

        // 同章重复写入覆盖不报错（INSERT OR REPLACE）
        save_chapter_cache(book_url, 4, "第四章", chapter_url, "第四章正文v2");
        let cached = with_database(|db| {
            let repo = CacheBookRepository::new(db.connection());
            repo.get_by_book_and_chapter_url(book_url, chapter_url)
        })
        .unwrap()
        .unwrap();
        assert_eq!(cached.content, "第四章正文v2");
    }

    // ─── [P2-28b] 章节字数回填链测试（对齐原版 BookHelp.writeText → upWordCount）──

    /// 辅助：读取指定书指定 index 章节的 wordCount
    fn read_chapter_word_count(book_url: &str, index: i32) -> Option<String> {
        with_database(|db| {
            Ok(BookChapterRepository::new(db.connection())
                .find_by_book_url_and_index(book_url, index)?
                .and_then(|c| c.word_count))
        })
        .unwrap_or_default()
    }

    /// [P2-28b] word_count_format 与原版 StringUtils.wordCountFormat 逐值对齐
    ///
    /// 原版：words≤0 → ""；0<words≤10000 → "{words}字"；words>10000 →
    /// `DecimalFormat("#.#").format(words * 1.0f / 10000f.toDouble()) + "万字"`。
    /// DecimalFormat 按 double 的精确二进制值 HALF_EVEN 舍入，故以下用例覆盖
    /// 浮点怪癖值：10500（1.05 双精度略高于 1.05 → 1.1）、12500（1.25 精确
    /// 平局 → HALF_EVEN 取偶 1.2）、13500（1.35 双精度略高于 1.35 → 1.4）、
    /// 14999/15000（同为 1.5）、10001/99999（去尾零形态）
    #[test]
    fn test_word_count_format_aligned_with_original() {
        let cases = [
            (0usize, ""),
            (1, "1字"),
            (9999, "9999字"),
            (10000, "10000字"),
            (10001, "1万字"),
            (10500, "1.1万字"),
            (12500, "1.2万字"),
            (13500, "1.4万字"),
            (14999, "1.5万字"),
            (15000, "1.5万字"),
            (25000, "2.5万字"),
            (99999, "10万字"),
        ];
        for (words, expected) in cases {
            assert_eq!(
                word_count_format(words),
                expected,
                "words={} 应与原版 wordCountFormat 一致",
                words
            );
        }
    }

    /// [P2-28b] 缓存写入成功后回填章节字数（对齐原版 writeText「成功写入后回填」；
    /// 字数 = UTF-16 码元数，格式对齐原版 StringUtils.wordCountFormat）
    #[test]
    fn test_save_chapter_cache_backfills_word_count() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://wc-backfill.example.com/book/1";
        let chapter_url = "https://wc-backfill.example.com/ch/4";

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: "https://wc-src.example.com".to_string(),
                ..legado_core::models::Book::default()
            })?;
            BookChapterRepository::new(db.connection()).insert(&BookChapter {
                url: chapter_url.to_string(),
                title: "第四章".to_string(),
                book_url: book_url.to_string(),
                index: 4,
                ..BookChapter::default()
            })?;
            Ok(())
        })
        .expect("前置数据写入失败");

        // 10500 UTF-16 码元 → "1.1万字"（double(1.05) 精确值 1.0500…0044 > 1.05 中点，
        // HALF_EVEN 进位——与原版 DecimalFormat("#.#") 行为一致）
        assert!(
            save_chapter_cache(book_url, 4, "第四章", chapter_url, &"字".repeat(10500)),
            "缓存写入应成功"
        );
        assert_eq!(
            read_chapter_word_count(book_url, 4).as_deref(),
            Some("1.1万字"),
            "缓存写入成功后应按原版 wordCountFormat 格式回填字数"
        );

        // 短内容 → 纯字数 + 字 形态
        assert!(
            save_chapter_cache(book_url, 4, "第四章", chapter_url, "第四章正文"),
            "缓存写入应成功"
        );
        assert_eq!(
            read_chapter_word_count(book_url, 4).as_deref(),
            Some("5字"),
            "≤10000 码元应为 纯字数+字 形态"
        );

        // 收尾清理（章节行事务外删除为 B-7 no-op，测试库隔离无害）
        with_database(|db| {
            CacheBookRepository::new(db.connection()).delete_by_book(book_url)?;
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            BookRepository::new(db.connection()).delete_by_url(book_url)?;
            Ok(())
        })
        .ok();
    }

    /// [P2-28b] 缓存命中惰性自愈：存量 wordCount 为空的章，命中返回路径按本次
    /// 缓存正文长度补算回填一次；首次回填后 wordCount 非空，后续命中不再写
    /// （一次性语义，经 AFTER UPDATE 探针触发器计数证明）
    #[test]
    fn test_cache_hit_lazy_self_heals_word_count_once() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://wc-heal.example.com/book/1";
        let chapter_url = "https://wc-heal.example.com/ch/7";
        let content = "x".repeat(25000); // 25000 UTF-16 码元 → "2.5万字"

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: "https://wc-src.example.com".to_string(),
                ..legado_core::models::Book::default()
            })?;
            // 章节行（wordCount 为空，模拟存量目录）
            BookChapterRepository::new(db.connection()).insert(&BookChapter {
                url: chapter_url.to_string(),
                title: "第七章".to_string(),
                book_url: book_url.to_string(),
                index: 7,
                ..BookChapter::default()
            })?;
            // 直写缓存行（模拟早于回填链引入的旧缓存，wordCount 未回填；
            // 不经 save_chapter_cache，避免其自身的回填掩盖「存量」前提）
            CacheBookRepository::new(db.connection()).insert(&CachedChapter {
                id: 0,
                book_url: book_url.to_string(),
                chapter_index: 7,
                chapter_title: "第七章".to_string(),
                chapter_url: chapter_url.to_string(),
                content: content.clone(),
                cached_at: 0,
                size_bytes: content.len() as i64,
            })?;
            Ok(())
        })
        .expect("前置数据写入失败");

        // 首次命中：正文原样返回 + 一次性字数回填
        let got = fetch_chapter_content(book_url, chapter_url, "https://wc-src.example.com")
            .expect("缓存命中正文返回不受回填影响");
        assert_eq!(got, content);
        assert_eq!(
            read_chapter_word_count(book_url, 7).as_deref(),
            Some("2.5万字"),
            "首次命中应惰性自愈回填字数"
        );

        // 安装 UPDATE 探针（仅本书范围），证明二次命中不再写 wordCount
        with_database(|db| {
            db.connection()
                .execute("CREATE TABLE IF NOT EXISTS wc_update_probe (n INTEGER)", [])
                .map_err(|e| LegadoError::Database(format!("探针建表失败: {e}")))?;
            db.connection()
                .execute(
                    "CREATE TRIGGER wc_heal_probe AFTER UPDATE ON chapters \
                     WHEN OLD.bookUrl = 'https://wc-heal.example.com/book/1' \
                     BEGIN INSERT INTO wc_update_probe VALUES (1); END",
                    [],
                )
                .map_err(|e| LegadoError::Database(format!("探针触发器创建失败: {e}")))?;
            Ok(())
        })
        .expect("探针安装失败");

        // 二次命中：wordCount 已非空 → 不重复回填
        let got2 =
            fetch_chapter_content(book_url, chapter_url, "https://wc-src.example.com").unwrap();
        assert_eq!(got2, content);
        assert_eq!(
            read_chapter_word_count(book_url, 7).as_deref(),
            Some("2.5万字")
        );
        let updates = with_database(|db| {
            let count: i64 = db
                .connection()
                .query_row("SELECT COUNT(*) FROM wc_update_probe", [], |row| row.get(0))
                .map_err(|e| LegadoError::Database(format!("探针计数查询失败: {e}")))?;
            Ok(count)
        })
        .unwrap();
        assert_eq!(updates, 0, "二次命中不应再次写 wordCount（一次性回填）");

        // 收尾清理：撤探针 + 清缓存/章节/书行
        with_database(|db| {
            let _ = db
                .connection()
                .execute("DROP TRIGGER IF EXISTS wc_heal_probe", []);
            let _ = db
                .connection()
                .execute("DROP TABLE IF EXISTS wc_update_probe", []);
            CacheBookRepository::new(db.connection()).delete_by_book(book_url)?;
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            BookRepository::new(db.connection()).delete_by_url(book_url)?;
            Ok(())
        })
        .ok();
    }

    /// [P2-28b] 回填失败不得影响正文返回：用按 bookUrl 定界的触发器模拟
    /// chapters 表 UPDATE 失败（RAISE ABORT；定界使即便清理遗漏也不波及其他用例）
    /// ——缓存命中自愈路径与缓存写入路径均降级告警，正文照常返回
    #[test]
    fn test_word_count_backfill_failure_harmless() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://wc-fail.example.com/book/1";
        let chapter_url = "https://wc-fail.example.com/ch/0";
        let content = "f".repeat(12000); // 12000 码元 → "1.2万字"（1.2 为精确双精度值）

        with_database(|db| {
            BookRepository::new(db.connection()).insert(&legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: "https://wc-src.example.com".to_string(),
                ..legado_core::models::Book::default()
            })?;
            BookChapterRepository::new(db.connection()).insert(&BookChapter {
                url: chapter_url.to_string(),
                title: "第一章".to_string(),
                book_url: book_url.to_string(),
                index: 0,
                ..BookChapter::default()
            })?;
            CacheBookRepository::new(db.connection()).insert(&CachedChapter {
                id: 0,
                book_url: book_url.to_string(),
                chapter_index: 0,
                chapter_title: "第一章".to_string(),
                chapter_url: chapter_url.to_string(),
                content: content.clone(),
                cached_at: 0,
                size_bytes: content.len() as i64,
            })?;
            // 模拟回填失败：仅拦截本书的 chapters UPDATE
            db.connection()
                .execute(
                    "CREATE TRIGGER wc_fail_sim BEFORE UPDATE ON chapters \
                     WHEN OLD.bookUrl = 'https://wc-fail.example.com/book/1' \
                     BEGIN SELECT RAISE(ABORT, '模拟字数回填失败'); END",
                    [],
                )
                .map_err(|e| LegadoError::Database(format!("失败模拟触发器创建失败: {e}")))?;
            Ok(())
        })
        .expect("前置数据写入失败");

        // 缓存命中路径：自愈回填失败（降级告警）→ 正文仍原样返回
        let got = fetch_chapter_content(book_url, chapter_url, "https://wc-src.example.com")
            .expect("回填失败不得影响正文返回");
        assert_eq!(got, content);

        // 写入路径：缓存写入成功（覆盖缓存行），回填失败降级告警，主流程不受影响
        save_chapter_cache(book_url, 0, "第一章", chapter_url, &content);

        // wordCount 保持为空（回填从未成功）
        assert!(
            read_chapter_word_count(book_url, 0)
                .map(|w| w.trim().is_empty())
                .unwrap_or(true),
            "回填失败后 wordCount 应保持为空"
        );

        // 收尾清理：撤触发器 + 清缓存/章节/书行
        with_database(|db| {
            let _ = db
                .connection()
                .execute("DROP TRIGGER IF EXISTS wc_fail_sim", []);
            CacheBookRepository::new(db.connection()).delete_by_book(book_url)?;
            let _ = BookChapterRepository::new(db.connection()).delete_by_book_url(book_url);
            BookRepository::new(db.connection()).delete_by_url(book_url)?;
            Ok(())
        })
        .ok();
    }

    #[test]
    fn test_fetch_chapter_content_source_not_found() {
        let _db_guard = setup_db_and_source("https://other2.example.com");
        let err = fetch_chapter_content(
            "https://x.com/book",
            "https://x.com/ch/1",
            "https://no-such-source.example.com",
        )
        .unwrap_err();
        assert!(err.to_string().contains("书源不存在"));
    }

    /// 网络测试：需要真实网络访问，CI 中忽略
    #[test]
    #[ignore = "requires network access"]
    fn test_fetch_chapter_content_returns_text_not_json_metadata() {
        let source_url = "https://text-check.example.com";
        let book_url = "https://text-check.example.com/book/1";
        let chapter_url = format!("{book_url}/chapter/0");
        let _db_guard = setup_db_and_source(source_url);

        let content = fetch_chapter_content(book_url, &chapter_url, source_url).unwrap();
        // 确保返回的是真实正文，不是 JSON 元数据
        assert!(!content.contains("need_fetch"));
        assert!(!content.contains("chapter_url"));
    }

    // ─── 内容净化 / 替换规则测试 ────────────────────────────────────────

    /// 辅助：构造启用/禁用的替换规则
    fn make_test_rule(
        name: &str,
        pattern: &str,
        replacement: &str,
        is_regex: bool,
        enabled: bool,
    ) -> ReplaceRule {
        ReplaceRule {
            name: name.to_string(),
            pattern: pattern.to_string(),
            replacement: replacement.to_string(),
            is_regex,
            is_enabled: enabled,
            ..ReplaceRule::default()
        }
    }

    /// 测试普通字符串替换：启用的规则应生效
    #[test]
    fn test_content_processing_text_replace() {
        let rules = vec![
            make_test_rule("去广告", "广告", "", false, true),
            make_test_rule("替换test", "test", "测试", false, true),
        ];
        let result = process_content_with_rules("这是广告内容test", "", &rules, "");
        assert_eq!(result, "这是内容测试");
    }

    /// 测试正则替换：启用的正则规则应生效
    #[test]
    fn test_content_processing_regex_replace() {
        let rules = vec![make_test_rule("数字", r"\d+", "NUM", true, true)];
        let result = process_content_with_rules("abc 123 def 456", "", &rules, "");
        assert_eq!(result, "abc NUM def NUM");
    }

    /// 测试未启用规则不生效：仅传入启用规则（模拟 get_enabled_rules 过滤）
    #[test]
    fn test_content_processing_disabled_rules_not_applied() {
        // 模拟 get_enabled_rules 仅返回启用的规则
        let all_rules = [
            make_test_rule("启用", "hello", "hi", false, true),
            make_test_rule("禁用", "world", "WORLD", false, false),
        ];
        // 只传入启用的（与 get_enabled_rules 行为一致）
        let enabled: Vec<_> = all_rules.iter().filter(|r| r.is_enabled).cloned().collect();
        let result = process_content_with_rules("hello world", "", &enabled, "");
        assert_eq!(result, "hi world"); // world 未被替换
    }

    /// 测试 scope 过滤：精确匹配（scope 按分隔符拆分后须与书籍名称完全相等）
    #[test]
    fn test_content_processing_scope_filter() {
        let mut rule = make_test_rule("特定书", "a", "X", false, true);
        rule.scope = Some("特定书籍".to_string());
        let rules = vec![rule];

        // 精确匹配 scope 命中
        let result = process_content_with_rules("abc", "", &rules, "特定书籍");
        assert_eq!(result, "Xbc");

        // 不匹配 scope
        let result = process_content_with_rules("abc", "", &rules, "其他书籍");
        assert_eq!(result, "abc");
    }

    /// 测试 scope 为空字符串或 global 时全局生效
    #[test]
    fn test_content_processing_scope_global() {
        let mut rule = make_test_rule("全局", "x", "Y", false, true);
        rule.scope = Some("global".to_string());
        let rules = vec![rule.clone()];
        let result = process_content_with_rules("xax", "", &rules, "任意书籍");
        assert_eq!(result, "YaY");

        // scope 为空字符串也视为全局
        let mut rule2 = make_test_rule("空scope", "x", "Y", false, true);
        rule2.scope = Some(String::new());
        let result = process_content_with_rules("xax", "", &[rule2], "任意书籍");
        assert_eq!(result, "YaY");
    }

    /// 测试空 book_name 时带具体 scope 的规则不生效（修复 contains("") 恒真缺陷）
    #[test]
    fn test_content_processing_scope_empty_book_name() {
        let mut rule = make_test_rule("限定书", "a", "X", false, true);
        rule.scope = Some("某书籍".to_string());
        let rules = vec![rule];
        // book_name 为空时，scoped 规则不应生效
        let result = process_content_with_rules("abc", "", &rules, "");
        assert_eq!(result, "abc");
    }

    /// 测试子串不误命中：book_name="斗破" 不应命中 scope="斗破苍穹"
    #[test]
    fn test_content_processing_scope_no_substring_match() {
        let mut rule = make_test_rule("斗破苍穹", "a", "X", false, true);
        rule.scope = Some("斗破苍穹".to_string());
        let rules = vec![rule];
        // 子串书名不应命中
        let result = process_content_with_rules("abc", "", &rules, "斗破");
        assert_eq!(result, "abc");
        // 精确书名应命中
        let result = process_content_with_rules("abc", "", &rules, "斗破苍穹");
        assert_eq!(result, "Xbc");
    }

    /// 测试 scope 多分隔符（,;，；）拆分后精确匹配
    #[test]
    fn test_content_processing_scope_multi_delimiter() {
        let mut rule = make_test_rule("多书", "a", "X", false, true);
        rule.scope = Some("书A，书B;书C".to_string());
        let rules = vec![rule];
        assert_eq!(process_content_with_rules("abc", "", &rules, "书B"), "Xbc");
        assert_eq!(process_content_with_rules("abc", "", &rules, "书C"), "Xbc");
        assert_eq!(process_content_with_rules("abc", "", &rules, "书D"), "abc");
    }

    /// 测试去重复标题：正文开头与章节标题相同时应被去除
    #[test]
    fn test_content_processing_remove_duplicate_title() {
        let rules: Vec<ReplaceRule> = vec![];
        let result = process_content_with_rules("第一章 开始\n正文内容", "第一章 开始", &rules, "");
        assert_eq!(result, "正文内容");
    }

    /// 集成测试：通过 apply_content_processing 完整链路（DB 加载规则 + 净化）
    #[test]
    fn test_apply_content_processing_integration() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 插入一条唯一命名的启用规则（不清理其他测试的规则，避免并行竞态）
        let rule_id = with_database(|db| {
            let repo = ReplaceRuleRepository::new(db.connection());
            repo.insert(&ReplaceRule {
                name: "reader_集成测试规则_unique".to_string(),
                pattern: "广告文字".to_string(),
                replacement: String::new(),
                is_regex: false,
                is_enabled: true,
                ..ReplaceRule::default()
            })
        })
        .unwrap();

        let result =
            apply_content_processing("https://any-book-url.example.com", "正文广告文字结尾", "");
        assert_eq!(result, "正文结尾");

        // 清理本测试插入的规则
        with_database(|db| {
            let repo = ReplaceRuleRepository::new(db.connection());
            repo.delete(rule_id)?;
            Ok(())
        })
        .unwrap();
    }

    /// 测试 raw 变体不应用替换规则：被规则删除/替换的词仍保留
    #[test]
    fn test_content_processing_raw_keeps_replaced_words() {
        let rules = vec![make_test_rule("去广告", "广告", "", false, true)];
        // apply_replace_rules=false：即使有启用规则，"广告" 仍保留
        let result =
            process_content_with_rules_inner("这是广告内容", "", &rules, "", false, None, true);
        assert_eq!(result, "这是广告内容");
        // apply_replace_rules=true：规则生效，"广告" 被删除
        let result =
            process_content_with_rules_inner("这是广告内容", "", &rules, "", true, None, true);
        assert_eq!(result, "这是内容");
    }

    /// 测试 raw 变体仍执行去重复标题（仅替换规则关闭）
    #[test]
    fn test_content_processing_raw_still_removes_duplicate_title() {
        let rules: Vec<ReplaceRule> = vec![];
        let result = process_content_with_rules_inner(
            "第一章 开始\n正文",
            "第一章 开始",
            &rules,
            "",
            false,
            None,
            true,
        );
        assert_eq!(result, "正文");
    }

    // ─── 简繁转换透传测试 ───────────────────────────────────

    /// 测试净化管线 t2s：繁体正文经处理后转为简体
    #[test]
    fn test_content_processing_chinese_convert_t2s() {
        let rules: Vec<ReplaceRule> = vec![];
        let result = process_content_with_rules_inner(
            "測試內容",
            "",
            &rules,
            "",
            true,
            Some("t2s".to_string()),
            true,
        );
        assert_eq!(result, "测试内容");
    }

    /// 测试净化管线 s2t：简体正文经处理后转为繁体
    #[test]
    fn test_content_processing_chinese_convert_s2t() {
        let rules: Vec<ReplaceRule> = vec![];
        let result = process_content_with_rules_inner(
            "测试内容",
            "",
            &rules,
            "",
            true,
            Some("s2t".to_string()),
            true,
        );
        assert_eq!(result, "測試內容");
    }

    /// 测试 0=不转换回归：chinese_convert=None 时正文保持原样
    #[test]
    fn test_content_processing_chinese_convert_none() {
        let rules: Vec<ReplaceRule> = vec![];
        let result =
            process_content_with_rules_inner("測試內容abc", "", &rules, "", true, None, true);
        assert_eq!(result, "測試內容abc");
    }

    /// 测试设置/读取往返：0/1/2 持久化后读回一致，非法值归一为 0
    #[test]
    fn test_chinese_convert_type_roundtrip() {
        let _db_guard = crate::db_state::ensure_test_db();

        for t in [1, 2, 0] {
            set_chinese_convert_type(t);
            assert_eq!(get_chinese_convert_type(), t);
        }
        // 非法值归一为 0
        set_chinese_convert_type(9);
        assert_eq!(get_chinese_convert_type(), 0);
        set_chinese_convert_type(-1);
        assert_eq!(get_chinese_convert_type(), 0);

        // 方向映射语义：0/1/2 → None/t2s/s2t
        assert_eq!(chinese_convert_direction(0), None);
        assert_eq!(chinese_convert_direction(1), Some("t2s".to_string()));
        assert_eq!(chinese_convert_direction(2), Some("s2t".to_string()));
    }

    /// 集成测试：设置繁简配置后，apply_content_processing 完整链路对正文生效
    #[test]
    fn test_apply_content_processing_chinese_convert_integration() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://chinese-convert-test.example.com/book/1";

        // t2s：繁体正文转简体
        set_chinese_convert_type(1);
        let result = apply_content_processing(book_url, "繁體正文內容", "");
        assert_eq!(result, "繁体正文内容");

        // s2t：简体正文转繁体
        set_chinese_convert_type(2);
        let result = apply_content_processing(book_url, "简体正文内容", "");
        assert_eq!(result, "簡體正文內容");

        // 0=不转换回归
        set_chinese_convert_type(0);
        let result = apply_content_processing(book_url, "繁體正文內容", "");
        assert_eq!(result, "繁體正文內容");

        // raw 路径（内容搜索语义）不做繁简转换，保持原文（无章节上下文传 None）
        set_chinese_convert_type(1);
        let result = apply_content_processing_raw(book_url, "繁體正文內容", "", None);
        assert_eq!(result, "繁體正文內容");

        // 还原默认配置，避免影响其他测试
        set_chinese_convert_type(0);
    }

    /// 测试标题繁简转换：对齐 Kotlin getDisplayTitle（1=t2s / 2=s2t / 0=不转）
    #[test]
    fn test_title_convert_by_type() {
        assert_eq!(convert_title_by_type("第一章 測試", 1), "第一章 测试");
        assert_eq!(convert_title_by_type("第一章 测试", 2), "第一章 測試");
        assert_eq!(convert_title_by_type("第一章 測試", 0), "第一章 測試");
    }

    // ─── get_chapter_content_full 测试 ─────────────────────────────────────

    /// 章节不存在时应返回错误
    #[test]
    fn test_get_chapter_content_full_chapter_not_found() {
        let _db_guard = crate::db_state::ensure_test_db();
        let err = get_chapter_content_full("https://no-such-book.example.com", 999).unwrap_err();
        assert!(err.to_string().contains("章节"));
    }

    /// 在线书籍未配置书源（origin 为空）时应返回错误
    #[test]
    fn test_get_chapter_content_full_no_origin() {
        let _db_guard = crate::db_state::ensure_test_db();
        let book_url = "https://full-test-no-origin.example.com/book/1";

        // 插入一本 origin 为空的书籍和章节
        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: String::new(), // 空 origin
                ..legado_core::models::Book::default()
            };
            let _ = book_repo.insert(&book);

            let ch_repo = BookChapterRepository::new(db.connection());
            let ch = legado_core::models::BookChapter {
                url: format!("{book_url}/ch/0"),
                title: "第一章".to_string(),
                is_volume: false,
                base_url: book_url.to_string(),
                book_url: book_url.to_string(),
                index: 0,
                is_vip: false,
                is_pay: false,
                resource_url: None,
                tag: None,
                word_count: None,
                start: None,
                end: None,
                start_fragment_id: None,
                end_fragment_id: None,
                variable: None,
                img_url: None,
            };
            let _ = ch_repo.insert_batch(&[ch]);
            Ok::<(), legado_core::LegadoError>(())
        })
        .unwrap();

        let err = get_chapter_content_full(book_url, 0).unwrap_err();
        assert!(err.to_string().contains("书源"));
    }

    /// 网络测试：在线书籍完整链路（需要真实网络，CI 中忽略）
    #[test]
    #[ignore = "requires network access"]
    fn test_get_chapter_content_full_online() {
        let source_url = "https://full-online-test.example.com";
        let book_url = "https://full-online-test.example.com/book/1";
        let _db_guard = setup_db_and_source(source_url);

        // 插入书籍（origin = source_url）和章节
        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            let book = legado_core::models::Book {
                book_url: book_url.to_string(),
                origin: source_url.to_string(),
                ..legado_core::models::Book::default()
            };
            let _ = book_repo.insert(&book);

            let ch_repo = BookChapterRepository::new(db.connection());
            let ch = legado_core::models::BookChapter {
                url: format!("{book_url}/chapter/0"),
                title: "第一章".to_string(),
                is_volume: false,
                base_url: book_url.to_string(),
                book_url: book_url.to_string(),
                index: 0,
                is_vip: false,
                is_pay: false,
                resource_url: None,
                tag: None,
                word_count: None,
                start: None,
                end: None,
                start_fragment_id: None,
                end_fragment_id: None,
                variable: None,
                img_url: None,
            };
            let _ = ch_repo.insert_batch(&[ch]);
            Ok::<(), legado_core::LegadoError>(())
        })
        .unwrap();

        let content = get_chapter_content_full(book_url, 0).unwrap();
        assert!(!content.is_empty());
        // 确保返回的是真实正文，不是 JSON 元数据
        assert!(!content.contains("need_fetch"));
    }

    /// 集成测试：apply_content_processing_raw 不应用替换规则，apply_content_processing 仍应用
    #[test]
    fn test_apply_content_processing_raw_integration() {
        let _db_guard = crate::db_state::ensure_test_db();
        let rule_id = with_database(|db| {
            let repo = ReplaceRuleRepository::new(db.connection());
            repo.insert(&ReplaceRule {
                name: "reader_raw_测试规则_unique".to_string(),
                pattern: "敏感词".to_string(),
                replacement: String::new(),
                is_regex: false,
                is_enabled: true,
                ..ReplaceRule::default()
            })
        })
        .unwrap();

        let raw_input = "正文含敏感词结尾";
        // 净化变体（阅读器/导出）：替换规则生效
        let purified = apply_content_processing("https://raw-test.example.com", raw_input, "");
        assert_eq!(purified, "正文含结尾");
        // raw 变体（内容搜索语义）：替换规则不生效，原词保留（无章节上下文传 None）
        let raw = apply_content_processing_raw("https://raw-test.example.com", raw_input, "", None);
        assert_eq!(raw, raw_input);

        with_database(|db| {
            let repo = ReplaceRuleRepository::new(db.connection());
            repo.delete(rule_id)?;
            Ok(())
        })
        .unwrap();
    }

    // ─── toggle_same_title_removed 测试（Task #51，契约 §2.9.10） ─────────────

    /// 插入测试书籍 + 章节（toggle 开关测试专用）
    ///
    /// 书籍已存在时跳过插入：INSERT OR REPLACE 会先删旧行再插新行，
    /// 触发 chapters 外键级联删除，把已有章节一并清掉。
    fn insert_book_and_chapter(book_url: &str, chapter_index: i32, title: &str) {
        with_database(|db| {
            let book_repo = BookRepository::new(db.connection());
            if book_repo.find_by_url(book_url)?.is_none() {
                let book = legado_core::models::Book {
                    book_url: book_url.to_string(),
                    ..legado_core::models::Book::default()
                };
                book_repo.insert(&book)?;
            }

            let ch_repo = BookChapterRepository::new(db.connection());
            let ch = legado_core::models::BookChapter {
                url: format!("{book_url}/chapter/{chapter_index}"),
                title: title.to_string(),
                is_volume: false,
                base_url: book_url.to_string(),
                book_url: book_url.to_string(),
                index: chapter_index,
                is_vip: false,
                is_pay: false,
                resource_url: None,
                tag: None,
                word_count: None,
                start: None,
                end: None,
                start_fragment_id: None,
                end_fragment_id: None,
                variable: None,
                img_url: None,
            };
            ch_repo.insert_batch(&[ch])?;
            Ok::<(), legado_core::LegadoError>(())
        })
        .unwrap();
    }

    /// 清理测试书籍章节与开关记录
    fn cleanup_toggle_test_data(book_url: &str) {
        with_database(|db| {
            use rusqlite::params;
            let conn = db.connection();
            let to_db_err = |e| LegadoError::Database(format!("清理测试数据失败: {e}"));
            conn.execute("DELETE FROM chapters WHERE bookUrl = ?1", params![book_url])
                .map_err(to_db_err)?;
            conn.execute("DELETE FROM books WHERE bookUrl = ?1", params![book_url])
                .map_err(to_db_err)?;
            conn.execute(
                "DELETE FROM caches WHERE key LIKE ?1",
                params![format!("sameTitleRemoved:{book_url}:%")],
            )
            .map_err(to_db_err)?;
            Ok(())
        })
        .unwrap();
    }

    /// Task #51：错误码——书籍不存在 → Internal；章节不存在 → Db
    #[test]
    fn test_toggle_same_title_removed_errors() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 书籍不存在 → Internal 错误
        let err = toggle_same_title_removed("https://no-such-book.example.com", 0, false)
            .expect_err("书籍不存在应报错");
        assert!(
            matches!(err, LegadoError::Internal(_)),
            "书籍不存在应为 Internal 错误，实际: {err:?}"
        );

        // 书籍存在但章节不存在 → Db 错误
        let book_url = "https://toggle-err-test.example.com/book/1";
        insert_book_and_chapter(book_url, 0, "第一章 测试");
        let err = toggle_same_title_removed(book_url, 99, false).expect_err("章节不存在应报错");
        assert!(
            matches!(err, LegadoError::Database(_)),
            "章节不存在应为 Db 错误，实际: {err:?}"
        );
        cleanup_toggle_test_data(book_url);
    }

    /// Task #51：章级开关接通正文净化链路（默认去除 / opt-out 保留 / 恢复默认）
    #[test]
    fn test_toggle_same_title_removed_content_pipeline() {
        let _db_guard = crate::db_state::ensure_test_db();

        let book_url = "https://toggle-pipeline-test.example.com/book/1";
        let title = "第一章 测试";
        insert_book_and_chapter(book_url, 0, title);
        // 正文开头与章节标题重复（去重复标题的目标场景）
        let raw = "第一章 测试\n正文内容。";

        // 全局默认：去除重复标题
        let result = apply_content_processing_chapter(book_url, raw, title, 0);
        assert_eq!(result, "正文内容。");

        // opt-out（enable=false）：保留原始标题
        toggle_same_title_removed(book_url, 0, false).unwrap();
        let result = apply_content_processing_chapter(book_url, raw, title, 0);
        assert_eq!(result, "第一章 测试\n正文内容。");

        // 其他章不受影响（章级隔离，仍走全局默认）
        insert_book_and_chapter(book_url, 1, "第二章 测试");
        let raw2 = "第二章 测试\n第二正文。";
        let result = apply_content_processing_chapter(book_url, raw2, "第二章 测试", 1);
        assert_eq!(result, "第二正文。");

        // 恢复默认（enable=true）：重新去除重复标题
        toggle_same_title_removed(book_url, 0, true).unwrap();
        let result = apply_content_processing_chapter(book_url, raw, title, 0);
        assert_eq!(result, "正文内容。");

        // 幂等：重复切换不报错
        toggle_same_title_removed(book_url, 0, true).unwrap();
        toggle_same_title_removed(book_url, 0, false).unwrap();
        toggle_same_title_removed(book_url, 0, false).unwrap();

        cleanup_toggle_test_data(book_url);
    }
}
