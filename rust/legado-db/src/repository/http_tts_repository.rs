//! HttpTts Repository - httpTTS 表 CRUD（对齐 Room v95 + 上游 speed/synthesisThreadCount + Rust 扩展）

use rusqlite::{Connection, OptionalExtension, params};
use serde::de::{self, Deserializer};
use serde::{Deserialize, Serialize};

use legado_core::{LegadoError, LegadoResult};

/// 合成并发上限（对齐上游 `HttpTTS.MAX_SYNTHESIS_THREAD_COUNT`）
pub const MAX_SYNTHESIS_THREAD_COUNT: i32 = 8;

fn default_synthesis_thread_count() -> i32 {
    1
}

fn default_is_enabled() -> bool {
    true
}

fn deserialize_login_ui<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let val: Option<serde_json::Value> = Option::deserialize(deserializer)?;
    match val {
        None | Some(serde_json::Value::Null) => Ok(None),
        Some(serde_json::Value::String(s)) => Ok(Some(s)),
        Some(serde_json::Value::Array(arr)) => {
            serde_json::to_string(&arr).map(Some).map_err(de::Error::custom)
        }
        Some(other) => Ok(Some(other.to_string())),
    }
}

fn deserialize_bool_or_int<'de, D>(deserializer: D) -> Result<Option<bool>, D::Error>
where
    D: Deserializer<'de>,
{
    let val: Option<serde_json::Value> = Option::deserialize(deserializer)?;
    match val {
        None | Some(serde_json::Value::Null) => Ok(None),
        Some(serde_json::Value::Bool(b)) => Ok(Some(b)),
        Some(serde_json::Value::Number(n)) => Ok(n.as_i64().map(|v| v != 0)),
        Some(serde_json::Value::String(s)) => {
            let trimmed = s.trim();
            if trimmed.eq_ignore_ascii_case("true") || trimmed == "1" {
                Ok(Some(true))
            } else if trimmed.eq_ignore_ascii_case("false") || trimmed == "0" {
                Ok(Some(false))
            } else {
                Ok(None)
            }
        }
        _ => Ok(None),
    }
}

fn deserialize_enabled<'de, D>(deserializer: D) -> Result<bool, D::Error>
where
    D: Deserializer<'de>,
{
    Ok(deserialize_bool_or_int(deserializer)?.unwrap_or(true))
}

fn deserialize_synthesis_thread_count<'de, D>(deserializer: D) -> Result<i32, D::Error>
where
    D: Deserializer<'de>,
{
    let val: Option<i32> = Option::deserialize(deserializer)?;
    Ok(val
        .unwrap_or(1)
        .clamp(1, MAX_SYNTHESIS_THREAD_COUNT))
}

/// HTTP TTS 朗读源（全字段 camelCase 对齐 Dart `HttpTts` 与上游 `HttpTTS`）
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HttpTts {
    #[serde(default)]
    pub id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub content_type: Option<String>,
    #[serde(default)]
    pub pause_duration: i32,
    #[serde(default)]
    pub concurrent_rate: Option<String>,
    #[serde(default)]
    pub login_url: Option<String>,
    #[serde(default, deserialize_with = "deserialize_login_ui")]
    pub login_ui: Option<String>,
    #[serde(default)]
    pub header: Option<String>,
    #[serde(default)]
    pub js_lib: Option<String>,
    #[serde(default, deserialize_with = "deserialize_bool_or_int")]
    pub enabled_cookie_jar: Option<bool>,
    #[serde(default)]
    pub login_check_js: Option<String>,
    #[serde(default)]
    pub speed: Option<i32>,
    #[serde(
        default = "default_synthesis_thread_count",
        deserialize_with = "deserialize_synthesis_thread_count"
    )]
    pub synthesis_thread_count: i32,
    #[serde(default, alias = "created_at")]
    pub last_update_time: i64,
    #[serde(
        default = "default_is_enabled",
        alias = "is_enabled",
        deserialize_with = "deserialize_enabled"
    )]
    pub is_enabled: bool,
}

impl Default for HttpTts {
    fn default() -> Self {
        Self {
            id: 0,
            name: String::new(),
            url: String::new(),
            content_type: None,
            pause_duration: 0,
            concurrent_rate: Some("0".to_string()),
            login_url: None,
            login_ui: None,
            header: None,
            js_lib: None,
            enabled_cookie_jar: Some(false),
            login_check_js: None,
            speed: None,
            synthesis_thread_count: 1,
            last_update_time: 0,
            is_enabled: true,
        }
    }
}

