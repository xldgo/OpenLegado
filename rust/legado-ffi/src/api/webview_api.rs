//! BackstageWebView DOM 执行通道 FFI（SOURCE_DIFF P1）
//!
//! 对 `legado_core::webview_channel` 的纯 FFI 包装：
//! - 事件流：[`run_webview_request_stream`]
//! - 回传：[`submit_webview_result`] / [`submit_webview_result_with_cookies`]（项 B/B1）
//! - 取消：[`cancel_webview_request`]

use std::sync::Arc;

use legado_core::webview_channel::{WebViewManager, WebViewRequest};

/// 只捕获数据能力；回调不会查询调用时的其他Engine或保留根实例。
struct WebViewHost {
    manager: Arc<WebViewManager>,
    network: Arc<legado_engine::NetworkContext>,
}
fn host() -> WebViewHost {
    WebViewHost {
        manager: manager(),
        network: crate::engine_holder::network(),
    }
}
fn manager() -> Arc<WebViewManager> {
    crate::engine_holder::js_resources()
        .host_resources()
        .webview
        .clone()
}

/// WebView 请求事件流（长期存活）
pub async fn run_webview_request_stream<F>(mut on_event: F)
where
    F: FnMut(WebViewRequest) -> Result<(), String>,
{
    let manager = manager();
    let Ok(task) = crate::engine_holder::task_group().begin() else {
        return;
    };
    let _guard = task.guard();
    let mut subscription = manager.subscribe();
    loop {
        let request = tokio::select! {
            biased;
            _=task.cancelled()=>break,
            request=subscription.recv_async()=>match request {Some(request)=>request,None=>break},
        };
        match task.with_active(|| on_event(request)) {
            Some(Ok(())) => {}
            _ => break,
        }
    }
}

pub fn submit_webview_result(key: &str, result: &str) -> bool {
    manager().submit(key, result)
}

/// 提交 WebView 执行结果 + WebView 侧域 cookie 回流（项 B/B1，加法式条目）
///
/// 设计/取证：`.tmp/engine_forensic_d/design_upstream_aligned.md` §3 项 B1
/// 与 §2.2 G1——WebView 路径（原生 backstageEval）完成的 WAF 状态机 cookie
/// 此前仅驻留 Android `CookieManager`，从不回流 Rust/DB cookie 存储，后续
/// JS 桥请求缺会话态（冷启动被重新挑战，如 x81zws 403 场景）。
///
/// 先认领本实例仍有效的请求，再通过所属NetworkContext合并Cookie，最后唤醒。
/// 未知、取消、超时或重复的key没有Cookie副作用；认领后的写入不承诺强制回滚。
/// Cookie解析失败仍沿用空映射与既有结果回传，数据库失败记录日志。
pub fn submit_webview_result_with_cookies(key: &str, result: &str, cookies_json: &str) -> bool {
    let cookies = if cookies_json.trim().is_empty() {
        Default::default()
    } else {
        serde_json::from_str::<serde_json::Map<String, serde_json::Value>>(cookies_json)
            .map(|values| {
                values
                    .into_iter()
                    .filter_map(|(key, value)| value.as_str().map(|v| (key, v.to_owned())))
                    .collect()
            })
            .unwrap_or_else(|error| {
                log::warn!("WebView cookie 回流解析失败：{error}");
                Default::default()
            })
    };
    submit_webview_result_with_cookie_map(key, result, cookies)
}

pub fn submit_webview_result_with_cookie_map(
    key: &str,
    result: &str,
    cookies: std::collections::HashMap<String, String>,
) -> bool {
    host().submit(key, result, cookies)
}
impl WebViewHost {
    fn submit(
        &self,
        key: &str,
        result: &str,
        cookies: std::collections::HashMap<String, String>,
    ) -> bool {
        self.complete(
            key,
            legado_core::webview_channel::WebViewResponse {
                result: result.into(),
                ..Default::default()
            },
            cookies,
        )
    }
    fn complete(
        &self,
        key: &str,
        response: legado_core::webview_channel::WebViewResponse,
        cookies: std::collections::HashMap<String, String>,
    ) -> bool {
        if response
            .error
            .as_ref()
            .is_some_and(|error| error.trim().is_empty())
        {
            return false;
        }
        self.manager.submit_response_with(key, response, || {
            for (raw_key, cookie) in cookies {
                if cookie.trim().is_empty() {
                    continue;
                }
                let domain = legado_net::cookie_store::normalize_cookie_key(&raw_key);
                if !domain.is_empty()
                    && let Err(error) = self.network.set_cookie(&domain, &cookie)
                {
                    log::warn!("合并持久化WebView Cookie失败: {error}");
                }
            }
        })
    }
}

