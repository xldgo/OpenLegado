library;

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
import 'package:flutter_legado/src/domain/models/book_highlight.dart';
import 'package:flutter_legado/src/domain/models/highlight_rule.dart';

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
import 'package:flutter_legado/src/domain/models/webdav_connection.dart';

/// 单元测试 Mock 定义
///
/// 使用 mocktail 生成 RustApi / AudioService / http.Client 的 mock 实例，
/// 供 Providers / Services 层测试使用。

import 'package:flutter_legado/src/domain/contracts/search_service.dart';
import 'package:flutter_legado/src/domain/contracts/search_history_repository.dart';

import 'package:flutter_legado/src/domain/contracts/cloud_tts_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_cloud_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/tts_cache_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_tts_cache_repository.dart';
import 'package:flutter_legado/src/domain/contracts/read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/data/repositories/mock_read_aloud_voice_repository.dart';
import 'package:flutter_legado/src/domain/contracts/source_checker.dart';
import 'package:flutter_legado/src/domain/contracts/source_login_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_source_repository.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';
import 'package:flutter_legado/src/domain/contracts/book_group_repository.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_panel.dart';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

import 'package:flutter_legado/src/services/rust_api.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_repository.dart';
import 'package:flutter_legado/src/domain/contracts/http_tts_synthesizer.dart';
import 'package:flutter_legado/src/services/audio_service.dart';
import 'package:flutter_legado/src/services/stream_audio_player.dart';
import 'package:flutter_legado/src/models/models.dart';

/// RustApi 的 mock 实现
class MockHttpTtsRepository extends Mock implements HttpTtsRepository {
  MockHttpTtsRepository() {
    when(() => getHttpTts()).thenAnswer((_) async => const []);
  }
}

class MockHttpTtsSynthesizer extends Mock implements HttpTtsSynthesizer {}

class _MockBookshelfRepository extends Mock implements BookshelfRepository {}

class _MockBookGroupRepository extends Mock implements BookGroupRepository {}

class _MockBookSourceRepository extends Mock implements BookSourceRepository {}

class SourceCheckerMock extends Mock implements SourceChecker {}

class SourceLoginRepositoryMock extends Mock implements SourceLoginRepository {}

class SearchServiceMock extends Mock implements SearchService {}

class SearchHistoryRepositoryMock extends Mock
    implements SearchHistoryRepository {}

class BackupRepositoryMock extends Mock implements BackupRepository {}

class WebDavServiceMock extends Mock implements WebDavService {}

class ReadingRepositoryMock extends Mock implements ReadingRepository {}

class ChapterCacheRepositoryMock extends Mock
    implements ChapterCacheRepository {}

class CacheDownloadServiceMock extends Mock implements CacheDownloadService {}

class RssSourceRepositoryMock extends Mock implements RssSourceRepository {}

class RssArticleRepositoryMock extends Mock implements RssArticleRepository {}

class RssReadRecordRepositoryMock extends Mock
    implements RssReadRecordRepository {}

class RssStarRepositoryMock extends Mock implements RssStarRepository {}

class ReplaceRuleRepositoryMock extends Mock implements ReplaceRuleRepository {}

class ReplaceRuleServiceMock extends Mock implements ReplaceRuleService {}

class RuleSubRepositoryMock extends Mock implements RuleSubRepository {}

class RuleSubServiceMock extends Mock implements RuleSubService {}

class HighlightRepositoryMock extends Mock implements HighlightRepository {}

class HighlightRuleRepositoryMock extends Mock
    implements HighlightRuleRepository {}

class DictionaryServiceMock extends Mock implements DictionaryService {}

class DictRuleRepositoryMock extends Mock implements DictRuleRepository {}

class AppLogRepositoryMock extends Mock implements AppLogRepository {}

class CacheRepositoryMock extends Mock implements CacheRepository {}

class DatabaseMaintenanceServiceMock extends Mock
    implements DatabaseMaintenanceService {}

class LocalBookServiceMock extends Mock implements LocalBookService {}

class BookArchiveServiceMock extends Mock implements BookArchiveService {}

class BookExportServiceMock extends Mock implements BookExportService {}

class ReviewServiceMock extends Mock implements ReviewService {}

class MockRustApi extends Mock implements RustApi {
  @override
  final LocalBookService localBookService = LocalBookServiceMock();
  @override
  final BookArchiveService bookArchiveService = BookArchiveServiceMock();
  @override
  final BookExportService bookExportService = BookExportServiceMock();
  @override
  final ReviewService reviewService = ReviewServiceMock();

