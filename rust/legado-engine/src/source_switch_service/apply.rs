//! 变量合并、抓取与单事务提交；只使用所属服务的数据能力。
use super::*;

impl SourceSwitchService {
    pub(super) fn locate_switch_book_and_source(
        &self,
        book_url: &str,
        new_source_url: &str,
    ) -> LegadoResult<(Book, BookSource)> {
        use legado_db::BookRepository;

        let (book, source) = self.database(|db| {
            let repo = BookRepository::new(db.connection());
            let book = repo
                .find_by_url(book_url)?
                .ok_or_else(|| LegadoError::Database("书籍不存在".into()))?;

            // 新书源配置：既用于抓取新目录，也用于取书源名称
            let source_repo = legado_db::BookSourceRepository::new(db.connection());
            let source = source_repo
                .find_by_url(new_source_url)?
                .ok_or_else(|| LegadoError::Database(format!("书源不存在: {new_source_url}")))?;

            Ok((book, source))
        })?;
        Ok((book, source))
    }

    pub(super) fn lookup_candidate_variable(
        &self,
        new_book_url: &str,
        new_source_url: &str,
    ) -> LegadoResult<Option<String>> {
        let variable = self.database(|db| {
            let repo = legado_db::SearchBookRepository::new(db.connection());
            match repo.find_by_book_url(new_book_url)? {
                Some(row) if row.origin == new_source_url => Ok(row.variable),
                _ => Ok(None),
            }
        })?;
        Ok(variable)
    }

    pub(super) fn apply_book_variable_merge(
        &self,
        book: &mut Book,
        candidate_variable: Option<&str>,
        info_variable: Option<&str>,
        new_book_url: &str,
        source_url: &str,
    ) {
        let merged_variable = merge_variables(candidate_variable, info_variable);
        book.variable = yield_stale_overlay_to_db(
            merged_variable.as_deref(),
            book.variable.as_deref(),
            candidate_variable,
            &legado_fetcher::web_book::book_var_overlay_map(
                &self.js,
                &self.web_book,
                source_url,
                new_book_url,
            ),
        );
    }

