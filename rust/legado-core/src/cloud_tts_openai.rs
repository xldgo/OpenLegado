//! 对照固定上游 OpenAiCloudTtsProvider 的请求与音色规则。
use super::cloud_tts::*;
use crate::LegadoResult;
use serde_json::json;
pub struct OpenAiCloudTtsProvider;
impl CloudTtsProvider for OpenAiCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::OpenAiSpeech
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        [
            "alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer",
            "verse", "marin", "cedar",
        ]
        .into_iter()
        .map(|id| CloudTtsVoiceDescriptor {
            id: id.into(),
            styles: Vec::new(),
            sample_rate: None,
            display_name: format!("{}{}", id[..1].to_uppercase(), &id[1..]),
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
        if engine.api_key.trim().is_empty() {
            return Err(invalid("OpenAI API Key 不能为空"));
        }
        if engine.api_key.chars().any(|c| c.is_control()) {
            return Err(invalid("OpenAI API Key 含无效字符"));
        }
        if engine.model.trim().is_empty() {
            return Err(invalid("OpenAI TTS 模型不能为空"));
        }
        if request.voice_id.trim().is_empty() {
            return Err(invalid("OpenAI 音色不能为空"));
        }
        if request.text.trim().is_empty() {
            return Err(invalid("朗读文本为空"));
        }
        if request.text.chars().count() > OPENAI_MAX_CHARACTERS {
            return Err(invalid(
                "OpenAI 单次朗读文本超过 4096 字符，需由朗读会话分片",
            ));
        }
        if !request.speed.is_finite() || !(0.25..=4.0).contains(&request.speed) {
            return Err(invalid("OpenAI TTS 速度必须在 0.25 到 4.0 之间"));
        }
        let format = request.format.to_lowercase();
        if !["mp3", "opus", "aac", "flac", "wav", "pcm"].contains(&format.as_str()) {
            return Err(invalid("OpenAI TTS 音频格式不支持"));
        }
        let instructions = [request.style.as_str(), request.instructions.as_str()]
            .into_iter()
            .filter(|s| !s.trim().is_empty())
            .collect::<Vec<_>>()
            .join(" ");
        let voice = if request.voice_id.starts_with("voice_") {
            json!({"id":request.voice_id})
        } else {
            json!(request.voice_id)
        };
        let mut body = json!({"model":engine.model,"input":request.text,"voice":voice,"response_format":format,"speed":request.speed});
        if !instructions.is_empty() && !engine.model.starts_with("tts-1") {
            body["instructions"] = json!(instructions);
        }
        let base = if engine.base_url.trim().is_empty() {
            "https://api.openai.com/v1"
        } else {
            engine.base_url.trim_end_matches('/')
        };
        let endpoint = if base.ends_with("/audio/speech") {
            base.to_owned()
        } else {
            format!("{base}/audio/speech")
        };
        let url = parse_service_url(
            &endpoint,
            "OpenAI TTS 服务地址无效",
            "OpenAI TTS 服务地址必须是无凭据、查询或片段的 HTTP(S) 地址",
        )?;
        Ok(PreparedCloudSpeech {
            authentication_headers: Vec::new(),
            endpoint: url.to_string(),
            credential_header: "Authorization",
            additional_headers: Vec::new(),
            response_kind: CloudSpeechResponseKind::AudioBytes,
            authorization: format!("Bearer {}", engine.api_key),
            body: CloudSpeechBody::Json(body),
            response_format: format,
        })
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        if bytes.is_empty() {
            return Err(invalid("OpenAI TTS 没有返回音频数据"));
        }
        let (extension, content_type) = match format {
            "mp3" => ("mp3", "audio/mpeg"),
            "opus" => ("ogg", "audio/ogg"),
            "aac" => ("aac", "audio/aac"),
            "flac" => ("flac", "audio/flac"),
            "wav" => ("wav", "audio/wav"),
            "pcm" => {
                return Ok(CloudTtsAudio {
                    bytes: pcm16_mono_to_wav(&bytes, 24000)?,
                    extension: "wav",
                    content_type: "audio/wav",
                });
            }
            _ => return Err(invalid("OpenAI TTS 音频格式不支持")),
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
    fn json_body(p: &super::PreparedCloudSpeech) -> serde_json::Value {
        let super::CloudSpeechBody::Json(value) = &p.body else {
            panic!("预期 JSON 请求")
        };
        value.clone()
    }
    use super::*;
    fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "engine".into(),
            api_key: "fixture-key".into(),
            ..Default::default()
        }
    }
    fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: "中文 \"引号\" 😀\n换行".into(),
            voice_id: "coral".into(),
            style: "平静".into(),
            instructions: "用中文朗读".into(),
            ..Default::default()
        }
    }
    #[test]
    fn exact_upstream_request_and_endpoint() {
        let p = OpenAiCloudTtsProvider
            .prepare(&engine(), &request())
            .unwrap();
        assert_eq!(p.endpoint, "https://api.openai.com/v1/audio/speech");
        assert_eq!(p.authorization, "Bearer fixture-key");
        assert_eq!(
            json_body(&p),
            json!({"model":"gpt-4o-mini-tts","input":"中文 \"引号\" 😀\n换行","voice":"coral","response_format":"mp3","speed":1.0,"instructions":"平静 用中文朗读"})
        );
        let mut e = engine();
        e.base_url = "https://local.example/v1/audio/speech/".into();
        e.model = "tts-1-hd".into();
        let mut r = request();
        r.voice_id = "voice_123".into();
        r.format = "WAV".into();
        let p = OpenAiCloudTtsProvider.prepare(&e, &r).unwrap();
        assert_eq!(p.endpoint, "https://local.example/v1/audio/speech");
        assert_eq!(json_body(&p)["voice"], json!({"id":"voice_123"}));
        assert!(json_body(&p).get("instructions").is_none());
        assert_eq!(json_body(&p)["response_format"], "wav");
    }
    #[test]
    fn validations_and_secrets_do_not_export() {
        let mut e = engine();
        e.enabled = false;
        assert!(OpenAiCloudTtsProvider.prepare(&e, &request()).is_err());
        e.enabled = true;
        for speed in [f64::NAN, f64::INFINITY, 0.24, 4.01] {
            let mut r = request();
            r.speed = speed;
            assert!(OpenAiCloudTtsProvider.prepare(&e, &r).is_err());
        }
        for url in [
            "file:///tmp",
            "https://fixture-key@example/v1",
            "https://example/v1?key=fixture-key",
            "https://example/v1#key",
        ] {
            e.base_url = url.into();
            let error = OpenAiCloudTtsProvider
                .prepare(&e, &request())
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("fixture-key"));
        }
        assert!(!format!("{e:?}").contains("fixture-key"));
        assert!(!serde_json::to_string(&e).unwrap().contains("fixture-key"));
        assert!(serde_json::from_str::<CloudTtsProviderType>("\"not_supported\"").is_err());
    }
    #[test]
    fn all_formats_and_pcm_header() {
        assert_eq!(OpenAiCloudTtsProvider.voices().len(), 13);
        for format in ["mp3", "opus", "aac", "flac", "wav"] {
            let audio = OpenAiCloudTtsProvider
                .decode_audio(format, vec![1, 2])
                .unwrap();
            assert_eq!(audio.bytes, vec![1, 2]);
        }
        let audio = OpenAiCloudTtsProvider
            .decode_audio("pcm", vec![1, 2, 3, 4])
            .unwrap();
        assert_eq!(audio.extension, "wav");
        assert_eq!(&audio.bytes[..4], b"RIFF");
        assert_eq!(&audio.bytes[8..12], b"WAVE");
        assert_eq!(
            u32::from_le_bytes(audio.bytes[24..28].try_into().unwrap()),
            24000
        );
        assert_eq!(&audio.bytes[44..], &[1, 2, 3, 4]);
        assert!(pcm16_mono_to_wav(&[1], 24000).is_err());
        assert!(pcm16_mono_to_wav(&[], 24000).is_err());
        assert!(pcm16_mono_to_wav(&[1, 2], u32::MAX).is_err());
    }
    #[test]
    fn empty_overlong_and_unsupported_inputs_are_explicit_errors() {
        let e = engine();
        let mut r = request();
        r.text = " ".into();
        assert!(OpenAiCloudTtsProvider.prepare(&e, &r).is_err());
        r.text = "😀".repeat(4096);
        assert!(OpenAiCloudTtsProvider.prepare(&e, &r).is_ok());
        r.text.push('甲');
        assert!(OpenAiCloudTtsProvider.prepare(&e, &r).is_err());
        r = request();
        r.format = "json".into();
        assert!(OpenAiCloudTtsProvider.prepare(&e, &r).is_err());
        r = request();
        r.voice_id = "".into();
        assert!(OpenAiCloudTtsProvider.prepare(&e, &r).is_err());
    }
}
