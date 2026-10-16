import '../domain/contracts/cover_rule_repository.dart';
import '../domain/contracts/source_switch_service.dart';
import '../domain/contracts/cover_search_service.dart';
import '../domain/contracts/explore_service.dart';
import '../domain/contracts/explore_state_repository.dart';
import '../domain/contracts/book_source_query_service.dart';
import '../domain/contracts/book_source_debug_service.dart';
import '../domain/contracts/auto_task_repository.dart';
import '../domain/contracts/auto_task_service.dart';
import '../domain/contracts/book_image_repository.dart';
import '../domain/contracts/audio_cache_repository.dart';
import '../domain/contracts/audio_cache_download_service.dart';
import '../domain/contracts/audio_book_service.dart';
import '../domain/contracts/video_danmaku_service.dart';
import '../domain/contracts/local_book_service.dart';
import '../domain/contracts/book_archive_service.dart';
import '../domain/contracts/book_export_service.dart';
import '../domain/contracts/review_service.dart';
import '../domain/contracts/cache_repository.dart';
import '../domain/contracts/database_maintenance_service.dart';
import '../domain/contracts/app_log_repository.dart';
import '../domain/contracts/dictionary_service.dart';
import '../domain/contracts/dict_rule_repository.dart';
import '../domain/contracts/highlight_repository.dart';
import '../domain/contracts/highlight_rule_repository.dart';
import '../domain/contracts/rule_sub_repository.dart';
import '../domain/contracts/rule_sub_service.dart';
import '../domain/contracts/replace_rule_repository.dart';
import '../domain/contracts/replace_rule_service.dart';
import '../domain/contracts/rss_source_repository.dart';
import '../domain/contracts/rss_article_repository.dart';
import '../domain/contracts/rss_read_record_repository.dart';
import '../domain/contracts/rss_star_repository.dart';
import '../domain/contracts/chapter_cache_repository.dart';
import '../domain/contracts/cache_download_service.dart';
import '../domain/contracts/reading_repository.dart';
import '../domain/contracts/backup_repository.dart';
import '../domain/contracts/webdav_service.dart';
import '../domain/contracts/search_service.dart';
import '../domain/contracts/search_history_repository.dart';
import '../domain/contracts/source_login_repository.dart';
import '../domain/contracts/cloud_tts_repository.dart';
import '../data/repositories/rust_cloud_tts_repository.dart';
import '../data/repositories/rust_read_aloud_voice_repository.dart';
import '../domain/contracts/read_aloud_voice_repository.dart';
import '../data/repositories/rust_tts_cache_repository.dart';
import '../domain/contracts/tts_cache_repository.dart';
import '../domain/contracts/source_checker.dart';
import '../domain/contracts/book_source_repository.dart';
import '../domain/contracts/bookshelf_repository.dart';
import '../domain/contracts/book_group_repository.dart';

import 'dart:convert';

import '../data/bridge/runtime_configuration.dart';
import '../data/bridge/rust_json_decode.dart';
import '../domain/contracts/bookmark_repository.dart';
import '../domain/contracts/read_record_repository.dart';
import '../domain/contracts/http_tts_repository.dart';
import '../domain/contracts/http_tts_synthesizer.dart';

import '../bridge/rust_lib.dart' as bridge;
import 'book_api.dart';
export '../data/bridge/rust_api_exception.dart';
import 'platform_bridge_service.dart';

part 'rust_api_decode.part.dart';
part 'rust_api_sources.part.dart';
part 'rust_api_reader_data.part.dart';
part 'rust_api_discovery_cache.part.dart';
part 'rust_api_media_format.part.dart';

// ↑ 分域 part 文件（体检 §三.16 超长文件拆分）：RustApi 按域拆为 mixin 组合，
// 各 mixin 方法原样搬移、合集实现 BookApi，零行为变更。

