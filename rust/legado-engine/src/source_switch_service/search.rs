//! 换源搜索、候选过滤和批次快照；只使用所属服务的数据能力。
use super::*;

impl SourceSwitchService {
    pub fn search_alternative_sources_selected(
        &self,
        book_name: &str,
        author: &str,
        source_urls: &[String],
        options: SwitchSearchOptions,
    ) -> LegadoResult<SourceSwitchResponse> {
        if !options.force_refresh {
            if let Some(matches) = self.try_load_change_source_from_db(book_name, author, &options)
            {
                return Ok(SourceSwitchResponse {
                    book_name: book_name.to_string(),
                    author: author.to_string(),
                    matches,
                });
            }
        } else {
            // 强制刷新：清掉该书旧 searchBooks，避免与新结果混杂
            self.clear_search_books_for_change(book_name, author);
        }

        let sources = self.resolve_switch_sources_selected(source_urls)?;
        if sources.is_empty() {
            return Ok(SourceSwitchResponse {
                book_name: book_name.to_string(),
                author: author.to_string(),
                matches: Vec::new(),
            });
        }

        // 并行搜索（对齐 SearchModel.mapParallelSafe：限流并发 + 单源超时 60s）
        let book_name_for_search = book_name.to_string();
        let sources_for_search = sources.clone();
        let candidates = self.runtime.block_on(async {
            let client = self.network.client()?;

            let mut all_candidates: Vec<SearchCandidate> = Vec::new();
            let outcomes: Vec<_> = stream::iter(sources_for_search)
                .map(|source| {
                    let client = client.clone();
                    let keyword = book_name_for_search.clone();
                    async move {
                        let url = source.book_source_url.clone();
                        let result = tokio::time::timeout(
                            crate::source_batches::SWITCH_SOURCE_TIMEOUT,
                            self.search_for_switch(&client, &source, &keyword),
                        )
                        .await;
                        (url, result)
                    }
                })
                .buffer_unordered(crate::source_batches::SEARCH_CONCURRENCY)
                .collect()
                .await;

            for (_url, joined) in outcomes {
                if let Ok(Ok(mut items)) = joined {
                    all_candidates.append(&mut items);
                }
            }
            Ok::<_, LegadoError>(all_candidates)
        })?;

        // Task #25：对齐原版 ChangeBookSourceViewModel L266-270 的换源硬过滤：
        // 只保留同名书（fName == name），可选「校验作者」开关（原版
        // AppConfig.changeSourceCheckAuthor，键名一致）。此前仅打分排序不过滤，
        // match_score 为 0 的毫不相关错书仍全部进入换源列表（Task #25 现象）。
        // config 读取失败按关闭处理（不误伤同名过滤主语义）。
        let check_author = self.config("changeSourceCheckAuthor").trim() == "true";
        let candidates =
            SourceMatcher::filter_for_change(candidates, book_name, author, check_author);

        let candidates = if options.needs_enrichment() {
            self.enrich_switch_candidates(&sources, candidates, &options)?
        } else {
            candidates
        };

        // 使用 SourceMatcher 评分排序（loadWordCount 开启时用字数 comparator）
        let matches = SourceMatcher::rank_candidates_with_options(
            candidates,
            book_name,
            author,
            options.load_word_count,
        );

        self.ensure_active()?;
        self.persist_switch_matches(&matches);

        Ok(SourceSwitchResponse {
            book_name: book_name.to_string(),
            author: author.to_string(),
            matches,
        })
    }

    pub(super) fn push_change_source_batch(
        &self,
        on_batch: &mut impl FnMut(ChangeSourceBatch) -> Result<(), String>,
        batch: ChangeSourceBatch,
    ) -> Result<(), String> {
        let result = self
            .publish(|| on_batch(batch))
            .unwrap_or_else(|| Err("换源已取消".into()));
        if result.is_err()
            && let Some(operation) = &self.operation
        {
            operation.cancel();
        }
        result
    }

