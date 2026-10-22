//! Gemini 3.8 单音色协议；正文与风格隔离，不持有网络、缓存或播放状态。
use super::cloud_tts::*;
use crate::LegadoResult;
use base64::{Engine, engine::general_purpose::STANDARD};
use serde::Deserialize;
use serde_json::json;

pub struct GeminiCloudTtsProvider;

const VOICES: &[&str] = &[
    "Kore",
    "Puck",
    "Charon",
    "Fenrir",
    "Leda",
    "Orus",
    "Aoede",
    "Callirrhoe",
    "Autonoe",
    "Enceladus",
    "Iapetus",
    "Umbriel",
    "Algieba",
    "Despina",
    "Erinome",
    "Algenib",
    "Rasalgethi",
    "Laomedeia",
    "Achernar",
    "Alnilam",
    "Schedar",
    "Gacrux",
    "Pulcherrima",
    "Achird",
    "Zubenelgenubi",
    "Vindemiatrix",
    "Sadachbia",
    "Sadaltager",
    "Sulafat",
    "Zephyr",
];

impl CloudTtsProvider for GeminiCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::GeminiTts
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        VOICES
            .iter()
            .map(|&id| CloudTtsVoiceDescriptor {
                id: id.into(),
                display_name: id.into(),
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
            return Err(invalid("Gemini 引擎类型或状态无效"));
        }
        if engine.api_key.is_empty()
            || engine
                .api_key
                .chars()
                .any(|c| c.is_control() || c.is_whitespace())
        {
            return Err(invalid("Gemini API Key 无效"));
        }
        let model = engine
            .model
            .trim()
            .strip_prefix("models/")
            .unwrap_or(engine.model.trim());
        if !matches!(model, "gemini-3.8-flash-tts" | "gemini-3.8-flash-lite-tts") {
            return Err(invalid("Gemini 本接口仅支持 3.8 Flash/Flash Lite TTS 模型"));
        }
        if request.text.trim().is_empty()
            || request.text.encode_utf16().count() > 4000
            || request.voice_id.trim().is_empty()
            || request.voice_id.chars().any(char::is_control)
        {
            return Err(invalid("Gemini 音色或文本无效，每片最多 4000 UTF-16 单元"));
        }
        if request.format != "wav" || request.sample_rate.is_some_and(|r| r != 24000) {
            return Err(invalid("Gemini 本接口使用 24 kHz WAV 输出"));
        }
        let base = if engine.base_url.trim().is_empty() {
            "https://generativelanguage.googleapis.com/v1beta"
        } else {
            engine.base_url.trim()
        };
        let mut url = parse_service_url(
            base,
            "Gemini 服务基址无效",
            "Gemini 基址须为无凭据、查询或片段的 HTTP(S) 地址",
        )?;
        let path = url.path().trim_end_matches('/');
        let path = path.strip_suffix("/openai").unwrap_or(path);
        url.set_path(&format!("{path}/models/{model}:generateContent"));
        let mut part = json!({"text": request.text});
        let style = [&request.style, &request.instructions]
            .into_iter()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join("\n");
        if !style.is_empty() {
            part["speech_metadata"] = json!({"style": style});
        }
        Ok(PreparedCloudSpeech {
            endpoint: url.into(),
            credential_header: "x-goog-api-key",
            authorization: engine.api_key.clone(),
            response_kind: CloudSpeechResponseKind::JsonAudio,
            additional_headers: Vec::new(),
            authentication_headers: Vec::new(),
            response_format: "wav".into(),
            body: CloudSpeechBody::Json(json!({
                "contents":[{"role":"user", "parts":[part]}],
                "generationConfig": {"responseModalities":["AUDIO"],
                    "speechConfig":{"voiceConfig":{"voice":request.voice_id}},
                    "responseFormat":{"audio":{"mimeType":"AUDIO_WAV"}}}
            })),
        })
    }
    fn decode_response(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<DecodedCloudSpeech> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct Envelope {
            candidates: Option<Vec<Candidate>>,
            error: Option<serde_json::Value>,
            prompt_feedback: Option<serde_json::Value>,
        }
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct Candidate {
            finish_reason: String,
            content: Content,
        }
        #[derive(Deserialize)]
        struct Content {
            parts: Vec<Part>,
        }
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct Part {
            inline_data: Option<InlineData>,
            #[serde(default)]
            thought: bool,
        }
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct InlineData {
            mime_type: String,
            data: String,
        }
        let envelope: Envelope =
            serde_json::from_slice(&bytes).map_err(|_| invalid("Gemini 音频响应无效或未完成"))?;
        if envelope.error.is_some()
            || envelope
                .prompt_feedback
                .as_ref()
                .is_some_and(|f| f.get("blockReason").is_some())
        {
            return Err(invalid("Gemini 合成失败或内容被阻止"));
        }
        let candidate = envelope
            .candidates
            .and_then(|c| c.into_iter().next())
            .ok_or_else(|| invalid("Gemini 未返回候选音频"))?;
        if candidate.finish_reason != "STOP" {
            return Err(invalid("Gemini 合成未正常结束，拒绝部分音频"));
        }
        let mut chunks = Vec::new();
        let mut kind = None;
        let mut count = 0;
        for part in candidate.content.parts {
            if part.thought {
                continue;
            }
            let inline = part
                .inline_data
                .ok_or_else(|| invalid("Gemini 返回了非音频内容"))?;
            let next = AudioKind::parse(&inline.mime_type)?;
            if kind.is_some_and(|previous| previous != next) {
                return Err(invalid("Gemini 音频分片格式不一致"));
            }
            kind = Some(next);
            let encoded = inline
                .data
                .bytes()
                .filter(|b| !b.is_ascii_whitespace())
                .collect::<Vec<_>>();
            let decoded = STANDARD
                .decode(encoded)
                .map_err(|_| invalid("Gemini 音频 Base64 无效"))?;
            if decoded.is_empty() || next == AudioKind::Pcm && !decoded.len().is_multiple_of(2) {
                return Err(invalid("Gemini 音频为空或样本不完整"));
            }
            chunks.extend(decoded);
            count += 1;
        }
        let bytes = match kind {
            Some(AudioKind::Pcm) => pcm16_mono_to_wav(&chunks, 24000)?,
            Some(AudioKind::Wav) if count == 1 => chunks,
            _ => return Err(invalid("Gemini 未返回唯一 WAV 或连续 PCM 音频")),
        };
        self.decode_audio(format, bytes)
            .map(DecodedCloudSpeech::Audio)
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        // 核对完整 RIFF、fmt/data 块及 PCM 几何；不会再次给现有 WAV 添加头部。
        if format != "wav"
            || bytes.len() < 44
            || !bytes.starts_with(b"RIFF")
            || &bytes[8..12] != b"WAVE"
            || (u32::from_le_bytes(bytes[4..8].try_into().unwrap()) as usize).checked_add(8)
                != Some(bytes.len())
        {
            return Err(invalid("Gemini WAV 容器无效或不完整"));
        }
        let mut offset = 12usize;
        let (mut has_format, mut has_data) = (false, false);
        while offset.checked_add(8).is_some_and(|end| end <= bytes.len()) {
            let size =
                u32::from_le_bytes(bytes[offset + 4..offset + 8].try_into().unwrap()) as usize;
            let end = offset
                .checked_add(8)
                .and_then(|v| v.checked_add(size))
                .ok_or_else(|| invalid("Gemini WAV 长度溢出"))?;
            if end > bytes.len() {
                return Err(invalid("Gemini WAV 数据块不完整"));
            }
            match &bytes[offset..offset + 4] {
                b"fmt " => {
                    let b = &bytes[offset + 8..end];
                    if has_format
                        || b.len() < 16
                        || b[0..2] != 1u16.to_le_bytes()
                        || b[2..4] != 1u16.to_le_bytes()
                        || b[4..8] != 24000u32.to_le_bytes()
                        || b[8..12] != 48000u32.to_le_bytes()
                        || b[12..14] != 2u16.to_le_bytes()
                        || b[14..16] != 16u16.to_le_bytes()
                    {
                        return Err(invalid("Gemini WAV 须为 24 kHz 单声道 16-bit PCM"));
                    }
                    has_format = true;
                }
                b"data" => {
                    if has_data || size == 0 || !size.is_multiple_of(2) {
                        return Err(invalid("Gemini WAV 样本无效"));
                    }
                    has_data = true;
                }
                _ => {}
            }
            offset = end
                .checked_add(size % 2)
                .ok_or_else(|| invalid("Gemini WAV 长度溢出"))?;
        }
        if !has_format || !has_data || offset != bytes.len() {
            return Err(invalid("Gemini WAV 缺少完整格式或音频块"));
        }
        Ok(CloudTtsAudio {
            bytes,
            extension: "wav",
            content_type: "audio/wav",
        })
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum AudioKind {
    Wav,
    Pcm,
}
impl AudioKind {
    fn parse(mime: &str) -> LegadoResult<Self> {
        let mime = mime.to_ascii_lowercase();
        let mut fields = mime.split(';').map(str::trim);
        let media = fields.next().unwrap_or_default();
        let params = fields.collect::<Vec<_>>();
        match media {
            "audio/wav" | "audio/wave" | "audio/x-wav" if params.is_empty() => Ok(Self::Wav),
            "audio/l16"
                if params.len() == 2
                    && params.contains(&"codec=pcm")
                    && params.contains(&"rate=24000") =>
            {
                Ok(Self::Pcm)
            }
            _ => Err(invalid("Gemini 音频 MIME 或采样参数不支持")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn engine() -> CloudTtsEngine {
        CloudTtsEngine {
            id: "gemini".into(),
            provider: CloudTtsProviderType::GeminiTts,
            api_key: "private-key".into(),
            model: "gemini-3.8-flash-tts".into(),
            ..Default::default()
        }
    }
    fn request() -> CloudTtsSynthesisRequest {
        CloudTtsSynthesisRequest {
            text: " 甲😀\n\"原文\" ".into(),
            voice_id: "Kore".into(),
            style: " 平静 ".into(),
            instructions: " 保留停顿 ".into(),
            format: "wav".into(),
            ..Default::default()
        }
    }
    fn envelope(mime: &str, bytes: &[u8]) -> serde_json::Value {
        json!({"candidates":[{"finishReason":"STOP", "content":{"parts":[{"inlineData":{"mimeType":mime,"data":STANDARD.encode(bytes)}}]}}]})
    }
    fn decode(value: serde_json::Value) -> LegadoResult<CloudTtsAudio> {
        match GeminiCloudTtsProvider.decode_response("wav", value.to_string().into_bytes())? {
            DecodedCloudSpeech::Audio(audio) => Ok(audio),
            _ => panic!("预期音频"),
        }
    }
    #[test]
    fn structured_style_preserves_transcript_and_normalizes_endpoint() {
        let mut engine = engine();
        engine.base_url = "https://example.com/v1beta/openai/".into();
        engine.model = "models/gemini-3.8-flash-lite-tts".into();
        let prepared = GeminiCloudTtsProvider.prepare(&engine, &request()).unwrap();
        assert_eq!(
            prepared.endpoint,
            "https://example.com/v1beta/models/gemini-3.8-flash-lite-tts:generateContent"
        );
        assert_eq!(prepared.credential_header, "x-goog-api-key");
        assert_eq!(prepared.authorization, "private-key");
        assert!(prepared.response_kind == CloudSpeechResponseKind::JsonAudio);
        let CloudSpeechBody::Json(body) = prepared.body else {
            panic!("预期 JSON")
        };
        assert_eq!(
            body,
            json!({"contents":[{"role":"user","parts":[{"text":request().text,"speech_metadata":{"style":"平静\n保留停顿"}}]}],
            "generationConfig":{"responseModalities":["AUDIO"],"speechConfig":{"voiceConfig":{"voice":"Kore"}},"responseFormat":{"audio":{"mimeType":"AUDIO_WAV"}}}})
        );
        assert_eq!(GeminiCloudTtsProvider.voices().len(), 30);
        assert_eq!(GeminiCloudTtsProvider.voices().last().unwrap().id, "Zephyr");
        let mut request = request();
        request.style.clear();
        request.instructions.clear();
        let CloudSpeechBody::Json(body) = GeminiCloudTtsProvider
            .prepare(&engine, &request)
            .unwrap()
            .body
        else {
            panic!("预期 JSON")
        };
        assert!(
            body["contents"][0]["parts"][0]
                .get("speech_metadata")
                .is_none()
        );
    }
    #[test]
    fn wav_is_not_double_wrapped_and_pcm_chunks_preserve_order() {
        let wav = pcm16_mono_to_wav(&[1, 0, 2, 0], 24000).unwrap();
        assert_eq!(decode(envelope("audio/wav", &wav)).unwrap().bytes, wav);
        let mut pcm = envelope("Audio/L16;rate=24000;codec=pcm", &[1, 0]);
        pcm["candidates"][0]["content"]["parts"].as_array_mut().unwrap().push(
            json!({"inlineData":{"mimeType":"audio/l16;codec=pcm;rate=24000","data":STANDARD.encode([2, 0])}}));
        assert_eq!(decode(pcm).unwrap().bytes, wav);
        let mut twice = envelope("audio/wav", &wav);
        let part = twice["candidates"][0]["content"]["parts"][0].clone();
        twice["candidates"][0]["content"]["parts"]
            .as_array_mut()
            .unwrap()
            .push(part);
        assert!(decode(twice).is_err());
        assert!(decode(envelope("audio/wav", &wav[..wav.len() - 1])).is_err());
        let mut oversized = wav;
        oversized[4..8].copy_from_slice(&u32::MAX.to_le_bytes());
        assert!(decode(envelope("audio/wav", &oversized)).is_err());
    }
    #[test]
    fn invalid_or_blocked_responses_never_become_cached_audio_or_expose_payload() {
        let good = envelope("audio/l16;codec=pcm;rate=24000", &[1, 0]);
        let mut cases = vec![
            json!({"error":{"message":"private-key"}}),
            json!({"candidates":[]}),
            envelope("application/json", b"private-key"),
            envelope("audio/l16;rate=16000;codec=pcm", &[1, 0]),
            envelope("audio/l16;codec=pcm;rate=24000", &[1]),
            envelope("audio/wav", b"RIFFprivate-key"),
        ];
        for finish in ["MAX_TOKENS", "SAFETY", "OTHER"] {
            let mut case = good.clone();
            case["candidates"][0]["finishReason"] = finish.into();
            cases.push(case);
        }
        let mut case = good.clone();
        case["promptFeedback"] = json!({"blockReason":"SAFETY"});
        cases.push(case);
        let mut case = good.clone();
        case["candidates"][0]["content"]["parts"][0]["inlineData"]["data"] =
            "%%%private-key".into();
        cases.push(case);
        for case in cases {
            assert!(
                !decode(case)
                    .err()
                    .unwrap()
                    .to_string()
                    .contains("private-key")
            );
        }
    }
    #[test]
    fn rejects_old_protocol_models_invalid_key_url_text_and_format() {
        for index in 0..9 {
            let mut engine = engine();
            let mut request = request();
            match index {
                0 => engine.model = "gemini-2.5-pro-preview-tts".into(),
                1 => engine.api_key = "bad\nkey".into(),
                2 => engine.base_url = "https://private-key@example.com/v1beta".into(),
                3 => engine.base_url = "https://example.com/v1beta?key=private-key".into(),
                4 => request.text = "😀".repeat(2001),
                5 => request.text = "  ".into(),
                6 => request.voice_id.clear(),
                7 => request.format = "mp3".into(),
                _ => request.sample_rate = Some(16000),
            }
            assert!(GeminiCloudTtsProvider.prepare(&engine, &request).is_err());
        }
    }
}
