//! 网络资源的实例归属、开库前后接续和真实 localhost Cookie 往返。

use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::Arc;
use std::time::Duration;

use legado_db::CookieRepository;
use legado_engine::{EngineContext, NetworkContext};
use legado_net::{CookiePersistence, LegadoClientConfig, client::COOKIE_JAR_HEADER};

fn row(engine: &EngineContext, domain: &str) -> Option<String> {
    engine
        .storage()
        .with_database(|db| CookieRepository::new(db.connection()).get_by_tag(domain))
        .unwrap()
}

fn responses(responses: Vec<String>) -> (String, std::thread::JoinHandle<Vec<String>>) {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}/", listener.local_addr().unwrap());
    let handle = std::thread::spawn(move || {
        let mut requests = Vec::new();
        for response in responses {
            let (mut stream, _) = listener.accept().unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 1024];
            while !request.windows(4).any(|part| part == b"\r\n\r\n") {
                let count = stream.read(&mut buffer).unwrap();
                assert!(count > 0);
                request.extend_from_slice(&buffer[..count]);
            }
            requests.push(String::from_utf8(request).unwrap());
            stream.write_all(response.as_bytes()).unwrap();
        }
        requests
    });
    (url, handle)
}

#[tokio::test]
async fn redirect_cookies_share_the_request_gate_and_preserve_each_header() {
    for enabled in [true, false] {
        let (url, server) = responses(vec![
            "HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\nSet-Cookie: redirect=1; Path=/\r\nSet-Cookie: second=2; Path=/\r\nConnection: close\r\n\r\n".into(),
            "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".into(),
        ]);
        let engine = EngineContext::in_memory().unwrap();
        engine
            .network()
            .reset_client_with_config(LegadoClientConfig {
                no_proxy: true,
                ..Default::default()
            })
            .unwrap();
        let headers =
            enabled.then(|| HashMap::from([(COOKIE_JAR_HEADER.to_owned(), "1".to_owned())]));
        let result = engine
            .network()
            .client()
            .unwrap()
            .get_raw(&url, headers)
            .await
            .unwrap();
        assert_eq!(result.status, 200);
        let requests = server.join().unwrap();
        assert_eq!(requests[1].to_lowercase().contains("redirect=1"), enabled);
        assert_eq!(requests[1].to_lowercase().contains("second=2"), enabled);
        assert_eq!(row(&engine, "127.0.0.1").is_some(), enabled);
    }
}

#[tokio::test]
async fn concurrent_requests_keep_cookie_write_permissions_separate() {
    let (on_url, on_server) = responses(vec!["HTTP/1.1 200 OK\r\nContent-Length: 0\r\nSet-Cookie: on=1; Path=/\r\nConnection: close\r\n\r\n".into()]);
    let (off_url, off_server) = responses(vec!["HTTP/1.1 200 OK\r\nContent-Length: 0\r\nSet-Cookie: off=1; Path=/\r\nConnection: close\r\n\r\n".into()]);
    let engine = EngineContext::in_memory().unwrap();
    engine
        .network()
        .reset_client_with_config(LegadoClientConfig {
            no_proxy: true,
            ..Default::default()
        })
        .unwrap();
    let client = engine.network().client().unwrap();
    let (on, off) = tokio::join!(
        client.get_raw(
            &on_url,
            Some(HashMap::from([(
                COOKIE_JAR_HEADER.to_owned(),
                "1".to_owned()
            )]))
        ),
        client.get_raw(&off_url, None),
    );
    on.unwrap();
    off.unwrap();
    on_server.join().unwrap();
    off_server.join().unwrap();
    assert_eq!(row(&engine, "127.0.0.1").as_deref(), Some("on=1"));
}

#[test]
fn instances_isolate_cookie_storage_and_old_clients_keep_their_database() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let first_client = first.network().client().unwrap();
    let second_client = second.network().client().unwrap();
    assert!(!Arc::ptr_eq(
        first_client.cookie_store(),
        second_client.cookie_store()
    ));
    first_client
        .cookie_persistence()
        .unwrap()
        .save("same.test", "a=first");
    second_client
        .cookie_persistence()
        .unwrap()
        .save("same.test", "a=second");
    first.network().reset_client();
    first_client
        .cookie_persistence()
        .unwrap()
        .save("same.test", "b=old-request");
    assert_eq!(
        row(&first, "same.test").as_deref(),
        Some("a=first; b=old-request")
    );
    assert_eq!(row(&second, "same.test").as_deref(), Some("a=second"));
}

#[test]
fn early_network_binds_once_merges_memory_and_upgrades_existing_clients() {
    let network = Arc::new(NetworkContext::default());
    let early = network.client().unwrap();
    early
        .cookie_store()
        .write()
        .unwrap()
        .set_cookies_from_string("early.test", "shared=memory; early=1");
    let engine = EngineContext::in_memory().unwrap();
    engine
        .storage()
        .with_database(|db| {
            CookieRepository::new(db.connection()).upsert("early.test", "shared=db; disk=1")
        })
        .unwrap();
    let engine = engine.with_network(network.clone()).unwrap();
    assert_eq!(
        early.client_id(),
        engine.network().client().unwrap().client_id()
    );
    let merged = row(&engine, "early.test").unwrap();
    let map = legado_net::CookieStore::cookie_string_to_map(&merged);
    assert_eq!(map.get("shared").map(String::as_str), Some("memory"));
    assert_eq!(map.len(), 3);
    early
        .cookie_persistence()
        .unwrap()
        .save("early.test", "after=1");
    assert!(row(&engine, "early.test").unwrap().contains("after=1"));
    assert!(
        EngineContext::in_memory()
            .unwrap()
            .with_network(network)
            .is_err()
    );
    assert!(row(&engine, "early.test").unwrap().contains("disk=1"));
}