    pub(super) fn commit_source_switch(
        &self,
        book: &mut Book,
        source: &BookSource,
        target: SwitchCommitTarget<'_>,
        info: WebBookInfo,
        web_chapters: Vec<WebChapter>,
    ) -> LegadoResult<Book> {
        let SwitchCommitTarget {
            book_url,
            source_url: new_source_url,
            detail_url: new_book_url,
        } = target;
        use legado_db::BookRepository;
        use legado_db::repository::Repository;

        // [T2] tocUrl = 详情解析出的真实目录页（目录页可与详情页不同，
        //     如「详情页=books/1、目录页=/book/1/chapters」的源）
        let toc_url = if info.toc_url.trim().is_empty() {
            new_book_url.to_string()
        } else {
            info.toc_url.clone()
        };

        // Task #21 修复：空结果保护。新书源未解析到任何章节时（目录抓取返回
        //    Ok(vec![]) 而非错误），直接返回可读错误，且不改动任何库记录
        //    （保留原 origin/tocUrl 与原目录），避免把书换成「无章节」而比未换源
        //    更糟的回归。
        if web_chapters.is_empty() {
            return Err(LegadoError::Parser(format!(
                "换源失败：新书源未解析到任何章节（目录地址={toc_url}），已保留原书源与目录"
            )));
        }

        // 3. 转换为 BookChapter，base_url/book_url 均落稳定的原 bookUrl
        //    [T1] 保留解析值 variable/is_volume：章节级 @put 变量（翻页 token 类）
        //    与卷章标记是正文请求/去重的前置输入，写死 None/false 会导致换源后正文错误
        let book_chapters: Vec<BookChapter> = web_chapters
            .iter()
            .map(|wc| BookChapter {
                url: wc.url.clone(),
                title: wc.title.clone(),
                is_volume: wc.is_volume,
                base_url: book_url.to_string(),
                book_url: book_url.to_string(),
                index: wc.index,
                is_vip: wc.is_vip,
                is_pay: false,
                resource_url: None,
                tag: None,
                word_count: None,
                start: None,
                end: None,
                start_fragment_id: None,
                end_fragment_id: None,
                variable: wc.variable.clone(),
                img_url: None,
            })
            .collect();

        // 4. 将书源字段更新 + 清旧缓存/旧章节 + 写入新章节，全部包进单个 DB 事务：
        //    全部成功才提交；中途失败自动回滚，保留原书源与原章节，
        //    避免留下"无章节"状态（比未换源更糟）。bookUrl 保持稳定，仅改
        //    origin/originName/tocUrl，update 的 WHERE 命中原行（稳定主键）。
        //    connection() 返回共享的 &Connection（r2d2 池），无法用需 &mut 的
        //    Connection::transaction()，故沿用项目既有的 unchecked_transaction()
        //    模式（见 highlight_rule_repository / book_chapter_repository）。
        //    insert_batch 内部会自开事务，此处改用 insert_batch_no_tx 避免嵌套 BEGIN。
        // 仅更新书源相关字段；bookUrl 不变 → update 的 WHERE 命中原行（稳定主键）
        book.origin = new_source_url.to_string();
        book.origin_name = source.book_source_name.clone();
        // [T2] tocUrl = 详情解析出的真实目录页（原写死详情页 URL，使「目录独立页」
        //      源后续刷新目录/正文定位全错）
        book.toc_url = toc_url;
        // [P2-8] 换源根因修复：写入当前书源下该书的详情页地址（new_book_url）。
        //    换源后 bookUrl（稳定主键）仍为旧源地址，「抓取书籍页」路径
        //    （详情刷新 / tocUrl 推导 / preUpdateJs 钩子）优先用本字段，为空时
        //    回退 bookUrl（未换源书籍与存量库行为不变）。
        book.origin_book_url = new_book_url.to_string();
        // [T2] 详情字段按 parse 门控结果更新（name/author 已含 canReName 门控；
        //      Option 字段仅在解析出值时覆盖，避免新源缺字段抹掉既有信息）
        book.name = info.name;
        book.author = info.author;
        if info.cover_url.is_some() {
            book.cover_url = info.cover_url;
        }
        if info.intro.is_some() {
            book.intro = info.intro;
        }
        if info.kind.is_some() {
            book.kind = info.kind;
        }
        if info.word_count.is_some() {
            book.word_count = info.word_count;
        }
        // [目录派生字段同步] 对齐上游 BookChapterList.updateBookTocInfo（目录成功
        // 后 totalChapterNum/latestChapterTitle 以目录结果写入；详情 lastChapter
        // 规则值写在目录写之前，由目录值覆盖——此处不再取详情值）：
        // - totalChapterNum = 落库章节数（与同事务 insert_batch 的 bookChapters
        //   行数一致，DB 内部一致性；书架进度百分比 = durChapterIndex/(N-1) 随之
        //   正确）
        // - latestChapterTitle = 新目录末章标题
        // - latestChapterTime = now，仅章数增长时（上游 updateBookTocInfo 条件分支）
        // 截断目录（非 2xx 保留前缀）按前缀章数写入——对齐上游「body-null 判停
        // 后 updateBookTocInfo 写 list.size」；I/O 级失败/空结果不会走到提交
        // （目录抓取 Err 上抛 + 函数入口空目录守卫），不存在陈旧值写回路径。
        let old_total = book.total_chapter_num;
        let new_total = book_chapters.len() as i32;
        book.total_chapter_num = new_total;
        book.latest_chapter_title = book_chapters.last().map(|c| c.title.clone());
        if old_total < new_total {
            book.latest_chapter_time = now_millis();
        }
        // 标记需要重新获取章节列表
        book.last_check_time = 0;
        book.last_check_count = 0;
        self.publish(|| -> LegadoResult<()> {
            self.database(|db| {
                let conn = db.connection();
                let tx = conn
                    .unchecked_transaction()
                    .map_err(|e| LegadoError::Database(format!("开启换源事务失败: {e}")))?;

                // [B-4] `update` 的 UPDATE SET 结构性排除进度列（见
                // BookRepository::update 的 [B-3] 注释）：本事务的入参 book 是「抓取前
                // 快照」（locate_switch_book_and_source 读取），不含分钟级网络抓取
                // 窗口内写入的进度——全行写回会把窗口内进度抹平。此处零代码改动：
                // 靠结构排除实现「换源提交不抹窗口内进度」。
                BookRepository::new(conn).update(book)?;
                let cache_repo = legado_db::CacheBookRepository::new(conn);
                cache_repo.delete_by_book(book_url)?;
                let chapter_repo = legado_db::BookChapterRepository::new(conn);
                chapter_repo.delete_by_book_url(book_url)?;
                chapter_repo.insert_batch_no_tx(&book_chapters)?;

                tx.commit()
                    .map_err(|e| LegadoError::Database(format!("提交换源事务失败: {e}")))?;
                Ok(())
            })?;

            // [B-6] 换源提交后按**新书源**登记 (书源, 章节) → 下一章 URL：换源后
            // 正文分页「命中下一章即截断」按当前书源的目录判定（registry 复合键
            // (书源, 章节) 天然隔离旧源登记，此处为当前书源补齐精确通道）
            legado_fetcher::web_book::record_next_chapter_map(
                &self.web_book,
                new_source_url,
                &web_chapters,
            );

            Ok(())
        })
        .ok_or_else(|| LegadoError::Internal("换源已取消".into()))??;

        Ok(book.clone())
    }

