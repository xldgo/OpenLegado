//! 词典请求与导入解析，保持错误和作用域语义。
use super::scope::engine_tag;
use super::*;

impl DictionaryService {
    pub(super) fn fetch_url_body(&self, url: &str) -> LegadoResult<String> {
        if url.trim().is_empty() {
            return Err(LegadoError::Database("导入 URL 为空".to_string()));
        }
        // 纯 URL（非规则模板）：构建单变量请求走既有取体链路
        let analyze_url = AnalyzeUrl::parse(url, &HashMap::new(), 1)
            .map_err(|e| LegadoError::Database(format!("解析导入 URL 失败: {e}")))?;
        // 写侧 CookieJar 门控：导入动作无源上下文（上游 ImportDictRuleDialog
        // 同为显式导入、不经 BaseSource），恒不补标记。
        let body = self
            .resources
            .runtime
            .block_on(async {
                match tokio::time::timeout(
                    Duration::from_secs(DICT_RULE_TIMEOUT_SECS),
                    crate::rule_text::fetch_body(&self.resources.network, &analyze_url, None),
                )
                .await
                {
                    Ok(result) => result,
                    Err(_) => Err(format!("抓取超时（>{DICT_RULE_TIMEOUT_SECS}s）: {url}")),
                }
            })
            .map_err(LegadoError::Database)?;
        Ok(body)
    }
    pub(super) fn search_dict_rule(&self, rule: &DictRule, key: &str) -> Result<String, String> {
        // 1. 构建请求（对标 AnalyzeUrl(urlRule, key = word)）
        let analyze_url = self.build_request(rule, key)?;

        // 2. 取响应 body（单规则超时保护）
        // 写侧 CookieJar 门控：DictRule 无 enabledCookieJar 字段（上游
        // DictRule.search 构造 AnalyzeUrl 不传 source），恒不补标记。
        let body = self.resources.runtime.block_on(async {
            match tokio::time::timeout(
                Duration::from_secs(DICT_RULE_TIMEOUT_SECS),
                crate::rule_text::fetch_body(&self.resources.network, &analyze_url, None),
            )
            .await
            {
                Ok(result) => result,
                Err(_) => Err(format!(
                    "请求超时（>{DICT_RULE_TIMEOUT_SECS}s）: {}",
                    analyze_url.url()
                )),
            }
        })?;

        // 3. showRule 解析（对标 AnalyzeRule.getString(showRule, mContent = body)）
        self.apply_show_rule(&rule.name, &rule.show_rule, &body, analyze_url.url(), key)
    }
    fn build_request(&self, rule: &DictRule, key: &str) -> Result<AnalyzeUrl, String> {
        let tag = engine_tag(&rule.name);
        // Kotlin AnalyzeUrl 构造时把 key 绑定进 JS 作用域，此处经前置注入等价实现
        let executor =
            DictScopeExecutor::with_resources(&self.resources.js, &tag, key, &rule.url_rule);
        let mut vars = HashMap::new();
        vars.insert("key".to_string(), key.to_string());
        vars.insert("word".to_string(), key.to_string());

        #[cfg(feature = "quickjs")]
        {
            AnalyzeUrl::parse_with_js(&rule.url_rule, &vars, 1, &executor)
                .map_err(|e| e.to_string())
        }
        #[cfg(not(feature = "quickjs"))]
        {
            let _ = executor;
            AnalyzeUrl::parse(&rule.url_rule, &vars, 1).map_err(|e| e.to_string())
        }
    }
    fn apply_show_rule(
        &self,
        rule_name: &str,
        show_rule: &str,
        body: &str,
        base_url: &str,
        key: &str,
    ) -> Result<String, String> {
        let rule = show_rule.trim();
        if rule.is_empty() {
            return Ok(body.to_string());
        }

        let tag = engine_tag(rule_name);
        match rule.find("@js:") {
            None => self
                .build_analyzer(body, base_url, &tag, key)
                .get_string(rule)
                .map_err(|e| format!("showRule 解析失败: {e}")),
            Some(idx) => {
                let selector = rule[..idx].trim();
                let js_code = &rule[idx + "@js:".len()..];

                // 前置选择器（若有）先解析，结果作为 JS 的 result 绑定
                let intermediate = if selector.is_empty() {
                    body.to_string()
                } else {
                    self.build_analyzer(body, base_url, &tag, key)
                        .get_string(selector)
                        .map_err(|e| format!("showRule 选择器解析失败: {e}"))?
                };

                let executor =
                    DictScopeExecutor::with_resources(&self.resources.js, &tag, key, &intermediate);
                executor.execute_js(js_code)
            }
        }
    }
    fn build_analyzer(&self, content: &str, base_url: &str, tag: &str, key: &str) -> AnalyzeRule {
        let executor = DictScopeExecutor::with_resources(&self.resources.js, tag, key, content);
        AnalyzeRule::with_js_executor(
            content.to_string(),
            base_url.to_string(),
            Arc::new(executor),
        )
    }
}

pub(super) fn parse_import_rules(body: &str) -> LegadoResult<Vec<DictRule>> {
    let trimmed = body.trim();
    if trimmed.is_empty() {
        return Err(LegadoError::Database("导入内容为空".to_string()));
    }

    // 复用原版模型（serde 字段名 camelCase 对齐 GSON）
    type LegacyRule = legado_core::models::DictRule;

    let legacy: Vec<LegacyRule> = if trimmed.starts_with('[') {
        serde_json::from_str(trimmed)
            .map_err(|e| LegadoError::Database(format!("解析导入 JSON 数组失败: {e}")))?
    } else {
        let single: LegacyRule = serde_json::from_str(trimmed)
            .map_err(|e| LegadoError::Database(format!("解析导入 JSON 单对象失败: {e}")))?;
        vec![single]
    };

    Ok(legacy
        .into_iter()
        .filter(|r| !r.name.trim().is_empty())
        .map(|m| DictRule {
            id: 0,
            name: m.name.trim().to_string(),
            url_rule: m.url_rule,
            show_rule: m.show_rule,
            is_enabled: m.enabled,
            sort_order: m.sort_number,
        })
        .collect())
}
