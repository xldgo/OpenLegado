import '../../data/repositories/rust_cover_rule_repository.dart';
import '../../data/services/rust_source_switch_service.dart';
import '../../data/services/rust_cover_search_service.dart';
import '../../data/services/rust_explore_service.dart';
import '../../data/repositories/rust_explore_state_repository.dart';
import '../../data/services/rust_book_source_query_service.dart';
import '../../data/services/rust_book_source_debug_service.dart';
import '../../data/repositories/rust_auto_task_repository.dart';
import '../../data/services/rust_auto_task_service.dart';
import '../../data/repositories/rust_book_image_repository.dart';
import '../../data/repositories/rust_audio_cache_repository.dart';
import '../../data/services/rust_audio_cache_download_service.dart';
import '../../data/services/rust_audio_book_service.dart';
import '../../data/services/rust_video_danmaku_service.dart';
import '../../data/services/rust_local_book_service.dart';
import '../../data/services/rust_book_archive_service.dart';
import '../../data/services/rust_book_export_service.dart';
import '../../data/services/rust_review_service.dart';
import '../../data/repositories/rust_cache_repository.dart';
import '../../data/services/rust_database_maintenance_service.dart';
import '../../data/repositories/rust_app_log_repository.dart';
import '../../data/services/rust_dictionary_service.dart';
import '../../data/repositories/rust_dict_rule_repository.dart';
import '../../data/repositories/rust_highlight_repository.dart';
import '../../data/repositories/rust_highlight_rule_repository.dart';
import '../../data/repositories/rust_rule_sub_repository.dart';
import '../../data/services/rust_rule_sub_service.dart';
import '../../data/repositories/rust_replace_rule_repository.dart';
import '../../data/services/rust_replace_rule_service.dart';
import '../../data/repositories/rust_rss_source_repository.dart';
import '../../data/repositories/rust_rss_article_repository.dart';
import '../../data/repositories/rust_rss_read_record_repository.dart';
import '../../data/repositories/rust_rss_star_repository.dart';
import '../../data/repositories/rust_chapter_cache_repository.dart';
import '../../data/services/rust_cache_download_service.dart';
import '../../data/repositories/rust_reading_repository.dart';
import '../../services/platform_bridge_service.dart';
import '../../data/repositories/rust_backup_repository.dart';
import '../../data/services/rust_webdav_service.dart';
import '../../data/services/rust_search_service.dart';
import '../../data/repositories/rust_search_history_repository.dart';
import '../../data/repositories/rust_source_login_repository.dart';
import '../../data/services/rust_source_checker.dart';
import '../../data/repositories/rust_book_source_repository.dart';
import '../../services/cover_decode_loader.dart';
import '../../data/repositories/rust_bookshelf_repository.dart';
import '../../data/repositories/rust_book_group_repository.dart';
import '../../data/bridge/runtime_configuration.dart';
import '../../data/services/rust_http_tts_synthesizer.dart';
import '../../data/bridge/rust_runtime.dart';
import '../../data/repositories/rust_bookmark_repository.dart';
import '../../data/repositories/rust_read_record_repository.dart';
import '../../data/repositories/rust_http_tts_repository.dart';
import '../../platform/app_environment.dart';
import '../../services/book_api.dart';
import '../../services/mock_book_api.dart';
import '../../services/rust_api.dart';
import 'rust_bootstrap.dart';
import 'settings_runtime_configuration.dart';

