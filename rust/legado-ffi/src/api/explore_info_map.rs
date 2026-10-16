//! 发现页 infoMap 存储（对标 Android `InfoMap` + `exploreInfoMapList`）
//!
//! 发现分类的 toggle/select/text 控件会读写 infoMap；抓取书籍时
//! `AnalyzeUrl` 须携带同一 infoMap 才能与原版请求 URL 一致。

use legado_core::LegadoResult;
use std::collections::HashMap;

/// 获取书源 infoMap 快照（内存优先，回退 DB）
pub fn snapshot(source_url: &str) -> LegadoResult<HashMap<String, String>> {
    Ok(crate::engine_holder::source_info_map().snapshot(source_url))
}

/// 写入单个键（对标 Android infoMap[title] = value）
pub fn put(source_url: &str, key: &str, value: &str) -> LegadoResult<()> {
    crate::engine_holder::source_info_map().put(source_url, key, value);
    Ok(())
}

/// 若键不存在则写入默认值（toggle/select 初始化）
pub fn ensure_default(source_url: &str, key: &str, default: &str) -> LegadoResult<()> {
    crate::engine_holder::source_info_map().ensure_default(source_url, key, default);
    Ok(())
}

/// 将 infoMap 展平为 AnalyzeUrl 变量表（含 `infoMap.key` 点号键）
pub fn variables_for_url(
    source_url: &str,
    page: i32,
    base_url: &str,
) -> LegadoResult<HashMap<String, String>> {
    let info_map = snapshot(source_url)?;
    let mut variables = HashMap::new();
    variables.insert("page".to_string(), page.max(1).to_string());
    variables.insert("baseUrl".to_string(), base_url.to_string());
    for (k, v) in &info_map {
        variables.insert(k.clone(), v.clone());
        variables.insert(format!("infoMap.{k}"), v.clone());
    }
    // 供 JS 前缀注入完整 infoMap 对象
    let json = serde_json::to_string(&info_map).unwrap_or_else(|_| "{}".to_string());
    variables.insert("__infoMapJson".to_string(), json);
    Ok(variables)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_variables_for_url_includes_info_map_entries() {
        let source = "https://explore-info-map.test";
        put(source, "榜类", "推荐").unwrap();
        let vars = variables_for_url(source, 1, source).unwrap();
        assert_eq!(vars.get("榜类"), Some(&"推荐".to_string()));
        assert_eq!(vars.get("infoMap.榜类"), Some(&"推荐".to_string()));
        assert_eq!(vars.get("page"), Some(&"1".to_string()));
    }
}
