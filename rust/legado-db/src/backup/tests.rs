use super::*;
use crate::*;
use legado_core::models::{BookSource, Bookmark, ReplaceRule};
fn seed(conn: &Connection) {
    BookGroupRepository::new(conn)
        .insert(&BookGroup {
            group_id: 1,
            group_name: "分组".into(),
            ..Default::default()
        })
        .unwrap();
    BookRepository::new(conn)
        .insert(&Book {
            book_url: "book".into(),
            name: "原始书".into(),
            author: "作者".into(),
            group: 1,
            ..Default::default()
        })
        .unwrap();
    BookSourceRepository::new(conn)
        .insert(&BookSource {
            book_source_url: "source".into(),
            book_source_name: "源".into(),
            ..Default::default()
        })
        .unwrap();
    BookmarkRepository::new(conn)
        .insert(&Bookmark {
            book_name: "原始书".into(),
            content: "书签".into(),
            ..Default::default()
        })
        .unwrap();
    ReplaceRuleRepository::new(conn)
        .insert(&ReplaceRule {
            name: "规则".into(),
            pattern: "广告".into(),
            ..Default::default()
        })
        .unwrap();
    conn.execute_batch("INSERT INTO httpTTS(id,name,url) VALUES(7,'朗读','https://tts.test');
        INSERT INTO cloud_tts_engines VALUES('cloud','云端','mimo','https://tts.test','model','{}','','',1,1,1,'credential-id');
        INSERT INTO read_aloud_voices VALUES('voice','http','7','speaker','音色','{}','[]','user',1,1,0,1,1,1);
        INSERT INTO txtTocRules(id,name,rule,replacement,enable) VALUES(9,'目录','regex','replace',0);
        INSERT INTO dictRules(id,name,urlRule,enabled,sortNumber) VALUES(8,'词典','url',0,3);
        INSERT INTO keyboardAssists VALUES(0,'键','值',2);
        INSERT INTO ruleSubs(id,name,url,js,showRule,sourceUrl) VALUES(4,'订阅','https://sub','js','show','source');
        INSERT INTO rssStars(origin,sort,title,starTime,link,content) VALUES('rss','sort','收藏',100,'link','内容');
        INSERT INTO rssReadRecords(record,title,readTime) VALUES('link','文章',88);
        INSERT INTO highlights(time,bookUrl,bookName,bookAuthor,chapterIndex,chapterPos,chapterPosEnd,chapterName,bookText,style,note) VALUES(99,'book','原始书','作者',1,2,3,'章节','原文','{}','笔记');
        INSERT INTO readRecord(deviceId,bookName,author,readTime,lastRead) VALUES('设备','原始书','作者',1000,2000);
        INSERT INTO readRecordDetail(deviceId,bookName,bookAuthor,date,readTime,lastRead) VALUES('设备','原始书','作者','2026-10-24',1000,2000);
        INSERT INTO readRecordSession(id,deviceId,bookName,bookAuthor,bookUrl,startTime,endTime) VALUES(42,'设备','原始书','作者','book',1000,2000);").unwrap();
    ReadRecordRepository::new(conn)
        .add_daily_seconds("2026-10-24", 1)
        .unwrap();
    CacheRepository::new(conn)
        .put("config:threadCount", "3", 0)
        .unwrap();
    CacheRepository::new(conn)
        .put("config:secret-api-token", "不应导出", 0)
        .unwrap();
    CacheRepository::new(conn)
        .put("temporary", "缓存", 0)
        .unwrap();
}
#[test]
fn mixed_snapshot_preserves_ids_relations_and_reading_totals_on_repeat_restore() {
    let source = init_in_memory_database().unwrap();
    let target = init_in_memory_database().unwrap();
    seed(source.connection());
    HighlightRuleRepository::new(source.connection())
        .insert(&legado_core::models::HighlightRule {
            id: 13,
            name: "备份高亮".into(),
            pattern: "目标".into(),
            ..Default::default()
        })
        .unwrap();
    let exported = BackupRepository::new(source.connection())
        .export(100)
        .unwrap();
    assert_eq!(
        exported.config,
        BTreeMap::from([("threadCount".into(), "3".into())])
    );
    let target_repo = BackupRepository::new(target.connection());
    for round in 0..2 {
        let counts = target_repo.restore(&exported).unwrap();
        assert_eq!(counts["bookmarks"], 1);
        assert_eq!(counts["httpTts"], 1);
        let roundtrip = target_repo.export(200).unwrap();
        assert_eq!(roundtrip.collections, exported.collections);
        assert_eq!(roundtrip.config, exported.config);
        if round == 0 {
            target.connection().execute_batch("INSERT INTO chapters(url,title,isVolume,baseUrl,bookUrl,\"index\",isVip,isPay) VALUES('chapter','目录',0,'','book',0,0,0)").unwrap();
        } else {
            assert_eq!(
                target
                    .connection()
                    .query_row("SELECT count(*) FROM chapters", [], |r| r.get::<_, i64>(0))
                    .unwrap(),
                1
            );
        }
    }
    assert!(
        CacheRepository::new(target.connection())
            .get("temporary")
            .unwrap()
            .is_none()
    );
    assert_eq!(
        target
            .connection()
            .query_row("SELECT SUM(readTime) FROM readRecord", [], |r| r
                .get::<_, i64>(0))
            .unwrap(),
        1000
    );
}
#[test]
fn snapshot_rejects_unsupported_or_damaged_data_before_modifying_business_rows() {
    let db = init_in_memory_database().unwrap();
    seed(db.connection());
    let repo = BackupRepository::new(db.connection());
    let original = repo.export(100).unwrap();
    let mut broken = original.clone();
    broken.version = 1;
    assert!(repo.restore(&broken).is_err());
    let mut broken = original.clone();
    broken.collections.remove("httpTts");
    assert!(repo.restore(&broken).is_err());
    let mut broken = original.clone();
    broken.collections.get_mut("dictRules").unwrap()[0]
        .insert("unexpected".into(), Value::from("字段"));
    assert!(repo.restore(&broken).is_err());
    let mut broken = original.clone();
    let duplicate = broken.collections["bookmarks"][0].clone();
    broken
        .collections
        .get_mut("bookmarks")
        .unwrap()
        .push(duplicate);
    assert!(repo.restore(&broken).is_err());
    let mut broken = original.clone();
    broken.collections.get_mut("readRecordDetails").unwrap()[0]
        .insert("readTime".into(), Value::from("无效"));
    assert!(repo.restore(&broken).is_err());
    assert_eq!(repo.export(200).unwrap().collections, original.collections);
}
#[test]
fn snapshot_restores_roll_back_late_write_or_commit_failure_and_remain_retryable() {
    let source = init_in_memory_database().unwrap();
    seed(source.connection());
    let snapshot = BackupRepository::new(source.connection())
        .export(100)
        .unwrap();
    let target = init_in_memory_database().unwrap();
    let repo = BackupRepository::new(target.connection());
    let original = repo.export(0).unwrap();
    let cases = [
        (
            "CREATE TRIGGER refuse_read BEFORE INSERT ON readRecord BEGIN SELECT RAISE(ABORT,'拒绝记录'); END;",
            "DROP TRIGGER refuse_read;",
            "readRecords",
        ),
        (
            "CREATE TABLE commit_guard(book TEXT REFERENCES books(bookUrl) DEFERRABLE INITIALLY DEFERRED); CREATE TRIGGER refuse_commit AFTER INSERT ON readRecord BEGIN INSERT INTO commit_guard VALUES('missing'); END;",
            "DROP TRIGGER refuse_commit; DROP TABLE commit_guard;",
            "提交备份恢复事务失败",
        ),
    ];
    for (setup, cleanup, context) in cases {
        target.connection().execute_batch(setup).unwrap();
        let e = repo.restore(&snapshot).unwrap_err();
        assert!(e.to_string().contains(context), "{e}");
        assert!(target.connection().is_autocommit());
        assert_eq!(repo.export(200).unwrap().collections, original.collections);
        target.connection().execute_batch(cleanup).unwrap();
    }
    repo.restore(&snapshot).unwrap();
}
