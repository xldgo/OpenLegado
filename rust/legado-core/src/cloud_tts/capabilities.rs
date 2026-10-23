//! Provider请求默认值与既有表单能力；不读取网络、凭据或数据库。
use super::CloudTtsProviderType;

#[derive(Debug, Clone, Copy)]
pub struct CloudTtsNumericRange {
    pub min: f64,
    pub max: f64,
}
impl CloudTtsNumericRange {
    pub fn contains(self, value: f64) -> bool {
        (self.min..=self.max).contains(&value)
    }
}
#[derive(Debug, Clone)]
pub struct CloudTtsCapabilities {
    pub provider: CloudTtsProviderType,
    pub default_model: &'static str,
    pub default_voice: &'static str,
    pub formats: &'static [&'static str],
    pub styles: &'static [&'static str],
    pub sample_rates: &'static [u32],
    pub pcm_sample_rates: &'static [u32],
    pub supports_source_speed: bool,
    pub supports_locale: bool,
    pub supports_prosody: bool,
    pub requires_region: bool,
    pub uses_model: bool,
    pub uses_secret_key: bool,
    pub remote_catalog: bool,
    pub static_voice_descriptors: bool,
    pub supports_instructions: bool,
    pub supports_style: bool,
    pub requires_app_id: bool,
    pub supports_role: bool,
    pub supports_sample_rate: bool,
    pub source_speed_range: CloudTtsNumericRange,
    pub prosody_range: CloudTtsNumericRange,
}
impl CloudTtsProviderType {
    pub const ALL: [Self; 8] = [
        Self::VolcengineV3,
        Self::GeminiTts,
        Self::Volcengine,
        Self::AwsPolly,
        Self::AzureSpeech,
        Self::OpenAiSpeech,
        Self::AlibabaCloud,
        Self::Mimo,
    ];

