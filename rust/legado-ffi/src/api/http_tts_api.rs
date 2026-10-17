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
    let value: serde_json::Value = serde_json::from_str(http_tts_json)?;
    add_http_tts_entity(
        serde_json::from_value(value.clone())?,
        legado_core::tts_catalog::parse(&value),
    )
}

/// 实体与文档导入共用事务、目录同步及限流刷新。
pub fn add_http_tts_entity(
    tts: HttpTts,
    catalog: legado_core::tts_catalog::CatalogDraft,
) -> LegadoResult<i64> {
    let id = with_database(|db| {
        let tx = db
            .connection()
            .unchecked_transaction()
            .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
        let id = HttpTtsRepository::new(&tx).insert_entity(&tts)?;
        legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(&tx)
            .sync_http(id, &catalog, tts.last_update_time)?;
        tx.commit()
            .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
        Ok(id)
    })?;
    super::source_rate_limit::registry().refresh(
        &format!("httpTts:{id}"),
        tts.concurrent_rate.as_deref().unwrap_or(""),
    );
    Ok(id)
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
    let value: serde_json::Value = serde_json::from_str(http_tts_json)?;
    update_http_tts_entity(
        serde_json::from_value(value.clone())?,
        legado_core::tts_catalog::parse(&value),
    )
}

/// 实体与文档导入共用事务、目录同步及限流刷新。
pub fn update_http_tts_entity(
    tts: HttpTts,
    catalog: legado_core::tts_catalog::CatalogDraft,
) -> LegadoResult<bool> {
    let updated = with_database(|db| {
        let tx = db
            .connection()
            .unchecked_transaction()
            .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
        let updated = HttpTtsRepository::new(&tx).update_entity(&tts)?;
        if updated {
            legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(&tx)
                .sync_http(tts.id, &catalog, tts.last_update_time)?;
        }
        tx.commit()
            .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
        Ok(updated)
    })?;
    if updated {
        super::source_rate_limit::registry().refresh(
            &format!("httpTts:{}", tts.id),
            tts.concurrent_rate.as_deref().unwrap_or(""),
        );
    }
    Ok(updated)
}

/// 导入仍是 JSON 文档边界，逐项写入，不丢失内嵌目录。
pub fn import_http_tts_json(raw: &str) -> LegadoResult<i32> {
    let items: Vec<serde_json::Value> = serde_json::from_str(raw)?;
    let mut count = 0;
    for item in items {
        let tts: HttpTts = serde_json::from_value(item.clone())?;
        if tts.name.is_empty() || tts.url.is_empty() {
            continue;
        }
        add_http_tts_entity(tts, legado_core::tts_catalog::parse(&item))?;
        count += 1;
    }
    Ok(count)
}

