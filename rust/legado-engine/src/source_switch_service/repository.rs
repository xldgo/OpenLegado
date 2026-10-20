//! 候选查询、配置、评分与持久化；只使用所属服务的数据能力。
use super::*;

impl SourceSwitchService {
    pub(super) fn try_load_change_source_from_db(
        &self,
        book_name: &str,
        author: &str,
        options: &SwitchSearchOptions,
    ) -> Option<Vec<SourceMatch>> {
        self.storage.as_ref()?;
        let check_author = self.config("changeSourceCheckAuthor").trim() == "true";
        let search_group = self.config("searchGroup").trim().to_string();
        let author_filter = if check_author {
            legado_core::book_help::format_book_author(author)
        } else {
            String::new()
        };
        // [审计 D6 | ChangeBookSourceViewModel.kt:603-625] 原版 getDbSearchBooks 以
        // 原样 book.name 查询（不做归一化）；库内书名在解析期已经 formatBookName，
        // 查询参数不再二次归一化
        log::info!(
            "换源读库: name={} author_filter={} searchGroup={}",
            book_name,
            author_filter,
            search_group
        );

        let books = self
            .database(|db| {
                let repo = legado_db::SearchBookRepository::new(db.connection());
                repo.change_source_by_group(book_name, &author_filter, &search_group)
            })
            .ok()?;

        if books.is_empty() {
            return None;
        }

        let candidates: Vec<SearchCandidate> = books
            .into_iter()
            .map(|b| SearchCandidate {
                source_url: b.origin,
                source_name: b.origin_name,
                book_url: b.book_url,
                book_name: b.name,
                author: b.author,
                latest_chapter: b.latest_chapter_title,
                word_count: b.word_count,
                chapter_word_count_text: b.chapter_word_count_text,
                chapter_word_count: b.chapter_word_count,
                respond_time: b.respond_time,
                origin_order: b.origin_order,
                book_score: b.book_score,
                // [T5] 读库路径：searchBooks 行的搜索期级联变量
                variable: b.variable,
            })
            .collect();

        // 读库路径不再二次过滤（SQL 已按名/作者/分组筛过）；直接评分排序
        let matches = SourceMatcher::rank_candidates_with_options(
            candidates,
            book_name,
            author,
            options.load_word_count,
        );
        if matches.is_empty() {
            None
        } else {
            Some(matches)
        }
    }

    pub(super) fn clear_search_books_for_change(&self, book_name: &str, author: &str) {
        if self.storage.is_none() {
            return;
        }
        let check_author = self.config("changeSourceCheckAuthor").trim() == "true";
        let author_filter = if check_author {
            legado_core::book_help::format_book_author(author)
        } else {
            String::new()
        };
        let normalized_name = legado_core::book_help::format_book_name(book_name);
        self.publish(|| {
            let _ = self.database(|db| {
                let repo = legado_db::SearchBookRepository::new(db.connection());
                let _ = repo.clear_by_name_author(&normalized_name, &author_filter);
                Ok(())
            });
        });
    }

    pub fn resolve_switch_sources_selected(
        &self,
        urls: &[String],
    ) -> LegadoResult<Vec<BookSource>> {
        let sources =
            crate::source_catalog::load_search_sources_selected_from(self.storage.as_ref(), urls)?;
        Ok(self.filter_sources_by_search_group(sources))
    }

    pub(super) fn filter_sources_by_search_group(
        &self,
        sources: Vec<BookSource>,
    ) -> Vec<BookSource> {
        let group = self.config(SEARCH_GROUP_CONFIG_KEY);
        let target = group.trim();
        if target.is_empty() {
            return sources;
        }
        sources
            .into_iter()
            .filter(|s| source_group_contains(s.book_source_group.as_deref().unwrap_or(""), target))
            .collect()
    }

    pub(super) fn config_flag(&self, key: &str) -> bool {
        self.config(key).trim() == "true"
    }

    pub fn persist_switch_matches(&self, matches: &[SourceMatch]) {
        if matches.is_empty() || self.storage.is_none() {
            return;
        }
        use legado_core::models::SearchBook;
        use std::time::{SystemTime, UNIX_EPOCH};
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);
        let books: Vec<SearchBook> = matches
            .iter()
            .map(|m| SearchBook {
                book_url: m.book_url.clone(),
                origin: m.source_url.clone(),
                origin_name: m.source_name.clone(),
                name: m.book_name.clone(),
                author: m.author.clone(),
                word_count: m.word_count.clone(),
                latest_chapter_title: m.latest_chapter.clone(),
                time: now,
                origin_order: m.origin_order,
                chapter_word_count_text: m.chapter_word_count_text.clone(),
                chapter_word_count: m.chapter_word_count,
                respond_time: m.respond_time,
                book_score: m.book_score,
                // [R1 修复 2026-09-06] 落库必须带候选搜索期变量：switch_book_source
                // 按 (new_book_url, origin) 回查 searchBooks 取候选变量（对齐原版
                // SearchBook.toBook() 复制 variable），此前 `..default()` 丢字段导致
                // 网络路径与读库路径的候选变量双双丢失，变量依赖源换源后目录/正文
                // 请求打错地址（内容错书的链路根因）
                variable: m.variable.clone(),
                ..SearchBook::default()
            })
            .collect();
        self.publish(|| {
            let _ = self.database(|db| {
                let repo = legado_db::SearchBookRepository::new(db.connection());
                let _ = repo.insert_all(&books);
                Ok(())
            });
        });
    }
}

