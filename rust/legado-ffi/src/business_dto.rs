//! 稳定业务快照；规则、脚本与真正文档保留字符串边界。— Codex + Bridge

/// 音频跳过窗口；单位为毫秒，未知或过短音频不生成窗口。
#[derive(Debug, Clone)]
pub struct AudioSkipWindowDto {
    pub intro_end_ms: i64,
    pub outro_start_ms: i64,
}
impl From<legado_core::audio_skip_policy::AudioSkipWindow> for AudioSkipWindowDto {
    fn from(value: legado_core::audio_skip_policy::AudioSkipWindow) -> Self {
        Self {
            intro_end_ms: value.intro_end_ms,
            outro_start_ms: value.outro_start_ms,
        }
    }
}

/// 规则执行的固定外层，结果中的文本不再另行编码。
#[derive(Debug, Clone)]
pub struct RuleParseResultDto {
    pub results: Vec<String>,
    pub count: u64,
}

/// 旧版文件导入的实际计数及逐文件消息。
#[derive(Debug, Clone)]
pub struct OldDataImportResultDto {
    pub books: u64,
    pub book_sources: u64,
    pub replace_rules: u64,
    pub messages: Vec<String>,
}
impl From<legado_engine::backup_service::OldImportResult> for OldDataImportResultDto {
    fn from(v: legado_engine::backup_service::OldImportResult) -> Self {
        Self {
            books: v.books as u64,
            book_sources: v.book_sources as u64,
            replace_rules: v.replace_rules as u64,
            messages: v.messages,
        }
    }
}

/// 同步返回两份真实文档；只对固定外层类型化。
#[derive(Debug, Clone)]
pub struct WebDavSyncResultDto {
    pub books: String,
    pub sources: String,
}

