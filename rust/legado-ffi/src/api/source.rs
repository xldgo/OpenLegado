//! 书源宿主适配：文档解析、连接装配与成功提交后的限速发布。
use crate::db_state::with_database;
use legado_core::models::BookSource;
use legado_core::{LegadoError, LegadoResult};
use legado_engine::book_source_service::BookSourceService;

pub fn list_sources() -> LegadoResult<Vec<BookSource>> {
    with_database(|db| BookSourceService::new(db).list_sources())
}
pub fn add_source(source_json: &str) -> LegadoResult<BookSource> {
    let source = serde_json::from_str(source_json)
        .map_err(|e| LegadoError::Ffi(format!("BookSource JSON 解析失败: {e}")))?;
    add_source_entity(source)
}
pub fn add_source_entity(source: BookSource) -> LegadoResult<BookSource> {
    let saved = with_database(|db| BookSourceService::new(db).add_source(source))?;
    Ok(saved.publish(&crate::api::source_rate_limit::registry()))
}
pub fn update_source(source_json: &str) -> LegadoResult<()> {
    let source = serde_json::from_str(source_json)
        .map_err(|e| LegadoError::Ffi(format!("BookSource JSON 解析失败: {e}")))?;
    update_source_entity(source)
}
pub fn update_source_entity(source: BookSource) -> LegadoResult<()> {
    let saved = with_database(|db| BookSourceService::new(db).update_source(&source))?;
    saved.publish(&crate::api::source_rate_limit::registry());
    Ok(())
}
pub fn delete_source(source_url: &str) -> LegadoResult<()> {
    with_database(|db| BookSourceService::new(db).delete_source(source_url))
}
pub fn enable_source(source_url: &str) -> LegadoResult<()> {
    set_source_enabled(source_url, true)
}
pub fn disable_source(source_url: &str) -> LegadoResult<()> {
    set_source_enabled(source_url, false)
}
fn set_source_enabled(source_url: &str, enabled: bool) -> LegadoResult<()> {
    with_database(|db| BookSourceService::new(db).set_source_enabled(source_url, enabled))
}
pub fn import_sources(json_array: &str) -> LegadoResult<i32> {
    // [SOURCE-PARSE-UNIFY-20261022] 与 Room 导入共用同一解析实现
    let sources = legado_core::models::book_source::parse_source_array(json_array)
        .map_err(|e| LegadoError::Ffi(format!("书源 JSON 数组解析失败: {e}")))?;
    let saved = with_database(|db| BookSourceService::new(db).import_sources(&sources))?;
    Ok(saved.publish(&crate::api::source_rate_limit::registry()))
}
/// 只读解析单个书源 JSON，供编辑页粘贴/扫码回填使用。
///
/// [SOURCE-PARSE-FFI-20261022] 仅解析归一化，不写数据库、不写限速表、
/// 不修改任何既有记录；与 `import_sources` 共用同一 `parse_source_json`。
pub fn parse_source(json: &str) -> LegadoResult<BookSource> {
    legado_core::models::book_source::parse_source_json(json)
        .map_err(|e| LegadoError::Ffi(format!("书源解析失败: {e}")))
}

