//! V1登录沿用带setup的解析器与既有错误忽略策略。
use super::*;

fn get_login_js(source: &BookSource) -> Option<String> {
    let rule = source.login_url.as_deref()?.trim();
    if rule.is_empty() {
        return None;
    }
    let lower = rule.to_lowercase();
    if lower.starts_with("<js>") {
        let end = rule.rfind('<').unwrap_or(rule.len());
        return Some(rule[4..end].to_string());
    }
    if lower.starts_with("@js:") {
        return Some(rule[4..].to_string());
    }
    Some(rule.to_string())
}

impl SourceActionService {
    pub fn eval_login_v1(&self, source: &BookSource, action: &str) -> LegadoResult<String> {
        let login_js = get_login_js(source)
            .ok_or_else(|| LegadoError::JsEngine("书源 loginUrl 缺失或为空".into()))?;

        // 对齐原版：`loginJs` + `if(typeof login=='function'){login.apply(this);}`
        // this 绑定为 {source, cookie, java}（setup 语义；书山 login() 内
        // `const {java, source, cookie} = this` 解构依赖）
        let action_name = if action.trim().is_empty() {
            "login"
        } else {
            action.trim().trim_end_matches('(').trim_end_matches(')')
        };
        let script = format!("{login_js}\n")
            + "if (typeof "
            + action_name
            + " == 'function') {"
            + "  "
            + action_name
            + ".apply({ source: source, cookie: cookie, java: java });"
            + "}";

        // 书源上下文：sanitize jsLib + setup（含 header 规则注入全局请求头）
        let js_lib_sanitized = source
            .js_lib
            .as_deref()
            .map(legado_fetcher::js_adapter::sanitize_js_lib_for_quickjs);
        let analyzer = legado_fetcher::js_adapter::construct_analyzer_with_source_context(
            &self
                .resources
                .js
                .for_source("source", &source.book_source_url, ""),
            String::new(),
            source.book_source_url.clone(),
            &source.book_source_url,
            js_lib_sanitized.as_deref(),
            (self.resources.setup)(source).ok(),
        );
        let _ = analyzer.get_string(&format!("@js:{script}"));

        // 返回登录头状态（便于 UI 判定登录结果）
        let header = self
            .resources
            .login
            .get_login_header(&source.book_source_url)
            .unwrap_or_default();
        if header.is_empty() || header == "null" {
            return Ok(String::new());
        }
        Ok(header)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_login_js_strips_wrappers() {
        let src = BookSource {
            book_source_url: "https://t.test".to_string(),
            login_url: Some("<js>function login(){ return 1; }</js>".to_string()),
            ..BookSource::default()
        };
        let js = get_login_js(&src).unwrap();
        assert!(js.contains("function login"));
        assert!(!js.contains("<js>"));
    }

    #[test]
    fn test_get_login_js_plain_kept() {
        let src = BookSource {
            book_source_url: "https://t.test".to_string(),
            login_url: Some("function login(){ return 1; }".to_string()),
            ..BookSource::default()
        };
        assert_eq!(get_login_js(&src).unwrap(), "function login(){ return 1; }");
    }
}