  @override
  final CacheRepository cacheRepository = CacheRepositoryMock();
  @override
  final DatabaseMaintenanceService databaseMaintenanceService =
      DatabaseMaintenanceServiceMock();
  @override
  final AppLogRepository appLogRepository = AppLogRepositoryMock();
  @override
  final DictionaryService dictionaryService = DictionaryServiceMock();
  @override
  final DictRuleRepository dictRuleRepository = DictRuleRepositoryMock();
  @override
  final HighlightRepository highlightRepository = HighlightRepositoryMock();
  @override
  final HighlightRuleRepository highlightRuleRepository =
      HighlightRuleRepositoryMock();
  @override
  final RuleSubRepository ruleSubRepository = RuleSubRepositoryMock();
  @override
  final RuleSubService ruleSubService = RuleSubServiceMock();
  @override
  final ReplaceRuleRepository replaceRuleRepository =
      ReplaceRuleRepositoryMock();
  @override
  final ReplaceRuleService replaceRuleService = ReplaceRuleServiceMock();
  @override
  final RssSourceRepository rssSourceRepository = RssSourceRepositoryMock();
  @override
  final RssArticleRepository rssArticleRepository = RssArticleRepositoryMock();
  @override
  final RssReadRecordRepository rssReadRecordRepository =
      RssReadRecordRepositoryMock();
  @override
  final RssStarRepository rssStarRepository = RssStarRepositoryMock();

  @override
  final ChapterCacheRepository chapterCacheRepository =
      ChapterCacheRepositoryMock();
  @override
  final CacheDownloadService cacheDownloadService = CacheDownloadServiceMock();
  @override
  final ReadingRepository readingRepository = ReadingRepositoryMock();
  @override
  final BackupRepository backupRepository = BackupRepositoryMock();
  @override
  final WebDavService webDavService = WebDavServiceMock();
  MockRustApi() {
    // 普通夹具给出默认跟随配置，避免无关播放测试进入旧Preferences迁移。
    // 设置/迁移用例按需覆盖为实际数据、空值或读取失败。
    when(() => getConfig(any())).thenAnswer(
      (call) async =>
          call.positionalArguments.first == 'ttsFollowSys' ? 'true' : null,
    );
  }

  @override
  final SearchService searchService = SearchServiceMock();
  @override
  final SearchHistoryRepository searchHistoryRepository =
      SearchHistoryRepositoryMock();
  @override
  final CloudTtsRepository cloudTtsRepository = MockCloudTtsRepository();
  @override
  final ReadAloudVoiceRepository readAloudVoiceRepository =
      MockReadAloudVoiceRepository(supportsCatalog: false);
  @override
  final TtsCacheRepository ttsCacheRepository = const MockTtsCacheRepository();
  @override
  final SourceLoginRepository sourceLoginRepository =
      SourceLoginRepositoryMock();
  @override
  final SourceChecker sourceChecker = SourceCheckerMock();
  @override
  final BookSourceRepository bookSourceRepository = _MockBookSourceRepository();
  @override
  final BookshelfRepository bookshelfRepository = _MockBookshelfRepository();
  @override
  final BookGroupRepository bookGroupRepository = _MockBookGroupRepository();
  @override
  final HttpTtsSynthesizer httpTtsSynthesizer = MockHttpTtsSynthesizer();
  @override
  final HttpTtsRepository httpTtsRepository = MockHttpTtsRepository();
}

/// AudioService 的 mock 实现
class MockAudioService extends Mock implements AudioService {
  MockAudioService() {
    registerFallbackValue(
      const MediaPlaybackProgress(
        mediaId: '',
        sessionToken: 0,
        chapterIndex: 0,
        state: 'paused',
        position: 0,
        duration: 0,
        speed: 1,
        canSeek: false,
        hasPrevious: false,
        hasNext: false,
        isStream: false,
      ),
    );
    when(() => updateProgress(any())).thenAnswer((_) async {});
    when(() => seekStream).thenAnswer((_) => const Stream.empty());
    when(() => openPlaybackStream).thenAnswer((_) => const Stream.empty());
    when(() => takePendingOpen()).thenAnswer((_) async => null);
  }
}

/// StreamAudioPlayer 的 Fake 实现（A1 批 TTS 本地播放链测试）
///
/// 记录网络/本地播放调用，由测试经 [completePlayback] 手动触发完成回调，
/// 便于验证「完成回调驱动段落推进」而非估算 Timer。
class FakeStreamAudioPlayer implements StreamAudioPlayer {
  final List<String> playedUrls = [];
  final List<({String path, double speed})> playedLocalFiles = [];
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int disposeCount = 0;
  int seekCount = 0;
  Duration? lastSeekPosition;

  @override
  bool isInitialized = false;
  @override
  bool isPlaying = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = Duration.zero;
  @override
  String? currentUrl;
  @override
  void Function(Object? tag)? onCompleted;
  @override
  void Function(Object error, Object? tag)? onError;
  @override
  void Function(Duration position, Duration duration, Object? tag)? onProgress;

  /// 当前装载绑定的归属标识（模拟真实播放器闭包捕获的 tag，stop 后清空）
  @override
  Object? currentTag;

  /// 每次 playUrl/playLocalFile 绑定的归属标识（供测试取旧章 tag 模拟迟到回调）
  final List<Object?> playedTags = [];

  /// 置为非零后，playUrl/playLocalFile 时模拟播放器已解析出的媒体时长
  Duration loadedDuration = Duration.zero;

  /// 置为非空后 [playLocalFile] 抛出该异常（模拟本地文件播放失败）
  Object? playLocalError;