    pub fn switch_book_source_entity_with<F: BookSourceFetcher>(
        &self,
        fetcher: &F,
        book_url: &str,
        new_source_url: &str,
        new_book_url: &str,
    ) -> LegadoResult<Book> {
        // Task #21 修复：换源目标详情页 URL 为空时提前返回可读错误。
        // 否则空 URL 会传入 get_chapters（步骤 2b），触发解析器抛出令人困惑的
        // "bookUrl不能为空"（web_book.rs get_chapters 空值校验）。
        // 空 book_url 通常源于书源 ruleSearch.bookUrl 未解析出详情页 URL 的候选，
        // 此处兜底防御，主过滤在 search_for_switch（不让空候选进入换源列表）。
        if new_book_url.trim().is_empty() {
            return Err(LegadoError::Parser(
                "换源目标书籍详情页 URL 为空，无法切换书源（该候选未解析出有效链接）".into(),
            ));
        }

        // 1. 定位书籍 + 加载新书源配置（只读，见 helper 文档）
        let (mut book, source) = self.locate_switch_book_and_source(book_url, new_source_url)?;

        // [T5] 候选搜索期变量（searchBooks 行回查）
        let candidate_variable = self.lookup_candidate_variable(new_book_url, new_source_url)?;

        // P1-2 入口收口：换源执行 ruleBookInfo + 写 DB（变量桥读写）→ 先切
        // flow scope（键 = 新源详情页 URL，与 webbook_info 同键族），防上一
        // 流程残留 scope 串读/误清

        // 2a. [T2] 新源详情解析（canReName=false：保留既有书名/作者，对齐原版
        //     changeSource getBookInfoAwait 门控；cover/intro/kind/lastChapter/
        //     wordCount 在 parse 内按解析值更新，tocUrl 为真实目录页）
        //     [R1 修复 2026-09-06] 详情请求带候选搜索期变量表：原版
        //     getBookInfoAwait 的 AnalyzeUrl 以 ruleData=book 构建（WebBook.kt:225-231，
        //     book.variable=候选变量），bookUrl 的 {{key}} 模板与 ,{json} 请求选项
        //     用其展开；此前恒空表 → 变量依赖源详情请求打错地址。
        self.ensure_active()?;
        let detail_vars =
            legado_fetcher::web_book::chapter_url_variables(candidate_variable.as_deref());
        let info = self
            .runtime
            .block_on(async {
                fetcher
                    .get_book_info_with_existing_and_vars(
                        &source,
                        new_book_url,
                        false,
                        &book.name,
                        &book.author,
                        &detail_vars,
                    )
                    .await
            })
            .map_err(|e| {
                LegadoError::Parser(format!(
                    "换源失败：新源「{}」详情页解析失败，已保留原书源与目录: {e}",
                    source.book_source_name
                ))
            })?;

        // [T5] 变量合并 + 陈旧 overlay 让位（须在 2b 目录抓取前完成：目录请求
        //      变量表 = 候选 ⊕ 详情导出合并值，见 helper 文档）
        self.apply_book_variable_merge(
            &mut book,
            candidate_variable.as_deref(),
            info.variable.as_deref(),
            new_book_url,
            &source.book_source_url,
        );

        // 2b. [T2] 用解析出的真实 tocUrl 抓取新目录
        let toc_url = if info.toc_url.trim().is_empty() {
            new_book_url.to_string()
        } else {
            info.toc_url.clone()
        };
        self.ensure_active()?;
        let web_chapters: Vec<WebChapter> = self
            .runtime
            .block_on(async {
                // [R1 修复 2026-09-06] 目录请求带合并后 book.variable（候选 ⊕ 详情导出）：
                // 原版 getChapterListAwait 的 AnalyzeUrl 以 ruleData=book 构建
                // （WebBook.kt:312-318）；此前恒空表 → 变量依赖源目录请求打错地址。
                let toc_vars =
                    legado_fetcher::web_book::chapter_url_variables(book.variable.as_deref());
                // P2-2（2026-09-17）：传 2a 详情解析出的书名作 hint。上游
                // BookChapterList.kt:196 以 `AnalyzeRule(book, bookSource)` 构建
                // 解析器，`@js:[{title: book.name, url: …}]` 类 ruleToc.chapterList
                // 规则可读取 book.name；已知目录页直抓路径不抓详情页，无 hint 时
                // book 绑定名为空 → 此类规则标题退化（SiS文學網简体等 4 源）。
                // hint 为 Option：Mock 等实现走 trait 默认（退化为
                // get_chapters_with_vars），既有签名不变。
                fetcher
                    .get_chapters_with_vars_and_name_hint(
                        &source,
                        &toc_url,
                        &toc_vars,
                        Some(&info.name),
                    )
                    .await
            })
            .map_err(|e| {
                LegadoError::Parser(format!(
                    "换源失败：新源「{}」目录获取失败，已保留原书源与目录: {e}",
                    source.book_source_name
                ))
            })?;

        // 3+4. 空目录守卫 + 单事务提交 + 下一章登记 + 书籍 JSON（共用尾段）
        self.commit_source_switch(
            &mut book,
            &source,
            SwitchCommitTarget {
                book_url,
                source_url: new_source_url,
                detail_url: new_book_url,
            },
            info,
            web_chapters,
        )
    }

