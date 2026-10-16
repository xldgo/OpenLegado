//! 两档均运行的实例 Cookie/数据库验证；不通过全局注册或镜像模拟。

use legado_engine::EngineContext;
use legado_js::host_api::cookie_store::CookieAccess;
use legado_net::{CookiePersistence, CookieStore};
use std::sync::Arc;
use std::time::Duration;

fn row(engine: &EngineContext, domain: &str) -> Option<String> {
    engine
        .storage()
        .with_database(|db| legado_db::CookieRepository::new(db.connection()).get_by_tag(domain))
        .unwrap()
}

fn values(engine: &EngineContext, url: &str) -> std::collections::HashMap<String, String> {
    CookieStore::cookie_string_to_map(&engine.network().get(url))
}

#[test]
fn both_hosts_cookie_capability_keeps_domain_and_instance_boundaries() {
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    for (url, domain, sibling) in [
        (
            "https://a.book.com.cn/chapter",
            "book.com.cn",
            "https://b.book.com.cn/other",
        ),
        (
            "http://127.0.0.1:8080/",
            "127.0.0.1",
            "http://127.0.0.1:9090/",
        ),
        ("http://[::1]:8080/", "::1", "http://[::1]:9090/"),
    ] {
        one.network().set(url, "session=one; second=retained");
        two.network().set(url, "session=two");
        assert_eq!(values(&one, sibling).get("session").unwrap(), "one");
        assert_eq!(values(&two, sibling).get("session").unwrap(), "two");
        assert!(row(&one, domain).unwrap().contains("session=one"));
        one.network().set(sibling, "session=changed");
        assert_eq!(values(&one, url).get("session").unwrap(), "changed");
        assert_eq!(values(&one, url).get("second").unwrap(), "retained");
        one.network().clear(url);
        assert_eq!(one.network().get(sibling), "");
        assert!(row(&one, domain).is_none());
        assert_eq!(values(&two, url).get("session").unwrap(), "two");
    }
    assert_eq!(one.network().get("https://foreign.test/"), "");
    one.network().set("bare-key", "bare=value");
    assert_eq!(one.network().get("bare-key"), "bare=value");
    assert_eq!(one.network().get("https://bare-key/"), "bare=value");
}

#[test]
fn cookie_header_merge_keeps_explicit_names_case_and_foreign_domains_out() {
    let engine = EngineContext::in_memory().unwrap();
    engine
        .network()
        .set("https://same.test", "a=jar; added=two");
    engine
        .network()
        .set("https://foreign.test", "foreign=secret");
    let mut headers = std::collections::HashMap::from([("cOoKiE".into(), "a=explicit".into())]);
    legado_js::host_api::cookie_store::merge_cookie_string(
        &mut headers,
        &engine.network().get("https://sub.same.test/page"),
    );
    assert_eq!(headers.len(), 1);
    let merged = CookieStore::cookie_string_to_map(&headers["cOoKiE"]);
    assert_eq!(merged.get("a").unwrap(), "explicit");
    assert_eq!(merged.get("added").unwrap(), "two");
    assert!(!merged.contains_key("foreign"));
    let mut empty = Default::default();
    legado_js::host_api::cookie_store::merge_cookie_string(&mut empty, "");
    assert!(empty.is_empty());
}

#[test]
fn raw_key_overlay_is_local_and_clear_removes_both_candidates() {
    let engine = EngineContext::in_memory().unwrap();
    let url = "https://raw.test/chapter";
    engine
        .network()
        .set("raw.test", "same=domain; retained=yes");
    engine.network().set_cookie(url, "same=raw").unwrap();
    assert_eq!(values(&engine, url).get("same").unwrap(), "raw");
    assert_eq!(values(&engine, url).get("retained").unwrap(), "yes");
    assert_eq!(
        values(&engine, "https://raw.test/other")
            .get("same")
            .unwrap(),
        "domain"
    );
    engine.network().clear(url);
    assert_eq!(engine.network().get(url), "");
    assert!(row(&engine, "raw.test").is_none());
    assert!(row(&engine, url).is_none());
}

#[test]
fn clear_all_preserves_write_identity_and_does_not_touch_another_engine() {
    let engine = EngineContext::in_memory().unwrap();
    let other = EngineContext::in_memory().unwrap();
    let before = legado_net::cookie_store::write_coordinator(engine.network().cookie_store());
    engine.network().set("https://one.test", "one=1");
    engine.network().set("https://two.test", "two=2");
    other.network().set("https://one.test", "other=3");
    engine.network().clear_all();
    let after = legado_net::cookie_store::write_coordinator(engine.network().cookie_store());
    assert!(Arc::ptr_eq(&before, &after));
    engine
        .network()
        .cookie_persistence()
        .preload(engine.network().cookie_store());
    assert!(engine.network().cookie_store().read().unwrap().is_empty());
    assert!(row(&engine, "one.test").is_none());
    assert!(row(&engine, "two.test").is_none());
    assert_eq!(other.network().get("https://one.test"), "other=3");
}

