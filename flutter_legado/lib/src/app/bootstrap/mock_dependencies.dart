import '../../domain/contracts/privacy_credential_repository.dart';
import '../../domain/contracts/config_repository.dart';
import '../../domain/contracts/app_runtime.dart';
import '../../data/repositories/mock_config_repository.dart';
import '../../data/bridge/mock_app_runtime.dart';
import '../../domain/contracts/reading_content_service.dart';
import '../../domain/contracts/source_action_service.dart';
import '../../data/services/mock_reading_content_service.dart';
import '../../data/services/mock_source_action_service.dart';
import '../../domain/contracts/book_source_edit_service.dart';
import '../../domain/contracts/source_login_v2_service.dart';
import '../../domain/contracts/verification_service.dart';
import '../../domain/contracts/webview_bridge_service.dart';
import '../../data/services/mock_book_source_edit_service.dart';
import '../../data/services/mock_source_login_v2_service.dart';
import '../../data/services/mock_verification_service.dart';
import '../../data/services/mock_webview_bridge_service.dart';
import '../../domain/contracts/network_service.dart';
import '../../domain/contracts/local_server_service.dart';
import '../../domain/contracts/rule_execution_service.dart';
import '../../data/services/mock_network_service.dart';
import '../../data/services/mock_local_server_service.dart';
import '../../data/services/mock_rule_execution_service.dart';
import '../../domain/contracts/cover_rule_repository.dart';
import '../../data/repositories/mock_cover_rule_repository.dart';
import '../../domain/contracts/source_switch_service.dart';
import '../../domain/contracts/cover_search_service.dart';
import '../../data/services/mock_source_switch_service.dart';
import '../../data/services/mock_cover_search_service.dart';
import '../../domain/contracts/explore_service.dart';
import '../../domain/contracts/explore_state_repository.dart';
import '../../domain/contracts/book_source_query_service.dart';
import '../../domain/contracts/book_source_debug_service.dart';
import '../../data/services/mock_explore_service.dart';
import '../../data/repositories/mock_explore_state_repository.dart';
import '../../data/services/mock_book_source_query_service.dart';
import '../../data/services/mock_book_source_debug_service.dart';
import '../../data/repositories/mock_auto_task_repository.dart';
import '../../data/services/mock_auto_task_service.dart';
import '../../domain/contracts/auto_task_repository.dart';
import '../../domain/contracts/auto_task_service.dart';
import '../../data/repositories/mock_book_image_repository.dart';
import '../../data/repositories/mock_audio_cache_repository.dart';
import '../../data/services/mock_audio_cache_download_service.dart';
import '../../data/services/mock_audio_book_service.dart';
import '../../data/services/mock_video_danmaku_service.dart';
import '../../domain/contracts/book_image_repository.dart';
import '../../domain/contracts/audio_cache_repository.dart';
import '../../domain/contracts/audio_cache_download_service.dart';
import '../../domain/contracts/audio_book_service.dart';
import '../../domain/contracts/video_danmaku_service.dart';
import '../../data/services/mock_local_book_service.dart';
import '../../data/services/mock_book_archive_service.dart';
import '../../data/services/mock_book_export_service.dart';
import '../../data/services/mock_review_service.dart';
import '../../domain/contracts/local_book_service.dart';
import '../../domain/contracts/book_archive_service.dart';
import '../../domain/contracts/book_export_service.dart';
import '../../domain/contracts/review_service.dart';
import '../../data/repositories/mock_cache_repository.dart';
import '../../data/services/mock_database_maintenance_service.dart';
import '../../domain/contracts/cache_repository.dart';
import '../../domain/contracts/database_maintenance_service.dart';
import '../../domain/contracts/app_log_repository.dart';
import '../../data/repositories/mock_app_log_repository.dart';
import '../../domain/contracts/dictionary_service.dart';
import '../../domain/contracts/dict_rule_repository.dart';
import '../../data/services/mock_dictionary_service.dart';
import '../../data/repositories/mock_dict_rule_repository.dart';
import '../../domain/contracts/highlight_repository.dart';
import '../../domain/contracts/highlight_rule_repository.dart';
import '../../data/repositories/mock_highlight_repository.dart';
import '../../data/repositories/mock_highlight_rule_repository.dart';
import '../../data/repositories/mock_rule_sub_repository.dart';
import '../../data/services/mock_rule_sub_service.dart';
import '../../domain/contracts/rule_sub_repository.dart';
import '../../domain/contracts/rule_sub_service.dart';
import '../../data/repositories/mock_replace_rule_repository.dart';
import '../../data/services/mock_replace_rule_service.dart';
import '../../domain/contracts/replace_rule_repository.dart';
import '../../domain/contracts/replace_rule_service.dart';
import '../../data/repositories/mock_rss_star_repository.dart';
import '../../data/repositories/mock_rss_read_record_repository.dart';
import '../../data/repositories/mock_rss_article_repository.dart';
import '../../data/repositories/mock_rss_source_repository.dart';
import '../../domain/contracts/rss_source_repository.dart';
import '../../domain/contracts/rss_article_repository.dart';
import '../../domain/contracts/rss_read_record_repository.dart';
import '../../domain/contracts/rss_star_repository.dart';
import '../../domain/contracts/chapter_cache_repository.dart';
import '../../domain/contracts/cache_download_service.dart';
import '../../data/repositories/mock_chapter_cache_repository.dart';
import '../../data/services/mock_cache_download_service.dart';
import '../../domain/contracts/reading_repository.dart';
import '../../data/repositories/mock_reading_repository.dart';
import '../../domain/contracts/backup_repository.dart';
import '../../domain/contracts/webdav_service.dart';
import '../../data/repositories/mock_backup_repository.dart';
import '../../data/services/mock_webdav_service.dart';
import '../../domain/contracts/search_service.dart';
import '../../domain/contracts/search_history_repository.dart';
import '../../data/services/mock_search_service.dart';
import '../../data/repositories/mock_search_history_repository.dart';
import '../../domain/contracts/source_login_repository.dart';
import '../../data/repositories/mock_source_login_repository.dart';
import '../../data/repositories/mock_cloud_tts_repository.dart';
import '../../domain/contracts/cloud_tts_repository.dart';
import '../../data/repositories/mock_read_aloud_voice_repository.dart';
import '../../data/repositories/mock_tts_cache_repository.dart';
import '../../domain/contracts/tts_cache_repository.dart';
import '../../data/services/mock_source_checker.dart';
import '../../domain/contracts/source_checker.dart';
import '../../data/repositories/mock_book_source_repository.dart';
import '../../domain/contracts/book_source_repository.dart';
import '../../data/repositories/mock_bookshelf_repository.dart';
import '../../data/repositories/mock_book_group_repository.dart';
import '../../domain/contracts/bookshelf_repository.dart';
import '../../domain/contracts/book_group_repository.dart';
import '../../data/services/mock_http_tts_synthesizer.dart';
import '../../data/repositories/mock_bookmark_repository.dart';
import '../../data/repositories/mock_read_record_repository.dart';
import '../../data/repositories/mock_http_tts_repository.dart';
import '../../domain/contracts/bookmark_repository.dart';
import '../../domain/contracts/read_record_repository.dart';
import '../../domain/contracts/http_tts_repository.dart';
import '../../domain/contracts/http_tts_synthesizer.dart';
import '../../data/bridge/mock_app_data.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_privacy_credential_repository.dart';

