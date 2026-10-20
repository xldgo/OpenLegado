//! 单源请求、JS执行和搜索结果解析，复用Fetcher底层能力。
use super::*;
pub use legado_core::book_help::format_book_word_count as word_count_format;
pub use legado_fetcher::book_type::book_type_of_source;
use legado_fetcher::web_book::book_list_elements_or_default;
use legado_net::client::DEFAULT_USER_AGENT;

pub async fn search_single_source_owned(
    context: SearchContext,
    source: &BookSource,
    keyword: &str,
    page: i32,
    precision: bool,
) -> LegadoResult<Vec<SearchResult>> {
    let task = context.task.clone().expect("独立单源入口必须登记任务");
    let _guard = task.guard();
    let result = tokio::select! {
        biased;
        _ = task.cancelled() => return Err(search_cancelled()),
        result = search_single_source_with_context(&context, source, keyword, page, precision) => result,
    };
    task.with_active(|| result)
        .unwrap_or_else(|| Err(search_cancelled()))
}

pub async fn search_single_source_with_context(
    context: &SearchContext,
    source: &BookSource,
    keyword: &str,
    page: i32,
    precision: bool,
) -> LegadoResult<Vec<SearchResult>> {
    context.ensure_active()?;
    let client = &context.deps.client;
    let resources = context
        .deps
        .js
        .for_source("search", &source.book_source_url, keyword);
    // G4：书源 concurrentRate 固定窗口节流（对齐 Kotlin ConcurrentRateLimiter）
    context.deps.rate_limiter.acquire(source).await;
    context.ensure_active()?;

    // 阶段计时诊断（LEGADO_SEARCH_PHASE_TIMING=1）：定位单源 30s 超时挂起阶段
    let phase_on = std::env::var("LEGADO_SEARCH_PHASE_TIMING").is_ok();
    let t_phase = std::time::Instant::now();
    // JS 书源分派
    if source.is_js_source() {
        let mut results = search_js_source(context, source, keyword, page).await?;
        context.ensure_active()?;
        // [审计 D4 | WebBook.kt:47 + JsSourceBook.kt:29-37] 原版把 precision
        // filter 传入 JsSourceBook.searchAwait，JS 源结果同样受三字段"或"
        // 语义约束，不得绕过
        results.retain(|r| {
            precision_filter_match(
                precision,
                keyword,
                &r.book_name,
                &r.author,
                r.kind.as_deref(),
            )
        });
        return Ok(results);
    }

    // 队列④ P1-A 复审：删除 jsLib 预校验——「存在任意 JS 语法」≠「搜索依赖
    // jsLib」，口径过宽会误伤纯 CSS 规则 + `{{key}}` 字面插值的书源
    //（favcomic 夹具实证：改前可正常搜，改后预校验必失败 → 每关键词 0 结果）。
    // 能力缺失/JS 失败在真被使用时经既有路径给可读文案：searchUrl 失败 →
    // `legado-js-error://` 错误 URL 解码（P2-C）；bookList JS 失败 →
    // get_elements 上抛（P2-D）；jsLib 加载失败 → run_fresh 登记台账 +
    // 真 JS 求值时上抛。error_class 映射不变。

    // 1. 获取搜索 URL 模板
    let search_url_template = source
        .search_url
        .as_ref()
        .ok_or_else(|| LegadoError::Parser("书源未配置 searchUrl".into()))?;

    if search_url_template.is_empty() {
        return Err(LegadoError::Parser("书源 searchUrl 为空".into()));
    }

    // 2. 使用 AnalyzeUrl 构建请求（同步且可能执行 {{JS}} 表达式；
    //    移入阻塞线程：恶意/超长同步计算不会占住 tokio worker，
    //    保证单源超时能在 await 点生效，避免整体挂起）
    let template = search_url_template.clone();
    let key = keyword.to_string();
    let build_base = source.book_source_url.clone();
    let source_lib = source.js_lib.clone();
    // 书源上下文 setup：搜索模板 `{{source.getKey()}}` 等依赖 source/cookie
    // 绑定（爱下电子等源）——对齐原版 AnalyzeUrl.kt evalJS source 绑定
    let search_setup = context.deps.setup_script_for(source);
    let url_resources = resources.clone();
    let build_task = context.task.clone();
    let analyze_url = tokio::task::spawn_blocking(move || {
        let _task = build_task;
        legado_fetcher::js_adapter::build_search_url_with_setup(
            &url_resources,
            &template,
            &key,
            // 页码透传（批次B G-B-01）：原硬编码 page=1，现由调用方传入
            page,
            &build_base,
            source_lib.as_deref(),
            search_setup,
        )
    })
    .await
    .map_err(|e| LegadoError::Internal(format!("搜索 URL 构建任务异常: {e}")))?;
    context.ensure_active()?;
    if phase_on {
        eprintln!(
            "[phase] url_build={}ms src={}",
            t_phase.elapsed().as_millis(),
            source.book_source_url
        );
    }
    // 队列④ P2-C：必须用 rule_url() 判断/解码——analyze_url.url() 是经
    // get_absolute_url 拼到书源域名下的绝对 URL，`legado-js-error://` 这类
    // 非 http(s)/data/`/` 开头的自定义 scheme 会被当相对路径拼接而丢失
    // 前缀（见 analyze_url 单测 test_js_error_url_prefix_survives_in_rule_url），
    // 用 url() 判断的 guard 恒不命中（死码）
    if analyze_url.rule_url().starts_with("legado-js-error://") {
        // 解码错误 URL 还原真实 JS 错误文本，标注为 JsEngine
        // （error_class 仍为 js_error——classify_source_outcome 既有映射，
        // 契约不变；此前误标 Internal → parser_error）
        let detail = legado_fetcher::js_adapter::decode_js_error_url(analyze_url.rule_url())
            .map(|m| m.chars().take(160).collect::<String>());
        return Err(LegadoError::JsEngine(match detail {
            Some(d) if !d.is_empty() => format!("searchUrl JS 求值失败: {d}"),
            _ => "searchUrl JS 求值失败（无法解码错误详情）".into(),
        }));
    }

    // 3. 合并请求头：书源全局 header + AnalyzeUrl 提取的 header
    let mut headers = parse_header_option(source.header.as_deref()).unwrap_or_default();
    headers.extend(analyze_url.headers().clone());
    // [UI-fix 2026-08-10 | Reasonix] 对齐原版 BaseSource.kt:202-204 +
    // AppConfig.userAgent：书源未配置 UA 时补充 Chrome UA（默认 Legado/1.0
    // 会被反爬站点识别为非浏览器而拒绝/返回空列表）
    ensure_default_user_agent(&mut headers);
    // 写侧 CookieJar 门控（批 1）：开启源补内部标记头（只补不覆盖；
    // None/Some(false) 不补），发送前由 legado-net 剥离、绝不出网；
    // 读侧 DB cookie 注入由 legado-net 无条件完成，与此无关。
    legado_fetcher::web_book::apply_cookie_jar_marker(&mut headers, source);
    let headers_opt = if headers.is_empty() {
        None
    } else {
        Some(headers)
    };

    // 4. 发送 HTTP 请求
    // P2-19 尾项：统一走原始字节 + 四级解码入口（显式 charset → Content-Type →
    // HTML meta → chardetng 统计探测 → lossy UTF-8）。改前非 explicit 分支经
    // reqwest `.text()`（只认 Content-Type），meta-only / 无标识 GBK 页书名乱码；
    // 显式 charset 语义不变（入口内部最高优先），final_url/resp_code 仍取
    // raw.url/raw.status（与改前两分支逐字一致）。
    // [S0-E | AnalyzeUrl.kt:499-534] 对齐原版：不校验 HTTP 状态码，
    // 非 2xx 响应体仍进入解析（通常得空列表），仅日志留痕。
    // P2-19 批3：urlOption followRedirects / retry 经 fetcher 汇聚点发送
    //（send_raw 与 send_text 共用 send_with_options，两分支行为一致）。
    let raw = legado_fetcher::analyze_request::send_raw(client, &analyze_url, headers_opt).await?;
    // [P2-19 尾项审查 P1-1] 3xx 留痕：改前 raw（显式 charset）分支条件为
    // `!(200..300)`（3xx 亦留痕），文本分支 `!is_success()`（3xx 不留痕）；
    // 两分支统一 send_raw 后恢复 raw 分支的 3xx 可见性。审查单条件
    // `!(200..400)`（文案「非 2xx/3xx」）与其验收句「followRedirects=false 的
    // 302 应能看到日志」互斥（302 ∈ 200..400 会被静默），故拆两条：4xx/5xx 按
    // 建议口径留痕，未跟随/不可跟随的 3xx 单独留痕——合取等价于原 raw 分支
    // `!(200..300)` 的完整语义，登记为行为变化。
    if !(200..400).contains(&raw.status) {
        eprintln!(
            "[search] 非 2xx/3xx HTTP {} url={}",
            raw.status,
            analyze_url.url()
        );
    }
    if (300..400).contains(&raw.status) {
        eprintln!(
            "[search] 未跟随 3xx HTTP {} url={}",
            raw.status,
            analyze_url.url()
        );
    }
    let body = legado_fetcher::web_book::decode_web_response(
        &raw.body,
        &raw.headers,
        analyze_url.charset(),
    );
    let (final_url, resp_code) = (raw.url, raw.status);
    context.ensure_active()?;
    if phase_on {
        eprintln!(
            "[phase] http={}ms src={}",
            t_phase.elapsed().as_millis(),
            source.book_source_url
        );
    }

    // [S0-E | WebBook.kt:74-99] loginCheckJs：对齐原版 StrResponse 语义——检测
    // 结果是可被解析采用的响应对象（JS 可修改响应：自动登录返回新 body/url 等）；
    // 非对象返回值/执行失败 → errResponse(500) 二次 eval：仍 code 500 或 cast
    // 失败 → LoginRequired（整源失败；原版错误吞吐：单源失败静默不中断其他源）。
    // [WebBook.kt:100-111] 解析采用 login-check 返回的响应（baseUrl=res.url、
    // body=res.body）：bookUrlPattern 直连判定与相对 URL 绝对化均基于修改后 URL。
    let login_source = source.clone();
    let login_task = context.task.clone();
    let login_outcome = tokio::task::spawn_blocking(move || {
        let _task = login_task;
        legado_fetcher::web_book::RealBookSourceFetcher::execute_login_check(
            &resources,
            &login_source,
            &body,
            &final_url,
            resp_code,
        )
    })
    .await
    .map_err(|error| LegadoError::Internal(format!("搜索登录校验任务异常: {error}")))??;
    context.ensure_active()?;
    // [S0-D | 任务 B 2026-09-19；任务 A 2026-09-19 适配] login_check 段计时点
    //（env 门控 LEGADO_SEARCH_PHASE_TIMING）：已移至 login_check 调用之后，
    // 恢复段末累计语义（即 login_check 段结束时刻的累计耗时），输出携带会话
    // 标识 + 书源 URL（计划要求可关联）。
    if phase_on {
        let session_id = context.session_id();
        eprintln!(
            "[phase] login_check={}ms session={} src={}",
            t_phase.elapsed().as_millis(),
            session_id,
            source.book_source_url
        );
    }
    // 5. 使用 AnalyzeRule 解析搜索结果（同步解析同样移入阻塞线程，
    //    灾难性正则/超大页面不会阻塞 runtime，单源超时可中断）
    let source_clone = source.clone();
    let keyword_owned = keyword.to_string();
    let parse_body = login_outcome.body;
    let parse_url = login_outcome.url;
    let parse_context = context.clone();
    let parsed = tokio::task::spawn_blocking(move || {
        parse_search_response_with_context(
            &parse_context,
            &parse_body,
            &parse_url,
            &source_clone,
            precision,
            &keyword_owned,
        )
    })
    .await
    .map_err(|e| LegadoError::Internal(format!("搜索解析任务异常: {e}")))?;
    context.ensure_active()?;
    if phase_on {
        eprintln!(
            "[phase] total={}ms src={}",
            t_phase.elapsed().as_millis(),
            source.book_source_url
        );
    }
    parsed
}