  /// 置为非空后 [playUrl] 抛出该异常（模拟网络流播放失败）
  Object? playUrlError;
  Future<void>? pauseBarrier;
  Future<void>? seekBarrier;
  Object? resumeError;

  @override
  Future<void> playUrl(String url, {double speed = 1.0, Object? tag}) async {
    final err = playUrlError;
    if (err != null) throw err;
    playedUrls.add(url);
    playedTags.add(tag);
    currentTag = tag;
    duration = loadedDuration;
    isPlaying = true;
    isInitialized = true;
    currentUrl = url;
  }

  @override
  Future<void> playLocalFile(
    String path, {
    double speed = 1.0,
    Object? tag,
  }) async {
    final err = playLocalError;
    if (err != null) throw err;
    playedLocalFiles.add((path: path, speed: speed));
    playedTags.add(tag);
    currentTag = tag;
    duration = loadedDuration;
    isPlaying = true;
    isInitialized = true;
    currentUrl = path;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    await pauseBarrier;
    isPlaying = false;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    isPlaying = true;
  }

  @override
  Future<bool> resumeWithTag({
    required Object previousTag,
    required Object tag,
  }) async {
    if (!isInitialized || !identical(currentTag, previousTag)) return false;
    if (resumeError != null) throw resumeError!;
    currentTag = tag;
    await resume();
    return true;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> seek(Duration position) async {
    seekCount++;
    await seekBarrier;
    lastSeekPosition = position;
    this.position = position;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    isPlaying = false;
    isInitialized = false;
    currentUrl = null;
    currentTag = null;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    isPlaying = false;
    isInitialized = false;
  }

  /// 模拟当前音频自然播完（纯音频后端完成事件 → onCompleted 回调，
  /// 携带本次装载的归属标识）
  void completePlayback() {
    isPlaying = false;
    onCompleted?.call(currentTag);
  }

  /// 模拟迟到的旧章完成回调（携带旧章归属标识，不改变当前归属）
  void completePlaybackForTag(Object? tag) {
    isPlaying = false;
    onCompleted?.call(tag);
  }

  /// 模拟播放器上报进度（纯音频后端位置回调 → onProgress，
  /// 携带本次装载的归属标识）
  void emitProgress(Duration position, Duration duration) {
    this.position = position;
    this.duration = duration;
    onProgress?.call(position, duration, currentTag);
  }

  /// 模拟迟到的旧章进度回调（携带旧章归属标识，不改变当前归属）
  void emitProgressForTag(Object? tag, Duration position, Duration duration) {
    this.position = position;
    this.duration = duration;
    onProgress?.call(position, duration, tag);
  }
}

/// http.Client 的 mock 实现
class MockHttpClient extends Mock implements http.Client {}

/// http.Response 的 mock 实现
class MockHttpResponse extends Mock implements http.Response {}

/// Book 的 Fake 实现（用于 registerFallbackValue）
class FakeBook extends Fake implements Book {}

/// RssSource 的 Fake 实现
class FakeRssSource extends Fake implements RssSource {}

/// HttpTts 的 Fake 实现（D3 种子导入测试的 any() fallback）
class FakeHttpTts extends Fake implements HttpTts {}

/// BookSource 的 Fake 实现
class FakeBookSource extends Fake implements BookSource {}

/// Bookmark 的 Fake 实现
class FakeBookmark extends Fake implements Bookmark {}

/// ReplaceRule 的 Fake 实现
class FakeReplaceRule extends Fake implements ReplaceRule {}

/// Uri 的 Fake 实现
class FakeUri extends Fake implements Uri {}

/// 注册所有 fallback 值（在 setUpAll 中调用）
void registerFallbacks() {
  registerFallbackValue(const RuleSub());
  registerFallbackValue(const BookHighlight());
  registerFallbackValue(const HighlightRule());
  registerFallbackValue(const WebDavConnection());
  registerFallbackValue(HttpTtsCancellation());
  registerFallbackValue(FakeBook());
  registerFallbackValue(FakeRssSource());
  registerFallbackValue(FakeHttpTts());
  registerFallbackValue(FakeBookSource());
  registerFallbackValue(FakeBookmark());
  registerFallbackValue(FakeReplaceRule());
  registerFallbackValue(const BookGroup());
  registerFallbackValue(FakeUri());
}

/// 旧顶/底栏回归统一挂载当前阅读菜单。
ReaderMenuPanel buildReaderMenu({
  VoidCallback? onAddBookmark,
  VoidCallback? onOpenCatalog,
  VoidCallback? onOpenSettings,
  VoidCallback? onOpenContentSearch,
  VoidCallback? onReadAloud,
}) => ReaderMenuPanel(
  visible: true,
  onBack: () {},
  onAddBookmark: onAddBookmark ?? () {},
  onOpenCatalog: onOpenCatalog ?? () {},
  onOpenSettings: onOpenSettings ?? () {},
  onOpenContentSearch: onOpenContentSearch ?? () {},
  onReadAloud: onReadAloud ?? () {},
  onToggleAutoPage: () {},
  onOpenReplaceRules: () {},
);