fn source_group_contains(source_group: &str, target: &str) -> bool {
    let normalized: String = source_group
        .chars()
        .map(|c| match c {
            ';' | '；' | '，' => ',',
            other => other,
        })
        .collect();
    normalized.split(',').any(|name| name.trim() == target)
}

impl SourceSwitchService {
    pub fn default_options(&self) -> SwitchSearchOptions {
        SwitchSearchOptions {
            load_info: self.config_flag("changeSourceLoadInfo"),
            load_toc: self.config_flag("changeSourceLoadToc"),
            load_word_count: self.config_flag("changeSourceLoadWordCount"),
            force_refresh: false,
        }
    }

    pub fn update_search_book_score(&self, book_url: &str, score: i32) -> LegadoResult<()> {
        let book_url = book_url.trim();
        if book_url.is_empty() {
            return Err(LegadoError::Database("bookUrl 不能为空".into()));
        }
        if !(-1..=1).contains(&score) {
            return Err(LegadoError::Database("评分仅允许 -1/0/1".into()));
        }
        if self.storage.is_none() {
            return Err(LegadoError::Database("数据库未初始化".into()));
        }
        let change = self.database(|db| {
            let repo = legado_db::SearchBookRepository::new(db.connection());
            let pre = repo
                .find_by_book_url(book_url)?
                .map(|b| b.book_score)
                .unwrap_or(0);
            if repo.update_book_score(book_url, score)? == 0 {
                return Err(LegadoError::Database(format!(
                    "searchBooks 中不存在 bookUrl={book_url}"
                )));
            }
            Ok(repo.find_by_book_url(book_url)?.map(|b| (b.origin, pre)))
        })?;
        // 归还当前连接后再同步配置，单连接独立实例也不嵌套借连接。
        if let Some((origin, pre)) = change {
            self.sync_source_score_delta(&origin, pre, score);
        }
        Ok(())
    }

    pub fn delete_search_book(&self, book_url: &str) -> LegadoResult<()> {
        let book_url = book_url.trim();
        if book_url.is_empty() {
            return Err(LegadoError::Database("bookUrl 不能为空".into()));
        }
        if self.storage.is_none() {
            return Err(LegadoError::Database("数据库未初始化".into()));
        }
        self.database(|db| {
            let repo = legado_db::SearchBookRepository::new(db.connection());
            let affected = repo.delete_by_book_url(book_url)?;
            if affected == 0 {
                return Err(LegadoError::Database(format!(
                    "searchBooks 中不存在 bookUrl={book_url}"
                )));
            }
            Ok(())
        })
    }

    fn sync_source_score_delta(&self, origin: &str, pre_score: i32, new_score: i32) {
        let delta = if pre_score != 0 {
            new_score - pre_score
        } else {
            new_score
        };
        if delta == 0 {
            return;
        }
        let cur = self
            .database(|db| {
                legado_db::CacheRepository::new(db.connection()).get(&format!("config:{origin}"))
            })
            .map(|v| v.unwrap_or_default())
            .ok()
            .and_then(|v| v.parse::<i32>().ok())
            .unwrap_or(0);
        let _ = self.database(|db| {
            legado_db::CacheRepository::new(db.connection()).put(
                &format!("config:{origin}"),
                &(cur + delta).to_string(),
                0,
            )
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    /// Task #145（留项#12）：分组包含判定纯语义单测
    #[test]
    fn test_source_group_contains_membership() {
        // 逗号分隔多组：首/尾/中间组均命中
        assert!(source_group_contains("玄幻,仙侠,都市", "玄幻"));
        assert!(source_group_contains("玄幻,仙侠,都市", "都市"));
        assert!(source_group_contains("玄幻,仙侠,都市", "仙侠"));
        // 组名两侧空白（含全角空格）trim 后命中
        assert!(source_group_contains("玄幻, 仙侠", "仙侠"));
        assert!(source_group_contains("玄幻,\u{3000}仙侠", "仙侠"));
        // 分隔符规范化：`;`/`；`/`，` 等同逗号
        assert!(source_group_contains("玄幻;仙侠；都市，科幻", "科幻"));
        // 精确匹配：不做子串匹配（原版逐组名相等判定）
        assert!(!source_group_contains("玄幻仙侠", "玄幻"));
        assert!(!source_group_contains("玄幻", "幻"));
        // 空分组字段不命中任何目标
        assert!(!source_group_contains("", "玄幻"));
        assert!(!source_group_contains("  ,  ", "玄幻"));
    }
}
