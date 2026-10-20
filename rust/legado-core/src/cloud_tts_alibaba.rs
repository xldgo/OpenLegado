//! 对照固定上游百炼请求、音色与 PCM/下载响应；不访问网络或数据库。
use super::cloud_tts::*;
use crate::LegadoResult;
use base64::{Engine, engine::general_purpose::STANDARD};
use serde_json::{Value, json};

pub struct AlibabaCloudTtsProvider;
impl CloudTtsProvider for AlibabaCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::AlibabaCloud
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        ["Cherry", "Serena", "Ethan", "Chelsie"]
            .into_iter()
            .map(|id| CloudTtsVoiceDescriptor {
                id: id.into(),
                display_name: id.into(),
                styles: Vec::new(),
                sample_rate: Some(24000),
                ..Default::default()
            })
            .collect()
    }
    fn prepare(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        if engine.provider != self.provider_type() || !engine.enabled || engine.id.trim().is_empty()
        {
            return Err(invalid("百炼朗读引擎类型、状态或 ID 无效"));
        }
        if engine.api_key.trim().is_empty() || engine.api_key.chars().any(char::is_control) {
            return Err(invalid("百炼 API Key 为空或含无效字符"));
        }
        if engine.model.trim().is_empty()
            || request.voice_id.trim().is_empty()
            || request.text.trim().is_empty()
        {
            return Err(invalid("百炼模型、音色或朗读文本为空"));
        }
        if request.text.chars().count() > 600 {
            return Err(invalid("百炼单次文本超过 600 字符，需由朗读会话分片"));
        }
        if !request.format.eq_ignore_ascii_case("wav") {
            return Err(invalid("百炼仅支持 WAV 输出"));
        }
        let mut input = json!({"text":request.text,"voice":request.voice_id,"language_type":if request.locale.trim().is_empty() {"Auto"} else {&request.locale}});
        let instructions = [&request.style, &request.instructions]
            .into_iter()
            .filter(|s| !s.trim().is_empty())
            .map(String::as_str)
            .collect::<Vec<_>>()
            .join("；");
        if engine.model.to_lowercase().contains("instruct") && !instructions.is_empty() {
            input["instructions"] = json!(instructions);
        }
        let base = if engine.base_url.trim().is_empty() {
            "https://dashscope.aliyuncs.com/api/v1"
        } else {
            engine.base_url.trim_end_matches('/')
        };
        let endpoint = if base.ends_with("/generation") {
            base.to_owned()
        } else {
            format!("{base}/services/aigc/multimodal-generation/generation")
        };
        let url = url::Url::parse(&endpoint).map_err(|_| invalid("百炼服务地址无效"))?;
        if !["http", "https"].contains(&url.scheme())
            || url.host_str().is_none()
            || !url.username().is_empty()
            || url.password().is_some()
            || url.query().is_some()
            || url.fragment().is_some()
        {
            return Err(invalid(
                "百炼服务地址必须是无凭据、查询或片段的 HTTP(S) 地址",
            ));
        }
        Ok(PreparedCloudSpeech {
            authentication_headers: Vec::new(),
            endpoint: url.to_string(),
            credential_header: "Authorization",
            authorization: format!("Bearer {}", engine.api_key),
            additional_headers: vec![("X-DashScope-SSE", "enable".into())],
            response_kind: CloudSpeechResponseKind::EventStream,
            body: CloudSpeechBody::Json(json!({"model":engine.model,"input":input})),
            response_format: "wav".into(),
        })
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        if format != "wav"
            || bytes.len() <= 44
            || !bytes.starts_with(b"RIFF")
            || &bytes[8..12] != b"WAVE"
        {
            return Err(invalid("百炼下载未返回完整 WAV 音频"));
        }
        let declared = u32::from_le_bytes(bytes[4..8].try_into().unwrap()) as usize;
        if declared.checked_add(8) != Some(bytes.len()) {
            return Err(invalid("百炼下载 WAV 长度不完整"));
        }
        Ok(CloudTtsAudio {
            bytes,
            extension: "wav",
            content_type: "audio/wav",
        })
    }
    fn decode_response(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<DecodedCloudSpeech> {
        if format != "wav" {
            return Err(invalid("百炼仅支持 WAV 输出"));
        }
        let text = std::str::from_utf8(&bytes).map_err(|_| invalid("百炼 SSE 编码无效"))?;
        let mut pcm = Vec::new();
        let mut audio_url = String::new();
        let mut data = Vec::new();
        let mut error_event = false;
        let mut complete = false;
        for line in text.lines().chain(std::iter::once("")) {
            if line.is_empty() {
                if error_event {
                    return Err(invalid("百炼返回错误事件"));
                }
                if !data.is_empty() {
                    let payload = data.join("\n");
                    data.clear();
                    if payload.trim() == "[DONE]" {
                        complete = true;
                        break;
                    }
                    complete |= decode_event(&payload, &mut pcm, &mut audio_url)?;
                }
                error_event = false;
            } else if let Some(value) = line.strip_prefix("data:") {
                data.push(value.strip_prefix(' ').unwrap_or(value));
            } else if let Some(value) = line.strip_prefix("event:") {
                error_event = value.trim() == "error";
            }
        }
        if !complete {
            return Err(invalid("百炼音频流未完成，拒绝缓存部分音频"));
        }
        if !pcm.is_empty() {
            return Ok(DecodedCloudSpeech::Audio(CloudTtsAudio {
                bytes: pcm16_mono_to_wav(&pcm, 24000)?,
                extension: "wav",
                content_type: "audio/wav",
            }));
        }
        let url = url::Url::parse(&audio_url).map_err(|_| invalid("百炼未返回有效音频地址"))?;
        if !["http", "https"].contains(&url.scheme())
            || url.host_str().is_none()
            || !url.username().is_empty()
            || url.password().is_some()
            || url.fragment().is_some()
        {
            return Err(invalid("百炼音频下载地址无效"));
        }
        Ok(DecodedCloudSpeech::Download(url.to_string()))
    }
}
fn decode_event(payload: &str, pcm: &mut Vec<u8>, audio_url: &mut String) -> LegadoResult<bool> {
    let value: Value = serde_json::from_str(payload).map_err(|_| invalid("百炼 SSE JSON 无效"))?;
    if !value.is_object()
        || value.get("error").is_some()
        || value
            .get("code")
            .is_some_and(|v| !v.is_null() && v.as_str() != Some(""))
        || value
            .get("status_code")
            .is_some_and(|v| v.as_u64().is_none_or(|n| !(200..300).contains(&n)))
    {
        return Err(invalid("百炼返回合成错误"));
    }
    let output = value
        .get("output")
        .and_then(Value::as_object)
        .ok_or_else(|| invalid("百炼 SSE 缺少 output"))?;
    if let Some(audio) = output.get("audio").filter(|v| !v.is_null()) {
        let audio = audio
            .as_object()
            .ok_or_else(|| invalid("百炼音频字段无效"))?;
        if let Some(data) = audio.get("data").filter(|v| !v.is_null()) {
            let data = data
                .as_str()
                .ok_or_else(|| invalid("百炼 PCM 不是 Base64 字符串"))?;
            let compact: Vec<u8> = data.bytes().filter(|b| !b.is_ascii_whitespace()).collect();
            pcm.extend(
                STANDARD
                    .decode(compact)
                    .map_err(|_| invalid("百炼 PCM Base64 无效"))?,
            );
        }
        if let Some(url) = audio.get("url").filter(|v| !v.is_null()) {
            let url = url
                .as_str()
                .ok_or_else(|| invalid("百炼音频地址字段无效"))?;
            if !url.trim().is_empty() {
                *audio_url = url.into();
            }
        }
    }
    match output.get("finish_reason").filter(|v| !v.is_null()) {
        None => Ok(false),
        Some(v) if v.as_str() == Some("stop") => Ok(true),
        Some(_) => Err(invalid("百炼音频流被截断或异常结束")),
    }
}