/// 删除 HTTP TTS 源
pub fn delete_http_tts(id: i64) -> LegadoResult<bool> {
    let deleted = with_database(|db| {
        let tx = db
            .connection()
            .unchecked_transaction()
            .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
        let deleted = HttpTtsRepository::new(&tx).delete(id)?;
        legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(&tx)
            .clear_http(id)?;
        tx.commit()
            .map_err(|e| legado_core::LegadoError::Database(e.to_string()))?;
        Ok(deleted)
    })?;
    if deleted {
        super::source_rate_limit::registry().remove(&format!("httpTts:{id}"));
    }
    Ok(deleted)
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

        let id = crate::ffi::ffi::http_tts_add(
            serde_json::from_str::<HttpTts>(input_json).unwrap().into(),
        )
        .unwrap();
        assert_eq!(id, -1029);

        let list: Vec<serde_json::Value> = crate::ffi::ffi::http_tts_list()
            .unwrap()
            .into_iter()
            .map(|item| serde_json::to_value(HttpTts::from(item)).unwrap())
            .collect();
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
        let ok = crate::ffi::ffi::http_tts_update(updated.clone().into()).unwrap();
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
        let missing_ok = crate::ffi::ffi::http_tts_update(missing.into()).unwrap();
        assert!(!missing_ok);

        // 非法 JSON 抛错
        assert!(crate::ffi::ffi::http_tts_import("{".to_string()).is_err());
        assert!(crate::ffi::ffi::http_tts_import("[null]".to_string()).is_err());

        assert!(delete_http_tts(-1029).unwrap());
    }
    #[test]
    fn catalog_import_preserves_flags_and_delete_cleans_only_engine() {
        let _guard = crate::db_state::ensure_test_db();
        let raw=serde_json::json!({"id":-98124,"name":"目录源","url":"https://tts","speakersJson":r#"[{"speakerName":"中文","toneID":"zh-a"}]"#, "emotionsJson":r#"[{"emotionName":"高兴","emotionTag":"happy"}]"#}).to_string();
        add_http_tts_json(&raw).unwrap();
        let id =
            legado_db::repository::read_aloud_voice_repository::stable_id("http", "-98124", "zh-a");
        super::super::read_aloud_voice_api::set_flags(&id, false, true).unwrap();
        add_http_tts_json(&raw).unwrap();
        update_http_tts_json(r#"{"id":-98124,"name":"改名","url":"https://new"}"#).unwrap();
        let rows: Vec<legado_db::repository::read_aloud_voice_repository::ReadAloudVoice> =
            super::super::read_aloud_voice_api::list().unwrap();
        let voice = rows.iter().find(|v| v.id == id).unwrap();
        assert!(!voice.enabled);
        assert!(voice.excluded);
        assert!(voice.emotion_catalog_json.contains("happy"));
        delete_http_tts(-98124).unwrap();
        let rows = super::super::read_aloud_voice_api::list().unwrap();
        assert!(rows.iter().all(|v| v.id != id));
    }
    #[test]
    fn document_import_skips_empty_and_keeps_committed_items_on_later_error() {
        let _guard = crate::db_state::ensure_test_db();
        let raw = r#"[{"name":"","url":"https://unused"},{"id":-98126,"name":"已提交","url":"https://tts","loginUi":[{"name":"密钥"}],"speakersJson":"[{\"speakerName\":\"中文\",\"toneID\":\"zh\"}]"},null,{"id":-98127,"name":"不应执行","url":"https://tts"}]"#;
        assert!(crate::ffi::ffi::http_tts_import(raw.to_owned()).is_err());
        let rows = get_http_tts_list().unwrap();
        let saved = rows.iter().find(|v| v.id == -98126).unwrap();
        assert_eq!(saved.login_ui.as_deref(), Some(r#"[{"name":"密钥"}]"#));
        assert!(!rows.iter().any(|v| v.id == -98127));
        let voices = super::super::read_aloud_voice_api::list().unwrap();
        assert!(
            voices
                .iter()
                .any(|v| v.engine_id == "-98126" && v.speaker_id == "zh")
        );
        assert_eq!(
            crate::ffi::ffi::http_tts_import(
                r#"[{"name":"","url":"https://unused"},{"name":"没有地址"}]"#.to_owned()
            )
            .unwrap(),
            0
        );
        delete_http_tts(-98126).unwrap();
    }

    #[test]
    fn catalog_save_failure_rolls_back_source() {
        let _guard = crate::db_state::ensure_test_db();
        with_database(|db|{db.connection().execute_batch("CREATE TEMP TRIGGER reject_catalog BEFORE INSERT ON read_aloud_voices BEGIN SELECT RAISE(ABORT,'catalog fixture'); END;").map_err(|e|legado_core::LegadoError::Database(e.to_string()))?;
            // 同一连接直接使用事务，FFI closure 换池连接不能共享 TEMP trigger。
            let tx=db.connection().unchecked_transaction().unwrap();
            let tts=HttpTts{id:-98125,name:"不应残留".into(),url:"https://tts".into(),..Default::default()};
            HttpTtsRepository::new(&tx).insert_entity(&tts).unwrap();
            let draft=legado_core::tts_catalog::parse(&serde_json::json!({"speakersJson":r#"[{"name":"甲","toneID":"a"}]"#}));
            assert!(legado_db::repository::read_aloud_voice_repository::ReadAloudVoiceRepository::new(&tx).sync_http(-98125,&draft,0).is_err());
            drop(tx);
            assert!(HttpTtsRepository::new(db.connection()).find_all()?.iter().all(|v|v.id!= -98125));
            db.connection().execute_batch("DROP TRIGGER reject_catalog").unwrap();Ok(())}).unwrap();
    }
}
