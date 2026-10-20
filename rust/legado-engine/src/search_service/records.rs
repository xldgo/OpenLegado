//! 结果转换、阅读记录索引与所属数据库持久化。
use super::*;
use legado_db::ReadRecordRepository;
use legado_db::repository::read_record_repository::decode_read_record_authors;

pub fn result_to_search_book(r: SearchResult) -> CoreSearchBook {
    CoreSearchBook {
        book_url: r.book_url,
        origin: r.source_url,
        origin_name: r.source_name,
        book_type: r.book_type,
        name: r.book_name,
        author: r.author,
        kind: r.kind,
        cover_url: r.cover_url,
        intro: r.intro,
        word_count: r.word_count,
        latest_chapter_title: r.latest_chapter,
        toc_url: String::new(),
        time: chrono_now_ms(),
        // [T5] 搜索期级联变量随 SearchBook 落库（换源读库路径复用）
        variable: r.variable,
        // [P0-2 S4] 透传真实书源排序（原恒写 0，违反数据契约约束 #4）
        origin_order: r.origin_order,
        chapter_word_count_text: None,
        chapter_word_count: -1,
        respond_time: -1,
        book_score: 0,
        // 阅读记录标识（由 api::search 批量附加后透传）
        has_read_record: r.has_read_record,
        read_record_author: r.read_record_author,
        // 跨源聚合 origins（队列⑩a P1-1 项2 加法式字段）：解析/批次路径不填充，
        // 仅聚合入口 aggregate_search_books_json 产出时非空
        origins: Vec::new(),
    }
}

pub fn persist_search_books(storage: Option<&StorageContext>, books: &[CoreSearchBook]) {
    let Some(storage) = storage else {
        return;
    };
    if books.is_empty() {
        return;
    }
    let _ = storage.with_database(|db| {
        let repo = legado_db::SearchBookRepository::new(db.connection());
        let _ = repo.insert_all(books);
        Ok(())
    });
}

fn chrono_now_ms() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

pub struct ReadRecordIndex {
    /// 书名 -> 阅读记录中的作者列表（旧记录/无作者时为空列表）
    authors: HashMap<String, Vec<String>>,
}

impl ReadRecordIndex {
    pub fn load_from(storage: Option<&StorageContext>) -> Self {
        let records = storage
            .and_then(|storage| {
                storage
                    .with_database(|db| ReadRecordRepository::new(db.connection()).find_all())
                    .ok()
            })
            .unwrap_or_default();
        Self::of(records)
    }

    /// 由记录列表构建索引（对齐上游 `ReadRecordIndex.of`）
    ///
    /// 注意：上游 `ReadRecordAuthors.decode` 对空白 author 返回 {""}，
    /// 索引中保留空串占位以表达「旧记录无作者 → 按书名命中任意作者」；
    /// Rust 侧解码返回空列表时需补上空串占位保持等价。
    pub fn of(records: Vec<legado_db::repository::read_record_repository::ReadRecord>) -> Self {
        let mut authors: HashMap<String, Vec<String>> = HashMap::new();
        for record in records {
            let mut decoded = decode_read_record_authors(&record.author);
            if decoded.is_empty() {
                decoded.push(String::new());
            }
            authors.entry(record.book_name).or_default().extend(decoded);
        }
        Self { authors }
    }

    /// 查询书籍是否有阅读记录（对齐上游 `ReadRecordIndex.contains`）
    pub fn contains(&self, name: &str, author: &str) -> bool {
        let Some(record_authors) = self.authors.get(name) else {
            return false;
        };
        let author = author.trim();
        if author.is_empty() {
            return true;
        }
        record_authors
            .iter()
            .any(|a| a.trim().is_empty() || a == author)
    }

    /// 查询并返回（是否有记录, 记录中的作者展示串）
    ///
    /// 作者展示串仅在有记录时返回：多作者以顿号连接，
    /// 记录无作者信息时为 None。
    pub fn lookup(&self, name: &str, author: &str) -> (bool, Option<String>) {
        if !self.contains(name, author) {
            return (false, None);
        }
        let display = self
            .authors
            .get(name)
            .map(|list| {
                list.iter()
                    .filter(|a| !a.trim().is_empty())
                    .cloned()
                    .collect::<Vec<_>>()
                    .join("、")
            })
            .filter(|s| !s.is_empty());
        (true, display)
    }
}

pub fn annotate_results(results: &mut [SearchResult], index: &ReadRecordIndex) {
    for item in results.iter_mut() {
        let (has_record, record_author) = index.lookup(&item.book_name, &item.author);
        item.has_read_record = has_record;
        item.read_record_author = record_author;
    }
}

pub fn build_annotated_candidate(c: SearchResult, index: &ReadRecordIndex) -> AnnotatedCandidate {
    let (has_record, record_author) = index.lookup(&c.book_name, &c.author);
    AnnotatedCandidate {
        book_name: c.book_name,
        author: c.author,
        cover_url: c.cover_url,
        intro: c.intro,
        latest_chapter: c.latest_chapter,
        source_url: c.source_url,
        source_name: c.source_name,
        book_url: c.book_url,
        relevance_score: 0.0,
        origin_order: c.origin_order,
        has_read_record: has_record,
        read_record_author: record_author,
        variable: c.variable,
    }
}

pub fn extract_cover_candidates(results: Vec<SearchResult>) -> Vec<CoverCandidate> {
    let mut seen: HashSet<String> = HashSet::new();
    let mut candidates: Vec<CoverCandidate> = Vec::new();
    for item in results {
        if let Some(url) = item.cover_url
            && !url.is_empty()
            && seen.insert(url.clone())
        {
            candidates.push(CoverCandidate {
                url,
                width: 0,
                height: 0,
            });
        }
    }
    candidates
}

/// 搜索结果到换源候选的统一转换，沿用调用来源的排序编号。
pub fn result_to_candidate(r: SearchResult, origin_order: i32) -> SearchCandidate {
    SearchCandidate {
        source_url: r.source_url,
        source_name: r.source_name,
        book_url: r.book_url,
        book_name: r.book_name,
        author: r.author,
        latest_chapter: r.latest_chapter,
        word_count: r.word_count,
        chapter_word_count_text: None,
        chapter_word_count: -1,
        respond_time: -1,
        origin_order,
        book_score: 0,
        variable: r.variable,
    }
}
