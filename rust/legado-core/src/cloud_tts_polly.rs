//! Polly 纯协议适配；时间显式注入签名计算，不持有网络或可变全局状态。
use super::cloud_tts::*;
use crate::LegadoResult;
use chrono::{DateTime, Utc};
use hmac::{Hmac, KeyInit, Mac};
use serde::Deserialize;
use sha2::{Digest, Sha256};

pub struct AwsPollyCloudTtsProvider;

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn mac(key: &[u8], bytes: &[u8]) -> LegadoResult<Vec<u8>> {
    let mut mac = Hmac::<Sha256>::new_from_slice(key).map_err(|_| invalid("AWS 签名密钥无效"))?;
    mac.update(bytes);
    Ok(mac.finalize().into_bytes().to_vec())
}
fn encode(text: &str) -> String {
    let mut result = String::new();
    for b in text.bytes() {
        if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) {
            result.push(b as char);
        } else {
            result.push_str(&format!("%{b:02X}"));
        }
    }
    result
}
/// 固定时间可用于官方向量核验；调用者负责传入与发送内容完全相同的字节。
pub fn signed_headers(
    engine: &CloudTtsEngine,
    method: &str,
    endpoint: &str,
    body: &[u8],
    now: DateTime<Utc>,
) -> LegadoResult<(String, Vec<(&'static str, String)>)> {
    let url = url::Url::parse(endpoint).map_err(|_| invalid("AWS 服务地址无效"))?;
    let host = url
        .host_str()
        .ok_or_else(|| invalid("AWS 服务地址缺少主机"))?;
    let host = match url.port() {
        Some(port) => format!("{host}:{port}"),
        None => host.to_owned(),
    };
    let date = now.format("%Y%m%d").to_string();
    let timestamp = now.format("%Y%m%dT%H%M%SZ").to_string();
    let payload_hash = hex(&Sha256::digest(body));
    let mut query = url
        .query_pairs()
        .map(|(k, v)| (encode(&k), encode(&v)))
        .collect::<Vec<_>>();
    query.sort();
    let query = query
        .into_iter()
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>()
        .join("&");
    // 本 Provider 的资源路径仅含固定 ASCII；自定义前缀按 SigV4 双编码百分号。
    let path = url
        .path()
        .split('/')
        .map(encode)
        .collect::<Vec<_>>()
        .join("/");
    let headers =
        format!("host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{timestamp}\n");
    let signed = "host;x-amz-content-sha256;x-amz-date";
    let canonical = format!("{method}\n{path}\n{query}\n{headers}\n{signed}\n{payload_hash}");
    let scope = format!("{date}/{}/polly/aws4_request", engine.region);
    let text = format!(
        "AWS4-HMAC-SHA256\n{timestamp}\n{scope}\n{}",
        hex(&Sha256::digest(canonical.as_bytes()))
    );
    let day = mac(
        format!("AWS4{}", engine.secret_key).as_bytes(),
        date.as_bytes(),
    )?;
    let region = mac(&day, engine.region.as_bytes())?;
    let service = mac(&region, b"polly")?;
    let key = mac(&service, b"aws4_request")?;
    let signature = hex(&mac(&key, text.as_bytes())?);
    Ok((
        format!(
            "AWS4-HMAC-SHA256 Credential={}/{scope}, SignedHeaders={signed}, Signature={signature}",
            engine.api_key
        ),
        vec![
            ("Host", host),
            ("X-Amz-Date", timestamp),
            ("X-Amz-Content-Sha256", payload_hash),
        ],
    ))
}
fn endpoint(engine: &CloudTtsEngine) -> LegadoResult<String> {
    if engine.provider != CloudTtsProviderType::AwsPolly
        || !engine.enabled
        || engine.id.trim().is_empty()
    {
        return Err(invalid("AWS 引擎类型或状态无效"));
    }
    if engine.api_key.trim().is_empty()
        || engine.secret_key.trim().is_empty()
        || engine
            .api_key
            .chars()
            .any(|c| c.is_control() || c.is_whitespace() || matches!(c, ',' | '/'))
        || engine.secret_key.chars().any(char::is_control)
    {
        return Err(invalid("AWS 成组凭据无效"));
    }
    if engine.region.is_empty()
        || !engine
            .region
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
    {
        return Err(invalid("AWS 区域不能为空且须为区域标识"));
    }
    let base = if engine.base_url.trim().is_empty() {
        format!("https://polly.{}.amazonaws.com", engine.region)
    } else {
        engine.base_url.trim().trim_end_matches('/').to_owned()
    };
    parse_service_url(
        &base,
        "AWS 服务地址无效",
        "AWS 地址须为无凭据、查询或片段的 HTTP(S) 地址",
    )?;
    Ok(base)
}
fn model(engine: &CloudTtsEngine) -> LegadoResult<&str> {
    let model = if engine.model.trim().is_empty() {
        "neural"
    } else {
        engine.model.as_str()
    };
    if !matches!(model, "standard" | "neural" | "long-form" | "generative") {
        return Err(invalid("AWS 合成模型不支持"));
    }
    Ok(model)
}
impl CloudTtsProvider for AwsPollyCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::AwsPolly
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        Vec::new()
    }
    fn prepare_catalog(&self, engine: &CloudTtsEngine) -> LegadoResult<CloudVoiceCatalog> {
        self.prepare_catalog_page(engine, None)
    }
    fn prepare_catalog_page(
        &self,
        engine: &CloudTtsEngine,
        token: Option<&str>,
    ) -> LegadoResult<CloudVoiceCatalog> {
        let mut url = format!(
            "{}/v1/voices?Engine={}&IncludeAdditionalLanguageCodes=yes",
            endpoint(engine)?,
            encode(model(engine)?)
        );
        if let Some(token) = token {
            url.push_str(&format!("&NextToken={}", encode(token)));
        }
        let (authorization, authentication_headers) =
            signed_headers(engine, "GET", &url, b"", Utc::now())?;
        Ok(CloudVoiceCatalog::Remote(PreparedCloudCatalog {
            endpoint: url,
            credential_header: "Authorization",
            authorization,
            authentication_headers,
        }))
    }
    fn decode_catalog_page(&self, bytes: &[u8]) -> LegadoResult<CloudCatalogPage> {
        #[derive(Deserialize)]
        #[serde(rename_all = "PascalCase")]
        struct Voice {
            id: String,
            name: Option<String>,
            language_code: Option<String>,
            gender: Option<String>,
            #[serde(default)]
            supported_engines: Vec<String>,
        }
        #[derive(Deserialize)]
        #[serde(rename_all = "PascalCase")]
        struct Page {
            voices: Vec<Voice>,
            next_token: Option<String>,
        }
        let page: Page =
            serde_json::from_slice(bytes).map_err(|_| invalid("AWS 音色目录格式无效"))?;
        let voices = page
            .voices
            .into_iter()
            .map(|v| {
                if v.id.trim().is_empty() {
                    return Err(invalid("AWS 音色目录缺少有效 ID"));
                }
                Ok(CloudTtsVoiceDescriptor {
                    display_name: v
                        .name
                        .filter(|s| !s.trim().is_empty())
                        .unwrap_or_else(|| v.id.clone()),
                    id: v.id,
                    locale: v.language_code.unwrap_or_default(),
                    gender: v.gender.unwrap_or_default(),
                    supported_models: v.supported_engines,
                    ..Default::default()
                })
            })
            .collect::<LegadoResult<Vec<_>>>()?;
        Ok(CloudCatalogPage {
            voices,
            next_token: page.next_token.filter(|t| !t.trim().is_empty()),
        })
    }
    fn prepare(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        let url = format!("{}/v1/speech", endpoint(engine)?);
        if request.text.trim().is_empty()
            || request.text.chars().count() > 3000
            || request.voice_id.trim().is_empty()
        {
            return Err(invalid("AWS 音色或文本无效，正文每片最多 3000 字符"));
        }
        let format = request.format.to_ascii_lowercase();
        let wire = match format.as_str() {
            "mp3" => "mp3",
            "ogg_vorbis" => "ogg_vorbis",
            "pcm" | "wav" => "pcm",
            _ => return Err(invalid("AWS 音频格式不支持")),
        };
        let rate = if wire == "pcm" {
            Some(request.sample_rate.unwrap_or(16000))
        } else {
            request.sample_rate
        };
        if let Some(rate) = rate
            && !(if wire == "pcm" {
                [8000, 16000].contains(&rate)
            } else {
                [8000, 16000, 22050, 24000, 44100, 48000].contains(&rate)
            })
        {
            return Err(invalid("AWS 音频采样率不支持"));
        }
        let mut body = serde_json::json!({"Engine":model(engine)?,"OutputFormat":wire,"Text":request.text,"TextType":"text","VoiceId":request.voice_id});
        if !request.locale.trim().is_empty() {
            body["LanguageCode"] = request.locale.clone().into();
        }
        if let Some(rate) = rate {
            body["SampleRate"] = rate.to_string().into();
        }
        let body = CloudSpeechBody::Json(body);
        let (authorization, authentication_headers) =
            signed_headers(engine, "POST", &url, body.encode().as_bytes(), Utc::now())?;
        Ok(PreparedCloudSpeech {
            endpoint: url,
            credential_header: "Authorization",
            authorization,
            authentication_headers,
            additional_headers: Vec::new(),
            response_kind: CloudSpeechResponseKind::AudioBytes,
            body,
            response_format: if wire == "pcm" {
                format!("pcm:{}", rate.unwrap_or(16000))
            } else {
                format
            },
        })
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        if let Some(rate) = format.strip_prefix("pcm:") {
            let rate = rate.parse().map_err(|_| invalid("AWS PCM 采样率无效"))?;
            return Ok(CloudTtsAudio {
                bytes: pcm16_mono_to_wav(&bytes, rate)?,
                extension: "wav",
                content_type: "audio/wav",
            });
        }
        let (extension, content_type) = match format {
            "mp3"
                if bytes.starts_with(b"ID3")
                    || bytes.len() > 1 && bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0 =>
            {
                ("mp3", "audio/mpeg")
            }
            "ogg_vorbis" if bytes.starts_with(b"OggS") => ("ogg", "audio/ogg"),
            _ => return Err(invalid("AWS 未返回所请求的音频格式")),
        };
        Ok(CloudTtsAudio {
            bytes,
            extension,
            content_type,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "polly".into(),
            provider: CloudTtsProviderType::AwsPolly,
            api_key: "AKIDEXAMPLE".into(),
            secret_key: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY".into(),
            region: "us-east-1".into(),
            model: "neural".into(),
            ..Default::default()
        }
    }
    fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: "中文 😀\n引号\"".into(),
            voice_id: "Zhiyu".into(),
            locale: "cmn-CN".into(),
            ..Default::default()
        }
    }
    #[test]
    fn signature_is_fixed_and_canonical_query_does_not_use_form_encoding() {
        // RFC 4231 HMAC-SHA256 测试向量，先验证签名所用原语。
        assert_eq!(
            hex(&mac(&[0x0b; 20], b"Hi There").unwrap()),
            "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
        );
        let now = "2015-08-30T12:36:00Z".parse::<DateTime<Utc>>().unwrap();
        // AWS 示例凭据；预期值用独立 Python hashlib/hmac 计算。
        let (auth,headers)=signed_headers(&engine(),"GET","https://polly.us-east-1.amazonaws.com/v1/voices?IncludeAdditionalLanguageCodes=yes&Engine=neural",b"",now).unwrap();
        assert!(auth.ends_with(
            "Signature=9eaedf635f3dbbc8f384f6464284e19ab6fb908b8b0b7c63f886a7f8b4016f9a"
        ));
        assert_eq!(headers[0].1, "polly.us-east-1.amazonaws.com");
        assert_eq!(headers[1].1, "20150830T123600Z");
        let a = signed_headers(
            &engine(),
            "GET",
            "http://localhost:1234/v1/voices?b=%2B%2F%3D&a=%20",
            b"",
            now,
        )
        .unwrap();
        let b = signed_headers(
            &engine(),
            "GET",
            "http://localhost:1234/v1/voices?a=+&b=%2B%2F%3D",
            b"",
            now,
        )
        .unwrap();
        assert_eq!(a.0, b.0);
        assert_eq!(a.1[0].1, "localhost:1234");
        assert_eq!(encode(" +/=中文"), "%20%2B%2F%3D%E4%B8%AD%E6%96%87");
    }
    #[test]
    fn request_and_pcm_rate_match_actual_wire_data() {
        let mut request = request();
        request.format = "wav".into();
        let prepared = AwsPollyCloudTtsProvider
            .prepare(&engine(), &request)
            .unwrap();
        let CloudSpeechBody::Json(body) = prepared.body else {
            panic!("预期 JSON")
        };
        assert_eq!(
            body,
            serde_json::json!({"Engine":"neural","OutputFormat":"pcm","SampleRate":"16000","Text":request.text,"TextType":"text","VoiceId":"Zhiyu","LanguageCode":"cmn-CN"})
        );
        let audio = AwsPollyCloudTtsProvider
            .decode_audio(&prepared.response_format, vec![0, 1, 0, 2])
            .unwrap();
        assert_eq!(&audio.bytes[24..28], &16000u32.to_le_bytes());
        request.sample_rate = Some(8000);
        let prepared = AwsPollyCloudTtsProvider
            .prepare(&engine(), &request)
            .unwrap();
        let audio = AwsPollyCloudTtsProvider
            .decode_audio(&prepared.response_format, vec![0, 1])
            .unwrap();
        assert_eq!(&audio.bytes[24..28], &8000u32.to_le_bytes());
        request.sample_rate = Some(24000);
        assert!(
            AwsPollyCloudTtsProvider
                .prepare(&engine(), &request)
                .is_err()
        );
    }
    #[test]
    fn catalog_page_keeps_metadata_and_token_without_persisting_them() {
        let page=AwsPollyCloudTtsProvider.decode_catalog_page(br#"{"Voices":[{"Id":"Zhiyu","Name":"","LanguageCode":"cmn-CN","Gender":"Female","SupportedEngines":["standard","neural"]}],"NextToken":"+/= token"}"#).unwrap();
        assert_eq!(page.voices[0].display_name, "Zhiyu");
        assert_eq!(page.voices[0].supported_models, ["standard", "neural"]);
        let CloudVoiceCatalog::Remote(request) = AwsPollyCloudTtsProvider
            .prepare_catalog_page(&engine(), page.next_token.as_deref())
            .unwrap()
        else {
            panic!("预期网络目录")
        };
        assert!(request.endpoint.ends_with("&NextToken=%2B%2F%3D%20token"));
        assert!(
            AwsPollyCloudTtsProvider
                .decode_catalog_page(br#"{"Voices":[{"Id":""}]}"#)
                .is_err()
        );
        assert!(
            AwsPollyCloudTtsProvider
                .decode_catalog_page(br#"{}"#)
                .is_err()
        );
    }
    #[test]
    fn invalid_inputs_and_errors_never_export_secret() {
        let mut engine = engine();
        assert!(
            !serde_json::to_string(&engine)
                .unwrap()
                .contains("EXAMPLEKEY")
        );
        assert!(!format!("{engine:?}").contains("EXAMPLEKEY"));
        for field in ["region", "api", "secret", "model", "base", "enabled"] {
            let mut bad = engine.clone();
            match field {
                "region" => bad.region.clear(),
                "api" => bad.api_key.clear(),
                "secret" => bad.secret_key.clear(),
                "model" => bad.model = "unknown".into(),
                "base" => bad.base_url = "https://secret@example.com".into(),
                _ => bad.enabled = false,
            }
            let error = AwsPollyCloudTtsProvider
                .prepare(&bad, &request())
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("EXAMPLEKEY"));
        }
        engine.model.clear();
        assert!(
            AwsPollyCloudTtsProvider
                .prepare(&engine, &request())
                .is_ok()
        );
        assert!(
            AwsPollyCloudTtsProvider
                .decode_audio("mp3", b"error".to_vec())
                .is_err()
        );
        assert!(
            AwsPollyCloudTtsProvider
                .decode_audio("pcm:16000", vec![1])
                .is_err()
        );
    }
}
