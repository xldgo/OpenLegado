//! 独立音色目录：按单个引擎同步，保留用户标记。
use legado_core::{LegadoError, LegadoResult, tts_catalog::CatalogDraft};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
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
                && v.managed_by == managed
                && !incoming.contains(&v.id)
        }) {
            if kind == "http" {
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
}
