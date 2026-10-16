import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
export 'package:flutter_legado/src/data/bridge/rust_api_exception.dart';

export 'app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_legado/src/app/bootstrap/application_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/rust_bootstrap.dart';
import 'package:flutter_legado/src/app/bootstrap/settings_runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/platform/app_environment.dart';

import 'app_test_api.dart';

import 'package:flutter_legado/src/domain/contracts/app_log_repository.dart';
import 'package:flutter_legado/src/domain/contracts/webdav_service.dart';
import 'package:flutter_legado/src/domain/contracts/backup_repository.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_archive_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_export_service.dart';
import 'package:flutter_legado/src/domain/contracts/review_service.dart';
import 'package:flutter_legado/src/domain/contracts/cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/database_maintenance_service.dart';
import 'package:flutter_legado/src/domain/contracts/chapter_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/config_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cover_search_service.dart';
import 'package:flutter_legado/src/domain/contracts/cover_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/dictionary_service.dart';
import 'package:flutter_legado/src/domain/contracts/dict_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/highlight_repository.dart';
import 'package:flutter_legado/src/domain/contracts/highlight_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/local_server_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/audio_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/video_danmaku_service.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/domain/contracts/reading_content_service.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_service.dart';
import 'package:flutter_legado/src/domain/contracts/rss_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_article_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_star_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rule_execution_service.dart';
import 'package:flutter_legado/src/domain/contracts/rule_sub_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rule_sub_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_action_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_edit_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_v2_service.dart';
import 'package:flutter_legado/src/domain/contracts/verification_service.dart';
import 'package:flutter_legado/src/domain/contracts/webview_bridge_service.dart';
import 'package:flutter_legado/src/domain/contracts/auto_task_repository.dart';
import 'package:flutter_legado/src/domain/contracts/auto_task_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_switch_service.dart';
import 'package:flutter_legado/src/domain/contracts/explore_service.dart';
import 'package:flutter_legado/src/domain/contracts/explore_state_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_query_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_debug_service.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_checker.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/search_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_history_repository.dart';
import 'package:flutter_legado/src/domain/contracts/app_runtime.dart';

