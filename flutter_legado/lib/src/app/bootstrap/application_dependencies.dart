import 'mock_dependencies.dart';
import '../../data/repositories/rust_config_repository.dart';
import '../../data/bridge/rust_app_runtime.dart';
import '../../data/services/rust_reading_content_service.dart';
import '../../data/services/rust_source_action_service.dart';
import '../../data/services/rust_book_source_edit_service.dart';
import '../../data/services/rust_source_login_v2_service.dart';
import '../../data/services/rust_verification_service.dart';
import '../../data/services/rust_webview_bridge_service.dart';
import '../../data/services/rust_network_service.dart';
import '../../data/services/rust_local_server_service.dart';
import '../../data/services/rust_rule_execution_service.dart';
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
import 'rust_bootstrap.dart';
import 'settings_runtime_configuration.dart';
import '../../data/repositories/rust_cloud_tts_repository.dart';
import '../../data/repositories/rust_read_aloud_voice_repository.dart';
import '../../data/repositories/rust_tts_cache_repository.dart';
import '../../domain/contracts/app_runtime.dart';
import '../../domain/contracts/privacy_credential_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_settings_provider.dart';
import '../../features/reader/application/reader_settings_provider.dart';
import '../../data/repositories/rust_privacy_credential_repository.dart';
import '../../domain/contracts/app_log_repository.dart';
import '../../domain/contracts/webdav_service.dart';
import '../../domain/contracts/backup_repository.dart';
import '../../domain/contracts/local_book_service.dart';
import '../../domain/contracts/book_archive_service.dart';
import '../../domain/contracts/book_export_service.dart';
import '../../domain/contracts/review_service.dart';
import '../../domain/contracts/cache_repository.dart';
import '../../domain/contracts/database_maintenance_service.dart';
import '../../domain/contracts/chapter_cache_repository.dart';
import '../../domain/contracts/cache_download_service.dart';
import '../../domain/contracts/config_repository.dart';
import '../../domain/contracts/cover_search_service.dart';
import '../../domain/contracts/cover_rule_repository.dart';
import '../../domain/contracts/dictionary_service.dart';
import '../../domain/contracts/dict_rule_repository.dart';
import '../../domain/contracts/highlight_repository.dart';
import '../../domain/contracts/highlight_rule_repository.dart';
import '../../domain/contracts/local_server_service.dart';
import '../../domain/contracts/book_image_repository.dart';
import '../../domain/contracts/audio_cache_repository.dart';
import '../../domain/contracts/audio_cache_download_service.dart';
import '../../domain/contracts/audio_book_service.dart';
import '../../domain/contracts/video_danmaku_service.dart';
import '../../domain/contracts/network_service.dart';
import '../../domain/contracts/reading_content_service.dart';
import '../../domain/contracts/reading_repository.dart';
import '../../domain/contracts/replace_rule_repository.dart';
import '../../domain/contracts/replace_rule_service.dart';
import '../../domain/contracts/rss_source_repository.dart';
import '../../domain/contracts/rss_article_repository.dart';
import '../../domain/contracts/rss_read_record_repository.dart';
import '../../domain/contracts/rss_star_repository.dart';
import '../../domain/contracts/rule_execution_service.dart';
import '../../domain/contracts/rule_sub_repository.dart';
import '../../domain/contracts/rule_sub_service.dart';
import '../../domain/contracts/source_action_service.dart';
import '../../domain/contracts/book_source_edit_service.dart';
import '../../domain/contracts/source_login_v2_service.dart';
import '../../domain/contracts/verification_service.dart';
import '../../domain/contracts/webview_bridge_service.dart';
import '../../domain/contracts/auto_task_repository.dart';
import '../../domain/contracts/auto_task_service.dart';
import '../../domain/contracts/source_switch_service.dart';
import '../../domain/contracts/explore_service.dart';
import '../../domain/contracts/explore_state_repository.dart';
import '../../domain/contracts/book_source_query_service.dart';
import '../../domain/contracts/book_source_debug_service.dart';
import '../../domain/contracts/bookmark_repository.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/book_group_repository.dart';
import '../../domain/contracts/book_source_repository.dart';
import '../../domain/contracts/source_checker.dart';
import '../../domain/contracts/source_login_repository.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../domain/contracts/http_tts_repository.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../domain/contracts/tts_cache_repository.dart';
import '../../domain/contracts/read_aloud_voice_repository.dart';
import '../../domain/contracts/read_record_repository.dart';
import '../../domain/contracts/search_service.dart';
import '../../domain/contracts/search_history_repository.dart';

final mockModeProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('USE_MOCK'),
);

