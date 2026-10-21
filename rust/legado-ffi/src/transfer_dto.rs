//! 仅承载跨语言传输类型，领域校验和持久化仍由既有业务层负责。— Codex + Bridge
use legado_core::models::Bookmark;
use legado_db::ReadRecordDetail;
use serde::{Deserialize, Serialize};

/// 书签完整快照；偏移为章内 UTF-16，时间为毫秒。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BookmarkDto {
    pub id: i64,
    pub time: i64,
    pub book_name: String,
    pub book_author: String,
    pub chapter_index: i32,
    pub chapter_pos: i32,
    pub chapter_name: String,
    pub book_text: String,
    pub content: String,
}

impl From<Bookmark> for BookmarkDto {
    fn from(value: Bookmark) -> Self {
        Self {
            id: value.id,
            time: value.time,
            book_name: value.book_name,
            book_author: value.book_author,
            chapter_index: value.chapter_index,
            chapter_pos: value.chapter_pos,
            chapter_name: value.chapter_name,
            book_text: value.book_text,
            content: value.content,
        }
    }
}

impl From<BookmarkDto> for Bookmark {
    fn from(value: BookmarkDto) -> Self {
        Self {
            id: value.id,
            time: value.time,
            book_name: value.book_name,
            book_author: value.book_author,
            chapter_index: value.chapter_index,
            chapter_pos: value.chapter_pos,
            chapter_name: value.chapter_name,
            book_text: value.book_text,
            content: value.content,
        }
    }
}

/// 单书每日阅读明细，保留服务端既有 JSON 序列化，同时供 FRB 强类型传输。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReadRecordDetailDto {
    pub book_name: String,
    pub author: String,
    pub date: String,
    pub read_time: i64,
    pub last_read: i64,
}

impl From<ReadRecordDetail> for ReadRecordDetailDto {
    fn from(value: ReadRecordDetail) -> Self {
        Self {
            book_name: value.book_name,
            author: value.author,
            date: value.date,
            read_time: value.read_time,
            last_read: value.last_read,
        }
    }
}

/// 累计阅读快照；毫秒、设备归属与原服务端字段保持。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadRecordDto {
    pub book_name: String,
    pub author: String,
    pub read_time: i64,
    pub last_read: i64,
    #[serde(default)]
    pub device_id: String,
}

/// 每日阅读总量；日期保持本地日期，时长单位为整秒。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadRecordDailyDto {
    pub date: String,
    pub seconds: i64,
}

/// 真实阅读会话；不在桥接层重新分片或折算时间。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadRecordSessionDto {
    pub id: i64,
    pub device_id: String,
    pub book_name: String,
    pub author: String,
    pub book_url: String,
    pub start_time: i64,
    pub end_time: i64,
    pub chapter_index: i32,
}

impl From<legado_db::ReadRecordSession> for ReadRecordSessionDto {
    fn from(value: legado_db::ReadRecordSession) -> Self {
        Self {
            id: value.id,
            device_id: value.device_id,
            book_name: value.book_name,
            author: value.book_author,
            book_url: value.book_url,
            start_time: value.start_time,
            end_time: value.end_time,
            chapter_index: value.chapter_index,
        }
    }
}

/// 分组列表的既有六字段投影，不扩充写入能力。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BookGroupDto {
    pub group_id: i64,
    pub group_name: String,
    pub cover: Option<String>,
    pub order: i32,
    pub show: bool,
    pub is_private: bool,
}

/// 正文标注完整快照；样式文档原样传输。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BookHighlightDto {
    pub time: i64,
    pub book_url: String,
    pub chapter_url: String,
    pub book_name: String,
    pub book_author: String,
    pub chapter_index: i32,
    pub chapter_pos: i32,
    pub chapter_pos_end: i32,
    pub layout_title_length: i32,
    pub chapter_name: String,
    pub book_text: String,
    pub style: String,
    pub note: String,
}

impl From<legado_core::models::BookHighlight> for BookHighlightDto {
    fn from(value: legado_core::models::BookHighlight) -> Self {
        Self {
            time: value.time,
            book_url: value.bookUrl,
            chapter_url: value.chapterUrl,
            book_name: value.bookName,
            book_author: value.bookAuthor,
            chapter_index: value.chapterIndex,
            chapter_pos: value.chapterPos,
            chapter_pos_end: value.chapterPosEnd,
            layout_title_length: value.layoutTitleLength,
            chapter_name: value.chapterName,
            book_text: value.bookText,
            style: value.style,
            note: value.note,
        }
    }
}

impl From<BookHighlightDto> for legado_core::models::BookHighlight {
    fn from(value: BookHighlightDto) -> Self {
        Self {
            time: value.time,
            bookUrl: value.book_url,
            chapterUrl: value.chapter_url,
            bookName: value.book_name,
            bookAuthor: value.book_author,
            chapterIndex: value.chapter_index,
            chapterPos: value.chapter_pos,
            chapterPosEnd: value.chapter_pos_end,
            layoutTitleLength: value.layout_title_length,
            chapterName: value.chapter_name,
            bookText: value.book_text,
            style: value.style,
            note: value.note,
        }
    }
}

/// 自动高亮规则；可空作用范围、排序、超时和标题标记全部保留。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HighlightRuleDto {
    pub id: i64,
    pub name: String,
    pub pattern: String,
    pub is_regex: bool,
    pub scope: Option<String>,
    pub is_enabled: bool,
    pub style: String,
    pub sort_order: i32,
    pub timeout_millisecond: i64,
    pub apply_to_title: bool,
}

impl From<legado_core::models::HighlightRule> for HighlightRuleDto {
    fn from(value: legado_core::models::HighlightRule) -> Self {
        Self {
            id: value.id,
            name: value.name,
            pattern: value.pattern,
            is_regex: value.isRegex,
            scope: value.scope,
            is_enabled: value.isEnabled,
            style: value.style,
            sort_order: value.sortOrder,
            timeout_millisecond: value.timeoutMillisecond,
            apply_to_title: value.applyToTitle,
        }
    }
}

