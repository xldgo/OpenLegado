//! 词典宿主适配：能力捕获与传输映射，业务归Engine服务。
use legado_core::{LegadoError, LegadoResult};
use legado_db::DictRule;
pub use legado_engine::dictionary_service::DictEntry;
use legado_engine::dictionary_service::{DictionaryResources, DictionaryService};
use serde::Serialize;
fn host_service() -> DictionaryService {
    let engine = crate::engine_holder::current().ok();
    DictionaryService::new(DictionaryResources {
        storage: engine.as_ref().map(|e| e.storage().clone()),
        network: engine
            .as_ref()
            .map(|e| e.network().clone())
            .unwrap_or_else(crate::engine_holder::network),
        js: engine
            .as_ref()
            .map(|e| e.js_resources().clone())
            .unwrap_or_else(crate::engine_holder::js_resources),
        runtime: crate::runtime::get_runtime().handle().clone(),
    })
}
/// 字典规则 DTO（序列化字段对齐契约 §2.45：camelCase）
#[derive(Debug, Clone, Serialize)]
pub struct DictRuleDto {
    pub id: i64,
    pub name: String,
    #[serde(rename = "urlRule")]
    pub url_rule: String,
    #[serde(rename = "showRule")]
    pub show_rule: String,
    pub enabled: bool,
    #[serde(rename = "sortNumber")]
    pub sort_number: i32,
}

impl From<&DictRule> for DictRuleDto {
    fn from(r: &DictRule) -> Self {
        Self {
            id: r.id,
            name: r.name.clone(),
            url_rule: r.url_rule.clone(),
            show_rule: r.show_rule.clone(),
            enabled: r.is_enabled,
            sort_number: r.sort_order,
        }
    }
}

pub fn dict_lookup(word: &str) -> LegadoResult<DictEntry> {
    host_service().dict_lookup(word)
}
pub fn dict_rule_add(name: &str, url_rule: &str, show_rule: &str) -> LegadoResult<i64> {
    host_service().dict_rule_add(name, url_rule, show_rule)
}
pub fn dict_rule_update(
    id: i64,
    name: &str,
    url_rule: &str,
    show_rule: &str,
) -> LegadoResult<bool> {
    host_service().dict_rule_update(id, name, url_rule, show_rule)
}
pub fn dict_rule_delete(id: i64) -> LegadoResult<bool> {
    host_service().dict_rule_delete(id)
}
pub fn dict_rule_set_enabled(id: i64, enabled: bool) -> LegadoResult<bool> {
    host_service().dict_rule_set_enabled(id, enabled)
}
pub fn reorder_dict_rules(ids: &[i64]) -> LegadoResult<i32> {
    host_service().reorder_dict_rules(ids)
}
pub fn dict_rule_import(json_or_url: &str, kind: &str) -> LegadoResult<i32> {
    host_service().dict_rule_import(json_or_url, kind)
}
pub fn dict_rule_list() -> LegadoResult<Vec<DictRuleDto>> {
    Ok(host_service()
        .dict_rule_list()?
        .iter()
        .map(Into::into)
        .collect())
}
pub fn dict_rule_reorder(ids_json: &str) -> LegadoResult<i32> {
    let ids: Vec<i64> = serde_json::from_str(ids_json)
        .map_err(|e| LegadoError::Database(format!("解析 reorder IDs 失败: {e}")))?;
    reorder_dict_rules(&ids)
}

#[cfg(test)]
use crate::db_state::with_database;
#[cfg(test)]
use legado_db::DictRuleRepository;
#[cfg(test)]
mod tests {
    use super::*;

