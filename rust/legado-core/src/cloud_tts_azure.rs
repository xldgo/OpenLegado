//! 对照 AzureSpeechCloudTtsProvider 的 SSML 与目录语义；仅处理纯协议数据。
use super::cloud_tts::*;
use crate::LegadoResult;
use serde::Deserialize;

pub struct AzureSpeechCloudTtsProvider;

fn endpoint(engine: &CloudTtsEngine) -> LegadoResult<String> {
    if engine.provider != CloudTtsProviderType::AzureSpeech || !engine.enabled {
        return Err(invalid("Azure 引擎类型无效或已停用"));
    }
    if engine.id.trim().is_empty()
        || engine.api_key.trim().is_empty()
        || engine.api_key.chars().any(char::is_control)
    {
        return Err(invalid("Azure 引擎 ID 或密钥无效"));
    }
    let base = if engine.base_url.trim().is_empty() {
        let region = engine.region.trim();
        if region.is_empty()
            || !region
                .bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
        {
            return Err(invalid("Azure 区域不能为空且须为区域标识"));
        }
        format!("https://{region}.tts.speech.microsoft.com")
    } else {
        engine.base_url.trim().trim_end_matches('/').to_owned()
    };
    let url = url::Url::parse(&base).map_err(|_| invalid("Azure 服务地址无效"))?;
    if !matches!(url.scheme(), "http" | "https")
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
        || url.query().is_some()
        || url.fragment().is_some()
    {
        return Err(invalid("Azure 地址须为无凭据、查询或片段的 HTTP(S) 地址"));
    }
    Ok(base)
}
fn xml(text: &str) -> LegadoResult<String> {
    let mut output = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '&' => output.push_str("&amp;"),
            '<' => output.push_str("&lt;"),
            '>' => output.push_str("&gt;"),
            '"' => output.push_str("&quot;"),
            '\'' => output.push_str("&apos;"),
            '\t' | '\n' | '\r' => output.push(c),
            c if c >= ' ' && c != '\u{fffe}' && c != '\u{ffff}' => output.push(c),
            _ => return Err(invalid("Azure 文本包含 XML 不支持的字符")),
        }
    }
    Ok(output)
}
impl CloudTtsProvider for AzureSpeechCloudTtsProvider {
    fn provider_type(&self) -> CloudTtsProviderType {
        CloudTtsProviderType::AzureSpeech
    }
    fn voices(&self) -> Vec<CloudTtsVoiceDescriptor> {
        Vec::new()
    }
    fn prepare_catalog(&self, engine: &CloudTtsEngine) -> LegadoResult<CloudVoiceCatalog> {
        Ok(CloudVoiceCatalog::Remote(PreparedCloudCatalog {
            authentication_headers: Vec::new(),
            endpoint: format!("{}/cognitiveservices/voices/list", endpoint(engine)?),
            credential_header: "Ocp-Apim-Subscription-Key",
            authorization: engine.api_key.clone(),
        }))
    }
    fn decode_catalog(&self, bytes: &[u8]) -> LegadoResult<Vec<CloudTtsVoiceDescriptor>> {
        #[derive(Deserialize)]
        #[serde(rename_all = "PascalCase")]
        struct Voice {
            short_name: String,
            local_name: Option<String>,
            display_name: Option<String>,
            locale: Option<String>,
            gender: Option<String>,
            style_list: Option<Vec<String>>,
            role_play_list: Option<Vec<String>>,
            sample_rate_hertz: Option<String>,
        }
        let voices: Vec<Voice> =
            serde_json::from_slice(bytes).map_err(|_| invalid("Azure 音色目录格式无效"))?;
        let mut seen = std::collections::HashSet::new();
        let mut result = Vec::with_capacity(voices.len());
        for v in voices {
            if v.short_name.trim().is_empty() {
                return Err(invalid("Azure 音色目录缺少有效 ID"));
            }
            if !seen.insert(v.short_name.clone()) {
                continue;
            }
            let display_name = v
                .local_name
                .filter(|s| !s.trim().is_empty())
                .or_else(|| v.display_name.filter(|s| !s.trim().is_empty()))
                .unwrap_or_else(|| v.short_name.clone());
            result.push(CloudTtsVoiceDescriptor {
                id: v.short_name,
                display_name,
                locale: v.locale.unwrap_or_default(),
                gender: v.gender.unwrap_or_default(),
                styles: v.style_list.unwrap_or_default(),
                roles: v.role_play_list.unwrap_or_default(),
                supported_models: Vec::new(),
                sample_rate: v.sample_rate_hertz.and_then(|s| s.parse().ok()),
            });
        }
        Ok(result)
    }
    fn prepare(
        &self,
        engine: &CloudTtsEngine,
        request: &CloudTtsSynthesisRequest,
    ) -> LegadoResult<PreparedCloudSpeech> {
        let endpoint = endpoint(engine)?;
        if request.voice_id.trim().is_empty() || request.text.trim().is_empty() {
            return Err(invalid("Azure 音色或文本不能为空"));
        }
        if ![request.speed, request.pitch, request.volume]
            .into_iter()
            .all(f64::is_finite)
            || request.speed <= 0.0
            || request.speed > 4.0
        {
            return Err(invalid("Azure 音色数值无效"));
        }
        let format = request.format.to_ascii_lowercase();
        let output = match format.as_str() {
            "wav" => "riff-24khz-16bit-mono-pcm",
            "ogg" | "opus" => "ogg-24khz-16bit-mono-opus",
            "mp3" => "audio-24khz-48kbitrate-mono-mp3",
            _ => return Err(invalid("Azure 音频格式不支持")),
        };
        let locale = if request.locale.trim().is_empty() {
            request
                .voice_id
                .split('-')
                .take(2)
                .collect::<Vec<_>>()
                .join("-")
        } else {
            request.locale.clone()
        };
        let percent = |v: f64| ((v as f32 - 1.0) * 100.0).clamp(-100.0, 100.0) as i32;
        let prosody = format!(
            "<prosody rate=\"{}\" pitch=\"{}%\" volume=\"{}%\">{}</prosody>",
            request.speed,
            percent(request.pitch),
            percent(request.volume),
            xml(&request.text)?
        );
        let expressed = if request.style.trim().is_empty() && request.role.trim().is_empty() {
            prosody
        } else {
            let style = if request.style.trim().is_empty() {
                "general"
            } else {
                &request.style
            };
            let role = if request.role.trim().is_empty() {
                String::new()
            } else {
                format!(" role=\"{}\"", xml(&request.role)?)
            };
            format!(
                "<mstts:express-as style=\"{}\"{role}>{prosody}</mstts:express-as>",
                xml(style)?
            )
        };
        let body = format!(
            "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xmlns:mstts=\"https://www.w3.org/2001/mstts\" xml:lang=\"{}\"><voice name=\"{}\">{expressed}</voice></speak>",
            xml(&locale)?,
            xml(&request.voice_id)?
        );
        Ok(PreparedCloudSpeech {
            authentication_headers: Vec::new(),
            endpoint: format!("{endpoint}/cognitiveservices/v1"),
            credential_header: "Ocp-Apim-Subscription-Key",
            authorization: engine.api_key.clone(),
            response_kind: CloudSpeechResponseKind::AudioBytes,
            additional_headers: vec![
                ("X-Microsoft-OutputFormat", output.into()),
                ("User-Agent", "Legado".into()),
            ],
            body: CloudSpeechBody::Ssml(body),
            response_format: format,
        })
    }
    fn decode_audio(&self, format: &str, bytes: Vec<u8>) -> LegadoResult<CloudTtsAudio> {
        let wav_size_valid = bytes
            .get(4..8)
            .and_then(|v| <[u8; 4]>::try_from(v).ok())
            .is_some_and(|v| u64::from(u32::from_le_bytes(v)) + 8 == bytes.len() as u64);
        let (extension, content_type, valid) = match format {
            "wav" => (
                "wav",
                "audio/wav",
                bytes.len() > 44
                    && bytes.starts_with(b"RIFF")
                    && bytes.get(8..12) == Some(b"WAVE")
                    && wav_size_valid,
            ),
            "ogg" | "opus" => ("ogg", "audio/ogg", bytes.starts_with(b"OggS")),
            "mp3" => (
                "mp3",
                "audio/mpeg",
                bytes.starts_with(b"ID3")
                    || bytes.len() > 1 && bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0,
            ),
            _ => return Err(invalid("Azure 音频格式不支持")),
        };
        if !valid {
            return Err(invalid("Azure 未返回有效音频"));
        }
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
            id: "azure".into(),
            provider: CloudTtsProviderType::AzureSpeech,
            api_key: "private-fixture".into(),
            region: "eastasia".into(),
            ..Default::default()
        }
    }
    #[test]
    fn ssml_request_matches_upstream_and_escapes_all_xml_inputs() {
        let request = CloudTtsSynthesisRequest {
            text: "甲<&\"'😀\n乙".into(),
            voice_id: "zh-CN-XiaoxiaoNeural".into(),
            style: "cheerful".into(),
            role: "Girl".into(),
            speed: 1.5,
            pitch: 0.8,
            volume: 1.2,
            format: "opus".into(),
            ..Default::default()
        };
        let prepared = AzureSpeechCloudTtsProvider
            .prepare(&engine(), &request)
            .unwrap();
        assert_eq!(
            prepared.endpoint,
            "https://eastasia.tts.speech.microsoft.com/cognitiveservices/v1"
        );
        assert_eq!(prepared.credential_header, "Ocp-Apim-Subscription-Key");
        assert_eq!(prepared.body.content_type(), "application/ssml+xml");
        let expected = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xmlns:mstts=\"https://www.w3.org/2001/mstts\" xml:lang=\"zh-CN\"><voice name=\"zh-CN-XiaoxiaoNeural\"><mstts:express-as style=\"cheerful\" role=\"Girl\"><prosody rate=\"1.5\" pitch=\"-19%\" volume=\"20%\">甲&lt;&amp;&quot;&apos;😀\n乙</prosody></mstts:express-as></voice></speak>";
        assert_eq!(prepared.body.encode(), expected);
        assert!(
            prepared
                .additional_headers
                .iter()
                .any(|(k, v)| *k == "X-Microsoft-OutputFormat" && v == "ogg-24khz-16bit-mono-opus")
        );
        let mut injected = request;
        injected.locale = "en-US\" onload=\"bad".into();
        injected.voice_id = "x\"<>".into();
        injected.role = "\"<&'".into();
        let ssml = AzureSpeechCloudTtsProvider
            .prepare(&engine(), &injected)
            .unwrap()
            .body
            .encode();
        assert!(ssml.contains("xml:lang=\"en-US&quot; onload=&quot;bad\""));
        assert!(!ssml.contains("name=\"x\""));
    }
    #[test]
    fn catalog_decodes_names_language_styles_roles_and_rejects_bad_documents() {
        let bytes = br#"[{"ShortName":"zh-CN-XiaoxiaoNeural","LocalName":"","DisplayName":"Xiaoxiao","Locale":"zh-CN","Gender":"Female","StyleList":["cheerful"],"RolePlayList":["Girl"],"SampleRateHertz":"24000"},{"ShortName":"zh-CN-XiaoxiaoNeural"}]"#;
        let voices = AzureSpeechCloudTtsProvider.decode_catalog(bytes).unwrap();
        assert_eq!(voices.len(), 1);
        assert_eq!(voices[0].display_name, "Xiaoxiao");
        assert_eq!(voices[0].locale, "zh-CN");
        assert_eq!(voices[0].gender, "Female");
        assert_eq!(voices[0].styles, ["cheerful"]);
        assert_eq!(voices[0].roles, ["Girl"]);
        assert_eq!(voices[0].sample_rate, Some(24000));
        for invalid in ["{}", "[{\"ShortName\":\"\"}]", "[{\"ShortName\":3}]"] {
            assert!(
                AzureSpeechCloudTtsProvider
                    .decode_catalog(invalid.as_bytes())
                    .is_err()
            );
        }
    }
    #[test]
    fn endpoints_validation_and_audio_formats_are_explicit() {
        let mut engine = engine();
        let request = CloudTtsSynthesisRequest {
            text: "正文".into(),
            voice_id: "zh-CN-XiaoxiaoNeural".into(),
            ..Default::default()
        };
        engine.region.clear();
        assert!(
            AzureSpeechCloudTtsProvider
                .prepare(&engine, &request)
                .is_err()
        );
        engine.base_url = "http://127.0.0.1:1234/tts/".into();
        let CloudVoiceCatalog::Remote(catalog) = AzureSpeechCloudTtsProvider
            .prepare_catalog(&engine)
            .unwrap()
        else {
            panic!()
        };
        assert_eq!(
            catalog.endpoint,
            "http://127.0.0.1:1234/tts/cognitiveservices/voices/list"
        );
        assert_eq!(
            AzureSpeechCloudTtsProvider
                .prepare(&engine, &request)
                .unwrap()
                .endpoint,
            "http://127.0.0.1:1234/tts/cognitiveservices/v1"
        );
        for base in [
            "https://private-fixture@example.org",
            "file:///private-fixture",
            "https://example.org?private-fixture",
        ] {
            engine.base_url = base.into();
            let error = AzureSpeechCloudTtsProvider
                .prepare(&engine, &request)
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("private-fixture"));
        }
        let wave = pcm16_mono_to_wav(&[0, 1, 0, 2], 24000).unwrap();
        assert!(
            AzureSpeechCloudTtsProvider
                .decode_audio("wav", wave)
                .is_ok()
        );
        assert_eq!(
            AzureSpeechCloudTtsProvider
                .decode_audio("opus", b"OggSfixture".to_vec())
                .unwrap()
                .extension,
            "ogg"
        );
        assert!(
            AzureSpeechCloudTtsProvider
                .decode_audio("mp3", b"ID3fixture".to_vec())
                .is_ok()
        );
        assert!(
            AzureSpeechCloudTtsProvider
                .decode_audio("wav", b"bad".to_vec())
                .is_err()
        );
    }
}