/// Mock能力按需创建，跨领域状态由同一容器中的数据对象共享。— Codex + Bridge
final mockAppDataProvider = Provider<MockAppData>((ref) => MockAppData());
final mockAudioCacheStoreProvider = Provider<MockAudioCacheStore>(
  (ref) => MockAudioCacheStore(),
);
final mockAppRuntimeProvider = Provider<AppRuntime>(
  (ref) => MockAppRuntime(startup: ref.watch(mockAppDataProvider).initialize),
);
final mockPrivacyCredentialProvider = Provider<PrivacyCredentialRepository>(
  (ref) => MockPrivacyCredentialRepository(),
);
final mockAppLogRepositoryProvider = Provider<AppLogRepository>((ref) {
  return MockAppLogRepository();
});
final mockWebDavServiceProvider = Provider<WebDavService>((ref) {
  return const MockWebDavService();
});
final mockBackupRepositoryProvider = Provider<BackupRepository>((ref) {
  return const MockBackupRepository();
});
final mockLocalBookServiceProvider = Provider<LocalBookService>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockLocalBookService(store: data.bookshelf);
});
final mockBookArchiveServiceProvider = Provider<BookArchiveService>((ref) {
  return const MockBookArchiveService();
});
final mockBookExportServiceProvider = Provider<BookExportService>((ref) {
  return MockBookExportService(
    bookshelf: ref.watch(mockBookshelfRepositoryProvider),
    reading: ref.watch(mockReadingRepositoryProvider),
  );
});
final mockReviewServiceProvider = Provider<ReviewService>((ref) {
  return const MockReviewService();
});
final mockCacheRepositoryProvider = Provider<CacheRepository>((ref) {
  return const MockCacheRepository();
});
final mockDatabaseMaintenanceServiceProvider =
    Provider<DatabaseMaintenanceService>((ref) {
      return const MockDatabaseMaintenanceService();
    });