pub fn parse_search_response_with_context(
    context: &SearchContext,
    body: &str,
    base_url: &str,
    source: &BookSource,
    precision: bool,
    key: &str,
) -> LegadoResult<Vec<SearchResult>> {
    let resources = context
        .deps
        .js
        .for_source("search", &source.book_source_url, key);
    // [S0-E | BookList.kt:62-81] bookUrlPattern 详情页直连（原版在列表解析前判定，
    // baseUrl = 重定向后最终 URL 整串全匹配）：命中则按详情页规则解析单条结果。
    let has_pattern = source
        .book_url_pattern
        .as_deref()
        .is_some_and(|p| !p.trim().is_empty());
    if has_pattern
        && legado_fetcher::web_book::matches_book_url_pattern(
            source.book_url_pattern.as_deref().unwrap_or(""),
            base_url,
        )
    {
        let info = legado_fetcher::web_book::RealBookSourceFetcher::with_deps(context.deps.clone())
            .parse_book_info_from_body(source, body.to_string(), base_url, base_url, true, "", "");
        return Ok(if info.name.is_empty() {
            vec![]
        } else {
            let item = web_info_to_search_result(info, source);
            // [P3-6 阶段三 | BookList.kt:184-190] getInfoItem 同样受 filter 约束
            if !precision_filter_match(
                precision,
                key,
                &item.book_name,
                &item.author,
                item.kind.as_deref(),
            ) {
                return Ok(vec![]);
            }
            vec![item]
        });
    }

    // [S0-E | BookList.kt:84-96] ruleSearch 缺失 → 空规则（bookList 空 → getElements
    // 得空集合 → 走下方空列表回退），不再提前返回、也不再把整个响应体当单条元素。
    let default_rule_search = legado_core::models::rule::SearchRule::default();
    let rule_search = source.rule_search.as_ref().unwrap_or(&default_rule_search);

    // 创建顶层 AnalyzeRule（quickjs 启用时注入 JS 执行器，使 @js: 搜索规则生效；
    // 2026-08-10 起同时注入书源 jsLib，模板引用的 Reload/getHosts 等库函数可用）
    // [P0-2 S1 | BookList.kt AnalyzeRule(ruleData, bookSource)] 追加书源上下文 setup
    // （source/cookie 绑定 + BookSource 方法），使搜索规则中 `{{source.getKey()}}`、
    // jsLib 函数 `let { source, cookie } = this` 等依赖生效——对齐发现页已用的
    // construct_analyzer_with_source_context（此前搜索主路径仅注入 jsLib，无 setup）。
    let setup_script = context.deps.setup_script_for(source);
    let analyzer = legado_fetcher::js_adapter::construct_analyzer_with_source_context(
        &resources,
        body.to_string(),
        base_url.to_string(),
        &source.book_source_url,
        source.js_lib.as_deref(),
        setup_script.clone(),
    );

    // 获取书籍列表元素
    // [P0-2 S2 | BookList.kt:90-96] 剥离 bookList 规则的 `+`/`-` 前缀：
    // `-` 表示最终结果逆序（reverse），`+` 本版本仅去前缀、无额外行为。
    let (book_list_rule, reverse) =
        split_book_list_prefix(rule_search.book_list.as_deref().unwrap_or(""));
    // [S0-D | 任务 B 2026-09-19] list 提取（getElements）段起点（env 门控计时）
    let t_list_extract = std::time::Instant::now();
    let elements = if book_list_rule.is_empty() {
        // [S0-E] 对齐原版 getElements("")：空规则得空集合（随后走空列表回退）
        Vec::new()
    } else {
        // 队列④ P2-D：bookList 规则 JS 求值失败不再静默吞掉（此前
        // unwrap_or_default → 空列表 →「暂无书籍」无从查因）——仅
        // JsEngine 类上抛（经批次错误通道显示原因，error_class 仍为
        // js_error，契约不变）；非 JS 错误维持吞错语义（空列表 → S0-E 回退）
        book_list_elements_or_default(analyzer.get_elements(&book_list_rule))?
    };
    // [S0-D | 任务 B 2026-09-19] list 提取计时点（env 门控 LEGADO_SEARCH_PHASE_TIMING）：
    // 输出携带会话标识 + 书源 URL（计划要求可关联）
    if std::env::var_os("LEGADO_SEARCH_PHASE_TIMING").is_some() {
        let session_id = context.session_id();
        eprintln!(
            "[phase] list_extract={}ms session={} src={} n={}",
            t_list_extract.elapsed().as_millis(),
            session_id,
            source.book_source_url,
            elements.len()
        );
    }

    if elements.is_empty() {
        // [S0-E | BookList.kt:100-108] 空列表详情回退：原版双条件 —— 列表为空
        // 且未配置 bookUrlPattern 才回退；pattern 已配置但不命中 → 直接返回空。
        if has_pattern {
            return Ok(Vec::new());
        }
        let info = legado_fetcher::web_book::RealBookSourceFetcher::with_deps(context.deps.clone())
            .parse_book_info_from_body(source, body.to_string(), base_url, base_url, true, "", "");
        return Ok(if info.name.is_empty() {
            vec![]
        } else {
            let item = web_info_to_search_result(info, source);
            // [P3-6 阶段三 | BookList.kt:184-190] getInfoItem 同样受 filter 约束
            if !precision_filter_match(
                precision,
                key,
                &item.book_name,
                &item.author,
                item.kind.as_deref(),
            ) {
                return Ok(vec![]);
            }
            vec![item]
        });
    }

    // 对每个元素解析各字段
    // [S0-D | 任务 B 2026-09-19] field 解析段起点（env 门控计时）
    let t_field_parse = std::time::Instant::now();
    let mut results = Vec::new();
    for element_html in &elements {
        // 列表元素按结构化对象写入（JSON 元素 → result 注入为对象，
        // `result.source` 等属性访问；HTML 元素自动回退字符串）
        // — DeepSeek Harness + Bridge
        // [P0-2 S1] 与顶层一致：注入书源上下文 setup（source/cookie），使元素级 JS 规则可用
        let mut item_analyzer = legado_fetcher::js_adapter::construct_analyzer_with_source_context(
            &resources,
            String::new(),
            base_url.to_string(),
            &source.book_source_url,
            source.js_lib.as_deref(),
            setup_script.clone(),
        );
        item_analyzer.set_element_content(element_html.clone());

        // 批量字段提取：纯 CSS 规则共享一次 HTML 解析（搜索速度修复 2026-08-18，
        // 此前每字段各自全量 parse → yeudusk 35s 超时）；语义与逐字段 get_string
        // 完全一致。索引序：0 name / 1 author / 2 kind / 3 word_count /
        // 4 book_url / 5 cover / 6 intro / 7 last_chapter。
        let field_rules: Vec<&str> = vec![
            rule_search.name.as_deref().unwrap_or(""),
            rule_search.author.as_deref().unwrap_or(""),
            rule_search.kind.as_deref().unwrap_or(""),
            rule_search.word_count.as_deref().unwrap_or(""),
            rule_search.book_url.as_deref().unwrap_or(""),
            rule_search.cover_url.as_deref().unwrap_or(""),
            rule_search.intro.as_deref().unwrap_or(""),
            rule_search.last_chapter.as_deref().unwrap_or(""),
        ];
        let fields = item_analyzer.get_strings_batch(field_rules);
        let fields_str: Vec<String> = fields.into_iter().map(|r| r.unwrap_or_default()).collect();
        let field_str = |i: usize| -> String { fields_str.get(i).cloned().unwrap_or_default() };

        // 提取书名（必填，无书名则跳过）；清洗对齐原版 BookHelp.formatBookName
        let book_name = legado_core::book_help::format_book_name(&field_str(0));
        if book_name.is_empty() {
            continue;
        }

        // 提取作者（清洗对齐原版 BookHelp.formatBookAuthor）
        let author = legado_core::book_help::format_book_author(&field_str(1));

        // 提取分类（部分失败不致整条丢弃，对齐原版逐字段 try/catch 语义）。
        // 多标签按原版 BookList.kt:230 `getStringList(ruleKind)?.joinToString(",")` 用逗号分隔：
        // 批量路径 css_vec_to_string 已把多匹配以 \n 连接，此处将 \n 换为 ,（等价于 joinToString(",")，
        // 复用共享 CSS 解析、零额外 parse，不回退 2026-08-18 搜索提速）。
        let kind = legado_core::book_help::normalize_book_kind(&field_str(2));

        // [P3-6 阶段三 | BookList.kt:236-238] precision filter:原版在 getSearchItem
        // 中以 (name, author, kind) 调用 filter,不命中即丢弃该条(precision 关闭时全通过)。
        if !precision_filter_match(precision, key, &book_name, &author, kind.as_deref()) {
            continue;
        }

        // 提取字数并格式化（对齐原版 wordCountFormat）
        let word_count = word_count_format(&field_str(3));

        // 书籍详情页 URL
        let raw_book_url = field_str(4);
        // [UI-fix 2026-08-10 | Reasonix] 对齐原版 BookList.kt:282-284 +
        // AnalyzeRule.kt:369-375：bookUrl 规则解析为空时回退书源主页
        // （bookSourceUrl），避免 book_url 为空导致结果条目无法打开
        // [S0-E | BookList.kt:281-284] bookUrl 规则为空时回退 baseUrl（最终搜索页
        // URL，重定向后），而非书源主页 —— 对齐原版 getSearchItem 回退语义。
        let book_url = if raw_book_url.is_empty() {
            base_url.to_string()
        } else {
            resolve_url(&raw_book_url, base_url)
        };

        // 提取封面 URL
        let raw_cover = field_str(5);
        let cover_url = if raw_cover.is_empty() {
            None
        } else {
            Some(resolve_url(&raw_cover, base_url))
        };

        // 提取简介（对齐原版 BookList.kt:260 `HtmlFormatter.formatIntro`：块级标签→换行、
        // 删注释与其他标签（含 img）、折叠空白；与正文 format_keep_img 保留 img 区分）
        let intro = if field_str(6).is_empty() {
            None
        } else {
            Some(legado_core::html_formatter::format_intro(&field_str(6)))
        };

        // 提取最新章节
        let latest_chapter = if field_str(7).is_empty() {
            None
        } else {
            Some(field_str(7))
        };

        // [T5 | SearchBook.kt:134] 元素级 @put/putVariable 级联导出（字段规则
        // 求值完成后统一收集，随候选进入换源；对齐原版 SearchModel 落库语义）
        let variable = item_analyzer.export_variables_json();

        results.push(SearchResult {
            source_url: source.book_source_url.clone(),
            source_name: source.book_source_name.clone(),
            book_name,
            author,
            book_url,
            latest_chapter,
            intro,
            cover_url,
            kind,
            word_count,
            book_type: book_type_of_source(source.book_source_type),
            // [P0-2 S4 | BookList.kt:215] originOrder = source.customOrder（真实书源排序，非默认 0）
            origin_order: source.custom_order,
            // 阅读记录标识由搜索完成后统一批量附加（见 annotate_results）
            has_read_record: false,
            read_record_author: None,
            variable,
        });
    }

    // [P0-2 S2 | BookList.kt:142-147] 去重（LinkedHashSet 语义，保留首次出现）后按
    // `-` 前缀逆序。键 = 书源 + 书名 + bookUrl：同源同详情页视为重复，不同书名不误伤。
    let mut results = dedup_search_results_keep_first(results);
    if reverse {
        results.reverse();
    }

    // [S0-D | 任务 B 2026-09-19] field 解析计时点（env 门控 LEGADO_SEARCH_PHASE_TIMING）：
    // 覆盖元素级字段提取 + 去重逆序，输出携带会话标识 + 书源 URL（计划要求可关联）；
    // bookUrlPattern 直连 / 空列表回退等早退路径不经过该段，故不产出此计时点
    if std::env::var_os("LEGADO_SEARCH_PHASE_TIMING").is_some() {
        let session_id = context.session_id();
        eprintln!(
            "[phase] field_parse={}ms session={} src={} n={}",
            t_field_parse.elapsed().as_millis(),
            session_id,
            source.book_source_url,
            results.len()
        );
    }

    Ok(results)
}

