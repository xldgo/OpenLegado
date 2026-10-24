//! 规则文档共用解析；本地主键不参与跨设备合并。
use super::HighlightStyle;
use crate::models::HighlightRule;
use crate::{LegadoError, LegadoResult};
use serde_json::Value;
use sha2::{Digest, Sha256};

/// MD3的字符串ID（含预设名）转换为确定的UUID v8，原有UUID原样规范化。
pub fn external_uuid(value: &str) -> String {
    if let Ok(uuid) = uuid::Uuid::parse_str(value) {
        return uuid.to_string();
    }
    let hash = Sha256::digest(format!("openlegado:highlight-rule:{value}"));
    let mut bytes = [0; 16];
    bytes.copy_from_slice(&hash[..16]);
    bytes[6] = (bytes[6] & 0x0f) | 0x80;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    uuid::Uuid::from_bytes(bytes).to_string()
}

pub fn normalize_rule(mut rule: HighlightRule) -> LegadoResult<HighlightRule> {
    rule.uuid = if rule.uuid.trim().is_empty() {
        HighlightRule::new_uuid()
    } else {
        uuid::Uuid::parse_str(&rule.uuid)
            .map_err(|_| LegadoError::Parser("高亮规则UUID无效".into()))?
            .to_string()
    };
    let raw: Value = if rule.style.trim().is_empty() {
        serde_json::json!({})
    } else {
        serde_json::from_str(&rule.style)
            .map_err(|e| LegadoError::Parser(format!("高亮样式无效：{e}")))?
    };
    let mut style = HighlightStyle::parse(&rule.style)?;
    if raw.get("targetScope").is_none() {
        style.target_scope = if rule.applyToTitle { 0 } else { 2 };
    }
    rule.applyToTitle = style.target_scope != 2;
    rule.style = style.json()?;
    if rule.isRegex {
        let adapted = super::matcher::adapted_pattern(&rule.pattern);
        if crate::regex_safe::compile_regex_safe(&adapted).is_none()
            && crate::regex_safe::compile_fancy_regex_safe(&adapted).is_none()
        {
            return Err(LegadoError::Parser(format!(
                "高亮规则「{}」的正则无效",
                rule.name
            )));
        }
    }
    Ok(rule)
}

pub fn parse_document(content: &str) -> LegadoResult<Vec<HighlightRule>> {
    let decoded: Value = serde_json::from_str(content)
        .map_err(|e| LegadoError::Parser(format!("高亮规则JSON无效：{e}")))?;
    let entries = match decoded {
        Value::Array(items) => items,
        Value::Object(mut object) => {
            if let Some(rules) = object.remove("rules") {
                rules
                    .as_array()
                    .cloned()
                    .ok_or_else(|| LegadoError::Parser("rules必须是数组".into()))?
            } else {
                vec![Value::Object(object)]
            }
        }
        _ => return Err(LegadoError::Parser("请选择高亮规则对象或数组".into())),
    };
    let mut uuids = std::collections::HashSet::new();
    entries
        .into_iter()
        .enumerate()
        .map(|(index, entry)| {
            let result = (|| {
                let mut object = entry
                    .as_object()
                    .cloned()
                    .ok_or_else(|| LegadoError::Parser("规则必须是对象".into()))?;
                let md3_id = object.get("id").and_then(Value::as_str).map(str::to_owned);
                let md3 = md3_id.is_some()
                    || object.contains_key("targetScope")
                    || object.contains_key("bgColor");
                if md3 {
                    let style =
                        serde_json::from_value::<HighlightStyle>(Value::Object(object.clone()))
                            .map_err(|e| LegadoError::Parser(format!("高亮样式字段无效：{e}")))?
                            .normalized()?;
                    object.insert("style".into(), Value::String(style.json()?));
                    object.insert("isRegex".into(), Value::Bool(true));
                    if let Some(value) = object.remove("enabled") {
                        object.insert("isEnabled".into(), value);
                    }
                    if let Some(value) = object.remove("position") {
                        object.insert("sortOrder".into(), value);
                    }
                }
                if let Some(id) = md3_id {
                    object.insert("uuid".into(), Value::String(external_uuid(&id)));
                }
                object.insert("id".into(), Value::from(0));
                object.entry("sortOrder").or_insert(Value::from(index));
                let rule = normalize_rule(
                    serde_json::from_value::<HighlightRule>(Value::Object(object))
                        .map_err(|e| LegadoError::Parser(format!("规则字段无效：{e}")))?,
                )?;
                if !uuids.insert(rule.uuid.clone()) {
                    return Err(LegadoError::Parser("规则UUID重复".into()));
                }
                Ok(rule)
            })();
            result.map_err(|e| LegadoError::Parser(format!("第{}条高亮规则无效：{e}", index + 1)))
        })
        .collect()
}

/// 名称、正则、默认启停和统一底色来自MD3 HighlightRulePresets (91e19d0d0)。
pub fn presets() -> LegadoResult<Vec<HighlightRule>> {
    parse_document(include_str!("presets.json"))
}

/// 自有格式保留UUID和完整样式；本地主键不会用于下一次导入。
pub fn export_document(rules: &[HighlightRule]) -> LegadoResult<String> {
    let rules = rules
        .iter()
        .cloned()
        .map(normalize_rule)
        .collect::<LegadoResult<Vec<_>>>()?;
    serde_json::to_string_pretty(&rules).map_err(Into::into)
}