    pub fn switch_book_source_prefetch_entity_with<F: BookSourceFetcher>(
        &self,
        fetcher: &F,
        book_url: &str,
        new_source_url: &str,
        new_book_url: &str,
    ) -> LegadoResult<Book> {
        // Task #21 同款兜底防御（与旧路径同一文案/同一前置）
        if new_book_url.trim().is_empty() {
            return Err(LegadoError::Parser(
                "换源目标书籍详情页 URL 为空，无法切换书源（该候选未解析出有效链接）".into(),
            ));
        }

        // 1. 定位书籍 + 加载新书源配置（与旧路径共用）
        let (mut book, source) = self.locate_switch_book_and_source(book_url, new_source_url)?;

        // [T5] 候选搜索期变量（与旧路径共用）
        let candidate_variable = self.lookup_candidate_variable(new_book_url, new_source_url)?;

        // P1-2 入口收口（与旧路径共用同一 flow scope 切点）

        // 命中/未命中分支（上游 getToc L659-682：命中 → 不抓取直接用；
        // 未命中 → 现场抓取）
        let entry = self.prefetch_cache_get(new_source_url, new_book_url);
        let cached_info = entry.as_ref().and_then(|e| e.info.clone());
        let cached_chapters = entry.map(|e| e.chapters).filter(|c| !c.is_empty());

        // 2a. 详情（命中：缓存 info 直接用（零网络），None 降级现场补抓；
        //     未命中：现场抓取，执行链与旧路径 2a 一致，请求带候选变量表）
        let detail_vars =
            legado_fetcher::web_book::chapter_url_variables(candidate_variable.as_deref());
        let info = match cached_info {
            Some(info) => info,
            None => {
                self.ensure_active()?;
                self.runtime
                    .block_on(async {
                        fetcher
                            .get_book_info_with_existing_and_vars(
                                &source,
                                new_book_url,
                                false,
                                &book.name,
                                &book.author,
                                &detail_vars,
                            )
                            .await
                    })
                    .map_err(|e| {
                        LegadoError::Parser(format!(
                            "换源失败：新源「{}」详情页解析失败，已保留原书源与目录: {e}",
                            source.book_source_name
                        ))
                    })?
            }
        };

        // [T5] 变量合并 + 陈旧 overlay 让位（须在未命中路径的目录抓取前完成：
        //      目录请求变量表 = 候选 ⊕ 详情导出合并值）
        self.apply_book_variable_merge(
            &mut book,
            candidate_variable.as_deref(),
            info.variable.as_deref(),
            new_book_url,
            &source.book_source_url,
        );

        // 2b. 目录（命中：预拉缓存目录直接用，零网络；未命中：现场抓取，可取消）。
        // 真实 tocUrl 由共用尾段 commit_source_switch 从 info 统一解析
        // （「空 toc_url → new_book_url」回退与旧路径同一逻辑）
        let web_chapters: Vec<WebChapter> = match cached_chapters {
            Some(chapters) => chapters,
            None => {
                self.ensure_active()?;
                let toc_url = if info.toc_url.trim().is_empty() {
                    new_book_url.to_string()
                } else {
                    info.toc_url.clone()
                };
                self.runtime
                    .block_on(async {
                        // 目录请求变量表 = 合并后 book.variable（与旧路径 2b 一致）
                        let toc_vars = legado_fetcher::web_book::chapter_url_variables(
                            book.variable.as_deref(),
                        );
                        fetcher
                            .get_chapters_with_vars_and_name_hint(
                                &source,
                                &toc_url,
                                &toc_vars,
                                Some(&info.name),
                            )
                            .await
                    })
                    .map_err(|e| {
                        LegadoError::Parser(format!(
                            "换源失败：新源「{}」目录获取失败，已保留原书源与目录: {e}",
                            source.book_source_name
                        ))
                    })?
            }
        };

        // 提交前取消兜底：2a/2b 均成功后若已取消 → 不提交（DB 零变更）
        self.ensure_active()?;

        // 3+4. 空目录守卫 + 单事务提交 + 下一章登记 + 书籍 JSON（共用尾段）
        self.commit_source_switch(
            &mut book,
            &source,
            SwitchCommitTarget {
                book_url,
                source_url: new_source_url,
                detail_url: new_book_url,
            },
            info,
            web_chapters,
        )
    }
}

