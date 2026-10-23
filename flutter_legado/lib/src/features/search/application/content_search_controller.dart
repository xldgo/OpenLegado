import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/contracts/search_history_repository.dart';
import '../../../domain/contracts/content_search_service.dart';

export '../../../domain/contracts/content_search_service.dart'
    show ContentSearchScope;

class ContentMatch {
  const ContentMatch({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.hit,
  });
  final int chapterIndex;
  final String chapterTitle;
  final ContentSearchHit hit;
}

/// 不可变界面快照；章节调度、匹配与取消由原生服务拥有。— Codex + UI
class ContentSearchState {
  ContentSearchState({
    List<ContentMatch> results = const [],
    List<String> history = const [],
    this.searching = false,
    this.query = '',
    this.scanned = 0,
    this.total = 0,
    this.limitReached = false,
  }) : results = List.unmodifiable(results),
       history = List.unmodifiable(history);
  final List<ContentMatch> results;
  final List<String> history;
  final bool searching;
  final String query;
  final int scanned, total;
  final bool limitReached;
  ContentSearchState copyWith({
    List<ContentMatch>? results,
    List<String>? history,
    bool? searching,
    String? query,
    int? scanned,
    int? total,
    bool? limitReached,
  }) => ContentSearchState(
    results: results ?? this.results,
    history: history ?? this.history,
    searching: searching ?? this.searching,
    query: query ?? this.query,
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
    limitReached: limitReached ?? this.limitReached,
  );
}

class ContentSearchController extends ChangeNotifier {
  ContentSearchController({
    required this.bookUrl,
    required this.bookName,
    required this.history,
    required this.matching,
    required this.log,
  });
  final String bookUrl, bookName;
  final SearchHistoryRepository history;
  final ContentSearchService matching;
  final void Function(String, Object, StackTrace) log;
  ContentSearchState _state = ContentSearchState();
  ContentSearchState get state => _state;
  int _generation = 0, _historyGeneration = 0;
  bool _closed = false;
  StreamSubscription<ContentSearchBatch>? _subscription;
  Completer<void>? _searchDone;

  void _cancelActive() {
    final sub = _subscription;
    final done = _searchDone;
    _subscription = null;
    _searchDone = null;
    if (done != null && !done.isCompleted) done.complete();
    if (sub != null) {
      unawaited(
        sub.cancel().catchError((Object e, StackTrace s) {
          if (!_closed) log('取消正文搜索', e, s);
        }),
      );
    }
  }

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
    _cancelActive();
    bool current() => !_closed && generation == _generation;
    _publish(
      _state.copyWith(
        query: query,
        searching: true,
        results: [],
        scanned: 0,
        total: 0,
        limitReached: false,
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
    final done = Completer<void>();
    _searchDone = done;
    void finish() {
      if (!done.isCompleted) done.complete();
      if (current()) {
        _subscription = null;
        _searchDone = null;
        _publish(_state.copyWith(searching: false));
      }
    }

    try {
      _subscription = matching
          .search(
            bookUrl: bookUrl,
            query: query,
            useRegex: useRegex,
            useReplace: useReplace,
            scope: scope,
            currentChapterIndex: currentChapterIndex,
          )
          .listen(
            (batch) {
              if (!current()) return;
              final error = batch.error;
              if (error != null) {
                log(
                  '搜索章节${batch.chapterIndex}',
                  StateError(error),
                  StackTrace.current,
                );
              }
              final chapterIndex = batch.chapterIndex;
              _publish(
                _state.copyWith(
                  results: [
                    ..._state.results,
                    if (chapterIndex != null)
                      for (final hit in batch.hits)
                        ContentMatch(
                          chapterIndex: chapterIndex,
                          chapterTitle: batch.chapterTitle,
                          hit: hit,
                        ),
                  ],
                  scanned: batch.scanned,
                  total: batch.total,
                  limitReached: batch.limitReached,
                ),
              );
            },
            onError: (Object e, StackTrace s) {
              if (current()) log('正文搜索', e, s);
              finish();
            },
            onDone: finish,
            cancelOnError: true,
          );
    } catch (e, s) {
      if (current()) log('正文搜索', e, s);
      finish();
    }
    await done.future;
  }

  void clear() {
    _generation++;
    _cancelActive();
    _publish(
      _state.copyWith(
        query: '',
        results: [],
        searching: false,
        scanned: 0,
        total: 0,
        limitReached: false,
      ),
    );
  }

  void cancel() {
    _generation++;
    _cancelActive();
    _publish(_state.copyWith(searching: false));
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _cancelActive();
    _historyGeneration++;
    super.dispose();
  }
}
