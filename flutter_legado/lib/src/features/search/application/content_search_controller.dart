import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/contracts/reading_repository.dart';
import '../../../domain/contracts/chapter_cache_repository.dart';
import '../../../domain/contracts/search_history_repository.dart';
import '../../../domain/contracts/content_search_service.dart';

enum ContentSearchScope { current, cached, network }

class ContentMatch {
  const ContentMatch({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.hit,
  });
  final int chapterIndex;
  final String chapterTitle;
  final ContentSearchHit hit;
  String get snippet => hit.snippet;
}

/// 不可变结果快照；取消只停止后续调度与发布，不伪称底层请求已取消。— Codex + UI
class ContentSearchState {
  ContentSearchState({
    List<ContentMatch> results = const [],
    List<String> history = const [],
    this.searching = false,
    this.query = '',
    this.scanned = 0,
    this.total = 0,
  }) : results = List.unmodifiable(results),
       history = List.unmodifiable(history);
  final List<ContentMatch> results;
  final List<String> history;
  final bool searching;
  final String query;
  final int scanned, total;
  ContentSearchState copyWith({
    List<ContentMatch>? results,
    List<String>? history,
    bool? searching,
    String? query,
    int? scanned,
    int? total,
  }) => ContentSearchState(
    results: results ?? this.results,
    history: history ?? this.history,
    searching: searching ?? this.searching,
    query: query ?? this.query,
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
  );
}

class ContentSearchController extends ChangeNotifier {
  ContentSearchController({
    required this.bookUrl,
    required this.bookName,
    required this.reading,
    required this.cache,
    required this.history,
    required this.matching,
    required this.log,
  });
  static const maxResults = 200;
  final String bookUrl, bookName;
  final ReadingRepository reading;
  final ChapterCacheRepository cache;
  final SearchHistoryRepository history;
  final ContentSearchService matching;
  final void Function(String, Object, StackTrace) log;
  ContentSearchState _state = ContentSearchState();
  ContentSearchState get state => _state;
  int _generation = 0, _historyGeneration = 0;
  bool _closed = false;
  void _publish(ContentSearchState value) {
    if (_closed) return;
    _state = value;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    final generation = ++_historyGeneration;
    try {
      final values = await history.getSearchHistory(limit: 20);
      if (!_closed && generation == _historyGeneration) {
        _publish(_state.copyWith(history: values.map((e) => e.word).toList()));
      }
    } catch (e, s) {
      if (!_closed) log('读取正文搜索历史', e, s);
    }
  }

  Future<void> clearHistory() async {
    final generation = ++_historyGeneration;
    try {
      await history.clearSearchHistory();
      if (!_closed && generation == _historyGeneration) {
        _publish(_state.copyWith(history: []));
      }
    } catch (e, s) {
      if (!_closed) log('清空正文搜索历史', e, s);
    }
  }

  Future<void> search(
    String raw, {
    required int currentChapterIndex,
    required bool useRegex,
    required bool useReplace,
    required ContentSearchScope scope,
  }) async {
    final query = raw.trim();
    if (query.isEmpty || _closed) return;
    final generation = ++_generation;
    bool current() => !_closed && generation == _generation;
    _publish(
      _state.copyWith(
        query: query,
        searching: true,
        results: [],
        scanned: 0,
        total: 0,
      ),
    );
    unawaited(
      history.addSearchKeyword(query, bookName).catchError((
        Object e,
        StackTrace s,
      ) {
        if (current()) log('保存正文搜索历史', e, s);
      }),
    );
    ContentSearchMatcher? matcher;
    try {
      matcher = await matching.open(query, useRegex: useRegex);
      if (!current() || matcher == null) return;
      final chapters = await reading.getChapters(bookUrl);
      if (!current()) return;
      _publish(_state.copyWith(total: chapters.length));
      Set<String> cached = {};
      if (scope == ContentSearchScope.cached) {
        try {
          cached = (await cache.listCachedChapterUrls(bookUrl)).toSet();
        } catch (e, s) {
          if (current()) log('读取已缓存章节范围', e, s);
        }
      }
      if (!current()) return;
      final results = <ContentMatch>[];
      for (var i = 0; i < chapters.length; i++) {
        if (!current()) return;
        final chapter = chapters[i];
        if (scope == ContentSearchScope.current && i != currentChapterIndex) {
          continue;
        }
        if (scope == ContentSearchScope.cached &&
            i != currentChapterIndex &&
            !cached.contains(chapter.url)) {
          continue;
        }
        try {
          final content = useReplace
              ? await reading.getChapterContent(bookUrl, chapter.index)
              : await reading.getChapterContentRaw(bookUrl, chapter.index);
          if (!current()) return;
          final hits = await matcher.search(content);
          if (!current()) return;
          for (final hit in hits) {
            results.add(
              ContentMatch(
                chapterIndex: chapter.index,
                chapterTitle: chapter.title,
                hit: hit,
              ),
            );
            if (results.length >= maxResults) break;
          }
        } catch (e, s) {
          if (current()) log('搜索章节${chapter.index}', e, s);
        }
        if (!current()) return;
        _publish(_state.copyWith(results: results, scanned: i + 1));
        if (results.length >= maxResults) break;
      }
    } catch (e, s) {
      if (current()) log('正文搜索', e, s);
    } finally {
      matcher?.close();
      if (current()) _publish(_state.copyWith(searching: false));
    }
  }

  void clear() {
    _generation++;
    _publish(
      _state.copyWith(
        query: '',
        results: [],
        searching: false,
        scanned: 0,
        total: 0,
      ),
    );
  }

  void cancel() {
    _generation++;
    _publish(_state.copyWith(searching: false));
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _historyGeneration++;
    super.dispose();
  }
}
