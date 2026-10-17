//! 词典应用服务：显式存储/网络/JS资源，不访问宿主全局状态。
mod rules;
mod scope;
mod text;
use crate::{NetworkContext, StorageContext};
use legado_core::{LegadoError, LegadoResult};
use legado_db::{DictRule, DictRuleRepository};
use legado_parser::{AnalyzeRule, AnalyzeUrl, JsExecutor};
use rules::parse_import_rules;
use scope::DictScopeExecutor;
use serde::Serialize;
use std::{collections::HashMap, sync::Arc, time::Duration};
use text::html_to_text;
const DICT_RULE_TIMEOUT_SECS: u64 = 15;

/// 词典查询结果实体
///
/// 序列化字段对齐 Dart `DictEntry` 模型：`word` / `phonetic` / `definitions`。
#[derive(Debug, Clone, Serialize)]
pub struct DictEntry {
    /// 归一化后的单词（trim）
    pub word: String,
    /// 音标（字典规则链路无结构化音标，恒为空字符串）
    pub phonetic: String,
    /// 释义条目列表（每条对应一个启用字典规则的结果，前缀 `【规则名】`）
    pub definitions: Vec<String>,
}

pub struct DictionaryResources {
    pub storage: Option<StorageContext>,
    pub network: Arc<NetworkContext>,
    pub js: Arc<legado_js::JsResources>,
    pub runtime: tokio::runtime::Handle,
}
pub struct DictionaryService {
    resources: DictionaryResources,
}
impl DictionaryService {
    pub fn new(resources: DictionaryResources) -> Self {
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
    pub fn dict_lookup(&self, word: &str) -> LegadoResult<DictEntry> {
        let key = word.trim().to_string();

        if self.resources.storage.is_none() {
            // 数据库未初始化：与旧静态表时代的「无异常」语义保持一致
            return Ok(empty_entry(key));
        }

        let rules = self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            // 对标 Kotlin DefaultData.importDefaultDictRules：表为空时注入原版默认 5 源
            repo.seed_default_rules()?;
            repo.find_enabled()
        })?;

        // 无启用规则：返回空 definitions（契约约定非异常）
        let mut definitions = Vec::new();
        for rule in rules {
            match self.search_dict_rule(&rule, &key) {
                Ok(text) => {
                    let text = html_to_text(&text);
                    if !text.trim().is_empty() {
                        definitions.push(format!("【{}】{}", rule.name, text.trim()));
                    }
                }
                Err(e) => {
                    // 原版在独立页签内展示单规则错误；本契约为扁平列表，失败仅记日志跳过
                    log::warn!("字典规则 [{}] 查询「{}」失败: {}", rule.name, key, e);
                }
            }
        }

        Ok(DictEntry {
            word: key,
            phonetic: String::new(),
            definitions,
        })
    }
    pub fn dict_rule_list(&self) -> LegadoResult<Vec<DictRule>> {
        self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            // 表为空时注入原版默认 5 源（对标 dict_lookup 的 seed 行为）
            repo.seed_default_rules()?;
            let rules = repo.list_all_ordered()?;
            Ok(rules)
        })
    }
    pub fn dict_rule_add(&self, name: &str, url_rule: &str, show_rule: &str) -> LegadoResult<i64> {
        self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.insert(name, url_rule, show_rule)
        })
    }
    pub fn dict_rule_update(
        &self,
        id: i64,
        name: &str,
        url_rule: &str,
        show_rule: &str,
    ) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.update(id, name, url_rule, show_rule)
        })
    }
    pub fn dict_rule_delete(&self, id: i64) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.delete(id)
        })
    }
    pub fn dict_rule_set_enabled(&self, id: i64, enabled: bool) -> LegadoResult<bool> {
        self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.set_enabled(id, enabled)
        })
    }
    pub fn reorder_dict_rules(&self, ids: &[i64]) -> LegadoResult<i32> {
        self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            repo.reorder(ids)?;
            Ok(ids.len() as i32)
        })
    }
    pub fn dict_rule_import(&self, json_or_url: &str, kind: &str) -> LegadoResult<i32> {
        let body = match kind {
            "url" => self.fetch_url_body(json_or_url)?,
            _ => json_or_url.to_string(),
        };

        let rules = parse_import_rules(&body)?;

        let count = self.with_database(|db| {
            let repo = DictRuleRepository::new(db.connection());
            for rule in &rules {
                // REPLACE by name：同名覆盖（保留 id），异名插入
                repo.upsert_by_name(rule)?;
            }
            Ok(rules.len() as i32)
        })?;

        Ok(count)
    }
}

fn empty_entry(word: String) -> DictEntry {
    DictEntry {
        word,
        phonetic: String::new(),
        definitions: Vec::new(),
    }
}

#[cfg(test)]
mod tests;