    pub async fn run_change_source_stream_selected<F>(
        &self,
        book_name: String,
        author: String,
        source_urls: Vec<String>,
        options: SwitchSearchOptions,
        mut on_batch: F,
    ) where
        F: FnMut(ChangeSourceBatch) -> Result<(), String>,
    {
        use std::sync::atomic::AtomicBool;
        // 对齐上游 startSearch() 入口清空 tocMap/bookMap（L279-281）：新一轮
        // 搜索会话作废旧会话预拉，防选中读到陈旧目录

        // 对齐原版 ChangeBookSourceViewModel.searchDataFlow：先 getDbSearchBooks，
        // 非空直接展示（单批推送即结束）；仅空列表或强制刷新才全量搜索
        if !options.force_refresh {
            if let Some(matches) =
                self.try_load_change_source_from_db(&book_name, &author, &options)
            {
                // 早期批次：sink 关闭无在飞任务可 abort，忽略推送结果
                let _ = self.push_change_source_batch(
                    &mut on_batch,
                    ChangeSourceBatch {
                        source_index: 0,
                        source_url: String::new(),
                        source_name: String::new(),
                        error: None,
                        finished_count: 1,
                        total_count: 1,
                        is_last: true,
                        matches,
                    },
                );
                return;
            }
        } else {
            // 强制刷新：清掉该书旧 searchBooks，避免与新结果混杂
            self.clear_search_books_for_change(&book_name, &author);
        }

        let sources = match self.resolve_switch_sources_selected(&source_urls) {
            Ok(s) => s,
            Err(e) => {
                let _ = self.push_change_source_batch(
                    &mut on_batch,
                    ChangeSourceBatch {
                        source_index: 0,
                        source_url: String::new(),
                        source_name: String::new(),
                        error: Some(e.to_string()),
                        finished_count: 0,
                        total_count: 0,
                        is_last: true,
                        matches: Vec::new(),
                    },
                );
                return;
            }
        };

        if sources.is_empty() {
            let _ = self.push_change_source_batch(
                &mut on_batch,
                ChangeSourceBatch {
                    source_index: 0,
                    source_url: String::new(),
                    source_name: String::new(),
                    error: None,
                    finished_count: 0,
                    total_count: 0,
                    is_last: true,
                    matches: Vec::new(),
                },
            );
            return;
        }

        let client = match self.network.client() {
            Ok(c) => c,
            Err(e) => {
                let _ = self.push_change_source_batch(
                    &mut on_batch,
                    ChangeSourceBatch {
                        source_index: 0,
                        source_url: String::new(),
                        source_name: String::new(),
                        error: Some(e.to_string()),
                        finished_count: 0,
                        total_count: sources.len(),
                        is_last: true,
                        matches: Vec::new(),
                    },
                );
                return;
            }
        };

        // 与批量路径同口径：原版 AppConfig.changeSourceCheckAuthor（读取失败按关闭）
        let check_author = self.config("changeSourceCheckAuthor").trim() == "true";

        // 会话级门控标志：sink 关闭 → 驱动器置位取消并 abort 在飞任务（复用 P0-3 驱动机制）
        let cancel = self
            .operation
            .as_ref()
            .expect("换源流入口必须登记任务")
            .task()
            .clone();
        let paused = Arc::new(AtomicBool::new(false));

        // 累积过滤后候选（逐源增量过滤 ≡ 批量过滤，元素级判定）
        let mut accumulated: Vec<SearchCandidate> = Vec::new();

        // search_one 闭包为 move（'static），需预克隆；on_source 闭包借用 book_name/author/options
        let client_for_search = client.clone();
        let search_context = self.clone();
        let book_name_for_search = book_name.clone();

        crate::source_batches::drive_source_batches(
            sources.clone(),
            crate::source_batches::SEARCH_CONCURRENCY,
            crate::source_batches::SWITCH_SOURCE_TIMEOUT,
            &cancel,
            &paused,
            move |source: BookSource| {
                let context = search_context.clone();
                let client = client_for_search.clone();
                let keyword = book_name_for_search.clone();
                async move { context.search_for_switch(&client, &source, &keyword).await }
            },
            |outcome| {
                // 该源候选增量过滤（同名 + 可选作者校验）并累积
                if let Ok(items) = &outcome.result {
                    accumulated.extend(SourceMatcher::filter_for_change(
                        items.clone(),
                        &book_name,
                        &author,
                        check_author,
                    ));
                }
                // 重排快照：当前已过滤评分候选全量集
                let matches = SourceMatcher::rank_candidates_with_options(
                    accumulated.clone(),
                    &book_name,
                    &author,
                    options.load_word_count,
                );
                // sink 关闭（Err）→ 传播给驱动器，置位取消并 abort 在飞任务
                self.push_change_source_batch(
                    &mut on_batch,
                    ChangeSourceBatch {
                        source_index: outcome.index,
                        source_url: outcome.source_url,
                        source_name: outcome.source_name,
                        error: outcome.result.err().map(|e| e.to_string()),
                        finished_count: outcome.finished_count,
                        total_count: outcome.total_count,
                        is_last: outcome.is_last,
                        matches,
                    },
                )
            },
        )
        .await;

        if self.ensure_active().is_err() {
            return;
        }

        // 流内后置增强（不阻塞首批到达——所有搜索批次已先行推送）：
        // enrich 开启时对累积候选执行详情/目录/试读字数，再推最终重排快照
        let enriched = if options.needs_enrichment() {
            self.enrich_switch_candidates_async(
                &sources,
                accumulated,
                &options,
                |context: &SourceSwitchService| context.fetcher(),
            )
            .await
            .unwrap_or_default()
        } else {
            accumulated
        };

        if self.ensure_active().is_err() {
            return;
        }
        let final_matches = SourceMatcher::rank_candidates_with_options(
            enriched,
            &book_name,
            &author,
            options.load_word_count,
        );

        // 终批仅在 enrich 开启时推送（enriched+重排快照）；未开启时最后一搜索批次即最终态
        if options.needs_enrichment() {
            let total = sources.len();
            // 终批推送失败（sink 已关闭）不影响最终候选落库
            let _ = self.push_change_source_batch(
                &mut on_batch,
                ChangeSourceBatch {
                    source_index: 0,
                    source_url: String::new(),
                    source_name: String::new(),
                    error: None,
                    finished_count: total,
                    total_count: total,
                    is_last: true,
                    matches: final_matches.clone(),
                },
            );
        }

        // 最终候选落库 searchBooks（对齐原版 searchSuccess → insert；供下次读库路径复用）
        self.persist_switch_matches(&final_matches);
    }
}

impl SourceSwitchService {
    async fn search_for_switch(
        &self,
        client: &LegadoClient,
        source: &BookSource,
        keyword: &str,
    ) -> LegadoResult<Vec<SearchCandidate>> {
        self.ensure_active()?;
        let request = SwitchSearchRequest {
            client: client.clone(),
            source: source.clone(),
            keyword: keyword.to_string(),
            task: self.operation.as_ref().map(|op| op.task().clone()),
        };
        tokio::select! {
            biased;
            _=self.cancelled()=>Err(LegadoError::Internal("换源已取消".into())),
            result=(self.search)(request)=>result,
        }
    }
}
