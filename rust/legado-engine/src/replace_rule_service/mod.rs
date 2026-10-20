//! 替换规则管理与执行；借用连接，预览资源由宿主显式传入。
use legado_core::content_processor::{ReplaceRuleEntry, apply_source_replace_rules};
use legado_core::{LegadoError, LegadoResult, models::ReplaceRule};
use legado_db::{Database, ReplaceRuleRepository};

mod preview;
pub use preview::preview_replace_rule;

/// 现有编辑入口允许写入的字段，未提供的可选项在更新时保留。
pub struct ReplaceRuleFields<'a> {
    pub name: &'a str,
    pub pattern: &'a str,
    pub replacement: &'a str,
    pub is_regex: bool,
    pub group: Option<&'a str>,
    pub scope_title: Option<bool>,
    pub scope_content: Option<bool>,
    pub exclude_scope: Option<&'a str>,
    pub timeout_millisecond: Option<i64>,
    pub scope_source: Option<bool>,
}

pub struct ReplaceRuleService<'a> {
    db: &'a Database,
}
impl<'a> ReplaceRuleService<'a> {
    pub fn new(db: &'a Database) -> Self {
        Self { db }
    }
    fn repository(&self) -> ReplaceRuleRepository<'_> {
        ReplaceRuleRepository::new(self.db.connection())
    }
    pub fn list_rules(&self) -> LegadoResult<Vec<ReplaceRule>> {
        self.repository().find_all()
    }
    pub fn add_rule(&self, scope: &str, fields: ReplaceRuleFields<'_>) -> LegadoResult<i64> {
        let rule = ReplaceRule {
            id: 0,
            name: fields.name.to_string(),
            group: fields.group.map(str::to_string),
            pattern: fields.pattern.to_string(),
            replacement: fields.replacement.to_string(),
            scope: if scope.is_empty() {
                None
            } else {
                Some(scope.to_string())
            },
            scope_title: fields.scope_title.unwrap_or(false),
            scope_content: fields.scope_content.unwrap_or(true),
            scope_source: fields.scope_source.unwrap_or(false),
            exclude_scope: fields
                .exclude_scope
                .filter(|s| !s.is_empty())
                .map(str::to_string),
            is_enabled: true,
            is_regex: fields.is_regex,
            timeout_millisecond: fields.timeout_millisecond.unwrap_or(3000),
            order: 0,
        };
        self.repository().insert(&rule)
    }
    pub fn update_rule(
        &self,
        id: i64,
        enabled: bool,
        fields: ReplaceRuleFields<'_>,
    ) -> LegadoResult<()> {
        let repo = self.repository();
        let all = repo.find_all()?;
        let existing = all
            .iter()
            .find(|r| r.id == id)
            .ok_or_else(|| LegadoError::Database("替换规则不存在".into()))?;
        let merged_group = match fields.group {
            Some(s) if !s.is_empty() => Some(s.to_string()),
            Some(_) => None,
            None => existing.group.clone(),
        };
        let merged_exclude = match fields.exclude_scope {
            Some(s) if !s.is_empty() => Some(s.to_string()),
            Some(_) => None,
            None => existing.exclude_scope.clone(),
        };
        let updated = ReplaceRule {
            id,
            name: fields.name.to_string(),
            group: merged_group,
            pattern: fields.pattern.to_string(),
            replacement: fields.replacement.to_string(),
            scope: existing.scope.clone(),
            scope_title: fields.scope_title.unwrap_or(existing.scope_title),
            scope_content: fields.scope_content.unwrap_or(existing.scope_content),
            scope_source: fields.scope_source.unwrap_or(existing.scope_source),
            exclude_scope: merged_exclude,
            is_enabled: enabled,
            is_regex: fields.is_regex,
            timeout_millisecond: fields
                .timeout_millisecond
                .unwrap_or(existing.timeout_millisecond),
            order: existing.order,
        };
        repo.update(&updated)
    }
    pub fn delete_rule(&self, id: i64) -> LegadoResult<()> {
        self.repository().delete(id)
    }
    pub fn enabled_rules(&self) -> LegadoResult<Vec<ReplaceRule>> {
        self.repository().get_enabled_rules()
    }
    pub fn set_enabled(&self, id: i64, enabled: bool) -> LegadoResult<()> {
        self.repository().set_enabled(id, enabled)
    }
    /// 书源规则沿用无生产JS执行器的路径，与编辑器预览区分。
    pub fn apply_to_source(&self, json: &str, name: &str, url: &str) -> LegadoResult<String> {
        let rules = self.enabled_rules()?;
        let entries: Vec<ReplaceRuleEntry> = rules
            .iter()
            .map(ReplaceRuleEntry::from_replace_rule)
            .collect();
        Ok(apply_source_replace_rules(json, &entries, name, url, None))
    }
}

#[cfg(test)]
mod tests;