/// 真实能力的测试视图，所有实例仍由实际Provider容器拥有。
class NativeTestApi implements TestApi, ReadingConfigSync, ThemeConfigSync {
  NativeTestApi(this.container);
  final ProviderContainer container;
  @override
  AppLogRepository get appLogRepository =>
      container.read(appLogRepositoryProvider);
  @override
  WebDavService get webDavService => container.read(webDavServiceProvider);
  @override
  BackupRepository get backupRepository =>
      container.read(backupRepositoryProvider);
  @override
  LocalBookService get localBookService =>
      container.read(localBookServiceProvider);
  @override
  BookArchiveService get bookArchiveService =>
      container.read(bookArchiveServiceProvider);
  @override
  BookExportService get bookExportService =>
      container.read(bookExportServiceProvider);
  @override
  ReviewService get reviewService => container.read(reviewServiceProvider);
  @override
  CacheRepository get cacheRepository =>
      container.read(cacheRepositoryProvider);
  @override
  DatabaseMaintenanceService get databaseMaintenanceService =>
      container.read(databaseMaintenanceServiceProvider);
  @override
  ChapterCacheRepository get chapterCacheRepository =>
      container.read(chapterCacheRepositoryProvider);
  @override
  CacheDownloadService get cacheDownloadService =>
      container.read(cacheDownloadServiceProvider);
  @override
  ConfigRepository get configRepository =>
      container.read(configRepositoryProvider);
  @override
  CoverSearchService get coverSearchService =>
      container.read(coverSearchServiceProvider);
  @override
  CoverRuleRepository get coverRuleRepository =>
      container.read(coverRuleRepositoryProvider);
  @override
  DictionaryService get dictionaryService =>
      container.read(dictionaryServiceProvider);
  @override
  DictRuleRepository get dictRuleRepository =>
      container.read(dictRuleRepositoryProvider);
  @override
  HighlightRepository get highlightRepository =>
      container.read(highlightRepositoryProvider);
  @override
  HighlightRuleRepository get highlightRuleRepository =>
      container.read(highlightRuleRepositoryProvider);
  @override
  LocalServerService get localServerService =>
      container.read(localServerServiceProvider);
  @override
  BookImageRepository get bookImageRepository =>
      container.read(bookImageRepositoryProvider);
  @override
  AudioCacheRepository get audioCacheRepository =>
      container.read(audioCacheRepositoryProvider);
  @override
  AudioCacheDownloadService get audioCacheDownloadService =>
      container.read(audioCacheDownloadServiceProvider);
  @override
  AudioBookService get audioBookService =>
      container.read(audioBookServiceProvider);
  @override
  VideoDanmakuService get videoDanmakuService =>
      container.read(videoDanmakuServiceProvider);
  @override
  NetworkService get networkService => container.read(networkServiceProvider);
  @override
  ReadingContentService get readingContentService =>
      container.read(readingContentServiceProvider);
  @override
  ReadingRepository get readingRepository =>
      container.read(readingRepositoryProvider);
  @override
  ReplaceRuleRepository get replaceRuleRepository =>
      container.read(replaceRuleRepositoryProvider);
  @override
  ReplaceRuleService get replaceRuleService =>
      container.read(replaceRuleServiceProvider);
  @override
  RssSourceRepository get rssSourceRepository =>
      container.read(rssSourceRepositoryProvider);
  @override
  RssArticleRepository get rssArticleRepository =>
      container.read(rssArticleRepositoryProvider);
  @override
  RssReadRecordRepository get rssReadRecordRepository =>
      container.read(rssReadRecordRepositoryProvider);
  @override
  RssStarRepository get rssStarRepository =>
      container.read(rssStarRepositoryProvider);
  @override
  RuleExecutionService get ruleExecutionService =>
      container.read(ruleExecutionServiceProvider);
  @override
  RuleSubRepository get ruleSubRepository =>
      container.read(ruleSubRepositoryProvider);
  @override
  RuleSubService get ruleSubService => container.read(ruleSubServiceProvider);
  @override
  SourceActionService get sourceActionService =>
      container.read(sourceActionServiceProvider);
  @override
  BookSourceEditService get bookSourceEditService =>
      container.read(bookSourceEditServiceProvider);
  @override
  SourceLoginV2Service get sourceLoginV2Service =>
      container.read(sourceLoginV2ServiceProvider);
  @override
  VerificationService get verificationService =>
      container.read(verificationServiceProvider);
  @override
  WebViewBridgeService get webViewBridgeService =>
      container.read(webViewBridgeServiceProvider);
  @override
  AutoTaskRepository get autoTaskRepository =>
      container.read(autoTaskRepositoryProvider);
  @override
  AutoTaskService get autoTaskService =>
      container.read(autoTaskServiceProvider);
  @override
  SourceSwitchService get sourceSwitchService =>
      container.read(sourceSwitchServiceProvider);
  @override
  ExploreService get exploreService => container.read(exploreServiceProvider);
  @override
  ExploreStateRepository get exploreStateRepository =>
      container.read(exploreStateRepositoryProvider);
  @override
  BookSourceQueryService get bookSourceQueryService =>
      container.read(bookSourceQueryServiceProvider);
  @override
  BookSourceDebugService get bookSourceDebugService =>
      container.read(bookSourceDebugServiceProvider);
  @override
  BookmarkRepository get bookmarkRepository =>
      container.read(bookmarkRepositoryProvider);
  @override
  BookshelfRepository get bookshelfRepository =>
      container.read(bookshelfRepositoryProvider);
  @override
  BookGroupRepository get bookGroupRepository =>
      container.read(bookGroupRepositoryProvider);
  @override
  BookSourceRepository get bookSourceRepository =>
      container.read(bookSourceRepositoryProvider);
  @override
  SourceChecker get sourceChecker => container.read(sourceCheckerProvider);
  @override
  SourceLoginRepository get sourceLoginRepository =>
      container.read(sourceLoginRepositoryProvider);
  @override
  CloudTtsRepository get cloudTtsRepository =>
      container.read(cloudTtsRepositoryProvider);
  @override
  HttpTtsRepository get httpTtsRepository =>
      container.read(httpTtsRepositoryProvider);
  @override
  HttpTtsSynthesizer get httpTtsSynthesizer =>
      container.read(httpTtsSynthesizerProvider);
  @override
  TtsCacheRepository get ttsCacheRepository =>
      container.read(ttsCacheRepositoryProvider);
  @override
  ReadAloudVoiceRepository get readAloudVoiceRepository =>
      container.read(readAloudVoiceRepositoryProvider);
  @override
  ReadRecordRepository get readRecordRepository =>
      container.read(readRecordRepositoryProvider);
  @override
  SearchService get searchService => container.read(searchServiceProvider);
  @override
  SearchHistoryRepository get searchHistoryRepository =>
      container.read(searchHistoryRepositoryProvider);
  @override
  AppRuntime get runtime => container.read(appRuntimeProvider);
  @override
  Future<void> refreshReadBookConfig() =>
      container.read(readingConfigSyncProvider).refreshReadBookConfig();
  @override
  Future<void> synchronizeThemeConfig() => container
      .read(rustBootstrapProvider)
      .configurationSync
      .synchronizeThemeConfig();
}

TestApi createTestApplication({
  bool useMock = const bool.fromEnvironment('USE_MOCK'),
  RustBootstrap? bootstrap,
  RuntimeConfigurationSource? configurationSource,
}) {
  if (useMock) return MockBookApi();
  return NativeTestApi(
    createApplicationContainer(
      bootstrap:
          bootstrap ??
          RustBootstrap(
            runtime: const NativeRustRuntime(),
            environment: const NativeAppEnvironment(),
            configurationSource:
                configurationSource ?? SettingsRuntimeConfiguration(),
          ),
    ),
  );
}

Future<TestApi> initializeTestApplication({TestApi? api}) async {
  final instance = api ?? createTestApplication();
  await instance.runtime.initialize();
  return instance;
}

ReadingConfigSync readingConfigSyncFor(TestApi api) => api is ReadingConfigSync
    ? api as ReadingConfigSync
    : const NoopReadingConfigSync();
ThemeConfigSync themeConfigSyncFor(TestApi api) => api is ThemeConfigSync
    ? api as ThemeConfigSync
    : const NoopThemeConfigSync();
