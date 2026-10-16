//! 书源校验 API（Task #87）
//!
//! 对 `legado-net::source_checker::SourceChecker` 的纯 FFI 包装，
//! 暴露单本校验与批量流式校验，供 Flutter 书源校验页面接入。
//!
//! - 单本校验：[`check_source`]（搜索→详情→目录→正文四步 + 验证码/重定向检测）
//! - 批量校验：[`run_check_sources_stream`]（**串行**逐个回推进度，
//!   对齐 Kotlin `CheckSourceService` 的 flow 顺序校验与
//!   legado-server `/sources/check-batch` 的语义）
//!
//! 与 server 端点的差异：批量校验采用串行执行（对齐 Kotlin 原版），
//! 避免对书源站产生并发压力；支持宿主内取消（对齐 Kotlin `CheckSource.stop`）。

use std::sync::Arc;

use serde::{Deserialize, Serialize};

use legado_core::models::BookSource;
use legado_core::{LegadoError, LegadoResult};
use legado_db::BookSourceRepository;
use legado_net::source_checker::{CheckResult, CheckerConfig, SourceChecker};

use legado_db::repository::Repository;
use legado_engine::{NetworkContext, Operation, StorageContext};

// ─── 配置 DTO ─────────────────────────────────────────────────────────────────

/// 校验配置 JSON DTO（所有字段可选，缺省回落 [`CheckerConfig::default`]）
///
/// 字段一一对应 `CheckerConfig`：
/// `keyword` / `step_timeout_ms` / `check_search` / `check_toc` /
/// `check_content` / `detect_captcha` / `detect_redirect`。
#[derive(Debug, Clone, Default, Deserialize)]
struct CheckerConfigDto {
    keyword: Option<String>,
    step_timeout_ms: Option<u64>,
    check_search: Option<bool>,
    check_toc: Option<bool>,
    check_content: Option<bool>,
    detect_captcha: Option<bool>,
    detect_redirect: Option<bool>,
}

/// 解析校验配置 JSON（空字符串 / `"{}"` 均使用默认配置）
fn parse_config(config_json: &str) -> LegadoResult<CheckerConfig> {
    let defaults = CheckerConfig::default();
    if config_json.trim().is_empty() {
        return Ok(defaults);
    }
    let dto: CheckerConfigDto = serde_json::from_str(config_json)
        .map_err(|e| LegadoError::Ffi(format!("校验配置 JSON 解析失败: {e}")))?;
    Ok(CheckerConfig {
        keyword: dto
            .keyword
            .filter(|s| !s.is_empty())
            .unwrap_or(defaults.keyword),
        step_timeout_ms: dto.step_timeout_ms.unwrap_or(defaults.step_timeout_ms),
        check_search: dto.check_search.unwrap_or(defaults.check_search),
        check_toc: dto.check_toc.unwrap_or(defaults.check_toc),
        check_content: dto.check_content.unwrap_or(defaults.check_content),
        detect_captcha: dto.detect_captcha.unwrap_or(defaults.detect_captcha),
        detect_redirect: dto.detect_redirect.unwrap_or(defaults.detect_redirect),
    })
}

/// 客户端与取消作用域在入口固定，不从异步回调重新发现宿主。
fn create_checker(network: &NetworkContext, config: CheckerConfig) -> LegadoResult<SourceChecker> {
    Ok(SourceChecker::with_config(
        Arc::new(network.client()?),
        config,
    ))
}

// ─── 单本校验 ─────────────────────────────────────────────────────────────────

/// 校验单个书源（搜索→详情→目录→正文四步 + 验证码/重定向检测）
///
/// `source_json` — BookSource JSON（字段名对齐 Android 原版 camelCase）
/// `config_json` — 可选校验配置 JSON（见 [`CheckerConfigDto`]），空串使用默认配置
///
/// 返回 [`CheckResult`]（同步阻塞执行，内部走全局 tokio runtime）。
pub fn check_source(source_json: &str, config_json: &str) -> LegadoResult<CheckResult> {
    let source: BookSource = serde_json::from_str(source_json)
        .map_err(|e| LegadoError::Ffi(format!("BookSource JSON 解析失败: {e}")))?;
    let config = parse_config(config_json)?;
    let task = crate::engine_holder::task_group()
        .begin()
        .map_err(|e| LegadoError::Ffi(format!("书源校验任务不可用: {e}")))?;
    let checker = create_checker(&crate::engine_holder::network(), config)?;
    crate::runtime::block_on(async move {
        let result = tokio::select! {
            biased;
            _ = task.cancelled() => return Err(LegadoError::Ffi("书源校验已取消".into())),
            result = checker.check_full(&source) => result,
        };
        task.with_active(|| result)
            .ok_or_else(|| LegadoError::Ffi("书源校验已取消".into()))
    })
}