final mockChapterCacheRepositoryProvider = Provider<ChapterCacheRepository>((
  ref,
) {
  return const MockChapterCacheRepository();
});
final mockCacheDownloadServiceProvider = Provider<CacheDownloadService>((ref) {
  return const MockCacheDownloadService();
});
final mockConfigRepositoryProvider = Provider<ConfigRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockConfigRepository(values: data.configs);
});
final mockCoverSearchServiceProvider = Provider<CoverSearchService>((ref) {
  return const MockCoverSearchService();
});
final mockCoverRuleRepositoryProvider = Provider<CoverRuleRepository>((ref) {
  return MockCoverRuleRepository();
});
final mockDictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return const MockDictionaryService();
});
final mockDictRuleRepositoryProvider = Provider<DictRuleRepository>((ref) {
  return MockDictRuleRepository();
});
final mockHighlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return MockHighlightRepository();
});
final mockHighlightRuleRepositoryProvider = Provider<HighlightRuleRepository>((
  ref,
) {
  final data = ref.watch(mockAppDataProvider);
  return MockHighlightRuleRepository(nextId: data.allocateId);
});
final mockLocalServerServiceProvider = Provider<LocalServerService>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockLocalServerService(configs: data.configs);
});
final mockBookImageRepositoryProvider = Provider<BookImageRepository>((ref) {
  return MockBookImageRepository();
});
final mockAudioCacheRepositoryProvider = Provider<AudioCacheRepository>((ref) {
  return MockAudioCacheRepository(
    store: ref.watch(mockAudioCacheStoreProvider),
  );
});
final mockAudioCacheDownloadServiceProvider =
    Provider<AudioCacheDownloadService>((ref) {
      return MockAudioCacheDownloadService(
        store: ref.watch(mockAudioCacheStoreProvider),
      );
    });
