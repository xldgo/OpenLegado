//! 目录读取、刷新及事务提交。
use super::*;
impl ReadingService {
    pub fn get_chapters(&self, book_url: &str) -> LegadoResult<ChapterListResponse> {
        // 1. 尝试从数据库读取已有章节
        let chapters = self.with_database(|db| {
            let repo = BookChapterRepository::new(db.connection());
            repo.find_by_book_url(book_url)
        })?;

        if !chapters.is_empty() {
            let mut chapters = chapters;
            self.apply_title_convert(&mut chapters);
            let total = chapters.len() as i32;
            return Ok(ChapterListResponse { total, chapters });
        }

        // 2. 数据库无章节：如果是本地书籍，从文件解析并入库
        if is_local_book(book_url) {
            // [C1] 还原为真实文件路径（相对标识 → 当前 Documents；绝对原样）
            let real_path = (self.resources.resolve_path)(book_url);
            let chapter_infos = legado_book::LocalBook::get_chapters(&real_path)?;
            let mut book_chapters: Vec<BookChapter> = chapter_infos
                .iter()
                .map(|ci| BookChapter {
                    url: ci.url.clone(),
                    title: ci.title.clone(),
                    is_volume: ci.is_volume,
                    base_url: book_url.to_string(),
                    book_url: book_url.to_string(),
                    index: ci.index,
                    is_vip: false,
                    is_pay: false,
                    resource_url: None,
                    tag: None,
                    word_count: None,
                    start: ci.start,
                    end: ci.end,
                    start_fragment_id: None,
                    end_fragment_id: None,
                    variable: None,
                    img_url: None,
                })
                .collect();

            // 存入数据库供后续访问
            if !book_chapters.is_empty() {
                // [B-13b] 懒加载入库同时同步 books 行目录派生字段（totalChapterNum /
                // latestChapterTitle / latestChapterTime）：修复前仅写章节行，books
                // 行派生字段停留 0/NULL → 书架章节数与最新章节显示为空。
                // latestChapterTime 仅章数增长时写入（对齐 refresh_toc 的增长条件
                // 分支）；books 行不存在时 no-op（书架入口 add_book 已建行）。
                let new_total = book_chapters.len() as i32;
                let new_latest_title: Option<String> =
                    book_chapters.last().map(|c| c.title.clone());
                self.with_database(|db| {
                    let conn = db.connection();
                    let repo = BookChapterRepository::new(conn);
                    repo.insert_batch(&book_chapters)?;
                    let book_repo = BookRepository::new(conn);
                    if let Some(existing) = book_repo.find_by_url(book_url)? {
                        book_repo.update_toc_derived_fields(
                            book_url,
                            new_total,
                            new_latest_title.as_deref(),
                            (existing.total_chapter_num < new_total).then_some(now_millis()),
                        )?;
                    }
                    Ok(())
                })?;
            }

            // 显示层标题繁简转换（不回写数据库）
            self.apply_title_convert(&mut book_chapters);

            let total = book_chapters.len() as i32;
            return Ok(ChapterListResponse {
                total,
                chapters: book_chapters,
            });
        }

        // 3. 在线书籍无章节记录，返回空
        Ok(ChapterListResponse {
            total: 0,
            chapters: vec![],
        })
    }
    pub fn refresh_toc_with_fetcher<F: BookSourceFetcher>(
        &self,
        book_url: &str,
        source_url: &str,
        engine: &WebBookEngine<F>,
    ) -> LegadoResult<ChapterListResponse> {
        // [性能专项 2026-09-24] 刷新代数 +1：本刷新成为最新代数，使在途旧刷新的
        // 目录分页链在下一页边界判活失败而中止（换源场景取消 10 分钟在途链；
        // 对齐上游 ensureActive() 判活语义，无状态 FFI 用进程级原子计数器，
        // 不改 FFI 签名）。
        legado_fetcher::web_book::bump_toc_fetch_epoch(&self.resources.web_book);
        // 1. 从数据库获取书源配置 + 书籍记录（书籍用于确定真实的目录抓取 URL）
        let (source, existing_book) = self.with_database(|db| {
            let source = BookSourceRepository::new(db.connection()).find_by_url(source_url)?;
            let book = legado_db::BookRepository::new(db.connection()).find_by_url(book_url)?;
            Ok((source, book))
        })?;
        let source =
            source.ok_or_else(|| LegadoError::Database(format!("书源不存在: {source_url}")))?;

        // Task #21 修复：抓取目录用书籍的 tocUrl，而非 bookUrl。换源后 bookUrl 作为
        // 稳定主键保持旧源 URL（在新源上并非有效地址），tocUrl 才指向当前书源的
        // 详情/目录页；用 bookUrl 抓取会把旧源 URL 传给新源解析器导致目录获取失败
        // （用户反馈「目录也获取不到」的根因之一）。tocUrl 为空时回退 bookUrl，
        // 对齐原版 WebBook.getChapterList 以 book.tocUrl 为目录页地址的行为。
        // [P2-8] 回退链细化为 tocUrl → originBookUrl（当前书源详情页，换源事务
        // 写入；tocUrl 可能已被坏值污染或为空）→ bookUrl（未换源书籍/存量库，
        // 行为不变）。
        // 目录更新前钩子（对齐 WebBook.getChapterListAwait(runPerJs=true) → runPreUpdateJs）
        // 须在计算 fetch_url 之前执行，以便 reGetBook/refreshTocUrl/手写改 book 生效
        let mut working_book = existing_book.clone();
        if let Some(ref mut book) = working_book {
            if let Err(e) = self.run_pre_update_js(&source, book) {
                eprintln!("[refresh_toc] preUpdateJs: {e}");
            } else {
                // 持久化 preUpdateJs / 钩子对 bookUrl·tocUrl·variable 等的改写。
                // [B-4] 这是全行快照写回，但 `update` 的 UPDATE SET 结构性排除
                // 进度列（B-3），钩子执行/持久化期间并发写入的进度不会被回退
                // （此处零代码改动，靠结构排除保护进度）。
                let _ = self.with_database(|db| {
                    legado_db::BookRepository::new(db.connection()).update(book)
                });
            }
        }

        let fetch_url = working_book
            .as_ref()
            .map(|b| {
                let toc = b.toc_url.trim();
                if !toc.is_empty() {
                    toc.to_string()
                } else {
                    // [P2-8] 书籍页取址（originBookUrl 优先、空回退 bookUrl，见
                    // Book::book_page_fetch_url）；两者皆空时回退入参 book_url
                    let origin = b.book_page_fetch_url();
                    if origin.trim().is_empty() {
                        book_url.to_string()
                    } else {
                        origin.to_string()
                    }
                }
            })
            .unwrap_or_else(|| book_url.to_string());

        // [P2-12 2026-09-18] 变量链：目录/详情请求模板经 DB `books.variable`
        // （working_book.variable——preUpdateJs 钩子运行后已持久化的用户值）
        // 展开。优先级：DB 持久化值（用户显式设置）> 书源 `@put` 默认导出，
        // 与换源链 P1-1 理由一致（本刷新路径无 @put 再合并，仅更新目录）。
        // 修复前两处 get_chapters 变量表恒空 → 换源后重进详情/刷新目录时
        // `{{svid}}`/`{{tok}}` 展开为空 → 请求错误地址（服务端 400）。
        let toc_variables = legado_fetcher::web_book::chapter_url_variables(
            working_book.as_ref().and_then(|b| b.variable.as_deref()),
        );

        // 2. 使用 WebBookEngine 从网络获取章节列表（变量表见上方 P2-12 注释）
        // [bookUrl 脏值修正 2026-10-05] 身份/取址点分离：本入口的 `book_url` 入参
        // 是书籍稳定主键（DB `find_by_url` 查询键），`fetch_url` 只是取址点
        //（tocUrl / 书籍页取址点 / 回退 bookUrl）。旧调用把取址点当 book_url 传给
        // fetcher → 目录阶段 meta 缓存把 tocUrl 记成“书籍取址点”并经 (书源, 章节)
        // 反查泄漏到正文阶段 `book` 绑定与媒体副内容 sink（弹幕/歌词落库键，
        // V-B1 审查已登记的静默丢弹幕面）。对齐原版 WebBook.getChapterListAwait
        //（book.bookUrl 主键 + book.tocUrl 取址点二元语义，WebBook.kt:310-326）。
        let book_key = book_url;
        let mut web_chapters: Vec<WebChapter> = self.resources.runtime.block_on(async {
            engine
                .get_chapters_with_book_key_and_vars(
                    &source,
                    &fetch_url,
                    book_key,
                    None,
                    None,
                    &toc_variables,
                )
                .await
        })?;

        // [P2-2 | 存量坏 tocUrl 自愈 2026-09-18] 首次抓取（通常按 tocUrl）未解析到
        // 章节（存量坏值：如换源后 tocUrl 仍指向旧源页面、页面改版后不再含目录），
        // 且书籍页取址点（book_page_fetch_url：originBookUrl 优先、空回退 bookUrl）
        // 与已尝试的抓取地址不同 → 按书籍页地址重试一次；成功则把新 tocUrl 持久化
        //（对齐既有 update 语义：tocUrl 为当前书源目录页地址），后续刷新直达有效
        // 地址。`!= fetch_url` 同时覆盖「tocUrl 为空、首抓地址已是书籍页取址点」
        // 的情形，避免对同一地址重复抓取。
        if web_chapters.is_empty() {
            let retry_url = working_book
                .as_ref()
                .map(|b| b.book_page_fetch_url().to_string())
                .filter(|u| !u.trim().is_empty() && *u != fetch_url);
            if let Some(retry_url) = retry_url {
                // [P2-12] 重试同样携 DB 变量表（retry_url 为书籍页取址点，
                // 可能含 {{key}} 模板）
                // [bookUrl 脏值修正] 重试仍以 `book_url` 为主键、retry_url 为取址点
                match self.resources.runtime.block_on(async {
                    engine
                        .get_chapters_with_book_key_and_vars(
                            &source,
                            &retry_url,
                            book_key,
                            None,
                            None,
                            &toc_variables,
                        )
                        .await
                }) {
                    Ok(chapters) if !chapters.is_empty() => {
                        // 持久化新 tocUrl；写库失败仅记录，不影响本次刷新结果。
                        // P2-1：改用单列 update_toc_url（全行 update 会把两次网络
                        // 抓取前读取的 37 列快照写回：期间并发写入的进度列
                        // （durChapterIndex 等）被旧值覆盖，且「本来正确但一次
                        // 瞬时解析为空」的 tocUrl 会被永久改写）。
                        if let Some(b) = working_book.as_mut() {
                            b.toc_url = retry_url.clone();
                            let book_url_key = b.book_url.clone();
                            let _ = self.with_database(|db| {
                                legado_db::BookRepository::new(db.connection())
                                    .update_toc_url(&book_url_key, &retry_url)
                            });
                        }
                        web_chapters = chapters;
                    }
                    _ => {}
                }
            }
        }

        // Task #21 修复：空结果保护。新抓取未解析到任何章节时（get_chapters 返回
        // Ok(vec![]) 而非错误，如书源失效/页面改版），绝不清空已有目录——否则会把
        // 书留成「无章节」状态，比刷新前更糟（换源/刷新「越刷越糟」回归）。
        // 有旧章节则原样返回旧目录；无旧章节才返回可读错误。
        if web_chapters.is_empty() {
            let existing = self.with_database(|db| {
                BookChapterRepository::new(db.connection()).find_by_book_url(book_url)
            })?;
            if !existing.is_empty() {
                let mut existing = existing;
                self.apply_title_convert(&mut existing);
                let total = existing.len() as i32;
                return Ok(ChapterListResponse {
                    total,
                    chapters: existing,
                });
            }
            return Err(LegadoError::Parser(
                "刷新目录失败：未从书源解析到任何章节（书源可能失效，请尝试换源）".into(),
            ));
        }

        // 3. 转换为 BookChapter 并存入数据库
        let book_chapters: Vec<BookChapter> = web_chapters
            .iter()
            .map(|wc| BookChapter {
                url: wc.url.clone(),
                title: wc.title.clone(),
                is_volume: false,
                base_url: book_url.to_string(),
                book_url: book_url.to_string(),
                index: wc.index,
                is_vip: wc.is_vip,
                is_pay: false,
                resource_url: None,
                tag: None,
                // N5: 字数透传（WebChapter.word_count 来自 updateTime 规则/JS 源）
                word_count: wc.word_count.clone(),
                start: None,
                end: None,
                start_fragment_id: None,
                end_fragment_id: None,
                variable: wc.variable.clone(),
                img_url: None,
            })
            .collect();

        // [目录派生字段同步] 对齐上游 updateBookTocInfo：刷新成功后 books 行
        // totalChapterNum = 新目录章数 / latestChapterTitle = 末章标题（截断保留
        // 前缀时 = 前缀章数，与上游一致；空结果不会走到这里——上方守卫已提前
        // 返回）。latestChapterTime 仅章数增长时写入（上游条件分支）。真实 origin
        // 书籍走单列 UPDATE 写器（只触碰派生字段，不写进度列——B-3 安全，P2-1
        // 风格）；占位/本地 origin 路径在同一内存对象上同步（全行写结构性排除
        // 进度列，B-3 安全）。
        let new_total = book_chapters.len() as i32;
        let new_latest_title: Option<String> = book_chapters.last().map(|c| c.title.clone());

        // 4. 确保书籍记录存在（满足 chapters 表外键约束），然后先删除旧章节，再批量插入新章节
        // [Task #66 加固] 占位落库须带书源信息（origin/originName）：否则 origin 取默认
        // loc_book，阅读器随后按 origin 找书源取正文会报「书源不存在: loc_book」
        // （搜索→目录页→点章节进入阅读的路径，此时 Flutter 尚未执行带 origin 的
        // addBook）。既有记录 origin 仍为默认值时同样补齐（加法式，不覆盖已有真实书源）。
        self.with_database(|db| {
            let conn = db.connection();
            // [B-7] 「删旧章节 + 写新章节 + 清失效缓存」包进同一事务：裸 autocommit
            // 删除会向并发读者暴露「0 章」中间态（对齐换源事务模式）。
            // delete_by_book_url 事务外为 no-op（见 BookChapterRepository）；
            // pool 共享 &Connection 无法用 &mut Connection::transaction()，
            // 沿用项目既有的 unchecked_transaction() 模式（见 source_switch.rs）。
            let tx = conn
                .unchecked_transaction()
                .map_err(|e| LegadoError::Database(format!("开启目录更新事务失败: {e}")))?;
            let book_repo = legado_db::BookRepository::new(conn);
            match book_repo.find_by_url(book_url)? {
                None => {
                    // Task#125：占位落库须打 NOT_SHELF，对齐原版 readBook 临时书 /
                    // 书架 list_books 过滤；否则「仅浏览/拉目录」会污染书架。
                    let mut book = legado_core::models::Book {
                        book_url: book_url.to_string(),
                        origin: source_url.to_string(),
                        origin_name: source.book_source_name.clone(),
                        book_type: legado_core::models::book::book_type::NOT_SHELF,
                        ..legado_core::models::Book::default()
                    };
                    // [目录派生字段同步] 新书无旧章数（0 < new_total 恒成立——
                    // 目录非空守卫在前）→ 派生字段随插入一并写入
                    book.total_chapter_num = new_total;
                    book.latest_chapter_title = new_latest_title.clone();
                    book.latest_chapter_time = now_millis();
                    book_repo.insert(&book)?;
                }
                Some(mut existing)
                    if existing.origin.is_empty()
                        || existing.origin == legado_core::models::book::book_type::LOCAL_TAG =>
                {
                    existing.origin = source_url.to_string();
                    if existing.origin_name.is_empty() {
                        existing.origin_name = source.book_source_name.clone();
                    }
                    // [目录派生字段同步] 同一内存对象上同步（全行 update 结构性
                    // 排除进度列，B-3 安全）
                    let old_total = existing.total_chapter_num;
                    existing.total_chapter_num = new_total;
                    existing.latest_chapter_title = new_latest_title.clone();
                    if old_total < new_total {
                        existing.latest_chapter_time = now_millis();
                    }
                    book_repo.update(&existing)?;
                }
                Some(existing) => {
                    // [目录派生字段同步] 真实 origin 书籍：单条 UPDATE 只触碰派生
                    // 字段（不写进度列、不回退抓取前快照的其他列，B-3/P2-1 安全）；
                    // latestChapterTime 仅章数增长时写（上游条件分支）
                    book_repo.update_toc_derived_fields(
                        book_url,
                        new_total,
                        new_latest_title.as_deref(),
                        (existing.total_chapter_num < new_total).then_some(now_millis()),
                    )?;
                }
            }
            let repo = BookChapterRepository::new(conn);
            repo.delete_by_book_url(book_url)?;
            repo.insert_batch_no_tx(&book_chapters)?;
            // [B-5] 目录变更后清理失效缓存（同事务）：章节 URL 已不在新目录中的
            // 缓存行删除，URL 未变的章节保留缓存（不强制重抓）
            legado_db::CacheBookRepository::new(conn).clear_stale_chapter_urls(book_url)?;
            tx.commit()
                .map_err(|e| LegadoError::Database(format!("提交目录更新事务失败: {e}")))?;
            Ok(())
        })?;

        // [B-6] 目录重写后按当前书源登记 (书源, 章节) → 下一章 URL：正文分页
        // 「命中下一章即截断」需按最新目录判定。本入口（refresh_toc）不经
        // web_book 的章节列表缓存链（record_chapter_list_cache），须在此显式登记；
        // registry 复合键 (书源, 章节) 天然隔离旧源登记，重复登记幂等。
        legado_fetcher::web_book::record_next_chapter_map(
            &self.resources.web_book,
            source_url,
            &web_chapters,
        );

        // 显示层标题繁简转换（入库的是原始标题，仅转换返回副本）
        let mut book_chapters = book_chapters;
        self.apply_title_convert(&mut book_chapters);

        let total = book_chapters.len() as i32;
        Ok(ChapterListResponse {
            total,
            chapters: book_chapters,
        })
    }
    pub(super) fn get_chapter_index_title_variable(
        &self,
        book_url: &str,
        chapter_url: &str,
    ) -> LegadoResult<(i32, String, Option<String>, bool)> {
        let chapters = self.with_database(|db| {
            let repo = BookChapterRepository::new(db.connection());
            repo.find_by_book_url(book_url)
        })?;
        Ok(match chapters.iter().find(|ch| ch.url == chapter_url) {
            Some(ch) => (ch.index, ch.title.clone(), ch.variable.clone(), true),
            None => (0, String::new(), None, false),
        })
    }
}
