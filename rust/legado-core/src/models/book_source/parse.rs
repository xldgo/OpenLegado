//! 书源 JSON 统一解析（SOURCE-PARSE-UNIFY-20261022）
//!
//! 本模块是**唯一**的书源 JSON 解析实现，`legado-ffi::source_import`、
//! `legado-db::RoomImporter`、`legado-engine::RoomSourceImport`、
//! `legado-server::source_update` 必须全部经由这里，禁止再保留第二套字段解释。
//!
//! 转换规则对齐上游 `GsonExtensions.kt`：
//! - `StringJsonDeserializer`：标量 → 字符串、`null` → `null`、数组/对象 → JSON 字符串
//! - 六个规则类各自的 `jsonDeserializer`：接受对象，也接受「内容为 JSON 对象的字符串」
//! - `IntJsonDeserializer`：上游非数字即 null；本实现**有意保留数字字符串兼容超集**
//!   （见契约 SOURCE-PARSE-UNIFY-20261022），其余非法形态不静默转 0
//!
//! 语义要点：
//! - 整数：接受整数与合法整数字符串；超范围报错；布尔/数组/对象/非法字符串报错
//! - 布尔：`true/false`、`0/1`、`"true"/"false"/"1"/"0"/""`
//! - `Option<String>`：显式 `null` → `None`；标量 → 字符串；数组/对象 → JSON 字符串
//! - 非空 `String`（URL/名称）：显式 `null` → 空串；其余同上
//! - 规则字段：对象 / JSON 对象字符串两态

use serde::de::Error as _;
use serde::{Deserialize, Deserializer};
use serde_json::Value;

use super::super::rule::{BookInfoRule, ContentRule, ExploreRule, ReviewRule, SearchRule, TocRule};

// ─── 标量转换原语 ─────────────────────────────────────────────────────────────

/// `Option<String>` 的 `StringJsonDeserializer` 等价实现。
///
/// - `null` → `None`
/// - 字符串 → 原样
/// - 数字/布尔 → 其字符串形式（`1` → `"1"`、`true` → `"true"`）
/// - 数组/对象 → JSON 紧凑字符串（`[1,2]` → `"[1,2]"`）
pub fn lenient_opt_string<'de, D: Deserializer<'de>>(d: D) -> Result<Option<String>, D::Error> {
    let value = Value::deserialize(d)?;
    Ok(match value {
        Value::Null => None,
        Value::String(s) => Some(s),
        other => Some(scalar_or_json_to_string(&other)),
    })
}

/// 非空 `String` 版本：`null` → 空串（与既有 `variable` 口径一致），其余同上。
///
/// `bookSourceUrl` / `bookSourceName` 等非可空字段使用；空值是否可保存由
/// 既有必填校验负责，解析层不拦截。
pub fn lenient_string<'de, D: Deserializer<'de>>(d: D) -> Result<String, D::Error> {
    Ok(lenient_opt_string(d)?.unwrap_or_default())
}

/// 标量/复合值 → 字符串：字符串原样、数字与布尔取其字面量、数组与对象转 JSON 文本。
fn scalar_or_json_to_string(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        // `to_string` 对数字/布尔即其 JSON 字面量（1 → "1"、true → "true"）
        other => other.to_string(),
    }
}

/// 整数（`i64`）：接受整数与合法整数字符串，超范围报错，其余形态明确报错。
///
/// 有意保留数字字符串兼容（契约 SOURCE-PARSE-UNIFY-20261022 记录的兼容超集）。
pub fn lenient_i64<'de, D: Deserializer<'de>>(d: D) -> Result<i64, D::Error> {
    let value = Value::deserialize(d)?;
    match &value {
        Value::Number(n) => n
            .as_i64()
            .ok_or_else(|| D::Error::custom(format!("整数超出 i64 范围: {n}"))),
        Value::String(s) => s
            .trim()
            .parse::<i64>()
            .map_err(|_| D::Error::custom(format!("无法解析整数: {s:?}"))),
        // 显式 null 已在 [normalize_null_scalars] 阶段按「未提供」剔除，
        // 理论不可达；此处保守报错，避免静默转 0（契约要求不静默转 0）。
        Value::Null => Err(D::Error::custom(
            "整数字段不接受显式 null（应在归一化阶段按未提供处理）",
        )),
        other => Err(D::Error::custom(format!(
            "整数字段类型非法: {}",
            json_type_name(other)
        ))),
    }
}