// ─── 批量流式校验 ─────────────────────────────────────────────────────────────

/// 批量校验进度项（每完成一个书源推送一条）
///
/// 以 JSON 字符串跨 FFI 传递，字段：
/// - `index` — 当前书源在请求列表中的索引（从 0 开始）
/// - `total` — 本次校验的书源总数
/// - `is_last` — 是否为最后一条（`index == total - 1`）
/// - `source_name` — 书源名称（便于 UI 展示）
/// - `result` — 该书源的 [`CheckResult`] 完整结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckProgress {
    /// 当前书源索引（从 0 开始）
    pub index: usize,
    /// 书源总数
    pub total: usize,
    /// 是否为最后一条
    pub is_last: bool,
    /// 书源名称
    pub source_name: String,
    /// 该书源的校验结果
    pub result: CheckResult,
}

/// 批量校验书源（串行），逐个回推进度
///
/// 与 [`check_source`] 不同：本函数按请求顺序**串行**校验每个书源
/// （对齐 Kotlin `CheckSourceService` flow 顺序执行），每完成一个书源
/// 即调用一次 `on_result`（传入 [`CheckProgress`] 的 JSON 字符串）。
///
/// `source_urls_json` — 待校验书源 URL 的 JSON 数组；为空（空串/`[]`）则校验全部书源
/// `config_json` — 可选校验配置 JSON，空串使用默认配置
/// `on_result` — 每个书源完成时的回调；返回 `Err` 时提前终止（如 sink 已关闭）
///
/// 配合 [`cancel_check_sources`] 可提前中止。供 flutter_rust_bridge 的
/// `StreamSink` 绑定使用（在 ffi.rs 中将 `on_result` 接到 `sink.add`）。
pub async fn run_check_sources_stream<F>(
    source_urls_json: String,
    config_json: String,
    mut on_result: F,
) where
    F: FnMut(String) -> Result<(), String>,
{
    // 书源加载失败时以空流结束（Dart 侧表现为无结果）
    let slot = crate::engine_holder::source_checks();
    let Ok(operation) = slot.start() else {
        return;
    };
    let _guard = operation.guard();
    let storage = crate::engine_holder::current()
        .ok()
        .map(|engine| engine.storage().clone());
    let network = crate::engine_holder::network();
    let sources = load_check_sources(storage.as_ref(), &source_urls_json).unwrap_or_default();
    run_checks(sources, &config_json, &operation, &network, &mut on_result).await;
}

/// 批量校验内层实现（直接接收书源列表，便于测试注入）
///
/// 串行逐个校验并回推 [`CheckProgress`] JSON；`on_result` 返回 `Err`
/// 或取消标志置位时提前终止。
async fn run_checks<F>(
    sources: Vec<Option<BookSource>>,
    config_json: &str,
    operation: &Arc<Operation>,
    network: &NetworkContext,
    mut on_result: F,
) where
    F: FnMut(String) -> Result<(), String>,
{
    let total = sources.len();
    if total == 0 {
        return;
    }

    let config = parse_config(config_json).unwrap_or_default();
    let checker = match create_checker(network, config) {
        Ok(c) => c,
        Err(e) => {
            log::error!("书源校验：共享 HTTP 客户端初始化失败: {e}");
            return;
        }
    };

    // 串行逐个校验（对齐 Kotlin CheckSourceService，避免对书源站并发压力）
    for (index, source) in sources.into_iter().enumerate() {
        if !operation.is_active() {
            break;
        }

        let result = match source {
            Some(ref src) => tokio::select! {
                biased;
                _ = operation.task().cancelled() => break,
                result = checker.check_full(src) => result,
            },
            // 书源不存在：对齐 Kotlin source == null 分支，推送失败结果
            None => CheckResult {
                source_url: String::new(),
                search_ok: false,
                toc_ok: false,
                content_ok: false,
                search_error: Some("书源不存在".to_string()),
                toc_error: Some("skipped".to_string()),
                content_error: Some("skipped".to_string()),
                total_time_ms: 0,
                captcha: None,
                redirect: None,
            },
        };

        let progress = CheckProgress {
            index,
            total,
            is_last: index + 1 >= total,
            source_name: source
                .as_ref()
                .map(|s| s.book_source_name.clone())
                .unwrap_or_default(),
            result,
        };

        if let Ok(json) = serde_json::to_string(&progress) {
            // sink 关闭（Err）时提前终止
            match operation.publish(|| on_result(json)) {
                Some(Ok(())) => {}
                Some(Err(_)) => {
                    operation.cancel();
                    break;
                }
                None => break,
            }
        }
    }
}