impl From<HighlightRuleDto> for legado_core::models::HighlightRule {
    fn from(value: HighlightRuleDto) -> Self {
        Self {
            id: value.id,
            name: value.name,
            pattern: value.pattern,
            isRegex: value.is_regex,
            scope: value.scope,
            isEnabled: value.is_enabled,
            style: value.style,
            sortOrder: value.sort_order,
            timeoutMillisecond: value.timeout_millisecond,
            applyToTitle: value.apply_to_title,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reading_queries_keep_time_units_sessions_and_deletion() {
        let _guard = crate::db_state::ensure_test_db();
        use crate::ffi::ffi;
        use chrono::TimeZone;
        let start = chrono::Local
            .with_ymd_and_hms(2026, 1, 2, 12, 0, 0)
            .unwrap()
            .timestamp_millis();
        ffi::read_record_record_time(
            "类型化阅读记录".into(),
            "作者😀".into(),
            2999,
            Some(start),
            Some(start + 2999),
            "book://typed-record".into(),
            7,
        )
        .unwrap();
        let record = ffi::read_record_list()
            .unwrap()
            .into_iter()
            .find(|r| r.book_name == "类型化阅读记录")
            .unwrap();
        assert_eq!(
            (record.author.as_str(), record.read_time, record.last_read),
            ("作者😀", 2999, start + 2999)
        );
        let session = ffi::read_record_session_list()
            .unwrap()
            .into_iter()
            .find(|r| r.book_name == record.book_name)
            .unwrap();
        assert_eq!(
            (
                session.author.as_str(),
                session.book_url.as_str(),
                session.chapter_index,
                session.end_time - session.start_time
            ),
            ("作者😀", "book://typed-record", 7, 2999)
        );
        let daily = ffi::read_record_daily_list(2026).unwrap();
        assert!(daily.windows(2).all(|pair| pair[0].date < pair[1].date));
        assert!(
            daily
                .iter()
                .any(|r| r.date == "2026-01-02" && r.seconds >= 2)
        );
        ffi::read_record_sessions_delete(vec![session.id]).unwrap();
        assert!(
            !ffi::read_record_session_list()
                .unwrap()
                .iter()
                .any(|r| r.id == session.id)
        );
    }

    #[test]
    fn typed_highlights_preserve_fields_keys_filtering_and_rule_updates() {
        let _guard = crate::db_state::ensure_test_db();
        use crate::ffi::ffi;
        let item = legado_core::models::BookHighlight {
            bookUrl: "book://typed-highlight".into(),
            chapterUrl: "chapter://😀".into(),
            bookName: "类型化高亮".into(),
            bookAuthor: "作者".into(),
            chapterIndex: 3,
            chapterPos: 2,
            chapterPosEnd: 9,
            layoutTitleLength: -1,
            chapterName: "第三章".into(),
            bookText: "甲😀正文".into(),
            style: "{\"textColor\":-65536}".into(),
            note: "原始笔记".into(),
            ..Default::default()
        };
        let first = ffi::highlight_add(item.clone().into()).unwrap();
        let second = ffi::highlight_add(item.clone().into()).unwrap();
        assert_ne!(first, second);
        let mut saved = item.clone();
        saved.time = first;
        saved.note = "修改".into();
        assert_eq!(ffi::highlight_add(saved.clone().into()).unwrap(), first);
        let entries = ffi::highlight_list_by_chapter(item.bookUrl.clone(), 3).unwrap();
        assert_eq!(entries.len(), 2);
        let actual: legado_core::models::BookHighlight = entries
            .into_iter()
            .find(|e| e.time == first)
            .unwrap()
            .into();
        assert_eq!(actual, saved);
        assert!(
            ffi::highlight_search("甲😀".into())
                .unwrap()
                .iter()
                .any(|e| e.time == first)
        );
        let mut rule = legado_core::models::HighlightRule {
            name: "类型化规则".into(),
            pattern: "甲😀".into(),
            scope: Some("类型化高亮".into()),
            isRegex: true,
            applyToTitle: true,
            sortOrder: -4,
            timeoutMillisecond: 9007199254740993,
            style: "{\"backgroundColor\":1}".into(),
            ..Default::default()
        };
        rule.id = ffi::highlight_rule_save(rule.clone().into()).unwrap();
        let found: legado_core::models::HighlightRule =
            ffi::highlight_rule_find_enabled(item.bookName.clone(), "源".into())
                .unwrap()
                .into_iter()
                .find(|r| r.id == rule.id)
                .unwrap()
                .into();
        assert_eq!(found, rule);
        rule.isEnabled = false;
        assert_eq!(
            ffi::highlight_rule_save(rule.clone().into()).unwrap(),
            rule.id
        );
        assert!(
            !ffi::highlight_rule_find_enabled(item.bookName, "源".into())
                .unwrap()
                .iter()
                .any(|r| r.id == rule.id)
        );
        assert!(ffi::highlight_rule_delete(rule.id).unwrap());
        assert_eq!(ffi::highlight_delete_by_book(item.bookUrl).unwrap(), 2);
    }

    #[test]
    fn typed_groups_keep_existing_projection_and_visibility() {
        let _guard = crate::db_state::ensure_test_db();
        use crate::ffi::ffi;
        let id = ffi::book_group_add("类型化分组😀".into(), "".into(), -5, Some(true)).unwrap();
        assert!(ffi::book_group_set_show(id, false).unwrap());
        let group = ffi::book_group_list()
            .unwrap()
            .into_iter()
            .find(|g| g.group_id == id)
            .unwrap();
        assert_eq!(
            (
                group.group_name.as_str(),
                group.cover,
                group.order,
                group.show,
                group.is_private
            ),
            ("类型化分组😀", None, -5, false, true)
        );
        assert!(ffi::book_group_delete(id).unwrap());
    }

    #[test]
    fn bookmark_roundtrip_preserves_large_ids_unicode_and_offsets() {
        let dto = BookmarkDto {
            id: i64::MAX - 1,
            time: 9_007_199_254_740_993,
            book_name: "同名书😀".into(),
            book_author: String::new(),
            chapter_index: i32::MAX,
            chapter_pos: 3,
            chapter_name: "引号\"与换行\n".into(),
            book_text: "甲😀e\u{301}乙".into(),
            content: String::new(),
        };
        let entity: Bookmark = dto.clone().into();
        assert_eq!(BookmarkDto::from(entity), dto);
    }

    #[test]
    fn detail_mapping_preserves_milliseconds_without_exposing_device_identity() {
        let dto = ReadRecordDetailDto::from(ReadRecordDetail {
            device_id: "内部设备".into(),
            book_name: "阅读😀".into(),
            author: String::new(),
            date: "2024-02-29".into(),
            read_time: 9_007_199_254_740_993,
            last_read: i64::MAX - 1,
        });
        assert_eq!(dto.read_time, 9_007_199_254_740_993);
        assert_eq!(dto.last_read, i64::MAX - 1);
        assert_eq!(dto.date, "2024-02-29");
        let json = serde_json::to_value(&dto).unwrap();
        assert_eq!(json["bookName"], "阅读😀");
        assert_eq!(json["readTime"], dto.read_time);
        assert_eq!(json["author"], "");
        assert!(json.get("deviceId").is_none());
    }
    #[test]
    fn typed_bookmark_operations_preserve_storage_identity_time_and_filters() {
        use crate::ffi::ffi as bridge;
        let _guard = crate::db_state::ensure_test_db();
        let name = "类型化书签😀";
        let first = bridge::bookmark_add(
            name.into(),
            "甲".into(),
            7,
            3,
            "章节".into(),
            "甲😀乙".into(),
            "原备注".into(),
        )
        .unwrap();
        let second = bridge::bookmark_add(
            name.into(),
            "乙".into(),
            0,
            0,
            String::new(),
            String::new(),
            String::new(),
        )
        .unwrap();
        let original = bridge::get_bookmarks_by_book(name.into(), "甲".into())
            .unwrap()
            .remove(0);
        let mut updated = original.clone();
        updated.time = i64::MAX;
        updated.content = "类型化备注".into();
        updated.chapter_pos = 4;
        bridge::bookmark_update(updated).unwrap();
        let stored = bridge::get_bookmarks_by_book(name.into(), "甲".into())
            .unwrap()
            .remove(0);
        assert_eq!(stored.id, first);
        assert_eq!(stored.time, original.time);
        assert_eq!(stored.content, "类型化备注");
        assert_eq!(stored.chapter_pos, 4);
        assert_eq!(bridge::bookmark_get_all(name.into()).unwrap().len(), 2);
        assert_eq!(
            bridge::bookmark_search("类型化备注".into()).unwrap(),
            vec![stored.clone()]
        );
        let mut missing = stored.clone();
        missing.id = i64::MAX - 1;
        assert!(bridge::bookmark_update(missing).is_err());
        assert_eq!(
            bridge::get_bookmarks_by_book(name.into(), "甲".into()).unwrap(),
            vec![stored]
        );
        bridge::bookmark_delete(first).unwrap();
        bridge::bookmark_delete(second).unwrap();
        assert!(bridge::bookmark_get_all(name.into()).unwrap().is_empty());
    }
    #[test]
    fn platform_results_are_explicit_and_plain_text_is_untouched() {
        for text in [
            "正文😀",
            "{未完成的小说段落",
            r#"{"action":"unknown","url":"https://example.test"}"#,
        ] {
            assert!(
                matches!(TextResponseDto::from(text.to_owned()),TextResponseDto::Text(ref v) if v==text)
            );
        }
        let response=TextResponseDto::from(r#" {"action":"webView","url":"https://example.test","js":"document.title","cookie":"a=b","isRule":true,"delayTime":"900"} "#.to_owned());
        let TextResponseDto::PlatformAction(value) = response else {
            panic!("合法动作必须分派");
        };
        assert!(matches!(value.action, PlatformActionKind::WebView));
        assert_eq!(value.url.as_deref(), Some("https://example.test"));
        assert_eq!(value.cookie.as_deref(), Some("a=b"));
        assert!(value.is_rule);
        assert_eq!(value.delay_time_ms, 900);
        let TextResponseDto::PlatformAction(value) = TextResponseDto::from(
            r#"{"action":"copyText","text":"甲😀乙","delayTime":-5}"#.to_owned(),
        ) else {
            panic!();
        };
        assert_eq!(value.text.as_deref(), Some("甲😀乙"));
        assert_eq!(value.delay_time_ms, 0);
    }
    #[test]
    fn check_config_keeps_default_empty_keyword_and_explicit_false() {
        let default = legado_net::source_checker::CheckerConfig::default();
        let value: legado_net::source_checker::CheckerConfig = SourceCheckConfigDto {
            keyword: Some(String::new()),
            check_search: Some(false),
            step_timeout_ms: Some(17),
            ..Default::default()
        }
        .into();
        assert_eq!(value.keyword, default.keyword);
        assert!(!value.check_search);
        assert!(value.check_toc);
        assert_eq!(value.step_timeout_ms, 17);
    }
}

/// ReadConfig 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct ReadConfigDto {
    pub reverse_toc: bool,
    pub page_anim: Option<i32>,
    pub re_segment: bool,
    pub image_style: Option<String>,
    pub use_replace_rule: Option<bool>,
    pub del_tag: i64,
    pub tts_engine: Option<String>,
    pub split_long_chapter: bool,
    pub read_simulating: bool,
    pub start_date: Option<String>,
    pub start_chapter: Option<i32>,
    pub daily_chapters: i32,
    pub open_credits: i32,
    pub close_credits: i32,
    pub play_mode: i32,
    pub play_speed: f32,
    pub use_global_audio_skip: bool,
    pub manga_scroll_mode: Option<i32>,
    pub webtoon_side_padding_dp: Option<i32>,
}

impl From<legado_core::models::ReadConfig> for ReadConfigDto {
    fn from(value: legado_core::models::ReadConfig) -> Self {
        Self {
            reverse_toc: value.reverse_toc,
            page_anim: value.page_anim,
            re_segment: value.re_segment,
            image_style: value.image_style,
            use_replace_rule: value.use_replace_rule,
            del_tag: value.del_tag,
            tts_engine: value.tts_engine,
            split_long_chapter: value.split_long_chapter,
            read_simulating: value.read_simulating,
            start_date: value.start_date,
            start_chapter: value.start_chapter,
            daily_chapters: value.daily_chapters,
            open_credits: value.open_credits,
            close_credits: value.close_credits,
            play_mode: value.play_mode,
            play_speed: value.play_speed,
            use_global_audio_skip: value.use_global_audio_skip,
            manga_scroll_mode: value.manga_scroll_mode,
            webtoon_side_padding_dp: value.webtoon_side_padding_dp,
        }
    }
}

impl From<ReadConfigDto> for legado_core::models::ReadConfig {
    fn from(value: ReadConfigDto) -> Self {
        Self {
            reverse_toc: value.reverse_toc,
            page_anim: value.page_anim,
            re_segment: value.re_segment,
            image_style: value.image_style,
            use_replace_rule: value.use_replace_rule,
            del_tag: value.del_tag,
            tts_engine: value.tts_engine,
            split_long_chapter: value.split_long_chapter,
            read_simulating: value.read_simulating,
            start_date: value.start_date,
            start_chapter: value.start_chapter,
            daily_chapters: value.daily_chapters,
            open_credits: value.open_credits,
            close_credits: value.close_credits,
            play_mode: value.play_mode,
            play_speed: value.play_speed,
            use_global_audio_skip: value.use_global_audio_skip,
            manga_scroll_mode: value.manga_scroll_mode,
            webtoon_side_padding_dp: value.webtoon_side_padding_dp,
        }
    }
}

/// Book 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct BookDto {
    pub book_url: String,
    pub toc_url: String,
    pub origin_book_url: String,
    pub is_private: bool,
    pub origin: String,
    pub origin_name: String,
    pub name: String,
    pub author: String,
    pub kind: Option<String>,
    pub custom_tag: Option<String>,
    pub cover_url: Option<String>,
    pub custom_cover_url: Option<String>,
    pub intro: Option<String>,
    pub custom_intro: Option<String>,
    pub charset: Option<String>,
    pub book_type: i32,
    pub group: i64,
    pub latest_chapter_title: Option<String>,
    pub latest_chapter_time: i64,
    pub last_check_time: i64,
    pub last_check_count: i32,
    pub total_chapter_num: i32,
    pub dur_chapter_title: Option<String>,
    pub dur_chapter_index: i32,
    pub dur_volume_index: i32,
    pub chapter_in_volume_index: i32,
    pub dur_chapter_pos: i32,
    pub dur_chapter_time: i64,
    pub word_count: Option<String>,
    pub can_update: bool,
    pub order: i32,
    pub origin_order: i32,
    pub variable: Option<String>,
    pub read_config: Option<ReadConfigDto>,
    pub sync_time: i64,
    pub info_html: Option<String>,
    pub toc_html: Option<String>,
    pub download_urls: Option<String>,
    pub cover_origin: Option<String>,
}

impl From<legado_core::models::Book> for BookDto {
    fn from(value: legado_core::models::Book) -> Self {
        Self {
            book_url: value.book_url,
            toc_url: value.toc_url,
            origin_book_url: value.origin_book_url,
            is_private: value.is_private,
            origin: value.origin,
            origin_name: value.origin_name,
            name: value.name,
            author: value.author,
            kind: value.kind,
            custom_tag: value.custom_tag,
            cover_url: value.cover_url,
            custom_cover_url: value.custom_cover_url,
            intro: value.intro,
            custom_intro: value.custom_intro,
            charset: value.charset,
            book_type: value.book_type,
            group: value.group,
            latest_chapter_title: value.latest_chapter_title,
            latest_chapter_time: value.latest_chapter_time,
            last_check_time: value.last_check_time,
            last_check_count: value.last_check_count,
            total_chapter_num: value.total_chapter_num,
            dur_chapter_title: value.dur_chapter_title,
            dur_chapter_index: value.dur_chapter_index,
            dur_volume_index: value.dur_volume_index,
            chapter_in_volume_index: value.chapter_in_volume_index,
            dur_chapter_pos: value.dur_chapter_pos,
            dur_chapter_time: value.dur_chapter_time,
            word_count: value.word_count,
            can_update: value.can_update,
            order: value.order,
            origin_order: value.origin_order,
            variable: value.variable,
            read_config: value.read_config.map(Into::into),
            sync_time: value.sync_time,
            info_html: value.info_html,
            toc_html: value.toc_html,
            download_urls: value.download_urls,
            cover_origin: value.cover_origin,
        }
    }
}

impl From<BookDto> for legado_core::models::Book {
    fn from(value: BookDto) -> Self {
        Self {
            book_url: value.book_url,
            toc_url: value.toc_url,
            origin_book_url: value.origin_book_url,
            is_private: value.is_private,
            origin: value.origin,
            origin_name: value.origin_name,
            name: value.name,
            author: value.author,
            kind: value.kind,
            custom_tag: value.custom_tag,
            cover_url: value.cover_url,
            custom_cover_url: value.custom_cover_url,
            intro: value.intro,
            custom_intro: value.custom_intro,
            charset: value.charset,
            book_type: value.book_type,
            group: value.group,
            latest_chapter_title: value.latest_chapter_title,
            latest_chapter_time: value.latest_chapter_time,
            last_check_time: value.last_check_time,
            last_check_count: value.last_check_count,
            total_chapter_num: value.total_chapter_num,
            dur_chapter_title: value.dur_chapter_title,
            dur_chapter_index: value.dur_chapter_index,
            dur_volume_index: value.dur_volume_index,
            chapter_in_volume_index: value.chapter_in_volume_index,
            dur_chapter_pos: value.dur_chapter_pos,
            dur_chapter_time: value.dur_chapter_time,
            word_count: value.word_count,
            can_update: value.can_update,
            order: value.order,
            origin_order: value.origin_order,
            variable: value.variable,
            read_config: value.read_config.map(Into::into),
            sync_time: value.sync_time,
            info_html: value.info_html,
            toc_html: value.toc_html,
            download_urls: value.download_urls,
            cover_origin: value.cover_origin,
        }
    }
}

/// BookChapter 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct ChapterDto {
    pub url: String,
    pub title: String,
    pub is_volume: bool,
    pub base_url: String,
    pub book_url: String,
    pub index: i32,
    pub is_vip: bool,
    pub is_pay: bool,
    pub resource_url: Option<String>,
    pub tag: Option<String>,
    pub word_count: Option<String>,
    pub start: Option<i64>,
    pub end: Option<i64>,
    pub start_fragment_id: Option<String>,
    pub end_fragment_id: Option<String>,
    pub variable: Option<String>,
    pub img_url: Option<String>,
}