/// 整数（`i32`）：在 `i64` 基础上校验目标范围。
pub fn lenient_i32<'de, D: Deserializer<'de>>(d: D) -> Result<i32, D::Error> {
    let v = lenient_i64(d)?;
    i32::try_from(v).map_err(|_| D::Error::custom(format!("整数超出 i32 范围: {v}")))
}

/// 可空整数：缺省由字段默认处理，显式null保留None，其余复用i32转换。
pub fn lenient_opt_i32<'de, D: Deserializer<'de>>(d: D) -> Result<Option<i32>, D::Error> {
    let value = Value::deserialize(d)?;
    if value.is_null() {
        return Ok(None);
    }
    lenient_i32(value).map(Some).map_err(D::Error::custom)
}

/// 布尔：兼容 `true/false`、`0/1`、`"true"/"false"/"1"/"0"/""`。
pub fn lenient_bool<'de, D: Deserializer<'de>>(d: D) -> Result<bool, D::Error> {
    let value = Value::deserialize(d)?;
    lenient_bool_from_value(&value).map_err(D::Error::custom)
}

/// `Option<bool>` 版本：`null` → `None`，其余同 [`lenient_bool`]。
pub fn lenient_opt_bool<'de, D: Deserializer<'de>>(d: D) -> Result<Option<bool>, D::Error> {
    let value = Value::deserialize(d)?;
    if value.is_null() {
        return Ok(None);
    }
    lenient_bool_from_value(&value)
        .map(Some)
        .map_err(D::Error::custom)
}

/// 默认关闭的非可空布尔：显式null取false，其余复用统一布尔转换。
pub fn lenient_bool_default_false<'de, D: Deserializer<'de>>(d: D) -> Result<bool, D::Error> {
    Ok(lenient_opt_bool(d)?.unwrap_or_default())
}

fn lenient_bool_from_value(value: &Value) -> Result<bool, String> {
    match value {
        Value::Bool(b) => Ok(*b),
        Value::Number(n) => n
            .as_i64()
            .map(|v| v != 0)
            .ok_or_else(|| format!("布尔字段数字非法: {n}")),
        Value::String(s) => match s.trim() {
            "true" | "1" => Ok(true),
            "false" | "0" | "" => Ok(false),
            other => Err(format!("无法解析布尔值: {other:?}")),
        },
        other => Err(format!("布尔字段类型非法: {}", json_type_name(other))),
    }
}

fn json_type_name(value: &Value) -> &'static str {
    match value {
        Value::Null => "null",
        Value::Bool(_) => "布尔",
        Value::Number(_) => "数字",
        Value::String(_) => "字符串",
        Value::Array(_) => "数组",
        Value::Object(_) => "对象",
    }
}

// ─── 规则对象：对象 / JSON 对象字符串两态 ──────────────────────────────────────

/// 规则字段统一反序列化：接受 JSON 对象，也接受「内容为 JSON 对象的字符串」。
///
/// 对齐上游六个规则类的 `jsonDeserializer`：
/// `isJsonObject -> fromJson(json)`、`isJsonPrimitive -> fromJson(json.asString)`、
/// 其他形态 → `None`（上游为 `else -> null`）。
pub fn lenient_rule<'de, D, T>(d: D) -> Result<Option<T>, D::Error>
where
    D: Deserializer<'de>,
    T: for<'de2> Deserialize<'de2>,
{
    let value = Value::deserialize(d)?;
    rule_from_value(value).map_err(D::Error::custom)
}

fn rule_from_value<T>(value: Value) -> Result<Option<T>, String>
where
    T: for<'de2> Deserialize<'de2>,
{
    match value {
        Value::Null | Value::Array(_) => Ok(None),
        Value::Object(_) => deserialize_value(value).map(Some),
        Value::String(text) => {
            if text.trim().is_empty() {
                return Ok(None);
            }
            let value: Value = serde_json::from_str(&text)
                .map_err(|error| format!("规则 JSON 语法错误: {error}"))?;
            if value.is_null() {
                return Ok(None);
            }
            deserialize_value(value).map(Some)
        }
        other => Err(format!(
            "规则必须是对象或JSON对象字符串，实际为{}",
            json_type_name(&other)
        )),
    }
}