/// 只读提取预览所需归一化字段（契约 SOURCE-PARSE-FFI-20261022）。
///
/// 返回 JSON 数组，每项 `{bookSourceUrl, bookSourceName, bookSourceComment,
/// lastUpdateTime}`，**顺序与输入一致**。供导入预览页展示与状态判定，
/// 使预览与最终入库使用同一套字段解释，避免「预览说可导入、确认时失败」。
/// 解析失败返回错误（由调用方按「全部失败」提示）。
pub fn preview_fields(json_array: &str) -> LegadoResult<String> {
    let sources = legado_core::models::book_source::parse_source_array(json_array)
        .map_err(|e| LegadoError::Ffi(format!("书源预览解析失败: {e}")))?;
    let fields: Vec<serde_json::Value> = sources
        .iter()
        .map(|s| {
            serde_json::json!({
                "bookSourceUrl": s.book_source_url,
                "bookSourceName": s.book_source_name,
                "bookSourceComment": s.book_source_comment,
                "lastUpdateTime": s.last_update_time,
            })
        })
        .collect();
    serde_json::to_string(&fields)
        .map_err(|e| LegadoError::Ffi(format!("预览字段序列化失败: {e}")))
}
pub fn export_sources() -> LegadoResult<Vec<BookSource>> {
    list_sources()
}
pub fn list_enabled_sources() -> LegadoResult<Vec<BookSource>> {
    with_database(|db| BookSourceService::new(db).list_enabled_sources())
}
pub fn set_source_variable(source_url: &str, variable: &str) -> LegadoResult<()> {
    with_database(|db| BookSourceService::new(db).set_source_variable(source_url, variable))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 辅助：初始化内存数据库并设置全局状态（返回串行锁守卫，测试必须绑定到变量）
    fn setup_test_db() -> std::sync::MutexGuard<'static, ()> {
        crate::db_state::ensure_test_db()
    }

    /// [SOURCE-PARSE-FFI-20261022] 只读解析：不依赖数据库即可成功，
    /// 证明解析路径未触碰 DB；且与导入共用同一实现（字符串时间戳、
    /// 禁用布尔、规则对象均正确归一化）。
    #[test]
    fn test_parse_source_is_readonly_and_normalizes() {
        // 注意：故意不调用 setup_test_db()。若 parse_source 触碰数据库会失败。
        let parsed = parse_source(
            r#"{
                "bookSourceUrl": "https://readonly-parse.example",
                "bookSourceName": "只读解析源",
                "bookSourceType": "1",
                "enabled": "false",
                "lastUpdateTime": "1792486038190",
                "ruleToc": "{\"chapterList\":[1,2],\"isVolume\":false}"
            }"#,
        )
        .expect("只读解析应成功且无需数据库");

        assert_eq!(parsed.book_source_type, 1);
        assert!(!parsed.enabled, "enabled:\"false\" 应归一化为禁用");
        assert_eq!(parsed.last_update_time, 1_792_486_038_190);
        let toc = parsed.rule_toc.expect("字符串规则应解析为对象");
        assert_eq!(toc.chapter_list.as_deref(), Some("[1,2]"));
        assert_eq!(toc.is_volume.as_deref(), Some("false"));
    }

    /// [SOURCE-PARSE-FFI-20261022] 语法错误返回可定位错误，不静默降级。
    #[test]
    fn test_parse_source_reports_syntax_error() {
        let err = parse_source(r#"{"bookSourceUrl":"#).unwrap_err();
        assert!(format!("{err}").contains("语法"), "实际: {err}");
    }

    /// [SOURCE-PARSE-FFI-20261022] 预览字段与解析同源、顺序一致。
    #[test]
    fn test_preview_fields_matches_parse_order() {
        let json = r#"[
            {"bookSourceUrl":"https://p1.example","bookSourceName":"甲","lastUpdateTime":"100"},
            {"bookSourceUrl":"https://p2.example","bookSourceName":"乙"}
        ]"#;
        let fields = preview_fields(json).expect("预览字段提取应成功");
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&fields).unwrap();
        assert_eq!(parsed.len(), 2, "顺序与条数应与输入一致");
        assert_eq!(parsed[0]["bookSourceUrl"], "https://p1.example");
        assert_eq!(parsed[0]["lastUpdateTime"], 100);
        assert_eq!(parsed[1]["bookSourceName"], "乙");
        // 缺省 lastUpdateTime 归一化为 0
        assert_eq!(parsed[1]["lastUpdateTime"], 0);
    }

    /// 契约 §2.3：设置后可经查询接口自然带出；空串清除；书源不存在报 Internal
    #[test]
    fn test_set_source_variable() {
        let _db_guard = setup_test_db();
        let url = "https://task63-source-var.example.com";
        add_source(&format!(
            "{{\"bookSourceUrl\":\"{url}\",\"bookSourceName\":\"变量测试源\"}}"
        ))
        .unwrap();

        // 设置变量 → getBookSources 查询自然带出
        set_source_variable(url, "user=abc").unwrap();
        let sources = list_sources().unwrap();
        let found = sources.iter().find(|s| s.book_source_url == url).unwrap();
        assert_eq!(found.variable, "user=abc");

        // 空串 = 清除
        set_source_variable(url, "").unwrap();
        let sources = list_sources().unwrap();
        let found = sources.iter().find(|s| s.book_source_url == url).unwrap();
        assert_eq!(found.variable, "");

        // 书源不存在 → Internal 错误
        let err = set_source_variable("https://task63-not-exist.example.com", "x").unwrap_err();
        assert!(
            matches!(err, LegadoError::Internal(_)),
            "书源不存在应报 Internal"
        );

        // 清理测试书源
        delete_source(url).unwrap();
    }

    // ─── concurrentRate 保存路径刷新（宿主接线） ─────────────────────────────

    /// 构造书源（concurrentRate 可空）
    fn test_source(url: &str, rate: Option<&str>) -> BookSource {
        BookSource {
            book_source_url: url.to_string(),
            book_source_name: "限速刷新测试源".to_string(),
            concurrent_rate: rate.map(str::to_string),
            ..BookSource::default()
        }
    }

    /// 刷新生效判据：limiter 以旧率 1/10000 建立且窗口已用 1 次，保存入口把
    /// 配置刷新为 3/10000 后，携带旧快照的下一次 acquire 必须立即放行；
    /// 未刷新则沿用 1/10000 等满 10s 窗口 → 300ms 超时失败
    async fn assert_stale_acquire_passes(
        registry: &crate::api::source_rate_limit::RateLimiterRegistry,
        stale: &BookSource,
    ) {
        let passed = tokio::time::timeout(
            std::time::Duration::from_millis(300),
            registry.acquire(stale),
        )
        .await;
        assert!(
            passed.is_ok(),
            "保存入口写库成功后必须刷新 ffi registry（旧快照应受新配置约束）"
        );
    }

    /// add 写库成功刷新既有 limiter：同 URL 删除后按新率重新添加
    /// （删除只清 DB 不清 registry，re-add 时刷新可观测）
    #[test]
    fn test_add_source_refreshes_rate_limiter() {
        let _db_guard = setup_test_db();
        let url = "https://ffi-ratelimit-add.example";
        let registry = crate::api::source_rate_limit::registry();

        let v1 = test_source(url, Some("1/10000"));
        add_source(&serde_json::to_string(&v1).unwrap()).unwrap();
        crate::runtime::block_on(registry.acquire(&v1)); // 1/10000 窗口已用 1 次
        delete_source(url).unwrap();

        let v2 = test_source(url, Some("3/10000"));
        add_source(&serde_json::to_string(&v2).unwrap()).unwrap();
        crate::runtime::block_on(assert_stale_acquire_passes(&registry, &v1));

        delete_source(url).unwrap();
    }

    /// update 写库成功刷新既有 limiter：编辑 concurrentRate 后旧快照立即受新率约束
    #[test]
    fn test_update_source_refreshes_rate_limiter() {
        let _db_guard = setup_test_db();
        let url = "https://ffi-ratelimit-update.example";
        let registry = crate::api::source_rate_limit::registry();

        let v1 = test_source(url, Some("1/10000"));
        add_source(&serde_json::to_string(&v1).unwrap()).unwrap();
        crate::runtime::block_on(registry.acquire(&v1)); // 1/10000 窗口已用 1 次

        let v2 = test_source(url, Some("3/10000"));
        update_source(&serde_json::to_string(&v2).unwrap()).unwrap();
        crate::runtime::block_on(assert_stale_acquire_passes(&registry, &v1));

        delete_source(url).unwrap();
    }

    /// update 清除 concurrentRate（缺省 None 或空串）：registry 移除该 key 的
    /// limiter，旧快照下一次 acquire 立即放行（不再受已用满的旧窗口约束）
    #[test]
    fn test_update_source_clears_rate_limiter_when_rate_removed() {
        let _db_guard = setup_test_db();
        let url = "https://ffi-ratelimit-clear.example";
        let registry = crate::api::source_rate_limit::registry();

        let v1 = test_source(url, Some("1/10000"));
        add_source(&serde_json::to_string(&v1).unwrap()).unwrap();
        crate::runtime::block_on(registry.acquire(&v1)); // 旧率窗口已用 1 次

        // 保存时 concurrentRate 缺省（None）→ DB 清空 + registry 移除
        let cleared = test_source(url, None);
        update_source(&serde_json::to_string(&cleared).unwrap()).unwrap();
        let found = list_sources()
            .unwrap()
            .into_iter()
            .find(|s| s.book_source_url == url)
            .expect("书源仍存在");
        assert!(
            found.concurrent_rate.is_none(),
            "缺省保存应清空 DB 内 concurrentRate"
        );
        crate::runtime::block_on(assert_stale_acquire_passes(&registry, &v1));

        // 空串同样走清除路径（registry 移除既有 limiter）
        let v2 = test_source(url, Some("2/10000"));
        update_source(&serde_json::to_string(&v2).unwrap()).unwrap();
        crate::runtime::block_on(registry.acquire(&v2)); // 新窗口已用 1 次
        let empty = test_source(url, Some(""));
        update_source(&serde_json::to_string(&empty).unwrap()).unwrap();
        crate::runtime::block_on(assert_stale_acquire_passes(&registry, &v2));

        delete_source(url).unwrap();
    }

    /// import 批量写库成功后按实际书源列表逐个刷新（先有 in-flight limiter 的
    /// URL 被导入新率时，旧快照立即受新率约束）
    #[test]
    fn test_import_sources_refreshes_rate_limiter() {
        let _db_guard = setup_test_db();
        let url = "https://ffi-ratelimit-import.example";
        let registry = crate::api::source_rate_limit::registry();

        let stale = test_source(url, Some("1/10000"));
        crate::runtime::block_on(registry.acquire(&stale)); // URL 尚未入库，先有 in-flight limiter（窗口已用 1 次）

        let imported = serde_json::to_string(&vec![test_source(url, Some("3/10000"))]).unwrap();
        assert_eq!(import_sources(&imported).unwrap(), 1);
        crate::runtime::block_on(assert_stale_acquire_passes(&registry, &stale));

        delete_source(url).unwrap();
    }

    /// [P1-1] 批量导入出口整批原子：第 1 条合法、第 2 条非法（数值不是
    /// 书源对象）→ 整批失败且数据库零新增（不残留第 1 条）；合法批次仍全部写入
    #[test]
    fn test_import_sources_batch_is_atomic() {
        let _db_guard = setup_test_db();
        let url_ok = "https://ffi-batch-atomic-ok.example";
        let url_ok2 = "https://ffi-batch-atomic-ok2.example";

        // 第 2 条非法 → 整批失败，第 1 条不得落库
        let bad_batch =
            format!(r#"[{{"bookSourceUrl":"{url_ok}","bookSourceName":"批量合法源"}},42]"#);
        assert!(import_sources(&bad_batch).is_err());
        let after_fail = list_sources().unwrap();
        assert!(
            after_fail.iter().all(|s| s.book_source_url != url_ok),
            "整批失败时第 1 条不得残留（无部分成功态）"
        );

        // 合法批次仍整批提交
        let good_batch = format!(
            r#"[{{"bookSourceUrl":"{url_ok}","bookSourceName":"批量合法源"}},
               {{"bookSourceUrl":"{url_ok2}","bookSourceName":"批量合法源二"}}]"#
        );
        assert_eq!(import_sources(&good_batch).unwrap(), 2);
        let after_ok = list_sources().unwrap();
        assert_eq!(
            after_ok
                .iter()
                .filter(|s| s.book_source_url == url_ok || s.book_source_url == url_ok2)
                .count(),
            2,
            "成功批次应整批落库"
        );

        delete_source(url_ok).unwrap();
        delete_source(url_ok2).unwrap();
    }
}