impl From<legado_core::models::BookChapter> for ChapterDto {
    fn from(value: legado_core::models::BookChapter) -> Self {
        Self {
            url: value.url,
            title: value.title,
            is_volume: value.is_volume,
            base_url: value.base_url,
            book_url: value.book_url,
            index: value.index,
            is_vip: value.is_vip,
            is_pay: value.is_pay,
            resource_url: value.resource_url,
            tag: value.tag,
            word_count: value.word_count,
            start: value.start,
            end: value.end,
            start_fragment_id: value.start_fragment_id,
            end_fragment_id: value.end_fragment_id,
            variable: value.variable,
            img_url: value.img_url,
        }
    }
}

impl From<ChapterDto> for legado_core::models::BookChapter {
    fn from(value: ChapterDto) -> Self {
        Self {
            url: value.url,
            title: value.title,
            is_volume: value.is_volume,
            base_url: value.base_url,
            book_url: value.book_url,
            index: value.index,
            is_vip: value.is_vip,
            is_pay: value.is_pay,
            resource_url: value.resource_url,
            tag: value.tag,
            word_count: value.word_count,
            start: value.start,
            end: value.end,
            start_fragment_id: value.start_fragment_id,
            end_fragment_id: value.end_fragment_id,
            variable: value.variable,
            img_url: value.img_url,
        }
    }
}

