//! 词典/封面共享取体：保留data URI、Cookie门控与既有请求选项。
use legado_parser::AnalyzeUrl;
use std::collections::HashMap;

pub(crate) async fn fetch_body(
    network: &crate::NetworkContext,
    analyze_url: &AnalyzeUrl,
    cookie_jar_enabled: Option<bool>,
) -> Result<String, String> {
    // data: URI（如百度汉语规则的 data:;base64,{{...}}）无需网络
    if analyze_url.is_data_uri() {
        return analyze_url
            .get_byte_array_if_data_uri()
            .map(|bytes| String::from_utf8_lossy(&bytes).into_owned())
            .ok_or_else(|| "data: URI 解码失败".to_string());
    }

    let url = analyze_url.url();
    if url.is_empty() {
        return Err("AnalyzeUrl 解析后 URL 为空".to_string());
    }

    let client = network.client().map_err(|e| e.to_string())?;
    let headers = compose_fetch_headers(analyze_url, cookie_jar_enabled);

    // P2-19 批3：urlOption followRedirects / retry 经 fetcher 汇聚点发送
    //（文本路径；method 仍由 AnalyzeUrl 决定，语义与改前一致）
    let response = legado_fetcher::analyze_request::send_text(&client, analyze_url, headers)
        .await
        .map_err(|e| format!("网络请求失败: {e}"))?;
    if !response.is_success() {
        return Err(format!("HTTP {}", response.status));
    }
    Ok(response.body)
}

fn compose_fetch_headers(
    analyze_url: &AnalyzeUrl,
    cookie_jar_enabled: Option<bool>,
) -> Option<HashMap<String, String>> {
    let mut headers = analyze_url.headers().clone();
    // 写侧门控（批 2 残差接线）：`Some(true)` 补内部标记头，发送前由
    // legado-net 剥离（绝不出网）；None/false 按关。
    legado_fetcher::web_book::apply_cookie_jar_marker_by_flag(&mut headers, cookie_jar_enabled);
    if headers.is_empty() {
        None
    } else {
        Some(headers)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_compose_fetch_headers_cookie_jar_gate() {
        let plain = AnalyzeUrl::parse("http://example.com/x", &HashMap::new(), 1).unwrap();
        assert!(compose_fetch_headers(&plain, None).is_none());
        assert!(compose_fetch_headers(&plain, Some(false)).is_none());

        let headers = compose_fetch_headers(&plain, Some(true)).expect("Some(true) 应产出标记头");
        assert_eq!(
            headers
                .get(legado_net::COOKIE_JAR_HEADER)
                .map(String::as_str),
            Some("1")
        );

        // 规则 headers 保留 + 标记追加
        let with_rule = AnalyzeUrl::parse(
            r#"http://example.com/x,{"headers":{"X-Test":"1"}}"#,
            &HashMap::new(),
            1,
        )
        .unwrap();
        let headers = compose_fetch_headers(&with_rule, None).unwrap();
        assert_eq!(headers.get("X-Test").map(String::as_str), Some("1"));
        let headers = compose_fetch_headers(&with_rule, Some(true)).unwrap();
        assert_eq!(headers.get("X-Test").map(String::as_str), Some("1"));
        assert_eq!(
            headers
                .get(legado_net::COOKIE_JAR_HEADER)
                .map(String::as_str),
            Some("1")
        );

        // 同名键只补不覆盖（跟随上游同名机制）
        let same_name = AnalyzeUrl::parse(
            r#"http://example.com/x,{"headers":{"CookieJar":"rule"}}"#,
            &HashMap::new(),
            1,
        )
        .unwrap();
        let headers = compose_fetch_headers(&same_name, Some(true)).unwrap();
        assert_eq!(
            headers
                .get(legado_net::COOKIE_JAR_HEADER)
                .map(String::as_str),
            Some("rule")
        );
    }
}
