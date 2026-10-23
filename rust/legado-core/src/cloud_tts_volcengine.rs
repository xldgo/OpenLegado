//! 火山 V1 纯协议适配；稳定请求与发送时唯一编号分开，不持有网络或播放状态。
use super::cloud_tts::*;
use crate::LegadoResult;
use base64::{Engine, engine::general_purpose::STANDARD};
use serde::Deserialize;
use serde_json::json;

pub struct VolcengineCloudTtsProvider;

impl CloudTtsProvider for VolcengineCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::Volcengine
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        [
            ("BV001_streaming", "通用女声", "Female"),
            ("BV002_streaming", "通用男声", "Male"),
            ("BV700_streaming", "灿灿", "Female"),
            ("BV701_streaming", "擎苍", "Male"),
        ]
        .into_iter()
        .map(|(id, name, gender)| CloudTtsVoiceDescriptor {
            id: id.into(),
            display_name: name.into(),
            locale: "zh-CN".into(),
            gender: gender.into(),
            ..Default::default()
        })
        .collect()
    }
    fn prepare(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        if engine.provider != self.provider_type()
            || !engine.enabled
            || engine.id.trim().is_empty()
            || engine.app_id.trim().is_empty()
            || engine.app_id.chars().any(char::is_control)
        {
            return Err(invalid("火山引擎类型、状态或 App ID 无效"));
        }
        if engine.api_key.trim().is_empty()
            || engine
                .api_key
                .chars()
                .any(|c| c.is_control() || c.is_whitespace())
        {
            return Err(invalid("火山 Access Token 无效"));
        }
        if request.text.trim().is_empty()
            || request.text.len() > VOLCENGINE_MAX_UTF8_BYTES as usize
            || request.voice_id.trim().is_empty()
        {
            return Err(invalid("火山音色或文本无效，每片最多 1024 UTF-8 字节"));
        }
        if !request.speed.is_finite()
            || !(0.2..=3.0).contains(&request.speed)
            || !request.pitch.is_finite()
            || !(0.1..=3.0).contains(&request.pitch)
            || !request.volume.is_finite()
            || !(0.1..=3.0).contains(&request.volume)
        {
            return Err(invalid("火山语速须为 0.2～3，音调和音量须为 0.1～3"));
        }
        let format = request.format.to_ascii_lowercase();
        if !matches!(format.as_str(), "mp3" | "ogg_opus" | "wav" | "pcm") {
            return Err(invalid("火山音频格式不支持"));
        }
        let endpoint = if engine.base_url.trim().is_empty() {
            "https://openspeech.bytedance.com/api/v1/tts"
        } else {
            engine.base_url.trim()
        };
        let url = parse_service_url(
            endpoint,
            "火山服务地址无效",
            "火山地址须为无凭据、查询或片段的 HTTP(S) 完整端点",
        )?;
        let cluster = if engine.model.trim().is_empty() {
            "volcano_tts"
        } else {
            engine.model.as_str()
        };
        if cluster.chars().any(char::is_control) {
            return Err(invalid("火山业务集群无效"));
        }
        let mut audio = json!({"voice_type":request.voice_id,"encoding":format,
            "speed_ratio":request.speed,"volume_ratio":request.volume,"pitch_ratio":request.pitch});
        if !request.style.trim().is_empty() {
            audio["emotion"] = request.style.clone().into();
        }
        Ok(PreparedCloudSpeech {
            endpoint: url.to_string(),
            credential_header: "Authorization",
            authorization: format!("Bearer;{}", engine.api_key),
            response_kind: CloudSpeechResponseKind::JsonAudio,
            additional_headers: Vec::new(),
            authentication_headers: Vec::new(),
            body: CloudSpeechBody::Json(
                json!({"app":{"appid":engine.app_id,"token":engine.api_key,"cluster":cluster},
                "user":{"uid":"legado"},"audio":audio,"request":{"text":request.text,"text_type":"plain","operation":"query"}}),
            ),
            response_format: format,
        })
    }
    fn prepare_for_send(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        self.prepare_with_request_id(engine, request, uuid::Uuid::new_v4())
    }
    fn decode_response(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<DecodedCloudSpeech> {
        #[derive(Deserialize)]
        struct Envelope {
            code: i64,
            data: Option<String>,
            sequence: Option<i64>,
        }
        let envelope: Envelope =
            serde_json::from_slice(&bytes).map_err(|_| invalid("火山音频响应格式无效"))?;
        if !matches!(envelope.code, 0 | 3000) {
            return Err(invalid(&format!("火山合成失败，状态码 {}", envelope.code)));
        }
        if envelope.sequence.is_some_and(|s| s >= 0) {
            return Err(invalid("火山合成未完成，拒绝部分音频"));
        }
        let data = envelope
            .data
            .filter(|s| !s.trim().is_empty())
            .ok_or_else(|| invalid("火山未返回音频数据"))?;
        let encoded = data
            .bytes()
            .filter(|b| !b.is_ascii_whitespace())
            .collect::<Vec<_>>();
        let audio = STANDARD
            .decode(encoded)
            .map_err(|_| invalid("火山音频 Base64 无效"))?;
        self.decode_audio(format, audio)
            .map(DecodedCloudSpeech::Audio)
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        if format == "pcm" {
            return Ok(CloudTtsAudio {
                bytes: pcm16_mono_to_wav(&bytes, 24000)?,
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
            "ogg_opus" if bytes.starts_with(b"OggS") => ("ogg", "audio/ogg"),
            "wav" if bytes.len() > 44 && bytes.starts_with(b"RIFF") && &bytes[8..12] == b"WAVE" => {
                let declared =
                    u32::from_le_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]) as usize;
                if declared.checked_add(8) != Some(bytes.len()) {
                    return Err(invalid("火山 WAV 音频长度不完整"));
                }
                ("wav", "audio/wav")
            }
            _ => return Err(invalid("火山未返回所请求的完整音频格式")),
        };
        Ok(CloudTtsAudio {
            bytes,
            extension,
            content_type,
        })
    }
}
impl VolcengineCloudTtsProvider {
    /// 注入请求编号便于验证稳定请求只增加唯一编号，不修改音频参数。
    pub fn prepare_with_request_id(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
        id: uuid::Uuid,
    ) -> LegadoResult<PreparedCloudSpeech> {
        let mut prepared = self.prepare(engine, request)?;
        let CloudSpeechBody::Json(body) = &mut prepared.body else {
            return Err(invalid("火山请求体类型无效"));
        };
        body["request"]["reqid"] = id.to_string().into();
        Ok(prepared)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "volc".into(),
            provider: CloudTtsProviderType::Volcengine,
            app_id: "app-fixture".into(),
            api_key: "token-private".into(),
            model: "volcano_tts".into(),
            ..Default::default()
        }
    }
    fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: "甲😀\n引号\"".into(),
            voice_id: "BV001_streaming".into(),
            style: "happy".into(),
            speed: 0.2,
            pitch: 0.1,
            volume: 3.0,
            ..Default::default()
        }
    }
    fn body(prepared: PreparedCloudSpeech) -> serde_json::Value {
        let CloudSpeechBody::Json(body) = prepared.body else {
            panic!("预期 JSON")
        };
        body
    }
    #[test]
    fn exact_request_and_unique_request_ids_do_not_change_stable_body() {
        let provider = VolcengineCloudTtsProvider;
        let stable = provider.prepare(&engine(), &request()).unwrap();
        assert_eq!(
            stable.endpoint,
            "https://openspeech.bytedance.com/api/v1/tts"
        );
        assert_eq!(stable.authorization, "Bearer;token-private");
        assert!(stable.response_kind == CloudSpeechResponseKind::JsonAudio);
        let stable = body(stable);
        assert_eq!(
            stable,
            json!({"app":{"appid":"app-fixture","token":"token-private","cluster":"volcano_tts"},"user":{"uid":"legado"},"audio":{"voice_type":"BV001_streaming","encoding":"mp3","speed_ratio":0.2,"pitch_ratio":0.1,"volume_ratio":3.0,"emotion":"happy"},"request":{"text":request().text,"text_type":"plain","operation":"query"}})
        );
        let mut first = body(provider.prepare_for_send(&engine(), &request()).unwrap());
        let mut second = body(provider.prepare_for_send(&engine(), &request()).unwrap());
        let a = first["request"]
            .as_object_mut()
            .unwrap()
            .remove("reqid")
            .unwrap();
        let b = second["request"]
            .as_object_mut()
            .unwrap()
            .remove("reqid")
            .unwrap();
        assert_ne!(a, b);
        uuid::Uuid::parse_str(a.as_str().unwrap()).unwrap();
        assert_eq!(first, stable);
        assert_eq!(second, stable);
    }
    #[test]
    fn base64_audio_formats_and_terminal_response_are_explicit() {
        let provider = VolcengineCloudTtsProvider;
        for (format, bytes, extension) in [
            ("pcm", vec![0, 1, 0, 2], "wav"),
            (
                "wav",
                pcm16_mono_to_wav(&[0, 1, 0, 2], 24000).unwrap(),
                "wav",
            ),
            ("mp3", b"ID3fixture".to_vec(), "mp3"),
            ("ogg_opus", b"OggSfixture".to_vec(), "ogg"),
        ] {
            for code in [0, 3000] {
                let json = json!({"code":code,"sequence":-1,"data":format!(" \n{}\n",STANDARD.encode(&bytes))});
                let DecodedCloudSpeech::Audio(audio) = provider
                    .decode_response(format, json.to_string().into_bytes())
                    .unwrap()
                else {
                    panic!("预期音频")
                };
                assert_eq!(audio.extension, extension);
                if format == "pcm" {
                    assert_eq!(&audio.bytes[24..28], &24000u32.to_le_bytes());
                } else {
                    assert_eq!(audio.bytes, bytes);
                }
            }
        }
    }
    #[test]
    fn errors_truncated_audio_and_missing_code_never_expose_message() {
        let provider = VolcengineCloudTtsProvider;
        for envelope in [
            json!({"data":STANDARD.encode(b"ID3fixture")}),
            json!({"code":3001,"message":"token-private"}),
            json!({"code":3000}),
            json!({"code":3000,"data":""}),
            json!({"code":3000,"data":"%%%"}),
            json!({"code":3000,"data":STANDARD.encode(b"not audio")}),
            json!({"code":3000,"sequence":1,"data":STANDARD.encode(b"ID3fixture")}),
        ] {
            let error = provider
                .decode_response("mp3", envelope.to_string().into_bytes())
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("token-private"));
        }
        assert!(provider.decode_audio("pcm", vec![1]).is_err());
        let mut wav = pcm16_mono_to_wav(&[0, 1], 24000).unwrap();
        wav.pop();
        assert!(provider.decode_audio("wav", wav).is_err());
    }
    #[test]
    fn validation_covers_bytes_ranges_configuration_and_secrets() {
        let provider = VolcengineCloudTtsProvider;
        for index in 0..8 {
            let mut engine = engine();
            let mut request = request();
            match index {
                0 => engine.app_id.clear(),
                1 => engine.api_key = "bad\nsecret".into(),
                2 => engine.base_url = "https://token-private@example.com".into(),
                3 => request.speed = f64::NAN,
                4 => request.volume = 0.0,
                5 => request.pitch = 3.1,
                6 => request.format = "flac".into(),
                _ => request.text = "甲".repeat(342),
            }
            assert!(provider.prepare(&engine, &request).is_err());
        }
        let mut engine = engine();
        engine.model.clear();
        assert_eq!(
            body(provider.prepare(&engine, &request()).unwrap())["app"]["cluster"],
            "volcano_tts"
        );
        assert!(
            !serde_json::to_string(&engine)
                .unwrap()
                .contains("token-private")
        );
        assert!(!format!("{engine:?}").contains("token-private"));
        assert_eq!(
            provider
                .voices()
                .iter()
                .map(|v| v.id.as_str())
                .collect::<Vec<_>>(),
            [
                "BV001_streaming",
                "BV002_streaming",
                "BV700_streaming",
                "BV701_streaming"
            ]
        );
    }
}
