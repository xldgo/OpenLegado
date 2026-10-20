//! 图片获取、书源请求头和独立VM解密；不依赖FFI或宿主全局。
use std::collections::HashMap;

use legado_core::LegadoError;
use legado_core::LegadoResult;
use legado_core::models::BookSource;
#[cfg(feature = "quickjs")]
use legado_js::JsEngine;
#[cfg(feature = "quickjs")]
use legado_js::JsValue;
// 默认 Chrome UA（与搜索链路一致，避免图片 CDN 按 UA 拒请求）：
// 引用全仓唯一缺省 UA 常量（FFI 主链路 / JS 桥四池共享，同串防漂移）
use legado_net::client::DEFAULT_USER_AGENT;

/// 解析书源 header 字符串（JSON 对象 或 `key: value` 行）
/// 对齐原版 AnalyzeUrl.headerMap 语义
fn parse_header_map(header: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    let trimmed = header.trim();
    if trimmed.is_empty() {
        return map;
    }
    if trimmed.starts_with('{')
        && let Ok(v) = serde_json::from_str::<serde_json::Value>(trimmed)
        && let Some(obj) = v.as_object()
    {
        for (k, val) in obj {
            map.insert(k.clone(), val.as_str().unwrap_or_default().to_string());
        }
        return map;
    }
    for line in trimmed.lines() {
        if let Some(idx) = line.find(':') {
            let k = line[..idx].trim();
            let v = line[idx + 1..].trim();
            if !k.is_empty() {
                map.insert(k.to_string(), v.to_string());
            }
        }
    }
    map
}

/// 书源主页默认 Referer（对齐图片防盗链兜底）
///
/// 无尾斜杠纯域名（如 `https://site.com`）不得 `rsplitn('/')` 截成 `https:`。
fn default_referer_from_source_url(book_source_url: &str) -> Option<String> {
    let url = book_source_url.trim();
    if url.is_empty() {
        return None;
    }
    if url.ends_with('/') {
        return Some(url.to_string());
    }
    // 无路径：整段 URL + /
    if let Some(scheme_end) = url.find("://")
        && !url[scheme_end + 3..].contains('/')
    {
        return Some(format!("{url}/"));
    }
    // 有路径：去掉最后一段，保留目录尾斜杠
    if let Some(pos) = url.rfind('/') {
        let origin = &url[..=pos];
        if origin.contains("://") {
            return Some(origin.to_string());
        }
    }
    Some(format!("{}/", url.trim_end_matches('/')))
}

/// 解析复合图片 URL（`url,{json headers}`）：返回真实 URL 与内嵌 headers
///
/// 对齐原版 AnalyzeUrl.kt analyzeUrl 语义：切首个 `,` 前为 URL，后部
/// JSON（`{"headers":{...}}` 或扁平 `{...}`）解析为请求头。
/// 无 `,{` 复合段时原样返回 URL 与空 headers — Reasonix
fn split_composite_image_url(url: &str) -> (String, HashMap<String, String>) {
    if let Some(comma_pos) = url.find(',') {
        let after = url[comma_pos + 1..].trim();
        if after.starts_with('{') && after.ends_with('}') {
            let analyzed = legado_parser::AnalyzeUrl::new(url, None, None, "", None);
            let parsed_url = analyzed.url().to_string();
            if !parsed_url.is_empty() {
                let headers = analyzed
                    .headers()
                    .iter()
                    .map(|(k, v)| (k.clone(), v.clone()))
                    .collect::<HashMap<String, String>>();
                return (parsed_url, headers);
            }
        }
    }
    (url.to_string(), HashMap::new())
}

