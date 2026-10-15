import '../data/repositories/mock_cache_repository.dart';
import '../data/services/mock_database_maintenance_service.dart';
import '../domain/contracts/cache_repository.dart';
import '../domain/contracts/database_maintenance_service.dart';
import '../domain/contracts/app_log_repository.dart';
import '../data/repositories/mock_app_log_repository.dart';
import '../domain/contracts/dictionary_service.dart';
import '../domain/contracts/dict_rule_repository.dart';
import '../data/services/mock_dictionary_service.dart';
import '../data/repositories/mock_dict_rule_repository.dart';
import '../domain/contracts/highlight_repository.dart';
import '../domain/contracts/highlight_rule_repository.dart';
import '../data/repositories/mock_highlight_repository.dart';
import '../data/repositories/mock_highlight_rule_repository.dart';
import '../data/repositories/mock_rule_sub_repository.dart';
import '../data/services/mock_rule_sub_service.dart';
import '../domain/contracts/rule_sub_repository.dart';
import '../domain/contracts/rule_sub_service.dart';
import '../data/repositories/mock_replace_rule_repository.dart';
import '../data/services/mock_replace_rule_service.dart';
import '../domain/contracts/replace_rule_repository.dart';
import '../domain/contracts/replace_rule_service.dart';
import '../data/repositories/mock_rss_star_repository.dart';
import '../data/repositories/mock_rss_read_record_repository.dart';
import '../data/repositories/mock_rss_article_repository.dart';
import '../data/repositories/mock_rss_source_repository.dart';
import '../domain/contracts/rss_source_repository.dart';
import '../domain/contracts/rss_article_repository.dart';
import '../domain/contracts/rss_read_record_repository.dart';
import '../domain/contracts/rss_star_repository.dart';
import '../domain/contracts/chapter_cache_repository.dart';
import '../domain/contracts/cache_download_service.dart';
import '../data/repositories/mock_chapter_cache_repository.dart';
import '../data/services/mock_cache_download_service.dart';
import '../domain/contracts/reading_repository.dart';
import '../data/repositories/mock_reading_repository.dart';
import '../domain/contracts/backup_repository.dart';
import '../domain/contracts/webdav_service.dart';
import '../data/repositories/mock_backup_repository.dart';
import '../data/services/mock_webdav_service.dart';
import '../domain/contracts/search_service.dart';
import '../domain/contracts/search_history_repository.dart';
import '../data/services/mock_search_service.dart';
import '../data/repositories/mock_search_history_repository.dart';
import '../domain/contracts/source_login_repository.dart';
import '../data/repositories/mock_source_login_repository.dart';
import '../data/repositories/mock_cloud_tts_repository.dart';
import '../domain/contracts/cloud_tts_repository.dart';
import '../data/repositories/mock_read_aloud_voice_repository.dart';
import '../data/repositories/mock_tts_cache_repository.dart';
import '../domain/contracts/tts_cache_repository.dart';
import '../data/services/mock_source_checker.dart';
import '../domain/contracts/source_checker.dart';
import '../data/repositories/mock_book_source_repository.dart';
import '../domain/contracts/book_source_repository.dart';
import '../data/repositories/mock_bookshelf_repository.dart';
import '../data/repositories/mock_book_group_repository.dart';
import '../domain/contracts/bookshelf_repository.dart';
import '../domain/contracts/book_group_repository.dart';

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';
import '../data/services/mock_http_tts_synthesizer.dart';
import '../data/repositories/mock_bookmark_repository.dart';
import '../data/repositories/mock_read_record_repository.dart';
import '../data/repositories/mock_http_tts_repository.dart';
import '../domain/contracts/bookmark_repository.dart';
import '../domain/contracts/read_record_repository.dart';
import '../domain/contracts/http_tts_repository.dart';
import '../domain/contracts/http_tts_synthesizer.dart';
import 'book_api.dart';

part 'mock_book_api_store.part.dart';
part 'mock_book_api_sources.part.dart';
part 'mock_book_api_search_rss.part.dart';
part 'mock_book_api_reader_data.part.dart';
part 'mock_book_api_discovery_cache.part.dart';
part 'mock_book_api_media_format.part.dart';
part 'mock_book_api_sync_tools.part.dart';
part 'mock_book_api_content_ext.part.dart';

// ↑ 分域 part 文件（体检 §三.16 超长文件拆分）：MockBookApi 按域拆为 mixin 组合，
// 各 mixin 方法原样搬移、合集实现 BookApi，零行为变更。

