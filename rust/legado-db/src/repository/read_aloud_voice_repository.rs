//! 独立音色目录：按单个引擎同步，保留用户标记。
use legado_core::{LegadoError, LegadoResult, tts_catalog::CatalogDraft};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ReadAloudVoice {
    pub id: String,
    pub engine_type: String,
    pub engine_id: String,
    pub speaker_id: String,
    pub display_name: String,
    pub traits_json: String,
    pub emotion_catalog_json: String,
    pub managed_by: String,
    pub enabled: bool,
    pub available: bool,
    pub excluded: bool,
    pub revision: i64,
    pub created_at: i64,
    pub updated_at: i64,
}
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SystemVoiceEntry {
    pub speaker_id: String,
    pub display_name: String,
    pub traits_json: String,
}
fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
pub fn stable_id(kind: &str, engine: &str, speaker: &str) -> String {
    let hash = Sha256::digest(format!("{kind}\0{engine}\0{speaker}").as_bytes())
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect::<String>();
    format!("voice:{}", &hash[..32])
}
pub struct ReadAloudVoiceRepository<'a> {
    conn: &'a Connection,
}
impl<'a> ReadAloudVoiceRepository<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }
    pub fn list(&self) -> LegadoResult<Vec<ReadAloudVoice>> {
        let mut stmt=self.conn.prepare("SELECT id,engineType,engineId,speakerId,displayName,traitsJson,emotionCatalogJson,managedBy,enabled,available,excluded,revision,createdAt,updatedAt FROM read_aloud_voices ORDER BY available DESC,enabled DESC,displayName COLLATE NOCASE,id").map_err(db_error)?;
        let rows = stmt
            .query_map([], |r| {
                Ok(ReadAloudVoice {
                    id: r.get(0)?,
                    engine_type: r.get(1)?,
                    engine_id: r.get(2)?,
                    speaker_id: r.get(3)?,
                    display_name: r.get(4)?,
                    traits_json: r.get(5)?,
                    emotion_catalog_json: r.get(6)?,
                    managed_by: r.get(7)?,
                    enabled: r.get(8)?,
                    available: r.get(9)?,
                    excluded: r.get(10)?,
                    revision: r.get(11)?,
                    created_at: r.get(12)?,
                    updated_at: r.get(13)?,
                })
            })
            .map_err(db_error)?;
        rows.collect::<Result<Vec<_>, _>>().map_err(db_error)
    }
    /// 合成仅捕获当前 HTTP 引擎的情感目录；默认回落优先来源目录。
    pub fn http_emotion_catalogs(&self, engine_id: i64) -> LegadoResult<Vec<(String, String)>> {
        let mut statement = self
            .conn
            .prepare(
                "SELECT speakerId,emotionCatalogJson FROM read_aloud_voices
             WHERE engineType='http' AND engineId=?1
             ORDER BY CASE WHEN managedBy='http_source_catalog' THEN 0 ELSE 1 END,
                      available DESC,displayName COLLATE NOCASE,id",
            )
            .map_err(db_error)?;
        let rows = statement
            .query_map([engine_id.to_string()], |row| {
                Ok((row.get(0)?, row.get(1)?))
            })
            .map_err(db_error)?;
        rows.collect::<Result<Vec<_>, _>>().map_err(db_error)
    }

    pub fn get(&self, id: &str) -> LegadoResult<ReadAloudVoice> {
        self.list()?
            .into_iter()
            .find(|v| v.id == id)
            .ok_or_else(|| LegadoError::Ffi("音色不存在".into()))
    }
    /// 用户音色与目录共用稳定身份，目录发现不得覆盖自定义参数。
    pub fn save_user(&self, voice: &ReadAloudVoice) -> LegadoResult<()> {
        if !matches!(voice.engine_type.as_str(), "http" | "system" | "cloud_tts")
            || voice.speaker_id.trim().is_empty()
            || voice.display_name.trim().is_empty()
            || voice.id != stable_id(&voice.engine_type, &voice.engine_id, &voice.speaker_id)
        {
            return Err(LegadoError::Ffi("音色身份或名称无效".into()));
        }
        let traits: serde_json::Value = serde_json::from_str(&voice.traits_json)?;
        if !traits.is_object() {
            return Err(LegadoError::Ffi("用户音色参数必须为对象".into()));
        }
        let emotions: serde_json::Value = serde_json::from_str(&voice.emotion_catalog_json)?;
        if !emotions.is_array() {
            return Err(LegadoError::Ffi("音色情感目录必须为数组".into()));
        }
        match voice.engine_type.as_str() {
            "cloud_tts" => {
                let mut engine = super::cloud_tts_repository::CloudTtsRepository::new(self.conn)
                    .get(&voice.engine_id)?;
                let mut options = traits.as_object().unwrap().clone();
                options.insert("voiceId".into(), serde_json::json!(voice.speaker_id));
                engine.options_json = serde_json::to_string(&options)?;
                engine.validate()?;
            }
            "http" => {
                let exists: bool = self
                    .conn
                    .query_row(
                        "SELECT EXISTS(SELECT 1 FROM httpTTS WHERE id=?1)",
                        [&voice.engine_id],
                        |r| r.get(0),
                    )
                    .map_err(db_error)?;
                if !exists {
                    return Err(LegadoError::Ffi("HTTP 引擎不存在".into()));
                }
            }
            _ if !voice.engine_id.starts_with("system:") => {
                return Err(LegadoError::Ffi("系统引擎标识无效".into()));
            }
            _ => {}
        }
        let previous = self.list()?.into_iter().find(|v| v.id == voice.id);
        let timestamp = now();
        self.conn.execute("INSERT INTO read_aloud_voices(id,engineType,engineId,speakerId,displayName,traitsJson,emotionCatalogJson,managedBy,enabled,available,excluded,revision,createdAt,updatedAt) VALUES(?1,?2,?3,?4,?5,?6,?7,'user',?8,?9,?10,?11,?12,?13) ON CONFLICT(id) DO UPDATE SET displayName=excluded.displayName,traitsJson=excluded.traitsJson,emotionCatalogJson=excluded.emotionCatalogJson,managedBy='user',enabled=excluded.enabled,available=excluded.available,excluded=excluded.excluded,revision=excluded.revision,updatedAt=excluded.updatedAt",params![voice.id,voice.engine_type,voice.engine_id,voice.speaker_id,voice.display_name,voice.traits_json,voice.emotion_catalog_json,voice.enabled,voice.available,voice.excluded,previous.as_ref().map_or(1,|v|v.revision+1),previous.as_ref().map_or(timestamp,|v|v.created_at),timestamp]).map_err(db_error)?;
        Ok(())
    }
    pub fn delete_user(&self, id: &str) -> LegadoResult<bool> {
        Ok(self
            .conn
            .execute(
                "DELETE FROM read_aloud_voices WHERE id=?1 AND managedBy='user'",
                [id],
            )
            .map_err(db_error)?
            > 0)
    }
    pub fn sync_http(&self, id: i64, draft: &CatalogDraft, revision: i64) -> LegadoResult<()> {
        if draft.speakers.is_empty() {
            return Ok(());
        }
        let entries = draft
            .speakers
            .iter()
            .map(|s| {
                Ok((
                    s.tone_id.clone(),
                    s.speaker_name.clone(),
                    serde_json::to_string(&s.tags)?,
                ))
            })
            .collect::<LegadoResult<Vec<_>>>()?;
        self.sync(
            "http",
            &id.to_string(),
            entries,
            &serde_json::to_string(&draft.emotions)?,
            "http_source_catalog",
            revision,
        )
    }
    pub fn sync_system(&self, engine: &str, entries: Vec<SystemVoiceEntry>) -> LegadoResult<()> {
        if !engine.starts_with("system:") {
            return Err(LegadoError::Ffi("系统音色引擎标识无效".into()));
        }
        let tx = self.conn.unchecked_transaction().map_err(db_error)?;
        ReadAloudVoiceRepository::new(&tx).sync(
            "system",
            engine,
            entries
                .into_iter()
                .map(|e| (e.speaker_id, e.display_name, e.traits_json))
                .collect(),
            "[]",
            "system_catalog",
            0,
        )?;
        tx.commit().map_err(db_error)
    }
    fn sync(
        &self,
        kind: &str,
        engine: &str,
        entries: Vec<(String, String, String)>,
        emotions: &str,
        managed: &str,
        revision: i64,
    ) -> LegadoResult<()> {
        let old = self.list()?;
        let timestamp = now();
        let mut incoming = std::collections::HashSet::new();
        for (speaker, name, traits) in entries {
            if speaker.trim().is_empty() || name.trim().is_empty() {
                return Err(LegadoError::Ffi("音色 ID 与名称不能为空".into()));
            }
            let _: serde_json::Value = serde_json::from_str(&traits)?;
            let id = stable_id(kind, engine, &speaker);
            if !incoming.insert(id.clone()) {
                continue;
            }
            let previous = old.iter().find(|v| v.id == id);
            if previous.is_some_and(|v| v.managed_by == "user") {
                self.conn
                    .execute(
                        "UPDATE read_aloud_voices SET available=1 WHERE id=?1",
                        [&id],
                    )
                    .map_err(db_error)?;
                continue;
            }

            let changed = previous.is_none_or(|v| {
                v.display_name != name
                    || v.traits_json != traits
                    || v.emotion_catalog_json != emotions
                    || v.managed_by != managed
            });
            let rev = previous.map_or(revision, |v| {
                revision.max(v.revision + if changed { 1 } else { 0 })
            });
            let updated = previous
                .filter(|v| !changed && v.available && v.revision == rev)
                .map_or(timestamp, |v| v.updated_at);
            self.conn.execute("INSERT INTO read_aloud_voices(id,engineType,engineId,speakerId,displayName,traitsJson,emotionCatalogJson,managedBy,enabled,available,excluded,revision,createdAt,updatedAt) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,1,?10,?11,?12,?13) ON CONFLICT(id) DO UPDATE SET displayName=excluded.displayName,traitsJson=excluded.traitsJson,emotionCatalogJson=excluded.emotionCatalogJson,managedBy=excluded.managedBy,available=1,revision=excluded.revision,updatedAt=excluded.updatedAt",params![id,kind,engine,speaker,name,traits,emotions,managed,previous.is_none_or(|v|v.enabled),previous.is_some_and(|v|v.excluded),rev,previous.map_or(timestamp,|v|v.created_at),updated]).map_err(db_error)?;
        }
        for v in old.iter().filter(|v| {
            v.engine_type == kind
                && v.engine_id == engine
                && (v.managed_by == managed || v.managed_by == "user")
                && !incoming.contains(&v.id)
        }) {
            if kind == "http" && v.managed_by != "user" {
                self.conn
                    .execute("DELETE FROM read_aloud_voices WHERE id=?1", [&v.id])
                    .map_err(db_error)?;
            } else {
                self.conn.execute("UPDATE read_aloud_voices SET available=0,updatedAt=?2 WHERE id=?1 AND available=1",params![v.id,timestamp]).map_err(db_error)?;
            }
        }
        Ok(())
    }
    pub fn clear_http(&self, id: i64) -> LegadoResult<()> {
        self.conn
            .execute(
                "DELETE FROM read_aloud_voices WHERE engineType='http' AND engineId=?1",
                [id.to_string()],
            )
            .map_err(db_error)?;
        Ok(())
    }
    pub fn set_flags(&self, id: &str, enabled: bool, excluded: bool) -> LegadoResult<bool> {
        Ok(self
            .conn
            .execute(
                "UPDATE read_aloud_voices SET enabled=?2,excluded=?3,updatedAt=?4 WHERE id=?1",
                params![id, enabled, excluded, now()],
            )
            .map_err(db_error)?
            > 0)
    }
}
fn db_error(e: rusqlite::Error) -> LegadoError {
    LegadoError::Database(e.to_string())
}
#[cfg(test)]
mod tests {
    use super::*;
    fn conn() -> Connection {
        let c = Connection::open_in_memory().unwrap();
        c.execute_batch(crate::schema::CREATE_READ_ALOUD_VOICES)
            .unwrap();
        c
    }
    #[test]
    fn http_emotion_snapshot_is_scoped_and_prefers_source_catalog() {
        let conn = conn();
        let repo = ReadAloudVoiceRepository::new(&conn);
        let input = serde_json::json!({"speakersJson":r#"[{"speakerName":"A","toneID":"a"},{"speakerName":"Z","toneID":"z"}]"#, "emotionsJson":r#"[{"emotionName":"高兴","emotionTag":"happy"}]"#});
        repo.sync_http(1, &legado_core::tts_catalog::parse(&input), 1)
            .unwrap();
        repo.sync_http(2, &draft("other"), 1).unwrap();
        conn.execute("UPDATE read_aloud_voices SET managedBy='user',emotionCatalogJson='[]' WHERE engineId='1' AND speakerId='a'", []).unwrap();
        let snapshot = repo.http_emotion_catalogs(1).unwrap();
        assert_eq!(snapshot.len(), 2);
        assert_eq!(snapshot[0].0, "z");
        assert_eq!(snapshot[1], ("a".into(), "[]".into()));
        assert_eq!(
            serde_json::from_str::<Vec<legado_core::tts_catalog::EmotionDraft>>(&snapshot[0].1)
                .unwrap()[0]
                .emotion_tag,
            "happy"
        );
        assert!(repo.http_emotion_catalogs(99).unwrap().is_empty());
    }
    fn draft(id: &str) -> CatalogDraft {
        legado_core::tts_catalog::parse(
            &serde_json::json!({"speakersJson":format!("[{{\"speakerName\":\"中文\",\"toneID\":\"{id}\"}}]")}),
        )
    }
    #[test]
    fn sync_preserves_user_flags_scope_and_missing_catalog() {
        let c = conn();
        let r = ReadAloudVoiceRepository::new(&c);
        r.sync_http(1, &draft("a"), 1).unwrap();
        r.sync_http(2, &draft("b"), 1).unwrap();
        let a = stable_id("http", "1", "a");
        r.set_flags(&a, false, true).unwrap();
        r.sync_http(1, &draft("a"), 1).unwrap();
        r.sync_http(1, &CatalogDraft::default(), 0).unwrap();
        let rows = r.list().unwrap();
        assert_eq!(rows.len(), 2);
        let old = rows.iter().find(|v| v.id == a).unwrap();
        assert!(!old.enabled);
        assert!(old.excluded);
        r.clear_http(1).unwrap();
        assert_eq!(r.list().unwrap()[0].engine_id, "2");
    }
    #[test]
    fn system_disappearance_and_reappearance_keep_flags() {
        let c = conn();
        let r = ReadAloudVoiceRepository::new(&c);
        let e = || {
            vec![SystemVoiceEntry {
                speaker_id: "a".into(),
                display_name: "中文".into(),
                traits_json: "{}".into(),
            }]
        };
        r.sync_system("system:device", e()).unwrap();
        let id = stable_id("system", "system:device", "a");
        r.set_flags(&id, true, true).unwrap();
        r.sync_system("system:device", vec![]).unwrap();
        assert!(!r.list().unwrap()[0].available);
        r.sync_system("system:device", e()).unwrap();
        assert!(r.list().unwrap()[0].available);
        assert!(r.list().unwrap()[0].excluded);
    }
    #[test]
    fn system_invalid_entry_rolls_back_entire_sync() {
        let c = conn();
        let r = ReadAloudVoiceRepository::new(&c);
        assert!(
            r.sync_system(
                "system:",
                vec![
                    SystemVoiceEntry {
                        speaker_id: "a".into(),
                        display_name: "甲".into(),
                        traits_json: "{}".into()
                    },
                    SystemVoiceEntry {
                        speaker_id: "".into(),
                        display_name: "乙".into(),
                        traits_json: "{}".into()
                    }
                ]
            )
            .is_err()
        );
        assert!(r.list().unwrap().is_empty());
    }
    #[test]
    fn user_presets_are_independent_and_discovery_keeps_custom_parameters() {
        let c = conn();
        let r = ReadAloudVoiceRepository::new(&c);
        let entries = || {
            vec![
                SystemVoiceEntry {
                    speaker_id: "a".into(),
                    display_name: "目录名称".into(),
                    traits_json: r#"{"voiceKey":"a"}"#.into(),
                },
                SystemVoiceEntry {
                    speaker_id: "b".into(),
                    display_name: "第二音色".into(),
                    traits_json: r#"{"voiceKey":"b"}"#.into(),
                },
            ]
        };
        r.sync_system("system:device", entries()).unwrap();
        let mut voice = r.get(&stable_id("system", "system:device", "a")).unwrap();
        let created = voice.created_at;
        voice.display_name = "用户名称".into();
        voice.traits_json = r#"{"voiceKey":"a","speed":1.5}"#.into();
        r.save_user(&voice).unwrap();
        r.sync_system("system:device", entries()).unwrap();
        let saved = r.get(&voice.id).unwrap();
        assert_eq!(saved.display_name, "用户名称");
        assert_eq!(saved.traits_json, voice.traits_json);
        assert_eq!(saved.created_at, created);
        assert_eq!(saved.managed_by, "user");
        r.sync_system("system:device", vec![]).unwrap();
        assert!(!r.get(&voice.id).unwrap().available);
        r.sync_system("system:device", entries()).unwrap();
        assert!(r.get(&voice.id).unwrap().available);
        assert!(
            !r.delete_user(&stable_id("system", "system:device", "b"))
                .unwrap()
        );
        assert!(r.delete_user(&voice.id).unwrap());
        assert_eq!(r.list().unwrap().len(), 1);
    }
    #[test]
    fn cloud_presets_validate_identity_and_keep_engine_unchanged() {
        use crate::repository::cloud_tts_repository::*;
        let c = conn();
        c.execute_batch(crate::schema::CREATE_CLOUD_TTS_ENGINES)
            .unwrap();
        let engines = CloudTtsRepository::new(&c);
        let engine = CloudTtsMetadata {
            id: "cloud".into(),
            name: "云".into(),
            provider: legado_core::cloud_tts::CloudTtsProviderType::OpenAiSpeech,
            base_url: String::new(),
            model: "gpt-4o-mini-tts".into(),
            options_json: "{}".into(),
            region: String::new(),
            app_id: String::new(),
            enabled: true,
            created_at: 0,
            updated_at: 0,
            credential_key: "cloud-tts:cloud:fixture".into(),
        };
        engines.save(&engine).unwrap();
        let r = ReadAloudVoiceRepository::new(&c);
        for speaker in ["alloy", "nova"] {
            let voice = ReadAloudVoice {
                id: stable_id("cloud_tts", "cloud", speaker),
                engine_type: "cloud_tts".into(),
                engine_id: "cloud".into(),
                speaker_id: speaker.into(),
                display_name: speaker.into(),
                traits_json: r#"{"format":"wav","speed":1.1,"instructions":"中文"}"#.into(),
                emotion_catalog_json: "[]".into(),
                managed_by: "user".into(),
                enabled: true,
                available: true,
                excluded: false,
                revision: 0,
                created_at: 0,
                updated_at: 0,
            };
            r.save_user(&voice).unwrap();
        }
        assert_eq!(r.list().unwrap().len(), 2);
        assert_eq!(engines.get("cloud").unwrap().options_json, "{}");
        let mut bad = r.list().unwrap()[0].clone();
        bad.engine_id = "other".into();
        assert!(r.save_user(&bad).is_err());
        bad = r.list().unwrap()[0].clone();
        bad.traits_json = r#"{"apiKey":"secret"}"#.into();
        assert!(r.save_user(&bad).is_err());
        engines.delete("cloud").unwrap();
        assert!(r.list().unwrap().is_empty());
    }
}
