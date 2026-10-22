//! 对照固定上游 MiMo 请求与 SSE PCM 拼接；不访问网络、数据库或 Flutter。
use super::cloud_tts::*;
use crate::LegadoResult;
use base64::{Engine, engine::general_purpose::STANDARD};
use serde_json::{Value, json};

pub struct MimoCloudTtsProvider;
impl CloudTtsProvider for MimoCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::Mimo
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        [
            "mimo_default",
            "冰糖",
            "茉莉",
            "苏打",
            "白桦",
            "Mia",
            "Chloe",
            "Milo",
            "Dean",
        ]
        .into_iter()
        .map(|id| CloudTtsVoiceDescriptor {
            id: id.into(),
            display_name: if id == "mimo_default" {
                "MiMo 默认".into()
            } else {
                id.into()
            },
            styles: [
                "开心", "悲伤", "愤怒", "惊讶", "恐惧", "厌恶", "小声", "平静",
            ]
            .into_iter()
            .map(str::to_owned)
            .collect(),
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
        if engine.provider != self.provider_type() {
            return Err(invalid("云端 Provider 类型不匹配"));
        }
        if !engine.enabled {
            return Err(invalid("云端朗读引擎已停用"));
        }
        if engine.id.trim().is_empty() {
            return Err(invalid("云端朗读引擎 ID 不能为空"));
        }
        if engine.api_key.trim().is_empty() || engine.api_key.chars().any(|c| c.is_control()) {
            return Err(invalid("MiMo API Key 为空或含无效字符"));
        }
        if engine.model.trim().is_empty() {
            return Err(invalid("MiMo 模型不能为空"));
        }
        if request.text.trim().is_empty() || request.voice_id.trim().is_empty() {
            return Err(invalid("MiMo 朗读文本或音色为空"));
        }
        if !request.format.eq_ignore_ascii_case("wav") {
            return Err(invalid("MiMo 仅支持 WAV 输出"));
        }
        let mut messages = Vec::new();
        if !request.instructions.trim().is_empty() {
            messages.push(json!({"role":"user","content":request.instructions}));
        }
        let content = if request.style.trim().is_empty() {
            request.text.clone()
        } else {
            format!("({}){}", request.style, request.text)
        };
        messages.push(json!({"role":"assistant","content":content}));
        let body = json!({"model":engine.model,"messages":messages,"audio":{"format":"pcm16","voice":request.voice_id},"stream":true});
        let base = if engine.base_url.trim().is_empty() {
            "https://api.xiaomimimo.com/v1"
        } else {
            engine.base_url.trim_end_matches('/')
        };
        let endpoint = if base.ends_with("/chat/completions") {
            base.to_owned()
        } else {
            format!("{base}/chat/completions")
        };
        let url = parse_service_url(
            &endpoint,
            "MiMo TTS 服务地址无效",
            "MiMo TTS 服务地址必须是无凭据、查询或片段的 HTTP(S) 地址",
        )?;
        Ok(PreparedCloudSpeech {
            authentication_headers: Vec::new(),
            endpoint: url.to_string(),
            credential_header: "api-key",
            authorization: engine.api_key.clone(),
            additional_headers: Vec::new(),
            response_kind: CloudSpeechResponseKind::EventStream,
            body: CloudSpeechBody::Json(body),
            response_format: "wav".into(),
        })
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        if format != "wav" {
            return Err(invalid("MiMo 仅支持 WAV 输出"));
        }
        let text = std::str::from_utf8(&bytes).map_err(|_| invalid("MiMo SSE 响应编码无效"))?;
        let mut pcm = Vec::new();
        let mut complete = false;
        for frame in sse::frames(text) {
            if frame.event.trim() == "error" {
                return Err(invalid("MiMo 返回错误事件，未生成音频"));
            }
            if let Some(payload) = frame.data {
                if payload.trim() == "[DONE]" {
                    complete = true;
                    break;
                }
                complete |= decode_event(&payload, &mut pcm)?;
            }
        }
        if !complete {
            return Err(invalid("MiMo 音频流未完成，拒绝缓存部分音频"));
        }
        let bytes = pcm16_mono_to_wav(&pcm, 24000)?;
        Ok(CloudTtsAudio {
            bytes,
            extension: "wav",
            content_type: "audio/wav",
        })
    }
}
fn decode_event(payload: &str, pcm: &mut Vec<u8>) -> LegadoResult<bool> {
    let value: Value =
        serde_json::from_str(payload).map_err(|_| invalid("MiMo SSE 事件 JSON 无效"))?;
    if value.get("error").is_some() {
        return Err(invalid("MiMo 返回错误事件，未生成音频"));
    }
    let choices = value
        .get("choices")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("MiMo SSE 事件缺少 choices"))?;
    let Some(choice) = choices.first() else {
        return Ok(false);
    };
    if let Some(encoded) = choice.pointer("/delta/audio/data").filter(|v| !v.is_null()) {
        let encoded = encoded
            .as_str()
            .ok_or_else(|| invalid("MiMo 音频数据不是 Base64 字符串"))?;
        let compact: Vec<u8> = encoded
            .bytes()
            .filter(|b| !b.is_ascii_whitespace())
            .collect();
        let bytes = STANDARD
            .decode(compact)
            .map_err(|_| invalid("MiMo 音频 Base64 无效"))?;
        pcm.extend_from_slice(&bytes);
    }
    match choice.get("finish_reason").filter(|v| !v.is_null()) {
        None => Ok(false),
        Some(reason) if reason.as_str() == Some("stop") => Ok(true),
        Some(_) => Err(invalid("MiMo 音频流被截断或异常结束")),
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
    fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "fixture".into(),
            provider: CloudTtsProviderType::Mimo,
            api_key: "fixture-private".into(),
            model: "mimo-v2.5-tts".into(),
            ..Default::default()
        }
    }
    fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: "中文\"引号\"😀\n换行".into(),
            voice_id: "冰糖".into(),
            format: "wav".into(),
            style: "平静".into(),
            instructions: "用中文朗读".into(),
            ..Default::default()
        }
    }
    fn stream(ending: &str) -> Vec<u8> {
        format!("data: {{\"choices\":[{{\"delta\":{{\"audio\":{{\"data\":\"AQI=\"}}}}}}]}}\r\n\r\ndata: {{\"choices\":[{{\"delta\":{{\"audio\":{{\"data\":\"AwQ=\"}}}}}}]}}\r\n\r\n{ending}").into_bytes()
    }
    #[test]
    fn exact_upstream_request_authentication_and_voices() {
        let prepared = MimoCloudTtsProvider.prepare(&engine(), &request()).unwrap();
        assert_eq!(
            prepared.endpoint,
            "https://api.xiaomimimo.com/v1/chat/completions"
        );
        assert_eq!(prepared.credential_header, "api-key");
        assert_eq!(prepared.authorization, "fixture-private");
        assert!(prepared.response_kind == CloudSpeechResponseKind::EventStream);
        assert_eq!(
            json_body(&prepared),
            json!({"model":"mimo-v2.5-tts","messages":[{"role":"user","content":"用中文朗读"},{"role":"assistant","content":"(平静)中文\"引号\"😀\n换行"}],"audio":{"format":"pcm16","voice":"冰糖"},"stream":true})
        );
        let voices = MimoCloudTtsProvider.voices();
        assert_eq!(
            voices.iter().map(|v| v.id.as_str()).collect::<Vec<_>>(),
            [
                "mimo_default",
                "冰糖",
                "茉莉",
                "苏打",
                "白桦",
                "Mia",
                "Chloe",
                "Milo",
                "Dean"
            ]
        );
        assert!(
            voices
                .iter()
                .all(|v| v.styles.len() == 8 && v.sample_rate == Some(24000))
        );
    }
    #[test]
    fn optional_instructions_and_playback_parameters_do_not_change_request() {
        let mut r = request();
        r.style.clear();
        r.instructions.clear();
        let p = MimoCloudTtsProvider.prepare(&engine(), &r).unwrap();
        assert_eq!(
            json_body(&p)["messages"],
            json!([{"role":"assistant","content":r.text}])
        );
        r.speed = 2.0;
        r.pitch = 0.5;
        r.volume = 0.5;
        assert_eq!(
            json_body(&MimoCloudTtsProvider.prepare(&engine(), &r).unwrap()),
            json_body(&p)
        );
        let mut e = engine();
        e.base_url = "https://fixture.example/v1/chat/completions/".into();
        assert_eq!(
            MimoCloudTtsProvider.prepare(&e, &r).unwrap().endpoint,
            "https://fixture.example/v1/chat/completions"
        );
    }
    #[test]
    fn invalid_input_is_rejected_without_exposing_credentials() {
        let mut e = engine();
        e.enabled = false;
        assert!(MimoCloudTtsProvider.prepare(&e, &request()).is_err());
        e.enabled = true;
        for base in [
            "file:///tmp",
            "https://fixture-private@example/v1",
            "https://example/v1?key=fixture-private",
        ] {
            e.base_url = base.into();
            let error = MimoCloudTtsProvider
                .prepare(&e, &request())
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("fixture-private"));
        }
        e = engine();
        e.api_key = "bad\nkey".into();
        assert!(MimoCloudTtsProvider.prepare(&e, &request()).is_err());
        let mut r = request();
        r.format = "mp3".into();
        assert!(MimoCloudTtsProvider.prepare(&engine(), &r).is_err());
    }
    #[test]
    fn ordered_pcm_chunks_produce_exact_wav() {
        let a = MimoCloudTtsProvider
            .decode_audio("wav", stream("data: [DONE]\n\n"))
            .unwrap();
        assert_eq!(a.bytes, pcm16_mono_to_wav(&[1, 2, 3, 4], 24000).unwrap());
        let b = MimoCloudTtsProvider
            .decode_audio(
                "wav",
                stream("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"),
            )
            .unwrap();
        assert_eq!(a.bytes, b.bytes);
    }
    #[test]
    fn metadata_comments_and_multiline_data_are_not_audio() {
        let body=b": keepalive\n\nevent: message\ndata: {\"choices\":[]}\n\ndata: {\"choices\":[{\n data: \"delta\":{\"audio\":{\"data\":null}}}]}\n\n";
        // 正式 SSE 多行字段每行都必须以 data: 开始。
        let mut input = String::from_utf8(body.to_vec())
            .unwrap()
            .replace("\n data:", "\ndata:")
            .into_bytes();
        input.extend(stream("data: [DONE]\n\n"));
        assert!(MimoCloudTtsProvider.decode_audio("wav", input).is_ok());
    }
    #[test]
    fn invalid_or_partial_events_cannot_create_audio() {
        for body in [
            stream(""),
            stream("data: [DONE]\n"),
            stream("data: {\"error\":{\"message\":\"fixture-private\"}}\n\n"),
            stream("data: broken\n\n"),
            stream("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"length\"}]}\n\n"),
            b"data: {\"choices\":[{\"delta\":{\"audio\":{\"data\":\"!!!\"}}}]}\n\ndata: [DONE]\n\n"
                .to_vec(),
            b"data: [DONE]\n\n".to_vec(),
        ] {
            let error = MimoCloudTtsProvider
                .decode_audio("wav", body)
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("fixture-private"));
        }
    }
}