/// BookSource 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct BookSourceDto {
    pub book_source_url: String,
    pub book_source_name: String,
    pub book_source_group: Option<String>,
    pub book_source_type: i32,
    pub book_url_pattern: Option<String>,
    pub custom_order: i32,
    pub enabled: bool,
    pub enabled_explore: bool,
    pub js_lib: Option<String>,
    pub enabled_cookie_jar: Option<bool>,
    pub concurrent_rate: Option<String>,
    pub header: Option<String>,
    pub login_url: Option<String>,
    pub login_ui: Option<String>,
    pub login_check_js: Option<String>,
    pub cover_decode_js: Option<String>,
    pub book_source_comment: Option<String>,
    pub variable_comment: Option<String>,
    pub variable: String,
    pub last_update_time: i64,
    pub respond_time: i64,
    pub weight: i32,
    pub explore_url: Option<String>,
    pub explore_screen: Option<String>,
    pub rule_explore: Option<ExploreRuleDto>,
    pub search_url: Option<String>,
    pub rule_search: Option<SearchRuleDto>,
    pub rule_book_info: Option<BookInfoRuleDto>,
    pub rule_toc: Option<TocRuleDto>,
    pub rule_content: Option<ContentRuleDto>,
    pub rule_review: Option<ReviewRuleDto>,
    pub main_js: Option<String>,
    pub event_listener: bool,
    pub custom_button: bool,
}

