//! FFI 开库后 JS/WebView 与权威 Cookie 罐、真实数据库的闭环。
use legado_js::host_api::cookie_store::CookieAccess;
use std::path::Path;

/// 临时 DB 路径（进程号后缀防并发二进制撞名；测试开头先清掉上一次残留）
fn temp_db_path() -> std::path::PathBuf {
    let p = std::env::temp_dir().join(format!(
        "legado-ffi-db-open-wiring-{}.db",
        std::process::id()
    ));
    let _ = std::fs::remove_file(&p);
    p
}

/// rusqlite 直连读 `cookies` 表行（绕过下沉读路径，验证真实落库内容）
fn query_cookie_row(db_path: &Path, tag: &str) -> Option<String> {
    use rusqlite::OptionalExtension;
    let conn = rusqlite::Connection::open(db_path).expect("rusqlite 直连临时 DB");
    conn.query_row(
        "SELECT cookie FROM cookies WHERE url = ?1",
        rusqlite::params![tag],
        |r| r.get::<_, String>(0),
    )
    .optional()
    .expect("查询 cookies 表")
}

#[test]
fn db_open_wires_instance_cookies_and_persistence_end_to_end() {
    let db_path = temp_db_path();
    legado_ffi::ffi::ffi::init().unwrap();
    legado_ffi::ffi::ffi::db_open(db_path.to_string_lossy().into_owned()).unwrap();
    const URL: &str = "https://wiring.cookie.test/";
    let domain = legado_net::cookie_store::normalize_cookie_key(URL);
    #[cfg(feature = "quickjs")]
    legado_ffi::js_executor::execute_auto_task_js(
        "java.setCookie('https://wiring.cookie.test/', 'wiring=ok')",
    )
    .unwrap();
    #[cfg(not(feature = "quickjs"))]
    legado_ffi::api::webview_api::submit_webview_result_with_cookies(
        "no-waiter",
        "",
        &serde_json::json!({ (URL):"wiring=ok" }).to_string(),
    );
    assert_eq!(
        query_cookie_row(&db_path, &domain).as_deref(),
        Some("wiring=ok")
    );
    let reopened = legado_engine::EngineContext::open(db_path.to_str().unwrap()).unwrap();
    assert_eq!(reopened.network().get(URL), "wiring=ok");
    legado_ffi::api::net_api::clear_cookie(URL).unwrap();
    assert!(query_cookie_row(&db_path, &domain).is_none());
    let after_clear = legado_engine::EngineContext::open(db_path.to_str().unwrap()).unwrap();
    assert_eq!(after_clear.network().get(URL), "");
    assert_eq!(
        legado_ffi::http_state::shared_client()
            .unwrap()
            .cookie_store()
            .read()
            .unwrap()
            .cookies_for_key(URL),
        ""
    );
}