const SELECT_ALL_COLUMNS: &str = "
    SELECT id, name, url, contentType, pauseDuration, concurrentRate,
           loginUrl, loginUi, header, jsLib, enabledCookieJar, loginCheckJs,
           speed, synthesisThreadCount, lastUpdateTime, isEnabled
    FROM httpTTS
";

/// HTTP TTS 数据访问层
pub struct HttpTtsRepository<'a> {
    conn: &'a Connection,
}

impl<'a> HttpTtsRepository<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }

    /// 分配下一个正整数 ID（与 Android 导入负/正时间戳 ID 共存）
    fn next_id(&self) -> i64 {
        self.conn
            .query_row("SELECT COALESCE(MAX(id), 0) + 1 FROM httpTTS", [], |row| {
                row.get::<_, i64>(0)
            })
            .unwrap_or(1)
            .max(1)
    }

    /// 插入一条 TTS 源（仅传名称与 URL 的便捷入口），返回新 ID
    pub fn insert(&self, name: &str, url: &str) -> LegadoResult<i64> {
        let entity = HttpTts {
            name: name.to_string(),
            url: url.to_string(),
            ..HttpTts::default()
        };
        self.insert_entity(&entity)
    }

    /// 插入或覆盖完整 TTS 源实体，返回最终 ID
    ///
    /// - `tts.id != 0`：保留输入 ID（使用 `INSERT OR REPLACE` 对齐原版 Room `@Insert(onConflict = REPLACE)`）
    /// - `tts.id == 0`：自动分配正 ID
    pub fn insert_entity(&self, tts: &HttpTts) -> LegadoResult<i64> {
        let id = if tts.id != 0 { tts.id } else { self.next_id() };
        let last_update_time = if tts.last_update_time > 0 {
            tts.last_update_time
        } else {
            current_time_millis()
        };
        let concurrent_rate = tts
            .concurrent_rate
            .clone()
            .unwrap_or_else(|| "0".to_string());
        let enabled_cookie_jar = tts.enabled_cookie_jar.unwrap_or(false) as i32;
        let synthesis_thread_count = tts
            .synthesis_thread_count
            .clamp(1, MAX_SYNTHESIS_THREAD_COUNT);
        let is_enabled = tts.is_enabled as i32;

        self.conn
            .execute(
                "INSERT OR REPLACE INTO httpTTS (
                    id, name, url, contentType, pauseDuration, concurrentRate,
                    loginUrl, loginUi, header, jsLib, enabledCookieJar, loginCheckJs,
                    speed, synthesisThreadCount, lastUpdateTime, isEnabled
                 ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6,
                    ?7, ?8, ?9, ?10, ?11, ?12,
                    ?13, ?14, ?15, ?16
                 )",
                params![
                    id,
                    tts.name,
                    tts.url,
                    tts.content_type,
                    tts.pause_duration,
                    concurrent_rate,
                    tts.login_url,
                    tts.login_ui,
                    tts.header,
                    tts.js_lib,
                    enabled_cookie_jar,
                    tts.login_check_js,
                    tts.speed,
                    synthesis_thread_count,
                    last_update_time,
                    is_enabled,
                ],
            )
            .map_err(|e| LegadoError::Database(format!("插入 TTS 源失败: {e}")))?;
        Ok(id)
    }

    /// 获取所有 TTS 源
    pub fn find_all(&self) -> LegadoResult<Vec<HttpTts>> {
        let sql = format!("{SELECT_ALL_COLUMNS} ORDER BY lastUpdateTime DESC, id ASC");
        let mut stmt = self
            .conn
            .prepare(&sql)
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;

        let rows = stmt
            .query_map([], row_to_http_tts)
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| LegadoError::Database(format!("读取行失败: {e}")))?;
        Ok(rows)
    }

    /// 按 ID 查询
    pub fn find_by_id(&self, id: i64) -> LegadoResult<Option<HttpTts>> {
        let sql = format!("{SELECT_ALL_COLUMNS} WHERE id = ?1");
        let mut stmt = self
            .conn
            .prepare(&sql)
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;

        let result = stmt
            .query_row(params![id], row_to_http_tts)
            .optional()
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?;
        Ok(result)
    }

    /// 更新 TTS 源（仅更新名称与 URL，保留其它既有列）
    pub fn update(&self, id: i64, name: &str, url: &str) -> LegadoResult<bool> {
        let now = current_time_millis();
        let affected = self
            .conn
            .execute(
                "UPDATE httpTTS SET name = ?1, url = ?2, lastUpdateTime = ?3 WHERE id = ?4",
                params![name, url, now, id],
            )
            .map_err(|e| LegadoError::Database(format!("更新 TTS 源失败: {e}")))?;
        Ok(affected > 0)
    }

    /// 按 ID 原地更新完整 TTS 源实体；目标不存在返回 `Ok(false)`，不删除或新增记录
    pub fn update_entity(&self, tts: &HttpTts) -> LegadoResult<bool> {
        let now = current_time_millis();
        let concurrent_rate = tts
            .concurrent_rate
            .clone()
            .unwrap_or_else(|| "0".to_string());
        let enabled_cookie_jar = tts.enabled_cookie_jar.unwrap_or(false) as i32;
        let synthesis_thread_count = tts
            .synthesis_thread_count
            .clamp(1, MAX_SYNTHESIS_THREAD_COUNT);
        let is_enabled = tts.is_enabled as i32;

        let affected = self
            .conn
            .execute(
                "UPDATE httpTTS SET
                    name = ?1,
                    url = ?2,
                    contentType = ?3,
                    pauseDuration = ?4,
                    concurrentRate = ?5,
                    loginUrl = ?6,
                    loginUi = ?7,
                    header = ?8,
                    jsLib = ?9,
                    enabledCookieJar = ?10,
                    loginCheckJs = ?11,
                    speed = ?12,
                    synthesisThreadCount = ?13,
                    lastUpdateTime = ?14,
                    isEnabled = ?15
                 WHERE id = ?16",
                params![
                    tts.name,
                    tts.url,
                    tts.content_type,
                    tts.pause_duration,
                    concurrent_rate,
                    tts.login_url,
                    tts.login_ui,
                    tts.header,
                    tts.js_lib,
                    enabled_cookie_jar,
                    tts.login_check_js,
                    tts.speed,
                    synthesis_thread_count,
                    now,
                    is_enabled,
                    tts.id,
                ],
            )
            .map_err(|e| LegadoError::Database(format!("更新 TTS 源失败: {e}")))?;
        Ok(affected > 0)
    }

    /// 删除 TTS 源
    pub fn delete(&self, id: i64) -> LegadoResult<bool> {
        let affected = self
            .conn
            .execute("DELETE FROM httpTTS WHERE id = ?1", params![id])
            .map_err(|e| LegadoError::Database(format!("删除 TTS 源失败: {e}")))?;
        Ok(affected > 0)
    }

    /// 获取所有已启用的 TTS 源
    pub fn find_enabled(&self) -> LegadoResult<Vec<HttpTts>> {
        let sql =
            format!("{SELECT_ALL_COLUMNS} WHERE isEnabled = 1 ORDER BY lastUpdateTime DESC, id ASC");
        let mut stmt = self
            .conn
            .prepare(&sql)
            .map_err(|e| LegadoError::Database(format!("准备查询失败: {e}")))?;

        let rows = stmt
            .query_map([], row_to_http_tts)
            .map_err(|e| LegadoError::Database(format!("查询失败: {e}")))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| LegadoError::Database(format!("读取行失败: {e}")))?;
        Ok(rows)
    }

    /// 设置启用/禁用状态
    pub fn set_enabled(&self, id: i64, enabled: bool) -> LegadoResult<bool> {
        let affected = self
            .conn
            .execute(
                "UPDATE httpTTS SET isEnabled = ?1 WHERE id = ?2",
                params![enabled as i32, id],
            )
            .map_err(|e| LegadoError::Database(format!("设置 TTS 启用状态失败: {e}")))?;
        Ok(affected > 0)
    }
}

