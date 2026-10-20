//! HTTP TTS 语音合成请求管线（legado-fetcher 层）
//!
//! 对照上游 `HapeLee/legado-with-MD3` 的 `HttpReadAloudService.kt`（L1388-1422）与 `AnalyzeUrl.kt`：
//! 1. 建立基于 `HttpTtsConfig` 与 `TtsSpeakContext` 的 TTS 请求执行管线。
//! 2. 注入正文/源级语速、音色 ID/名称及 `currentEmotionName` / `currentEmotionTag`。
//! 3. 使用 `AnalyzeUrl::parse_with_js` 解析 URL 模板、`@Header`、`@Body`、POST/GET 方法及内嵌 JS 表达式。
//! 4. 组装源级 `header` 与 urlOption 请求头并发送请求（支持 CookieJar 门控）。
//! 5. Content-Type 校验：`application/json` 或以 `text/` 开头视为错误上抛，并校验 `http_tts.content_type` 正则。
//! 6. 完整配置与合成上下文经结构化序列化生成缓存键，命中时复用本地音频。

use crate::rate_limit::RateLimiterRegistry;
use crate::tts_control::{TtsCancellation, synthesis_lock};
use crate::tts_response::evaluate_tts_response;
#[cfg(feature = "quickjs")]
use crate::tts_response::evaluate_tts_response_with_headers;
use crate::tts_source::{
    TtsJsExecutor, TtsSourceStore, default_store, merge_headers, source_headers,
};
use legado_parser::JsExecutor;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock};
#[cfg(test)]
use std::time::Duration;

use regex::Regex;
use serde::{Deserialize, Serialize};

use legado_core::tts_speak::{SpeakCache, ext_from_content_type, is_error_content_type};
use legado_core::{LegadoError, LegadoResult};
use legado_net::LegadoClient;
#[cfg(all(test, feature = "quickjs"))]
use legado_net::LegadoRawResponse;
use legado_parser::AnalyzeUrl;

/// TTS 朗读请求上下文
#[derive(Debug, Clone)]
pub struct TtsSpeakContext<'a> {
    /// 朗读正文
    pub speak_text: &'a str,
    /// 朗读源级语速刻度（整数），按上游规则计算为 `(http_tts.speed ?? 5) + 5`
    pub speak_speed: i32,
    /// 音色 ID（可选）
    pub tone_id: Option<&'a str>,
    /// 发音人名称（可选）
    pub speaker_name: Option<&'a str>,
    /// 情感标签（可选）
    pub emotion_tag: Option<&'a str>,
    /// 目录映射后的情感名称，由所属合成操作注入。
    pub emotion_name: Option<&'a str>,
}

impl<'a> TtsSpeakContext<'a> {
    pub fn new(
        speak_text: &'a str,
        speak_speed: i32,
        tone_id: Option<&'a str>,
        speaker_name: Option<&'a str>,
        emotion_tag: Option<&'a str>,
    ) -> Self {
        Self {
            speak_text,
            speak_speed,
            tone_id,
            speaker_name,
            emotion_tag,
            emotion_name: None,
        }
    }

    /// 构建 AnalyzeUrl 所需变量字典（对齐上游 AnalyzeUrl）
    pub fn build_variables(&self) -> HashMap<String, String> {
        let mut vars = HashMap::new();
        vars.insert("speakText".to_string(), self.speak_text.to_string());
        vars.insert("text".to_string(), self.speak_text.to_string());
        vars.insert("speakSpeed".to_string(), self.speak_speed.to_string());
        vars.insert("speed".to_string(), self.speak_speed.to_string());
        vars.insert(
            "currentToneID".to_string(),
            self.tone_id.unwrap_or("").to_string(),
        );
        vars.insert(
            "currentSpeakerName".to_string(),
            self.speaker_name.unwrap_or("").to_string(),
        );
        vars.insert(
            "currentEmotionTag".to_string(),
            self.emotion_tag.unwrap_or("").to_string(),
        );
        vars.insert(
            "currentEmotionName".to_string(),
            self.emotion_name.unwrap_or("").to_string(),
        );
        vars
    }
}

/// HTTP TTS 源级配置模型（仅包含 fetcher 请求所需字段）
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct HttpTtsConfig {
    #[serde(default)]
    pub id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub header: Option<String>,
    #[serde(default)]
    pub content_type: Option<String>,
    #[serde(default)]
    pub js_lib: Option<String>,
    #[serde(default)]
    pub speed: Option<i32>,
    #[serde(default)]
    pub enabled_cookie_jar: Option<bool>,
    #[serde(default)]
    pub concurrent_rate: Option<String>,
    #[serde(default)]
    pub login_url: Option<String>,
    #[serde(default)]
    pub login_ui: Option<String>,
    #[serde(default)]
    pub login_check_js: Option<String>,
}

impl HttpTtsConfig {
    pub fn source_key(&self) -> String {
        format!("httpTts:{}", self.id)
    }

    /// 计算源级生效语速刻度：`(speed ?? 5) + 5`
    pub fn effective_speed(&self) -> i32 {
        self.speed.unwrap_or(5) + 5
    }
}

/// TTS 合成拉取产物
#[derive(Debug, Clone)]
pub struct TtsFetchResult {
    /// 本地音频文件绝对路径
    pub audio_path: PathBuf,
    /// 是否命中本地缓存
    pub from_cache: bool,
    /// 音频 MIME 类型（如 `audio/mpeg`）
    pub content_type: String,
}

/// 基于配置与请求上下文计算缓存键
pub fn tts_cache_key_from_context(config: &HttpTtsConfig, context: &TtsSpeakContext<'_>) -> String {
    // 配置与实际合成输入一起入键；修改 jsLib 或响应校验配置后必须重新合成。
    let input = serde_json::json!([
        config,
        context.speak_text,
        context.speak_speed,
        context.tone_id,
        context.speaker_name,
        context.emotion_tag,
        context.emotion_name
    ]);
    legado_core::crypto::md5_hex(input.to_string().as_bytes())
}

/// 解析 TTS URL 模板为 AnalyzeUrl（支持可选 JS 执行器）
pub fn parse_tts_analyze_url_with_executor(
    template: &str,
    variables: &HashMap<String, String>,
    source_tag: &str,
    js_lib: Option<&str>,
    custom_executor: Option<&dyn legado_parser::JsExecutor>,
) -> LegadoResult<AnalyzeUrl> {
    if let Some(exec) = custom_executor {
        AnalyzeUrl::parse_with_js(template, variables, 1, exec)
    } else {
        #[cfg(feature = "quickjs")]
        {
            let executor = legado_js::executor::QuickJsExecutor::new(source_tag)
                .with_js_lib(js_lib.map(|s| s.to_string()));
            AnalyzeUrl::parse_with_js(template, variables, 1, &executor)
        }
        #[cfg(not(feature = "quickjs"))]
        {
            let _ = (source_tag, js_lib);
            AnalyzeUrl::parse(template, variables, 1)
        }
    }
}