/// Mock 书籍 API 实现
///
/// 纯 Dart 实现，无需 Rust DLL，供 UI 轨开发使用。
/// 所有数据存储在内存中，会话内可读写。
/// 用法：`flutter run -d windows --dart-define=USE_MOCK=true`
///
/// ─── Mock 数据来源说明（REFACTORING_PLAN §6.4）───
///
/// 书源（BookSource）样本取自原 Android 端内置默认数据：
///   app/src/main/assets/defaultData/bookSources.json
///   （消消乐听书源，bookSourceType=1 音频源，含完整 ruleSearch/ruleExplore/ruleToc）
///
/// RSS 源（RssSource）样本取自原 Android 端内置默认数据：
///   app/src/main/assets/defaultData/rssSources.json
///   （使用说明 / 小说拾遗 / Meow云 / 烏雲净化，均为 legado 官方内置源）
///
/// HTTP TTS 引擎样本取自原 Android 端内置默认数据：
///   app/src/main/assets/defaultData/httpTTS.json
///   （百度 TTS / 阿里云语音，含真实 url 模板与 contentType）
///
/// 书架书籍（Book）消费合成脱敏样例资产
///   assets/mock_data/bookshelf_sample.json（USE_MOCK 数据源）：
///   结构严格对齐 flutter_legado/lib/src/models/book.dart 与
///   docs/API_CONTRACT.md §2.2（键名/类型与原版书架导出一致），
///   内容已全部替换为虚构数据（书名/作者/URL 均为示例值，http(s) 主机名
///   仅 example.com，不指向任何真实站点）；
///   来源与脱敏口径见 assets/mock_data/README.md。
class MockBookApi
    with
        MockBookApiStore,
        MockBookApiSources,
        MockBookApiSearchRss,
        MockBookApiReaderData,
        MockBookApiDiscoveryCache,
        MockBookApiMediaFormat,
        MockBookApiSyncTools,
        MockBookApiContentExt
    implements BookApi {
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

  MockBookApi({
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
    this.cacheRepository = cacheRepository ?? const MockCacheRepository();
    this.databaseMaintenanceService =
        databaseMaintenanceService ?? const MockDatabaseMaintenanceService();
    this.appLogRepository = appLogRepository ?? MockAppLogRepository();
    this.dictionaryService = dictionaryService ?? const MockDictionaryService();
    this.dictRuleRepository = dictRuleRepository ?? MockDictRuleRepository();
    this.highlightRepository = highlightRepository ?? MockHighlightRepository();
    this.highlightRuleRepository =
        highlightRuleRepository ??
        MockHighlightRuleRepository(nextId: () => _nextId++);
    this.ruleSubRepository = ruleSubRepository ?? MockRuleSubRepository();
    this.ruleSubService =
        ruleSubService ??
        MockRuleSubService(repository: this.ruleSubRepository);
    this.replaceRuleRepository =
        replaceRuleRepository ??
        MockReplaceRuleRepository(nextId: () => _nextId++);
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
    _bookshelfStore = MockBookshelfStore(load: _loadBookshelfSample);
    bookshelfRepository = MockBookshelfRepository(store: _bookshelfStore);
    this.readingRepository =
        readingRepository ??
        MockReadingRepository(
          books: _bookshelfStore,
          chapters: _chaptersCache,
          contents: _contentCache,
        );
    bookGroupRepository = MockBookGroupRepository(
      nextId: () => _nextId++,
      withDefaultGroups: true,
    );
    this.bookmarkRepository =
        bookmarkRepository ?? MockBookmarkRepository(nextId: () => _nextId++);
    this.readRecordRepository =
        readRecordRepository ?? MockReadRecordRepository();
    readAloudVoiceRepository = MockReadAloudVoiceRepository();
    cloudTtsRepository = MockCloudTtsRepository(
      onDelete: readAloudVoiceRepository.clearCloud,
    );
    this.httpTtsRepository =
        httpTtsRepository ??
        MockHttpTtsRepository(
          nextId: () => _nextId++,
          voiceCatalog: readAloudVoiceRepository,
          withDefaultEngines: true,
        );
    this.httpTtsSynthesizer =
        httpTtsSynthesizer ?? const MockHttpTtsSynthesizer();
    _bookSourceStore = MockBookSourceStore();
    bookSourceRepository = MockBookSourceRepository(
      store: _bookSourceStore,
      writeConfig: (key, value) => _configs[key] = value,
    );
    this.sourceChecker =
        sourceChecker ?? MockSourceChecker(store: _bookSourceStore);
    this.sourceLoginRepository =
        sourceLoginRepository ?? MockSourceLoginRepository();
    this.searchService = searchService ?? const MockSearchService();
    this.searchHistoryRepository =
        searchHistoryRepository ?? MockSearchHistoryRepository();
    _initMockData();
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

  // ========== 初始化/版本 ==========

  @override
  Future<void> initialize() async {
    // Mock 模式无需初始化；确保书架样例资产已加载
    // （MockBookApi 构造器保持同步，资产读取为异步，经守卫惰性完成）
    await _ensureBooksLoaded();
  }

  @override
  Future<String> getVersion() async => 'mock-1.0.0';
}