impl From<legado_core::models::BookSource> for BookSourceDto {
    fn from(value: legado_core::models::BookSource) -> Self {
        Self {
            book_source_url: value.book_source_url,
            book_source_name: value.book_source_name,
            book_source_group: value.book_source_group,
            book_source_type: value.book_source_type,
            book_url_pattern: value.book_url_pattern,
            custom_order: value.custom_order,
            enabled: value.enabled,
            enabled_explore: value.enabled_explore,
            js_lib: value.js_lib,
            enabled_cookie_jar: value.enabled_cookie_jar,
            concurrent_rate: value.concurrent_rate,
            header: value.header,
            login_url: value.login_url,
            login_ui: value.login_ui,
            login_check_js: value.login_check_js,
            cover_decode_js: value.cover_decode_js,
            book_source_comment: value.book_source_comment,
            variable_comment: value.variable_comment,
            variable: value.variable,
            last_update_time: value.last_update_time,
            respond_time: value.respond_time,
            weight: value.weight,
            explore_url: value.explore_url,
            explore_screen: value.explore_screen,
            rule_explore: value.rule_explore.map(Into::into),
            search_url: value.search_url,
            rule_search: value.rule_search.map(Into::into),
            rule_book_info: value.rule_book_info.map(Into::into),
            rule_toc: value.rule_toc.map(Into::into),
            rule_content: value.rule_content.map(Into::into),
            rule_review: value.rule_review.map(Into::into),
            main_js: value.main_js,
            event_listener: value.event_listener,
            custom_button: value.custom_button,
        }
    }
}

impl From<BookSourceDto> for legado_core::models::BookSource {
    fn from(value: BookSourceDto) -> Self {
        Self {
            book_source_url: value.book_source_url,
            book_source_name: value.book_source_name,
            book_source_group: value.book_source_group,
            book_source_type: value.book_source_type,
            book_url_pattern: value.book_url_pattern,
            custom_order: value.custom_order,
            enabled: value.enabled,
            enabled_explore: value.enabled_explore,
            js_lib: value.js_lib,
            enabled_cookie_jar: value.enabled_cookie_jar,
            concurrent_rate: value.concurrent_rate,
            header: value.header,
            login_url: value.login_url,
            login_ui: value.login_ui,
            login_check_js: value.login_check_js,
            cover_decode_js: value.cover_decode_js,
            book_source_comment: value.book_source_comment,
            variable_comment: value.variable_comment,
            variable: value.variable,
            last_update_time: value.last_update_time,
            respond_time: value.respond_time,
            weight: value.weight,
            explore_url: value.explore_url,
            explore_screen: value.explore_screen,
            rule_explore: value.rule_explore.map(Into::into),
            search_url: value.search_url,
            rule_search: value.rule_search.map(Into::into),
            rule_book_info: value.rule_book_info.map(Into::into),
            rule_toc: value.rule_toc.map(Into::into),
            rule_content: value.rule_content.map(Into::into),
            rule_review: value.rule_review.map(Into::into),
            main_js: value.main_js,
            event_listener: value.event_listener,
            custom_button: value.custom_button,
        }
    }
}

/// ExploreRule 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct ExploreRuleDto {
    pub book_list: Option<String>,
    pub name: Option<String>,
    pub author: Option<String>,
    pub intro: Option<String>,
    pub kind: Option<String>,
    pub last_chapter: Option<String>,
    pub update_time: Option<String>,
    pub book_url: Option<String>,
    pub cover_url: Option<String>,
    pub word_count: Option<String>,
}

impl From<legado_core::models::ExploreRule> for ExploreRuleDto {
    fn from(value: legado_core::models::ExploreRule) -> Self {
        Self {
            book_list: value.book_list,
            name: value.name,
            author: value.author,
            intro: value.intro,
            kind: value.kind,
            last_chapter: value.last_chapter,
            update_time: value.update_time,
            book_url: value.book_url,
            cover_url: value.cover_url,
            word_count: value.word_count,
        }
    }
}

impl From<ExploreRuleDto> for legado_core::models::ExploreRule {
    fn from(value: ExploreRuleDto) -> Self {
        Self {
            book_list: value.book_list,
            name: value.name,
            author: value.author,
            intro: value.intro,
            kind: value.kind,
            last_chapter: value.last_chapter,
            update_time: value.update_time,
            book_url: value.book_url,
            cover_url: value.cover_url,
            word_count: value.word_count,
        }
    }
}

/// SearchRule 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct SearchRuleDto {
    pub check_key_word: Option<String>,
    pub book_list: Option<String>,
    pub name: Option<String>,
    pub author: Option<String>,
    pub intro: Option<String>,
    pub kind: Option<String>,
    pub last_chapter: Option<String>,
    pub update_time: Option<String>,
    pub book_url: Option<String>,
    pub cover_url: Option<String>,
    pub word_count: Option<String>,
}

impl From<legado_core::models::SearchRule> for SearchRuleDto {
    fn from(value: legado_core::models::SearchRule) -> Self {
        Self {
            check_key_word: value.check_key_word,
            book_list: value.book_list,
            name: value.name,
            author: value.author,
            intro: value.intro,
            kind: value.kind,
            last_chapter: value.last_chapter,
            update_time: value.update_time,
            book_url: value.book_url,
            cover_url: value.cover_url,
            word_count: value.word_count,
        }
    }
}

impl From<SearchRuleDto> for legado_core::models::SearchRule {
    fn from(value: SearchRuleDto) -> Self {
        Self {
            check_key_word: value.check_key_word,
            book_list: value.book_list,
            name: value.name,
            author: value.author,
            intro: value.intro,
            kind: value.kind,
            last_chapter: value.last_chapter,
            update_time: value.update_time,
            book_url: value.book_url,
            cover_url: value.cover_url,
            word_count: value.word_count,
        }
    }
}

/// BookInfoRule 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct BookInfoRuleDto {
    pub init: Option<String>,
    pub name: Option<String>,
    pub author: Option<String>,
    pub intro: Option<String>,
    pub kind: Option<String>,
    pub last_chapter: Option<String>,
    pub update_time: Option<String>,
    pub cover_url: Option<String>,
    pub toc_url: Option<String>,
    pub word_count: Option<String>,
    pub can_re_name: Option<String>,
    pub download_urls: Option<String>,
}

impl From<legado_core::models::BookInfoRule> for BookInfoRuleDto {
    fn from(value: legado_core::models::BookInfoRule) -> Self {
        Self {
            init: value.init,
            name: value.name,
            author: value.author,
            intro: value.intro,
            kind: value.kind,
            last_chapter: value.last_chapter,
            update_time: value.update_time,
            cover_url: value.cover_url,
            toc_url: value.toc_url,
            word_count: value.word_count,
            can_re_name: value.can_re_name,
            download_urls: value.download_urls,
        }
    }
}

impl From<BookInfoRuleDto> for legado_core::models::BookInfoRule {
    fn from(value: BookInfoRuleDto) -> Self {
        Self {
            init: value.init,
            name: value.name,
            author: value.author,
            intro: value.intro,
            kind: value.kind,
            last_chapter: value.last_chapter,
            update_time: value.update_time,
            cover_url: value.cover_url,
            toc_url: value.toc_url,
            word_count: value.word_count,
            can_re_name: value.can_re_name,
            download_urls: value.download_urls,
        }
    }
}

