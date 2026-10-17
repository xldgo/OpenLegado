//! 目录刷新前钩子，复用所属服务的精搜和详情能力。
use super::*;

impl ReadingService {
    pub fn run_pre_update_js(&self, source: &BookSource, book: &mut Book) -> LegadoResult<()> {
        let Some(js) = source
            .rule_toc
            .as_ref()
            .and_then(|t| t.pre_update_js.as_deref())
            .map(str::trim)
            .filter(|s| !s.is_empty())
        else {
            return Ok(());
        };

        #[cfg(feature = "quickjs")]
        {
            self.run_pre_update_js_inner(source, book, js)
        }

        #[cfg(not(feature = "quickjs"))]
        {
            let _ = (js, source, book);
            Ok(())
        }
    }
}

#[cfg(feature = "quickjs")]
impl ReadingService {
    pub(super) fn run_pre_update_js_inner(
        &self,
        source: &BookSource,
        book: &mut Book,
        js: &str,
    ) -> LegadoResult<()> {
        use std::sync::{Arc, Mutex};

        use legado_core::LegadoError;
        use legado_parser::JsExecutor;

        let book_cell = Arc::new(Mutex::new(book.clone()));
        let source_owned = source.clone();

        let re_get: legado_js::host_api::pre_update_hooks::PreUpdateHook = {
            let book_cell = Arc::clone(&book_cell);
            let source = source_owned.clone();
            let service = self.clone();
            Arc::new(Mutex::new(move || {
                let mut b = book_cell.lock().map_err(|_| "book 锁失败".to_string())?;
                service
                    .re_get_book_native(&source, &mut b)
                    .map_err(|e| e.to_string())?;
                serde_json::to_string(&*b).map_err(|e| e.to_string())
            }))
        };

        let refresh: legado_js::host_api::pre_update_hooks::PreUpdateHook = {
            let book_cell = Arc::clone(&book_cell);
            let source = source_owned.clone();
            let service = self.clone();
            Arc::new(Mutex::new(move || {
                let mut b = book_cell.lock().map_err(|_| "book 锁失败".to_string())?;
                service
                    .refresh_toc_url_native(&source, &mut b)
                    .map_err(|e| e.to_string())?;
                serde_json::to_string(&*b).map_err(|e| e.to_string())
            }))
        };

        let book_json = serde_json::to_string(book).unwrap_or_else(|_| "{}".into());
        let source_json = serde_json::to_string(&source.book_source_url).unwrap_or_default();
        let wrapped = format!(
            "globalThis.book = {book_json};\n\
         globalThis.source = {source_json};\n\
         globalThis.fromBookInfo = false;\n\
         {js};\n\
         JSON.stringify(book);"
        );

        let executor = legado_js::executor::QuickJsExecutor::new(&source.book_source_url)
            .with_resources(
                self.resources
                    .js
                    .for_book(&source.book_source_url, &book.book_url),
            )
            .with_js_lib(source.js_lib.clone());

        let eval_out = legado_js::host_api::pre_update_hooks::with_hooks(re_get, refresh, || {
            executor.execute_js(&wrapped)
        })
        .map_err(|e| {
            LegadoError::JsEngine(format!(
                "执行preUpdateJs规则失败 书源:{}: {e}",
                source.book_source_name
            ))
        })?;

        // 优先采用 JS 侧最终 book；失败则回退钩子已写入的 book_cell
        if let Ok(updated) = serde_json::from_str::<Book>(&eval_out) {
            *book = updated;
        } else {
            if let Ok(guard) = book_cell.lock() {
                *book = guard.clone();
            }
        }
        Ok(())
    }
}

#[cfg(feature = "quickjs")]
impl ReadingService {
    pub(super) fn re_get_book_native(
        &self,
        source: &BookSource,
        book: &mut Book,
    ) -> LegadoResult<()> {
        let hit = self.resources.search.precise_search_selected(
            &book.name,
            &book.author,
            std::slice::from_ref(&source.book_source_url),
        )?;
        if !hit.book_url.is_empty() {
            book.origin_book_url = hit.book_url;
        }
        if let Some(var) = hit.variable.filter(|v| !v.is_empty()) {
            book.variable = Some(var);
        }
        self.refresh_toc_url_native(source, book)
    }
}

#[cfg(feature = "quickjs")]
impl ReadingService {
    pub(super) fn refresh_toc_url_native(
        &self,
        source: &BookSource,
        book: &mut Book,
    ) -> LegadoResult<()> {
        // P1-2 入口收口：本钩子执行 ruleBookInfo（JS 变量桥读写）→ 先切
        // flow scope（键 = 书籍页取址点 originBookUrl 优先、回退 bookUrl，
        // 与 webbook_info 的 book_url 键同族），防上一流程残留 scope 串读/误清。
        // reGetBook 钩子（re_get_book_native）经 precise_search 后落到本函数
        // 收口；precise_search 自身不加 begin（mid-flow 调用方，见其文档）。
        let engine = legado_fetcher::web_book::RealBookSourceFetcher::with_deps(
            self.deps_for_book(&source.book_source_url, &book.book_url)?,
        );
        // [P2-8] 取址：优先 originBookUrl（当前书源详情页），为空回退 bookUrl
        let fetch_url = book.book_page_fetch_url();
        let info = self.resources.runtime.block_on(async {
            legado_core::web_book::BookSourceFetcher::get_book_info(&engine, source, fetch_url)
                .await
        })?;
        apply_web_info_to_book(book, &info);
        Ok(())
    }
}

#[cfg(feature = "quickjs")]
pub fn apply_web_info_to_book(book: &mut Book, info: &legado_core::web_book::WebBookInfo) {
    if !info.toc_url.is_empty() {
        book.toc_url = info.toc_url.clone();
    }
    if !info.name.is_empty() {
        book.name = info.name.clone();
    }
    if !info.author.is_empty() {
        book.author = info.author.clone();
    }
    if let Some(ref cover) = info.cover_url {
        book.cover_url = Some(cover.clone());
    }
    if let Some(ref intro) = info.intro {
        book.intro = Some(intro.clone());
    }
    if let Some(ref kind) = info.kind {
        book.kind = Some(kind.clone());
    }
}