final mockAudioBookServiceProvider = Provider<AudioBookService>((ref) {
  return MockAudioBookService(
    reading: ref.watch(mockReadingRepositoryProvider),
  );
});
final mockVideoDanmakuServiceProvider = Provider<VideoDanmakuService>((ref) {
  return const MockVideoDanmakuService();
});
final mockNetworkServiceProvider = Provider<NetworkService>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockNetworkService(configs: data.configs);
});
final mockReadingContentServiceProvider = Provider<ReadingContentService>((
  ref,
) {
  final data = ref.watch(mockAppDataProvider);
  return MockReadingContentService(configs: data.configs);
});
final mockReadingRepositoryProvider = Provider<ReadingRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockReadingRepository(
    books: data.bookshelf,
    chapters: data.chapters,
    contents: data.contents,
  );
});
final mockReplaceRuleRepositoryProvider = Provider<ReplaceRuleRepository>((
  ref,
) {
  final data = ref.watch(mockAppDataProvider);
  return MockReplaceRuleRepository(nextId: data.allocateId);
});
final mockReplaceRuleServiceProvider = Provider<ReplaceRuleService>((ref) {
  return const MockReplaceRuleService();
});
final mockRssSourceRepositoryProvider = Provider<RssSourceRepository>((ref) {
  return MockRssSourceRepository(withDefaultSources: true);
});
final mockRssArticleRepositoryProvider = Provider<RssArticleRepository>((ref) {
  return const MockRssArticleRepository();
});
final mockRssReadRecordRepositoryProvider = Provider<RssReadRecordRepository>((
  ref,
) {
  return MockRssReadRecordRepository();
});
final mockRssStarRepositoryProvider = Provider<RssStarRepository>((ref) {
  return MockRssStarRepository();
});
final mockRuleExecutionServiceProvider = Provider<RuleExecutionService>((ref) {
  return const MockRuleExecutionService();
});
final mockRuleSubRepositoryProvider = Provider<RuleSubRepository>((ref) {
  return MockRuleSubRepository();
});
final mockRuleSubServiceProvider = Provider<RuleSubService>((ref) {
  return MockRuleSubService(
    repository: ref.watch(mockRuleSubRepositoryProvider),
  );
});
final mockSourceActionServiceProvider = Provider<SourceActionService>((ref) {
  return const MockSourceActionService();
});
final mockBookSourceEditServiceProvider = Provider<BookSourceEditService>((
  ref,
) {
  return const MockBookSourceEditService();
});
final mockSourceLoginV2ServiceProvider = Provider<SourceLoginV2Service>((ref) {
  return const MockSourceLoginV2Service();
});
final mockVerificationServiceProvider = Provider<VerificationService>((ref) {
  return const MockVerificationService();
});
final mockWebViewBridgeServiceProvider = Provider<WebViewBridgeService>((ref) {
  return const MockWebViewBridgeService();
});
final mockAutoTaskRepositoryProvider = Provider<AutoTaskRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockAutoTaskRepository(
    allocateId: () => 'mock-task-${data.allocateId()}',
  );
});
final mockAutoTaskServiceProvider = Provider<AutoTaskService>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockAutoTaskService(
    allocateId: () => 'mock-task-${data.allocateId()}',
  );
});
final mockSourceSwitchServiceProvider = Provider<SourceSwitchService>((ref) {
  return MockSourceSwitchService(
    bookshelf: ref.watch(mockBookshelfRepositoryProvider),
    sources: ref.watch(mockBookSourceRepositoryProvider),
  );
});
final mockExploreServiceProvider = Provider<ExploreService>((ref) {
  return const MockExploreService();
});
final mockExploreStateRepositoryProvider = Provider<ExploreStateRepository>((
  ref,
) {
  return MockExploreStateRepository();
});
final mockBookSourceQueryServiceProvider = Provider<BookSourceQueryService>((
  ref,
) {
  return const MockBookSourceQueryService();
});
final mockBookSourceDebugServiceProvider = Provider<BookSourceDebugService>((
  ref,
) {
  return const MockBookSourceDebugService();
});
final mockBookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockBookmarkRepository(nextId: data.allocateId);
});
final mockBookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockBookshelfRepository(store: data.bookshelf);
});
final mockBookGroupRepositoryProvider = Provider<BookGroupRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockBookGroupRepository(
    nextId: data.allocateId,
    withDefaultGroups: true,
  );
});
final mockBookSourceRepositoryProvider = Provider<BookSourceRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockBookSourceRepository(
    store: data.sources,
    writeConfig: (key, value) => data.configs[key] = value,
  );
});
final mockSourceCheckerProvider = Provider<SourceChecker>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockSourceChecker(store: data.sources);
});
final mockSourceLoginRepositoryProvider = Provider<SourceLoginRepository>((
  ref,
) {
  return MockSourceLoginRepository();
});
final mockCloudTtsRepositoryProvider = Provider<CloudTtsRepository>((ref) {
  return MockCloudTtsRepository(
    onDelete: ref.watch(mockReadAloudVoiceRepositoryProvider).clearCloud,
  );
});
final mockHttpTtsRepositoryProvider = Provider<HttpTtsRepository>((ref) {
  final data = ref.watch(mockAppDataProvider);
  return MockHttpTtsRepository(
    nextId: data.allocateId,
    voiceCatalog: ref.watch(mockReadAloudVoiceRepositoryProvider),
    withDefaultEngines: true,
  );
});
final mockHttpTtsSynthesizerProvider = Provider<HttpTtsSynthesizer>((ref) {
  return const MockHttpTtsSynthesizer();
});
final mockTtsCacheRepositoryProvider = Provider<TtsCacheRepository>((ref) {
  return const MockTtsCacheRepository();
});
final mockReadAloudVoiceRepositoryProvider =
    Provider<MockReadAloudVoiceRepository>((ref) {
      return MockReadAloudVoiceRepository();
    });
final mockReadRecordRepositoryProvider = Provider<ReadRecordRepository>((ref) {
  return MockReadRecordRepository();
});
final mockSearchServiceProvider = Provider<SearchService>((ref) {
  return const MockSearchService();
});
final mockSearchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return MockSearchHistoryRepository();
});
