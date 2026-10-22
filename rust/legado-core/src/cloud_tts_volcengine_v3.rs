//! 豆包 2.0 的 V3 SSE 纯协议；与 V1 独立，不执行网络或隐式回退。
use super::cloud_tts::*;
use crate::LegadoResult;
use base64::{Engine, engine::general_purpose::STANDARD};
use serde::Deserialize;
use serde_json::json;

pub struct VolcengineV3CloudTtsProvider;
impl CloudTtsProvider for VolcengineV3CloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::VolcengineV3
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        [
            ("zh_female_vv_uranus_bigtts", "Vivi 2.0"),
            ("zh_female_xiaohe_uranus_bigtts", "小何 2.0"),
            ("zh_male_m191_uranus_bigtts", "云舟 2.0"),
            ("zh_male_taocheng_uranus_bigtts", "小天 2.0"),
        ]
        .into_iter()
        .map(|(id, name)| CloudTtsVoiceDescriptor {
            id: id.into(),
            display_name: name.into(),
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
            || engine.model != "seed-tts-2.0"
        {
            return Err(invalid("火山 V3 本接口须使用 seed-tts-2.0 资源"));
        }
        if engine.api_key.is_empty()
            || engine
                .api_key
                .chars()
                .any(|c| c.is_control() || c.is_whitespace())
        {
            return Err(invalid("火山 V3 API Key 无效"));
        }
        if request.text.trim().is_empty()
            || request.text.len() > 1024
            || request.voice_id.trim().is_empty()
            || request.voice_id.chars().any(char::is_control)
            || request.voice_id.starts_with("BV")
        {
            return Err(invalid(
                "火山 V3 音色或文本无效；请使用 2.0 音色，每片最多 1024 UTF-8 字节",
            ));
        }
        if [request.speed, request.volume, request.pitch]
            .into_iter()
            .any(|v| !v.is_finite() || !(0.5..=2.0).contains(&v))
        {
            return Err(invalid("火山 V3 合成语速、音调和音量倍率须为 0.5～2"));
        }
        let (format, rate) = match request.format.as_str() {
            "mp3" => ("mp3", 24000),
            "ogg_opus" => ("ogg_opus", 48000),
            "pcm" | "wav" => ("pcm", 24000),
            _ => return Err(invalid("火山 V3 音频格式不支持")),
        };
        if request.sample_rate.is_some_and(|value| value != rate) {
            return Err(invalid("火山 V3 使用 24 kHz MP3/PCM 或 48 kHz Ogg"));
        }
        let endpoint = if engine.base_url.trim().is_empty() {
            "https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse"
        } else {
            engine.base_url.trim()
        };
        let url = parse_service_url(
            endpoint,
            "火山 V3 服务端点无效",
            "火山 V3 须使用无凭据、查询或片段的 HTTP(S) SSE 完整端点",
        )?;
        let mut additions =
            json!({"post_process":{"pitch":(12.0 * request.pitch.log2()).round() as i32}});
        let directions = [&request.style, &request.instructions]
            .into_iter()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join("\n");
        if !directions.is_empty() {
            additions["context_texts"] = json!([directions]);
        }
        Ok(PreparedCloudSpeech {
            endpoint: url.into(),
            credential_header: "X-Api-Key",
            authorization: engine.api_key.clone(),
            response_kind: CloudSpeechResponseKind::EventStream,
            additional_headers: vec![
                ("X-Api-Resource-Id", engine.model.clone()),
                ("Accept", "text/event-stream".into()),
            ],
            authentication_headers: Vec::new(),
            response_format: request.format.clone(),
            body: CloudSpeechBody::Json(
                json!({"req_params":{"text":request.text,"speaker":request.voice_id,
                "audio_params":{"format":format,"sample_rate":rate,
                    "speech_rate":((request.speed-1.0)*100.0).round() as i32,
                    "loudness_rate":((request.volume-1.0)*100.0).round() as i32},
                "additions":additions.to_string()}}),
            ),
        })
    }
    fn prepare_for_send(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        let mut prepared = self.prepare(engine, request)?;
        // 请求编号只用于服务端追踪，不进入稳定缓存键。
        prepared
            .authentication_headers
            .push(("X-Api-Request-Id", uuid::Uuid::new_v4().to_string()));
        Ok(prepared)
    }
    fn decode_response(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<DecodedCloudSpeech> {
        let stream = std::str::from_utf8(&bytes).map_err(|_| invalid("火山 V3 SSE 编码无效"))?;
        let (mut audio, mut complete) = (Vec::new(), false);
        for frame in sse::frames(stream) {
            if let Some(payload) = frame.data {
                decode_event(frame.event.trim(), &payload, &mut audio, &mut complete)?;
            } else if matches!(frame.event.trim(), "151" | "153" | "error") {
                return Err(invalid("火山 V3 返回取消或错误事件"));
            }
        }
        if !complete {
            return Err(invalid("火山 V3 音频未完成，拒绝部分结果"));
        }
        self.decode_audio(format, audio)
            .map(DecodedCloudSpeech::Audio)
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        let (bytes, extension, content_type) = match format {
            "pcm" | "wav" => (pcm16_mono_to_wav(&bytes, 24000)?, "wav", "audio/wav"),
            "mp3"
                if bytes.len() >= 3
                    && (bytes.starts_with(b"ID3")
                        || bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0) =>
            {
                (bytes, "mp3", "audio/mpeg")
            }
            "ogg_opus" if bytes.starts_with(b"OggS") => (bytes, "ogg", "audio/ogg"),
            _ => return Err(invalid("火山 V3 返回空音频或格式不匹配")),
        };
        Ok(CloudTtsAudio {
            bytes,
            extension,
            content_type,
        })
    }
}

fn decode_event(
    event: &str,
    payload: &str,
    audio: &mut Vec<u8>,
    complete: &mut bool,
) -> LegadoResult<()> {
    if matches!(event, "151" | "153" | "error") {
        return Err(invalid("火山 V3 合成取消或失败"));
    }
    if payload.trim() == "[DONE]" {
        return if *complete {
            Ok(())
        } else {
            Err(invalid("火山 V3 缺少成功完成事件"))
        };
    }
    if *complete {
        return Err(invalid("火山 V3 完成后仍返回数据"));
    }
    #[derive(Deserialize)]
    struct Frame {
        code: i64,
        data: Option<String>,
    }
    let frame: Frame =
        serde_json::from_str(payload).map_err(|_| invalid("火山 V3 事件 JSON 无效"))?;
    if !matches!(frame.code, 0 | 20000000) {
        return Err(invalid(&format!("火山 V3 合成失败，状态码 {}", frame.code)));
    }
    if let Some(data) = frame.data.filter(|s| !s.is_empty()) {
        let compact = data
            .bytes()
            .filter(|b| !b.is_ascii_whitespace())
            .collect::<Vec<_>>();
        let decoded = STANDARD
            .decode(compact)
            .map_err(|_| invalid("火山 V3 音频 Base64 无效"))?;
        if decoded.is_empty() {
            return Err(invalid("火山 V3 音频分片为空"));
        }
        audio.extend(decoded);
    } else if event == "352" {
        return Err(invalid("火山 V3 音频事件缺少数据"));
    }
    *complete = frame.code == 20000000 || event == "152";
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "v3".into(),
            provider: CloudTtsProviderType::VolcengineV3,
            model: "seed-tts-2.0".into(),
            api_key: "private-key".into(),
            ..Default::default()
        }
    }
    fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: " 原文😀\n\"甲\" ".into(),
            voice_id: "zh_female_vv_uranus_bigtts".into(),
            style: "平静".into(),
            instructions: "慢读".into(),
            speed: 0.5,
            pitch: 2.0,
            volume: 2.0,
            ..Default::default()
        }
    }
    fn stream(format: &str, stream: &str) -> LegadoResult<CloudTtsAudio> {
        let DecodedCloudSpeech::Audio(audio) =
            VolcengineV3CloudTtsProvider.decode_response(format, stream.as_bytes().to_vec())?
        else {
            panic!("预期音频")
        };
        Ok(audio)
    }
    fn frame(event: &str, code: i64, bytes: &[u8]) -> String {
        format!(
            "event: {event}\r\ndata: {}\r\n\r\n",
            json!({"code":code,"data":STANDARD.encode(bytes)})
        )
    }
    #[test]
    fn exact_request_and_uuid_do_not_change_stable_cache_identity() {
        let provider = VolcengineV3CloudTtsProvider;
        let stable = provider.prepare(&engine(), &request()).unwrap();
        assert_eq!(
            stable.endpoint,
            "https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse"
        );
        assert_eq!(stable.credential_header, "X-Api-Key");
        assert_eq!(stable.authorization, "private-key");
        assert_eq!(
            stable.additional_headers[0],
            ("X-Api-Resource-Id", "seed-tts-2.0".into())
        );
        assert!(stable.authentication_headers.is_empty());
        let CloudSpeechBody::Json(body) = stable.body else {
            panic!("预期 JSON")
        };
        assert_eq!(body["req_params"]["text"], request().text);
        assert_eq!(
            body["req_params"]["audio_params"],
            json!({"format":"mp3","sample_rate":24000,"speech_rate":-50,"loudness_rate":100})
        );
        let additions: serde_json::Value =
            serde_json::from_str(body["req_params"]["additions"].as_str().unwrap()).unwrap();
        assert_eq!(
            additions,
            json!({"post_process":{"pitch":12},"context_texts":["平静\n慢读"]})
        );
        let a = provider.prepare_for_send(&engine(), &request()).unwrap();
        let b = provider.prepare_for_send(&engine(), &request()).unwrap();
        assert_ne!(a.authentication_headers, b.authentication_headers);
        uuid::Uuid::parse_str(&a.authentication_headers[0].1).unwrap();
        assert_eq!(a.body.encode(), b.body.encode());
        assert_eq!(provider.voices().len(), 4);
    }
    #[test]
    fn ordered_pcm_chunks_and_successful_terminal_events() {
        let data = frame("352", 0, &[1]) + &frame("352", 0, &[0, 2, 0]);
        for terminal in [frame("152", 0, &[]), frame("", 20000000, &[])] {
            let decoded = stream("wav", &(data.clone() + &terminal)).unwrap();
            assert_eq!(
                decoded.bytes,
                pcm16_mono_to_wav(&[1, 0, 2, 0], 24000).unwrap()
            );
            assert_eq!(decoded.extension, "wav");
        }
        for (format, bytes, extension) in [
            ("mp3", b"ID3fixture".as_slice(), "mp3"),
            ("ogg_opus", b"OggSfixture".as_slice(), "ogg"),
        ] {
            let decoded =
                stream(format, &(frame("352", 0, bytes) + &frame("152", 0, &[]))).unwrap();
            assert_eq!(decoded.bytes, bytes);
            assert_eq!(decoded.extension, extension);
        }
    }
    #[test]
    fn failures_and_truncation_never_produce_audio_or_expose_private_payload() {
        let data = frame("352", 0, b"ID3fixture");
        for value in [
            data.clone(),
            data.clone() + frame("152", 0, &[]).trim_end(),
            data.clone() + "data: [DONE]\n\n",
            data.clone() + &frame("153", 0, &[]),
            data.clone() + &frame("151", 0, &[]),
            data.clone() + &frame("152", 55000000, &[]),
            data.clone() + "data: {\"code\":0,\"data\":\"%%%private-key\"}\n\n",
            frame("152", 0, &[]),
            "data: {\"message\":\"private-key\"}\n\n".into(),
            data.clone() + &frame("152", 0, &[]) + &data,
        ] {
            assert!(
                !stream("mp3", &value)
                    .err()
                    .unwrap()
                    .to_string()
                    .contains("private-key")
            );
        }
    }
    #[test]
    fn invalid_config_ranges_and_legacy_voices_are_explicit_errors() {
        for i in 0..8 {
            let mut e = engine();
            let mut r = request();
            match i {
                0 => e.model = "volcano_tts".into(),
                1 => e.api_key = "bad\nkey".into(),
                2 => r.voice_id = "BV001_streaming".into(),
                3 => r.text = "甲".repeat(342),
                4 => r.speed = 0.49,
                5 => r.pitch = f64::NAN,
                6 => r.sample_rate = Some(16000),
                _ => e.base_url = "https://private-key@example.com".into(),
            }
            assert!(VolcengineV3CloudTtsProvider.prepare(&e, &r).is_err());
        }
        let mut r = request();
        r.format = "ogg_opus".into();
        r.sample_rate = Some(48000);
        assert!(VolcengineV3CloudTtsProvider.prepare(&engine(), &r).is_ok());
    }
}