#[test]
fn memory_values_take_priority_when_rebuilding_a_client() {
    let engine = EngineContext::in_memory().unwrap();
    engine
        .network()
        .set("https://preload.test", "same=memory; kept=yes");
    engine
        .storage()
        .with_database(|db| {
            legado_db::CookieRepository::new(db.connection())
                .upsert("preload.test", "same=old; dbOnly=yes")
        })
        .unwrap();
    let client = engine.network().client().unwrap();
    assert_eq!(
        values(&engine, "https://preload.test").get("same").unwrap(),
        "memory"
    );
    assert_eq!(
        values(&engine, "https://preload.test")
            .get("dbOnly")
            .unwrap(),
        "yes"
    );
    assert_eq!(
        client
            .cookie_store()
            .read()
            .unwrap()
            .get_key("preload.test", "kept")
            .as_deref(),
        Some("yes")
    );
}

#[test]
fn unchanged_and_batch_writes_have_no_extra_database_updates() {
    let engine = EngineContext::in_memory().unwrap();
    engine.storage().with_database(|db| {
        db.connection().execute_batch("CREATE TABLE cookie_writes (total INTEGER NOT NULL); INSERT INTO cookie_writes VALUES(0); CREATE TRIGGER count_cookie_insert AFTER INSERT ON cookies BEGIN UPDATE cookie_writes SET total=total+1; END; CREATE TRIGGER count_cookie_update AFTER UPDATE ON cookies BEGIN UPDATE cookie_writes SET total=total+1; END;").map_err(|e|legado_core::LegadoError::Database(e.to_string()))
    }).unwrap();
    engine.network().set("https://batch.test", "a=1; b=2; c=3");
    engine.network().set("https://batch.test", "a=1; b=2; c=3");
    let count = engine
        .storage()
        .with_database(|db| {
            db.connection()
                .query_row("SELECT total FROM cookie_writes", [], |row| {
                    row.get::<_, i64>(0)
                })
                .map_err(|e| legado_core::LegadoError::Database(e.to_string()))
        })
        .unwrap();
    assert_eq!(count, 1);
    engine.network().set("https://batch.test", "a=changed");
    assert_eq!(values(&engine, "https://batch.test").len(), 3);
    assert_eq!(values(&engine, "https://batch.test").get("b").unwrap(), "2");
}

#[test]
fn failed_persistence_keeps_js_memory_but_native_results_report_the_error() {
    let engine = EngineContext::in_memory().unwrap();
    engine.network().set("https://failure.test", "session=old");
    engine.storage().with_database(|db|db.connection().execute_batch("CREATE TRIGGER reject_cookie_insert BEFORE INSERT ON cookies BEGIN SELECT RAISE(FAIL, 'fixture insert rejection'); END; CREATE TRIGGER reject_cookie_update BEFORE UPDATE ON cookies BEGIN SELECT RAISE(FAIL, 'fixture update rejection'); END; CREATE TRIGGER reject_cookie_delete BEFORE DELETE ON cookies BEGIN SELECT RAISE(FAIL, 'fixture delete rejection'); END;").map_err(|e|legado_core::LegadoError::Database(e.to_string()))).unwrap();
    engine
        .network()
        .set("https://failure.test", "session=memory");
    assert_eq!(
        engine.network().get("https://failure.test"),
        "session=memory"
    );
    assert_eq!(row(&engine, "failure.test").as_deref(), Some("session=old"));
    assert!(
        engine
            .network()
            .clear_cookie_keys(&["failure.test"])
            .is_err()
    );
    assert_eq!(engine.network().get("https://failure.test"), "");
    assert!(row(&engine, "failure.test").is_some());
    // 明确持久化失败后重建可能加载未删除的持久行，不宣称持久清除成功。
    engine
        .network()
        .cookie_persistence()
        .preload(engine.network().cookie_store());
    assert_eq!(engine.network().get("https://failure.test"), "session=old");
    engine.network().clear_all();
    assert_eq!(engine.network().get("https://failure.test"), "");
}

