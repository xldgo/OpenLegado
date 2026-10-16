import 'package:flutter_legado/src/domain/contracts/config_repository.dart';
import 'package:flutter_legado/src/domain/contracts/app_runtime.dart';
import 'package:flutter_legado/src/data/repositories/mock_config_repository.dart';
import 'package:flutter_legado/src/data/bridge/mock_app_runtime.dart';
import 'package:flutter_legado/src/domain/contracts/reading_content_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_action_service.dart';
import 'package:flutter_legado/src/data/services/mock_reading_content_service.dart';
import 'package:flutter_legado/src/data/services/mock_source_action_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_edit_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_v2_service.dart';
import 'package:flutter_legado/src/domain/contracts/verification_service.dart';
import 'package:flutter_legado/src/domain/contracts/webview_bridge_service.dart';
import 'package:flutter_legado/src/data/services/mock_book_source_edit_service.dart';
import 'package:flutter_legado/src/data/services/mock_source_login_v2_service.dart';
import 'package:flutter_legado/src/data/services/mock_verification_service.dart';
import 'package:flutter_legado/src/data/services/mock_webview_bridge_service.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/domain/contracts/local_server_service.dart';
import 'package:flutter_legado/src/domain/contracts/rule_execution_service.dart';
import 'package:flutter_legado/src/data/services/mock_network_service.dart';
import 'package:flutter_legado/src/data/services/mock_local_server_service.dart';
import 'package:flutter_legado/src/data/services/mock_rule_execution_service.dart';
import 'package:flutter_legado/src/domain/contracts/cover_rule_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_cover_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_switch_service.dart';
import 'package:flutter_legado/src/domain/contracts/cover_search_service.dart';
import 'package:flutter_legado/src/data/services/mock_source_switch_service.dart';
import 'package:flutter_legado/src/data/services/mock_cover_search_service.dart';
import 'package:flutter_legado/src/domain/contracts/explore_service.dart';
import 'package:flutter_legado/src/domain/contracts/explore_state_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_query_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_debug_service.dart';
import 'package:flutter_legado/src/data/services/mock_explore_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_explore_state_repository.dart';
import 'package:flutter_legado/src/data/services/mock_book_source_query_service.dart';
import 'package:flutter_legado/src/data/services/mock_book_source_debug_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_auto_task_repository.dart';
import 'package:flutter_legado/src/data/services/mock_auto_task_service.dart';
import 'package:flutter_legado/src/domain/contracts/auto_task_repository.dart';
import 'package:flutter_legado/src/domain/contracts/auto_task_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_book_image_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_audio_cache_repository.dart';
import 'package:flutter_legado/src/data/services/mock_audio_cache_download_service.dart';
import 'package:flutter_legado/src/data/services/mock_audio_book_service.dart';
import 'package:flutter_legado/src/data/services/mock_video_danmaku_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/audio_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/video_danmaku_service.dart';
import 'package:flutter_legado/src/data/services/mock_local_book_service.dart';
import 'package:flutter_legado/src/data/services/mock_book_archive_service.dart';
import 'package:flutter_legado/src/data/services/mock_book_export_service.dart';
import 'package:flutter_legado/src/data/services/mock_review_service.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_archive_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_export_service.dart';
import 'package:flutter_legado/src/domain/contracts/review_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_cache_repository.dart';
import 'package:flutter_legado/src/data/services/mock_database_maintenance_service.dart';
import 'package:flutter_legado/src/domain/contracts/cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/database_maintenance_service.dart';
import 'package:flutter_legado/src/domain/contracts/app_log_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_app_log_repository.dart';
import 'package:flutter_legado/src/domain/contracts/dictionary_service.dart';
import 'package:flutter_legado/src/domain/contracts/dict_rule_repository.dart';
import 'package:flutter_legado/src/data/services/mock_dictionary_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_dict_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/highlight_repository.dart';
import 'package:flutter_legado/src/domain/contracts/highlight_rule_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_highlight_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_highlight_rule_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rule_sub_repository.dart';
import 'package:flutter_legado/src/data/services/mock_rule_sub_service.dart';
import 'package:flutter_legado/src/domain/contracts/rule_sub_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rule_sub_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_replace_rule_repository.dart';
import 'package:flutter_legado/src/data/services/mock_replace_rule_service.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_star_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_read_record_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_article_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_rss_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_article_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_star_repository.dart';
import 'package:flutter_legado/src/domain/contracts/chapter_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cache_download_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_chapter_cache_repository.dart';
import 'package:flutter_legado/src/data/services/mock_cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_reading_repository.dart';
import 'package:flutter_legado/src/domain/contracts/backup_repository.dart';
import 'package:flutter_legado/src/domain/contracts/webdav_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_backup_repository.dart';
import 'package:flutter_legado/src/data/services/mock_webdav_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_history_repository.dart';
import 'package:flutter_legado/src/data/services/mock_search_service.dart';
import 'package:flutter_legado/src/data/repositories/mock_search_history_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_source_login_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/data/services/mock_source_checker.dart';
import 'package:flutter_legado/src/domain/contracts/source_checker.dart';
import 'package:flutter_legado/src/data/repositories/mock_book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_bookshelf_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_book_group_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';

