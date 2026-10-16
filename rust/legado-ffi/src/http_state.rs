//! FFI 网络能力的薄适配：资源属于 EngineHolder 的 NetworkContext。
//!
//! 数据库打开前后的客户端共用同一 CookieStore 和可绑定后端。
//! Cookie 罐和持久化由实例统一拥有，无 JS 镜像或进程注册钩子。

use legado_core::LegadoResult;
use legado_net::{LegadoClient, LegadoClientConfig};

/// WebView 回流统一经过本实例的域通道、共享 jar 与合并持久化。
pub(crate) fn persist_cookie_row_merged(tag: &str, incoming: &str) {
    if let Err(error) = crate::engine_holder::network().set_cookie(tag, incoming) {
        log::warn!("合并持久化 Cookie '{tag}' 写入失败: {error}");
    }
}

pub fn shared_client() -> LegadoResult<LegadoClient> {
    crate::engine_holder::network().client()
}

pub fn reset_shared_client() {
    crate::engine_holder::network().reset_client();
}

pub fn reset_shared_client_with_config(config: LegadoClientConfig) -> LegadoResult<()> {
    crate::engine_holder::network().reset_client_with_config(config)
}

// ─── 测试 ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use legado_net::{CookiePersistence, CookieStore};
    use std::sync::Arc;

    /// 串行保护：以下测试会读写全局单例（含 reset），需串行执行避免相互干扰。
    static TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    /// 多次调用 shared_client 应共享同一底层客户端。
    ///
    /// 通过公共访问器 `cookie_store()` 返回的 `Arc` 指针相等来判定
    /// （clone 共享同一 `Arc<RwLock<CookieStore>>`）。
    #[test]
    fn test_shared_client_same_underlying() {
        let _g = TEST_LOCK.lock().unwrap();
        // 池锁（项 B/B1 锁序扩）：与 webview_api 等第二组池触碰测试串行
        let _p = crate::test_support::lock_pool_tests();
        let c1 = shared_client().unwrap();
        let c2 = shared_client().unwrap();
        assert!(
            Arc::ptr_eq(c1.cookie_store(), c2.cookie_store()),
            "多次 shared_client 应共享同一底层 CookieStore"
        );
    }

    /// 并发调用 shared_client 安全，且均共享同一底层客户端。
    #[test]
    fn test_shared_client_concurrent() {
        let _g = TEST_LOCK.lock().unwrap();
        let _p = crate::test_support::lock_pool_tests();
        let baseline = shared_client().unwrap();
        let baseline_ptr = Arc::as_ptr(baseline.cookie_store()) as usize;

        let mut handles = Vec::new();
        for _ in 0..8 {
            handles.push(std::thread::spawn(move || {
                let c = shared_client().unwrap();
                let ptr = Arc::as_ptr(c.cookie_store()) as usize;
                assert_eq!(ptr, baseline_ptr, "并发 shared_client 应共享同一底层客户端");
            }));
        }
        for h in handles {
            h.join().unwrap();
        }
    }

    /// reset 后应重建底层客户端（client_id 不同），但**共享 Cookie
    /// store 内容不丢**（Arc 指针不变——脑裂修复语义：reset 重建客户端
    /// 不另开新罐，在途 403 重种状态跨 reset 保留）。
    #[test]
    fn test_reset_shared_client_rebuilds() {
        let _g = TEST_LOCK.lock().unwrap();
        let _p = crate::test_support::lock_pool_tests();
        let before = shared_client().unwrap();
        reset_shared_client();
        let after = shared_client().unwrap();
        assert!(
            Arc::ptr_eq(before.cookie_store(), after.cookie_store()),
            "reset 后应复用进程级共享 Cookie store（内容不丢）"
        );
        assert_ne!(
            before.client_id(),
            after.client_id(),
            "reset 后应重建底层客户端实例"
        );
    }

    // ─── Cookie 持久化（DB 注入）测试 ──────────────────────────

    /// DB 已初始化时，shared_client 应携带持久化后端，
    /// 且 DB 中预置的 Cookie 应被加载到客户端 CookieStore。
    #[test]
    fn test_shared_client_with_db_cookie_persistence() {
        let _g = TEST_LOCK.lock().unwrap();
        // 池锁在 DB 守卫之前（锁序：store → 池 → DB，见 test_support 文档）
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        // 预置一条 Cookie 到 DB（tag 为域名，与内存 CookieStore 键对齐）
        crate::db_state::with_database(|db| {
            let repo = legado_db::CookieRepository::new(db.connection());
            repo.upsert("persist-test.com", "session=from_db")
        })
        .unwrap();

        // reset 后重建客户端，应从 DB 加载 Cookie
        reset_shared_client();
        let client = shared_client().unwrap();
        assert!(
            client.cookie_persistence().is_some(),
            "DB 已初始化时共享客户端应携带持久化后端"
        );
        let store = client
            .cookie_store()
            .read()
            .unwrap_or_else(|e| e.into_inner());
        assert_eq!(
            store.get_key("persist-test.com", "session"),
            Some("from_db".to_string()),
            "DB 预置 Cookie 应被加载到内存 CookieStore"
        );
    }

    /// DbCookiePersistence 直接测试：save/load 与 CookieRepository 联动；
    /// 删除走 CookieRepository 直删（`CookiePersistence::delete` 死 API
    /// 已移除——保护性删除收敛到 [`delete_cookie_rows`]/`DbCookiePersistence::clear_rows`，
    /// 见 [正确性 2026-09-24]）
    #[test]
    fn test_db_cookie_persistence_roundtrip() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();

        let persistence = crate::engine_holder::network().cookie_persistence();
        persistence.save("roundtrip.com", "a=1; b=2");

        let loaded = persistence.load_all();
        assert!(
            loaded
                .iter()
                .any(|(tag, c)| tag == "roundtrip.com" && c == "a=1; b=2"),
            "save 后 load_all 应包含写入条目"
        );

        crate::db_state::with_database(|db| {
            let repo = legado_db::CookieRepository::new(db.connection());
            repo.delete_by_tag("roundtrip.com")
        })
        .unwrap();
        let loaded = persistence.load_all();
        assert!(
            !loaded.iter().any(|(tag, _)| tag == "roundtrip.com"),
            "delete 后 load_all 不应再包含该条目"
        );
    }

    // ─── 批 2：JS 桥书源开关注册表（db_open 注册）测试 ──────────────────────

    /// 批 2：current_source tag（book_source_url）→ `enabledCookieJar` 解析
    ///
    /// 覆盖：缺键 JSON 导入 → `Some(true)`（与 legado-core serde 默认联动）；
    /// 显式 false → `Some(false)`；库中不存在 → `None`（JS 桥按关）。
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_lookup_source_cookie_jar_from_db() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        use legado_db::repository::Repository;

        const TAG_ON: &str = "https://jsgate-lookup-on.test/";
        const TAG_OFF: &str = "https://jsgate-lookup-off.test/";

        // 缺键 JSON：enabledCookieJar 由 serde default 补 Some(true)
        let source_on: legado_core::models::BookSource = serde_json::from_str(
            r#"{"bookSourceUrl":"https://jsgate-lookup-on.test/","bookSourceName":"开"}"#,
        )
        .expect("书源 JSON");
        assert_eq!(
            source_on.enabled_cookie_jar,
            Some(true),
            "缺键应默认 Some(true)"
        );
        crate::db_state::with_database(|db| {
            let repo = legado_db::BookSourceRepository::new(db.connection());
            repo.insert(&source_on)
        })
        .expect("插入开启源");

        let mut source_off = source_on.clone();
        source_off.book_source_url = TAG_OFF.to_string();
        source_off.enabled_cookie_jar = Some(false);
        crate::db_state::with_database(|db| {
            let repo = legado_db::BookSourceRepository::new(db.connection());
            repo.insert(&source_off)
        })
        .expect("插入关闭源");

        assert_eq!(
            crate::engine_holder::js_resources()
                .http_resources()
                .request_for(Some(TAG_ON))
                .cookie_jar_enabled,
            true,
            "开启源应解析为 Some(true)"
        );
        assert_eq!(
            crate::engine_holder::js_resources()
                .http_resources()
                .request_for(Some(TAG_OFF))
                .cookie_jar_enabled,
            false,
            "关闭源应解析为 Some(false)"
        );
        assert_eq!(
            crate::engine_holder::js_resources()
                .http_resources()
                .request_for(Some("https://jsgate-lookup-missing.test/"))
                .cookie_jar_enabled,
            false,
            "库中不存在 → None（JS 桥按关）"
        );
    }

    // ─── JS 宿主 Cookie 持久化下沉（db_open 注册）测试 ──────────────────────

    /// cookie 串按键集合比较辅助（HashMap 迭代序不保证，按键集合相等断言）
    fn cookie_parts(s: &str) -> Vec<String> {
        let mut parts: Vec<String> = s
            .split(';')
            .map(|p| p.trim().to_string())
            .filter(|p| !p.is_empty())
            .collect();
        parts.sort();
        parts
    }

    fn db_cookie_row(dk: &str) -> Option<String> {
        crate::db_state::with_database(|db| {
            let repo = legado_db::CookieRepository::new(db.connection());
            repo.get_by_tag(dk)
        })
        .expect("DB 必须已初始化（ensure_test_db）")
    }

    /// 实例 Cookie 能力 → DB 往返：写入落库（合并串）→ 模拟重启（清内存）→
    /// 回填命中；同名覆盖 / 异名保留后 DB 行与内存自洽；清除后两侧无残留
    #[test]
    fn test_instance_cookie_db_roundtrip() {
        use legado_js::host_api::cookie_store::CookieAccess;
        let cookies = crate::engine_holder::network();
        let _g = TEST_LOCK.lock().unwrap();
        // 用例含 clear_all_cookies（进程级）+ 全局 cookie store 断言，
        // 必须持全局 store 串行锁排除其他 FFI 用例的 cookie 状态；
        // 全局锁序不变式：先 store 锁、后 DB 锁（见 test_support 模块文档）
        let _gs = crate::test_support::lock_global_store();
        let _db_guard = crate::db_state::ensure_test_db();

        const URL: &str = "https://ffi-js-persist.test/";
        let dk = legado_net::cookie_store::normalize_cookie_key(URL);
        // 清理残留（幂等）
        cookies.clear(URL);
        assert!(db_cookie_row(&dk).is_none(), "测试前清理残留 DB 行");

        // 写入 → DB 行（域名键 → 合并后完整串）
        cookies.set(URL, "a=1");
        cookies.set(URL, "b=2");
        let row = db_cookie_row(&dk).expect("写入后 DB 必须有「域名键 → 合并串」行");
        assert_eq!(
            cookie_parts(&row),
            cookie_parts(&cookies.get(URL)),
            "落库串必须与内存串按键相等（重启后从 DB 恢复 = 重启前内存态）"
        );

        // 模拟进程重启：仅丢弃内存 store（重启不清 DB 行）→ 启动回填 → 必须命中
        cookies.cookie_store().write().unwrap().clear();
        assert_eq!(cookies.get(URL), "", "回填前内存态必为空");
        cookies.cookie_persistence().preload(cookies.cookie_store());
        assert_eq!(
            cookie_parts(&cookies.get(URL)),
            cookie_parts(&row),
            "回填后内存态必须等于重启前落库串"
        );

        // 同名键覆盖 + 异名键保留，DB 行随写更新且自洽
        cookies.set(URL, "a=3");
        let row2 = db_cookie_row(&dk).expect("覆盖写后 DB 行必须更新");
        let parts = cookie_parts(&row2);
        assert!(
            parts.contains(&"a=3".to_string()),
            "同名键后写必须覆盖: {row2}"
        );
        assert!(
            !parts.contains(&"a=1".to_string()),
            "同名键旧值必须被覆盖: {row2}"
        );
        assert!(parts.contains(&"b=2".to_string()), "异名键必须保留: {row2}");
        assert_eq!(
            parts,
            cookie_parts(&cookies.get(URL)),
            "DB 行必须与内存态按键自洽"
        );

        // 收尾：两侧齐清（内存 + DB）
        cookies.clear(URL);
        assert_eq!(cookies.get(URL), "");
        assert!(
            db_cookie_row(&dk).is_none(),
            "清除后 DB 行必须删除（无残留）"
        );
    }

    /// 合并写回归（跨 store 键丢失防护）：HTTP jar 行与 JS 下沉写同一
    /// 域名键时必须按键并集合并——jar 写回不得抹 JS 键集、JS 写不得抹
    /// jar 键集（裸 upsert 会以本侧全量串覆盖他侧键）；同名键后写胜出
    ///（对齐上游单存储 last-write 语义）；FFI `clear_cookie` 全层齐清
    #[test]
    fn test_instance_cookie_merge_with_http_rows() {
        use legado_js::host_api::cookie_store::CookieAccess;
        let cookies = crate::engine_holder::network();
        let _g = TEST_LOCK.lock().unwrap();
        // 全局锁序不变式：先 crate 级全局 store 锁、后测试 DB 锁（与
        // source_switch / search 测试组同序；颠倒 + 并行执行 = ABBA 死锁，
        // 见 test_support 模块文档）
        let _gs = crate::test_support::lock_global_store();
        // 池锁（store → 池 → DB，见 test_support 文档）：本用例触碰
        // 共享客户端 jar 内存，须与第二组池触碰测试（webview_api）串行
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        const URL: &str = "https://merge.collide.test/";
        let dk = legado_net::cookie_store::normalize_cookie_key(URL);
        cookies.clear(URL);
        assert!(db_cookie_row(&dk).is_none(), "测试前清理残留 DB 行");

        // 1) HTTP jar 行先存在（模拟 Set-Cookie 写回 "a=1"）
        crate::engine_holder::network()
            .cookie_persistence()
            .save(&dk, "a=1");
        assert_eq!(
            db_cookie_row(&dk).map(|r| cookie_parts(&r)),
            Some(cookie_parts("a=1")),
            "空行合并写 = 传入串"
        );

        // 2) JS 写 c=3 → 行必须并集（jar 行键不得被抹）
        cookies.set(URL, "c=3");
        let row = db_cookie_row(&dk).expect("JS 写后行必须存在");
        assert_eq!(
            cookie_parts(&row),
            cookie_parts("a=1; c=3"),
            "JS 写不得抹 jar 行键（并集合并）: {row}"
        );

        // 3) 同名键覆盖：JS 覆盖 a=9（写方胜出）
        cookies.set(URL, "a=9");
        let row = db_cookie_row(&dk).expect("同名覆盖后行必须存在");
        assert_eq!(
            cookie_parts(&row),
            cookie_parts("a=9; c=3"),
            "同名键后写必须覆盖（写方胜出）: {row}"
        );

        // 4) jar 再写回（其自身视图 "a=9; b=2"——jar 内存无 c 键）→
        //    并集必须保留 JS 的 c=3（jar 全量串不得抹 JS 键集）
        crate::engine_holder::network()
            .cookie_persistence()
            .save(&dk, "a=9; b=2");
        let row = db_cookie_row(&dk).expect("jar 写回后行必须存在");
        assert_eq!(
            cookie_parts(&row),
            cookie_parts("a=9; b=2; c=3"),
            "jar 写回不得抹 JS 键（并集合并）: {row}"
        );

        // 5) FFI 入口全层齐清：jar 内存 + DB 行 + JS 内存 + DB 行
        crate::api::net_api::clear_cookie(URL).expect("clear_cookie 必须成功");
        assert!(db_cookie_row(&dk).is_none(), "全层清除后 DB 行必须删除");
        assert_eq!(cookies.get(URL), "", "全层清除后 JS 内存必须为空");
        // jar 读 guard 必须**块内释放**：随后的 clear_cookies → sink.remove
        // 会对同一 `Arc<RwLock<CookieStore>>` 取**写**锁——同一线程仍持读
        // guard 时 `RwLock::write()` 是 std 保证的自死锁（写方等待全部读方
        // 释放，而读方就是本线程、永远无法释放），且会连带卡住持 TEST_LOCK
        // 之外的全部 FFI 测试
        {
            let client = shared_client().unwrap();
            let store = client
                .cookie_store()
                .read()
                .unwrap_or_else(|p| p.into_inner());
            assert!(
                store.get_key(&dk, "a").is_none(),
                "全层清除后 jar 内存必须无该域 cookie"
            );
        }
        cookies.clear(URL); // 幂等收尾（raw 键行若有残留一并清）
    }

    /// JS 清除路径（`clear_cookies` → `sink.remove`）必须同步清共享 HTTP
    /// 客户端内存 CookieStore 的对应域：统一清除语义——清除后 jar 的后续
    /// 写回不会以旧内存态把已清域重新落库（复活）
    #[test]
    fn test_instance_cookie_remove_covers_jar_memory() {
        use legado_js::host_api::cookie_store::CookieAccess;
        let cookies = crate::engine_holder::network();
        let _g = TEST_LOCK.lock().unwrap();
        // 全局锁序不变式：先 crate 级全局 store 锁、后测试 DB 锁（与
        // source_switch / search 测试组同序；颠倒 + 并行执行 = ABBA 死锁，
        // 见 test_support 模块文档）
        let _gs = crate::test_support::lock_global_store();
        // 池锁（store → 池 → DB，见 test_support 文档）：本用例触碰
        // 共享客户端 jar 内存，须与第二组池触碰测试（webview_api）串行
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        const URL: &str = "https://jar.sync.test/";
        let dk = legado_net::cookie_store::normalize_cookie_key(URL);

        cookies.clear(URL); // 幂等清理

        // 预置 jar 内存域 cookie（模拟 Set-Cookie 已写入的内存态）
        {
            let client = shared_client().unwrap();
            client
                .cookie_store()
                .write()
                .unwrap_or_else(|p| p.into_inner())
                .set_cookies_from_string(&dk, "a=1");
        }
        cookies.set(URL, "js=1"); // JS 写（行并集 "a=1; js=1"）
        cookies.clear(URL); // JS 清除路径（JS 内存 + DB 行 + jar 内存）
        assert!(db_cookie_row(&dk).is_none(), "清除后 DB 行必须删除");
        assert_eq!(cookies.get(URL), "", "清除后 JS 内存必须为空");
        let client = shared_client().unwrap();
        let store = client
            .cookie_store()
            .read()
            .unwrap_or_else(|p| p.into_inner());
        assert!(
            store.get_key(&dk, "a").is_none(),
            "JS 清除后 jar 内存对应域必须同步清除（不得写回复活）"
        );
    }

    /// 全量清除（`clear_all_cookies` → `sink.remove_all`）：DB 全部行
    /// （含 jar 写回行）+ jar 内存全清，回填后不复活
    #[test]
    fn test_instance_cookie_remove_all() {
        use legado_js::host_api::cookie_store::CookieAccess;
        let cookies = crate::engine_holder::network();
        let _g = TEST_LOCK.lock().unwrap();
        // 全局锁序不变式：先 crate 级全局 store 锁、后测试 DB 锁（与
        // source_switch / search 测试组同序；颠倒 + 并行执行 = ABBA 死锁，
        // 见 test_support 模块文档）
        let _gs = crate::test_support::lock_global_store();
        // 池锁（store → 池 → DB，见 test_support 文档）：全量清除同步
        // 清共享客户端 jar 内存，须与第二组池触碰测试（webview_api）串行
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        const URL_A: &str = "https://clearall.a.test/";
        const URL_B: &str = "https://clearall.b.test/";

        cookies.clear(URL_A);
        cookies.clear(URL_B); // 幂等清理

        let dk_a = legado_net::cookie_store::normalize_cookie_key(URL_A);
        let dk_b = legado_net::cookie_store::normalize_cookie_key(URL_B);
        cookies.set(URL_A, "k=v");
        crate::engine_holder::network()
            .cookie_persistence()
            .save(&dk_b, "other=1"); // 模拟另一域的 jar 写回行
        assert!(db_cookie_row(&dk_a).is_some(), "JS 行必须存在");
        assert!(db_cookie_row(&dk_b).is_some(), "jar 行必须存在");

        cookies.clear_all();

        assert!(
            db_cookie_row(&dk_a).is_none(),
            "全量清除必须删除 DB 行（JS 侧）"
        );
        assert!(
            db_cookie_row(&dk_b).is_none(),
            "全量清除必须删除 DB 行（jar 侧，统一存储全清）"
        );
        assert_eq!(cookies.get(URL_A), "");
        let client = shared_client().unwrap();
        let store = client
            .cookie_store()
            .read()
            .unwrap_or_else(|p| p.into_inner());
        assert!(
            store.get_key(&dk_b, "other").is_none(),
            "全量清除必须同步清空 jar 内存（不得写回复活）"
        );
        drop(store);
        cookies.cookie_persistence().preload(cookies.cookie_store());
        assert_eq!(cookies.get(URL_A), "", "全量清除 + 回填后不得复活已清除域");
    }

    /// 写放大缓解吞吐：1000 次值变化 `set_cookie`（每次触发一次 DB upsert，
    /// 值不变写跳过）+ 500 次四段串批量 `set_cookie_str`（每次 JS 调用至多
    /// 一次 upsert，逐段调用则每段一次），量级校验（DB 初始化后写路径
    /// 不阻塞 JS 执行）
    #[test]
    fn test_instance_cookie_upsert_throughput() {
        use legado_js::host_api::cookie_store::CookieAccess;
        let cookies = crate::engine_holder::network();
        let _g = TEST_LOCK.lock().unwrap();
        // 全局锁序不变式：先 crate 级全局 store 锁、后测试 DB 锁（与
        // source_switch / search 测试组同序；颠倒 + 并行执行 = ABBA 死锁，
        // 见 test_support 模块文档）
        let _gs = crate::test_support::lock_global_store();
        let _db_guard = crate::db_state::ensure_test_db();

        const URL: &str = "https://perf.jspersist.test/";
        let dk = legado_net::cookie_store::normalize_cookie_key(URL);
        cookies.clear(URL);
        assert!(db_cookie_row(&dk).is_none(), "测试前清理残留 DB 行");

        const N: usize = 1000;
        let start = std::time::Instant::now();
        for i in 0..N {
            // 值每次变化 → 每次触发一次 DB upsert（值不变写被跳过，
            // 本用例测的就是「必须写」路径的吞吐下限）
            cookies.set(URL, &format!("v=v{i}"));
        }
        let elapsed = start.elapsed();
        eprintln!(
            "[perf] JS cookie sink upsert: {N} ops in {elapsed:?} \
             (avg {} µs/op)",
            elapsed.as_micros() / N as u128
        );
        assert!(
            elapsed < std::time::Duration::from_secs(10),
            "DB 写放大吞吐不可接受: {elapsed:?}"
        );

        // 批量形态（JS `setCookie` 绑定实际入口）：四段串一次 JS 调用 =
        // 至多一次 upsert（逐段 set_cookie 则四段四次——量化批量收敛收益）
        const M: usize = 500;
        let batch_start = std::time::Instant::now();
        for i in 0..M {
            cookies.set(URL, &format!("p0=v{i}; p1=v{i}; p2=v{i}; p3=v{i}"));
        }
        let batch_elapsed = batch_start.elapsed();
        eprintln!(
            "[perf] JS cookie sink batch upsert (4-pair string): {M} ops in \
             {batch_elapsed:?} (avg {} µs/op, 每 op 至多 1 次 DB upsert)",
            batch_elapsed.as_micros() / M as u128
        );
        assert!(
            batch_elapsed < std::time::Duration::from_secs(10),
            "DB 批量写吞吐不可接受: {batch_elapsed:?}"
        );

        // 收尾：两侧齐清
        cookies.clear(URL);
        assert!(
            db_cookie_row(&dk).is_none(),
            "清除后 DB 行必须删除（无残留）"
        );
    }

    #[test]
    fn js_changed_key_does_not_restore_stale_http_cookie() {
        use legado_js::host_api::cookie_store::CookieAccess;
        let cookies = crate::engine_holder::network();
        let _g = TEST_LOCK.lock().unwrap();
        let _store = crate::test_support::lock_global_store();
        let _db = crate::db_state::ensure_test_db();

        let url = "https://stale-js-network.test/";
        let domain = legado_net::cookie_store::normalize_cookie_key(url);
        cookies.set(url, "session=old-js");
        let network = crate::engine_holder::network();
        network
            .set_cookie(&domain, "session=new-http; jarOnly=1")
            .unwrap();
        cookies.set(url, "other=new-js");
        let row = db_cookie_row(&domain).unwrap();
        let values = CookieStore::cookie_string_to_map(&row);
        assert_eq!(values.get("session").map(String::as_str), Some("new-http"));
        assert_eq!(values.get("other").map(String::as_str), Some("new-js"));
        assert_eq!(
            network
                .cookie_store()
                .read()
                .unwrap()
                .get_key(&domain, "session")
                .as_deref(),
            Some("new-http")
        );
        // 显式改写同名键仍按这次 JS 操作的新值生效。
        cookies.set(url, "session=explicit-js");
        assert_eq!(
            network
                .cookie_store()
                .read()
                .unwrap()
                .get_key(&domain, "session")
                .as_deref(),
            Some("explicit-js")
        );
        cookies.clear(url);
    }
}
