//! [SOURCE-PARSE-UNIFY-20261022] Room 导入 与 FFI 类型化导入 逐字段一致对照
//!
//! 两条路径此前各自解释书源字段（Room 手写 `as_str()/as_i64()`、FFI 走 serde），
//! 同一份 JSON 会得到不同结果（`enabled:false` 被写成启用、规则对象落空、
//! `variable` 丢失、`respondTime` 缺省落 0）。收敛后两路径必须逐字段一致。
//!
//! 用例名沿用字段原写法（`respondTime` 等），放行 `non_snake_case`。
#![allow(non_snake_case)]

use legado_core::models::book_source::parse_source_array;
use legado_db::{BookSourceRepository, Database, RoomImporter, repository::Repository};

/// 一份覆盖各类「脏类型」与语义边界的书源 JSON。
const DOCUMENT: &str = r#"[
  {
    "bookSourceUrl": "https://parity-a.example",
    "bookSourceName": "对照源A",
    "bookSourceGroup": "分组",
    "bookSourceType": "1",
    "customOrder": "12",
    "enabled": "false",
    "enabledExplore": 0,
    "enabledCookieJar": "false",
    "concurrentRate": "3/10000",
    "header": {"X-Test": "1"},
    "lastUpdateTime": "1792486038190",
    "respondTime": null,
    "weight": "2",
    "variable": "k=v",
    "eventListener": 1,
    "customButton": "0",
    "exploreUrl": "[{'title':'科幻','url':'/lists/71.html'}]",
    "ruleToc": {"chapterList": [1, 2], "isVolume": false},
    "ruleSearch": "{\"bookList\":\".book\",\"name\":\".name\"}",
    "ruleContent": {"content": "@js:return result;", "title": true}
  }
]"#;

fn snapshot(db: &Database) -> Vec<serde_json::Value> {
    let list = BookSourceRepository::new(db.connection())
        .find_all()
        .expect("查询失败");
    list.iter()
        .map(|s| serde_json::to_value(s).expect("序列化失败"))
        .collect()
}

#[test]
fn room_与_ffi_导入逐字段一致() {
    let room_db = Database::open_in_memory().unwrap();
    RoomImporter::import_book_sources(room_db.connection(), DOCUMENT).unwrap();

    // FFI 路径等价实现：同一解析 + 同一 Repository 全列写入
    let ffi_db = Database::open_in_memory().unwrap();
    let parsed = parse_source_array(DOCUMENT).unwrap();
    BookSourceRepository::new(ffi_db.connection())
        .insert_batch(&parsed)
        .unwrap();

    let room_rows = snapshot(&room_db);
    let ffi_rows = snapshot(&ffi_db);
    assert_eq!(room_rows.len(), 1, "应导入 1 条");
    assert_eq!(
        room_rows, ffi_rows,
        "Room 与 FFI 两条路径导入结果必须逐字段一致"
    );
}

#[test]
fn 可见行为回归_禁用_规则_variable_默认值() {
    let db = Database::open_in_memory().unwrap();
    RoomImporter::import_book_sources(db.connection(), DOCUMENT).unwrap();
    let saved = BookSourceRepository::new(db.connection())
        .find_all()
        .unwrap()
        .into_iter()
        .next()
        .unwrap();

    // enabled:"false" 必须落为禁用（旧实现恒写启用）
    assert!(!saved.enabled, "enabled:\"false\" 应落禁用");
    assert!(!saved.enabled_explore, "enabledExplore:0 应落禁用");
    assert_eq!(saved.enabled_cookie_jar, Some(false));
    // 规则对象必须保留（旧实现落空值）
    let toc = saved.rule_toc.expect("ruleToc 应保留");
    assert_eq!(toc.chapter_list.as_deref(), Some("[1,2]"));
    assert_eq!(toc.is_volume.as_deref(), Some("false"));
    assert_eq!(
        saved
            .rule_search
            .expect("ruleSearch 字符串应解析")
            .book_list
            .as_deref(),
        Some(".book")
    );
    // variable 必须入库（旧 SQL 未含该列）
    assert_eq!(saved.variable, "k=v");
    // 缺省/显式 null 的 respondTime 落 180000（旧实现落 0）
    assert_eq!(
        saved.respond_time, 180000,
        "respondTime 显式 null 应落 180000"
    );
    // 数字字符串整数字段
    assert_eq!(saved.book_source_type, 1);
    assert_eq!(saved.custom_order, 12);
    assert_eq!(saved.weight, 2);
    assert_eq!(saved.last_update_time, 1_792_486_038_190);
    // 复合值转字符串
    assert_eq!(saved.header.as_deref(), Some(r#"{"X-Test":"1"}"#));
    assert_eq!(
        saved.rule_content.expect("正文规则应保留").title.as_deref(),
        Some("true")
    );
}

#[test]
fn 批量失败整批回滚() {
    let db = Database::open_in_memory().unwrap();
    RoomImporter::import_book_sources(
        db.connection(),
        r#"[{"bookSourceUrl":"https://keep.example","bookSourceName":"存量","bookSourceType":0}]"#,
    )
    .unwrap();
    let before = snapshot(&db);

    let err = RoomImporter::import_book_sources(
        db.connection(),
        r#"[
            {"bookSourceUrl":"https://keep.example","bookSourceName":"被改名称"},
            {"bookSourceUrl":"https://new.example","bookSourceName":"新增"},
            42
        ]"#,
    )
    .unwrap_err();
    assert!(
        format!("{err}").contains("第 3 项"),
        "错误应定位到第 3 项: {err}"
    );

    let after = snapshot(&db);
    assert_eq!(before, after, "任一条失败必须整批回滚，存量行不得被改");
}

#[test]
fn 坏规则字符串不得覆盖已有记录() {
    let db = Database::open_in_memory().unwrap();
    RoomImporter::import_book_sources(db.connection(), DOCUMENT).unwrap();
    let before = snapshot(&db);
    let error = RoomImporter::import_book_sources(db.connection(),
        r#"[{"bookSourceUrl":"https://parity-a.example","bookSourceName":"覆盖","ruleSearch":"{broken"}]"#
    ).unwrap_err();
    assert!(error.to_string().contains("ruleSearch"));
    assert_eq!(snapshot(&db), before);
}