/// 正式应用的构造与共享实例由Provider生命周期拥有。— Codex + Bridge
final rustBootstrapProvider = Provider<RustBootstrap>(
  (ref) => RustBootstrap(
    runtime: const NativeRustRuntime(),
    environment: const NativeAppEnvironment(),
    configurationSource: SettingsRuntimeConfiguration(
      appSettings: ref.watch(appSettingsServiceProvider),
      readingSession: ref.watch(readerThemeSessionProvider),
    ),
  ),
);
final appRuntimeProvider = Provider<AppRuntime>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAppRuntimeProvider)
      : RustAppRuntime(startup: ref.watch(rustBootstrapProvider).initialize),
);
final readingConfigSyncProvider = Provider<ReadingConfigSync>(
  (ref) => ref.watch(mockModeProvider)
      ? const NoopReadingConfigSync()
      : ref.watch(rustBootstrapProvider).configurationSync,
);
final privacyCredentialProvider = Provider<PrivacyCredentialRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockPrivacyCredentialProvider)
      : const RustPrivacyCredentialRepository(),
);
final appLogRepositoryProvider = Provider<AppLogRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAppLogRepositoryProvider)
      : const RustAppLogRepository(),
);
final webDavServiceProvider = Provider<WebDavService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockWebDavServiceProvider)
      : const RustWebDavService(),
);
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBackupRepositoryProvider)
      : const RustBackupRepository(),
);
final localBookServiceProvider = Provider<LocalBookService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockLocalBookServiceProvider)
      : const RustLocalBookService(),
);
final bookArchiveServiceProvider = Provider<BookArchiveService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookArchiveServiceProvider)
      : const RustBookArchiveService(),
);
final bookExportServiceProvider = Provider<BookExportService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookExportServiceProvider)
      : const RustBookExportService(),
);
final reviewServiceProvider = Provider<ReviewService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReviewServiceProvider)
      : const RustReviewService(),
);
final cacheRepositoryProvider = Provider<CacheRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockCacheRepositoryProvider)
      : const RustCacheRepository(),
);
final databaseMaintenanceServiceProvider = Provider<DatabaseMaintenanceService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockDatabaseMaintenanceServiceProvider)
      : const RustDatabaseMaintenanceService(),
);
final chapterCacheRepositoryProvider = Provider<ChapterCacheRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockChapterCacheRepositoryProvider)
      : const RustChapterCacheRepository(),
);
final cacheDownloadServiceProvider = Provider<CacheDownloadService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockCacheDownloadServiceProvider)
      : const RustCacheDownloadService(),
);
final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockConfigRepositoryProvider)
      : const RustConfigRepository(),
);
final coverSearchServiceProvider = Provider<CoverSearchService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockCoverSearchServiceProvider)
      : const RustCoverSearchService(),
);
final coverRuleRepositoryProvider = Provider<CoverRuleRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockCoverRuleRepositoryProvider)
      : const RustCoverRuleRepository(),
);
final dictionaryServiceProvider = Provider<DictionaryService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockDictionaryServiceProvider)
      : const RustDictionaryService(),
);
final dictRuleRepositoryProvider = Provider<DictRuleRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockDictRuleRepositoryProvider)
      : const RustDictRuleRepository(),
);
final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockHighlightRepositoryProvider)
      : const RustHighlightRepository(),
);
final highlightRuleRepositoryProvider = Provider<HighlightRuleRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockHighlightRuleRepositoryProvider)
      : const RustHighlightRuleRepository(),
);
final localServerServiceProvider = Provider<LocalServerService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockLocalServerServiceProvider)
      : const RustLocalServerService(),
);
final bookImageRepositoryProvider = Provider<BookImageRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookImageRepositoryProvider)
      : const RustBookImageRepository(),
);
final audioCacheRepositoryProvider = Provider<AudioCacheRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAudioCacheRepositoryProvider)
      : const RustAudioCacheRepository(),
);
final audioCacheDownloadServiceProvider = Provider<AudioCacheDownloadService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAudioCacheDownloadServiceProvider)
      : const RustAudioCacheDownloadService(),
);
final audioBookServiceProvider = Provider<AudioBookService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAudioBookServiceProvider)
      : const RustAudioBookService(),
);
final videoDanmakuServiceProvider = Provider<VideoDanmakuService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockVideoDanmakuServiceProvider)
      : const RustVideoDanmakuService(),
);
final networkServiceProvider = Provider<NetworkService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockNetworkServiceProvider)
      : const RustNetworkService(),
);
final readingContentServiceProvider = Provider<ReadingContentService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReadingContentServiceProvider)
      : const RustReadingContentService(),
);
final readingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReadingRepositoryProvider)
      : RustReadingRepository(
          dispatchAction: PlatformBridgeService.instance.interceptPayload,
        ),
);
final replaceRuleRepositoryProvider = Provider<ReplaceRuleRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReplaceRuleRepositoryProvider)
      : const RustReplaceRuleRepository(),
);
final replaceRuleServiceProvider = Provider<ReplaceRuleService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReplaceRuleServiceProvider)
      : const RustReplaceRuleService(),
);
final rssSourceRepositoryProvider = Provider<RssSourceRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRssSourceRepositoryProvider)
      : const RustRssSourceRepository(),
);
final rssArticleRepositoryProvider = Provider<RssArticleRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRssArticleRepositoryProvider)
      : const RustRssArticleRepository(),
);
final rssReadRecordRepositoryProvider = Provider<RssReadRecordRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRssReadRecordRepositoryProvider)
      : const RustRssReadRecordRepository(),
);
final rssStarRepositoryProvider = Provider<RssStarRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRssStarRepositoryProvider)
      : const RustRssStarRepository(),
);
final ruleExecutionServiceProvider = Provider<RuleExecutionService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRuleExecutionServiceProvider)
      : RustRuleExecutionService(
          interceptResult: PlatformBridgeService.instance.interceptResult,
        ),
);
final ruleSubRepositoryProvider = Provider<RuleSubRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRuleSubRepositoryProvider)
      : const RustRuleSubRepository(),
);
final ruleSubServiceProvider = Provider<RuleSubService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockRuleSubServiceProvider)
      : const RustRuleSubService(),
);
final sourceActionServiceProvider = Provider<SourceActionService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSourceActionServiceProvider)
      : RustSourceActionService(
          dispatchActions: PlatformBridgeService.instance.dispatchActions,
        ),
);
final bookSourceEditServiceProvider = Provider<BookSourceEditService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookSourceEditServiceProvider)
      : const RustBookSourceEditService(),
);
final sourceLoginV2ServiceProvider = Provider<SourceLoginV2Service>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSourceLoginV2ServiceProvider)
      : RustSourceLoginV2Service(
          interceptResult: PlatformBridgeService.instance.interceptResult,
        ),
);
final verificationServiceProvider = Provider<VerificationService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockVerificationServiceProvider)
      : const RustVerificationService(),
);
final webViewBridgeServiceProvider = Provider<WebViewBridgeService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockWebViewBridgeServiceProvider)
      : const RustWebViewBridgeService(),
);
final autoTaskRepositoryProvider = Provider<AutoTaskRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAutoTaskRepositoryProvider)
      : const RustAutoTaskRepository(),
);
final autoTaskServiceProvider = Provider<AutoTaskService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockAutoTaskServiceProvider)
      : const RustAutoTaskService(),
);
final sourceSwitchServiceProvider = Provider<SourceSwitchService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSourceSwitchServiceProvider)
      : const RustSourceSwitchService(),
);
final exploreServiceProvider = Provider<ExploreService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockExploreServiceProvider)
      : RustExploreService(
          interceptResult: PlatformBridgeService.instance.interceptResult,
        ),
);
final exploreStateRepositoryProvider = Provider<ExploreStateRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockExploreStateRepositoryProvider)
      : const RustExploreStateRepository(),
);
final bookSourceQueryServiceProvider = Provider<BookSourceQueryService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookSourceQueryServiceProvider)
      : RustBookSourceQueryService(
          interceptResult: PlatformBridgeService.instance.interceptResult,
        ),
);
final bookSourceDebugServiceProvider = Provider<BookSourceDebugService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookSourceDebugServiceProvider)
      : const RustBookSourceDebugService(),
);
final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookmarkRepositoryProvider)
      : const RustBookmarkRepository(),
);
final bookshelfRepositoryProvider = Provider<BookshelfRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookshelfRepositoryProvider)
      : const RustBookshelfRepository(),
);
final bookGroupRepositoryProvider = Provider<BookGroupRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookGroupRepositoryProvider)
      : const RustBookGroupRepository(),
);
final bookSourceRepositoryProvider = Provider<BookSourceRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockBookSourceRepositoryProvider)
      : const RustBookSourceRepository(
          onSourcesChanged: CoverDecodeLoader.invalidateSourceRegistry,
        ),
);
final sourceCheckerProvider = Provider<SourceChecker>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSourceCheckerProvider)
      : const RustSourceChecker(),
);
final sourceLoginRepositoryProvider = Provider<SourceLoginRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSourceLoginRepositoryProvider)
      : const RustSourceLoginRepository(),
);
final cloudTtsRepositoryProvider = Provider<CloudTtsRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockCloudTtsRepositoryProvider)
      : const RustCloudTtsRepository(),
);
final httpTtsRepositoryProvider = Provider<HttpTtsRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockHttpTtsRepositoryProvider)
      : const RustHttpTtsRepository(),
);
final httpTtsSynthesizerProvider = Provider<HttpTtsSynthesizer>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockHttpTtsSynthesizerProvider)
      : const RustHttpTtsSynthesizer(),
);
final ttsCacheRepositoryProvider = Provider<TtsCacheRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockTtsCacheRepositoryProvider)
      : const RustTtsCacheRepository(),
);
final readAloudVoiceRepositoryProvider = Provider<ReadAloudVoiceRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReadAloudVoiceRepositoryProvider)
      : const RustReadAloudVoiceRepository(),
);
final readRecordRepositoryProvider = Provider<ReadRecordRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockReadRecordRepositoryProvider)
      : RustReadRecordRepository(),
);
final searchServiceProvider = Provider<SearchService>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSearchServiceProvider)
      : const RustSearchService(),
);
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => ref.watch(mockModeProvider)
      ? ref.watch(mockSearchHistoryRepositoryProvider)
      : const RustSearchHistoryRepository(),
);
