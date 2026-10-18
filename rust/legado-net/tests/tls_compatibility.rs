//! reqwest 升级后的真实 TLS 握手回归，全部使用本地服务。

use legado_net::{ssl_config::SslConfig, tls::client_builder};
use rustls::{ServerConfig, pki_types::PrivateKeyDer};
use std::{net::SocketAddr, sync::Arc, time::Duration};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
    task::JoinHandle,
};
use tokio_rustls::TlsAcceptor;

async fn https_fixture() -> (SocketAddr, String, JoinHandle<bool>) {
    https_fixture_for("localhost").await
}

async fn https_fixture_for(name: &str) -> (SocketAddr, String, JoinHandle<bool>) {
    let name = name.to_string();
    let rcgen::CertifiedKey { cert, signing_key } =
        rcgen::generate_simple_self_signed(vec![name.clone()]).unwrap();
    let pem = cert.pem();
    let key = PrivateKeyDer::Pkcs8(signing_key.serialize_der().into());
    let config =
        ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
            .with_safe_default_protocol_versions()
            .unwrap()
            .with_no_client_auth()
            .with_single_cert(vec![cert.der().clone()], key)
            .unwrap();
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let server = tokio::spawn(async move {
        let (stream, _) = tokio::time::timeout(Duration::from_secs(5), listener.accept())
            .await
            .unwrap()
            .unwrap();
        let Ok(mut stream) = TlsAcceptor::from(Arc::new(config)).accept(stream).await else {
            return false;
        };
        assert_eq!(
            stream.get_ref().1.server_name(),
            Some(name.as_str()),
            "连接IP覆盖不得改变TLS SNI"
        );
        let mut request = Vec::new();
        let mut buffer = [0; 1024];
        // TLS 读取可能分段，收齐请求头后再响应，并拒绝提前关闭的连接。
        loop {
            let count = stream.read(&mut buffer).await.unwrap();
            assert!(count > 0, "TLS 客户端在请求头完整前关闭连接");
            request.extend_from_slice(&buffer[..count]);
            if request.windows(4).any(|bytes| bytes == b"\r\n\r\n") {
                break;
            }
        }
        let head = String::from_utf8(request).unwrap().to_lowercase();
        assert!(
            head.contains(&format!("host: {name}:{}", address.port())),
            "HTTP Host必须保留原URL域名"
        );
        stream
            .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
            .await
            .unwrap();
        stream.shutdown().await.unwrap();
        true
    });
    (address, pem, server)
}

fn fixture_client(address: SocketAddr, ssl: SslConfig) -> reqwest::Client {
    ssl.apply(client_builder())
        .no_proxy()
        .resolve("localhost", address)
        .timeout(Duration::from_secs(5))
        .build()
        .unwrap()
}

#[tokio::test]
async fn default_rejects_untrusted_certificate() {
    let (address, _, server) = https_fixture().await;
    let client = fixture_client(address, SslConfig::default());
    let error = client
        .get(format!("https://localhost:{}/", address.port()))
        .send()
        .await
        .unwrap_err();
    assert!(error.is_connect(), "{error:?}");
    assert!(!server.await.unwrap());
}

#[tokio::test]
async fn explicit_unsafe_ssl_accepts_self_signed_certificate() {
    let (address, _, server) = https_fixture().await;
    let client = fixture_client(address, SslConfig::unsafe_ssl());
    let response = client
        .get(format!("https://localhost:{}/", address.port()))
        .send()
        .await
        .unwrap();
    assert_eq!(response.text().await.unwrap(), "ok");
    assert!(server.await.unwrap());
}

#[tokio::test]
async fn custom_ca_accepts_matching_certificate() {
    let (address, pem, server) = https_fixture().await;
    let client = fixture_client(address, SslConfig::with_ca(pem));
    let response = client
        .get(format!("https://localhost:{}/", address.port()))
        .send()
        .await
        .unwrap();
    assert_eq!(response.text().await.unwrap(), "ok");
    assert!(server.await.unwrap());
}

#[tokio::test]
async fn custom_ca_still_rejects_wrong_hostname() {
    let (address, pem, server) = https_fixture().await;
    let client = fixture_client(address, SslConfig::with_ca(pem));
    let error = client
        .get(format!("https://127.0.0.1:{}/", address.port()))
        .send()
        .await
        .unwrap_err();
    assert!(error.is_connect(), "{error:?}");
    assert!(!server.await.unwrap());
}

#[tokio::test]
async fn request_dns_preserves_sni_host_and_certificate_verification() {
    let (address, pem, server) = https_fixture_for("reader.invalid").await;
    let client = legado_net::LegadoClient::new(legado_net::LegadoClientConfig {
        no_proxy: true,
        dns_addresses: vec![address.ip()],
        ssl: Some(SslConfig::with_ca(pem)),
        ..Default::default()
    })
    .unwrap();
    let url = format!("https://reader.invalid:{}/", address.port());
    let response = client.get_raw(&url, None).await.unwrap();
    assert_eq!(response.body, b"ok");
    assert_eq!(response.url, url);
    assert!(server.await.unwrap());
}