import 'package:flutter_legado/src/data/services/mock_http_tts_synthesizer.dart';
import 'package:flutter_legado/src/data/repositories/mock_bookmark_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_record_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

import 'app_test_api.dart';

import 'package:flutter_legado/src/data/bridge/mock_app_data.dart';

// 保留内存配置与运行时入口；独立Mock能力由同一装配点共享。

/// 旧用例的组合夹具；共享生产Mock数据，不作为应用入口。— Codex + UI
class MockBookApi implements TestApi {
  final _data = MockAppData();
  @override
  late final ReadingContentService readingContentService;
  @override
  late final SourceActionService sourceActionService;

  @override
  late final BookSourceEditService bookSourceEditService;
  @override
  late final SourceLoginV2Service sourceLoginV2Service;
  @override
  late final VerificationService verificationService;
  @override
  late final WebViewBridgeService webViewBridgeService;

  @override
  late final NetworkService networkService;
  @override
  late final LocalServerService localServerService;
  @override
  late final RuleExecutionService ruleExecutionService;

  @override
  late final SourceSwitchService sourceSwitchService;
  @override
  late final CoverSearchService coverSearchService;
  @override
  late final CoverRuleRepository coverRuleRepository;
  @override
  late final ExploreService exploreService;
  @override
  late final ExploreStateRepository exploreStateRepository;
  @override
  late final BookSourceQueryService bookSourceQueryService;
  @override
  late final BookSourceDebugService bookSourceDebugService;

  @override
  late final AutoTaskRepository autoTaskRepository;
  @override
  late final AutoTaskService autoTaskService;

  @override
  late final BookImageRepository bookImageRepository;
  @override
  late final AudioCacheRepository audioCacheRepository;
  @override
  late final AudioCacheDownloadService audioCacheDownloadService;
  @override
  late final AudioBookService audioBookService;
  @override
  late final VideoDanmakuService videoDanmakuService;

  @override
  late final LocalBookService localBookService;
  @override
  late final BookArchiveService bookArchiveService;
  @override
  late final BookExportService bookExportService;
  @override
  late final ReviewService reviewService;

  @override
  late final CacheRepository cacheRepository;
  @override
  late final DatabaseMaintenanceService databaseMaintenanceService;

  @override
  late final RuleSubRepository ruleSubRepository;
  @override
  late final HighlightRepository highlightRepository;
  @override
  late final DictionaryService dictionaryService;
  @override
  late final AppLogRepository appLogRepository;
  @override
  late final DictRuleRepository dictRuleRepository;
  @override
  late final HighlightRuleRepository highlightRuleRepository;
  @override
  late final RuleSubService ruleSubService;

  @override
  late final ReplaceRuleRepository replaceRuleRepository;
  @override
  late final ReplaceRuleService replaceRuleService;

  @override
  late final RssSourceRepository rssSourceRepository;

  @override
  late final RssArticleRepository rssArticleRepository;

  @override
  late final RssReadRecordRepository rssReadRecordRepository;

  @override
  late final RssStarRepository rssStarRepository;

  @override
  late final CloudTtsRepository cloudTtsRepository;
  @override
  final BackupRepository backupRepository = const MockBackupRepository();
  @override
  final WebDavService webDavService = const MockWebDavService();
  @override
  late final ReadingRepository readingRepository;
  @override
  late final ChapterCacheRepository chapterCacheRepository;
  @override
  late final CacheDownloadService cacheDownloadService;

  @override
  late final ConfigRepository configRepository;
  @override
  late final AppRuntime runtime;