/// 取消正在进行的批量校验（对齐 Kotlin `CheckSource.stop`）
pub fn cancel_check_sources() {
    crate::engine_holder::source_checks().cancel();
}

// ─── 内部实现 ─────────────────────────────────────────────────────────────────

/// 按 URL 列表从数据库加载待校验的书源
///
/// 与搜索链路不同：校验针对用户选中的书源，**不过滤禁用状态**
/// （对齐 Kotlin `CheckSourceService` 直接按 URL 取完整书源）。
/// 空串/空数组表示校验全部书源；列表中不存在的 URL 以 `None` 占位，
/// 保持推送顺序与请求列表一致。
fn load_check_sources(
    storage: Option<&StorageContext>,
    source_urls_json: &str,
) -> LegadoResult<Vec<Option<BookSource>>> {
    let urls: Vec<String> = if source_urls_json.trim().is_empty() {
        Vec::new()
    } else {
        serde_json::from_str(source_urls_json)
            .map_err(|e| LegadoError::Ffi(format!("书源 URL 列表解析失败: {e}")))?
    };
    let storage = storage
        .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?;
    storage.with_database(|db| {
        let repo = BookSourceRepository::new(db.connection());
        if urls.is_empty() {
            return Ok(repo.find_all()?.into_iter().map(Some).collect());
        }
        urls.iter().map(|url| repo.find_by_url(url)).collect()
    })
}

#[cfg(test)]
async fn run_check_sources_stream_inner<F>(
    sources: Vec<Option<BookSource>>,
    config: &str,
    on_result: F,
) where
    F: FnMut(String) -> Result<(), String>,
{
    let slot = Arc::new(legado_engine::OperationSlot::new(
        legado_engine::TaskGroup::default(),
    ));
    let operation = slot.start().unwrap();
    let _guard = operation.guard();
    run_checks(
        sources,
        config,
        &operation,
        &NetworkContext::default(),
        on_result,
    )
    .await;
}