fn precision_filter_match(
    precision: bool,
    key: &str,
    name: &str,
    author: &str,
    kind: Option<&str>,
) -> bool {
    !precision
        || name.contains(key)
        || author.contains(key)
        || kind.map(|k| k.contains(key)).unwrap_or(false)
}

fn web_info_to_search_result(
    info: legado_core::web_book::WebBookInfo,
    source: &BookSource,
) -> SearchResult {
    SearchResult {
        source_url: source.book_source_url.clone(),
        source_name: source.book_source_name.clone(),
        book_name: info.name,
        author: info.author,
        book_url: info.book_url,
        latest_chapter: info.last_chapter,
        intro: info.intro,
        cover_url: info.cover_url,
        kind: info.kind,
        word_count: info.word_count,
        // 原版 getInfoItem 带入 bookSource.getBookType()（BookList.kt:173）
        book_type: book_type_of_source(source.book_source_type),
        origin_order: source.custom_order,
        has_read_record: false,
        read_record_author: None,
        variable: info.variable,
    }
}

pub fn split_book_list_prefix(rule: &str) -> (String, bool) {
    if let Some(rest) = rule.strip_prefix('-') {
        return (rest.to_string(), true);
    }
    if let Some(rest) = rule.strip_prefix('+') {
        return (rest.to_string(), false);
    }
    (rule.to_string(), false)
}