/// TocRule 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct TocRuleDto {
    pub pre_update_js: Option<String>,
    pub chapter_list: Option<String>,
    pub chapter_name: Option<String>,
    pub chapter_url: Option<String>,
    pub format_js: Option<String>,
    pub is_volume: Option<String>,
    pub is_vip: Option<String>,
    pub is_pay: Option<String>,
    pub update_time: Option<String>,
    pub next_toc_url: Option<String>,
}

impl From<legado_core::models::TocRule> for TocRuleDto {
    fn from(value: legado_core::models::TocRule) -> Self {
        Self {
            pre_update_js: value.pre_update_js,
            chapter_list: value.chapter_list,
            chapter_name: value.chapter_name,
            chapter_url: value.chapter_url,
            format_js: value.format_js,
            is_volume: value.is_volume,
            is_vip: value.is_vip,
            is_pay: value.is_pay,
            update_time: value.update_time,
            next_toc_url: value.next_toc_url,
        }
    }
}

impl From<TocRuleDto> for legado_core::models::TocRule {
    fn from(value: TocRuleDto) -> Self {
        Self {
            pre_update_js: value.pre_update_js,
            chapter_list: value.chapter_list,
            chapter_name: value.chapter_name,
            chapter_url: value.chapter_url,
            format_js: value.format_js,
            is_volume: value.is_volume,
            is_vip: value.is_vip,
            is_pay: value.is_pay,
            update_time: value.update_time,
            next_toc_url: value.next_toc_url,
        }
    }
}

/// ContentRule 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct ContentRuleDto {
    pub content: Option<String>,
    pub sub_content: Option<String>,
    pub title: Option<String>,
    pub next_content_url: Option<String>,
    pub web_js: Option<String>,
    pub source_regex: Option<String>,
    pub replace_regex: Option<String>,
    pub image_style: Option<String>,
    pub image_decode: Option<String>,
    pub pay_action: Option<String>,
    pub call_back_js: Option<String>,
    pub content_batch: Option<String>,
    pub max_batch_size: Option<i32>,
}

impl From<legado_core::models::ContentRule> for ContentRuleDto {
    fn from(value: legado_core::models::ContentRule) -> Self {
        Self {
            content: value.content,
            sub_content: value.sub_content,
            title: value.title,
            next_content_url: value.next_content_url,
            web_js: value.web_js,
            source_regex: value.source_regex,
            replace_regex: value.replace_regex,
            image_style: value.image_style,
            image_decode: value.image_decode,
            pay_action: value.pay_action,
            call_back_js: value.call_back_js,
            content_batch: value.content_batch,
            max_batch_size: value.max_batch_size,
        }
    }
}

impl From<ContentRuleDto> for legado_core::models::ContentRule {
    fn from(value: ContentRuleDto) -> Self {
        Self {
            content: value.content,
            sub_content: value.sub_content,
            title: value.title,
            next_content_url: value.next_content_url,
            web_js: value.web_js,
            source_regex: value.source_regex,
            replace_regex: value.replace_regex,
            image_style: value.image_style,
            image_decode: value.image_decode,
            pay_action: value.pay_action,
            call_back_js: value.call_back_js,
            content_batch: value.content_batch,
            max_batch_size: value.max_batch_size,
        }
    }
}

/// ReviewRule 的桥接快照；不承担领域校验。
#[derive(Debug, Clone)]
pub struct ReviewRuleDto {
    pub review_url: Option<String>,
    pub avatar_rule: Option<String>,
    pub content_rule: Option<String>,
    pub post_time_rule: Option<String>,
    pub review_quote_url: Option<String>,
    pub vote_up_url: Option<String>,
    pub vote_down_url: Option<String>,
    pub post_review_url: Option<String>,
    pub post_quote_url: Option<String>,
    pub delete_url: Option<String>,
    pub enabled: bool,
    pub review_summary_url: Option<String>,
    pub summary_list_rule: Option<String>,
    pub summary_paragraph_index_rule: Option<String>,
    pub summary_paragraph_data_rule: Option<String>,
    pub summary_count_rule: Option<String>,
    pub review_detail_url: Option<String>,
    pub review_detail_next_page_url: Option<String>,
    pub detail_list_rule: Option<String>,
    pub detail_id_rule: Option<String>,
    pub detail_avatar_rule: Option<String>,
    pub detail_name_rule: Option<String>,
    pub detail_badge_rule: Option<String>,
    pub detail_content_rule: Option<String>,
    pub reply_list_rule: Option<String>,
    pub reply_id_rule: Option<String>,
    pub reply_avatar_rule: Option<String>,
    pub reply_name_rule: Option<String>,
    pub reply_badge_rule: Option<String>,
    pub reply_content_rule: Option<String>,
}

impl From<legado_core::models::ReviewRule> for ReviewRuleDto {
    fn from(value: legado_core::models::ReviewRule) -> Self {
        Self {
            review_url: value.review_url,
            avatar_rule: value.avatar_rule,
            content_rule: value.content_rule,
            post_time_rule: value.post_time_rule,
            review_quote_url: value.review_quote_url,
            vote_up_url: value.vote_up_url,
            vote_down_url: value.vote_down_url,
            post_review_url: value.post_review_url,
            post_quote_url: value.post_quote_url,
            delete_url: value.delete_url,
            enabled: value.enabled,
            review_summary_url: value.review_summary_url,
            summary_list_rule: value.summary_list_rule,
            summary_paragraph_index_rule: value.summary_paragraph_index_rule,
            summary_paragraph_data_rule: value.summary_paragraph_data_rule,
            summary_count_rule: value.summary_count_rule,
            review_detail_url: value.review_detail_url,
            review_detail_next_page_url: value.review_detail_next_page_url,
            detail_list_rule: value.detail_list_rule,
            detail_id_rule: value.detail_id_rule,
            detail_avatar_rule: value.detail_avatar_rule,
            detail_name_rule: value.detail_name_rule,
            detail_badge_rule: value.detail_badge_rule,
            detail_content_rule: value.detail_content_rule,
            reply_list_rule: value.reply_list_rule,
            reply_id_rule: value.reply_id_rule,
            reply_avatar_rule: value.reply_avatar_rule,
            reply_name_rule: value.reply_name_rule,
            reply_badge_rule: value.reply_badge_rule,
            reply_content_rule: value.reply_content_rule,
        }
    }
}

impl From<ReviewRuleDto> for legado_core::models::ReviewRule {
    fn from(value: ReviewRuleDto) -> Self {
        Self {
            review_url: value.review_url,
            avatar_rule: value.avatar_rule,
            content_rule: value.content_rule,
            post_time_rule: value.post_time_rule,
            review_quote_url: value.review_quote_url,
            vote_up_url: value.vote_up_url,
            vote_down_url: value.vote_down_url,
            post_review_url: value.post_review_url,
            post_quote_url: value.post_quote_url,
            delete_url: value.delete_url,
            enabled: value.enabled,
            review_summary_url: value.review_summary_url,
            summary_list_rule: value.summary_list_rule,
            summary_paragraph_index_rule: value.summary_paragraph_index_rule,
            summary_paragraph_data_rule: value.summary_paragraph_data_rule,
            summary_count_rule: value.summary_count_rule,
            review_detail_url: value.review_detail_url,
            review_detail_next_page_url: value.review_detail_next_page_url,
            detail_list_rule: value.detail_list_rule,
            detail_id_rule: value.detail_id_rule,
            detail_avatar_rule: value.detail_avatar_rule,
            detail_name_rule: value.detail_name_rule,
            detail_badge_rule: value.detail_badge_rule,
            detail_content_rule: value.detail_content_rule,
            reply_list_rule: value.reply_list_rule,
            reply_id_rule: value.reply_id_rule,
            reply_avatar_rule: value.reply_avatar_rule,
            reply_name_rule: value.reply_name_rule,
            reply_badge_rule: value.reply_badge_rule,
            reply_content_rule: value.reply_content_rule,
        }
    }
}