/// 执行 HTTP TTS 语音合成请求
///
/// 流程：
/// 1. 朗读文本校验；
/// 2. 检查本地 `SpeakCache`，命中则直接返回；
/// 3. 解析 URL 模板（变量替换、内嵌 JS、@Header、@Body、POST/GET、urlOption）；
/// 4. 组装请求头并发送 HTTP 请求（300s 超时保护）；
/// 5. 校验响应状态码与 Content-Type（针对 json/text 抛出错误消息，并校验 content_type 正则）；
/// 6. 写入本地缓存文件并返回音频路径。
pub async fn fetch_tts_audio(
    client: &LegadoClient,
    config: &HttpTtsConfig,
    context: &TtsSpeakContext<'_>,
    cache_dir: &Path,
) -> LegadoResult<TtsFetchResult> {
    fetch_tts_audio_with_executor(client, config, context, cache_dir, None).await
}

/// 带自定义 JS 执行器的 HTTP TTS 合成入口（用于测试或特殊宿主注入）
pub async fn fetch_tts_audio_with_executor(
    client: &LegadoClient,
    config: &HttpTtsConfig,
    context: &TtsSpeakContext<'_>,
    cache_dir: &Path,
    custom_executor: Option<&dyn legado_parser::JsExecutor>,
) -> LegadoResult<TtsFetchResult> {
    static RATES: OnceLock<Arc<RateLimiterRegistry>> = OnceLock::new();
    fetch_tts_audio_controlled(
        client,
        config,
        context,
        cache_dir,
        custom_executor,
        TtsFetchResources {
            store: default_store(),
            rates: RATES
                .get_or_init(|| Arc::new(RateLimiterRegistry::new()))
                .clone(),
        },
        &TtsCancellation::default(),
    )
    .await
}

