//! 候选增强、单候选超时及顺序恢复；只使用所属服务的数据能力。
use super::*;

impl SourceSwitchService {
    pub(super) fn enrich_switch_candidates(
        &self,
        sources: &[BookSource],
        candidates: Vec<SearchCandidate>,
        options: &SwitchSearchOptions,
    ) -> LegadoResult<Vec<SearchCandidate>> {
        self.runtime.block_on(self.enrich_switch_candidates_async(
            sources,
            candidates,
            options,
            |context: &SourceSwitchService| context.fetcher(),
        ))
    }

    pub async fn enrich_switch_candidates_async<F, MF>(
        &self,
        sources: &[BookSource],
        candidates: Vec<SearchCandidate>,
        options: &SwitchSearchOptions,
        make_fetcher: MF,
    ) -> LegadoResult<Vec<SearchCandidate>>
    where
        F: BookSourceFetcher + Send + 'static,
        MF: Fn(&SourceSwitchService) -> LegadoResult<F> + Send + Sync + 'static,
    {
        let source_map: HashMap<String, BookSource> = sources
            .iter()
            .map(|s| (s.book_source_url.clone(), s.clone()))
            .collect();

        let mut orphans = Vec::new();
        let mut jobs: Vec<(SearchCandidate, BookSource)> = Vec::new();
        for candidate in candidates {
            match source_map.get(&candidate.source_url) {
                Some(source) => jobs.push((candidate, source.clone())),
                None => orphans.push(candidate),
            }
        }

        // 有界并发 + 单候选超时（并发上限/索引槽/孤儿在前序恢复均在
        // run_enrich_jobs 内）
        let job_count = jobs.len();
        let done = self.run_enrich_jobs(make_fetcher, jobs, options).await;

        let mut filled: Vec<Option<SearchCandidate>> = vec![None; job_count];
        for (idx, c) in done {
            filled[idx] = Some(c);
        }
        let mut out = orphans;
        out.extend(filled.into_iter().flatten());
        Ok(out)
    }

    pub(super) async fn run_enrich_jobs<F, MF>(
        &self,
        make_fetcher: MF,
        jobs: Vec<(SearchCandidate, BookSource)>,
        options: &SwitchSearchOptions,
    ) -> Vec<(usize, SearchCandidate)>
    where
        F: BookSourceFetcher + Send + 'static,
        MF: Fn(&SourceSwitchService) -> LegadoResult<F> + Send + Sync + 'static,
    {
        self.run_enrich_jobs_until(
            make_fetcher,
            jobs,
            options,
            crate::source_batches::SWITCH_SOURCE_TIMEOUT,
        )
        .await
    }

    pub async fn run_enrich_jobs_until<F, MF>(
        &self,
        make_fetcher: MF,
        jobs: Vec<(SearchCandidate, BookSource)>,
        options: &SwitchSearchOptions,
        timeout: std::time::Duration,
    ) -> Vec<(usize, SearchCandidate)>
    where
        F: BookSourceFetcher + Send + 'static,
        MF: Fn(&SourceSwitchService) -> LegadoResult<F> + Send + Sync + 'static,
    {
        let factory = Arc::new(make_fetcher);
        stream::iter(jobs.into_iter().enumerate())
            .map(|(index, (candidate, source))| {
                let context = self.clone();
                let factory = factory.clone();
                let options = options.clone();
                async move {
                    if context.ensure_active().is_err() {
                        return (index, candidate);
                    }
                    let Ok(task) = context.state.tasks().begin() else {
                        return (index, candidate);
                    };
                    let _guard = task.guard();
                    let mut worker_context = context.clone();
                    worker_context.deadline = Some(task.clone());
                    let fallback = candidate.clone();
                    // 阻塞壳完整驱动候选的 async/JS 链；超时丢弃 join 不会提前注销真实工作。
                    let worker = tokio::task::spawn_blocking(move || {
                        let fetcher = match factory(&worker_context) {
                            Ok(fetcher) => fetcher,
                            Err(_) => return candidate,
                        };
                        worker_context.runtime.block_on(
                            worker_context.enrich_one_switch_candidate_with(
                                &fetcher, &source, candidate, &options,
                            ),
                        )
                    });
                    let result = tokio::select! {
                        biased;
                        _=context.cancelled()=>None,
                        result=tokio::time::timeout(timeout,worker)=>match result {
                            Ok(Ok(candidate))=>Some(candidate), _=>None,
                        },
                    };
                    if let Some(candidate) = result {
                        (index, candidate)
                    } else {
                        task.cancel();
                        (index, fallback)
                    }
                }
            })
            .buffer_unordered(ENRICH_CONCURRENCY)
            .collect()
            .await
    }