/// Rust FFI 统一访问层
///
/// 所有数据库操作通过 flutter_rust_bridge 生成的桥接函数调用 Rust 侧。
/// 尚未在 Rust FFI 中暴露的方法使用 Dart 侧 fallback 实现。
class RustApi
    with
        RustApiDecode,
        RustApiSources,
        RustApiReaderData,
        RustApiDiscoveryCache,
        RustApiMediaFormat
    implements BookApi, ReadingConfigSync, ThemeConfigSync {
  @override
  CloudTtsRepository get cloudTtsRepository => const RustCloudTtsRepository();
  factory RustApi({
    required SourceSwitchService sourceSwitchService,
    required CoverSearchService coverSearchService,
    required CoverRuleRepository coverRuleRepository,
    required ExploreService exploreService,
    required ExploreStateRepository exploreStateRepository,
    required BookSourceQueryService bookSourceQueryService,
    required BookSourceDebugService bookSourceDebugService,
    required AutoTaskRepository autoTaskRepository,
    required AutoTaskService autoTaskService,
    required BookImageRepository bookImageRepository,
    required AudioCacheRepository audioCacheRepository,
    required AudioCacheDownloadService audioCacheDownloadService,
    required AudioBookService audioBookService,
    required VideoDanmakuService videoDanmakuService,

    required LocalBookService localBookService,
    required BookArchiveService bookArchiveService,
    required BookExportService bookExportService,
    required ReviewService reviewService,

    required CacheRepository cacheRepository,
    required DatabaseMaintenanceService databaseMaintenanceService,
    required AppLogRepository appLogRepository,
    required DictionaryService dictionaryService,
    required DictRuleRepository dictRuleRepository,
    required HighlightRepository highlightRepository,
    required HighlightRuleRepository highlightRuleRepository,
    required RuleSubRepository ruleSubRepository,
    required RuleSubService ruleSubService,
    required ReplaceRuleRepository replaceRuleRepository,
    required ReplaceRuleService replaceRuleService,
    required RssSourceRepository rssSourceRepository,
    required RssArticleRepository rssArticleRepository,
    required RssReadRecordRepository rssReadRecordRepository,
    required RssStarRepository rssStarRepository,
    required ChapterCacheRepository chapterCacheRepository,
    required CacheDownloadService cacheDownloadService,
    required ReadingRepository readingRepository,
    required Future<void> Function() initialize,
    required ReadingConfigSync readingConfigSync,
    required BookmarkRepository bookmarkRepository,
    required ReadRecordRepository readRecordRepository,
    required HttpTtsRepository httpTtsRepository,
    required HttpTtsSynthesizer httpTtsSynthesizer,
    required BookshelfRepository bookshelfRepository,
    required BookGroupRepository bookGroupRepository,
    required BookSourceRepository bookSourceRepository,
    required SourceChecker sourceChecker,
    required SourceLoginRepository sourceLoginRepository,
    required SearchService searchService,
    required SearchHistoryRepository searchHistoryRepository,
    required BackupRepository backupRepository,
    required WebDavService webDavService,
  }) => RustApi._(
    sourceSwitchService,
    coverSearchService,
    coverRuleRepository,
    exploreService,
    exploreStateRepository,
    bookSourceQueryService,
    bookSourceDebugService,
    autoTaskRepository,
    autoTaskService,
    bookImageRepository,
    audioCacheRepository,
    audioCacheDownloadService,
    audioBookService,
    videoDanmakuService,
    localBookService,
    bookArchiveService,
    bookExportService,
    reviewService,
    cacheRepository,
    databaseMaintenanceService,
    appLogRepository,
    dictionaryService,
    dictRuleRepository,
    highlightRepository,
    highlightRuleRepository,
    ruleSubRepository,
    ruleSubService,
    replaceRuleRepository,
    replaceRuleService,
    rssSourceRepository,
    rssArticleRepository,
    rssReadRecordRepository,
    rssStarRepository,
    chapterCacheRepository,
    cacheDownloadService,
    readingRepository,
    initialize,
    readingConfigSync,
    bookmarkRepository,
    readRecordRepository,
    httpTtsRepository,
    httpTtsSynthesizer,
    bookshelfRepository,
    bookGroupRepository,
    bookSourceRepository,
    sourceChecker,
    sourceLoginRepository,
    searchService,
    searchHistoryRepository,
    backupRepository,
    webDavService,
  );

  RustApi._(
    this.sourceSwitchService,
    this.coverSearchService,
    this.coverRuleRepository,
    this.exploreService,
    this.exploreStateRepository,
    this.bookSourceQueryService,
    this.bookSourceDebugService,
    this.autoTaskRepository,
    this.autoTaskService,
    this.bookImageRepository,
    this.audioCacheRepository,
    this.audioCacheDownloadService,
    this.audioBookService,
    this.videoDanmakuService,
    this.localBookService,
    this.bookArchiveService,
    this.bookExportService,
    this.reviewService,
    this.cacheRepository,
    this.databaseMaintenanceService,
    this.appLogRepository,
    this.dictionaryService,
    this.dictRuleRepository,
    this.highlightRepository,
    this.highlightRuleRepository,
    this.ruleSubRepository,
    this.ruleSubService,
    this.replaceRuleRepository,
    this.replaceRuleService,
    this.rssSourceRepository,
    this.rssArticleRepository,
    this.rssReadRecordRepository,
    this.rssStarRepository,
    this.chapterCacheRepository,
    this.cacheDownloadService,
    this.readingRepository,
    this._initialize,
    this._readingConfigSync,
    this.bookmarkRepository,
    this.readRecordRepository,
    this.httpTtsRepository,
    this.httpTtsSynthesizer,
    this.bookshelfRepository,
    this.bookGroupRepository,
    this.bookSourceRepository,
    this.sourceChecker,
    this.sourceLoginRepository,
    this.searchService,
    this.searchHistoryRepository,
    this.backupRepository,
    this.webDavService,
  );

  @override
  final SourceSwitchService sourceSwitchService;
  @override
  final CoverSearchService coverSearchService;
  @override
  final CoverRuleRepository coverRuleRepository;
  @override
  final ExploreService exploreService;
  @override
  final ExploreStateRepository exploreStateRepository;
  @override
  final BookSourceQueryService bookSourceQueryService;
  @override
  final BookSourceDebugService bookSourceDebugService;

  @override
  final AutoTaskRepository autoTaskRepository;
  @override
  final AutoTaskService autoTaskService;

  @override
  final BookImageRepository bookImageRepository;
  @override
  final AudioCacheRepository audioCacheRepository;
  @override
  final AudioCacheDownloadService audioCacheDownloadService;
  @override
  final AudioBookService audioBookService;
  @override
  final VideoDanmakuService videoDanmakuService;

  @override
  final LocalBookService localBookService;
  @override
  final BookArchiveService bookArchiveService;
  @override
  final BookExportService bookExportService;
  @override
  final ReviewService reviewService;

  @override
  final CacheRepository cacheRepository;
  @override
  final DatabaseMaintenanceService databaseMaintenanceService;

  @override
  final RuleSubRepository ruleSubRepository;
  @override
  final HighlightRepository highlightRepository;
  @override
  final DictionaryService dictionaryService;
  @override
  final AppLogRepository appLogRepository;
  @override
  final DictRuleRepository dictRuleRepository;
  @override
  final HighlightRuleRepository highlightRuleRepository;
  @override
  final RuleSubService ruleSubService;

  @override
  final ReplaceRuleRepository replaceRuleRepository;
  @override
  final ReplaceRuleService replaceRuleService;

  @override
  final RssSourceRepository rssSourceRepository;

  @override
  final RssArticleRepository rssArticleRepository;

  @override
  final RssReadRecordRepository rssReadRecordRepository;

  @override
  final RssStarRepository rssStarRepository;

  @override
  final BackupRepository backupRepository;
  @override
  final WebDavService webDavService;

  @override
  final ReadingRepository readingRepository;
  @override
  final ChapterCacheRepository chapterCacheRepository;
  @override
  final CacheDownloadService cacheDownloadService;

  final Future<void> Function() _initialize;
  final ReadingConfigSync _readingConfigSync;

  @override
  final BookmarkRepository bookmarkRepository;

  @override
  final ReadRecordRepository readRecordRepository;

  @override
  final HttpTtsRepository httpTtsRepository;
  @override
  ReadAloudVoiceRepository get readAloudVoiceRepository =>
      const RustReadAloudVoiceRepository();

  @override
  final HttpTtsSynthesizer httpTtsSynthesizer;

  @override
  TtsCacheRepository get ttsCacheRepository => const RustTtsCacheRepository();

  @override
  final BookshelfRepository bookshelfRepository;

  @override
  final BookGroupRepository bookGroupRepository;

  @override
  final BookSourceRepository bookSourceRepository;

  @override
  final SourceChecker sourceChecker;

  @override
  final SourceLoginRepository sourceLoginRepository;

  @override
  final SearchService searchService;
  @override
  final SearchHistoryRepository searchHistoryRepository;

  /// 应用装配点提供完整生命周期，不在业务适配器中读取平台或设置。
  @override
  Future<void> initialize() => _initialize();

  /// 保留既有能力入口，调用方通过 ReadingConfigSync 注入访问。
  @override
  Future<void> refreshReadBookConfig() =>
      _readingConfigSync.refreshReadBookConfig();

  @override
  Future<void> synchronizeThemeConfig() => _readingConfigSync is ThemeConfigSync
      ? (_readingConfigSync as ThemeConfigSync).synchronizeThemeConfig()
      : Future.value();

  /// 获取 Rust 引擎版本号
  @override
  Future<String> getVersion() => bridge.version();
}