#[cfg(test)]
mod tests {
    fn json_body(p: &super::PreparedCloudSpeech) -> serde_json::Value {
        let super::CloudSpeechBody::Json(value) = &p.body else {
            panic!("预期 JSON 请求")
        };
        value.clone()
    }
    use super::*;
    pub fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "fixture".into(),
            provider: CloudTtsProviderType::AlibabaCloud,
            model: "qwen3-tts-flash".into(),
            api_key: "private-fixture".into(),
            ..Default::default()
        }
    }
    pub fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: "中文😀\n引号\"".into(),
            voice_id: "Cherry".into(),
            format: "wav".into(),
            style: "平静".into(),
            instructions: "用中文朗读".into(),
            ..Default::default()
        }
    }
    #[test]
    fn upstream_request_headers_endpoints_and_instruct() {
        let provider = AlibabaCloudTtsProvider;
        let mut e = engine();
        let mut r = request();
        let p = provider.prepare(&e, &r).unwrap();
        assert_eq!(
            p.endpoint,
            "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        );
        assert_eq!(p.authorization, "Bearer private-fixture");
        assert_eq!(
            p.additional_headers,
            vec![("X-DashScope-SSE", "enable".into())]
        );
        assert_eq!(
            json_body(&p),
            json!({"model":"qwen3-tts-flash","input":{"text":r.text,"voice":"Cherry","language_type":"Auto"}})
        );
        e.model = "qwen3-tts-instruct-flash".into();
        e.base_url = p.endpoint.clone();
        r.locale = "Chinese".into();
        let p = provider.prepare(&e, &r).unwrap();
        assert_eq!(json_body(&p)["input"]["instructions"], "平静；用中文朗读");
        assert_eq!(json_body(&p)["input"]["language_type"], "Chinese");
        assert_eq!(provider.voices().len(), 4);
        r.speed = 2.5;
        assert!(
            json_body(&provider.prepare(&e, &r).unwrap())["input"]
                .get("speed")
                .is_none()
        );
    }
    #[test]
    fn pcm_and_signed_url_outputs() {
        let stream=b"data: {\"output\":{\"audio\":{\"data\":\"AQI=\"}}}\r\n\r\ndata: {\"output\":{\"finish_reason\":\"stop\",\"audio\":{\"data\":\"AwQ=\"}}}\r\n\r\n";
        let DecodedCloudSpeech::Audio(audio) = AlibabaCloudTtsProvider
            .decode_response("wav", stream.to_vec())
            .unwrap()
        else {
            panic!()
        };
        assert_eq!(&audio.bytes[44..], &[1, 2, 3, 4]);
        assert_eq!(
            u32::from_le_bytes(audio.bytes[24..28].try_into().unwrap()),
            24000
        );
        let stream=b"data: {\"output\":{\"finish_reason\":\"stop\",\"audio\":{\"url\":\"http://example.org/a.wav?Signature=fixture\"}}}\n\n";
        let DecodedCloudSpeech::Download(url) = AlibabaCloudTtsProvider
            .decode_response("wav", stream.to_vec())
            .unwrap()
        else {
            panic!()
        };
        assert!(url.ends_with("?Signature=fixture"));
    }
    #[test]
    fn reject_errors_truncation_bad_audio_and_inputs_without_secrets() {
        for stream in [
            "data: bad\n\n",
            "event: error\ndata: {}\n\n",
            "data: {\"code\":\"secret-error\"}\n\n",
            "data: {\"output\":{\"audio\":{\"data\":\"AQI=\"}}}\n\n",
            "data: {\"output\":{\"finish_reason\":\"length\"}}\n\n",
            "data: {\"output\":{\"finish_reason\":\"stop\",\"audio\":{\"data\":\"%%%\"}}}\n\n",
            "data: {\"output\":{\"finish_reason\":\"stop\",\"audio\":{\"url\":\"file:///tmp/secret\"}}}\n\n",
        ] {
            let err = AlibabaCloudTtsProvider
                .decode_response("wav", stream.as_bytes().to_vec())
                .err()
                .unwrap()
                .to_string();
            assert!(!err.contains("secret"));
        }
        let mut r = request();
        r.text = "甲".repeat(600);
        assert!(AlibabaCloudTtsProvider.prepare(&engine(), &r).is_ok());
        r.text.push('甲');
        assert!(AlibabaCloudTtsProvider.prepare(&engine(), &r).is_err());
        for url in [
            "file:///private-fixture",
            "https://private-fixture@example.org",
            "https://example.org?secret=private-fixture",
        ] {
            let mut e = engine();
            e.base_url = url.into();
            let err = AlibabaCloudTtsProvider
                .prepare(&e, &request())
                .err()
                .unwrap()
                .to_string();
            assert!(!err.contains("private-fixture"));
        }
        assert!(
            AlibabaCloudTtsProvider
                .decode_audio("wav", vec![1, 2])
                .is_err()
        );
    }
    #[test]
    fn incomplete_downloaded_wav_is_rejected() {
        let mut truncated = pcm16_mono_to_wav(&[1, 2, 3, 4], 24000).unwrap();
        assert!(
            AlibabaCloudTtsProvider
                .decode_audio("wav", truncated.clone())
                .is_ok()
        );
        truncated.pop();
        assert!(
            AlibabaCloudTtsProvider
                .decode_audio("wav", truncated)
                .is_err()
        );
    }
}
