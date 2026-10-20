//! 云端引擎只存元数据和设备凭据引用，不保存 API Key。
use legado_core::{LegadoError, LegadoResult, cloud_tts::*};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CloudTtsMetadata {
    pub id: String,
    pub name: String,
    pub provider: CloudTtsProviderType,
    pub base_url: String,
    pub model: String,
    pub options_json: String,
    pub region: String,
    pub app_id: String,
    pub enabled: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub credential_key: String,
}
#[derive(Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CloudVoiceOptions {
    pub voice_id: Option<String>,
    pub locale: Option<String>,
    pub style: Option<String>,
    pub role: Option<String>,
    pub instructions: Option<String>,
    pub speed: Option<f64>,
    pub pitch: Option<f64>,
    pub volume: Option<f64>,
    pub format: Option<String>,
    pub sample_rate: Option<u32>,
}
impl CloudVoiceOptions {
    /// DTO 的非有限浮点值必须在 JSON 编码将其变成 null 前拒绝。
    pub fn validate(&self) -> LegadoResult<()> {
        if [self.speed, self.pitch, self.volume]
            .into_iter()
            .flatten()
            .any(|value| !value.is_finite())
        {
            return Err(LegadoError::Ffi("云端音色数值必须为有限值".into()));
        }
        Ok(())
    }
}
impl CloudTtsMetadata {
    pub fn engine(&self, api_key: String) -> CloudTtsEngine {
        CloudTtsEngine {
            id: self.id.clone(),
            name: self.name.clone(),
            provider: self.provider,
            base_url: self.base_url.clone(),
            api_key,
            secret_key: String::new(),
            model: self.model.clone(),
            region: self.region.clone(),
            app_id: self.app_id.clone(),
            enabled: self.enabled,
        }
    }
    pub fn engine_with_credentials(&self, payload: String) -> LegadoResult<CloudTtsEngine> {
        if self.provider != CloudTtsProviderType::AwsPolly {
            return Ok(self.engine(payload));
        }
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase", deny_unknown_fields)]
        struct Credentials {
            api_key: String,
            secret_key: String,
        }
        let credentials: Credentials = serde_json::from_str(&payload)
            .map_err(|_| LegadoError::Ffi("AWS 成组凭据无效，请重新填写".into()))?;
        let mut engine = self.engine(credentials.api_key);
        engine.secret_key = credentials.secret_key;
        Ok(engine)
    }
    pub fn request(&self, text: String) -> LegadoResult<CloudTtsSynthesisRequest> {
        let options: CloudVoiceOptions = serde_json::from_str(&self.options_json)?;
        options.validate()?;
        Ok(CloudTtsSynthesisRequest {
            text,
            voice_id: options.voice_id.unwrap_or_else(|| {
                match self.provider {
                    CloudTtsProviderType::OpenAiSpeech => "alloy",
                    CloudTtsProviderType::Mimo => "mimo_default",
                    CloudTtsProviderType::AlibabaCloud => "Cherry",
                    CloudTtsProviderType::AzureSpeech => "zh-CN-XiaoxiaoNeural",
                    CloudTtsProviderType::AwsPolly => "Zhiyu",
                    CloudTtsProviderType::Volcengine => "BV001_streaming",
                    CloudTtsProviderType::GeminiTts => "Kore",
                    CloudTtsProviderType::VolcengineV3 => "zh_female_vv_uranus_bigtts",
                }
                .into()
            }),
            locale: options.locale.unwrap_or_default(),
            style: options.style.unwrap_or_default(),
            role: options.role.unwrap_or_default(),
            instructions: options.instructions.unwrap_or_default(),
            speed: options.speed.unwrap_or(1.0),
            pitch: options.pitch.unwrap_or(1.0),
            volume: options.volume.unwrap_or(1.0),
            format: options.format.unwrap_or_else(|| {
                match self.provider {
                    CloudTtsProviderType::OpenAiSpeech => "mp3",
                    CloudTtsProviderType::AzureSpeech
                    | CloudTtsProviderType::AwsPolly
                    | CloudTtsProviderType::Volcengine
                    | CloudTtsProviderType::VolcengineV3 => "mp3",
                    CloudTtsProviderType::Mimo
                    | CloudTtsProviderType::AlibabaCloud
                    | CloudTtsProviderType::GeminiTts => "wav",
                }
                .into()
            }),
            sample_rate: options.sample_rate,
        })
    }
    pub fn validate(&self) -> LegadoResult<()> {
        if self.id.is_empty()
            || self.id.len() > 128
            || !self
                .id
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))
            || self.name.trim().is_empty()
        {
            return Err(LegadoError::Ffi("云端引擎 ID 或名称无效".into()));
        }
        if !self.credential_key.starts_with("cloud-tts:")
            || self.credential_key.len() < 20
            || !self
                .credential_key
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"_:-".contains(&b))
        {
            return Err(LegadoError::Ffi("云端凭据引用无效".into()));
        }
        let mut engine = self.engine("validation-only".into());
        engine.enabled = true;
        engine.secret_key = "validation-only".into();
        cloud_tts_provider(self.provider).prepare(&engine, &self.request("配置校验".into())?)?;
        Ok(())
    }
}
pub struct CloudTtsRepository<'a> {
    conn: &'a Connection,
}
fn db(e: rusqlite::Error) -> LegadoError {
    LegadoError::Database(e.to_string())
}
fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
impl<'a> CloudTtsRepository<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }
    pub fn list(&self) -> LegadoResult<Vec<CloudTtsMetadata>> {
        let mut statement=self.conn.prepare("SELECT id,name,provider,baseUrl,model,optionsJson,region,appId,enabled,createdAt,updatedAt,credentialKey FROM cloud_tts_engines ORDER BY createdAt,id").map_err(db)?;
        let rows = statement
            .query_map([], |r| {
                let provider: String = r.get(2)?;
                let provider =
                    serde_json::from_value(serde_json::json!(provider)).map_err(|e| {
                        rusqlite::Error::FromSqlConversionFailure(
                            2,
                            rusqlite::types::Type::Text,
                            Box::new(e),
                        )
                    })?;
                Ok(CloudTtsMetadata {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    provider,
                    base_url: r.get(3)?,
                    model: r.get(4)?,
                    options_json: r.get(5)?,
                    region: r.get(6)?,
                    app_id: r.get(7)?,
                    enabled: r.get(8)?,
                    created_at: r.get(9)?,
                    updated_at: r.get(10)?,
                    credential_key: r.get(11)?,
                })
            })
            .map_err(db)?;
        rows.collect::<Result<Vec<_>, _>>().map_err(db)
    }
    pub fn get(&self, id: &str) -> LegadoResult<CloudTtsMetadata> {
        self.list()?
            .into_iter()
            .find(|e| e.id == id)
            .ok_or_else(|| LegadoError::Ffi("云端朗读引擎不存在".into()))
    }
    pub fn save(&self, engine: &CloudTtsMetadata) -> LegadoResult<()> {
        engine.validate()?;
        let provider = serde_json::to_value(engine.provider)?
            .as_str()
            .unwrap()
            .to_string();
        let previous: Option<String> = self
            .conn
            .query_row(
                "SELECT provider FROM cloud_tts_engines WHERE id=?1",
                [&engine.id],
                |r| r.get(0),
            )
            .optional()
            .map_err(db)?;
        if previous.is_some_and(|previous| previous != provider) {
            return Err(LegadoError::Ffi(
                "已保存引擎不能更换 Provider，请新建引擎".into(),
            ));
        }
        let timestamp = now();
        self.conn.execute("INSERT INTO cloud_tts_engines(id,name,provider,baseUrl,model,optionsJson,region,appId,enabled,createdAt,updatedAt,credentialKey) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?10,?11) ON CONFLICT(id) DO UPDATE SET name=excluded.name,provider=excluded.provider,baseUrl=excluded.baseUrl,model=excluded.model,optionsJson=excluded.optionsJson,region=excluded.region,appId=excluded.appId,enabled=excluded.enabled,updatedAt=excluded.updatedAt,credentialKey=excluded.credentialKey",params![engine.id,engine.name,provider,engine.base_url,engine.model,engine.options_json,engine.region,engine.app_id,engine.enabled,timestamp,engine.credential_key]).map_err(db)?;
        Ok(())
    }
    pub fn delete(&self, id: &str) -> LegadoResult<bool> {
        let tx = self.conn.unchecked_transaction().map_err(db)?;
        tx.execute(
            "DELETE FROM read_aloud_voices WHERE engineType='cloud_tts' AND engineId=?1",
            [id],
        )
        .map_err(db)?;
        let deleted = tx
            .execute("DELETE FROM cloud_tts_engines WHERE id=?1", [id])
            .map_err(db)?
            > 0;
        tx.commit().map_err(db)?;
        Ok(deleted)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn polly_metadata_validates_and_credentials_decode_only_at_call_boundary() {
        let mut meta = metadata();
        meta.provider = CloudTtsProviderType::AwsPolly;
        meta.region = "us-east-1".into();
        meta.model = "neural".into();
        meta.options_json = "{}".into();
        meta.validate().unwrap();
        assert_eq!(meta.request("测试".into()).unwrap().voice_id, "Zhiyu");
        let runtime = meta
            .engine_with_credentials(
                r#"{"apiKey":"access-private","secretKey":"secret-private"}"#.into(),
            )
            .unwrap();
        assert_eq!(runtime.api_key, "access-private");
        assert_eq!(runtime.secret_key, "secret-private");
        assert!(!serde_json::to_string(&meta).unwrap().contains("private"));
        for input in [
            "secret-private",
            r#"{"apiKey":"secret-private"}"#,
            r#"{"apiKey":"a","secretKey":"s","extra":1}"#,
        ] {
            let error = meta
                .engine_with_credentials(input.into())
                .err()
                .unwrap()
                .to_string();
            assert!(!error.contains("secret-private"));
        }
    }
    #[test]
    fn volcengine_app_and_cluster_round_trip_without_credentials_or_migration() {
        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let repo = CloudTtsRepository::new(&connection);
        let mut meta = metadata();
        meta.provider = CloudTtsProviderType::Volcengine;
        meta.model = "volcano_tts".into();
        meta.options_json = "{}".into();
        assert!(repo.save(&meta).is_err());
        meta.app_id = "app-fixture".into();
        repo.save(&meta).unwrap();
        let saved = repo.get(&meta.id).unwrap();
        let engine = saved
            .engine_with_credentials("private-token".into())
            .unwrap();
        assert_eq!(engine.app_id, "app-fixture");
        assert_eq!(engine.model, "volcano_tts");
        assert!(
            !serde_json::to_string(&saved)
                .unwrap()
                .contains("private-token")
        );
        let request = saved.request("测试".into()).unwrap();
        assert_eq!(request.voice_id, "BV001_streaming");
        assert_eq!(request.format, "mp3");
        meta.app_id = "new-app".into();
        meta.model = "custom_cluster".into();
        repo.save(&meta).unwrap();
        assert_eq!(repo.get(&meta.id).unwrap().app_id, "new-app");
    }

    #[test]
    fn gemini_metadata_defaults_and_instructions_round_trip() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let repo = CloudTtsRepository::new(&conn);
        let mut meta = metadata();
        meta.provider = CloudTtsProviderType::GeminiTts;
        meta.model = "gemini-3.8-flash-tts".into();
        meta.options_json = "{}".into();
        repo.save(&meta).unwrap();
        let current = repo.get(&meta.id).unwrap();
        let request = current.request(" 原文😀 ".into()).unwrap();
        assert_eq!(request.voice_id, "Kore");
        assert_eq!(request.format, "wav");
        assert_eq!(request.text, " 原文😀 ");
        meta.options_json =
            r#"{"voiceId":"Zephyr","style":"平静","instructions":"慢读","format":"wav"}"#.into();
        repo.save(&meta).unwrap();
        assert_eq!(repo.get(&meta.id).unwrap().options_json, meta.options_json);
        meta.model = "gemini-2.5-pro-preview-tts".into();
        assert!(repo.save(&meta).is_err());
        assert_eq!(repo.get(&meta.id).unwrap().model, "gemini-3.8-flash-tts");
    }
    fn metadata() -> CloudTtsMetadata {
        CloudTtsMetadata {
            id: "cloud-test".into(),
            name: "云端".into(),
            provider: CloudTtsProviderType::OpenAiSpeech,
            base_url: String::new(),
            model: "gpt-4o-mini-tts".into(),
            options_json: r#"{"voiceId":"coral","format":"wav"}"#.into(),
            region: String::new(),
            app_id: String::new(),
            enabled: true,
            created_at: 0,
            updated_at: 0,
            credential_key: "cloud-tts:cloud-test:fixture".into(),
        }
    }

    #[test]
    fn volcengine_v3_is_independent_from_v1_and_keeps_resource_and_defaults() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let repo = CloudTtsRepository::new(&conn);
        let mut meta = metadata();
        meta.provider = CloudTtsProviderType::VolcengineV3;
        meta.model = "seed-tts-2.0".into();
        meta.options_json = "{}".into();
        meta.app_id.clear();
        repo.save(&meta).unwrap();
        let current = repo.get(&meta.id).unwrap();
        assert_eq!(
            current.request("原文".into()).unwrap().voice_id,
            "zh_female_vv_uranus_bigtts"
        );
        assert_eq!(current.request("原文".into()).unwrap().format, "mp3");
        let mut old = meta.clone();
        old.id = "v1".into();
        old.provider = CloudTtsProviderType::Volcengine;
        old.model = "volcano_tts".into();
        old.app_id = "app".into();
        repo.save(&old).unwrap();
        assert_eq!(repo.list().unwrap().len(), 2);
        meta.provider = CloudTtsProviderType::Volcengine;
        meta.app_id = "app".into();
        meta.model = "volcano_tts".into();
        assert!(repo.save(&meta).is_err());
        assert_eq!(
            repo.get(&meta.id).unwrap().provider,
            CloudTtsProviderType::VolcengineV3
        );
    }
    #[test]
    fn metadata_crud_preserves_identity_and_rejects_credentials() {
        let c = Connection::open_in_memory().unwrap();
        c.execute_batch(crate::schema::CREATE_READ_ALOUD_VOICES)
            .unwrap();
        c.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let r = CloudTtsRepository::new(&c);
        let mut e = metadata();
        r.save(&e).unwrap();
        let created = r.get(&e.id).unwrap().created_at;
        e.name = "修改".into();
        e.enabled = false;
        r.save(&e).unwrap();
        assert_eq!(r.get(&e.id).unwrap().created_at, created);
        assert!(!r.get(&e.id).unwrap().enabled);
        let json = serde_json::to_value(&e).unwrap();
        let mut with_secret = json.clone();
        with_secret["apiKey"] = serde_json::json!("private");
        assert!(serde_json::from_value::<CloudTtsMetadata>(with_secret).is_err());
        e.options_json = r#"{"apiKey":"private"}"#.into();
        assert!(r.save(&e).is_err());
        assert_eq!(r.get(&e.id).unwrap().options_json, metadata().options_json);
        assert!(r.delete(&e.id).unwrap());
        assert!(!r.delete(&e.id).unwrap());
    }
    #[test]
    fn options_and_address_validated_before_save() {
        let c = Connection::open_in_memory().unwrap();
        c.execute_batch(crate::schema::CREATE_READ_ALOUD_VOICES)
            .unwrap();
        c.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let r = CloudTtsRepository::new(&c);
        let mut e = metadata();
        for options in [
            "[]",
            r#"{"speed":5}"#,
            r#"{"format":"json"}"#,
            r#"{"voiceId":""}"#,
        ] {
            e.options_json = options.into();
            assert!(r.save(&e).is_err());
        }
        assert!(r.list().unwrap().is_empty());
    }
    #[test]
    fn mimo_metadata_defaults_and_provider_identity_are_preserved() {
        let c = Connection::open_in_memory().unwrap();
        c.execute_batch(crate::schema::CREATE_READ_ALOUD_VOICES)
            .unwrap();
        c.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let repo = CloudTtsRepository::new(&c);
        let mut m = metadata();
        m.provider = CloudTtsProviderType::Mimo;
        m.model = "mimo-v2.5-tts".into();
        m.options_json = "{}".into();
        repo.save(&m).unwrap();
        let saved = repo.get(&m.id).unwrap();
        let request = saved.request("中文".into()).unwrap();
        assert_eq!(request.voice_id, "mimo_default");
        assert_eq!(request.format, "wav");
        m.provider = CloudTtsProviderType::OpenAiSpeech;
        assert!(repo.save(&m).is_err());
        assert_eq!(
            repo.get(&m.id).unwrap().provider,
            CloudTtsProviderType::Mimo
        );
        m.provider = CloudTtsProviderType::Mimo;
        m.options_json = r#"{"format":"mp3"}"#.into();
        assert!(repo.save(&m).is_err());
    }
    #[test]
    fn alibaba_metadata_defaults_crud_and_provider_identity() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch("CREATE TABLE cloud_tts_engines(id TEXT PRIMARY KEY,name TEXT,provider TEXT,baseUrl TEXT,model TEXT,optionsJson TEXT,region TEXT,appId TEXT,enabled INTEGER,createdAt INTEGER,updatedAt INTEGER,credentialKey TEXT);").unwrap();
        let repo = CloudTtsRepository::new(&conn);
        let mut m = metadata();
        m.provider = CloudTtsProviderType::AlibabaCloud;
        m.model = "qwen3-tts-flash".into();
        m.options_json = "{}".into();
        let request = m.request("原文".into()).unwrap();
        assert_eq!(request.voice_id, "Cherry");
        assert_eq!(request.format, "wav");
        repo.save(&m).unwrap();
        assert_eq!(
            repo.get(&m.id).unwrap().provider,
            CloudTtsProviderType::AlibabaCloud
        );
        m.name = "改名".into();
        m.options_json =
            r#"{"voiceId":"Serena","instructions":"用中文朗读","format":"wav"}"#.into();
        repo.save(&m).unwrap();
        assert_eq!(
            repo.get(&m.id)
                .unwrap()
                .request("原文".into())
                .unwrap()
                .voice_id,
            "Serena"
        );
        m.provider = CloudTtsProviderType::Mimo;
        m.model = "mimo-v2.5-tts".into();
        assert!(repo.save(&m).is_err());
        assert_eq!(
            repo.get(&m.id).unwrap().provider,
            CloudTtsProviderType::AlibabaCloud
        );
    }

    #[test]
    fn complete_voice_options_reach_request_and_keep_strict_validation() {
        let mut m = metadata();
        m.provider = CloudTtsProviderType::AlibabaCloud;
        m.model = "qwen3-tts-instruct-flash".into();
        m.options_json = serde_json::json!({
            "voiceId": "Serena", "locale": "English", "role": "旁白",
            "style": "平静", "instructions": "保留指令", "speed": 1.5,
            "pitch": 1.2, "volume": 0.0, "sampleRate": 24000, "format": "wav",
        })
        .to_string();
        m.validate().unwrap();
        let request = m.request("原文".into()).unwrap();
        assert_eq!(request.locale, "English");
        assert_eq!(request.role, "旁白");
        assert_eq!(request.pitch, 1.2);
        assert_eq!(request.volume, 0.0);
        assert_eq!(request.sample_rate, Some(24000));
        assert_eq!(request.speed, 1.5);
        let prepared = cloud_tts_provider(m.provider)
            .prepare(&m.engine("fixture".into()), &request)
            .unwrap();
        let CloudSpeechBody::Json(body) = prepared.body else {
            panic!("预期 JSON 请求")
        };
        assert_eq!(body["input"]["language_type"], "English");
        for options in [
            r#"{"apiKey":"不能混入"}"#,
            r#"{"baseUrl":"http://example.org"}"#,
            r#"{"sampleRate":-1}"#,
            r#"{"sampleRate":4294967296}"#,
            r#"{"pitch":"高"}"#,
        ] {
            m.options_json = options.into();
            assert!(m.request("原文".into()).is_err());
        }
        m.options_json = "{}".into();
        let request = m.request("原文".into()).unwrap();
        assert_eq!(request.locale, "");
        assert_eq!(request.pitch, 1.0);
        assert_eq!(request.volume, 1.0);
        assert_eq!(request.sample_rate, None);
    }

    #[test]
    fn azure_region_defaults_and_full_voice_options_round_trip_without_secrets() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let repo = CloudTtsRepository::new(&conn);
        let mut m = metadata();
        m.provider = CloudTtsProviderType::AzureSpeech;
        m.model.clear();
        m.region = "eastasia".into();
        m.options_json = "{}".into();
        repo.save(&m).unwrap();
        let current = repo.get(&m.id).unwrap();
        assert_eq!(current.region, "eastasia");
        let request = current.request("文本".into()).unwrap();
        assert_eq!(request.voice_id, "zh-CN-XiaoxiaoNeural");
        assert_eq!(request.format, "mp3");
        m.options_json = r#"{"locale":"zh-CN","style":"cheerful","role":"Girl","pitch":1.2,"volume":0.8,"format":"ogg"}"#.into();
        repo.save(&m).unwrap();
        let current = repo.get(&m.id).unwrap();
        assert_eq!(current.options_json, m.options_json);
        assert_eq!(current.request("文本".into()).unwrap().role, "Girl");
        assert!(
            !serde_json::to_string(&current.engine("private-fixture".into()))
                .unwrap()
                .contains("private-fixture")
        );
        m.region.clear();
        assert!(repo.save(&m).is_err());
        assert_eq!(repo.get(&m.id).unwrap().region, "eastasia");
    }
}