pub fn merge_variables(initial: Option<&str>, detail: Option<&str>) -> Option<String> {
    let mut map = serde_json::Map::new();
    for (label, src) in [("initial", initial), ("detail", detail)] {
        let _ = label;
        if let Some(s) = src.map(str::trim).filter(|v| !v.is_empty())
            && let Ok(serde_json::Value::Object(m)) = serde_json::from_str::<serde_json::Value>(s)
        {
            for (k, v) in m {
                map.insert(k, v);
            }
        }
    }
    if map.is_empty() {
        None
    } else {
        Some(serde_json::Value::Object(map).to_string())
    }
}

pub fn yield_stale_overlay_to_db(
    merged: Option<&str>,
    db_variable: Option<&str>,
    candidate_variable: Option<&str>,
    overlay_keys: &HashMap<String, String>,
) -> Option<String> {
    let merged_raw = merged?;
    let Some(serde_json::Value::Object(mut map)) =
        serde_json::from_str::<serde_json::Value>(merged_raw).ok()
    else {
        return Some(merged_raw.to_string());
    };
    let candidate_has_key = |k: &str| {
        candidate_variable
            .map(str::trim)
            .filter(|v| !v.is_empty())
            .and_then(|s| serde_json::from_str::<serde_json::Value>(s).ok())
            .map(|v| v.as_object().is_some_and(|o| o.contains_key(k)))
            .unwrap_or(false)
    };
    let db_value = |k: &str| {
        db_variable
            .map(str::trim)
            .filter(|v| !v.is_empty())
            .and_then(|s| serde_json::from_str::<serde_json::Value>(s).ok())
            .and_then(|v| v.as_object().and_then(|o| o.get(k)).cloned())
    };
    for k in overlay_keys.keys() {
        if candidate_has_key(k) {
            continue;
        }
        if let Some(db_v) = db_value(k)
            && map.get(k) != Some(&db_v)
        {
            map.insert(k.clone(), db_v);
        }
    }
    Some(serde_json::Value::Object(map).to_string())
}

fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}
