//! 发现列表请求与解析，共用已捕获FetcherDeps。
use legado_core::{LegadoError, LegadoResult, models::BookSource, web_book::WebSearchResult};
use legado_parser::AnalyzeUrl;
use std::collections::HashMap;

pub async fn explore_books_async(
    source: &BookSource,
    url: &str,
    page: i32,
    deps: &crate::deps::FetcherDeps,
    info_map: &HashMap<String, String>,
) -> LegadoResult<Vec<WebSearchResult>> {
    let resources = deps.js.for_source("explore", &source.book_source_url, url);
    // 解析书源 header（对齐原版 getHeaderMap(hasLoginHeader=true)：
    // 静态 header + loginHeader 覆盖；JS setCookie cookie 改按**请求 URL 属域**
    // 在下方合并请求头时兜底注入，见 2026-09-23 上游同步）— DeepSeek Harness + Bridge
    let mut source_headers: HashMap<String, String> = source
        .header
        .as_ref()
        .and_then(|h| serde_json::from_str(h).ok())
        .unwrap_or_default();
    if let Some(login_header_json) = deps
        .login_header
        .as_ref()
        .and_then(|lookup| lookup(&source.book_source_url))
        && let Ok(map) = serde_json::from_str::<HashMap<String, String>>(&login_header_json)
    {
        source_headers.extend(map);
    }
    let source_headers = if source_headers.is_empty() {
        None
    } else {
        Some(source_headers)
    };

    // 规则书源路径
    let analyze_url = crate::explore_url::build_explore_url_with_setup(
        &resources,
        url,
        page,
        source,
        info_map,
        deps.source_context.as_ref().and_then(|build| build(source)),
    )
    // 分类 URL 脚本执行失败上抛真实错误（懒人听书未配置会话时
    // lrtsResolveSession 抛「请先登录…」；此前静默回退字面量 URL
    // 导致 HTTP 404 误导用户）。提取最内层 JS 错误，去掉
    // Internal/URL 模板 等包装前缀与堆栈行，文案对齐原版提示。
    .map_err(|e| {
        let msg = e.to_string();
        let core = msg.rsplit("JS engine error: ").next().unwrap_or(&msg);
        // 取首行并去掉 JS 堆栈 `(at ...` 尾部，文案对齐原版提示
        let first_line = core.lines().next().unwrap_or(core).trim();
        let clean = first_line
            .split(" (at ")
            .next()
            .unwrap_or(first_line)
            .trim();
        LegadoError::Internal(format!("分类加载失败：{clean}"))
    })?;

    let final_url = analyze_url.url().to_string();
    if final_url.is_empty() {
        return Err(LegadoError::Internal("解析后发现 URL 为空".into()));
    }

    // data: URI（猫眼看书分类 URL 形态 `data:;base64,<b64>,{"type":"maoyankanshu"}`）
    // 一律本地解码、不进 reqwest——reqwest 不支持 data: 协议，直接发送会报
    // 「builder error for url (data:...)」（iOS 实机 15 号缺陷）。
    // 语义与 `web_book::fetch_page` / `fetch_simple_cached` 的 data URI 分支
    // 统一（单一实现 `crate::web_book::data_uri_content_of`，直接消费
    // 已解析 AnalyzeUrl 的 response_type：type 非空 → hex 编码字节，否则
    // UTF-8 文本）；本地解码无网络响应，status 按 200 参与后续 loginCheckJs 链路。
    let (response_body, response_url, response_status) =
        match crate::web_book::data_uri_content_of(&analyze_url) {
            Some(result) => {
                let body = result?;
                (body, final_url.clone(), 200)
            }
            None => {
                // 发起 HTTP 请求（复用进程共享客户端单例）
                let client = deps.client.clone();

                // 合并请求头：书源全局 header + AnalyzeUrl 解析出的 header
                let mut headers = source_headers.clone().unwrap_or_default();
                headers.extend(analyze_url.headers().clone());

                // JS `java.setCookie` 写入的 cookie：按**请求 URL**（解析后的 final_url）
                // 属域取——cookie 属于域名而非书源（同域跨书源共享，不相关域名绝不
                // 携带）；`cookies_for_url` 内部归一为 `getSubDomain(url)` 等价域名键
                // （单一真源 `legado_net::cookie_store::cookie_domain_key`）。**按键合并**
                // 进已有 Cookie 头（已有同名键胜、非冲突键追加；键查找大小写不敏感）
                // ——对齐上游 AnalyzeUrl.setCookie → CookieManager.mergeCookies 语义。
                let cookie = client
                    .cookie_store()
                    .read()
                    .unwrap_or_else(|p| p.into_inner())
                    .cookies_for_key(&final_url);
                legado_js::host_api::cookie_store::merge_cookie_string(&mut headers, &cookie);

                // 写侧 CookieJar 门控（批 2）：开启源补内部标记头（只补不覆盖；
                // 发送前由 legado-net 剥离、绝不出网）；读侧 cookie 注入不受影响。
                crate::web_book::apply_cookie_jar_marker(&mut headers, source);

                let headers_opt = if headers.is_empty() {
                    None
                } else {
                    Some(headers)
                };

                let response = client
                    .get(&final_url, headers_opt)
                    .await
                    .map_err(|e| LegadoError::Network(format!("请求发现页失败: {e}")))?;

                if !response.is_success() {
                    return Err(LegadoError::Network(format!(
                        "HTTP {} for {}",
                        response.status, final_url
                    )));
                }
                (response.body, response.url, response.status)
            }
        };

    // loginCheckJs 登录检测（对齐原版 WebBook.exploreBookAwait:148-172 的
    // `evalJS(checkJs, it) as StrResponse` 双路径 + 采用修改响应，与搜索链
    // web_book::RealBookSourceFetcher::execute_login_check 同构）：
    // - 完成值按 StrResponse 对象解析（裸布尔/字符串等 cast 失败走错误路径，
    //   不再降级放行）；
    // - 未登录上抛 LoginRequired，由 UI 引导登录，避免把登录页/验证页当
    //   正常内容解析；
    // - JS 修改后的响应（自动登录等场景）被采用：后续解析用 outcome.body/url
    //   （对齐原版 WebBook.kt:173-181 `analyzeBookList(baseUrl = res.url,
    //   body = res.body)`）。
    // — DeepSeek Harness + Bridge（2026-08-14 发现页修复 R3）
    // — full-stack-engineer + Bridge（STAGE4-P36 语义对齐 F1 三叉点）
    let login_outcome = crate::web_book::RealBookSourceFetcher::execute_login_check(
        &resources,
        source,
        &response_body,
        &response_url,
        response_status,
    )?;

    let body = login_outcome.body;

    // 对齐原版 BookList：explore.bookList 为空时回退 search 规则
    let explore_rule = source.rule_explore.as_ref();
    let search_rule = source.rule_search.as_ref();
    let use_search_fallback = explore_rule
        .and_then(|r| r.book_list.as_deref())
        .unwrap_or("")
        .is_empty();

    let book_list_rule = if use_search_fallback {
        search_rule
            .and_then(|r| r.book_list.as_deref())
            .unwrap_or("")
    } else {
        explore_rule
            .and_then(|r| r.book_list.as_deref())
            .unwrap_or("")
    };

    // `-`/`+` 前缀（对齐原版 BookList.kt:90-96）：`-` 反转结果、`+` 剥离前缀 — A6
    let mut reverse = false;
    let mut book_list_rule = book_list_rule.to_string();
    if book_list_rule.starts_with('-') {
        reverse = true;
        book_list_rule = book_list_rule[1..].to_string();
    } else if book_list_rule.starts_with('+') {
        book_list_rule = book_list_rule[1..].to_string();
    }

    // 重定向后的最终 URL 作为 base（对齐原版 WebBook.kt:173-181 用 res.url；
    // STAGE4-P36：采用 loginCheckJs 修改后的 outcome.url——原版 res.url 即
    // check 后的 StrResponse.url）— A5
    let base_url = login_outcome.url.clone();
    let t_parse = std::time::Instant::now();

    // 书山聚合等聚合源 bookList `<js>` 脚本依赖 jsLib 函数（getSessionId 等）与
    // 书源上下文（source/cookie）；注入 sanitize 后的 jsLib + setup（对齐
    // bootstrap_explore_js_context 的加载策略）。此前 analyzer 无 jsLib →
    // getSessionId ReferenceError → 空列表「暂无书籍」。— DeepSeek Harness + Bridge
    let js_lib_sanitized = source
        .js_lib
        .as_deref()
        .map(crate::js_adapter::sanitize_js_lib_for_quickjs);
    let explore_setup = deps.source_context.as_ref().and_then(|build| build(source));
    // P2-11 ①：src = 发现响应体（explore 顶层分析器；单参 java.* 回退重解析
    // 原始 body——对齐搜索路径 bind_orig_src 约定（web_book.rs L1269-1279）与
    // 上游 AnalyzeRule.kt L904 `bindings["src"] = content`（this.content 不被
    // 规则链更新，多步链子步单参 java.* 仍重解析顶层原始响应体；此前 explore
    // 链式 JS 的 src 为中间产物，P2-11 §194 残差）
    let body_src_json = serde_json::to_string(&body).unwrap_or_default();
    let analyzer = crate::js_adapter::construct_analyzer_with_source_context(
        &resources,
        body,
        base_url.clone(),
        &source.book_source_url,
        js_lib_sanitized.as_deref(),
        explore_setup.clone(),
    );
    let analyzer = with_explore_top_bindings(analyzer, &body_src_json);

    let elements = if book_list_rule.is_empty() {
        vec![analyzer.content().to_string()]
    } else {
        analyzer.get_elements(&book_list_rule).unwrap_or_default()
    };

    // 规则提到循环外；单一 AnalyzeRule + setContent 复用（对齐原版 BookList）
    let name_rule = if use_search_fallback {
        search_rule.and_then(|r| r.name.as_deref()).unwrap_or("")
    } else {
        explore_rule.and_then(|r| r.name.as_deref()).unwrap_or("")
    };
    let author_rule = if use_search_fallback {
        search_rule.and_then(|r| r.author.as_deref()).unwrap_or("")
    } else {
        explore_rule.and_then(|r| r.author.as_deref()).unwrap_or("")
    };
    let book_url_rule = if use_search_fallback {
        search_rule
            .and_then(|r| r.book_url.as_deref())
            .unwrap_or("")
    } else {
        explore_rule
            .and_then(|r| r.book_url.as_deref())
            .unwrap_or("")
    };
    let cover_url_rule = if use_search_fallback {
        search_rule
            .and_then(|r| r.cover_url.as_deref())
            .unwrap_or("")
    } else {
        explore_rule
            .and_then(|r| r.cover_url.as_deref())
            .unwrap_or("")
    };
    let intro_rule = if use_search_fallback {
        search_rule.and_then(|r| r.intro.as_deref()).unwrap_or("")
    } else {
        explore_rule.and_then(|r| r.intro.as_deref()).unwrap_or("")
    };
    let last_chapter_rule = if use_search_fallback {
        search_rule
            .and_then(|r| r.last_chapter.as_deref())
            .unwrap_or("")
    } else {
        explore_rule
            .and_then(|r| r.last_chapter.as_deref())
            .unwrap_or("")
    };
    let kind_rule = if use_search_fallback {
        search_rule.and_then(|r| r.kind.as_deref()).unwrap_or("")
    } else {
        explore_rule.and_then(|r| r.kind.as_deref()).unwrap_or("")
    };
    let word_count_rule = if use_search_fallback {
        search_rule
            .and_then(|r| r.word_count.as_deref())
            .unwrap_or("")
    } else {
        explore_rule
            .and_then(|r| r.word_count.as_deref())
            .unwrap_or("")
    };

    let mut elem_analyzer = crate::js_adapter::construct_analyzer_with_source_context(
        &resources,
        String::new(),
        base_url.clone(),
        &source.book_source_url,
        js_lib_sanitized.as_deref(),
        explore_setup,
    );

    // A9：列表规则无命中时回退按详情页单本解析（对齐原版 BookList.kt:100-108
    // collections 空 → getInfoItem 用 ruleBookInfo 整页解析；详情页直连场景）
    if elements.is_empty() {
        if let Some(book) = parse_explore_as_single_book(source, &analyzer, &base_url) {
            return Ok(vec![book]);
        }
        return Ok(Vec::new());
    }

    let mut results = Vec::with_capacity(elements.len().min(50));
    for elem in elements.iter() {
        // 列表元素按结构化对象写入（JSON 元素 → result 注入为对象，
        // 书山 bookUrl `result.source` 等属性访问依赖；HTML 元素自动
        // 回退字符串）— DeepSeek Harness + Bridge
        elem_analyzer.set_element_content(elem.clone());

        let name = elem_analyzer.get_string(name_rule).unwrap_or_default();
        if name.is_empty() {
            continue;
        }
        // 书名/作者清洗（对齐原版 BookHelp.formatBookName/formatBookAuthor）— A2
        let name = format_book_name(&name);
        if name.is_empty() {
            continue;
        }
        let author = format_book_author(&elem_analyzer.get_string(author_rule).unwrap_or_default());
        let book_url_raw = elem_analyzer.get_string(book_url_rule).unwrap_or_default();
        // bookUrl 规则解析为空时回退当前页（对齐原版 BookList.kt:282-284 +
        // AnalyzeRule.kt:369-375 的 isUrl=true 空值回退 baseUrl；与 search.rs:934-938 一致）— A4
        let book_url = if book_url_raw.is_empty() {
            base_url.clone()
        } else {
            AnalyzeUrl::get_absolute_url(&base_url, &book_url_raw)
        };
        let cover_url = {
            let v = elem_analyzer.get_string(cover_url_rule).unwrap_or_default();
            if v.is_empty() {
                None
            } else {
                Some(AnalyzeUrl::get_absolute_url(&base_url, &v))
            }
        };
        let intro = {
            let v = elem_analyzer.get_string(intro_rule).unwrap_or_default();
            if v.is_empty() {
                None
            } else {
                // 简介净化（对齐原版 HtmlFormatter.formatIntro 去标签）— A3
                Some(format_intro(&v))
            }
        };
        let latest_chapter = {
            let v = elem_analyzer
                .get_string(last_chapter_rule)
                .unwrap_or_default();
            if v.is_empty() { None } else { Some(v) }
        };
        let kind = {
            let v = elem_analyzer.get_string(kind_rule).unwrap_or_default();
            if v.is_empty() {
                None
            } else {
                legado_core::book_help::normalize_book_kind(&v)
            }
        };

        // 字数格式化（对齐原版 wordCountFormat；与搜索路径一致）— A7
        let word_count = {
            let v = elem_analyzer
                .get_string(word_count_rule)
                .unwrap_or_default();
            legado_core::book_help::format_book_word_count(&v)
        };

        results.push(WebSearchResult {
            name,
            author,
            book_url,
            cover_url,
            intro,
            latest_chapter,
            source_url: source.book_source_url.clone(),
            kind,
            word_count,
            // 书籍类型位标记（对齐原版 BookType；漫画/听书/视频源分流）— A8
            book_type: crate::book_type::book_type_of_source(source.book_source_type),
        });
    }
    // `-` 前缀反转（对齐原版 BookList.kt:145-147）— A6
    if reverse {
        results.reverse();
    }
    eprintln!(
        "[explore] parse {} books from {} elements in {:?}",
        results.len(),
        elements.len(),
        t_parse.elapsed()
    );

    Ok(results)
}