/// 宿主注入登录存储、共享限流表和独立请求取消句柄。
pub struct TtsFetchResources {
    pub store: Arc<dyn TtsSourceStore>,
    pub rates: Arc<RateLimiterRegistry>,
}
pub async fn fetch_tts_audio_controlled(
    client: &LegadoClient,
    config: &HttpTtsConfig,
    context: &TtsSpeakContext<'_>,
    cache_dir: &Path,
    custom_executor: Option<&dyn JsExecutor>,
    resources: TtsFetchResources,
    cancellation: &TtsCancellation,
) -> LegadoResult<TtsFetchResult> {
    cancellation
        .run(fetch_tts_audio_inner(
            client,
            config,
            context,
            cache_dir,
            custom_executor,
            resources,
            cancellation,
        ))
        .await
}
async fn fetch_tts_audio_inner(
    client: &LegadoClient,
    config: &HttpTtsConfig,
    context: &TtsSpeakContext<'_>,
    cache_dir: &Path,
    custom_executor: Option<&dyn JsExecutor>,
    resources: TtsFetchResources,
    cancellation: &TtsCancellation,
) -> LegadoResult<TtsFetchResult> {
    let TtsFetchResources { store, rates } = resources;
    let text = context.speak_text.trim();
    if text.is_empty() {
        return Err(LegadoError::ContentEmpty("朗读文本为空".into()));
    }

    // 1. 本地缓存检查
    let cache = SpeakCache::new(cache_dir.to_path_buf());
    let cache_key = runtime_cache_key(config, context, store.as_ref())?;
    let lock = synthesis_lock(cache_dir.to_path_buf(), cache_key.clone());
    let _guard = lock.lock().await;
    cancellation.check()?;
    if let Some(path) = cache.get(&cache_key) {
        let ext = path
            .extension()
            .map(|e| e.to_string_lossy().to_string())
            .unwrap_or_else(|| "mp3".to_string());
        return Ok(TtsFetchResult {
            audio_path: path,
            from_cache: true,
            content_type: legado_core::tts_speak::content_type_from_ext(&ext).to_string(),
        });
    }

    // 2. 解析 URL 规则与内嵌 JS
    let vars = context.build_variables();
    let tts_executor = TtsJsExecutor::new(config, store.clone());
    let executor: &dyn JsExecutor = custom_executor.unwrap_or(&tts_executor);
    let mut headers = source_headers(config, executor, store.as_ref())?;
    #[cfg(feature = "quickjs")]
    store
        .http_resources()
        .put_headers(&config.source_key(), headers.clone());
    let analyze_url = if cfg!(feature = "quickjs") || custom_executor.is_some() {
        AnalyzeUrl::parse_with_js(&config.url, &vars, 1, executor)?
    } else {
        AnalyzeUrl::parse(&config.url, &vars, 1)?
    };
    cancellation.check()?;
    // URL 规则可以登录并写入新 Header，发请求前重新读回。
    if let Some(login) = store
        .load(&config.source_key())?
        .get("loginHeader")
        .filter(|v| !v.trim().is_empty())
    {
        merge_headers(
            &mut headers,
            serde_json::from_str(login)
                .map_err(|_| LegadoError::Parser("TTS 登录 Header JSON 无效".into()))?,
        );
    }
    merge_headers(&mut headers, analyze_url.headers().clone());
    crate::web_book::apply_cookie_jar_marker_by_flag(&mut headers, config.enabled_cookie_jar);
    let headers_opt = if headers.is_empty() {
        None
    } else {
        Some(headers)
    };

    // 4. 发起 HTTP 请求（300s 超时保护）
    let mut resp = crate::tts_transport::send_tts_request(
        client,
        config,
        &analyze_url,
        headers_opt.clone(),
        store.as_ref(),
        rates.as_ref(),
        cancellation,
    )
    .await?;
    cancellation.check()?;
    if let Some(check) = config
        .login_check_js
        .as_deref()
        .filter(|s| !s.trim().is_empty())
    {
        if custom_executor.is_some() {
            resp = evaluate_tts_response(executor, check, resp)?;
        } else {
            #[cfg(feature = "quickjs")]
            {
                let config = config.clone();
                let store = store.clone();
                let client = client.clone();
                let rates = rates.clone();
                let vars = vars.clone();
                let original_url = analyze_url.clone();
                let headers = headers_opt.clone().unwrap_or_default();
                let cancellation = cancellation.clone();
                let script = check.to_string();
                let variables = tts_executor.variables();
                resp=tokio::task::spawn_blocking(move || {
                    let request_headers=headers.clone();
                    let load_store=store.clone();
                    let load_config=config.clone();
                    let load_variables=variables.clone();
                    let loader=Arc::new(move |payload:&str| -> Result<String,String> {
                        let input:serde_json::Value=serde_json::from_str(payload).map_err(|e|e.to_string())?;
                        load_store.apply(&load_config.source_key(),serde_json::from_value(input["changes"].clone()).map_err(|e|e.to_string())?).map_err(|e|e.to_string())?;
                        let executor=TtsJsExecutor::new(&load_config,load_store.clone()).with_variables(load_variables.clone());
                        let mut next_headers:HashMap<String,String>=serde_json::from_value(input["headers"].clone()).map_err(|e|e.to_string())?;
                        let url=if input["reinit"].as_bool()==Some(true) {
                            AnalyzeUrl::parse_with_js(&load_config.url,&vars,1,&executor).map_err(|e|e.to_string())?
                        } else {original_url.clone()};
                        merge_headers(&mut next_headers,url.headers().clone());
                        crate::web_book::apply_cookie_jar_marker_by_flag(&mut next_headers,load_config.enabled_cookie_jar);
                        let response=legado_js::host_api::runtime_bridge::get_runtime().block_on(
                            crate::tts_transport::send_tts_request(&client,&load_config,&url,Some(next_headers),load_store.as_ref(),rates.as_ref(),&cancellation)
                        ).map_err(|e|e.to_string())?;
                        Ok(serde_json::json!({"status":response.status,"headers":response.headers,"body":response.body,"url":response.url}).to_string())
                    });
                    let executor=TtsJsExecutor::new(&config,store).with_variables(variables).with_response_loader(loader);
                    evaluate_tts_response_with_headers(&executor,&script,resp,&request_headers)
                }).await.map_err(|e|LegadoError::JsEngine(format!("TTS 响应脚本任务失败：{e}")))??;
            }
            #[cfg(not(feature = "quickjs"))]
            {
                return Err(LegadoError::JsEngine(
                    "此构建未启用 QuickJS，无法执行 TTS 响应脚本".into(),
                ));
            }
        }
    }
    cancellation.check()?;

    // 5. 校验响应状态码
    if !(200..300).contains(&resp.status) {
        return Err(LegadoError::Network(format!(
            "TTS 服务器返回错误状态码: {}",
            resp.status
        )));
    }
    if resp.body.is_empty() {
        return Err(LegadoError::Network("TTS 服务器返回空音频".into()));
    }

    // 6. Content-Type 校验
    let raw_content_type = resp.content_type().cloned().unwrap_or_else(|| {
        resp.headers
            .get("content-type")
            .or_else(|| resp.headers.get("Content-Type"))
            .cloned()
            .unwrap_or_default()
    });

    if is_error_content_type(&raw_content_type) {
        let msg = String::from_utf8_lossy(&resp.body);
        let msg = msg.trim();
        let msg = if msg.chars().count() > 500 {
            msg.chars().take(500).collect::<String>()
        } else {
            msg.to_string()
        };
        return Err(LegadoError::Network(format!("TTS 服务器返回错误：{}", msg)));
    }

    // 上游在完整正则匹配前去除 MIME 参数；charset 等参数不属于音频类型。
    let mime_type = raw_content_type.split(';').next().unwrap_or("").trim();

    if let Some(ref pattern) = config.content_type {
        let pattern = pattern.trim();
        if !pattern.is_empty() {
            let re = Regex::new(&format!("\\A(?:{pattern})\\z")).map_err(|e| {
                LegadoError::Internal(format!("无效的 Content-Type 正则表达式: {e}"))
            })?;
            if !re.is_match(mime_type) {
                return Err(LegadoError::Network(format!(
                    "TTS 响应 Content-Type '{}' 不匹配预期正则 '{}'",
                    raw_content_type, pattern
                )));
            }
        }
    }

    // 7. 写入本地缓存并返回
    let ext = ext_from_content_type(&raw_content_type);
    cancellation.check()?;
    let final_key = runtime_cache_key(config, context, store.as_ref())?;
    let mut audio_path = None;
    store.publish(&mut || {
        cancellation.check()?;
        audio_path = Some(cache.put(&final_key, ext, &resp.body)?);
        Ok(())
    })?;
    let audio_path =
        audio_path.ok_or_else(|| LegadoError::Internal("TTS 缓存发布未产生文件".into()))?;
    let clean_ct = raw_content_type
        .split(';')
        .next()
        .unwrap_or("audio/mpeg")
        .trim()
        .to_string();
    let clean_ct = if clean_ct.is_empty() {
        "audio/mpeg".to_string()
    } else {
        clean_ct
    };

    Ok(TtsFetchResult {
        audio_path,
        from_cache: false,
        content_type: clean_ct,
    })
}