/// 内层规则和外层书源均保留目标字段路径；不依赖错误文本反推字段。
fn deserialize_value<T>(value: Value) -> Result<T, String>
where
    T: for<'de2> Deserialize<'de2>,
{
    serde_path_to_error::deserialize(value)
        .map_err(|error| format!("字段 {}: {}", error.path(), error.inner()))
}

// 规则结构体的反序列化入口包装（供 `#[serde(deserialize_with)]` 直接引用）
macro_rules! rule_deserializer {
    ($fn_name:ident, $ty:ty) => {
        pub fn $fn_name<'de, D>(d: D) -> Result<Option<$ty>, D::Error>
        where
            D: Deserializer<'de>,
        {
            lenient_rule::<D, $ty>(d)
        }
    };
}

rule_deserializer!(lenient_explore_rule, ExploreRule);
rule_deserializer!(lenient_search_rule, SearchRule);
rule_deserializer!(lenient_book_info_rule, BookInfoRule);
rule_deserializer!(lenient_toc_rule, TocRule);
rule_deserializer!(lenient_content_rule, ContentRule);
rule_deserializer!(lenient_review_rule, ReviewRule);

// ─── 统一解析入口 ─────────────────────────────────────────────────────────────

/// 非可空标量字段：`null` 按「未提供」处理，以便走字段自身的默认值。
///
/// 契约 SOURCE-PARSE-UNIFY-20261022 要求缺省与显式 `null` 分别确定行为：
/// 对 `bookSourceType`/`customOrder`/`weight`/`lastUpdateTime`/`respondTime`/
/// `enabled` 等非可空字段，显式 `null` 与缺省同义（`respondTime` 得 180000，
/// 而非 0）。`Option<...>` 字段不在此列——它们的 `null` 有独立语义（`None`）。
const NON_NULLABLE_SCALAR_KEYS: &[&str] = &[
    "bookSourceType",
    "customOrder",
    "enabled",
    "enabledExplore",
    "lastUpdateTime",
    "respondTime",
    "weight",
    "eventListener",
    "customButton",
];

/// 将非可空标量字段的显式 `null` 剔除，使其按「未提供」落到 serde 默认值。
fn normalize_null_scalars(value: &mut Value) {
    let Some(object) = value.as_object_mut() else {
        return;
    };
    for key in NON_NULLABLE_SCALAR_KEYS {
        if object.get(*key).is_some_and(Value::is_null) {
            object.remove(*key);
        }
    }
}

/// 解码原始文档；批量预览和严格导入共用顶层结构规则。
pub fn decode_source_values(json: &str) -> crate::LegadoResult<Vec<Value>> {
    let value: Value = serde_json::from_str(json)
        .map_err(|e| crate::LegadoError::Parser(format!("书源 JSON 语法错误: {e}")))?;
    match value {
        Value::Array(items) => Ok(items),
        Value::Object(_) => Ok(vec![value]),
        other => Err(crate::LegadoError::Parser(format!(
            "书源 JSON 期望数组或对象，实际为{}",
            json_type_name(&other)
        ))),
    }
}

/// 一次解释一个条目；预览可记录失败并继续，写入由批量入口整体拒绝。
pub fn parse_source_value(mut value: Value) -> crate::LegadoResult<super::BookSource> {
    if !value.is_object() {
        return Err(crate::LegadoError::Parser(format!(
            "书源条目必须是 JSON 对象，实际为{}",
            json_type_name(&value)
        )));
    }
    normalize_null_scalars(&mut value);
    deserialize_value(value)
        .map_err(|error| crate::LegadoError::Parser(format!("书源字段解析失败: {error}")))
}

/// 编辑回填接受单对象或数组首项，不因其他条目失败改变首项结果。
pub fn parse_source_json(json: &str) -> crate::LegadoResult<super::BookSource> {
    let value = decode_source_values(json)?
        .into_iter()
        .next()
        .ok_or_else(|| crate::LegadoError::Parser("书源 JSON 数组为空".into()))?;
    parse_source_value(value)
}

/// 严格批量解析：任一条目失败时拒绝整批，写入前即可完整校验。
pub fn parse_source_array(json: &str) -> crate::LegadoResult<Vec<super::BookSource>> {
    decode_source_values(json)?
        .into_iter()
        .enumerate()
        .map(|(index, value)| {
            parse_source_value(value).map_err(|error| {
                crate::LegadoError::Parser(format!("第 {} 项解析失败: {error}", index + 1))
            })
        })
        .collect()
}