#[derive(Debug, Clone)]
pub struct RssSourceDto {
    pub source_url: String,
    pub source_name: String,
    pub source_icon: String,
    pub source_group: Option<String>,
    pub source_comment: Option<String>,
    pub enabled: bool,
    pub variable_comment: Option<String>,
    pub js_lib: Option<String>,
    pub enabled_cookie_jar: Option<bool>,
    pub concurrent_rate: Option<String>,
    pub header: Option<String>,
    pub login_url: Option<String>,
    pub login_ui: Option<String>,
    pub login_check_js: Option<String>,
    pub cover_decode_js: Option<String>,
    pub sort_url: Option<String>,
    pub single_url: bool,
    pub article_style: i32,
    pub rule_articles: Option<String>,
    pub rule_next_page: Option<String>,
    pub rule_title: Option<String>,
    pub rule_pub_date: Option<String>,
    pub rule_description: Option<String>,
    pub rule_image: Option<String>,
    pub rule_link: Option<String>,
    pub rule_content: Option<String>,
    pub content_whitelist: Option<String>,
    pub content_blacklist: Option<String>,
    pub should_override_url_loading: Option<String>,
    pub style: Option<String>,
    pub enable_js: bool,
    pub load_with_base_url: bool,
    pub inject_js: Option<String>,
    pub preload_js: Option<String>,
    pub start_html: Option<String>,
    pub start_style: Option<String>,
    pub start_js: Option<String>,
    pub show_web_log: bool,
    pub last_update_time: i64,
    pub custom_order: i32,
    pub rss_type: i32,
    pub preload: bool,
    pub cache_first: bool,
    pub search_url: Option<String>,
}
impl From<legado_core::models::RssSource> for RssSourceDto {
    fn from(v: legado_core::models::RssSource) -> Self {
        Self {
            source_url: v.source_url,
            source_name: v.source_name,
            source_icon: v.source_icon,
            source_group: v.source_group,
            source_comment: v.source_comment,
            enabled: v.enabled,
            variable_comment: v.variable_comment,
            js_lib: v.js_lib,
            enabled_cookie_jar: v.enabled_cookie_jar,
            concurrent_rate: v.concurrent_rate,
            header: v.header,
            login_url: v.login_url,
            login_ui: v.login_ui,
            login_check_js: v.login_check_js,
            cover_decode_js: v.cover_decode_js,
            sort_url: v.sort_url,
            single_url: v.single_url,
            article_style: v.article_style,
            rule_articles: v.rule_articles,
            rule_next_page: v.rule_next_page,
            rule_title: v.rule_title,
            rule_pub_date: v.rule_pub_date,
            rule_description: v.rule_description,
            rule_image: v.rule_image,
            rule_link: v.rule_link,
            rule_content: v.rule_content,
            content_whitelist: v.content_whitelist,
            content_blacklist: v.content_blacklist,
            should_override_url_loading: v.should_override_url_loading,
            style: v.style,
            enable_js: v.enable_js,
            load_with_base_url: v.load_with_base_url,
            inject_js: v.inject_js,
            preload_js: v.preload_js,
            start_html: v.start_html,
            start_style: v.start_style,
            start_js: v.start_js,
            show_web_log: v.show_web_log,
            last_update_time: v.last_update_time,
            custom_order: v.custom_order,
            rss_type: v.rss_type,
            preload: v.preload,
            cache_first: v.cache_first,
            search_url: v.search_url,
        }
    }
}
impl From<RssSourceDto> for legado_core::models::RssSource {
    fn from(v: RssSourceDto) -> Self {
        Self {
            source_url: v.source_url,
            source_name: v.source_name,
            source_icon: v.source_icon,
            source_group: v.source_group,
            source_comment: v.source_comment,
            enabled: v.enabled,
            variable_comment: v.variable_comment,
            js_lib: v.js_lib,
            enabled_cookie_jar: v.enabled_cookie_jar,
            concurrent_rate: v.concurrent_rate,
            header: v.header,
            login_url: v.login_url,
            login_ui: v.login_ui,
            login_check_js: v.login_check_js,
            cover_decode_js: v.cover_decode_js,
            sort_url: v.sort_url,
            single_url: v.single_url,
            article_style: v.article_style,
            rule_articles: v.rule_articles,
            rule_next_page: v.rule_next_page,
            rule_title: v.rule_title,
            rule_pub_date: v.rule_pub_date,
            rule_description: v.rule_description,
            rule_image: v.rule_image,
            rule_link: v.rule_link,
            rule_content: v.rule_content,
            content_whitelist: v.content_whitelist,
            content_blacklist: v.content_blacklist,
            should_override_url_loading: v.should_override_url_loading,
            style: v.style,
            enable_js: v.enable_js,
            load_with_base_url: v.load_with_base_url,
            inject_js: v.inject_js,
            preload_js: v.preload_js,
            start_html: v.start_html,
            start_style: v.start_style,
            start_js: v.start_js,
            show_web_log: v.show_web_log,
            last_update_time: v.last_update_time,
            custom_order: v.custom_order,
            rss_type: v.rss_type,
            preload: v.preload,
            cache_first: v.cache_first,
            search_url: v.search_url,
        }
    }
}
#[derive(Debug, Clone)]
pub struct RssArticleDto {
    pub title: String,
    pub link: String,
    pub description: Option<String>,
    pub pub_date: Option<String>,
    pub image_url: Option<String>,
}
impl From<crate::api::rss::RssArticle> for RssArticleDto {
    fn from(v: crate::api::rss::RssArticle) -> Self {
        Self {
            title: v.title,
            link: v.link,
            description: v.description,
            pub_date: v.pub_date,
            image_url: v.image_url,
        }
    }
}
#[derive(Debug, Clone)]
pub struct RssStarSnapshotDto {
    pub origin: String,
    pub sort: String,
    pub title: String,
    pub star_time: i64,
    pub link: Option<String>,
    pub pub_date: Option<String>,
    pub description: Option<String>,
    pub content: Option<String>,
    pub image: Option<String>,
    pub variable: Option<String>,
}
impl From<crate::api::rss_star_api::RssStarDto> for RssStarSnapshotDto {
    fn from(v: crate::api::rss_star_api::RssStarDto) -> Self {
        Self {
            origin: v.origin,
            sort: v.sort,
            title: v.title,
            star_time: v.star_time,
            link: v.link,
            pub_date: v.pub_date,
            description: v.description,
            content: v.content,
            image: v.image,
            variable: v.variable,
        }
    }
}
#[derive(Debug, Clone)]
pub struct RssReadRecordDto {
    pub origin: String,
    pub title: String,
    pub link: Option<String>,
    pub read_time: i64,
}
impl From<legado_db::repository::rss_read_record_repository::RssReadRecordRow>
    for RssReadRecordDto
{
    fn from(v: legado_db::repository::rss_read_record_repository::RssReadRecordRow) -> Self {
        Self {
            origin: v.origin,
            title: v.title,
            link: v.link,
            read_time: v.read_time,
        }
    }
}
#[derive(Debug, Clone)]
pub struct SearchHistoryDto {
    pub word: String,
    pub usage: i32,
    pub last_use_time: i64,
}
impl From<crate::api::search_history_api::SearchHistoryItem> for SearchHistoryDto {
    fn from(v: crate::api::search_history_api::SearchHistoryItem) -> Self {
        Self {
            word: v.word,
            usage: v.usage,
            last_use_time: v.last_use_time,
        }
    }
}
#[derive(Debug, Clone)]
pub struct ReplaceRuleDto {
    pub id: i64,
    pub name: String,
    pub group: Option<String>,
    pub pattern: String,
    pub replacement: String,
    pub scope: Option<String>,
    pub scope_title: bool,
    pub scope_content: bool,
    pub scope_source: bool,
    pub exclude_scope: Option<String>,
    pub is_enabled: bool,
    pub is_regex: bool,
    pub timeout_millisecond: i64,
    pub order: i32,
}
impl From<legado_core::models::ReplaceRule> for ReplaceRuleDto {
    fn from(v: legado_core::models::ReplaceRule) -> Self {
        Self {
            id: v.id,
            name: v.name,
            group: v.group,
            pattern: v.pattern,
            replacement: v.replacement,
            scope: v.scope,
            scope_title: v.scope_title,
            scope_content: v.scope_content,
            scope_source: v.scope_source,
            exclude_scope: v.exclude_scope,
            is_enabled: v.is_enabled,
            is_regex: v.is_regex,
            timeout_millisecond: v.timeout_millisecond,
            order: v.order,
        }
    }
}
#[derive(Debug, Clone)]
pub struct DictEntryDto {
    pub word: String,
    pub phonetic: String,
    pub definitions: Vec<String>,
}
impl From<crate::api::dict_api::DictEntry> for DictEntryDto {
    fn from(v: crate::api::dict_api::DictEntry) -> Self {
        Self {
            word: v.word,
            phonetic: v.phonetic,
            definitions: v.definitions,
        }
    }
}
#[derive(Debug, Clone)]
pub struct DictionaryRuleDto {
    pub id: i64,
    pub name: String,
    pub url_rule: String,
    pub show_rule: String,
    pub enabled: bool,
    pub sort_number: i32,
}
impl From<crate::api::dict_api::DictRuleDto> for DictionaryRuleDto {
    fn from(v: crate::api::dict_api::DictRuleDto) -> Self {
        Self {
            id: v.id,
            name: v.name,
            url_rule: v.url_rule,
            show_rule: v.show_rule,
            enabled: v.enabled,
            sort_number: v.sort_number,
        }
    }
}
#[derive(Debug, Clone)]
pub struct RuleSubscriptionDto {
    pub id: i64,
    pub url: String,
    pub name: String,
    pub sub_type: String,
    pub last_update: i64,
    pub version: String,
    pub is_enabled: bool,
    pub created_at: i64,
    pub custom_order: i32,
    pub auto_update: bool,
    pub update_interval: i32,
    pub silent_update: bool,
    pub js: Option<String>,
    pub show_rule: Option<String>,
    pub source_url: Option<String>,
}
impl From<legado_db::RuleSubRecord> for RuleSubscriptionDto {
    fn from(v: legado_db::RuleSubRecord) -> Self {
        Self {
            id: v.id,
            url: v.url,
            name: v.name,
            sub_type: v.sub_type,
            last_update: v.last_update,
            version: v.version,
            is_enabled: v.is_enabled,
            created_at: v.created_at,
            custom_order: v.custom_order,
            auto_update: v.auto_update,
            update_interval: v.update_interval,
            silent_update: v.silent_update,
            js: v.js,
            show_rule: v.show_rule,
            source_url: v.source_url,
        }
    }
}
impl From<RuleSubscriptionDto> for legado_db::RuleSubRecord {
    fn from(v: RuleSubscriptionDto) -> Self {
        Self {
            id: v.id,
            url: v.url,
            name: v.name,
            sub_type: v.sub_type,
            last_update: v.last_update,
            version: v.version,
            is_enabled: v.is_enabled,
            created_at: v.created_at,
            custom_order: v.custom_order,
            auto_update: v.auto_update,
            update_interval: v.update_interval,
            silent_update: v.silent_update,
            js: v.js,
            show_rule: v.show_rule,
            source_url: v.source_url,
        }
    }
}
#[derive(Debug, Clone)]
pub struct SubscriptionCheckDto {
    pub id: i64,
    pub url: String,
    pub name: String,
    pub due_for_update: bool,
    pub has_update: bool,
    pub remote_version: Option<String>,
    pub error: Option<String>,
}
impl From<crate::api::rule_sub_api::CheckUpdateResponse> for SubscriptionCheckDto {
    fn from(v: crate::api::rule_sub_api::CheckUpdateResponse) -> Self {
        Self {
            id: v.id,
            url: v.url,
            name: v.name,
            due_for_update: v.due_for_update,
            has_update: v.has_update,
            remote_version: v.remote_version,
            error: v.error,
        }
    }
}
#[derive(Debug, Clone)]
pub struct SubscriptionApplyDto {
    pub id: i64,
    pub url: String,
    pub success: bool,
    pub items_added: usize,
    pub items_updated: usize,
    pub items_removed: usize,
    pub total_items: usize,
    pub error: Option<String>,
}
impl From<crate::api::rule_sub_api::ApplyUpdateResponse> for SubscriptionApplyDto {
    fn from(v: crate::api::rule_sub_api::ApplyUpdateResponse) -> Self {
        Self {
            id: v.id,
            url: v.url,
            success: v.success,
            items_added: v.items_added,
            items_updated: v.items_updated,
            items_removed: v.items_removed,
            total_items: v.total_items,
            error: v.error,
        }
    }
}
#[derive(Debug, Clone)]
pub struct BackupRestoreResultDto {
    pub stats: RestoreStatsDto,
    pub preferences_json: String,
    pub sensitive_json: String,
    pub warnings: Vec<String>,
}
#[derive(Debug, Clone)]
pub struct RestoreStatsDto {
    pub books: usize,
    pub bookmarks: usize,
    pub replace_rules: usize,
    pub book_sources: usize,
    pub rss_sources: usize,
    pub read_records: usize,
    pub additional: std::collections::HashMap<String, usize>,
}
impl From<crate::api::backup_api::RestoreStats> for RestoreStatsDto {
    fn from(v: crate::api::backup_api::RestoreStats) -> Self {
        Self {
            books: v.books,
            bookmarks: v.bookmarks,
            replace_rules: v.replace_rules,
            book_sources: v.book_sources,
            rss_sources: v.rss_sources,
            read_records: v.read_records,
            additional: v.additional,
        }
    }
}
#[derive(Debug, Clone, Copy)]
pub enum LogLevelDto {
    Message,
    Crash,
    Http,
}
impl From<legado_core::app_log::LogLevel> for LogLevelDto {
    fn from(v: legado_core::app_log::LogLevel) -> Self {
        match v {
            legado_core::app_log::LogLevel::Message => Self::Message,
            legado_core::app_log::LogLevel::Crash => Self::Crash,
            legado_core::app_log::LogLevel::Http => Self::Http,
        }
    }
}
#[derive(Debug, Clone)]
pub struct AppLogDto {
    pub timestamp: i64,
    pub level: LogLevelDto,
    pub message: String,
}
impl From<legado_core::app_log::LogEntry> for AppLogDto {
    fn from(v: legado_core::app_log::LogEntry) -> Self {
        Self {
            timestamp: v.timestamp,
            level: v.level.into(),
            message: v.message,
        }
    }
}
#[derive(Debug, Clone, serde::Serialize)]
pub struct BackupFileDto {
    pub name: String,
    pub path: String,
    pub size: u64,
    pub modified: i64,
}
#[derive(Debug, Clone)]
pub struct BookOrderDto {
    pub book_url: String,
    pub order: i32,
}
#[derive(Debug, Clone)]
pub struct CachedChapterDto {
    pub url: String,
    pub word_count: String,
}
impl From<crate::api::cache_api::CachedChapterEntry> for CachedChapterDto {
    fn from(v: crate::api::cache_api::CachedChapterEntry) -> Self {
        Self {
            url: v.url,
            word_count: v.word_count,
        }
    }
}
