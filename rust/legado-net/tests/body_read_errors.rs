//! 用真实截断响应验证正文读取不会丢失底层错误原因。

use std::{error::Error, time::Duration};

use legado_core::LegadoError;
use legado_net::{LegadoClient, LegadoClientConfig, LegadoRequest};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};

enum ReadMode {
    Text,
    Bytes,
    Stream,
}

async fn assert_truncated_body_error(mode: ReadMode) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}/", listener.local_addr().unwrap());
    let server = tokio::spawn(async move {
        // 分别服务原始 reqwest 诊断参照与正式 LegadoClient 入口。
        for _ in 0..2 {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = Vec::new();
            while !request.ends_with(b"\r\n\r\n") {
                let byte = socket.read_u8().await.unwrap();
                request.push(byte);
                assert!(request.len() < 16384, "测试请求头异常");
            }
            socket
                .write_all(
                    b"HTTP/1.1 200 OK\r\nContent-Length: 128\r\nConnection: close\r\n\r\npartial",
                )
                .await
                .unwrap();
            socket.shutdown().await.unwrap();
        }
    });

    let raw_error = legado_net::tls::client_builder()
        .no_proxy()
        .timeout(Duration::from_secs(3))
        .build()
        .unwrap()
        .get(&url)
        .send()
        .await
        .expect("响应头应正常返回")
        .bytes()
        .await
        .expect_err("声明的正文长度不足，不能视作成功");
    let mut cause: &dyn Error = &raw_error;
    while let Some(source) = cause.source() {
        cause = source;
    }
    let root_cause = cause.to_string();
    assert!(!root_cause.is_empty());
    assert_ne!(
        root_cause,
        raw_error.to_string(),
        "夹具必须触发底层读取错误"
    );

    let client = LegadoClient::new(LegadoClientConfig {
        no_proxy: true,
        ..Default::default()
    })
    .unwrap();
    let (error, prefix) = match mode {
        ReadMode::Text => (
            client.get(&url, None).await.unwrap_err(),
            "Failed to read response body: ",
        ),
        ReadMode::Bytes => (
            client.get_raw(&url, None).await.unwrap_err(),
            "Failed to read response bytes: ",
        ),
        ReadMode::Stream => {
            let mut response = client
                .send_stream(&LegadoRequest::get(&url))
                .await
                .expect("流式响应头应正常返回");
            assert_eq!(response.status(), 200);
            let error = loop {
                match response.next_chunk().await {
                    Ok(Some(_)) => continue,
                    Ok(None) => panic!("截断流不能正常结束"),
                    Err(error) => break error,
                }
            };
            (error, "读取响应流失败: ")
        }
    };
    server.await.unwrap();
    let LegadoError::Network(message) = error else {
        panic!("读取失败必须保持 Network 分类: {error:?}");
    };
    assert!(message.starts_with(prefix), "原错误前缀应保持: {message}");
    assert!(
        message.contains(&root_cause),
        "应保留底层原因 {root_cause:?}，实际为 {message:?}"
    );
}

#[tokio::test]
async fn truncated_text_preserves_body_error_cause() {
    tokio::time::timeout(
        Duration::from_secs(10),
        assert_truncated_body_error(ReadMode::Text),
    )
    .await
    .expect("文本读取回归超时");
}

#[tokio::test]
async fn truncated_bytes_preserve_body_error_cause() {
    tokio::time::timeout(
        Duration::from_secs(10),
        assert_truncated_body_error(ReadMode::Bytes),
    )
    .await
    .expect("二进制读取回归超时");
}

#[tokio::test]
async fn truncated_stream_preserves_body_error_cause() {
    tokio::time::timeout(
        Duration::from_secs(10),
        assert_truncated_body_error(ReadMode::Stream),
    )
    .await
    .expect("流式读取回归超时");
}