/// 目录查询结果，章节索引与卷标保持不变。
#[derive(Debug, Clone)]
pub struct ChapterListDto {
    pub total: i32,
    pub chapters: Vec<ChapterDto>,
}

/// SearchBook 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct SearchBookDto {
    pub book_url: String,
    pub origin: String,
    pub origin_name: String,
    pub book_type: i32,
    pub name: String,
    pub author: String,
    pub kind: Option<String>,
    pub cover_url: Option<String>,
    pub intro: Option<String>,
    pub word_count: Option<String>,
    pub latest_chapter_title: Option<String>,
    pub toc_url: String,
    pub time: i64,
    pub variable: Option<String>,
    pub origin_order: i32,
    pub chapter_word_count_text: Option<String>,
    pub chapter_word_count: i32,
    pub respond_time: i32,
    pub book_score: i32,
    pub has_read_record: bool,
    pub read_record_author: Option<String>,
    pub origins: Vec<String>,
}

impl From<legado_core::models::SearchBook> for SearchBookDto {
    fn from(value: legado_core::models::SearchBook) -> Self {
        Self {
            book_url: value.book_url,
            origin: value.origin,
            origin_name: value.origin_name,
            book_type: value.book_type,
            name: value.name,
            author: value.author,
            kind: value.kind,
            cover_url: value.cover_url,
            intro: value.intro,
            word_count: value.word_count,
            latest_chapter_title: value.latest_chapter_title,
            toc_url: value.toc_url,
            time: value.time,
            variable: value.variable,
            origin_order: value.origin_order,
            chapter_word_count_text: value.chapter_word_count_text,
            chapter_word_count: value.chapter_word_count,
            respond_time: value.respond_time,
            book_score: value.book_score,
            has_read_record: value.has_read_record,
            read_record_author: value.read_record_author,
            origins: value.origins,
        }
    }
}

/// SearchSourceBatch 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct SearchSourceBatchDto {
    pub source_index: usize,
    pub source_url: String,
    pub source_name: String,
    pub books: Vec<SearchBookDto>,
    pub error: Option<String>,
    pub finished_count: usize,
    pub total_count: usize,
    pub is_last: bool,
    pub has_more: bool,
    pub error_class: String,
}

impl From<crate::api::search::SearchSourceBatch> for SearchSourceBatchDto {
    fn from(value: crate::api::search::SearchSourceBatch) -> Self {
        Self {
            source_index: value.source_index,
            source_url: value.source_url,
            source_name: value.source_name,
            books: value.books.into_iter().map(Into::into).collect(),
            error: value.error,
            finished_count: value.finished_count,
            total_count: value.total_count,
            is_last: value.is_last,
            has_more: value.has_more,
            error_class: value.error_class,
        }
    }
}

/// ChangeSourceBatch 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct ChangeSourceBatchDto {
    pub source_index: usize,
    pub source_url: String,
    pub source_name: String,
    pub error: Option<String>,
    pub finished_count: usize,
    pub total_count: usize,
    pub is_last: bool,
    pub matches: Vec<SourceMatchDto>,
}

impl From<crate::api::source_switch::ChangeSourceBatch> for ChangeSourceBatchDto {
    fn from(value: crate::api::source_switch::ChangeSourceBatch) -> Self {
        Self {
            source_index: value.source_index,
            source_url: value.source_url,
            source_name: value.source_name,
            error: value.error,
            finished_count: value.finished_count,
            total_count: value.total_count,
            is_last: value.is_last,
            matches: value.matches.into_iter().map(Into::into).collect(),
        }
    }
}

/// SourceMatch 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct SourceMatchDto {
    pub source_url: String,
    pub source_name: String,
    pub book_url: String,
    pub book_name: String,
    pub author: String,
    pub latest_chapter: Option<String>,
    pub word_count: Option<String>,
    pub score: f64,
    pub chapter_word_count_text: Option<String>,
    pub chapter_word_count: i32,
    pub respond_time: i32,
    pub origin_order: i32,
    pub book_score: i32,
    pub variable: Option<String>,
}

impl From<legado_core::source_matcher::SourceMatch> for SourceMatchDto {
    fn from(value: legado_core::source_matcher::SourceMatch) -> Self {
        Self {
            source_url: value.source_url,
            source_name: value.source_name,
            book_url: value.book_url,
            book_name: value.book_name,
            author: value.author,
            latest_chapter: value.latest_chapter,
            word_count: value.word_count,
            score: value.score,
            chapter_word_count_text: value.chapter_word_count_text,
            chapter_word_count: value.chapter_word_count,
            respond_time: value.respond_time,
            origin_order: value.origin_order,
            book_score: value.book_score,
            variable: value.variable,
        }
    }
}

/// CheckProgress 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct CheckProgressDto {
    pub index: usize,
    pub total: usize,
    pub is_last: bool,
    pub source_name: String,
    pub result: CheckResultDto,
}

impl From<crate::api::source_check_api::CheckProgress> for CheckProgressDto {
    fn from(value: crate::api::source_check_api::CheckProgress) -> Self {
        Self {
            index: value.index,
            total: value.total,
            is_last: value.is_last,
            source_name: value.source_name,
            result: value.result.into(),
        }
    }
}

/// CheckResult 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct CheckResultDto {
    pub source_url: String,
    pub search_ok: bool,
    pub toc_ok: bool,
    pub content_ok: bool,
    pub search_error: Option<String>,
    pub toc_error: Option<String>,
    pub content_error: Option<String>,
    pub total_time_ms: i64,
    pub captcha: Option<CaptchaInfoDto>,
    pub redirect: Option<RedirectInfoDto>,
}

impl From<legado_net::source_checker::CheckResult> for CheckResultDto {
    fn from(value: legado_net::source_checker::CheckResult) -> Self {
        Self {
            source_url: value.source_url,
            search_ok: value.search_ok,
            toc_ok: value.toc_ok,
            content_ok: value.content_ok,
            search_error: value.search_error,
            toc_error: value.toc_error,
            content_error: value.content_error,
            total_time_ms: value.total_time_ms,
            captcha: value.captcha.map(Into::into),
            redirect: value.redirect.map(Into::into),
        }
    }
}

/// CaptchaInfo 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct CaptchaInfoDto {
    pub detected: bool,
    pub captcha_type: Option<String>,
    pub matched_keyword: Option<String>,
}

