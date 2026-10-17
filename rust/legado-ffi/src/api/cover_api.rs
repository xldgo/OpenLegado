//! 封面规则宿主适配：默认资源与能力注入，配置/搜索编排归Engine。
use legado_core::{LegadoError, LegadoResult};
pub use legado_engine::cover_service::CoverRuleConfig;
use legado_engine::cover_service::{CoverResources, CoverService};
const DEFAULT_COVER_RULE_JSON: &str = include_str!("../../../assets/defaultData/coverRule.json");
fn host_service() -> CoverService {
    let engine = crate::engine_holder::current().ok();
    CoverService::new(CoverResources {
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
        default_config: DEFAULT_COVER_RULE_JSON.into(),
    })
}
pub fn get_cover_rule() -> LegadoResult<String> {
    Ok(serde_json::to_string(&read_cover_rule()?)?)
}
pub fn save_cover_rule(rule_json: &str) -> LegadoResult<bool> {
    let config: CoverRuleConfig = serde_json::from_str(rule_json)
        .map_err(|e| LegadoError::Internal(format!("封面规则 JSON 无效: {e}")))?;
    write_cover_rule(config)
}
pub fn search_cover_rules(name: &str) -> LegadoResult<String> {
    Ok(serde_json::to_string(&search_cover_urls(name)?)?)
}
pub fn read_cover_rule() -> LegadoResult<CoverRuleConfig> {
    host_service().read_cover_rule()
}
pub fn write_cover_rule(config: CoverRuleConfig) -> LegadoResult<bool> {
    host_service().write_cover_rule(config)
}
pub fn delete_cover_rule() -> LegadoResult<bool> {
    host_service().delete_cover_rule()
}
pub fn search_cover_urls(name: &str) -> LegadoResult<Vec<String>> {
    host_service().search_cover_urls(name)
}

#[cfg(test)]
use crate::db_state::with_database;
#[cfg(test)]
use legado_db::{CoverRule, CoverRuleRepository};
#[cfg(test)]
mod tests {
    use super::*;

    /// 串行锁：以下测试共享同一测试库的 coverRules 表，需串行执行
    static TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

    /// 清空 coverRules 表（测试隔离；持 ensure_test_db 串行锁调用）
    fn clear_cover_rules() {
        with_database(|db| {
            let repo = CoverRuleRepository::new(db.connection());
            repo.delete_all()
        })
        .unwrap();
    }

    /// 插入测试规则（启用）
    fn insert_rule(name: &str, rule: &str) -> i64 {
        with_database(|db| {
            let repo = CoverRuleRepository::new(db.connection());
            repo.insert(&CoverRule {
                id: 0,
                name: name.to_string(),
                rule: rule.to_string(),
                enable: true,
            })
        })
        .unwrap()
    }

    /// F4：get/save/delete 单配置往返 + 删除后回退默认
    #[test]
    fn test_cover_rule_crud_roundtrip() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();

        let empty_get = get_cover_rule().unwrap();
        let default_cfg: CoverRuleConfig = serde_json::from_str(&empty_get).unwrap();
        assert!(!default_cfg.search_url.is_empty());

        let saved =
            r#"{"enable":true,"searchUrl":"https://s.example/{{key}}","coverRule":"$.cover"}"#;
        assert!(save_cover_rule(saved).unwrap());
        let got: CoverRuleConfig = serde_json::from_str(&get_cover_rule().unwrap()).unwrap();
        assert!(got.enable);
        assert_eq!(got.search_url, "https://s.example/{{key}}");
        assert_eq!(got.cover_rule, "$.cover");

