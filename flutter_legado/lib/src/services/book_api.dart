import '../domain/contracts/config_repository.dart';
import '../domain/contracts/app_runtime.dart';
import '../domain/contracts/reading_content_service.dart';
import '../domain/contracts/source_action_service.dart';
import '../domain/contracts/book_source_edit_service.dart';
import '../domain/contracts/source_login_v2_service.dart';
import '../domain/contracts/verification_service.dart';
import '../domain/contracts/webview_bridge_service.dart';
import '../domain/contracts/network_service.dart';
import '../domain/contracts/local_server_service.dart';
import '../domain/contracts/rule_execution_service.dart';
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
import '../domain/contracts/read_aloud_voice_repository.dart';
import '../domain/contracts/tts_cache_repository.dart';
import '../domain/contracts/source_checker.dart';
import '../domain/contracts/book_source_repository.dart';
import '../domain/contracts/bookshelf_repository.dart';
import '../domain/contracts/book_group_repository.dart';
import '../domain/contracts/bookmark_repository.dart';
import '../domain/contracts/read_record_repository.dart';
import '../domain/contracts/http_tts_repository.dart';
import '../domain/contracts/http_tts_synthesizer.dart';

/// 书籍 API 抽象接口
///
/// 仅保留领域能力和运行时的装配引用，消费者通过窄接口访问。
/// 实现类：
/// - [RustApi]：真实 FFI 实现（需要 Rust DLL）
/// - MockBookApi：纯 Dart Mock 实现（无 DLL 可跑，UI 轨开发用）
abstract class BookApi {
  ReadingContentService get readingContentService;
  SourceActionService get sourceActionService;
  BookSourceEditService get bookSourceEditService;
  SourceLoginV2Service get sourceLoginV2Service;
  VerificationService get verificationService;
  WebViewBridgeService get webViewBridgeService;
  NetworkService get networkService;
  LocalServerService get localServerService;
  RuleExecutionService get ruleExecutionService;
  SourceSwitchService get sourceSwitchService;
  CoverSearchService get coverSearchService;
  CoverRuleRepository get coverRuleRepository;
  ExploreService get exploreService;
  ExploreStateRepository get exploreStateRepository;
  BookSourceQueryService get bookSourceQueryService;
  BookSourceDebugService get bookSourceDebugService;
  AutoTaskRepository get autoTaskRepository;
  AutoTaskService get autoTaskService;
  BookImageRepository get bookImageRepository;
  AudioCacheRepository get audioCacheRepository;
  AudioCacheDownloadService get audioCacheDownloadService;
  AudioBookService get audioBookService;
  VideoDanmakuService get videoDanmakuService;

  LocalBookService get localBookService;
  BookArchiveService get bookArchiveService;
  BookExportService get bookExportService;
  ReviewService get reviewService;

  CacheRepository get cacheRepository;
  DatabaseMaintenanceService get databaseMaintenanceService;
  AppLogRepository get appLogRepository;
  DictionaryService get dictionaryService;
  DictRuleRepository get dictRuleRepository;
  HighlightRepository get highlightRepository;
  HighlightRuleRepository get highlightRuleRepository;
  RuleSubRepository get ruleSubRepository;
  RuleSubService get ruleSubService;
  ReplaceRuleRepository get replaceRuleRepository;
  ReplaceRuleService get replaceRuleService;
  RssSourceRepository get rssSourceRepository;
  RssArticleRepository get rssArticleRepository;
  RssReadRecordRepository get rssReadRecordRepository;
  RssStarRepository get rssStarRepository;
  ChapterCacheRepository get chapterCacheRepository;
  CacheDownloadService get cacheDownloadService;
  ReadingRepository get readingRepository;
  BackupRepository get backupRepository;
  WebDavService get webDavService;

  /// 搜索执行与历史共享装配。
  SearchService get searchService;
  SearchHistoryRepository get searchHistoryRepository;

  CloudTtsRepository get cloudTtsRepository;

  /// 共享书源配置访问，登录与校验仍由各自能力承担。
  BookSourceRepository get bookSourceRepository;

  /// 与发起校验的会话共享同一实例。
  SourceChecker get sourceChecker;

  /// 经典、手动与 WebView 登录共用的凭据存储。
  SourceLoginRepository get sourceLoginRepository;

  /// 共享书架数据访问，不持有阅读器会话状态。
  BookshelfRepository get bookshelfRepository;

  /// 共享分组定义与显示配置访问。
  BookGroupRepository get bookGroupRepository;

  /// 共享应用装配的书签数据访问实例；书签 CRUD 由窄接口承担。
  BookmarkRepository get bookmarkRepository;

  /// 共享应用装配的阅读记录实例；数据读写由窄接口承担。
  ReadRecordRepository get readRecordRepository;

  /// 共享 HTTP 朗读引擎配置实例，不包含系统语音或播放状态。
  HttpTtsRepository get httpTtsRepository;
  ReadAloudVoiceRepository get readAloudVoiceRepository;

  /// 共享 HTTP 合成能力；缓存目录由应用生命周期单独注入。
  HttpTtsSynthesizer get httpTtsSynthesizer;
  TtsCacheRepository get ttsCacheRepository;

  ConfigRepository get configRepository;
  AppRuntime get runtime;
}
