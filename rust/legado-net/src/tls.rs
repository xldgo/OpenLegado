//! HTTP 客户端共用 TLS 默认值：保留 ring 与 Mozilla 根证书。
//!
//! reqwest 0.13 默认的平台证书校验需要 Android JVM 接线；当前 Dart FFI
//! 宿主沿用内置根证书，显式保留升级前的校验、自定义 CA 与 unsafeSSL 能力。

use reqwest::{Certificate, Client, ClientBuilder};
use std::sync::OnceLock;

/// 使用现有跨平台证书策略创建客户端构建器。
pub fn client_builder() -> ClientBuilder {
    static ROOTS: OnceLock<Vec<Certificate>> = OnceLock::new();
    // 与 reqwest 0.12 的 ring 后端一致；重复调用不覆盖已安装的 provider。
    let _ = rustls::crypto::ring::default_provider().install_default();
    let roots = ROOTS.get_or_init(|| {
        webpki_root_certs::TLS_SERVER_ROOT_CERTS
            .iter()
            .map(|der| Certificate::from_der(der.as_ref()).expect("内置根证书必须为合法 DER"))
            .collect()
    });
    ClientBuilder::new()
        .tls_backend_rustls()
        .tls_certs_only(roots.iter().cloned())
}

/// 创建默认客户端，与原 reqwest::Client::new 相同，在构建失败时明确报错。
pub fn client() -> Client {
    client_builder().build().expect("HTTP 客户端初始化失败")
}