    /// 清空 dict_rules 表（测试隔离；持 ensure_test_db 串行锁调用）
    fn clear_dict_rules() {
        with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.delete_all()
        })
        .unwrap();
    }

    /// 插入测试规则（启用）
    fn insert_rule(name: &str, url_rule: &str, show_rule: &str) -> i64 {
        with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.insert_record(&DictRule {
                id: 0,
                name: name.to_string(),
                url_rule: url_rule.to_string(),
                show_rule: show_rule.to_string(),
                is_enabled: true,
                sort_order: 100, // 避开默认 5 源的 0..4 排序区间
            })
        })
        .unwrap()
    }

    /// 规则查询路径：data: URI urlRule（免网络）+ 空 showRule 直返 body

    #[test]
    fn test_lookup_data_uri_rule() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();
        insert_rule(
            "本地测试",
            "data:text/plain;charset=utf-8,hello-{{key}}",
            "",
        );

        let entry = dict_lookup("  world  ").unwrap();
        assert_eq!(entry.word, "world"); // 仅 trim，不再小写
        assert!(entry.phonetic.is_empty());
        assert_eq!(entry.definitions.len(), 1);
        assert_eq!(entry.definitions[0], "【本地测试】hello-world");

        clear_dict_rules();
    }

    /// showRule CSS 选择器路径（data: URI HTML + 选择器提取）
    #[test]
    fn test_lookup_show_rule_css() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();
        insert_rule(
            "CSS测试",
            "data:text/html;charset=utf-8,<html><body><p id='def'>n. 测试释义</p></body></html>",
            "#def",
        );

        let entry = dict_lookup("word").unwrap();
        assert_eq!(entry.definitions.len(), 1);
        assert!(entry.definitions[0].contains("n. 测试释义"));

        clear_dict_rules();
    }

    /// 失败规则跳过：不可达规则不影响其余规则的结果
    #[test]
    fn test_lookup_failed_rule_skipped() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();
        insert_rule("不可达", "http://127.0.0.1:1/dict?q={{key}}", "");
        insert_rule("正常", "data:text/plain;charset=utf-8,ok", "");

        let entry = dict_lookup("x").unwrap();
        assert_eq!(entry.definitions.len(), 1);
        assert!(entry.definitions[0].starts_with("【正常】"));

        clear_dict_rules();
    }

    /// 无启用规则：返回空 definitions（非异常）
    #[test]
    fn test_lookup_no_enabled_rules() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();
        with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            let id = repo.insert_record(&DictRule {
                id: 0,
                name: "禁用规则".into(),
                url_rule: "data:text/plain,unused".into(),
                show_rule: "".into(),
                is_enabled: false,
                sort_order: 1,
            })?;
            repo.set_enabled(id, false)
        })
        .unwrap();

        let entry = dict_lookup("anything").unwrap();
        assert!(entry.definitions.is_empty());

        clear_dict_rules();
    }

    /// 表为空时注入原版默认 5 源（对标 DefaultData.importDefaultDictRules）
    #[test]
    fn test_lookup_seeds_defaults_when_empty() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();

        let seeded = with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.seed_default_rules()
        })
        .unwrap();
        assert_eq!(seeded, 5);

        let names = with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            Ok::<Vec<String>, legado_core::LegadoError>(
                repo.find_all()
                    .unwrap()
                    .into_iter()
                    .map(|r| r.name)
                    .collect(),
            )
        })
        .unwrap();
        assert_eq!(
            names,
            vec!["海词中文", "海词英文", "有道", "哔哩", "百度汉语"]
        );

        clear_dict_rules();
    }

    /// `@js:` urlRule + showRule 链路（quickjs 特性下验证 JS 作用域注入）
    #[cfg(feature = "quickjs")]
    #[test]
    fn test_lookup_js_rules() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();
        // urlRule 为纯 @js：返回 data: URI；showRule 为纯 @js：消费 result
        insert_rule(
            "JS测试",
            "@js:'data:text/plain;charset=utf-8,js-' + key",
            "@js:'jsdef:' + result",
        );

        let entry = dict_lookup("abc").unwrap();
        assert_eq!(entry.definitions.len(), 1);
        assert_eq!(entry.definitions[0], "【JS测试】jsdef:js-abc");

        clear_dict_rules();
    }

    /// 序列化字段对齐 Dart DictEntry 模型
    #[test]
    fn test_serialization_fields() {
        let entry = DictEntry {
            word: "book".into(),
            phonetic: "".into(),
            definitions: vec!["【测试】n. 书".into()],
        };
        let json = serde_json::to_value(&entry).unwrap();
        assert!(json.get("word").is_some());
        assert!(json.get("phonetic").is_some());
        assert!(json.get("definitions").is_some());
        assert!(json["definitions"].is_array());
    }

    // ─── CRUD 全流程（经 API 层，DB 隔离）────────────────────────────────

    /// add → list → update → set_enabled → reorder → delete 全链路
    #[test]
    fn test_dict_rule_crud_flow() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();

        // add（enabled=1, sortNumber=0）
        let id = dict_rule_add("自定义源", "http://x.com/{{key}}", "json.data").unwrap();
        assert!(id > 0);

        // list（表非空，不再 seed 默认 5 源）
        let list = dict_rule_list().unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].name, "自定义源");
        assert_eq!(list[0].sort_number, 0);

        // update（改 name/urlRule/showRule）
        assert!(dict_rule_update(id, "自定义源2", "http://y.com/{{key}}", "xpath://x").unwrap());
        let list = dict_rule_list().unwrap();
        assert_eq!(list[0].name, "自定义源2");
        assert_eq!(list[0].url_rule, "http://y.com/{{key}}");

        // set_enabled（禁用）
        assert!(dict_rule_set_enabled(id, false).unwrap());
        let list = dict_rule_list().unwrap();
        assert!(!list[0].enabled);

        // reorder（多规则重编号）
        let id2 = dict_rule_add("源B", "http://b.com", "").unwrap();
        let id3 = dict_rule_add("源C", "http://c.com", "").unwrap();
        // 新顺序：[id3, id, id2]
        let count = dict_rule_reorder(&format!("[{id3},{id},{id2}]")).unwrap();
        assert_eq!(count, 3);
        let list = dict_rule_list().unwrap();
        assert_eq!(list.len(), 3);
        // ORDER BY sortNumber,id → id3(0), id(1), id2(2)
        assert_eq!(list[0].id, id3);
        assert_eq!(list[0].sort_number, 0);
        assert_eq!(list[1].id, id);
        assert_eq!(list[1].sort_number, 1);
        assert_eq!(list[2].id, id2);
        assert_eq!(list[2].sort_number, 2);

        // delete
        assert!(dict_rule_delete(id).unwrap());
        assert!(!dict_rule_delete(999_999).unwrap()); // 不存在 → false
        let list = dict_rule_list().unwrap();
        assert_eq!(list.len(), 2);
        assert!(!list.iter().any(|r| r.id == id));

        clear_dict_rules();
    }

    /// 导入 REPLACE by name：异名插入、同名覆盖（保留 id、条数稳定）
    #[test]
    fn test_dict_rule_import_upsert_by_name() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();

        // 首次导入：数组两条（新名插入）
        let json1 = r#"[{"name":"导入源A","urlRule":"http://a","showRule":"sa"},{"name":"导入源B","urlRule":"http://b","showRule":"sb"}]"#;
        assert_eq!(dict_rule_import(json1, "text").unwrap(), 2);
        let list = dict_rule_list().unwrap();
        let id_a = list.iter().find(|r| r.name == "导入源A").unwrap().id;

        // 二次导入：A 同名覆盖（urlRule 变化，id 保留），B 同名覆盖，加一条新名
        let json2 = r#"[{"name":"导入源A","urlRule":"http://a2","showRule":"sa2"},{"name":"导入源B","urlRule":"http://b2","showRule":"sb2"},{"name":"导入源C","urlRule":"http://c","showRule":"sc"}]"#;
        assert_eq!(dict_rule_import(json2, "text").unwrap(), 3);
        let list = dict_rule_list().unwrap();
        assert_eq!(list.len(), 3);
        let a = list.iter().find(|r| r.name == "导入源A").unwrap();
        assert_eq!(a.id, id_a, "REPLACE by name 应保留原 id");
        assert_eq!(a.url_rule, "http://a2", "同名应覆盖 urlRule");

        // 单对象导入
        assert_eq!(
            dict_rule_import(
                r#"{"name":"导入源D","urlRule":"http://d","showRule":"sd"}"#,
                "text"
            )
            .unwrap(),
            1
        );
        assert_eq!(dict_rule_list().unwrap().len(), 4);

        // 导入失败 → 明确错误（非法 JSON）
        assert!(dict_rule_import("not json", "text").is_err());

        clear_dict_rules();
    }

    /// reorder 非法 JSON → 明确错误
    #[test]
    fn test_dict_rule_reorder_bad_json() {
        let _db_guard = crate::db_state::ensure_test_db();
        clear_dict_rules();
        assert!(dict_rule_reorder("not a json array").is_err());
        assert!(dict_rule_reorder(r#"{"a":1}"#).is_err());
        clear_dict_rules();
    }
}