impl From<legado_net::source_checker::CaptchaInfo> for CaptchaInfoDto {
    fn from(value: legado_net::source_checker::CaptchaInfo) -> Self {
        Self {
            detected: value.detected,
            captcha_type: value.captcha_type,
            matched_keyword: value.matched_keyword,
        }
    }
}

/// RedirectInfo 的类型化事件载荷。
#[derive(Debug, Clone)]
pub struct RedirectInfoDto {
    pub redirected: bool,
    pub original_url: String,
    pub final_url: String,
    pub is_login_redirect: bool,
}

impl From<legado_net::source_checker::RedirectInfo> for RedirectInfoDto {
    fn from(value: legado_net::source_checker::RedirectInfo) -> Self {
        Self {
            redirected: value.redirected,
            original_url: value.original_url,
            final_url: value.final_url,
            is_login_redirect: value.is_login_redirect,
        }
    }
}

/// 书源校验选项；缺省值由原校验器解析。— Codex + Bridge
#[derive(Debug, Clone, Default)]
pub struct SourceCheckConfigDto {
    pub keyword: Option<String>,
    pub step_timeout_ms: Option<u64>,
    pub check_search: Option<bool>,
    pub check_toc: Option<bool>,
    pub check_content: Option<bool>,
    pub detect_captcha: Option<bool>,
    pub detect_redirect: Option<bool>,
}
impl From<SourceCheckConfigDto> for legado_net::source_checker::CheckerConfig {
    fn from(v: SourceCheckConfigDto) -> Self {
        let d = Self::default();
        Self {
            keyword: v.keyword.filter(|s| !s.is_empty()).unwrap_or(d.keyword),
            step_timeout_ms: v.step_timeout_ms.unwrap_or(d.step_timeout_ms),
            check_search: v.check_search.unwrap_or(d.check_search),
            check_toc: v.check_toc.unwrap_or(d.check_toc),
            check_content: v.check_content.unwrap_or(d.check_content),
            detect_captcha: v.detect_captcha.unwrap_or(d.detect_captcha),
            detect_redirect: v.detect_redirect.unwrap_or(d.detect_redirect),
        }
    }
}
#[derive(Debug, Clone, Default)]
pub struct SwitchSearchOptionsDto {
    pub load_info: bool,
    pub load_toc: bool,
    pub load_word_count: bool,
    pub force_refresh: bool,
}
impl From<SwitchSearchOptionsDto> for crate::api::source_switch::SwitchSearchOptions {
    fn from(v: SwitchSearchOptionsDto) -> Self {
        Self {
            load_info: v.load_info,
            load_toc: v.load_toc,
            load_word_count: v.load_word_count,
            force_refresh: v.force_refresh,
        }
    }
}
#[derive(Debug, Clone)]
pub struct SourceSwitchResponseDto {
    pub book_name: String,
    pub author: String,
    pub matches: Vec<SourceMatchDto>,
}
impl From<crate::api::source_switch::SourceSwitchResponse> for SourceSwitchResponseDto {
    fn from(v: crate::api::source_switch::SourceSwitchResponse) -> Self {
        Self {
            book_name: v.book_name,
            author: v.author,
            matches: v.matches.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct AnnotatedCandidateDto {
    pub book_name: String,
    pub author: String,
    pub cover_url: Option<String>,
    pub intro: Option<String>,
    pub latest_chapter: Option<String>,
    pub source_url: String,
    pub source_name: String,
    pub book_url: String,
    pub relevance_score: f64,
    pub origin_order: i32,
    pub has_read_record: bool,
    pub read_record_author: Option<String>,
    pub variable: Option<String>,
}
impl From<crate::api::search::AnnotatedCandidate> for AnnotatedCandidateDto {
    fn from(v: crate::api::search::AnnotatedCandidate) -> Self {
        Self {
            book_name: v.book_name,
            author: v.author,
            cover_url: v.cover_url,
            intro: v.intro,
            latest_chapter: v.latest_chapter,
            source_url: v.source_url,
            source_name: v.source_name,
            book_url: v.book_url,
            relevance_score: v.relevance_score,
            origin_order: v.origin_order,
            has_read_record: v.has_read_record,
            read_record_author: v.read_record_author,
            variable: v.variable,
        }
    }
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PlatformActionKind {
    WebView,
    WebViewGetSource,
    WebViewGetOverrideUrl,
    OpenBrowser,
    StartBrowser,
    OpenUrl,
    OpenVideoPlayer,
    RefreshBookInfo,
    RefreshBookToc,
    RefreshContent,
    CopyText,
    ClearTtsCache,
}

#[derive(Debug, Clone)]
pub struct PlatformActionDto {
    pub action: PlatformActionKind,
    pub url: Option<String>,
    pub html: Option<String>,
    pub js: Option<String>,
    pub title: Option<String>,
    pub mime_type: Option<String>,
    pub text: Option<String>,
    pub message: Option<String>,
    pub result: Option<String>,
    pub cookie: Option<String>,
    pub source_regex: Option<String>,
    pub override_url_regex: Option<String>,
    pub source_key: Option<String>,
    pub tag: Option<String>,
    pub is_float: bool,
    pub is_rule: bool,
    pub cache_first: bool,
    pub delay_time_ms: i64,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub enum TextResponseDto {
    Text(String),
    PlatformAction(PlatformActionDto),
}
impl From<String> for TextResponseDto {
    fn from(raw: String) -> Self {
        fn payload(raw: &str) -> Option<PlatformActionDto> {
            if !raw.trim_start().starts_with('{') {
                return None;
            }
            let value: serde_json::Value = serde_json::from_str(raw).ok()?;
            let action = serde_json::from_value(value.get("action")?.clone()).ok()?;
            let string = |key: &str| {
                value.get(key).filter(|v| !v.is_null()).map(|v| {
                    v.as_str()
                        .map(str::to_owned)
                        .unwrap_or_else(|| v.to_string())
                })
            };
            Some(PlatformActionDto {
                action,
                url: string("url"),
                html: string("html"),
                js: string("js"),
                title: string("title"),
                mime_type: string("mimeType"),
                text: string("text"),
                message: string("message"),
                result: string("result"),
                cookie: string("cookie"),
                source_regex: string("sourceRegex"),
                override_url_regex: string("overrideUrlRegex"),
                source_key: string("sourceKey"),
                tag: string("tag"),
                is_float: value
                    .get("isFloat")
                    .and_then(serde_json::Value::as_bool)
                    .unwrap_or(false),
                is_rule: value
                    .get("isRule")
                    .and_then(serde_json::Value::as_bool)
                    .unwrap_or(false),
                cache_first: value
                    .get("cacheFirst")
                    .and_then(serde_json::Value::as_bool)
                    .unwrap_or(false),
                delay_time_ms: string("delayTime")
                    .and_then(|v| v.parse::<i64>().ok())
                    .unwrap_or(0)
                    .max(0),
            })
        }
        payload(&raw)
            .map(Self::PlatformAction)
            .unwrap_or(Self::Text(raw))
    }
}