/// JPEG/PNG/GIF/WEBP 魔数探测（漫画页几乎只用这些）
fn looks_like_image_bytes(bytes: &[u8]) -> bool {
    if bytes.len() < 4 {
        return false;
    }
    if bytes.starts_with(&[0xFF, 0xD8]) {
        return true; // JPEG
    }
    if bytes.starts_with(&[0x89, 0x50, 0x4E, 0x47]) {
        return true; // PNG
    }
    if bytes.starts_with(b"GIF8") {
        return true; // GIF
    }
    if bytes.len() >= 12 && &bytes[0..4] == b"RIFF" && &bytes[8..12] == b"WEBP" {
        return true; // WEBP
    }
    false
}

/// 图片业务只持有JS能力；网络和调度器由每次调用明确提供。
pub struct ImageService {
    js: std::sync::Arc<legado_js::JsResources>,
}
impl ImageService {
    pub fn new(js: std::sync::Arc<legado_js::JsResources>) -> Self {
        Self { js }
    }
    /// 对图片 bytes 执行 imageDecode（若书源配置了该规则）
    ///
    /// bindings 对齐原版 `source.evalJS(ruleJs) { put("result", inputStream); put("src", src) }`
    /// result = 图片 bytes（Uint8Array），src = 图片 URL。
    /// - 无 imageDecode → 原样返回
    /// - 有 imageDecode：每次新建引擎执行（对齐规则路径 v2.0.24，不用 pool）
    /// - jsLib 可选：有则先 eval，失败 eprintln 后仍尝试 decode（勿静默假成功掩盖）
    /// - decode 失败/空结果 → eprintln 可观测，回退原图
    pub fn decode_image_bytes(&self, source: &BookSource, img_url: &str, bytes: &[u8]) -> Vec<u8> {
        let Some(rule) = source
            .rule_content
            .as_ref()
            .and_then(|c| c.image_decode.clone())
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
        else {
            return bytes.to_vec();
        };

        let js_lib = source
            .js_lib
            .clone()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());

        #[cfg(feature = "quickjs")]
        {
            // P2-19：绑定当前书源 tag（对齐 pay_action_api / source_login_v2_api /
            // source_callback_api 同款加法式包裹，不改签名）：imageDecode 规则与
            // jsLib 内可出现 `java.ajax(source.key + "/k")` 等请求，Cookie 头按
            // 当前书源过滤——不绑定则落入「未归属上下文」，本源自己的 cookie
            // 也不携带（回归面：P2-19 修前 all_cookies() 全量合并至少还带着本源）。
            legado_js::host_api::current_source::with_current_source_tag(
                &source.book_source_url,
                || {
                    // 每次新建引擎：同源多图连续 decode 时顶层 const/let 不会 redeclaration
                    let engine = match self.js.create_engine(
                        legado_js::sandbox::SandboxConfig::default().with_allow_script_run(true),
                    ) {
                        Ok(e) => e,
                        Err(e) => {
                            eprintln!(
                                "[legado-ffi] imageDecode 引擎创建失败（回退原图）: {e} url={img_url}"
                            );
                            return bytes.to_vec();
                        }
                    };

                    if let Some(lib) = js_lib.as_deref()
                        && let Err(e) = JsEngine::eval(&engine, lib)
                    {
                        // 降级继续：部分书源混淆 jsLib 依赖 Rhino Packages，但仍可能仅靠
                        // imageDecode 内联逻辑；失败必须可观测，勿静默当成功
                        eprintln!(
                            "[legado-ffi] imageDecode jsLib 加载失败（降级继续 decode）: {e} source={}",
                            source.book_source_url
                        );
                    }

                    match JsEngine::eval_bytes(
                        &engine,
                        &rule,
                        &[
                            ("result", JsValue::Bytes(bytes.to_vec())),
                            ("src", JsValue::String(img_url.to_string())),
                        ],
                    ) {
                        Ok(decoded) if !decoded.is_empty() => decoded,
                        Ok(_) => {
                            eprintln!(
                                "[legado-ffi] imageDecode 返回空字节（回退原图）url={img_url}"
                            );
                            bytes.to_vec()
                        }
                        Err(e) => {
                            eprintln!(
                                "[legado-ffi] imageDecode 执行失败（回退原图）: {e} url={img_url}"
                            );
                            bytes.to_vec()
                        }
                    }
                },
            )
        }

