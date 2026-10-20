//! 封面规则服务：配置与串行查询，默认文档由宿主注入。
use crate::{NetworkContext, StorageContext};
use legado_core::{LegadoError, LegadoResult};
use legado_db::{CoverRule, CoverRuleRepository};
use legado_parser::{AnalyzeRule, AnalyzeUrl};
use serde::{Deserialize, Serialize};
use std::{sync::Arc, time::Duration};
const PRIMARY_COVER_RULE_NAME: &str = "legadoCoverRule";
const COVER_RULE_TIMEOUT_SECS: u64 = 15;

/// coverRules 表 rule 字段 / FFI 配置 JSON（对齐原版 `BookCover.CoverRule`）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CoverRuleConfig {
    #[serde(default = "default_true")]
    pub enable: bool,
    /// 搜索 URL 模板（支持 `{{key}}` 等模板，key=书名）
    #[serde(default)]
    pub search_url: String,
    /// 封面提取规则（AnalyzeRule getString isUrl=true 语义）
    #[serde(default)]
    pub cover_rule: String,
    /// 响应 Set-Cookie 写回开关（对齐上游 `BookCover.CoverRule.enabledCookieJar`）
    ///
    /// 上游 `BookCover.searchCover` 以 CoverRule 自身作 `AnalyzeUrl(source=…)`，
    /// 按 `source?.enabledCookieJar == true` 决定是否下发写侧标记头；上游字段
    /// 默认 false（官方对话框亦不暴露设置），故缺省/显式 null 均按关处理
    /// （`None` → 不补标记），与既有行为一致。
    #[serde(
        default,
        rename = "enabledCookieJar",
        skip_serializing_if = "Option::is_none"
    )]
    pub enabled_cookie_jar: Option<bool>,
}

fn default_true() -> bool {
    true
}