pub fn with_explore_top_bindings(
    analyzer: legado_parser::AnalyzeRule,
    body_src_json: &str,
) -> legado_parser::AnalyzeRule {
    analyzer
        .with_js_binding("src", body_src_json)
        .with_js_binding("book", "null")
}

pub fn parse_explore_as_single_book(
    source: &BookSource,
    analyzer: &legado_parser::AnalyzeRule,
    base_url: &str,
) -> Option<WebSearchResult> {
    let info_rule = source.rule_book_info.as_ref()?;
    let rule_name = info_rule.name.as_deref().unwrap_or("");
    let rule_author = info_rule.author.as_deref().unwrap_or("");
    let rule_cover = info_rule.cover_url.as_deref().unwrap_or("");
    let rule_intro = info_rule.intro.as_deref().unwrap_or("");
    let rule_kind = info_rule.kind.as_deref().unwrap_or("");
    let rule_word_count = info_rule.word_count.as_deref().unwrap_or("");

    let name = format_book_name(&analyzer.get_string(rule_name).unwrap_or_default());
    if name.is_empty() {
        return None;
    }
    let author = format_book_author(&analyzer.get_string(rule_author).unwrap_or_default());
    // BookInfoRule 无 bookUrl 字段：详情页直连场景 bookUrl 即当前页 URL
    //（对齐原版 BookList.getInfoItem 空规则回退 baseUrl）— A9
    let book_url = base_url.to_string();
    let cover_url = {
        let v = analyzer.get_string(rule_cover).unwrap_or_default();
        if v.is_empty() {
            None
        } else {
            Some(AnalyzeUrl::get_absolute_url(base_url, &v))
        }
    };
    let intro = {
        let v = analyzer.get_string(rule_intro).unwrap_or_default();
        if v.is_empty() {
            None
        } else {
            Some(format_intro(&v))
        }
    };
    let kind = {
        let v = analyzer.get_string(rule_kind).unwrap_or_default();
        if v.is_empty() {
            None
        } else {
            legado_core::book_help::normalize_book_kind(&v)
        }
    };
    let word_count = legado_core::book_help::format_book_word_count(
        &analyzer.get_string(rule_word_count).unwrap_or_default(),
    );

    Some(WebSearchResult {
        name,
        author,
        book_url,
        cover_url,
        intro,
        latest_chapter: None,
        source_url: source.book_source_url.clone(),
        kind,
        word_count,
        book_type: crate::book_type::book_type_of_source(source.book_source_type),
    })
}

pub fn format_book_name(name: &str) -> String {
    legado_core::book_help::format_book_name(name)
}

pub fn format_book_author(author: &str) -> String {
    legado_core::book_help::format_book_author(author)
}

pub fn format_intro(raw: &str) -> String {
    if raw.is_empty() {
        return String::new();
    }
    // 去标签（含 <br>/<p> 等块级转空格）
    let no_tag = regex::Regex::new(r"<[^>]+>")
        .map(|re| re.replace_all(raw, " ").into_owned())
        .unwrap_or_else(|_| raw.to_string());
    // 常见实体解码
    let decoded = no_tag
        .replace("&nbsp;", " ")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&#39;", "'");
    // 压缩空白
    decoded.split_whitespace().collect::<Vec<_>>().join(" ")
}
