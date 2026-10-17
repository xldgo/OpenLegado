import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../data/services/chapter_content_service.dart';
import '../../../domain/contracts/book_source_repository.dart';
import '../../../domain/contracts/review_service.dart';
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
    required this._content,
    required this._sources,
    required this._reviews,
  }) : super(const ReaderReviewState.empty());

  final ChapterContentService _content;
  final BookSourceRepository _sources;
  final ReviewService _reviews;
  bool _wasLoading = false;
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
      _reviewGeneration++;
      if (value.sourceJson != null) value = const ReaderReviewState.empty();
    }
    final completed = _wasLoading && !state.isLoading && state.error == null;
    _wasLoading = state.isLoading;
    if (!completed || key == null || key == _lastReady) return;
    _lastReady = key;
    _prefetch(state);
    unawaited(_loadReviews(state, key, ++_reviewGeneration));
  }

  void _prefetch(ReaderState state) {
    final book = state.currentBook!;
    final index = state.currentChapterIndex;
    for (var distance = 1; distance <= 2; distance++) {
      final next = index + distance;
      final previous = index - distance;
      if (next < state.chapters.length) {
        unawaited(_prefetchChapter(book.bookUrl, next));
      }
      if (previous >= 0) {
        unawaited(_prefetchChapter(book.bookUrl, previous));
      }
    }
  }

  Future<void> _prefetchChapter(String bookUrl, int index) async {
    try {
      await _content.read(bookUrl, index);
    } catch (_) {
      // 暖缓存失败不影响当前章节，不发布错误或伪造正文。
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
    super.dispose();
  }
}