pub struct CoverResources {
    pub storage: Option<StorageContext>,
    pub network: Arc<NetworkContext>,
    pub js: Arc<legado_js::JsResources>,
    pub runtime: tokio::runtime::Handle,
    pub default_config: Arc<str>,
}
pub struct CoverService {
    resources: CoverResources,
}
impl CoverService {
    pub fn new(resources: CoverResources) -> Self {
        Self { resources }
    }
    fn with_database<T>(
        &self,
        f: impl FnOnce(&legado_db::Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        self.resources
            .storage
            .as_ref()
            .ok_or_else(|| LegadoError::Database("数据库尚未初始化，请先调用 db_open".into()))?
            .with_database(f)
    }
    fn default_cover_rule_config(&self) -> LegadoResult<CoverRuleConfig> {
        serde_json::from_str(&self.resources.default_config)
            .map_err(|e| LegadoError::Internal(format!("解析默认封面规则失败: {e}")))
    }
    pub fn read_cover_rule(&self) -> LegadoResult<CoverRuleConfig> {
        let config = if self.resources.storage.is_some() {
            let rows = self.with_database(|db| {
                let repo = CoverRuleRepository::new(db.connection());
                repo.find_all()
            })?;
            if let Some(row) = rows
                .iter()
                .find(|r| r.name == PRIMARY_COVER_RULE_NAME)
                .or_else(|| rows.first())
            {
                match serde_json::from_str::<CoverRuleConfig>(&row.rule) {
                    Ok(mut c) => {
                        c.enable = row.enable;
                        c
                    }
                    Err(_) => {
                        // rule 非 JSON 对象时：把整段当 coverRule，searchUrl 空
                        CoverRuleConfig {
                            enable: row.enable,
                            search_url: String::new(),
                            cover_rule: row.rule.clone(),
                            // 非 JSON 配置无开关字段 → 按关（上游默认 false 同口径）
                            enabled_cookie_jar: None,
                        }
                    }
                }
            } else {
                self.default_cover_rule_config()?
            }
        } else {
            self.default_cover_rule_config()?
        };
        Ok(config)
    }
    pub fn write_cover_rule(&self, config: CoverRuleConfig) -> LegadoResult<bool> {
        if config.search_url.trim().is_empty() || config.cover_rule.trim().is_empty() {
            return Err(LegadoError::Internal("搜索url和cover规则不能为空".into()));
        }
        if self.resources.storage.is_none() {
            return Err(LegadoError::Internal("数据库未初始化".into()));
        }
        let mut inner = serde_json::json!({
            "searchUrl": config.search_url,
            "coverRule": config.cover_rule,
        });
        // 保留显式 enabledCookieJar（对齐上游整对象保存；缺省不写键，运行时按关）
        if let Some(enabled) = config.enabled_cookie_jar {
            inner["enabledCookieJar"] = serde_json::json!(enabled);
        }
        self.with_database(|db| {
            let repo = CoverRuleRepository::new(db.connection());
            // 单配置语义：清空后写入主配置行（与 Dialog 一致）
            repo.delete_all()?;
            repo.insert(&CoverRule {
                id: 0,
                name: PRIMARY_COVER_RULE_NAME.into(),
                rule: inner.to_string(),
                enable: config.enable,
            })?;
            Ok(())
        })?;
        Ok(true)
    }
    pub fn delete_cover_rule(&self) -> LegadoResult<bool> {
        if self.resources.storage.is_none() {
            return Ok(true);
        }
        self.with_database(|db| {
            let repo = CoverRuleRepository::new(db.connection());
            repo.delete_all()
        })?;
        Ok(true)
    }
    pub fn search_cover_urls(&self, name: &str) -> LegadoResult<Vec<String>> {
        let key = name.trim().to_string();

        if self.resources.storage.is_none() {
            // 数据库未初始化：返回空数组（沿用 dictLookup「非异常」语义）
            return Ok(vec![]);
        }

        // 规则数据读取失败 → 向上抛出（契约错误码 Internal）
        let rules = self.with_database(|db| {
            let repo = CoverRuleRepository::new(db.connection());
            repo.find_enabled()
        })?;

        // 逐条执行（串行，规模小）；单规则失败隔离
        let mut urls: Vec<String> = Vec::new();
        for rule in &rules {
            match self.search_one_cover_rule(rule, &key) {
                Ok(Some(url)) => urls.push(url),
                Ok(None) => {}
                Err(e) => {
                    log::warn!(
                        "封面规则 [{}] 搜索「{}」失败（已跳过）: {}",
                        rule.name,
                        key,
                        e
                    );
                }
            }
        }

        Ok(urls)
    }
    fn search_one_cover_rule(&self, rule: &CoverRule, key: &str) -> Result<Option<String>, String> {
        // 1. rule JSON 解析（searchUrl + coverRule）
        let config: CoverRuleConfig =
            serde_json::from_str(&rule.rule).map_err(|e| format!("rule JSON 解析失败: {e}"))?;
        let search_url = config.search_url.trim();
        let cover_rule = config.cover_rule.trim();
        if search_url.is_empty() || cover_rule.is_empty() {
            return Err("searchUrl/coverRule 为空".to_string());
        }

        // 2. searchUrl 模板渲染（复用 build_search_url：{{key}}/{{JS}}/searchKey）
        let analyze_url = legado_fetcher::js_adapter::build_search_url_with_setup(
            &self.resources.js.for_source("source", search_url, ""),
            search_url,
            key,
            1,
            search_url,
            None,
            None,
        );

        // 3. 取响应 body（复用引擎共享取体链路，含 data: URI / 超时保护）；
        // 写侧 CookieJar 门控（批 2 收尾）：上游 BookCover.searchCover 以
        // CoverRule 作 AnalyzeUrl(source=…) → 按本配置 enabledCookieJar 补标记
        //（缺省/None 按关，与上游字段默认 false 一致）。
        let body = self.resources.runtime.block_on(async {
            match tokio::time::timeout(
                Duration::from_secs(COVER_RULE_TIMEOUT_SECS),
                crate::rule_text::fetch_body(
                    &self.resources.network,
                    &analyze_url,
                    config.enabled_cookie_jar,
                ),
            )
            .await
            {
                Ok(result) => result,
                Err(_) => Err(format!(
                    "请求超时（>{COVER_RULE_TIMEOUT_SECS}s）: {}",
                    analyze_url.url()
                )),
            }
        })?;

        // 4. coverRule 提取（getString 语义，复用 AnalyzeRule 自动路由）
        let analyzer = AnalyzeRule::new(body, analyze_url.url().to_string())
            .with_variable_reader(self.resources.js.variable_reader());
        let raw = analyzer
            .get_string(cover_rule)
            .map_err(|e| format!("coverRule 提取失败: {e}"))?;
        let raw = raw.trim();
        if raw.is_empty() {
            return Ok(None);
        }

        // 5. isUrl=true 语义：提取结果按 URL 处理，相对路径补全为绝对 URL
        Ok(Some(AnalyzeUrl::get_absolute_url(analyze_url.url(), raw)))
    }
}

#[cfg(test)]
mod tests;