fn row_to_http_tts(row: &rusqlite::Row<'_>) -> rusqlite::Result<HttpTts> {
    let enabled_cookie_jar: Option<i32> = row.get(10)?;
    let synthesis_thread_count: Option<i32> = row.get(13)?;
    let is_enabled: i32 = row.get(15)?;
    Ok(HttpTts {
        id: row.get(0)?,
        name: row.get(1)?,
        url: row.get(2)?,
        content_type: row.get(3)?,
        pause_duration: row.get::<_, Option<i32>>(4)?.unwrap_or(0),
        concurrent_rate: row.get(5)?,
        login_url: row.get(6)?,
        login_ui: row.get(7)?,
        header: row.get(8)?,
        js_lib: row.get(9)?,
        enabled_cookie_jar: Some(enabled_cookie_jar.unwrap_or(0) != 0),
        login_check_js: row.get(11)?,
        speed: row.get(12)?,
        synthesis_thread_count: synthesis_thread_count
            .unwrap_or(1)
            .clamp(1, MAX_SYNTHESIS_THREAD_COUNT),
        last_update_time: row.get::<_, Option<i64>>(14)?.unwrap_or(0),
        is_enabled: is_enabled != 0,
    })
}

fn current_time_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_insert_and_find_all() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = HttpTtsRepository::new(db.connection());
        let id = repo.insert("引擎A", "http://a.example/tts").unwrap();
        assert!(id > 0);
        let all = repo.find_all().unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].name, "引擎A");
        assert!(all[0].is_enabled);
        assert_eq!(all[0].synthesis_thread_count, 1);
    }

    #[test]
    fn test_update_delete_set_enabled() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = HttpTtsRepository::new(db.connection());
        let id = repo.insert("旧名", "http://old").unwrap();
        assert!(repo.update(id, "新名", "http://new").unwrap());
        let item = repo.find_by_id(id).unwrap().unwrap();
        assert_eq!(item.name, "新名");
        assert!(repo.set_enabled(id, false).unwrap());
        assert!(!repo.find_by_id(id).unwrap().unwrap().is_enabled);
        assert!(repo.find_enabled().unwrap().is_empty());
        assert!(repo.delete(id).unwrap());
        assert!(repo.find_by_id(id).unwrap().is_none());
    }

    #[test]
    fn test_full_entity_roundtrip_and_login_ui_array_deserialization() {
        let db = crate::init_in_memory_database().unwrap();
        let repo = HttpTtsRepository::new(db.connection());

        let raw_json = r#"{
            "id": -29,
            "name": "阿里云语音",
            "url": "https://nls.example.com/tts",
            "contentType": "audio/mpeg",
            "pauseDuration": 150,
            "concurrentRate": "1500",
            "loginUrl": "function login(){}",
            "loginUi": [{"name": "AppKey", "type": "text"}],
            "header": "{\"X-Token\":\"abc\"}",
            "jsLib": "var v = 1;",
            "enabledCookieJar": true,
            "loginCheckJs": "result",
            "speed": 12,
            "synthesisThreadCount": 99,
            "lastUpdateTime": 1700000000000,
            "isEnabled": false
        }"#;

        let parsed: HttpTts = serde_json::from_str(raw_json).unwrap();
        assert_eq!(parsed.id, -29);
        assert_eq!(
            parsed.login_ui.as_deref(),
            Some(r#"[{"name":"AppKey","type":"text"}]"#)
        );
        assert_eq!(parsed.synthesis_thread_count, 8);
        assert_eq!(parsed.speed, Some(12));
        assert_eq!(parsed.pause_duration, 150);
        assert!(!parsed.is_enabled);

        let inserted_id = repo.insert_entity(&parsed).unwrap();
        assert_eq!(inserted_id, -29);

        let loaded = repo.find_by_id(-29).unwrap().unwrap();
        assert_eq!(loaded.name, "阿里云语音");
        assert_eq!(loaded.content_type.as_deref(), Some("audio/mpeg"));
        assert_eq!(loaded.pause_duration, 150);
        assert_eq!(loaded.concurrent_rate.as_deref(), Some("1500"));
        assert_eq!(loaded.login_url.as_deref(), Some("function login(){}"));
        assert_eq!(
            loaded.login_ui.as_deref(),
            Some(r#"[{"name":"AppKey","type":"text"}]"#)
        );
        assert_eq!(loaded.header.as_deref(), Some(r#"{"X-Token":"abc"}"#));
        assert_eq!(loaded.js_lib.as_deref(), Some("var v = 1;"));
        assert_eq!(loaded.enabled_cookie_jar, Some(true));
        assert_eq!(loaded.login_check_js.as_deref(), Some("result"));
        assert_eq!(loaded.speed, Some(12));
        assert_eq!(loaded.synthesis_thread_count, 8);
        assert_eq!(loaded.last_update_time, 1700000000000);
        assert!(!loaded.is_enabled);

        // 原地更新保留 ID，失败不修改原记录
        let mut modified = loaded.clone();
        modified.name = "阿里云语音-改".to_string();
        modified.speed = Some(20);
        modified.synthesis_thread_count = 4;
        assert!(repo.update_entity(&modified).unwrap());

        let after_update = repo.find_by_id(-29).unwrap().unwrap();
        assert_eq!(after_update.id, -29);
        assert_eq!(after_update.name, "阿里云语音-改");
        assert_eq!(after_update.speed, Some(20));
        assert_eq!(after_update.synthesis_thread_count, 4);
        assert_eq!(after_update.header.as_deref(), Some(r#"{"X-Token":"abc"}"#));

        let mut missing = after_update.clone();
        missing.id = 999999;
        assert!(!repo.update_entity(&missing).unwrap());
    }
}
