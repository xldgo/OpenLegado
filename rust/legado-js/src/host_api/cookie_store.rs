//! Cookie 窄数据能力及无状态转换；不持有进程级镜像或注册钩子。
use std::collections::HashMap;

/// 回调只捕获实例数据资源，不反向保留 EngineContext 或 VM 缓存。
pub trait CookieAccess: Send + Sync {
    fn get(&self, url: &str) -> String;
    fn set(&self, url: &str, cookie: &str);
    fn clear(&self, url: &str);
    fn clear_all(&self);
}

/// 按首次键位置保留顺序；跳过无等号、空键或空值。
pub fn cookie_str_to_map(cookie_str: &str) -> Vec<(String, String)> {
    let mut out: Vec<(String, String)> = Vec::new();
    for seg in cookie_str.split(';') {
        let seg = seg.trim();
        let Some(eq) = seg.find('=') else {
            continue;
        };
        let key = seg[..eq].trim();
        if key.is_empty() {
            continue;
        }
        let value = seg[eq + 1..].trim();
        if value.is_empty() {
            continue;
        }
        if let Some(slot) = out.iter_mut().find(|(k, _)| k == key) {
            slot.1 = value.to_string();
        } else {
            out.push((key.to_string(), value.to_string()));
        }
    }
    out
}

/// 上游 `CookieStore.mapToCookie` 语义的纯函数：空表 → `None`（上游返回
/// null）；否则 `k=v` 以 `; ` 连接（键值不再 trim——map 已是规范形态）。
pub fn map_to_cookie_str(pairs: &[(String, String)]) -> Option<String> {
    if pairs.is_empty() {
        return None;
    }
    Some(
        pairs
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join("; "),
    )
}

/// 已有请求头的同名 Cookie 优先，仅追加非冲突键。
pub fn merge_cookie_string(headers: &mut HashMap<String, String>, js_cookie: &str) {
    if js_cookie.is_empty() {
        return;
    }
    let existing_key = headers
        .keys()
        .find(|k| k.eq_ignore_ascii_case("cookie"))
        .cloned();
    match existing_key {
        Some(key) => {
            let existing = headers.get(&key).map(String::as_str).unwrap_or("");
            // 已有 cookie 名集（cookie 名大小写敏感：按 `;` 拆段取 `=` 前）
            let mut existing_names: std::collections::HashSet<String> = existing
                .split(';')
                .filter_map(|part| {
                    let part = part.trim();
                    if part.is_empty() {
                        return None;
                    }
                    Some(part.split('=').next()?.to_string())
                })
                .collect();
            // 非冲突 JS 键按序追加（同名跳过——已有键胜）
            let mut extra = String::new();
            for pair in js_cookie.split("; ") {
                let name = match pair.split_once('=') {
                    Some((n, _)) => n,
                    None => continue,
                };
                if existing_names.insert(name.to_string()) {
                    if !extra.is_empty() {
                        extra.push_str("; ");
                    }
                    extra.push_str(pair);
                }
            }
            if !extra.is_empty() {
                let combined = if existing.trim().is_empty() {
                    extra
                } else {
                    format!("{existing}; {extra}")
                };
                headers.insert(key, combined);
            }
        }
        None => {
            headers.insert("Cookie".to_string(), js_cookie.to_string());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_cookie_str_to_map_upstream_semantics() {
        // 基本拆分 + 键值 trim
        let m = cookie_str_to_map("a=1; b = 2 ;c=3");
        assert_eq!(
            m,
            vec![
                ("a".to_string(), "1".to_string()),
                ("b".to_string(), "2".to_string()),
                ("c".to_string(), "3".to_string()),
            ]
        );
        // 无 `=` 段跳过、空值段剔除（上游 isNotBlank 判定）
        let m = cookie_str_to_map("novalue; empty=; ok=v; =nokey;  ;");
        assert_eq!(m, vec![("ok".to_string(), "v".to_string())]);
        // 值内 `=` 保留（首个 `=` 分界，上游 split limit 2 口径）
        let m = cookie_str_to_map("sig=abc==;x=1");
        assert_eq!(m[0], ("sig".to_string(), "abc==".to_string()));
        // 同名键：位置保留、值覆盖（LinkedHashMap put 语义）
        let m = cookie_str_to_map("a=1; b=2; a=9");
        assert_eq!(
            m,
            vec![
                ("a".to_string(), "9".to_string()),
                ("b".to_string(), "2".to_string()),
            ]
        );
        // 空串 → 空表
        assert!(cookie_str_to_map("").is_empty());
    }

    #[test]
    fn test_map_to_cookie_str() {
        // 空 → None（上游 mapToCookie 空表返回 null）
        assert_eq!(map_to_cookie_str(&[]), None);
        let pairs = vec![
            ("a".to_string(), "1".to_string()),
            ("b".to_string(), "2".to_string()),
        ];
        assert_eq!(map_to_cookie_str(&pairs), Some("a=1; b=2".to_string()));
    }
}
