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
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import '../data/bridge/runtime_configuration.dart';
import '../data/bridge/rust_json_decode.dart';
import '../domain/contracts/bookmark_repository.dart';
import '../domain/contracts/read_record_repository.dart';
import '../domain/contracts/http_tts_repository.dart';
import '../domain/contracts/http_tts_synthesizer.dart';

import '../bridge/rust_lib.dart' as bridge;
import '../models/models.dart';
import 'book_api.dart';
import '../data/bridge/rust_api_exception.dart';
export '../data/bridge/rust_api_exception.dart';
import 'platform_bridge_service.dart';

part 'rust_api_decode.part.dart';
part 'rust_api_sources.part.dart';
part 'rust_api_search_rss.part.dart';
part 'rust_api_reader_data.part.dart';
part 'rust_api_discovery_cache.part.dart';
part 'rust_api_media_format.part.dart';
part 'rust_api_sync_tools.part.dart';
part 'rust_api_content_ext.part.dart';

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
        RustApiSearchRss,
        RustApiReaderData,
        RustApiDiscoveryCache,
        RustApiMediaFormat,
        RustApiSyncTools,
        RustApiContentExt
    implements BookApi, ReadingConfigSync, ThemeConfigSync {
  @override
  CloudTtsRepository get cloudTtsRepository => const RustCloudTtsRepository();
  factory RustApi({
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