    pub async fn enrich_one_switch_candidate_with(
        &self,
        fetcher: &impl BookSourceFetcher,
        source: &BookSource,
        mut candidate: SearchCandidate,
        options: &SwitchSearchOptions,
    ) -> SearchCandidate {
        if self.ensure_active().is_err() {
            return candidate;
        }
        candidate.origin_order = source.custom_order;
        if !(options.load_info || options.load_toc || options.load_word_count) {
            return candidate;
        }

        let book_url = candidate.book_url.clone();
        let mut toc_url = String::new();
        let mut prefetched_info: Option<WebBookInfo> = None;
        // [R1] 详情请求带候选搜索期变量表（与 apply 2a 同一展开口径：原版
        // getBookInfoAwait 的 AnalyzeUrl 以 ruleData=book 构建，WebBook.kt:225-231）
        let detail_vars =
            legado_fetcher::web_book::chapter_url_variables(candidate.variable.as_deref());

        if options.load_info
            && let Ok(info) = fetcher
                .get_book_info_with_existing_and_vars(
                    source,
                    &book_url,
                    false,
                    &candidate.book_name,
                    &candidate.author,
                    &detail_vars,
                )
                .await
        {
            if self.ensure_active().is_err() {
                return candidate;
            }
            if candidate
                .latest_chapter
                .as_ref()
                .is_none_or(|s| s.is_empty())
            {
                candidate.latest_chapter = info.last_chapter.clone();
            }
            if candidate.word_count.as_ref().is_none_or(|s| s.is_empty()) {
                candidate.word_count = info.word_count.clone();
            }
            toc_url = info.toc_url.clone();
            prefetched_info = Some(info.clone());
            // 上游 bookMap 恒写语义（loadBookInfo 成功后必写）：即使目录未
            // 拉取也先写「详情-only」条目，apply 命中可降级「缓存详情 +
            // 现场目录」省一次详情抓取
            self.prefetch_cache_insert(&source.book_source_url, &book_url, Some(info), Vec::new());
        }

        if self.ensure_active().is_err() {
            return candidate;
        }
        if options.load_toc || options.load_word_count {
            let toc_opt = if toc_url.trim().is_empty() {
                None
            } else {
                Some(toc_url.as_str())
            };
            match fetcher
                .get_chapters_with_hints_and_vars(
                    source,
                    &book_url,
                    toc_opt,
                    Some(&candidate.book_name),
                    &HashMap::new(),
                )
                .await
            {
                Ok(chapters) if !chapters.is_empty() => {
                    if self.ensure_active().is_err() {
                        return candidate;
                    }
                    if options.load_word_count {
                        apply_word_count_sample(&mut candidate, source, fetcher, &chapters).await;
                    }
                    // 上游 loadBookToc L395-415：tocMap[primaryStr()] 写入（章数
                    // 上限守卫在缓存内）。完整条目要求携带详情（apply 需要
                    // tocUrl 解析 + 字段更新 + 变量合并）：load_info 已抓则复用，
                    // 否则补抓一次（与 apply 2a 同一调用形态）
                    let cache_info = match prefetched_info.take() {
                        Some(info) => Some(info),
                        None => fetcher
                            .get_book_info_with_existing_and_vars(
                                source,
                                &book_url,
                                false,
                                &candidate.book_name,
                                &candidate.author,
                                &detail_vars,
                            )
                            .await
                            .ok(),
                    };
                    self.prefetch_cache_insert(
                        &source.book_source_url,
                        &book_url,
                        cache_info,
                        chapters,
                    );
                }
                Ok(_) => {}
                Err(_) => {}
            }
        }

        candidate
    }
}

async fn apply_word_count_sample(
    candidate: &mut SearchCandidate,
    source: &BookSource,
    engine: &impl legado_core::web_book::BookSourceFetcher,
    chapters: &[WebChapter],
) {
    let chapter_index = chapters.len().saturating_sub(1);
    let chapter = &chapters[chapter_index];
    let mut title = chapter.title.trim().to_string();
    if title.chars().count() > 20 {
        title = format!("{}…", title.chars().take(20).collect::<String>());
    }
    let start = std::time::Instant::now();
    let web_ch = WebChapter {
        url: chapter.url.clone(),
        title: chapter.title.clone(),
        index: chapter.index,
        is_vip: chapter.is_vip,
        is_volume: chapter.is_volume,
        variable: chapter.variable.clone(),
        word_count: None,
    };
    let (count, text) = match engine.get_content(source, &web_ch).await {
        Ok(content) => {
            let len = content.chars().count() as i32;
            (
                len,
                format!("[{}] {}\n字数：{}", chapter_index + 1, title, len),
            )
        }
        Err(e) => (
            -1,
            format!("[{}] {}\n获取字数失败：{}", chapter_index + 1, title, e),
        ),
    };
    candidate.chapter_word_count = count;
    candidate.chapter_word_count_text = Some(text);
    candidate.respond_time = start.elapsed().as_millis() as i32;
}