pub fn dedup_search_results_keep_first(items: Vec<SearchResult>) -> Vec<SearchResult> {
    let mut seen = std::collections::HashSet::new();
    let mut out = Vec::with_capacity(items.len());
    for it in items {
        // [S0-E | SearchBook.kt:65 + BookList.kt:142-144] 去重键 = bookUrl 单键
        //（原版 LinkedHashSet<SearchBook>，equals 仅比较 bookUrl；单源内 origin 恒定）
        let key = it.book_url.clone();
        if seen.insert(key) {
            out.push(it);
        }
    }
    out
}

pub fn resolve_url(url: &str, base_url: &str) -> String {
    if url.is_empty() {
        return String::new();
    }
    // 已是绝对 URL
    if url.starts_with("http://") || url.starts_with("https://") {
        return url.to_string();
    }
    // 协议相对
    if url.starts_with("//") {
        if let Some(pos) = base_url.find("://") {
            return format!("{}:{}", &base_url[..pos], url);
        }
        return format!("https:{}", url);
    }
    // 绝对路径
    if url.starts_with('/') {
        if let Some(pos) = base_url.find("://")
            && let Some(slash_pos) = base_url[pos + 3..].find('/')
        {
            let domain = &base_url[..pos + 3 + slash_pos];
            return format!("{}{}", domain, url);
        }
        return format!("{}{}", base_url.trim_end_matches('/'), url);
    }
    // 相对路径
    if let Some(pos) = base_url.rfind('/') {
        format!("{}/{}", &base_url[..pos], url)
    } else {
        format!("{}/{}", base_url, url)
    }
}

