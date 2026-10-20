import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../data/services/chapter_content_service.dart';
import '../../../domain/contracts/book_source_repository.dart';
import '../../../domain/contracts/review_service.dart';
import '../../../domain/contracts/download_settings_repository.dart';
import '../../../domain/models/download_settings.dart';
import 'reader_chapter_prefetcher.dart';
import 'reader_state.dart';

typedef _ChapterKey = ({
  String bookUrl,
  String sourceUrl,
  String chapterUrl,
  int index,
});

/// 段评数据绑定原章节，不复制阅读会话的书籍与正文。— Codex + UI
final class ReaderReviewState {
  const ReaderReviewState.empty()
    : counts = const {},
      keys = const {},
      sourceJson = null,
      _chapter = null;

  ReaderReviewState._({
    required Map<int, int> counts,
    required Map<int, String> keys,
    required this.sourceJson,
    required this._chapter,
  }) : counts = Map.unmodifiable(counts),
       keys = Map.unmodifiable(keys);

  final Map<int, int> counts;
  final Map<int, String> keys;
  final String? sourceJson;
  final _ChapterKey? _chapter;

  bool belongsTo(ReaderState state) =>
      _chapter != null && _chapter == _keyFor(state);
}

_ChapterKey? _keyFor(ReaderState state) {
  final book = state.currentBook;
  final chapter = state.currentChapter;
  if (book == null || chapter == null) return null;
  return (
    bookUrl: book.bookUrl,
    sourceUrl: book.origin,
    chapterUrl: chapter.url,
    index: state.currentChapterIndex,
  );
}

/// 观察章节加载完成，协调缓存预取和段评摘要；不持有页面或Ref。— Codex + UI
final class ReaderChapterCoordinator extends ValueNotifier<ReaderReviewState> {
  ReaderChapterCoordinator({
    required ChapterContentService content,
    required DownloadSettingsRepository settings,
    required this._sources,
    required this._reviews,
  }) : _prefetcher = ReaderChapterPrefetcher(content),
       super(const ReaderReviewState.empty()) {
    unawaited(_loadSettings(settings));
  }

  final ReaderChapterPrefetcher _prefetcher;
  StreamSubscription<DownloadSettings>? _settingsSubscription;
  DownloadSettings? _settings;
  ReaderState? _ready;
  final BookSourceRepository _sources;
  final ReviewService _reviews;
  bool _disposed = false;
  int _reviewGeneration = 0;
  _ChapterKey? _observed;
  _ChapterKey? _lastReady;

  void observe(ReaderState state) {
    if (_disposed) return;
    final key = _keyFor(state);
    if (key != _observed) {
      _observed = key;
      _lastReady = null;
      _ready = null;
      _prefetcher.stop();
      _reviewGeneration++;
      if (value.sourceJson != null) value = const ReaderReviewState.empty();
    }
    if (state.isLoading || state.error != null || key == null) {
      _ready = null;
      _prefetcher.pause();
      return;
    }
    final wasReady = _ready != null;
    _ready = state;
    if (_settings case final settings? when !wasReady) {
      _prefetcher.plan(state, settings);
    }
    if (key == _lastReady) return;
    _lastReady = key;
    unawaited(_loadReviews(state, key, ++_reviewGeneration));
  }

  Future<void> _loadSettings(DownloadSettingsRepository repository) async {
    try {
      await repository.load();
      if (_disposed) return;
      _settingsSubscription = repository.watch().listen((settings) {
        if (_disposed) return;
        _settings = settings;
        if (_ready case final state?) _prefetcher.plan(state, settings);
      });
    } catch (error) {
      // 配置读取失败时不按默认值发出网络请求，当前阅读继续。
      debugPrint('预下载设置读取失败：$error');
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _reviewGeneration;

  Future<void> _loadReviews(
    ReaderState state,
    _ChapterKey key,
    int generation,
  ) async {
    final book = state.currentBook!;
    if (book.origin.isEmpty) return;
    try {
      final sources = await _sources.getBookSources();
      if (!_isCurrent(generation)) return;
      final source = sources
          .where((source) => source.bookSourceUrl == book.origin)
          .firstOrNull;
      if (source == null) return;
      final rule = source.ruleReview;
      final enabled =
          (source.mainJs ?? '').trim().isNotEmpty ||
          (rule != null &&
              rule.enabled &&
              (rule.reviewSummaryUrl ?? '').trim().isNotEmpty);
      if (!enabled) return;
      final chapter = state.currentChapter;
      final sourceJson = jsonEncode(source.toJson());
      final summary = await _reviews.reviewGetSummary(sourceJson, {
        'chapterUrl': chapter?.url ?? '',
        'book': book.toJson(),
        if (chapter != null) 'chapter': chapter.toJson(),
      });
      if (!_isCurrent(generation)) return;
      value = ReaderReviewState._(
        counts: summary.counts,
        keys: summary.keys,
        sourceJson: sourceJson,
        chapter: key,
      );
    } catch (_) {
      if (_isCurrent(generation)) value = const ReaderReviewState.empty();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reviewGeneration++;
    _prefetcher.dispose();
    unawaited(_settingsSubscription?.cancel());
    super.dispose();
  }
}