  MockBookApi({
    AppRuntime? runtime,
    ReadingContentService? readingContentService,
    SourceActionService? sourceActionService,
    BookSourceEditService? bookSourceEditService,
    SourceLoginV2Service? sourceLoginV2Service,
    VerificationService? verificationService,
    WebViewBridgeService? webViewBridgeService,
    NetworkService? networkService,
    LocalServerService? localServerService,
    RuleExecutionService? ruleExecutionService,
    SourceSwitchService? sourceSwitchService,
    CoverSearchService? coverSearchService,
    CoverRuleRepository? coverRuleRepository,
    ExploreService? exploreService,
    ExploreStateRepository? exploreStateRepository,
    BookSourceQueryService? bookSourceQueryService,
    BookSourceDebugService? bookSourceDebugService,
    AutoTaskRepository? autoTaskRepository,
    AutoTaskService? autoTaskService,
    BookImageRepository? bookImageRepository,
    AudioCacheRepository? audioCacheRepository,
    AudioCacheDownloadService? audioCacheDownloadService,
    AudioBookService? audioBookService,
    VideoDanmakuService? videoDanmakuService,

    LocalBookService? localBookService,
    BookArchiveService? bookArchiveService,
    BookExportService? bookExportService,
    ReviewService? reviewService,

    CacheRepository? cacheRepository,
    DatabaseMaintenanceService? databaseMaintenanceService,
    AppLogRepository? appLogRepository,
    DictionaryService? dictionaryService,
    DictRuleRepository? dictRuleRepository,
    HighlightRepository? highlightRepository,
    HighlightRuleRepository? highlightRuleRepository,
    RuleSubRepository? ruleSubRepository,
    RuleSubService? ruleSubService,
    ReplaceRuleRepository? replaceRuleRepository,
    ReplaceRuleService? replaceRuleService,
    RssSourceRepository? rssSourceRepository,
    RssArticleRepository? rssArticleRepository,
    RssReadRecordRepository? rssReadRecordRepository,
    RssStarRepository? rssStarRepository,
    ChapterCacheRepository? chapterCacheRepository,
    CacheDownloadService? cacheDownloadService,
    ReadingRepository? readingRepository,
    BookmarkRepository? bookmarkRepository,
    ReadRecordRepository? readRecordRepository,
    HttpTtsRepository? httpTtsRepository,
    HttpTtsSynthesizer? httpTtsSynthesizer,
    SourceChecker? sourceChecker,
    SourceLoginRepository? sourceLoginRepository,
    SearchService? searchService,
    SearchHistoryRepository? searchHistoryRepository,
  }) {
    configRepository = MockConfigRepository(values: _data.configs);
    this.runtime = runtime ?? MockAppRuntime(startup: _data.initialize);
    this.readingContentService =
        readingContentService ??
        MockReadingContentService(configs: _data.configs);
    this.sourceActionService =
        sourceActionService ?? const MockSourceActionService();
    this.bookSourceEditService =
        bookSourceEditService ?? const MockBookSourceEditService();
    this.sourceLoginV2Service =
        sourceLoginV2Service ?? const MockSourceLoginV2Service();
    this.verificationService =
        verificationService ?? const MockVerificationService();
    this.webViewBridgeService =
        webViewBridgeService ?? const MockWebViewBridgeService();
    this.networkService =
        networkService ?? MockNetworkService(configs: _data.configs);
    this.localServerService =
        localServerService ?? MockLocalServerService(configs: _data.configs);
    this.ruleExecutionService =
        ruleExecutionService ?? const MockRuleExecutionService();
    this.cacheRepository = cacheRepository ?? const MockCacheRepository();
    this.databaseMaintenanceService =
        databaseMaintenanceService ?? const MockDatabaseMaintenanceService();
    this.appLogRepository = appLogRepository ?? MockAppLogRepository();
    this.dictionaryService = dictionaryService ?? const MockDictionaryService();
    this.dictRuleRepository = dictRuleRepository ?? MockDictRuleRepository();
    this.highlightRepository = highlightRepository ?? MockHighlightRepository();
    this.highlightRuleRepository =
        highlightRuleRepository ??
        MockHighlightRuleRepository(nextId: () => _data.allocateId());
    this.ruleSubRepository = ruleSubRepository ?? MockRuleSubRepository();
    this.ruleSubService =
        ruleSubService ??
        MockRuleSubService(repository: this.ruleSubRepository);
    this.replaceRuleRepository =
        replaceRuleRepository ??
        MockReplaceRuleRepository(nextId: () => _data.allocateId());
    this.replaceRuleService =
        replaceRuleService ?? const MockReplaceRuleService();
    this.rssSourceRepository =
        rssSourceRepository ??
        MockRssSourceRepository(withDefaultSources: true);
    this.rssArticleRepository =
        rssArticleRepository ?? const MockRssArticleRepository();
    this.rssReadRecordRepository =
        rssReadRecordRepository ?? MockRssReadRecordRepository();
    this.rssStarRepository = rssStarRepository ?? MockRssStarRepository();
    this.chapterCacheRepository =
        chapterCacheRepository ?? const MockChapterCacheRepository();
    this.cacheDownloadService =
        cacheDownloadService ?? const MockCacheDownloadService();
    bookshelfRepository = MockBookshelfRepository(store: _data.bookshelf);
    this.readingRepository =
        readingRepository ??
        MockReadingRepository(
          books: _data.bookshelf,
          chapters: _data.chapters,
          contents: _data.contents,
        );
    this.exploreService = exploreService ?? const MockExploreService();
    this.exploreStateRepository =
        exploreStateRepository ?? MockExploreStateRepository();
    this.bookSourceQueryService =
        bookSourceQueryService ?? const MockBookSourceQueryService();
    this.bookSourceDebugService =
        bookSourceDebugService ?? const MockBookSourceDebugService();
    String allocateTaskId() => 'mock-task-${_data.allocateId()}';
    this.autoTaskRepository =
        autoTaskRepository ??
        MockAutoTaskRepository(allocateId: allocateTaskId);
    this.autoTaskService =
        autoTaskService ?? MockAutoTaskService(allocateId: allocateTaskId);
    this.bookImageRepository = bookImageRepository ?? MockBookImageRepository();
    final audioCacheStore = MockAudioCacheStore();
    this.audioCacheRepository =
        audioCacheRepository ??
        MockAudioCacheRepository(store: audioCacheStore);
    this.audioCacheDownloadService =
        audioCacheDownloadService ??
        MockAudioCacheDownloadService(store: audioCacheStore);
    this.audioBookService =
        audioBookService ??
        MockAudioBookService(reading: this.readingRepository);
    this.videoDanmakuService =
        videoDanmakuService ?? const MockVideoDanmakuService();
    this.localBookService =
        localBookService ?? MockLocalBookService(store: _data.bookshelf);
    this.bookArchiveService =
        bookArchiveService ?? const MockBookArchiveService();
    this.bookExportService =
        bookExportService ??
        MockBookExportService(
          bookshelf: bookshelfRepository,
          reading: this.readingRepository,
        );
    this.reviewService = reviewService ?? const MockReviewService();
    bookGroupRepository = MockBookGroupRepository(
      nextId: () => _data.allocateId(),
      withDefaultGroups: true,
    );
    this.bookmarkRepository =
        bookmarkRepository ??
        MockBookmarkRepository(nextId: () => _data.allocateId());
    this.readRecordRepository =
        readRecordRepository ?? MockReadRecordRepository();
    readAloudVoiceRepository = MockReadAloudVoiceRepository();
    cloudTtsRepository = MockCloudTtsRepository(
      onDelete: readAloudVoiceRepository.clearCloud,
    );
    this.httpTtsRepository =
        httpTtsRepository ??
        MockHttpTtsRepository(
          nextId: () => _data.allocateId(),
          voiceCatalog: readAloudVoiceRepository,
          withDefaultEngines: true,
        );
    this.httpTtsSynthesizer =
        httpTtsSynthesizer ?? const MockHttpTtsSynthesizer();
    bookSourceRepository = MockBookSourceRepository(
      store: _data.sources,
      writeConfig: (key, value) => _data.configs[key] = value,
    );
    this.sourceChecker =
        sourceChecker ?? MockSourceChecker(store: _data.sources);
    this.sourceLoginRepository =
        sourceLoginRepository ?? MockSourceLoginRepository();
    this.searchService = searchService ?? const MockSearchService();
    this.searchHistoryRepository =
        searchHistoryRepository ?? MockSearchHistoryRepository();
    this.coverRuleRepository = coverRuleRepository ?? MockCoverRuleRepository();
    this.sourceSwitchService =
        sourceSwitchService ??
        MockSourceSwitchService(
          bookshelf: bookshelfRepository,
          sources: bookSourceRepository,
        );
    this.coverSearchService =
        coverSearchService ?? const MockCoverSearchService();
  }

  @override
  late final BookmarkRepository bookmarkRepository;

  @override
  late final ReadRecordRepository readRecordRepository;

  @override
  late final HttpTtsRepository httpTtsRepository;
  @override
  late final MockReadAloudVoiceRepository readAloudVoiceRepository;

  @override
  late final HttpTtsSynthesizer httpTtsSynthesizer;

  @override
  TtsCacheRepository get ttsCacheRepository => const MockTtsCacheRepository();

  @override
  late final BookshelfRepository bookshelfRepository;

  @override
  late final BookGroupRepository bookGroupRepository;

  @override
  late final BookSourceRepository bookSourceRepository;

  @override
  late final SourceChecker sourceChecker;

  @override
  late final SourceLoginRepository sourceLoginRepository;

  @override
  late final SearchService searchService;
  @override
  late final SearchHistoryRepository searchHistoryRepository;
}