fn parse_header_option(header_str: Option<&str>) -> Option<HashMap<String, String>> {
    header_str.and_then(|s| serde_json::from_str(s).ok())
}

pub fn ensure_default_user_agent(headers: &mut HashMap<String, String>) {
    if !headers.keys().any(|k| k.eq_ignore_ascii_case("user-agent")) {
        headers.insert("User-Agent".to_string(), DEFAULT_USER_AGENT.to_string());
    }
}

async fn search_js_source(
    context: &SearchContext,
    source: &BookSource,
    keyword: &str,
    page: i32,
) -> LegadoResult<Vec<SearchResult>> {
    let source_clone = source.clone();
    let key = keyword.to_string();

    let resources = context
        .deps
        .js
        .for_source("search", &source.book_source_url, keyword);
    let task = context.task.clone();
    let values = tokio::task::spawn_blocking(move || {
        let _task = task;
        let orchestrator =
            legado_fetcher::web_book::build_js_orchestrator(&resources, &source_clone)?;
        let mut orch =
            orchestrator.ok_or_else(|| LegadoError::Internal("JS 书源缺少 mainJs".into()))?;
        // 页码透传（批次B G-B-01）：原硬编码 page=1，现由调用方传入
        orch.search(&source_clone, &key, page)
    })
    .await
    .map_err(|e| LegadoError::Internal(format!("JS 搜索任务异常: {e}")))??;

    // 将 serde_json::Value 转换为 SearchResult
    let results = values
        .into_iter()
        .filter_map(|v| {
            let book_name = v.get("name")?.as_str()?.to_string();
            let book_url = v.get("bookUrl")?.as_str()?.to_string();
            if book_name.is_empty() || book_url.is_empty() {
                return None;
            }
            Some(SearchResult {
                source_url: source.book_source_url.clone(),
                source_name: source.book_source_name.clone(),
                book_name,
                author: v
                    .get("author")
                    .and_then(|a| a.as_str())
                    .unwrap_or_default()
                    .to_string(),
                book_url,
                latest_chapter: v
                    .get("latestChapter")
                    .or_else(|| v.get("lastChapter"))
                    .and_then(|l| l.as_str())
                    .filter(|s| !s.is_empty())
                    .map(|s| s.to_string()),
                intro: v
                    .get("intro")
                    .and_then(|i| i.as_str())
                    .filter(|s| !s.is_empty())
                    .map(|s| s.to_string()),
                cover_url: v
                    .get("coverUrl")
                    .and_then(|c| c.as_str())
                    .filter(|s| !s.is_empty())
                    .map(|s| s.to_string()),
                kind: v
                    .get("kind")
                    .and_then(|k| k.as_str())
                    .and_then(legado_core::book_help::normalize_book_kind),
                word_count: v
                    .get("wordCount")
                    .and_then(|w| w.as_str())
                    .and_then(word_count_format),
                book_type: book_type_of_source(source.book_source_type),
                // [P0-2 S4 | BookList.kt:215] originOrder = source.customOrder（真实书源排序，非默认 0）
                origin_order: source.custom_order,
                // [T5] JS 源返回 JSON 可携带 variable（JS 源搜索期变量）
                variable: v
                    .get("variable")
                    .and_then(|x| x.as_str())
                    .filter(|x| !x.is_empty())
                    .map(|x| x.to_string()),
                // 阅读记录标识由搜索完成后统一批量附加（见 annotate_results）
                has_read_record: false,
                read_record_author: None,
            })
        })
        .collect();

    Ok(results)
}