        #[cfg(not(feature = "quickjs"))]
        {
            let _ = (&self.js, rule, js_lib, img_url);
            eprintln!("[legado-ffi] imageDecode 需要 quickjs feature（回退原图）");
            bytes.to_vec()
        }
    }

    /// 下载图片（带书源 header 防盗链）并按 imageDecode 解码，返回原始字节
    ///
    /// 无 imageDecode 时返回原始图片字节；宿主负责书源文档解析。
    ///
    /// 支持原版 `url,{json headers}` 复合格式（favcomic 等漫画站图片 URL 内嵌
    /// 防盗链 header，对齐原版 AnalyzeUrl.kt analyzeUrl 切首个 `,` 前为 URL、
    /// 后部解析为 headerMap）：URL 含 `,{...}` 时经 [`split_composite_image_url`]
    /// 拆分，内嵌 headers 与书源 header 合并后请求 — Reasonix
    pub fn fetch_image_with_decode(
        &self,
        url: &str,
        source: &BookSource,
        network: &crate::NetworkContext,
        runtime: &tokio::runtime::Handle,
    ) -> LegadoResult<Vec<u8>> {
        // 解析复合 URL（url,{json headers}）：拆分出真实 URL 与内嵌 headers
        let (request_url, embedded_headers) = split_composite_image_url(url);

        // 构造请求头：书源 header（Referer 等）+ 内嵌 header + 默认 UA
        let mut headers: HashMap<String, String> = source
            .header
            .as_deref()
            .map(parse_header_map)
            .unwrap_or_default();
        // 内嵌 header 优先级最高（书源规则显式指定的防盗链）
        headers.extend(embedded_headers);
        if !headers.contains_key("User-Agent") && !headers.contains_key("user-agent") {
            headers.insert("User-Agent".to_string(), DEFAULT_USER_AGENT.to_string());
        }
        // 图片防盗链：无 Referer 时以书源主页兜底（对齐原版 ImageLoader referer）
        if !headers.contains_key("Referer")
            && !headers.contains_key("referer")
            && let Some(referer) = default_referer_from_source_url(&source.book_source_url)
        {
            headers.insert("Referer".to_string(), referer);
        }
        // 写侧 CookieJar 门控（批 2）：开启源补内部标记头（只补不覆盖；
        // 发送前由 legado-net 剥离、绝不出网）；读侧 cookie 注入不受影响。
        legado_fetcher::web_book::apply_cookie_jar_marker(&mut headers, source);

        let resp = runtime.block_on(async {
            let client = network.client()?;
            client.get_raw(&request_url, Some(headers)).await
        })?;
        if !resp.is_success() {
            return Err(LegadoError::Network(format!(
                "图片下载失败: HTTP {}",
                resp.status
            )));
        }
        let bytes = resp.body;

        // src 绑定对齐原版：传入完整（可能含复合 header 段）原始 URL
        let decoded = self.decode_image_bytes(source, url, &bytes);
        // 有 imageDecode 时：解密结果必须是可识别图片，禁止把密文当成功回传
        // （否则 Flutter Image.memory → Invalid image data / Decoder 刷屏）— Reasonix
        let has_decode_rule = source
            .rule_content
            .as_ref()
            .and_then(|c| c.image_decode.as_ref())
            .map(|s| !s.trim().is_empty())
            .unwrap_or(false);
        if has_decode_rule && !looks_like_image_bytes(&decoded) {
            return Err(LegadoError::Ffi(format!(
                "imageDecode 后仍非有效图片（len={} magic={:02X?}），请检查 java.createSymmetricCrypto/解密规则 url={request_url}",
                decoded.len(),
                decoded.iter().take(4).copied().collect::<Vec<_>>()
            )));
        }
        Ok(decoded)
    }
}

#[cfg(test)]
mod tests;