#[test]
fn domain_writer_and_delete_share_the_same_barrier_but_other_engines_do_not() {
    let one = Arc::new(EngineContext::in_memory().unwrap());
    let two = Arc::new(EngineContext::in_memory().unwrap());
    let (captured_tx, captured_rx) = std::sync::mpsc::channel();
    let (release_tx, release_rx) = std::sync::mpsc::channel();
    let writer_engine = one.clone();
    let writer = std::thread::spawn(move || {
        let network = writer_engine.network();
        legado_net::cookie_store::write_coordinator(network.cookie_store()).with_domain(
            "race.test",
            || {
                captured_tx.send(()).unwrap();
                release_rx.recv_timeout(Duration::from_secs(5)).unwrap();
                network
                    .cookie_store()
                    .write()
                    .unwrap()
                    .set_cookies_from_string("race.test", "stale=captured");
                network
                    .cookie_persistence()
                    .save("race.test", "stale=captured");
            },
        );
    });
    captured_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    let (other_tx, other_rx) = std::sync::mpsc::channel();
    let other = two.clone();
    let independent = std::thread::spawn(move || {
        other.network().set("https://race.test", "other=live");
        other_tx.send(()).unwrap();
    });
    other_rx
        .recv_timeout(Duration::from_secs(2))
        .expect("独立引擎不能被同域写锁阻塞");
    let (deleted_tx, deleted_rx) = std::sync::mpsc::channel();
    let clear_engine = one.clone();
    let clear = std::thread::spawn(move || {
        clear_engine.network().clear("https://race.test");
        deleted_tx.send(()).unwrap();
    });
    assert!(deleted_rx.recv_timeout(Duration::from_millis(40)).is_err());
    release_tx.send(()).unwrap();
    writer.join().unwrap();
    clear.join().unwrap();
    independent.join().unwrap();
    assert_eq!(one.network().get("https://race.test"), "");
    assert!(row(&one, "race.test").is_none());
    assert_eq!(two.network().get("https://race.test"), "other=live");
}

#[test]
fn cookie_resources_are_released_after_the_last_client_owner() {
    let engine = EngineContext::in_memory().unwrap();
    let store = Arc::downgrade(engine.network().cookie_store());
    let writes = legado_net::cookie_store::write_coordinator(engine.network().cookie_store());
    let weak_writes = Arc::downgrade(&writes);
    let client = engine.network().client().unwrap();
    drop(writes);
    drop(engine);
    assert!(store.upgrade().is_some());
    drop(client);
    assert!(store.upgrade().is_none());
    assert!(weak_writes.upgrade().is_none());
}

#[test]
fn deep_copy_has_an_independent_write_domain_but_arc_clients_share_the_original() {
    let original = Arc::new(std::sync::RwLock::new(CookieStore::new()));
    original
        .write()
        .unwrap()
        .set_cookies_from_string("copy.test", "a=original");
    let copied = Arc::new(std::sync::RwLock::new(original.read().unwrap().clone()));
    let original_writes = legado_net::cookie_store::write_coordinator(&original);
    let copied_writes = legado_net::cookie_store::write_coordinator(&copied);
    assert!(!Arc::ptr_eq(&original_writes, &copied_writes));
    let client =
        legado_net::LegadoClient::with_cookie_store(Default::default(), original.clone(), None)
            .unwrap();
    assert!(Arc::ptr_eq(
        &original_writes,
        &legado_net::cookie_store::write_coordinator(client.cookie_store())
    ));
    copied.write().unwrap().clear();
    assert_eq!(
        original
            .read()
            .unwrap()
            .cookies_for_key("https://copy.test"),
        "a=original"
    );
}

#[cfg(feature = "quickjs")]
#[test]
fn actual_vm_batch_replace_remove_and_cold_database_read_use_the_same_jar() {
    use legado_js::{JsEngine, SandboxConfig};
    let db = legado_db::init_in_memory_database().unwrap();
    legado_db::CookieRepository::new(db.connection())
        .upsert("native-cookie.test", "loaded=cold")
        .unwrap();
    let engine = EngineContext::from_database(db);
    let vm = engine
        .js_resources()
        .create_engine(SandboxConfig::default())
        .unwrap();
    assert_eq!(
        vm.eval("java.getCookie('https://sub.native-cookie.test/page','loaded')")
            .unwrap(),
        "cold"
    );
    vm.eval("java.setCookie('https://native-cookie.test','a=one; empty=; bad; =bad; eq=a=b')")
        .unwrap();
    vm.eval("java.replaceCookie('https://native-cookie.test','a=; b=two')")
        .unwrap();
    assert_eq!(
        vm.eval("java.getCookie('https://native-cookie.test','a')")
            .unwrap(),
        "one"
    );
    assert_eq!(
        vm.eval("java.getCookie('https://native-cookie.test','eq')")
            .unwrap(),
        "a=b"
    );
    let jar = engine.network().client().unwrap();
    assert_eq!(
        jar.cookie_store()
            .read()
            .unwrap()
            .get_key("native-cookie.test", "empty")
            .as_deref(),
        Some("")
    );
    assert!(!values(&engine, "https://native-cookie.test").contains_key("bad"));
    assert_eq!(
        vm.eval("java.removeCookie('https://native-cookie.test')")
            .unwrap(),
        ""
    );
    assert!(row(&engine, "native-cookie.test").is_none());
    assert_eq!(engine.network().get("https://native-cookie.test"), "");
    assert_eq!(
        jar.cookie_store()
            .read()
            .unwrap()
            .get_cookie_string("https://native-cookie.test"),
        ""
    );
}
