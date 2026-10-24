//! 高亮体系 FFI API
//!
//! 暴露正文高亮（highlights 表）与高亮规则（highlightRules 表）的 CRUD 能力，
//! 正式 FFI 直接传输实体，不维护无生产消费者的 JSON 保存入口。
//!
//! 对应 Android 原版 `BookHighlightDao` / `HighlightRuleDao`。

use legado_core::LegadoResult;
use legado_core::models::{BookHighlight, HighlightRule};
use legado_db::{HighlightRepository, HighlightRuleRepository};

use crate::db_state::with_database;

// ─── 高亮记录 CRUD ────────────────────────────────────────────

/// 新增/更新高亮记录（INSERT OR REPLACE，主键为 time）
///
/// time 为 0 时自动分配当前 Unix 毫秒时间戳。返回保存后的 time。
pub fn highlight_add(highlight: BookHighlight) -> LegadoResult<i64> {
    let fallback_time = if highlight.time == 0 {
        current_time_millis()
    } else {
        highlight.time
    };
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.insert_with_fallback_time(highlight, fallback_time)
    })
}

/// 按主键 time 删除高亮记录，返回是否实际删除
pub fn highlight_delete(time: i64) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.delete(time)
    })
}

/// 按书籍删除全部高亮记录，返回删除数量
pub fn highlight_delete_by_book(book_url: &str) -> LegadoResult<i64> {
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.delete_by_book(book_url)
    })
}

/// 按书籍获取高亮列表（按 chapterIndex/chapterPos/time 排序）
pub fn highlight_list_by_book(book_url: &str) -> LegadoResult<Vec<BookHighlight>> {
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.get_by_book(book_url)
    })
}

/// 按书籍 + 章节索引获取高亮列表
pub fn highlight_list_by_chapter(
    book_url: &str,
    chapter_index: i32,
) -> LegadoResult<Vec<BookHighlight>> {
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.get_by_chapter(book_url, chapter_index)
    })
}

/// 全局关键词搜索高亮（匹配 chapterName/bookText/note）
pub fn highlight_search(keyword: &str) -> LegadoResult<Vec<BookHighlight>> {
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.search(keyword)
    })
}

/// 获取所有高亮记录（按书名/作者/章节/位置排序）
pub fn highlight_list_all() -> LegadoResult<Vec<BookHighlight>> {
    with_database(|db| {
        let repo = HighlightRepository::new(db.connection());
        repo.find_all()
    })
}

// ─── 高亮规则 CRUD ────────────────────────────────────────────

/// 获取所有高亮规则（按 sortOrder 升序）
pub fn highlight_rule_list() -> LegadoResult<Vec<HighlightRule>> {
    with_database(|db| {
        let repo = HighlightRuleRepository::new(db.connection());
        repo.find_all()
    })
}

/// 保存高亮规则（新增或按 ID 覆盖），返回规则 ID
///
/// id 为 0 时使用自增主键新增。
pub fn highlight_rule_save(rule: HighlightRule) -> LegadoResult<i64> {
    with_database(|db| {
        let repo = HighlightRuleRepository::new(db.connection());
        repo.insert(&rule)
    })
}

/// 按 ID 删除高亮规则，返回是否实际删除
pub fn highlight_rule_delete(id: i64) -> LegadoResult<bool> {
    with_database(|db| {
        let repo = HighlightRuleRepository::new(db.connection());
        repo.delete(id)
    })
}

/// 按书籍查找启用的高亮规则（scope 匹配书名或书源名，空 scope 全局生效）
pub fn highlight_rule_find_enabled(
    book_name: &str,
    origin: &str,
) -> LegadoResult<Vec<HighlightRule>> {
    with_database(|db| {
        let repo = HighlightRuleRepository::new(db.connection());
        repo.find_enabled_by_book(book_name, origin)
    })
}

/// 导入只消费经过统一解析/编辑的实体；数据库内再规范化并原子合并。
pub fn highlight_rule_import(rules: &[HighlightRule]) -> LegadoResult<usize> {
    with_database(|db| HighlightRuleRepository::new(db.connection()).import(rules))
}

pub fn highlight_rule_export() -> LegadoResult<String> {
    legado_core::highlight_rules::export_document(&highlight_rule_list()?)
}