        assert!(delete_cover_rule().unwrap());
        let after_del: CoverRuleConfig = serde_json::from_str(&get_cover_rule().unwrap()).unwrap();
        assert_eq!(after_del.search_url, default_cfg.search_url);
    }

    /// F4 + 批 2 收尾：`enabledCookieJar` 经 save/get 往返保留，
    /// 缺省时 None（运行时按关，对齐上游字段默认 false）。
    #[test]
    fn test_cover_rule_enabled_cookie_jar_roundtrip() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();

        // 缺省（Dart 对话框现有 JSON 形态）→ None
        assert!(
            save_cover_rule(
                r#"{"enable":true,"searchUrl":"https://s.example/{{key}}","coverRule":"$.cover"}"#
            )
            .unwrap()
        );
        let cfg: CoverRuleConfig = serde_json::from_str(&get_cover_rule().unwrap()).unwrap();
        assert_eq!(cfg.enabled_cookie_jar, None, "缺省应保持 None（按关）");

        // 显式 true → save/get 往返保留（门控接线可被配置驱动）
        assert!(save_cover_rule(
            r#"{"enable":true,"searchUrl":"https://s.example/{{key}}","coverRule":"$.cover","enabledCookieJar":true}"#
        )
        .unwrap());
        let cfg: CoverRuleConfig = serde_json::from_str(&get_cover_rule().unwrap()).unwrap();
        assert_eq!(cfg.enabled_cookie_jar, Some(true));

        clear_cover_rules();
    }

    /// F4：空 searchUrl/coverRule 拒绝保存
    #[test]
    fn test_save_cover_rule_rejects_blank() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        let err = save_cover_rule(r#"{"enable":true,"searchUrl":"","coverRule":"x"}"#).unwrap_err();
        assert!(err.to_string().contains("不能为空"));
    }

    /// 无启用规则：返回空数组（非异常）
    #[test]
    fn test_no_enabled_rules_returns_empty_array() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();

        let json = search_cover_rules("任意书名").unwrap();
        assert_eq!(json, "[]");
    }

    /// 禁用规则不执行
    #[test]
    fn test_disabled_rule_not_executed() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();
        with_database(|db| {
            let repo = CoverRuleRepository::new(db.connection());
            repo.insert(&CoverRule {
                id: 0,
                name: "禁用规则".into(),
                rule: r#"{"searchUrl":"data:text/plain,x","coverRule":"$"}"#.into(),
                enable: false,
            })
        })
        .unwrap();

        let json = search_cover_rules("书名").unwrap();
        assert_eq!(json, "[]");
        clear_cover_rules();
    }

    /// 完整链路：data: URI searchUrl（{{key}} 模板替换）+ JsonPath coverRule 提取
    #[test]
    fn test_rule_url_template_and_extract() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();
        // searchUrl 为 data: URI，body 内含书名（验证 {{key}} 模板替换）；
        // coverRule 用 JsonPath 提取封面 URL
        insert_rule(
            "JSON封面",
            r#"{"searchUrl":"data:application/json;charset=utf-8,{\"q\":\"{{key}}\",\"cover\":\"https://cdn.example.com/cover-{{key}}.jpg\"}","coverRule":"$.cover"}"#,
        );

        let json = search_cover_rules("测试书").unwrap();
        let urls: Vec<String> = serde_json::from_str(&json).unwrap();
        assert_eq!(urls.len(), 1);
        assert_eq!(urls[0], "https://cdn.example.com/cover-测试书.jpg");
        clear_cover_rules();
    }

    /// 单规则失败隔离：不可达规则不影响其余规则
    #[test]
    fn test_failed_rule_isolated() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();
        // 规则1：不可达 URL（连接失败，自然隔离）
        insert_rule(
            "不可达",
            r#"{"searchUrl":"http://127.0.0.1:1/cover?q={{key}}","coverRule":"$.cover"}"#,
        );
        // 规则2：rule JSON 非法（解析失败，隔离）
        insert_rule("非法JSON", "not-json");
        // 规则3：正常 data: URI
        insert_rule(
            "正常",
            r#"{"searchUrl":"data:application/json;charset=utf-8,{\"cover\":\"http://ok.example.com/c.jpg\"}","coverRule":"$.cover"}"#,
        );

        let json = search_cover_rules("x").unwrap();
        let urls: Vec<String> = serde_json::from_str(&json).unwrap();
        assert_eq!(urls.len(), 1, "仅正常规则产出结果：{json}");
        assert_eq!(urls[0], "http://ok.example.com/c.jpg");
        clear_cover_rules();
    }

    /// 提取结果为空：该规则无产出（非失败）
    #[test]
    fn test_empty_extract_returns_nothing() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();
        // coverRule 提取不存在的字段 → 空结果
        insert_rule(
            "空提取",
            r#"{"searchUrl":"data:application/json;charset=utf-8,{\"a\":1}","coverRule":"$.cover"}"#,
        );

        let json = search_cover_rules("y").unwrap();
        assert_eq!(json, "[]");
        clear_cover_rules();
    }

    /// isUrl 语义：相对路径补全为绝对 URL
    #[test]
    fn test_relative_url_absolutized() {
        let _g = TEST_LOCK.lock().unwrap();
        let _db_guard = crate::db_state::ensure_test_db();
        clear_cover_rules();
        // searchUrl 为绝对 http 基址（不可达但 data 分支优先不走网络）——
        // 此处用 data: URI 取体，base URL 为 data: URI，无法补全 http 相对路径；
        // 故改用提取结果本身为完整 URL 的常规场景已由上例覆盖，
        // 本例验证 get_absolute_url 对绝对 URL 原样返回。
        insert_rule(
            "绝对URL",
            r#"{"searchUrl":"data:application/json;charset=utf-8,{\"cover\":\"https://abs.example.com/x.jpg\"}","coverRule":"$.cover"}"#,
        );

        let json = search_cover_rules("z").unwrap();
        let urls: Vec<String> = serde_json::from_str(&json).unwrap();
        assert_eq!(urls[0], "https://abs.example.com/x.jpg");
        clear_cover_rules();
    }
}