#[test]
fn clear_then_rebuild_does_not_restore_deleted_cookies() {
    let engine = EngineContext::in_memory().unwrap();
    let network = engine.network();
    let client = network.client().unwrap();
    client
        .cookie_store()
        .write()
        .unwrap()
        .set_cookies_from_string("clear.test", "a=1");
    network.cookie_persistence().save("clear.test", "a=1");
    network.clear_cookie_domain("clear.test").unwrap();
    network.reset_client();
    let rebuilt = network.client().unwrap();
    assert!(
        rebuilt
            .cookie_store()
            .read()
            .unwrap()
            .domain_cookie_string("clear.test")
            .is_empty()
    );
    assert!(
        client
            .cookie_store()
            .read()
            .unwrap()
            .domain_cookie_string("clear.test")
            .is_empty()
    );
    assert!(row(&engine, "clear.test").is_none());
}

#[test]
fn concurrent_rebuild_and_clear_leave_memory_and_database_empty() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    for _ in 0..12 {
        engine
            .network()
            .cookie_persistence()
            .save("race.test", "a=1");
        engine
            .network()
            .cookie_store()
            .write()
            .unwrap()
            .set_cookies_from_string("race.test", "a=1");
        engine.network().reset_client();
        std::thread::scope(|scope| {
            let load = scope.spawn(|| engine.network().client().unwrap());
            let clear = scope.spawn(|| engine.network().clear_cookie_domain("race.test").unwrap());
            load.join().unwrap();
            clear.join().unwrap();
        });
        assert!(row(&engine, "race.test").is_none());
        assert!(
            engine
                .network()
                .cookie_store()
                .read()
                .unwrap()
                .domain_cookie_string("race.test")
                .is_empty()
        );
    }
}

#[test]
fn concurrent_cookie_writers_merge_keys_without_cross_instance_callbacks() {
    let engine = EngineContext::in_memory().unwrap();
    std::thread::scope(|scope| {
        for i in 0..8 {
            let persistence = engine.network().cookie_persistence();
            scope.spawn(move || persistence.save("merge.test", &format!("key{i}=value{i}")));
        }
    });
    assert_eq!(
        legado_net::CookieStore::cookie_string_to_map(&row(&engine, "merge.test").unwrap()).len(),
        8
    );
}

#[test]
fn retained_client_does_not_keep_root_context_or_network_alive() {
    let engine = Arc::new(EngineContext::in_memory().unwrap());
    let weak_engine = Arc::downgrade(&engine);
    let weak_network = Arc::downgrade(engine.network());
    let client = engine.network().client().unwrap();
    drop(engine);
    assert!(weak_engine.upgrade().is_none());
    assert!(weak_network.upgrade().is_none());
    // 在途请求仍拥有原后端和池；不会读取另一个引擎的数据库。
    client
        .cookie_persistence()
        .unwrap()
        .save("retained.test", "a=1");
    assert_eq!(client.cookie_persistence().unwrap().load_all().len(), 1);
}

#[tokio::test]
async fn localhost_response_cookie_is_shared_persisted_cleared_and_gated() {
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let server = std::thread::spawn(move || {
        let mut requests = Vec::new();
        for _ in 0..3 {
            let (mut stream, _) = listener.accept().unwrap();
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 1024];
            while !request.windows(4).any(|part| part == b"\r\n\r\n") {
                let count = stream.read(&mut buffer).unwrap();
                assert!(count > 0);
                request.extend_from_slice(&buffer[..count]);
            }
            requests.push(String::from_utf8(request).unwrap());
            stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nSet-Cookie: response=1; Path=/\r\nConnection: close\r\n\r\nok").unwrap();
        }
        requests
    });
    let network = Arc::new(NetworkContext::default());
    network
        .reset_client_with_config(LegadoClientConfig {
            no_proxy: true,
            ..Default::default()
        })
        .unwrap();
    let early = network.client().unwrap();
    let url = format!("http://{address}/");
    let headers = HashMap::from([(COOKIE_JAR_HEADER.to_owned(), "1".to_owned())]);
    early.get_raw(&url, Some(headers.clone())).await.unwrap();
    let engine = EngineContext::in_memory()
        .unwrap()
        .with_network(network)
        .unwrap();
    assert_eq!(row(&engine, "127.0.0.1").as_deref(), Some("response=1"));
    let web_client = engine.network().client().unwrap();
    assert_eq!(early.client_id(), web_client.client_id());
    web_client.get_raw(&url, Some(headers)).await.unwrap();
    engine.network().clear_cookie_domain("127.0.0.1").unwrap();
    early.get_raw(&url, None).await.unwrap();
    let seen = server.join().unwrap();
    assert!(seen[1].to_lowercase().contains("cookie: response=1"));
    assert!(!seen[2].to_lowercase().contains("cookie:"));
    assert!(
        row(&engine, "127.0.0.1").is_none(),
        "关闭 CookieJar 时响应不得重新落库"
    );
}