// ─── 测试 ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    use std::sync::atomic::Ordering;

    /// 构造无 searchUrl 的书源（校验走纯错误路径，无需网络）
    fn make_source_no_search(url: &str, name: &str) -> BookSource {
        BookSource {
            book_source_url: url.to_string(),
            book_source_name: name.to_string(),
            search_url: None,
            ..BookSource::default()
        }
    }

    // ─── 配置解析 ─────────────────────────────────────────────

    #[test]
    fn test_parse_config_empty_uses_default() {
        let cfg = parse_config("").unwrap();
        let defaults = CheckerConfig::default();
        assert_eq!(cfg.keyword, defaults.keyword);
        assert_eq!(cfg.step_timeout_ms, defaults.step_timeout_ms);
        assert!(cfg.check_search && cfg.check_toc && cfg.check_content);
    }

    #[test]
    fn test_parse_config_partial_override() {
        let cfg =
            parse_config(r#"{"keyword":"自定义","step_timeout_ms":5000,"check_content":false}"#)
                .unwrap();
        assert_eq!(cfg.keyword, "自定义");
        assert_eq!(cfg.step_timeout_ms, 5000);
        assert!(!cfg.check_content);
        // 未指定字段回落默认
        assert!(cfg.check_search);
        assert!(cfg.detect_captcha);
    }

    #[test]
    fn test_parse_config_invalid_json() {
        assert!(parse_config("{invalid").is_err());
    }

    // ─── 单本校验 ─────────────────────────────────────────────

    /// 无 searchUrl 书源：四步全失败且携带错误信息（纯错误路径，无网络）
    #[test]
    fn test_check_source_no_search_url() {
        let source = make_source_no_search("https://example.com", "测试源");
        let json = serde_json::to_string(&source).unwrap();

        let result = check_source(&json, "").expect("单本校验失败");
        assert!(!result.search_ok);
        assert!(!result.toc_ok);
        assert!(!result.content_ok);
        assert!(result.search_error.unwrap().contains("searchUrl"));
        assert!(result.total_time_ms >= 0);
    }

    /// 自定义配置生效：关闭后续检查时 toc/content 直接置通过
    #[test]
    fn test_check_source_with_config_skip_steps() {
        let source = make_source_no_search("https://example.com", "测试源");
        let json = serde_json::to_string(&source).unwrap();

        let result = check_source(&json, r#"{"check_toc":false,"check_content":false}"#)
            .expect("单本校验失败");
        assert!(!result.search_ok);
        // 关闭的检查步骤直接视为通过（对齐 SourceChecker 语义）
        assert!(result.toc_ok);
        assert!(result.content_ok);
    }

    /// 非法书源 JSON 应报错
    #[test]
    fn test_check_source_invalid_json() {
        assert!(check_source("{not json", "").is_err());
    }

    // ─── 批量流式校验 ─────────────────────────────────────────

    /// 串行推送：顺序、进度字段与 is_last 标记
    #[tokio::test]
    async fn test_check_sources_stream_order_and_progress() {
        let sources = vec![
            Some(make_source_no_search("https://a.example.com", "源A")),
            Some(make_source_no_search("https://b.example.com", "源B")),
            Some(make_source_no_search("https://c.example.com", "源C")),
        ];

        let collected = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let collected_cb = collected.clone();

        run_check_sources_stream_inner(sources, "", move |json| {
            collected_cb.lock().unwrap().push(json);
            Ok(())
        })
        .await;

        let items = collected.lock().unwrap();
        assert_eq!(items.len(), 3, "应推送 3 条进度");

        for (i, json) in items.iter().enumerate() {
            let progress: CheckProgress = serde_json::from_str(json).unwrap();
            assert_eq!(progress.index, i, "推送顺序应与请求顺序一致");
            assert_eq!(progress.total, 3);
            assert_eq!(progress.is_last, i == 2);
            assert!(!progress.result.search_ok);
        }
        assert_eq!(items.len(), 3);
        let first: CheckProgress = serde_json::from_str(&items[0]).unwrap();
        assert_eq!(first.source_name, "源A");
    }

    /// 不存在的书源（None 占位）推送失败结果而非跳过，保持序号连续
    #[tokio::test]
    async fn test_check_sources_stream_missing_source() {
        let sources = vec![
            Some(make_source_no_search("https://a.example.com", "源A")),
            None,
        ];

        let collected = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let collected_cb = collected.clone();

        run_check_sources_stream_inner(sources, "", move |json| {
            collected_cb.lock().unwrap().push(json);
            Ok(())
        })
        .await;

        let items = collected.lock().unwrap();
        assert_eq!(items.len(), 2);
        let missing: CheckProgress = serde_json::from_str(&items[1]).unwrap();
        assert_eq!(missing.index, 1);
        assert!(missing.is_last);
        assert!(missing.result.search_error.unwrap().contains("书源不存在"));
    }

    /// sink 关闭（回调返回 Err）时应提前终止
    #[tokio::test]
    async fn test_check_sources_stream_sink_closed() {
        let sources = vec![
            Some(make_source_no_search("https://a.example.com", "源A")),
            Some(make_source_no_search("https://b.example.com", "源B")),
            Some(make_source_no_search("https://c.example.com", "源C")),
        ];

        let count = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let count_cb = count.clone();

        run_check_sources_stream_inner(sources, "", move |_json| {
            count_cb.fetch_add(1, Ordering::SeqCst);
            Err("sink closed".to_string())
        })
        .await;

        assert_eq!(count.load(Ordering::SeqCst), 1, "sink 关闭后应立即终止");
    }

    /// 空列表：不推送任何进度
    #[tokio::test]
    async fn test_check_sources_stream_empty() {
        let count = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let count_cb = count.clone();
        run_check_sources_stream_inner(Vec::new(), "", move |_json| {
            count_cb.fetch_add(1, Ordering::SeqCst);
            Ok(())
        })
        .await;
        assert_eq!(count.load(Ordering::SeqCst), 0);
    }

    /// 回调明确取消此流后不再推送后续结果
    #[tokio::test]
    async fn test_check_sources_stream_cancel() {
        let sources = vec![
            Some(make_source_no_search("https://a.example.com", "源A")),
            Some(make_source_no_search("https://b.example.com", "源B")),
            Some(make_source_no_search("https://c.example.com", "源C")),
        ];

        let collected = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
        let collected_cb = collected.clone();

        // 回调以错误结束此流，取消在发布门控外处理。
        run_check_sources_stream_inner(sources, "", move |json| {
            collected_cb.lock().unwrap().push(json);
            Err("收到首条后取消此流".into())
        })
        .await;

        assert_eq!(collected.lock().unwrap().len(), 1, "取消后应停止推送");
    }

    /// URL 列表解析失败应报错
    #[test]
    fn test_load_check_sources_invalid_json() {
        assert!(load_check_sources(None, "{bad").is_err());
    }

    /// CheckProgress 序列化字段契约（snake_case）
    #[test]
    fn test_check_progress_serialize_contract() {
        let progress = CheckProgress {
            index: 0,
            total: 2,
            is_last: false,
            source_name: "测试源".to_string(),
            result: CheckResult {
                source_url: "https://example.com".to_string(),
                search_ok: true,
                toc_ok: true,
                content_ok: false,
                search_error: None,
                toc_error: None,
                content_error: Some("skipped: toc failed".to_string()),
                total_time_ms: 100,
                captcha: None,
                redirect: None,
            },
        };
        let json = serde_json::to_string(&progress).unwrap();
        for field in [
            "\"index\"",
            "\"total\"",
            "\"is_last\"",
            "\"source_name\"",
            "\"result\"",
            "\"search_ok\"",
            "\"toc_ok\"",
            "\"content_ok\"",
            "\"total_time_ms\"",
        ] {
            assert!(json.contains(field), "缺少字段 {field}: {json}");
        }
    }
    #[tokio::test]
    async fn cancelled_real_check_cannot_resume_when_a_replacement_starts() {
        use super::super::source_task_fixture::Fixture;
        use legado_engine::{EngineContext, OperationSlot};
        use std::time::Duration;
        let mut fixture = Fixture::new(1, true, |_| "<a href='/book'>测试书</a>".into());
        let engine = EngineContext::in_memory().unwrap();
        let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
        let old = slot.start().unwrap();
        let _guard = old.guard();
        let mut source = make_source_no_search(&fixture.url, "旧源");
        source.search_url = Some(format!("{}/search", fixture.url));
        let mut messages = Vec::new();
        let mut future = Box::pin(run_checks(
            vec![Some(source)],
            "",
            &old,
            engine.network(),
            |json| {
                messages.push(json);
                Ok(())
            },
        ));
        tokio::select! { _ = fixture.request() => {}, _ = &mut future => panic!("请求应处于等待中") }
        slot.cancel();
        let new = slot.start().unwrap();
        tokio::time::timeout(Duration::from_secs(2), future)
            .await
            .unwrap();
        old.finish();
        assert!(messages.is_empty());
        assert!(new.is_active());
        let mut fresh = Vec::new();
        run_checks(vec![None], "", &new, engine.network(), |json| {
            fresh.push(json);
            Ok(())
        })
        .await;
        assert_eq!(fresh.len(), 1);
        fixture.release.send(()).unwrap();
        fixture.worker.join().unwrap();
    }

    #[tokio::test]
    async fn independent_real_checks_use_their_own_cookie_and_cancellation_scope() {
        use super::super::source_task_fixture::Fixture;
        use legado_engine::{EngineContext, OperationSlot};
        let mut fixture = Fixture::new(2, false, |_| "<a href='/book'>测试书</a>".into());
        let first = EngineContext::in_memory().unwrap();
        let second = EngineContext::in_memory().unwrap();
        let mut results = Vec::new();
        for (engine, identity) in [(&first, "first"), (&second, "second")] {
            engine
                .network()
                .set_cookie("127.0.0.1", &format!("identity={identity}"))
                .unwrap();
            let slot = Arc::new(OperationSlot::new(engine.tasks().clone()));
            let operation = slot.start().unwrap();
            let _guard = operation.guard();
            let mut source = make_source_no_search(&fixture.url, identity);
            source.search_url = Some(format!("{}/search", fixture.url));
            run_checks(
                vec![Some(source)],
                r#"{"check_toc":false,"check_content":false}"#,
                &operation,
                engine.network(),
                |json| {
                    results.push(json);
                    Ok(())
                },
            )
            .await;
            assert!(
                fixture
                    .request()
                    .await
                    .contains(&format!("identity={identity}"))
            );
        }
        for json in results {
            assert!(
                serde_json::from_str::<CheckProgress>(&json)
                    .unwrap()
                    .result
                    .all_ok()
            );
        }
        fixture.worker.join().unwrap();
    }

    #[test]
    fn check_source_loading_uses_only_the_captured_storage_and_keeps_missing_entries() {
        use legado_engine::EngineContext;
        for name in ["甲库", "乙库"] {
            let engine = EngineContext::in_memory().unwrap();
            let mut source = make_source_no_search("https://same-source.test", name);
            source.enabled = false;
            engine
                .storage()
                .with_database(|db| BookSourceRepository::new(db.connection()).insert(&source))
                .unwrap();
            let loaded = load_check_sources(
                Some(engine.storage()),
                r#"["https://same-source.test","missing"]"#,
            )
            .unwrap();
            assert_eq!(loaded[0].as_ref().unwrap().book_source_name, name);
            assert!(loaded[1].is_none());
            assert_eq!(
                load_check_sources(Some(engine.storage()), "[]")
                    .unwrap()
                    .len(),
                1
            );
        }
    }
}
