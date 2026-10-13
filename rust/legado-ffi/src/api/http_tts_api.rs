//! HTTP TTS 朗读源管理 API
//!
//! 提供 HTTP TTS 源的增删改查操作，通过 HttpTtsRepository 访问数据库。
//! 批次 T1：统一使用全字段 camelCase `legado_db::HttpTts` 模型。

use legado_core::LegadoResult;
use legado_db::{HttpTts, HttpTtsRepository};

use crate::db_state::with_database;

/// HTTP TTS 源 DTO（全字段 camelCase，直接对齐 `legado_db::HttpTts`）
pub type HttpTtsDto = HttpTts;

/// 获取所有 HTTP TTS 源
pub fn get_http_tts_list() -> LegadoResult<Vec<HttpTtsDto>> {
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.find_all()
    })
}

/// 添加 HTTP TTS 源（仅传名称与 URL），返回新 ID
pub fn add_http_tts(name: &str, url: &str) -> LegadoResult<i64> {
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.insert(name, url)
    })
}

/// 添加或覆盖完整 HTTP TTS 源 JSON，返回最终 ID
pub fn add_http_tts_json(http_tts_json: &str) -> LegadoResult<i64> {
    let tts: HttpTts = serde_json::from_str(http_tts_json)?;
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.insert_entity(&tts)
    })
}

/// 更新 HTTP TTS 源（仅更新名称与 URL）
pub fn update_http_tts(id: i64, name: &str, url: &str) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.update(id, name, url)
    })
}

/// 按 ID 原地更新完整 HTTP TTS 源 JSON
pub fn update_http_tts_json(http_tts_json: &str) -> LegadoResult<bool> {
    let tts: HttpTts = serde_json::from_str(http_tts_json)?;
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.update_entity(&tts)
    })
}

/// 删除 HTTP TTS 源
pub fn delete_http_tts(id: i64) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.delete(id)
    })
}

/// 设置 HTTP TTS 源启用/禁用
pub fn set_http_tts_enabled(id: i64, enabled: bool) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = HttpTtsRepository::new(db.connection());
        repo.set_enabled(id, enabled)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_http_tts_crud() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 添加
        let id = add_http_tts("测试TTS", "http://tts.example.com/speak").unwrap();
        assert!(id > 0);

        // 获取列表
        let list = get_http_tts_list().unwrap();
        assert!(list.iter().any(|t| t.name == "测试TTS"));

        // 更新
        assert!(update_http_tts(id, "新TTS", "http://new.tts.com").unwrap());
        let list = get_http_tts_list().unwrap();
        let tts = list.iter().find(|t| t.id == id).unwrap();
        assert_eq!(tts.name, "新TTS");

        // 禁用
        assert!(set_http_tts_enabled(id, false).unwrap());
        let list = get_http_tts_list().unwrap();
        let tts = list.iter().find(|t| t.id == id).unwrap();
        assert!(!tts.is_enabled);

        // 删除
        assert!(delete_http_tts(id).unwrap());
        let list = get_http_tts_list().unwrap();
        assert!(!list.iter().any(|t| t.id == id));
    }

    #[test]
    fn test_http_tts_full_json_crud_and_array_login_ui() {
        let _db_guard = crate::db_state::ensure_test_db();

        let input_json = r#"{
            "id": -1029,
            "name": "测试全字段引擎",
            "url": "https://tts.example.com/stream,{\"method\":\"POST\"}",
            "contentType": "audio/mpeg",
            "pauseDuration": 200,
            "concurrentRate": "1500",
            "loginUrl": "function login(){}",
            "loginUi": [{"name": "AppKey", "type": "text"}],
            "header": "{\"Authorization\":\"Bearer token\"}",
            "jsLib": "var x = 1;",
            "enabledCookieJar": true,
            "loginCheckJs": "result",
            "speed": 15,
            "synthesisThreadCount": 12,
            "lastUpdateTime": 1700000001234,
            "isEnabled": false
        }"#;

        let id = crate::ffi::ffi::http_tts_add(input_json.to_string()).unwrap();
        assert_eq!(id, -1029);

        let list_json = crate::ffi::ffi::http_tts_list().unwrap();
        let list: Vec<serde_json::Value> = serde_json::from_str(&list_json).unwrap();
        let item = list
            .iter()
            .find(|v| v.get("id").and_then(|i| i.as_i64()) == Some(-1029))
            .expect("应能查到新插入的完整引擎");

        assert_eq!(item["name"], "测试全字段引擎");
        assert_eq!(item["contentType"], "audio/mpeg");
        assert_eq!(item["pauseDuration"], 200);
        assert_eq!(item["concurrentRate"], "1500");
        assert_eq!(item["loginUrl"], "function login(){}");
        assert_eq!(item["loginUi"], r#"[{"name":"AppKey","type":"text"}]"#);
        assert_eq!(item["header"], r#"{"Authorization":"Bearer token"}"#);
        assert_eq!(item["jsLib"], "var x = 1;");
        assert_eq!(item["enabledCookieJar"], true);
        assert_eq!(item["loginCheckJs"], "result");
        assert_eq!(item["speed"], 15);
        assert_eq!(item["synthesisThreadCount"], 8);
        assert_eq!(item["lastUpdateTime"], 1700000001234_i64);
        assert_eq!(item["isEnabled"], false);

        // 原地更新
        let mut updated: HttpTts = serde_json::from_value(item.clone()).unwrap();
        updated.name = "测试全字段引擎-已改".to_string();
        updated.speed = Some(25);
        updated.synthesis_thread_count = 3;
        let ok =
            crate::ffi::ffi::http_tts_update(serde_json::to_string(&updated).unwrap()).unwrap();
        assert!(ok);

        let after_list = get_http_tts_list().unwrap();
        let after = after_list.iter().find(|t| t.id == -1029).unwrap();
        assert_eq!(after.name, "测试全字段引擎-已改");
        assert_eq!(after.speed, Some(25));
        assert_eq!(after.synthesis_thread_count, 3);
        assert_eq!(
            after.header.as_deref(),
            Some(r#"{"Authorization":"Bearer token"}"#)
        );

        // 更新不存在 ID 返回 false，且不改变已有记录
        let mut missing = updated.clone();
        missing.id = -999999;
        let missing_ok =
            crate::ffi::ffi::http_tts_update(serde_json::to_string(&missing).unwrap()).unwrap();
        assert!(!missing_ok);

        // 非法 JSON 抛错
        assert!(crate::ffi::ffi::http_tts_add("{".to_string()).is_err());
        assert!(crate::ffi::ffi::http_tts_update("{".to_string()).is_err());

        assert!(delete_http_tts(-1029).unwrap());
    }
}
