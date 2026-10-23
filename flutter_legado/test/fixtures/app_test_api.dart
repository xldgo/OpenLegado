import 'read_aloud_planner.dart';
import 'preview_normalize_stub.dart';

import 'package:flutter_legado/src/app/bootstrap/source_import_factory.dart';

import 'dart:async';

import 'media_audio_service.dart';
import 'media_artwork_loader.dart';

import 'package:flutter_legado/src/features/audio/application/audio_notifier.dart'
    show audioServiceProvider, mediaArtworkLoaderProvider;
import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'mock_book_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_privacy_credential_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

export 'mock_book_api.dart';

import 'package:flutter_legado/src/domain/contracts/config_repository.dart';
import 'package:flutter_legado/src/domain/contracts/app_runtime.dart';
import 'package:flutter_legado/src/domain/contracts/reading_content_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_action_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_edit_service.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_v2_service.dart';
import 'package:flutter_legado/src/domain/contracts/verification_service.dart';
import 'package:flutter_legado/src/domain/contracts/webview_bridge_service.dart';
import 'package:flutter_legado/src/domain/contracts/network_service.dart';
import 'package:flutter_legado/src/domain/contracts/local_server_service.dart';
import 'package:flutter_legado/src/domain/contracts/rule_execution_service.dart';
import 'package:flutter_legado/src/domain/contracts/cover_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_switch_service.dart';
import 'package:flutter_legado/src/domain/contracts/cover_search_service.dart';
import 'package:flutter_legado/src/domain/contracts/explore_service.dart';
import 'package:flutter_legado/src/domain/contracts/explore_state_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_query_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_debug_service.dart';
import 'package:flutter_legado/src/domain/contracts/auto_task_repository.dart';
import 'package:flutter_legado/src/domain/contracts/auto_task_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_image_repository.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/audio_cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/audio_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/video_danmaku_service.dart';
import 'package:flutter_legado/src/domain/contracts/local_book_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_archive_service.dart';
import 'package:flutter_legado/src/domain/contracts/book_export_service.dart';
import 'package:flutter_legado/src/domain/contracts/review_service.dart';
import 'package:flutter_legado/src/domain/contracts/cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/database_maintenance_service.dart';
import 'package:flutter_legado/src/domain/contracts/app_log_repository.dart';
import 'package:flutter_legado/src/domain/contracts/dictionary_service.dart';
import 'package:flutter_legado/src/domain/contracts/dict_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/highlight_repository.dart';
import 'package:flutter_legado/src/domain/contracts/highlight_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rule_sub_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rule_sub_service.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_service.dart';
import 'package:flutter_legado/src/domain/contracts/rss_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_article_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/rss_star_repository.dart';
import 'package:flutter_legado/src/domain/contracts/chapter_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cache_download_service.dart';
import 'package:flutter_legado/src/domain/contracts/reading_repository.dart';
import 'package:flutter_legado/src/domain/contracts/backup_repository.dart';
import 'package:flutter_legado/src/domain/contracts/webdav_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_history_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_repository.dart';
import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_checker.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_record_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';

import 'package:flutter_legado/src/data/bridge/runtime_configuration.dart';
import 'package:flutter_legado/src/features/appearance/appearance_settings_provider.dart';

