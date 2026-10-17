//! 发现应用服务：显式资源与所属infoMap，不访问宿主全局槽位。
use crate::{SourceInfoMap, TaskGroup, TaskHandle};
use legado_core::{
    LegadoError, LegadoResult,
    explore::{ExploreCategory, parse_explore_url},
    models::BookSource,
    web_book::WebSearchResult,
};
use serde::Serialize;
use std::{collections::HashMap, sync::Arc};
pub type ExploreSetup = Arc<dyn Fn(&BookSource) -> LegadoResult<String> + Send + Sync>;
pub struct ExploreResources {
    pub js: Arc<legado_js::JsResources>,
    pub info: Arc<SourceInfoMap>,
    pub tasks: TaskGroup,
    pub runtime: tokio::runtime::Handle,
    pub setup: ExploreSetup,
}
pub struct ExploreService {
    resources: ExploreResources,
}
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ExploreEvalActionResult {
    pub raw: String,
    pub actions: Vec<serde_json::Value>,
    pub refresh_explore: bool,
}
impl ExploreService {
    pub fn new(resources: ExploreResources) -> Self {
        Self { resources }
    }
    pub fn info_map_put(&self, source: &str, key: &str, value: &str) -> LegadoResult<()> {
        self.resources.info.put(source, key, value);
        Ok(())
    }
    pub fn info_map_ensure_default(
        &self,
        source: &str,
        key: &str,
        value: &str,
    ) -> LegadoResult<()> {
        self.resources.info.ensure_default(source, key, value);
        Ok(())
    }
    pub fn info_map_snapshot(&self, source: &str) -> HashMap<String, String> {
        self.resources.info.snapshot(source)
    }
    #[cfg(feature = "quickjs")]
    fn fresh_engine(
        &self,
        tag: &str,
    ) -> LegadoResult<Arc<std::sync::Mutex<legado_js::QuickJsEngine>>> {
        let engine = self
            .resources
            .js
            .for_source("source", tag, "")
            .create_engine(
                legado_js::sandbox::SandboxConfig::default()
                    .with_allow_script_run(true)
                    .with_memory_limit(64 * 1024 * 1024),
            )?;
        Ok(Arc::new(std::sync::Mutex::new(engine)))
    }
    pub fn explore_eval_action_result(
        &self,
        source: &BookSource,
        action_js: &str,
    ) -> LegadoResult<ExploreEvalActionResult> {
        #[cfg(feature = "quickjs")]
        {
            let result = self.eval_explore_action_js(action_js, source)?;
            Ok(result)
        }
        #[cfg(not(feature = "quickjs"))]
        {
            let _ = (action_js, source);
            Err(LegadoError::JsEngine(
                "QuickJS engine not enabled. Build with --features quickjs".into(),
            ))
        }
    }
    pub fn explore_eval_ui_js(&self, source: &BookSource, js_str: &str) -> LegadoResult<String> {
        #[cfg(feature = "quickjs")]
        {
            self.eval_explore_ui_js(js_str, source)
        }
        #[cfg(not(feature = "quickjs"))]
        {
            let _ = (js_str, source);
            Err(LegadoError::JsEngine(
                "QuickJS engine not enabled. Build with --features quickjs".into(),
            ))
        }
    }
    pub fn explore_parse_url_entity(
        &self,
        explore_url: &str,
        source: Option<BookSource>,
    ) -> LegadoResult<Vec<ExploreCategory>> {
        let rule_str = self.resolve_explore_rule_str(explore_url, source.as_ref())?;
        let categories: Vec<ExploreCategory> = parse_explore_url(&rule_str);
        if let Some(src) = source.as_ref() {
            self.init_info_map_defaults(&src.book_source_url, &categories);
        }
        Ok(categories)
    }
    fn init_info_map_defaults(&self, source_url: &str, categories: &[ExploreCategory]) {
        for cat in categories {
            if cat.r#type != "toggle" && cat.r#type != "select" {
                continue;
            }
            let chars: Vec<&str> = cat
                .chars
                .as_ref()
                .map(|list| {
                    list.iter()
                        .filter_map(|v| v.as_deref())
                        .filter(|s| !s.is_empty())
                        .collect()
                })
                .unwrap_or_default();
            if chars.is_empty() {
                continue;
            }
            let default = cat
                .default_value
                .as_deref()
                .filter(|s| !s.is_empty())
                .unwrap_or(chars[0]);
            if let Err(e) = self.info_map_ensure_default(source_url, &cat.title, default) {
                // 仅落库失败告警：内存态已写入，发现页默认值仍可用
                log::warn!("发现页默认值未落库（内存态不受影响）: {e}");
            }
        }
    }
    pub fn explore_fetch_books_entity_with_deps(
        &self,
        source: BookSource,
        url: &str,
        page: i32,
        deps: legado_fetcher::deps::FetcherDeps,
        info_map: HashMap<String, String>,
        task: Option<TaskHandle>,
    ) -> LegadoResult<Vec<WebSearchResult>> {
        if url.is_empty() {
            return Err(LegadoError::Internal("发现分类 URL 为空".into()));
        }
        // P1-2 入口收口：发现页执行 ruleExplore（JS 书源 orchestrator / 规则
        // 书源 fresh_engine，变量桥读写）→ 先切 flow scope（键 =
        // explore:{书源 URL}，与 webbook_search 的 search:{书源 URL} 同族），
        // 防上一流程残留 scope 串读/误清。单源单流程调用（无并发各源），
        // 逐源键安全

        // JS 书源分派：spawn_blocking 避免嵌套 runtime 死锁（R1）
        if source.is_js_source() {
            let source_clone = source.clone();
            let url_clone = url.to_string();
            let js = deps.js.clone();
            let values = self.resources.runtime.block_on(async {
                tokio::task::spawn_blocking(move || {
                    let _task = task;
                    let mut orchestrator = legado_fetcher::web_book::build_js_orchestrator(
                        &js.for_source("explore", &source_clone.book_source_url, &url_clone),
                        &source_clone,
                    )?
                    .ok_or_else(|| LegadoError::Internal("JS 书源缺少 mainJs".into()))?;
                    orchestrator.explore(&source_clone, &url_clone, page)
                })
                .await
                .map_err(|e| LegadoError::Internal(format!("JS 发现任务异常: {e}")))?
            })?;
            let results = legado_fetcher::web_book::convert_js_search_results(
                values,
                &source.book_source_url,
            );
            return Ok(results);
        }

        // 规则书源路径
        let results: Vec<WebSearchResult> = self.resources.runtime.block_on(async {
            legado_fetcher::explore::explore_books_async(&source, url, page, &deps, &info_map).await
        })?;

        Ok(results)
    }
    fn resolve_explore_rule_str(
        &self,
        explore_url: &str,
        source: Option<&BookSource>,
    ) -> LegadoResult<String> {
        let trimmed = explore_url.trim();
        if trimmed.is_empty() {
            return Ok(String::new());
        }

        let lower = trimmed.to_ascii_lowercase();
        if lower.starts_with("@js:") {
            let js_code = trimmed.get(4..).unwrap_or("").trim();
            if js_code.is_empty() {
                return Ok(String::new());
            }
            let source = match source.cloned() {
                Some(s) => s,
                None => {
                    return Err(LegadoError::Internal(
                        "@js: exploreUrl 需要书源 JSON 上下文".into(),
                    ));
                }
            };
            return self.eval_explore_js(js_code, &source);
        }

        if lower.starts_with("<js>") {
            let js_code = extract_js_tag_body(trimmed);
            if js_code.is_empty() {
                return Ok(String::new());
            }
            let source = match source.cloned() {
                Some(s) => s,
                None => {
                    return Err(LegadoError::Internal(
                        "@js: exploreUrl 需要书源 JSON 上下文".into(),
                    ));
                }
            };
            return self.eval_explore_js(&js_code, &source);
        }

        Ok(trimmed.to_string())
    }

    #[cfg(feature = "quickjs")]
    pub fn eval_explore_js(&self, js_code: &str, source: &BookSource) -> LegadoResult<String> {
        use legado_js::JsEngine;
        use legado_js::host_api::current_source::with_current_source_tag;

        let tag = source.book_source_url.clone();
        let engine = self.fresh_engine(&tag)?;
        let guard = engine
            .lock()
            .map_err(|e| LegadoError::JsEngine(format!("JS 引擎加锁失败: {e}")))?;

        with_current_source_tag(&tag, || {
            self.bootstrap_explore_js_context(&guard, source)?;

            let encoded = serde_json::to_string(js_code)
                .map_err(|e| LegadoError::JsEngine(format!("exploreUrl 脚本编码失败: {e}")))?;
            // 执行方式对齐 Android Rhino 的 this 语义（书山聚合等聚合源 ERROR 根治）：
            // - rquickjs ctx.eval 为严格模式，裸调用函数 this=undefined，
            //   书山 jsLib 函数常用 `let { source } = this` → Cannot convert...；
            // - `new Function` 构造体非严格：代码经**参数**传入（避免字符串转义
            //   拼接问题），函数体内直接 eval → 非严格 → 裸调用函数
            //   this=globalThis（var source/java 已挂全局）✅；
            // - `getConfig.call(this)` 显式调用 this=全局，source 可用 ✅。
            // — DeepSeek Harness + Bridge（发现页修复）
            let wrapped = format!(
                r#"new Function('__legadoCode', 'var __r = eval(__legadoCode); if (__r === null || __r === undefined) return ""; if (typeof __r === "string") return String(__r).trim(); try {{ return JSON.stringify(__r); }} catch (e) {{ return String(__r); }}')({encoded})"#,
                encoded = encoded
            );

            let result = guard
                .eval(&wrapped)
                .map_err(|e| LegadoError::JsEngine(format!("exploreUrl JS 执行失败: {e}")))?;

            self.sync_info_map_from_js(&guard, &tag)?;

            Ok(result.trim().to_string())
        })
    }

    #[cfg(feature = "quickjs")]
    fn bootstrap_explore_js_context(
        &self,
        guard: &legado_js::QuickJsEngine,
        source: &BookSource,
    ) -> LegadoResult<()> {
        use legado_js::JsEngine;

        legado_fetcher::explore_js::load_js_lib_for_explore(
            guard,
            source.book_source_url.as_str(),
            source.js_lib.as_deref(),
        );

        // JS 单文件书源：exploreUrl @js: 常调用 mainJs 内定义的函数
        if source.is_js_source()
            && let Some(main_js) = source.main_js.as_deref()
        {
            let main_js = main_js.trim();
            if !main_js.is_empty()
                && let Err(e) = guard.eval(main_js)
            {
                eprintln!("[explore] mainJs 加载失败: {e}");
                return Err(LegadoError::JsEngine(format!(
                    "exploreUrl mainJs 加载失败: {e}"
                )));
            }
        }

        let setup = (self.resources.setup)(source)?;
        if let Err(e) = guard.eval(&setup) {
            return Err(LegadoError::JsEngine(format!(
                "exploreUrl 上下文初始化失败: {e}"
            )));
        }
        Ok(())
    }

    #[cfg(feature = "quickjs")]
    fn sync_info_map_from_js(
        &self,
        guard: &legado_js::QuickJsEngine,
        source_url: &str,
    ) -> LegadoResult<()> {
        use legado_js::JsEngine;
        let sync_script = r#"
(function() {
  try {
    if (typeof infoMap !== 'object' || infoMap === null) return '{}';
    var out = {};
    for (var k in infoMap) {
      if (!Object.prototype.hasOwnProperty.call(infoMap, k)) continue;
      if (typeof infoMap[k] === 'function') continue;
      out[k] = String(infoMap[k]);
    }
    return JSON.stringify(out);
  } catch (e) {
    return '{}';
  }
})()
"#;
        let json = guard
            .eval(sync_script)
            .map_err(|e| LegadoError::JsEngine(format!("infoMap 同步失败: {e}")))?;
        let map: std::collections::HashMap<String, String> =
            serde_json::from_str(json.trim()).unwrap_or_default();
        for (k, v) in map {
            let _ = self.info_map_put(source_url, &k, &v);
        }
        Ok(())
    }

    #[cfg(feature = "quickjs")]
    fn eval_explore_action_js(
        &self,
        action_js: &str,
        source: &BookSource,
    ) -> LegadoResult<ExploreEvalActionResult> {
        use legado_js::JsEngine;
        use legado_js::host_api::current_source::with_current_source_tag;
        use legado_js::host_api::ui_action_queue;

        let task = self
            .resources
            .tasks
            .begin()
            .map_err(|e| LegadoError::Ffi(e.to_string()))?;
        let _guard = task.guard();

        let tag = source.book_source_url.clone();
        let engine = self.fresh_engine(&tag)?;
        let guard = engine
            .lock()
            .map_err(|e| LegadoError::JsEngine(format!("JS 引擎加锁失败: {e}")))?;

        let collected = ui_action_queue::collect_actions(|| {
            with_current_source_tag(&tag, || {
                self.bootstrap_explore_js_context(&guard, source)?;
                let raw = guard.eval(action_js).map_err(|e| {
                    LegadoError::JsEngine(format!("explore action JS 执行失败: {e}"))
                })?;
                task.with_active(|| self.sync_info_map_from_js(&guard, &tag))
                    .unwrap_or_else(|| Err(LegadoError::Ffi("发现页动作已取消".into())))?;
                Ok::<_, LegadoError>(raw)
            })
        });
        let raw = collected.result?;
        task.with_active(|| {
            Ok(ExploreEvalActionResult {
                raw,
                actions: collected.actions,
                refresh_explore: collected.refresh_explore,
            })
        })
        .unwrap_or_else(|| Err(LegadoError::Ffi("发现页动作已取消".into())))
    }

    #[cfg(feature = "quickjs")]
    fn eval_explore_ui_js(&self, js_str: &str, source: &BookSource) -> LegadoResult<String> {
        use legado_js::JsEngine;
        use legado_js::host_api::current_source::with_current_source_tag;

        let tag = source.book_source_url.clone();
        let engine = self.fresh_engine(&tag)?;
        let guard = engine
            .lock()
            .map_err(|e| LegadoError::JsEngine(format!("JS 引擎加锁失败: {e}")))?;

        with_current_source_tag(&tag, || {
            self.bootstrap_explore_js_context(&guard, source)?;

            guard
                .eval(js_str)
                .map(|s| s.trim().to_string())
                .map_err(|e| LegadoError::JsEngine(format!("explore ui JS 执行失败: {e}")))
        })
    }

    #[cfg(not(feature = "quickjs"))]
    pub fn eval_explore_js(&self, _js_code: &str, _source: &BookSource) -> LegadoResult<String> {
        Err(LegadoError::JsEngine(
            "QuickJS engine not enabled. Build with --features quickjs".into(),
        ))
    }
}

fn extract_js_tag_body(s: &str) -> String {
    let lower = s.to_ascii_lowercase();
    if let Some(start) = lower.find("<js>") {
        let content_start = start + "<js>".len();
        if let Some(end) = lower.rfind("</js>")
            && end >= content_start
        {
            return s[content_start..end].trim().to_string();
        }
        return s[content_start..].trim().to_string();
    }
    String::new()
}

#[cfg(test)]
mod tests;