/// 当前 Unix 毫秒时间戳
fn current_time_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_highlight_crud_flow() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 新增
        let json = r#"{
            "time": 0,
            "bookUrl": "bk://highlight_test",
            "chapterUrl": "ch://1",
            "bookName": "高亮测试书",
            "bookAuthor": "测试作者",
            "chapterIndex": 2,
            "chapterPos": 10,
            "chapterPosEnd": 25,
            "chapterName": "第三章",
            "bookText": "这是一段高亮文本",
            "style": "{}",
            "note": "测试笔记"
        }"#;
        let time = highlight_add(serde_json::from_str(json).unwrap()).unwrap();
        assert!(time > 0);

        // 按书籍查询
        let by_book = highlight_list_by_book("bk://highlight_test").unwrap();
        assert_eq!(by_book.len(), 1);
        assert_eq!(by_book[0].bookText, "这是一段高亮文本");

        // 按章节查询
        let by_chapter = highlight_list_by_chapter("bk://highlight_test", 2).unwrap();
        assert_eq!(by_chapter.len(), 1);

        // 关键词搜索
        let results = highlight_search("高亮文本").unwrap();
        assert!(results.iter().any(|h| h.bookUrl == "bk://highlight_test"));

        // 删除
        assert!(highlight_delete(time).unwrap());
        let by_book = highlight_list_by_book("bk://highlight_test").unwrap();
        assert_eq!(by_book.len(), 0);
    }

    #[test]
    fn test_highlight_delete_by_book() {
        let _db_guard = crate::db_state::ensure_test_db();

        for i in 0..2 {
            let json = format!(
                r#"{{"time": 0, "bookUrl": "bk://del_test", "chapterIndex": {i},
                     "bookName": "删除测试", "bookText": "t{i}"}}"#
            );
            highlight_add(serde_json::from_str(&json).unwrap()).unwrap();
        }
        assert_eq!(highlight_list_by_book("bk://del_test").unwrap().len(), 2);
        let deleted = highlight_delete_by_book("bk://del_test").unwrap();
        assert_eq!(deleted, 2);
    }

    #[test]
    fn test_highlight_rule_crud_flow() {
        let _db_guard = crate::db_state::ensure_test_db();

        // 新增规则（id=0 自增）
        let json = r#"{
            "name": "FFI测试规则",
            "pattern": "关键词",
            "isRegex": false,
            "isEnabled": true,
            "style": "{}",
            "sortOrder": 100,
            "timeoutMillisecond": 3000,
            "applyToTitle": false
        }"#;
        let id = highlight_rule_save(serde_json::from_str(json).unwrap()).unwrap();
        assert!(id > 0);

        // 列表包含新规则
        let rules = highlight_rule_list().unwrap();
        assert!(rules.iter().any(|r| r.id == id && r.name == "FFI测试规则"));

        // 按书籍查找启用规则
        let enabled = highlight_rule_find_enabled("", "").unwrap();
        assert!(enabled.iter().any(|r| r.id == id));

        // 覆盖保存（同 ID 更新）
        let update_json = format!(
            r#"{{"id": {id}, "name": "FFI测试规则-更新", "pattern": "新关键词",
                 "isRegex": true, "isEnabled": true, "style": "{{}}",
                 "sortOrder": 100, "timeoutMillisecond": 3000}}"#
        );
        let saved_id = highlight_rule_save(serde_json::from_str(&update_json).unwrap()).unwrap();
        assert_eq!(saved_id, id);
        let rules = highlight_rule_list().unwrap();
        let updated = rules.iter().find(|r| r.id == id).unwrap();
        assert_eq!(updated.name, "FFI测试规则-更新");
        assert!(updated.isRegex);

        // 删除
        assert!(highlight_rule_delete(id).unwrap());
        assert!(!highlight_rule_delete(id).unwrap());
    }

    #[test]
    fn test_default_entities_keep_unknown_title_and_rule_defaults() {
        let _db_guard = crate::db_state::ensure_test_db();
        let time = highlight_add(BookHighlight::default()).unwrap();
        let item = highlight_list_all()
            .unwrap()
            .into_iter()
            .find(|h| h.time == time)
            .unwrap();
        assert_eq!(item.layoutTitleLength, -1);
        assert_eq!(item.note, "");
        assert!(highlight_delete(time).unwrap());
        let id = highlight_rule_save(HighlightRule::default()).unwrap();
        let rule = highlight_rule_list()
            .unwrap()
            .into_iter()
            .find(|r| r.id == id)
            .unwrap();
        assert_eq!(
            rule,
            legado_core::highlight_rules::normalize_rule(HighlightRule {
                id,
                uuid: rule.uuid.clone(),
                ..Default::default()
            })
            .unwrap()
        );
        assert!(highlight_rule_delete(id).unwrap());
    }
}