pub fn complete_webview_request(key: &str, response: crate::task_dto::WebViewResponseDto) -> bool {
    host().complete(
        key,
        legado_core::webview_channel::WebViewResponse {
            result: response.result,
            final_url: response.final_url,
            error: response.error,
        },
        response.cookies,
    )
}

pub fn cancel_webview_request(key: &str) -> bool {
    manager().cancel(key)
}

pub fn page_call(
    key: &str,
    call: crate::task_dto::WebViewPageCallDto,
) -> legado_core::LegadoResult<String> {
    use crate::task_dto::WebViewPageTargetDto;
    use legado_engine::webview_page_service::{PageCall, PageTarget, WebViewPageService};
    let js = crate::engine_holder::js_resources();
    let manager = js.host_resources().webview.clone();
    let service = WebViewPageService {
        js,
        storage: crate::engine_holder::current()
            .ok()
            .map(|engine| engine.storage().clone()),
    };
    let target = match call.target {
        WebViewPageTargetDto::Source => PageTarget::Source,
        WebViewPageTargetDto::Cache => PageTarget::Cache,
        WebViewPageTargetDto::Java => PageTarget::Java,
    };
    let value = manager.with_page_call(key, |request, lease| {
        service.call(
            request,
            lease,
            PageCall {
                target,
                method: call.method,
                args: call.args,
            },
        )
    })?;
    Ok(serde_json::to_string(&value)?)
}