fn runtime_cache_key(
    config: &HttpTtsConfig,
    context: &TtsSpeakContext<'_>,
    store: &dyn TtsSourceStore,
) -> LegadoResult<String> {
    let key = tts_cache_key_from_context(config, context);
    let values = store.load(&config.source_key())?;
    if values.is_empty() {
        return Ok(key);
    }
    Ok(legado_core::crypto::md5_hex(
        serde_json::json!([key, values]).to_string().as_bytes(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::SocketAddr;
    use std::sync::Arc;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;
    use tokio::sync::Mutex;

    #[derive(Debug, Clone, Default)]
    struct RecordedRequest {
        method: String,
        uri: String,
        headers: HashMap<String, String>,
        body: Vec<u8>,
    }

    async fn spawn_test_tts_server<F>(handler: F) -> (SocketAddr, Arc<Mutex<Vec<RecordedRequest>>>)
    where
        F: Fn(&RecordedRequest) -> (u16, &'static str, Vec<u8>) + Send + Sync + 'static,
    {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let records = Arc::new(Mutex::new(Vec::new()));
        let records_clone = Arc::clone(&records);
        let handler = Arc::new(handler);

        tokio::spawn(async move {
            while let Ok((mut sock, _)) = listener.accept().await {
                let handler = Arc::clone(&handler);
                let records = Arc::clone(&records_clone);
                tokio::spawn(async move {
                    let mut buf = Vec::new();
                    let head_end = loop {
                        let mut chunk = [0u8; 1024];
                        let n = match sock.read(&mut chunk).await {
                            Ok(0) | Err(_) => return,
                            Ok(n) => n,
                        };
                        buf.extend_from_slice(&chunk[..n]);
                        if let Some(pos) = buf.windows(4).position(|w| w == b"\r\n\r\n") {
                            break pos;
                        }
                    };
                    let head_str = String::from_utf8_lossy(&buf[..head_end]);
                    let mut lines = head_str.lines();
                    let first_line = lines.next().unwrap_or("");
                    let mut parts = first_line.split_whitespace();
                    let method = parts.next().unwrap_or("GET").to_string();
                    let uri = parts.next().unwrap_or("/").to_string();

                    let mut headers = HashMap::new();
                    let mut content_length = 0usize;
                    for line in lines {
                        if let Some((k, v)) = line.split_once(':') {
                            let k_clean = k.trim().to_lowercase();
                            let v_clean = v.trim().to_string();
                            if k_clean == "content-length" {
                                content_length = v_clean.parse().unwrap_or(0);
                            }
                            headers.insert(k_clean, v_clean);
                        }
                    }

                    let mut body = buf[head_end + 4..].to_vec();
                    while body.len() < content_length {
                        let mut chunk = [0u8; 1024];
                        let n = match sock.read(&mut chunk).await {
                            Ok(0) | Err(_) => break,
                            Ok(n) => n,
                        };
                        body.extend_from_slice(&chunk[..n]);
                    }

                    let req = RecordedRequest {
                        method,
                        uri,
                        headers,
                        body,
                    };

                    let (status, ct, resp_body) = handler(&req);
                    records.lock().await.push(req);

                    let response = format!(
                        "HTTP/1.1 {} OK\r\nContent-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                        status,
                        ct,
                        resp_body.len()
                    );
                    sock.write_all(response.as_bytes()).await.ok();
                    sock.write_all(&resp_body).await.ok();
                    sock.flush().await.ok();
                });
            }
        });

        (addr, records)
    }

    fn temp_test_cache_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "legado_tts_fetcher_test_{}_{}_{}",
            tag,
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).ok();
        dir
    }

    // 场景 1：GET 请求占位符与变量替换（?text={{speakText}}&speed={{speakSpeed}}）
    #[tokio::test]
    async fn test_tts_fixture_get_placeholders() {
        let (addr, records) =
            spawn_test_tts_server(|_req| (200, "audio/mpeg", b"AUDIO_BYTES_GET".to_vec())).await;

        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("get");
        let config = HttpTtsConfig {
            id: 1,
            name: "TestGetEngine".into(),
            url: format!(
                "http://{}/tts?text={{{{speakText}}}}&speed={{{{speakSpeed}}}}",
                addr
            ),
            speed: Some(3),
            ..Default::default()
        };
        let context = TtsSpeakContext::new(
            "测试GET朗读",
            config.effective_speed(), // (3) + 5 = 8
            None,
            None,
            None,
        );

        // 第一次请求：触网拉取并落盘
        let result = fetch_tts_audio(&client, &config, &context, &cache_dir)
            .await
            .unwrap();
        assert!(!result.from_cache);
        assert_eq!(result.content_type, "audio/mpeg");
        assert!(result.audio_path.exists());
        let saved_bytes = std::fs::read(&result.audio_path).unwrap();
        assert_eq!(saved_bytes, b"AUDIO_BYTES_GET");

        // 验证收到的请求
        let reqs = records.lock().await;
        assert_eq!(reqs.len(), 1);
        assert_eq!(reqs[0].method, "GET");
        assert!(reqs[0].uri.contains("speed=8"));
        // 中文字符被正确编码
        assert!(reqs[0].uri.contains("text="));

        // 第二次请求：命中缓存，免网络请求
        drop(reqs);
        let result2 = fetch_tts_audio(&client, &config, &context, &cache_dir)
            .await
            .unwrap();
        assert!(result2.from_cache);
        assert_eq!(result2.audio_path, result.audio_path);
        let reqs2 = records.lock().await;
        assert_eq!(reqs2.len(), 1); // 仍只有 1 次网络请求

        std::fs::remove_dir_all(&cache_dir).ok();
    }

    // 场景 2：POST + JSON Body 模板（@Body:{"text": "{{speakText}}", "rate": {{speakSpeed}}}）
    #[tokio::test]
    async fn test_tts_fixture_post_json_body() {
        let (addr, records) =
            spawn_test_tts_server(|_req| (200, "audio/wav", b"RIFF_FAKE_WAV_BYTES".to_vec())).await;

        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("post");
        let config = HttpTtsConfig {
            id: 2,
            name: "TestPostEngine".into(),
            url: format!(
                "http://{}/api/tts @Body:{{\"text\": \"{{{{speakText}}}}\", \"rate\": {{{{speakSpeed}}}}}}",
                addr
            ),
            speed: Some(5),
            ..Default::default()
        };
        let context = TtsSpeakContext::new("测试POST主体", 10, None, None, None);

        let result = fetch_tts_audio(&client, &config, &context, &cache_dir)
            .await
            .unwrap();
        assert!(!result.from_cache);
        assert_eq!(result.content_type, "audio/wav");
        assert!(
            result
                .audio_path
                .extension()
                .map(|e| e == "wav")
                .unwrap_or(false)
        );

        let reqs = records.lock().await;
        assert_eq!(reqs.len(), 1);
        assert_eq!(reqs[0].method, "POST");
        assert_eq!(reqs[0].uri, "/api/tts");
        let body_str = String::from_utf8_lossy(&reqs[0].body);
        let json_val: serde_json::Value = serde_json::from_str(&body_str).unwrap();
        assert_eq!(json_val["text"], "测试POST主体");
        assert_eq!(json_val["rate"], 10);

        std::fs::remove_dir_all(&cache_dir).ok();
    }

    // 场景 3：自定义 Header（源级 header + urlOption headers 均生效）
    #[tokio::test]
    async fn test_tts_fixture_custom_headers_combined() {
        let (addr, records) =
            spawn_test_tts_server(|_req| (200, "audio/mpeg", b"AUDIO_HEADERS_TEST".to_vec())).await;

        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("headers");
        let config = HttpTtsConfig {
            id: 3,
            name: "TestHeadersEngine".into(),
            url: format!(
                "http://{}/tts?text={{{{speakText}}}},{{\"headers\": {{\"X-Option-Header\": \"OptionVal\"}}}}",
                addr
            ),
            header: Some(
                r#"{"X-Source-Header": "SourceVal", "User-Agent": "LegadoTTS/1.0"}"#.into(),
            ),
            ..Default::default()
        };
        let context = TtsSpeakContext::new("测试头部传递", 10, None, None, None);

        let result = fetch_tts_audio(&client, &config, &context, &cache_dir)
            .await
            .unwrap();
        assert!(!result.from_cache);

        let reqs = records.lock().await;
        assert_eq!(reqs.len(), 1);
        let h = &reqs[0].headers;
        assert_eq!(
            h.get("x-source-header").map(|s| s.as_str()),
            Some("SourceVal")
        );
        assert_eq!(
            h.get("x-option-header").map(|s| s.as_str()),
            Some("OptionVal")
        );
        assert_eq!(
            h.get("user-agent").map(|s| s.as_str()),
            Some("LegadoTTS/1.0")
        );

        std::fs::remove_dir_all(&cache_dir).ok();
    }

    // 场景 4：内嵌 JS 表达式求值（例如 {{speakText.split("").reverse().join("")}}）
    #[tokio::test]
    async fn test_tts_fixture_embedded_js_expression() {
        let (addr, records) =
            spawn_test_tts_server(|_req| (200, "audio/mpeg", b"AUDIO_JS_EXPR".to_vec())).await;

        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("js");
        let config = HttpTtsConfig {
            id: 4,
            name: "TestJsEngine".into(),
            url: format!(
                "http://{}/tts?text={{{{speakText.split(\"\").reverse().join(\"\")}}}}",
                addr
            ),
            ..Default::default()
        };
        let context = TtsSpeakContext::new("abcdef", 10, None, None, None);

        let result = fetch_tts_audio(&client, &config, &context, &cache_dir)
            .await
            .unwrap();
        assert!(!result.from_cache);

        let reqs = records.lock().await;
        assert_eq!(reqs.len(), 1);
        #[cfg(feature = "quickjs")]
        {
            assert!(
                reqs[0].uri.contains("text=fedcba"),
                "JS 求值应将 abcdef 反转为 fedcba，实际 URI: {}",
                reqs[0].uri
            );
        }

        std::fs::remove_dir_all(&cache_dir).ok();
    }

    // 场景 5：Content-Type 校验（json/text 报错与正则校验）
    #[tokio::test]
    async fn test_tts_fixture_content_type_error_and_regex() {
        let (addr, _) = spawn_test_tts_server(|req| {
            if req.uri.contains("err_json") {
                (
                    200,
                    "application/json",
                    r#"{"error": "配额已用完"}"#.as_bytes().to_vec(),
                )
            } else if req.uri.contains("err_text") {
                (200, "text/plain; charset=utf-8", b"Server busy".to_vec())
            } else {
                (200, "audio/ogg", b"OGG_AUDIO".to_vec())
            }
        })
        .await;

        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("errors");

        // 5a. 服务端返回 application/json 报错
        let config_json = HttpTtsConfig {
            id: 5,
            name: "ErrJson".into(),
            url: format!("http://{}/tts?err_json=1&text={{{{speakText}}}}", addr),
            ..Default::default()
        };
        let err_json = fetch_tts_audio(
            &client,
            &config_json,
            &TtsSpeakContext::new("测试", 10, None, None, None),
            &cache_dir,
        )
        .await
        .unwrap_err();
        assert!(err_json.to_string().contains("配额已用完"));

        // 5b. 服务端返回 text/plain 报错
        let config_text = HttpTtsConfig {
            id: 6,
            name: "ErrText".into(),
            url: format!("http://{}/tts?err_text=1&text={{{{speakText}}}}", addr),
            ..Default::default()
        };
        let err_text = fetch_tts_audio(
            &client,
            &config_text,
            &TtsSpeakContext::new("测试", 10, None, None, None),
            &cache_dir,
        )
        .await
        .unwrap_err();
        assert!(err_text.to_string().contains("Server busy"));

        // 5c. Content-Type 正则匹配失败
        let config_regex = HttpTtsConfig {
            id: 7,
            name: "RegexCheck".into(),
            url: format!("http://{}/tts?text={{{{speakText}}}}", addr),
            content_type: Some("^audio/mpeg$".into()),
            ..Default::default()
        };
        let err_regex = fetch_tts_audio(
            &client,
            &config_regex,
            &TtsSpeakContext::new("测试", 10, None, None, None),
            &cache_dir,
        )
        .await
        .unwrap_err();
        assert!(err_regex.to_string().contains("不匹配预期正则"));

        std::fs::remove_dir_all(&cache_dir).ok();
    }

    // 真正发请求，验证 MIME 参数清理与整串匹配，而非仅测试正则工具。
    #[tokio::test]
    async fn test_tts_fixture_mime_parameters_and_full_match() {
        let (addr, _) = spawn_test_tts_server(|req| {
            if req.uri.contains("extended") {
                (200, "audio/mpeg-extra", b"INVALID_AUDIO".to_vec())
            } else {
                (200, "audio/mpeg; charset=utf-8", b"VALID_AUDIO".to_vec())
            }
        })
        .await;
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("mime_match");
        let config = HttpTtsConfig {
            id: 20,
            url: format!("http://{addr}/tts"),
            content_type: Some("^audio/mpeg$".into()),
            ..Default::default()
        };
        let context = TtsSpeakContext::new("正文", 10, None, None, None);
        let result = fetch_tts_audio(&client, &config, &context, &cache_dir)
            .await
            .unwrap();
        assert_eq!(result.content_type, "audio/mpeg");
        assert_eq!(std::fs::read(result.audio_path).unwrap(), b"VALID_AUDIO");
        let extended = HttpTtsConfig {
            url: format!("http://{addr}/extended"),
            content_type: Some("audio/mpeg".into()),
            ..config
        };
        let error = fetch_tts_audio(&client, &extended, &context, &cache_dir)
            .await
            .unwrap_err();
        assert!(error.to_string().contains("不匹配预期正则"));
        assert_eq!(std::fs::read_dir(&cache_dir).unwrap().count(), 1);
        std::fs::remove_dir_all(cache_dir).unwrap();
    }

    #[test]
    fn test_tts_cache_key_differentiation() {
        let config = HttpTtsConfig {
            id: 1,
            url: "https://tts.example/api".into(),
            ..Default::default()
        };
        let context = TtsSpeakContext::new("正文", 10, None, None, None);
        let key = tts_cache_key_from_context(&config, &context);
        for changed in [
            TtsSpeakContext::new("其他正文", 10, None, None, None),
            TtsSpeakContext::new("正文", 11, None, None, None),
            TtsSpeakContext::new("正文", 10, Some("音色"), None, None),
            TtsSpeakContext::new("正文", 10, None, Some("发音人"), None),
            TtsSpeakContext::new("正文", 10, None, None, Some("情感")),
            TtsSpeakContext {
                emotion_name: Some("高兴"),
                ..context.clone()
            },
        ] {
            assert_ne!(key, tts_cache_key_from_context(&config, &changed));
        }
        assert_eq!(key, tts_cache_key_from_context(&config, &context));
    }

    #[test]
    fn test_tts_cache_configuration_and_structured_voice_boundaries() {
        let config = HttpTtsConfig {
            id: 1,
            url: "https://tts.example/api".into(),
            ..Default::default()
        };
        let context = TtsSpeakContext::new("正文", 10, None, None, None);
        let key = tts_cache_key_from_context(&config, &context);
        for changed in [
            HttpTtsConfig {
                id: 2,
                ..config.clone()
            },
            HttpTtsConfig {
                header: Some("token-B".into()),
                ..config.clone()
            },
            HttpTtsConfig {
                js_lib: Some("function voice(){return 'B';}".into()),
                ..config.clone()
            },
            HttpTtsConfig {
                content_type: Some("audio/wav".into()),
                ..config.clone()
            },
        ] {
            assert_ne!(key, tts_cache_key_from_context(&changed, &context));
        }
        let first = TtsSpeakContext::new("正文", 10, Some("a:b"), Some("c"), None);
        let second = TtsSpeakContext::new("正文", 10, Some("a"), Some("b:c"), None);
        assert_ne!(
            tts_cache_key_from_context(&config, &first),
            tts_cache_key_from_context(&config, &second)
        );
        assert_eq!(key, tts_cache_key_from_context(&config, &context));
    }

    // 场景 7：JS 上下文的类型与转义可靠性（纯数字正文、多行换行符、speakSpeed + 5 整数运算）
    #[tokio::test]
    async fn test_tts_js_context_safety() {
        let (addr, records) =
            spawn_test_tts_server(|_req| (200, "audio/mpeg", b"AUDIO_DATA".to_vec())).await;

        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let cache_dir = temp_test_cache_dir("js_safety");

        // 场景 A: 纯数字正文 "12345" 执行 .split("") 不报错，且结果正确
        let config_num = HttpTtsConfig {
            id: 10,
            name: "NumericTextEngine".into(),
            url: format!(
                "http://{}/tts?text={{{{speakText.split(\"\").reverse().join(\"\")}}}}",
                addr
            ),
            ..Default::default()
        };
        let context_num = TtsSpeakContext::new("12345", 10, None, None, None);
        let res_num = fetch_tts_audio(&client, &config_num, &context_num, &cache_dir)
            .await
            .unwrap();
        assert!(!res_num.from_cache);

        // 场景 B: 正文包含多行换行符 \n 能够正常执行 JS 不报 SyntaxError
        let config_multi = HttpTtsConfig {
            id: 11,
            name: "MultilineEngine".into(),
            url: format!(
                "http://{}/tts?lines={{{{speakText.split(\"\\n\").length}}}}",
                addr
            ),
            ..Default::default()
        };
        let context_multi = TtsSpeakContext::new("第一行\n第二行\n第三行", 10, None, None, None);
        let res_multi = fetch_tts_audio(&client, &config_multi, &context_multi, &cache_dir)
            .await
            .unwrap();
        assert!(!res_multi.from_cache);

        // 场景 C: speakSpeed + 5 结果为整数 15 而非字符串 "105"
        let config_speed = HttpTtsConfig {
            id: 12,
            name: "SpeedEngine".into(),
            url: format!("http://{}/tts?calc_speed={{{{speakSpeed + 5}}}}", addr),
            ..Default::default()
        };
        let context_speed = TtsSpeakContext::new("测试文本", 10, None, None, None);
        let res_speed = fetch_tts_audio(&client, &config_speed, &context_speed, &cache_dir)
            .await
            .unwrap();
        assert!(!res_speed.from_cache);

        let property_config = HttpTtsConfig {
            id: 13,
            name: "PropertyEngine".into(),
            url: format!("http://{}/tts?text_length={{{{speakText.length}}}}", addr),
            ..Default::default()
        };
        fetch_tts_audio(
            &client,
            &property_config,
            &TtsSpeakContext::new("甲乙丙丁", 10, None, None, None),
            &cache_dir,
        )
        .await
        .unwrap();
        let _reqs = records.lock().await;
        #[cfg(feature = "quickjs")]
        {
            assert!(
                _reqs.iter().any(|r| r.uri.contains("text=54321")),
                "纯数字文本 .split('') 应成功反转为 54321"
            );
            assert!(
                _reqs.iter().any(|r| r.uri.contains("lines=3")),
                "多行换行正文在 JS 中应求值为 3 行"
            );
            assert!(
                _reqs.iter().any(|r| r.uri.contains("calc_speed=15")),
                "speakSpeed + 5 必须求值为整数 15，不得拼接为 105"
            );
        }

        #[cfg(feature = "quickjs")]
        assert!(
            _reqs
                .iter()
                .any(|request| request.uri.contains("text_length=4"))
        );
        std::fs::remove_dir_all(&cache_dir).ok();
    }
    #[cfg(feature = "quickjs")]
    #[tokio::test]
    async fn test_tts_source_login_headers_and_binary_response() {
        use crate::tts_source::{MemoryTtsSourceStore, TtsSourceStore};
        use std::collections::BTreeMap;
        let (addr, records) =
            spawn_test_tts_server(|_| (200, "application/json", vec![0, 255, 128, 1])).await;
        let config=HttpTtsConfig {
            id:701,name:"独立 TTS 源".into(),
            url:format!("http://{addr}/tts?k={{{{source.getKey()}}}},{{\"headers\":{{\"x-login\":\"option\"}}}}"),
            header:Some("@js:JSON.stringify({'X-Login':'source','X-Key':source.getKey(),'X-Account':source.getLoginInfoMap().get('account')})".into()),
            login_check_js:Some("result.newBuilder().header('Content-Type','audio/mpeg').body(result.body().bytes()).build()".into()),
            ..Default::default()
        };
        let store = Arc::new(MemoryTtsSourceStore::default());
        store
            .apply(
                &config.source_key(),
                BTreeMap::from([
                    ("loginInfo".into(), Some(r#"{"account":"甲"}"#.into())),
                    ("loginHeader".into(), Some(r#"{"x-login":"saved"}"#.into())),
                ]),
            )
            .unwrap();
        let dir = temp_test_cache_dir("source_binary");
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let result = fetch_tts_audio_controlled(
            &client,
            &config,
            &TtsSpeakContext::new("正文", 10, None, None, None),
            &dir,
            None,
            TtsFetchResources {
                store: store.clone(),
                rates: Arc::new(RateLimiterRegistry::new()),
            },
            &TtsCancellation::default(),
        )
        .await
        .unwrap();
        assert_eq!(
            std::fs::read(result.audio_path).unwrap(),
            vec![0, 255, 128, 1]
        );
        let requests = records.lock().await;
        assert_eq!(
            requests[0].headers.get("x-login").map(String::as_str),
            Some("option")
        );
        assert_eq!(
            requests[0].headers.get("x-key").map(String::as_str),
            Some("httpTts:701")
        );
        assert!(requests[0].headers.contains_key("x-account"));
        drop(requests);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(feature = "quickjs")]
    #[test]
    fn test_tts_source_jslib_identity_storage_and_invalid_response() {
        use crate::tts_source::{MemoryTtsSourceStore, TtsSourceStore};
        let store = Arc::new(MemoryTtsSourceStore::default());
        let config = HttpTtsConfig {
            id: 702,
            js_lib: Some("var bootKey=source.getKey();".into()),
            ..Default::default()
        };
        let executor = TtsJsExecutor::new(&config, store.clone());
        assert_eq!(
            executor
                .execute_js("source.put('token','first');bootKey")
                .unwrap(),
            "httpTts:702"
        );
        assert_eq!(executor.execute_js("source.get('token')").unwrap(), "first");
        let other = TtsJsExecutor::new(
            &HttpTtsConfig {
                id: 703,
                ..Default::default()
            },
            store.clone(),
        );
        assert_eq!(other.execute_js("source.get('token')").unwrap(), "");
        assert!(
            executor
                .execute_js("source.put('before-error','saved');throw new Error('bad')")
                .is_err()
        );
        assert_eq!(
            store
                .load("httpTts:702")
                .unwrap()
                .get("v_before-error")
                .map(String::as_str),
            Some("saved")
        );
        let response = LegadoRawResponse {
            raw_summary: String::new(),
            status: 200,
            headers: HashMap::new(),
            body: vec![0, 255],
            url: "http://local".into(),
        };
        assert!(evaluate_tts_response(&executor, "true", response.clone()).is_err());
        assert_eq!(
            evaluate_tts_response(&executor, "result", response)
                .unwrap()
                .body,
            vec![0, 255]
        );
    }

    #[tokio::test]
    async fn test_tts_dedup_cancel_wait_and_network_no_cache() {
        let (addr, records) =
            spawn_test_tts_server(|_| (200, "audio/mpeg", b"AUDIO".to_vec())).await;
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let config = HttpTtsConfig {
            id: 704,
            url: format!("http://{addr}/tts"),
            ..Default::default()
        };
        let dir = temp_test_cache_dir("dedup_cancel");
        let context = TtsSpeakContext::new("同一段", 10, None, None, None);
        let (first, second) = tokio::join!(
            fetch_tts_audio(&client, &config, &context, &dir),
            fetch_tts_audio(&client, &config, &context, &dir)
        );
        assert_ne!(first.unwrap().from_cache, second.unwrap().from_cache);
        assert_eq!(records.lock().await.len(), 1);
        let rates = Arc::new(RateLimiterRegistry::new());
        let limited = HttpTtsConfig {
            id: 705,
            concurrent_rate: Some("1/10000".into()),
            ..config.clone()
        };
        rates.acquire_key(&limited.source_key(), "1/10000").await;
        let cancellation = TtsCancellation::default();
        let future = fetch_tts_audio_controlled(
            &client,
            &limited,
            &context,
            &dir,
            None,
            TtsFetchResources {
                store: default_store(),
                rates,
            },
            &cancellation,
        );
        let cancelling = async {
            tokio::time::sleep(Duration::from_millis(40)).await;
            cancellation.cancel();
        };
        let (result, _) = tokio::join!(future, cancelling);
        assert!(result.unwrap_err().to_string().contains("TTS_CANCELLED"));
        assert_eq!(records.lock().await.len(), 1);
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 1);
        // 请求已经到达服务器但响应一直挂起，取消必须释放网络等待且不落盘。
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let pending = HttpTtsConfig {
            id: 706,
            url: format!("http://{}/hang", listener.local_addr().unwrap()),
            ..Default::default()
        };
        let cancellation = TtsCancellation::default();
        let stop_after_accept = async {
            let (socket, _) = listener.accept().await.unwrap();
            cancellation.cancel();
            tokio::time::sleep(Duration::from_millis(20)).await;
            drop(socket);
        };
        let (result, _) = tokio::join!(
            fetch_tts_audio_controlled(
                &client,
                &pending,
                &context,
                &dir,
                None,
                TtsFetchResources {
                    store: default_store(),
                    rates: Arc::new(RateLimiterRegistry::new())
                },
                &cancellation
            ),
            stop_after_accept
        );
        assert!(result.unwrap_err().to_string().contains("TTS_CANCELLED"));
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 1);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(feature = "quickjs")]
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn test_tts_explicit_flow_survives_response_reload_but_not_next_synthesis() {
        let (addr, records) = spawn_test_tts_server(|req| {
            if req.uri.contains("phase=retry") {
                (200, "audio/mpeg", b"FLOW-AUDIO".to_vec())
            } else {
                (200, "application/json", br#"{"retry":true}"#.to_vec())
            }
        })
        .await;
        let config = HttpTtsConfig {
            id: 721,
            url: format!("@js:if(java.__lgStoreGet('flowToken')!=='original')throw new Error('URL 丢失会话'); 'http://{addr}/audio?phase='+(java.__lgStoreGet('phase')||'first')"),
            header: Some("@js:if(java.__lgStoreGet('phase'))throw new Error('上次合成残留');java.__lgStorePut('flowToken','original');cache.put('cached','kept');JSON.stringify({'X-Flow':'configured'})".into()),
            login_check_js: Some("if(java.__lgStoreGet('flowToken')!=='original')throw new Error('响应校验丢失会话');java.__lgStorePut('phase','retry');java.initUrl();var refreshed=java.getResponse();if(cache.get('cached')!=='kept')throw new Error('重新请求丢失缓存');refreshed".into()),
            ..Default::default()
        };
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let dir = temp_test_cache_dir("explicit_flow_reload");
        let store = Arc::new(crate::tts_source::MemoryTtsSourceStore::default());
        for text in ["第一段", "第二段"] {
            let result = fetch_tts_audio_controlled(
                &client,
                &config,
                &TtsSpeakContext::new(text, 10, None, None, None),
                &dir,
                None,
                TtsFetchResources {
                    store: store.clone(),
                    rates: Arc::new(RateLimiterRegistry::new()),
                },
                &TtsCancellation::default(),
            )
            .await
            .unwrap();
            assert_eq!(std::fs::read(result.audio_path).unwrap(), b"FLOW-AUDIO");
        }
        let requests = records.lock().await;
        assert_eq!(requests.len(), 4);
        for pair in requests.as_chunks::<2>().0 {
            assert!(pair[0].uri.contains("phase=first"));
            assert!(pair[1].uri.contains("phase=retry"));
            assert_eq!(
                pair[1].headers.get("x-flow").map(String::as_str),
                Some("configured")
            );
        }
        drop(requests);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(feature = "quickjs")]
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn test_tts_login_check_refresh_response_and_cache_account() {
        let (addr, records) = spawn_test_tts_server(|req| {
            if req.headers.get("x-auth").map(String::as_str) == Some("renewed") {
                (200, "audio/mpeg", vec![0, 255, 128, 7])
            } else {
                (200, "application/json", br#"{"status":40000001}"#.to_vec())
            }
        })
        .await;
        let config=HttpTtsConfig {
            id:711,url:format!("http://{addr}/audio,{{\"method\":\"POST\",\"body\":\"text={{{{speakText}}}}\"}}"),
            login_url:Some("function login(){source.putLoginHeader(JSON.stringify({'X-Auth':'renewed'}));}".into()),
            login_check_js:Some("var response=result;if(response.headers().get('Content-Type')!=='audio/mpeg'){source.login();java.getHeaderMap().putAll(source.getHeaderMap(true));response=java.getResponse();}response".into()),
            ..Default::default()
        };
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let dir = temp_test_cache_dir("response_refresh");
        let store = Arc::new(crate::tts_source::MemoryTtsSourceStore::default());
        let context = TtsSpeakContext::new("正文", 10, None, None, None);
        let rates = Arc::new(RateLimiterRegistry::new());
        let response = fetch_tts_audio_controlled(
            &client,
            &config,
            &context,
            &dir,
            None,
            TtsFetchResources {
                store: store.clone(),
                rates: rates.clone(),
            },
            &TtsCancellation::default(),
        )
        .await
        .unwrap();
        assert_eq!(
            std::fs::read(&response.audio_path).unwrap(),
            vec![0, 255, 128, 7]
        );
        let req = records.lock().await;
        assert_eq!(req.len(), 2);
        assert_eq!(req[0].method, "POST");
        assert_eq!(req[1].method, "POST");
        assert_eq!(req[0].body, req[1].body);
        drop(req);
        let hit = fetch_tts_audio_controlled(
            &client,
            &config,
            &context,
            &dir,
            None,
            TtsFetchResources {
                store: store.clone(),
                rates: rates.clone(),
            },
            &TtsCancellation::default(),
        )
        .await
        .unwrap();
        assert!(hit.from_cache);
        assert_eq!(records.lock().await.len(), 2);
        use crate::tts_source::TtsSourceStore;
        store
            .apply(
                &config.source_key(),
                std::collections::BTreeMap::from([(
                    "loginInfo".into(),
                    Some("{\"account\":\"new\"}".into()),
                )]),
            )
            .unwrap();
        let changed = fetch_tts_audio_controlled(
            &client,
            &config,
            &context,
            &dir,
            None,
            TtsFetchResources { store, rates },
            &TtsCancellation::default(),
        )
        .await
        .unwrap();
        assert!(!changed.from_cache);
        assert_ne!(changed.audio_path, response.audio_path);
        assert_eq!(records.lock().await.len(), 3);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[tokio::test]
    async fn test_tts_cookie_write_gate_and_login_header_identity() {
        let (addr, records) = spawn_test_tts_server(|req| {
            if req.uri.contains("seed") {
                (
                    200,
                    "audio/mpeg\r\nSet-Cookie: tts_token=first; Path=/",
                    b"FIRST".to_vec(),
                )
            } else {
                (
                    200,
                    "audio/mpeg\r\nSet-Cookie: tts_token=second; Path=/",
                    b"NEXT".to_vec(),
                )
            }
        })
        .await;
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let dir = temp_test_cache_dir("cookies");
        let first = HttpTtsConfig {
            id: 712,
            url: format!("http://{addr}/seed"),
            header: Some(r#"{"Authorization":"private"}"#.into()),
            enabled_cookie_jar: Some(true),
            ..Default::default()
        };
        let second = HttpTtsConfig {
            id: 713,
            url: format!("http://{addr}/check"),
            enabled_cookie_jar: Some(false),
            ..Default::default()
        };
        fetch_tts_audio(
            &client,
            &first,
            &TtsSpeakContext::new("甲", 10, None, None, None),
            &dir,
        )
        .await
        .unwrap();
        fetch_tts_audio(
            &client,
            &second,
            &TtsSpeakContext::new("乙", 10, None, None, None),
            &dir,
        )
        .await
        .unwrap();
        fetch_tts_audio(
            &client,
            &second,
            &TtsSpeakContext::new("丙", 10, None, None, None),
            &dir,
        )
        .await
        .unwrap();
        let req = records.lock().await;
        assert_eq!(
            req[0].headers.get("authorization").map(String::as_str),
            Some("private")
        );
        assert!(!req[1].headers.contains_key("authorization"));
        assert!(!req[1].headers.contains_key("cookiejar"));
        assert!(
            req[1]
                .headers
                .get("cookie")
                .unwrap()
                .contains("tts_token=first")
        );
        assert!(
            req[2]
                .headers
                .get("cookie")
                .unwrap()
                .contains("tts_token=first")
        );
        drop(req);
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[tokio::test]
    async fn test_tts_invalid_header_does_not_contact_server() {
        let (addr, records) =
            spawn_test_tts_server(|_| (200, "audio/mpeg", b"AUDIO".to_vec())).await;
        let client = LegadoClient::new(legado_net::LegadoClientConfig::default()).unwrap();
        let dir = temp_test_cache_dir("invalid_header");
        let config = HttpTtsConfig {
            id: 714,
            url: format!("http://{addr}/audio"),
            header: Some("invalid-json".into()),
            ..Default::default()
        };
        let error = fetch_tts_audio(
            &client,
            &config,
            &TtsSpeakContext::new("正文", 10, None, None, None),
            &dir,
        )
        .await
        .unwrap_err();
        assert!(error.to_string().contains("请求头"));
        assert!(records.lock().await.is_empty());
        assert!(std::fs::read_dir(&dir).unwrap().next().is_none());
        std::fs::remove_dir_all(dir).unwrap();
    }
}