/// 书籍 API 抽象接口
///
/// 仅保留领域能力和运行时的装配引用，消费者通过窄接口访问。
/// 实现类：
/// - [RustApi]：真实 FFI 实现（需要 Rust DLL）
/// - MockBookApi：纯 Dart Mock 实现（无 DLL 可跑，UI 轨开发用）
abstract class TestApi {
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

/// 仅用于测试的组合装配，生产代码不依赖此集合。— Codex + UI
extension TestApiOverrides on TestApi {
  List<Override> get overrides => [
    sourcePreviewNormalizerProvider.overrideWithValue(stubPreviewNormalize),
    appLogRepositoryProvider.overrideWith((ref) => appLogRepository),
    webDavServiceProvider.overrideWith((ref) => webDavService),
    backupRepositoryProvider.overrideWith((ref) => backupRepository),
    localBookServiceProvider.overrideWith((ref) => localBookService),
    bookArchiveServiceProvider.overrideWith((ref) => bookArchiveService),
    bookExportServiceProvider.overrideWith((ref) => bookExportService),
    reviewServiceProvider.overrideWith((ref) => reviewService),
    cacheRepositoryProvider.overrideWith((ref) => cacheRepository),
    databaseMaintenanceServiceProvider.overrideWith(
      (ref) => databaseMaintenanceService,
    ),
    chapterCacheRepositoryProvider.overrideWith(
      (ref) => chapterCacheRepository,
    ),
    cacheDownloadServiceProvider.overrideWith((ref) => cacheDownloadService),
    configRepositoryProvider.overrideWith((ref) => configRepository),
    coverSearchServiceProvider.overrideWith((ref) => coverSearchService),
    coverRuleRepositoryProvider.overrideWith((ref) => coverRuleRepository),
    dictionaryServiceProvider.overrideWith((ref) => dictionaryService),
    dictRuleRepositoryProvider.overrideWith((ref) => dictRuleRepository),
    highlightRepositoryProvider.overrideWith((ref) => highlightRepository),
    highlightRuleRepositoryProvider.overrideWith(
      (ref) => highlightRuleRepository,
    ),
    localServerServiceProvider.overrideWith((ref) => localServerService),
    bookImageRepositoryProvider.overrideWith((ref) => bookImageRepository),
    audioCacheRepositoryProvider.overrideWith((ref) => audioCacheRepository),
    audioCacheDownloadServiceProvider.overrideWith(
      (ref) => audioCacheDownloadService,
    ),
    audioBookServiceProvider.overrideWith((ref) => audioBookService),
    videoDanmakuServiceProvider.overrideWith((ref) => videoDanmakuService),
    networkServiceProvider.overrideWith((ref) => networkService),
    readingContentServiceProvider.overrideWith((ref) => readingContentService),
    readingRepositoryProvider.overrideWith((ref) => readingRepository),
    replaceRuleRepositoryProvider.overrideWith((ref) => replaceRuleRepository),
    replaceRuleServiceProvider.overrideWith((ref) => replaceRuleService),
    rssSourceRepositoryProvider.overrideWith((ref) => rssSourceRepository),
    rssArticleRepositoryProvider.overrideWith((ref) => rssArticleRepository),
    rssReadRecordRepositoryProvider.overrideWith(
      (ref) => rssReadRecordRepository,
    ),
    rssStarRepositoryProvider.overrideWith((ref) => rssStarRepository),
    ruleExecutionServiceProvider.overrideWith((ref) => ruleExecutionService),
    ruleSubRepositoryProvider.overrideWith((ref) => ruleSubRepository),
    ruleSubServiceProvider.overrideWith((ref) => ruleSubService),
    sourceActionServiceProvider.overrideWith((ref) => sourceActionService),
    bookSourceEditServiceProvider.overrideWith((ref) => bookSourceEditService),
    sourceLoginV2ServiceProvider.overrideWith((ref) => sourceLoginV2Service),
    verificationServiceProvider.overrideWith((ref) => verificationService),
    webViewBridgeServiceProvider.overrideWith((ref) => webViewBridgeService),
    autoTaskRepositoryProvider.overrideWith((ref) => autoTaskRepository),
    autoTaskServiceProvider.overrideWith((ref) => autoTaskService),
    sourceSwitchServiceProvider.overrideWith((ref) => sourceSwitchService),
    exploreServiceProvider.overrideWith((ref) => exploreService),
    exploreStateRepositoryProvider.overrideWith(
      (ref) => exploreStateRepository,
    ),
    bookSourceQueryServiceProvider.overrideWith(
      (ref) => bookSourceQueryService,
    ),
    bookSourceDebugServiceProvider.overrideWith(
      (ref) => bookSourceDebugService,
    ),
    bookmarkRepositoryProvider.overrideWith((ref) => bookmarkRepository),
    bookshelfRepositoryProvider.overrideWith((ref) => bookshelfRepository),
    bookGroupRepositoryProvider.overrideWith((ref) => bookGroupRepository),
    bookSourceRepositoryProvider.overrideWith((ref) => bookSourceRepository),
    sourceCheckerProvider.overrideWith((ref) => sourceChecker),
    sourceLoginRepositoryProvider.overrideWith((ref) => sourceLoginRepository),
    cloudTtsRepositoryProvider.overrideWith((ref) => cloudTtsRepository),
    httpTtsRepositoryProvider.overrideWith((ref) => httpTtsRepository),
    httpTtsSynthesizerProvider.overrideWith((ref) => httpTtsSynthesizer),
    ttsCacheRepositoryProvider.overrideWith((ref) => ttsCacheRepository),
    readAloudVoiceRepositoryProvider.overrideWith(
      (ref) => readAloudVoiceRepository,
    ),
    readRecordRepositoryProvider.overrideWith((ref) => readRecordRepository),
    searchServiceProvider.overrideWith((ref) => searchService),
    searchHistoryRepositoryProvider.overrideWith(
      (ref) => searchHistoryRepository,
    ),
    if (this is MockBookApi)
      privacyCredentialProvider.overrideWithValue(
        MockPrivacyCredentialRepository(),
      ),
    appRuntimeProvider.overrideWith((ref) => runtime),
    readingConfigSyncProvider.overrideWithValue(
      this is ReadingConfigSync
          ? this as ReadingConfigSync
          : const NoopReadingConfigSync(),
    ),
    themeConfigSyncProvider.overrideWithValue(
      this is ThemeConfigSync
          ? this as ThemeConfigSync
          : const NoopThemeConfigSync(),
    ),
  ];
}

/// 组合夹具先提供缺省依赖，单个用例后声明的替身优先。
List<Override> mergeTestOverrides(List<Override> values) => {
  for (final value in [
    readAloudPlannerProvider.overrideWithValue(FixtureReadAloudPlanner()),
    mediaArtworkLoaderProvider.overrideWithValue(FakeMediaArtworkLoader()),
    audioServiceProvider.overrideWith((ref) {
      final audio = TestMediaAudioService();
      ref.onDispose(() => unawaited(audio.closeStreams()));
      return audio;
    }),
    ...values,
  ])
    value.origin: value,
}.values.toList();