/// 应用装配点集中选择实现和生命周期。— Codex + UI
BookApi createBookApi({
  bool useMock = const bool.fromEnvironment('USE_MOCK'),
  RustBootstrap? bootstrap,
  RuntimeConfigurationSource? configurationSource,
}) {
  if (useMock) return MockBookApi();
  final startup =
      bootstrap ??
      RustBootstrap(
        runtime: const NativeRustRuntime(),
        environment: const NativeAppEnvironment(),
        configurationSource:
            configurationSource ?? SettingsRuntimeConfiguration(),
      );
  return RustApi(
    sourceSwitchService: const RustSourceSwitchService(),
    coverSearchService: const RustCoverSearchService(),
    coverRuleRepository: const RustCoverRuleRepository(),
    exploreService: RustExploreService(
      interceptResult: PlatformBridgeService.instance.interceptResult,
    ),
    exploreStateRepository: const RustExploreStateRepository(),
    bookSourceQueryService: RustBookSourceQueryService(
      interceptResult: PlatformBridgeService.instance.interceptResult,
    ),
    bookSourceDebugService: const RustBookSourceDebugService(),
    autoTaskRepository: const RustAutoTaskRepository(),
    autoTaskService: const RustAutoTaskService(),
    bookImageRepository: const RustBookImageRepository(),
    audioCacheRepository: const RustAudioCacheRepository(),
    audioCacheDownloadService: const RustAudioCacheDownloadService(),
    audioBookService: const RustAudioBookService(),
    videoDanmakuService: const RustVideoDanmakuService(),
    localBookService: const RustLocalBookService(),
    bookArchiveService: const RustBookArchiveService(),
    bookExportService: const RustBookExportService(),
    reviewService: const RustReviewService(),
    cacheRepository: const RustCacheRepository(),
    databaseMaintenanceService: const RustDatabaseMaintenanceService(),
    appLogRepository: const RustAppLogRepository(),
    dictionaryService: const RustDictionaryService(),
    dictRuleRepository: const RustDictRuleRepository(),
    highlightRepository: const RustHighlightRepository(),
    highlightRuleRepository: const RustHighlightRuleRepository(),
    ruleSubRepository: const RustRuleSubRepository(),
    ruleSubService: const RustRuleSubService(),
    replaceRuleRepository: const RustReplaceRuleRepository(),
    replaceRuleService: const RustReplaceRuleService(),
    rssSourceRepository: const RustRssSourceRepository(),
    rssArticleRepository: const RustRssArticleRepository(),
    rssReadRecordRepository: const RustRssReadRecordRepository(),
    rssStarRepository: const RustRssStarRepository(),
    chapterCacheRepository: const RustChapterCacheRepository(),
    cacheDownloadService: const RustCacheDownloadService(),
    readingRepository: RustReadingRepository(
      interceptResult: PlatformBridgeService.instance.interceptResult,
    ),
    backupRepository: const RustBackupRepository(),
    webDavService: const RustWebDavService(),
    initialize: startup.initialize,
    readingConfigSync: startup.configurationSync,
    bookmarkRepository: const RustBookmarkRepository(),
    readRecordRepository: RustReadRecordRepository(),
    httpTtsRepository: const RustHttpTtsRepository(),
    httpTtsSynthesizer: const RustHttpTtsSynthesizer(),
    bookshelfRepository: const RustBookshelfRepository(),
    bookGroupRepository: const RustBookGroupRepository(),
    sourceChecker: const RustSourceChecker(),
    sourceLoginRepository: const RustSourceLoginRepository(),
    searchService: const RustSearchService(),
    searchHistoryRepository: const RustSearchHistoryRepository(),
    bookSourceRepository: const RustBookSourceRepository(
      onSourcesChanged: CoverDecodeLoader.invalidateSourceRegistry,
    ),
  );
}

/// 初始化成功后返回原实例，供根 ProviderScope 注入；失败原样上抛。
Future<BookApi> initializeBookApi({BookApi? api}) async {
  final instance = api ?? createBookApi();
  await instance.initialize();
  return instance;
}

/// 消费者不识别具体 RustApi；Mock 缺少此能力时保持空操作。
ReadingConfigSync readingConfigSyncFor(BookApi api) => api is ReadingConfigSync
    ? api as ReadingConfigSync
    : const NoopReadingConfigSync();

ThemeConfigSync themeConfigSyncFor(BookApi api) => api is ThemeConfigSync
    ? api as ThemeConfigSync
    : const NoopThemeConfigSync();