pub fn pending_requests() -> Vec<WebViewRequest> {
    manager().pending()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn typed_completion_keeps_final_url_empty_success_and_claims_before_cookies() {
        use legado_core::webview_channel::WebViewResponse;
        let engine = legado_engine::EngineContext::in_memory().unwrap();
        let host = WebViewHost {
            manager: engine.js_resources().host_resources().webview.clone(),
            network: engine.network().clone(),
        };
        let request = || WebViewRequest {
            url: "https://typed.webview.test/start".into(),
            ..Default::default()
        };
        let cookies = || {
            std::collections::HashMap::from([(
                "https://typed.webview.test/final".into(),
                "session=new".into(),
            )])
        };
        let handle = host.manager.request(request());
        assert!(!host.complete(
            handle.key(),
            WebViewResponse {
                error: Some(" ".into()),
                ..Default::default()
            },
            cookies()
        ));
        let domain = legado_net::cookie_store::normalize_cookie_key("https://typed.webview.test/");
        assert!(
            engine
                .storage()
                .with_database(|db| {
                    legado_db::CookieRepository::new(db.connection()).get_by_tag(&domain)
                })
                .unwrap()
                .is_none()
        );
        assert!(host.complete(
            handle.key(),
            WebViewResponse {
                result: String::new(),
                final_url: "https://typed.webview.test/final".into(),
                error: None,
            },
            cookies()
        ));
        let response = handle
            .wait_response(std::time::Duration::from_secs(1))
            .unwrap();
        assert_eq!(response.result, "");
        assert_eq!(response.final_url, "https://typed.webview.test/final");
        let domain = legado_net::cookie_store::normalize_cookie_key(&response.final_url);
        let row = engine
            .storage()
            .with_database(|db| {
                legado_db::CookieRepository::new(db.connection()).get_by_tag(&domain)
            })
            .unwrap();
        assert_eq!(row.as_deref(), Some("session=new"));
        let handle = host.manager.request(request());
        assert!(host.complete(
            handle.key(),
            WebViewResponse {
                error: Some("页面失败".into()),
                ..Default::default()
            },
            Default::default()
        ));
        assert!(
            handle
                .wait_response(std::time::Duration::from_secs(1))
                .unwrap_err()
                .to_string()
                .contains("页面失败")
        );
    }

    /// cookie 串按键集合比较辅助（HashMap 迭代序不保证，按键集合相等断言；
    /// 与 http_state 测试同名辅助同语义）
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

    /// B1：cookiesJson 域键 ETLD+1 归一 → merged upsert 落库（同名键新值
    /// 胜、异名键并集），且等待方被唤醒（先持久化后唤醒）
    #[test]
    fn test_submit_with_cookies_merged_upsert() {
        // 全局锁序不变式：（模块锁）→ store 锁 → 池锁 → DB 守卫
        // （见 test_support 模块文档）
        let _gs = crate::test_support::lock_global_store();
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        const URL: &str = "https://a.wv-b1-merge.test/";
        let dk = legado_net::cookie_store::normalize_cookie_key(URL);
        // 幂等清理残留行（DB 守卫已持有，失败即环境异常）
        crate::engine_holder::network()
            .clear_cookie_keys(&[dk.as_str()])
            .expect("清理残留行必须成功（DB 已初始化）");
        // 预置行（模拟 jar / JS 侧已落库键 a=1）
        crate::engine_holder::network()
            .set_cookie(&dk, "a=1")
            .unwrap();

        // 等待方线程挂起（模拟 JS 执行线程），主线程回流 + 唤醒
        let req = WebViewRequest {
            key: String::new(),
            action: "webView".into(),
            html: String::new(),
            url: URL.into(),
            js: String::new(),
            source_regex: String::new(),
            override_url_regex: String::new(),
            cache_first: false,
            delay_time: 0,
            is_rule: false,
            result: String::new(),
            source_key: String::new(),
            cookie: String::new(),
            headers: Default::default(),
            created_at_ms: 0,
        };
        let mgr = manager();
        let handle = mgr.request(req);
        let key = handle.key().to_string();
        let waiter = thread::spawn(move || handle.wait(std::time::Duration::from_secs(5)));

        // a=2 覆盖 a=1（写方胜）、b=3 并集追加
        let hit = submit_webview_result_with_cookies(
            &key,
            "done",
            &format!("{{\"{}\": \"a=2; b=3\"}}", URL),
        );
        assert!(hit, "必须命中进行中的请求");
        assert_eq!(
            waiter.join().unwrap().unwrap(),
            "done",
            "等待方必须收到结果"
        );

        let row = db_cookie_row(&dk).expect("落库后 DB 行必须存在");
        assert_eq!(
            cookie_parts(&row),
            cookie_parts("a=2; b=3"),
            "merged upsert 必须为键集并集 + 同名新值胜: {row}"
        );
        // 收尾清理
        crate::engine_holder::network()
            .clear_cookie_keys(&[dk.as_str()])
            .expect("收尾清理必须成功（DB 已初始化）");
    }

    /// P2-19 反例：不相关域名的 cookie 绝不落行（归一到 ETLD+1 域键，
    /// 子域 URL 不得新建子域行；其他域已有行不被触碰）
    #[test]
    fn test_submit_with_cookies_unrelated_domain_not_touched() {
        let _gs = crate::test_support::lock_global_store();
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        // 两域 ETLD+1 必须不同（keep → wv-b1.test；other → wv-b2.test），
        // 且 other 为子域形态（验证归一后不落子域原始行）
        const KEEP_URL: &str = "https://keep.wv-b1.test/";
        const OTHER_URL: &str = "https://sub.unrelated.wv-b2.test/";
        let keep_dk = legado_net::cookie_store::normalize_cookie_key(KEEP_URL);
        let other_dk = legado_net::cookie_store::normalize_cookie_key(OTHER_URL);
        assert_ne!(keep_dk, other_dk, "两个域键必须不同");
        let tags: Vec<&str> = vec![keep_dk.as_str(), other_dk.as_str()];
        crate::engine_holder::network()
            .clear_cookie_keys(&tags)
            .expect("清理残留行必须成功（DB 已初始化）");

        // 无关域已有行
        crate::engine_holder::network()
            .set_cookie(&keep_dk, "keep=1")
            .unwrap();

        // 回流另一域（子域 URL 形态）cookie
        let hit = submit_webview_result_with_cookies(
            "wv-b1-nokey", // 无进行中的请求 → 返回false且不写Cookie
            "ignored",
            &format!("{{\"{}\": \"waf=42\"}}", OTHER_URL),
        );
        assert!(!hit, "无进行中请求时 submit 必须返回 false");

        // 不相关域行不被触碰
        assert_eq!(
            cookie_parts(&db_cookie_row(&keep_dk).unwrap_or_default()),
            cookie_parts("keep=1"),
            "回流另一域不得触碰 keep 域行"
        );
        #[cfg(feature = "quickjs")]
        {
            // ETLD+1 归一：子域 URL 落到 `wv-b2.test` 行
            assert_eq!(other_dk, "wv-b2.test", "quickjs 档必须归一到 ETLD+1");
            assert_eq!(
                cookie_parts(&db_cookie_row(&other_dk).unwrap_or_default()),
                Vec::<String>::new(),
                "未知请求不得创建Cookie行"
            );
            // 反例核心：不得新建子域原始行
            assert!(
                db_cookie_row("sub.unrelated.wv-b2.test").is_none(),
                "P2-19：子域原始键不得落行（必须归一到 ETLD+1）"
            );
        }
        // 收尾清理
        let tags: Vec<&str> = vec![keep_dk.as_str(), other_dk.as_str()];
        crate::engine_holder::network()
            .clear_cookie_keys(&tags)
            .expect("收尾清理必须成功（DB 已初始化）");
    }

    /// 空 / 非法 cookiesJson：不 panic、不落库、唤醒语义与旧方法一致
    #[test]
    fn test_submit_with_cookies_empty_or_invalid_json() {
        let _gs = crate::test_support::lock_global_store();
        let _p = crate::test_support::lock_pool_tests();
        let _db_guard = crate::db_state::ensure_test_db();

        let req = WebViewRequest {
            key: String::new(),
            action: "webView".into(),
            html: String::new(),
            url: "https://invalid.wv-b1.test/".into(),
            js: String::new(),
            source_regex: String::new(),
            override_url_regex: String::new(),
            cache_first: false,
            delay_time: 0,
            is_rule: false,
            result: String::new(),
            source_key: String::new(),
            cookie: String::new(),
            headers: Default::default(),
            created_at_ms: 0,
        };
        let mgr = manager();
        let handle = mgr.request(req);
        let key = handle.key().to_string();
        let waiter = thread::spawn(move || handle.wait(std::time::Duration::from_secs(5)));

        for bad in ["", "{}", "   ", "not-a-json", "\"just a string\"", "[1, 2]"] {
            let hit = submit_webview_result_with_cookies(&key, "noop", bad);
            // 首次命中唤醒后请求已出队，后续提交返回 false（同旧方法语义）
            assert_eq!(
                hit,
                bad.is_empty(),
                "首次提交必须命中，重复提交返回 false（{bad}）"
            );
        }
        assert_eq!(waiter.join().unwrap().unwrap(), "noop");

        // 空值条目不落行：再发一个全空值对象
        let _ = submit_webview_result_with_cookies(
            "wv-b1-emptyvals",
            "noop",
            r#"{ "https://emptyvals.wv-b1.test/": "  ", "https://emptyvals2.wv-b1.test/": "" }"#,
        );
        assert!(
            db_cookie_row("emptyvals.wv-b1.test").is_none(),
            "全空值条目不得落行"
        );
    }

    #[test]
    fn results_and_cookie_effects_belong_to_only_the_live_request_owner() {
        use legado_engine::EngineContext;
        let one = Arc::new(EngineContext::in_memory().unwrap());
        let two = EngineContext::in_memory().unwrap();
        let weak = Arc::downgrade(&one);
        let make_host = |engine: &EngineContext| WebViewHost {
            manager: engine.js_resources().host_resources().webview.clone(),
            network: engine.network().clone(),
        };
        let a = make_host(&one);
        let b = make_host(&two);
        let request = || {
            serde_json::from_value(serde_json::json!({
                "key":"", "action":"webView", "html":"", "url":"https://same.webview.test/",
                "js":"", "is_rule":false, "result":"", "created_at_ms":0
            }))
            .unwrap()
        };
        let cookies = |value: &str| {
            std::collections::HashMap::from([("https://same.webview.test/".into(), value.into())])
        };
        let domain = legado_net::cookie_store::normalize_cookie_key("https://same.webview.test/");
        let row = |engine: &EngineContext| {
            engine
                .storage()
                .with_database(|db| {
                    legado_db::CookieRepository::new(db.connection()).get_by_tag(&domain)
                })
                .unwrap()
        };
        let handle = a.manager.request(request());
        let key = handle.key().to_string();
        assert!(!b.submit(&key, "wrong", cookies("session=wrong")));
        assert!(row(&one).is_none());
        assert!(row(&two).is_none());
        assert!(a.submit(&key, "done", cookies("session=one")));
        assert_eq!(
            handle.wait(std::time::Duration::from_secs(1)).unwrap(),
            "done"
        );
        assert_eq!(row(&one).as_deref(), Some("session=one"));
        assert!(row(&two).is_none());
        assert!(!a.submit(&key, "duplicate", cookies("session=duplicate")));
        let handle = a.manager.request(request());
        let key = handle.key().to_string();
        assert!(a.manager.cancel(&key));
        assert!(!a.submit(&key, "late", cookies("session=late")));
        assert!(handle.wait(std::time::Duration::from_secs(1)).is_err());
        let handle = a.manager.request(request());
        let key = handle.key().to_string();
        assert!(handle.wait(std::time::Duration::ZERO).is_err());
        assert!(!a.submit(&key, "expired", cookies("session=expired")));
        assert!(!a.submit("unknown", "", cookies("session=unknown")));
        assert_eq!(row(&one).as_deref(), Some("session=one"));
        assert!(row(&two).is_none());
        drop(one);
        assert!(weak.upgrade().is_none(), "捕获的数据能力不得强持根Engine");
        assert!(!a.submit("unknown-after-drop", "", cookies("session=after")));
    }
}