    pub fn capabilities(self) -> CloudTtsCapabilities {
        let common = CloudTtsCapabilities {
            provider: self,
            default_model: "",
            default_voice: "",
            formats: &[],
            styles: &[],
            sample_rates: &[],
            pcm_sample_rates: &[],
            supports_source_speed: false,
            supports_locale: false,
            supports_prosody: false,
            requires_region: false,
            uses_model: true,
            uses_secret_key: false,
            remote_catalog: false,
            static_voice_descriptors: false,
            supports_instructions: true,
            supports_style: true,
            requires_app_id: false,
            supports_role: true,
            supports_sample_rate: false,
            source_speed_range: CloudTtsNumericRange {
                min: 0.25,
                max: 4.0,
            },
            prosody_range: CloudTtsNumericRange { min: 0.0, max: 2.0 },
        };
        match self {
            Self::VolcengineV3 => CloudTtsCapabilities {
                default_model: "seed-tts-2.0",
                default_voice: "zh_female_vv_uranus_bigtts",
                formats: &["mp3", "ogg_opus", "wav", "pcm"],
                supports_source_speed: true,
                supports_prosody: true,
                static_voice_descriptors: true,
                supports_role: false,
                source_speed_range: CloudTtsNumericRange { min: 0.5, max: 2.0 },
                prosody_range: CloudTtsNumericRange { min: 0.5, max: 2.0 },
                ..common
            },
            Self::GeminiTts => CloudTtsCapabilities {
                default_model: "gemini-3.8-flash-tts",
                default_voice: "Kore",
                formats: &["wav"],
                supports_role: false,
                ..common
            },
            Self::Volcengine => CloudTtsCapabilities {
                default_model: "volcano_tts",
                default_voice: "BV001_streaming",
                formats: &["mp3", "ogg_opus", "wav", "pcm"],
                supports_source_speed: true,
                supports_prosody: true,
                static_voice_descriptors: true,
                supports_instructions: false,
                requires_app_id: true,
                supports_role: false,
                source_speed_range: CloudTtsNumericRange { min: 0.2, max: 3.0 },
                prosody_range: CloudTtsNumericRange { min: 0.1, max: 3.0 },
                ..common
            },
            Self::AwsPolly => CloudTtsCapabilities {
                default_model: "neural",
                default_voice: "Zhiyu",
                formats: &["mp3", "ogg_vorbis", "wav", "pcm"],
                supports_locale: true,
                requires_region: true,
                uses_secret_key: true,
                remote_catalog: true,
                supports_instructions: false,
                supports_style: false,
                supports_sample_rate: true,
                sample_rates: &[8000, 16000, 22050, 24000, 44100, 48000],
                pcm_sample_rates: &[8000, 16000],
                ..common
            },
            Self::AzureSpeech => CloudTtsCapabilities {
                default_model: "",
                default_voice: "zh-CN-XiaoxiaoNeural",
                formats: &["mp3", "wav", "ogg", "opus"],
                supports_source_speed: true,
                supports_locale: true,
                supports_prosody: true,
                requires_region: true,
                uses_model: false,
                remote_catalog: true,
                supports_instructions: false,
                ..common
            },
            Self::OpenAiSpeech => CloudTtsCapabilities {
                default_model: "gpt-4o-mini-tts",
                default_voice: "alloy",
                formats: &["mp3", "opus", "aac", "flac", "wav", "pcm"],
                supports_source_speed: true,
                ..common
            },
            Self::AlibabaCloud => CloudTtsCapabilities {
                default_model: "qwen3-tts-flash",
                default_voice: "Cherry",
                formats: &["wav"],
                supports_locale: true,
                ..common
            },
            Self::Mimo => CloudTtsCapabilities {
                default_model: "mimo-v2.5-tts",
                default_voice: "mimo_default",
                formats: &["wav"],
                styles: &[
                    "开心", "悲伤", "愤怒", "惊讶", "恐惧", "厌恶", "小声", "平静",
                ],
                ..common
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::cloud_tts::*;

    #[test]
    fn advertised_defaults_formats_and_editing_ranges_prepare_real_requests() {
        for kind in CloudTtsProviderType::ALL {
            let capabilities = kind.capabilities();
            let engine = CloudTtsEngine {
                id: "fixture".into(),
                provider: kind,
                api_key: "fixture-key".into(),
                secret_key: "fixture-secret".into(),
                app_id: "fixture-app".into(),
                region: "us-east-1".into(),
                model: capabilities.default_model.into(),
                ..Default::default()
            };
            let provider = cloud_tts_provider(kind);
            if !capabilities.remote_catalog {
                assert!(
                    provider
                        .voices()
                        .iter()
                        .any(|voice| voice.id == capabilities.default_voice)
                );
            }
            for format in capabilities.formats {
                let mut request = CloudTtsSynthesisRequest {
                    text: "中文😀".into(),
                    voice_id: capabilities.default_voice.into(),
                    format: (*format).into(),
                    ..Default::default()
                };
                assert!(
                    provider.prepare(&engine, &request).is_ok(),
                    "{kind:?}/{format}"
                );
                if capabilities.supports_source_speed {
                    for value in [
                        capabilities.source_speed_range.min,
                        capabilities.source_speed_range.max,
                    ] {
                        request.speed = value;
                        assert!(
                            provider.prepare(&engine, &request).is_ok(),
                            "{kind:?}/{format}/{value}"
                        );
                    }
                    request.speed = 1.0;
                }
                if capabilities.supports_prosody {
                    for value in [
                        capabilities.prosody_range.min,
                        capabilities.prosody_range.max,
                    ] {
                        request.pitch = value;
                        request.volume = value;
                        assert!(
                            provider.prepare(&engine, &request).is_ok(),
                            "{kind:?}/{format}/{value}"
                        );
                    }
                    request.pitch = 1.0;
                    request.volume = 1.0;
                }
                if capabilities.supports_sample_rate {
                    let rates = if ["pcm", "wav"].contains(format) {
                        capabilities.pcm_sample_rates
                    } else {
                        capabilities.sample_rates
                    };
                    for rate in rates {
                        request.sample_rate = Some(*rate);
                        assert!(
                            provider.prepare(&engine, &request).is_ok(),
                            "{kind:?}/{format}/{rate}"
                        );
                    }
                }
            }
        }
    }
}
