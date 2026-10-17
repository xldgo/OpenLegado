import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/contracts/audio_cache_repository.dart';
import '../../../domain/contracts/cache_download_service.dart';
import '../../../domain/contracts/chapter_cache_repository.dart';
import '../../../models/models.dart';
import '../../../services/audio_cache_events.dart';

/// 目录观察用快照，不代替下载服务或缓存仓储。— Codex + UI
class TocCacheState {
  TocCacheState({
    Set<String> urls = const {},
    Map<String, String> wordCounts = const {},
    Set<int> downloading = const {},
    Set<int> failed = const {},
    Set<int> audio = const {},
  }) : urls = Set.unmodifiable(urls),
       wordCounts = Map.unmodifiable(wordCounts),
       downloading = Set.unmodifiable(downloading),
       failed = Set.unmodifiable(failed),
       audio = Set.unmodifiable(audio);

  final Set<String> urls;
  final Map<String, String> wordCounts;
  final Set<int> downloading;
  final Set<int> failed;
  final Set<int> audio;

  bool sameAs(TocCacheState other) =>
      setEquals(urls, other.urls) &&
      mapEquals(wordCounts, other.wordCounts) &&
      setEquals(downloading, other.downloading) &&
      setEquals(failed, other.failed) &&
      setEquals(audio, other.audio);
}

/// 随目录路由启停的只读观察，统一初始、轮询及音频事件刷新。— Codex + UI
class TocCacheController extends ChangeNotifier {
  TocCacheController({
    required this._readBook,
    required this._chapters,
    required this._downloads,
    required this._audio,
    required this._events,
  });

  final Book Function() _readBook;
  final ChapterCacheRepository _chapters;
  final CacheDownloadService _downloads;
  final AudioCacheRepository _audio;
  final Stream<AudioCacheChanged> _events;
  TocCacheState _state = TocCacheState();
  TocCacheState get state => _state;
  Timer? _timer;
  StreamSubscription<AudioCacheChanged>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _refreshing;

  bool _isLocal(Book book) =>
      book.origin == BookType.localTag ||
      book.origin.startsWith(BookType.webDavTag);
  bool _isAudio(Book book) => (book.bookType & BookType.audio) != 0;

  void start() {
    if (_disposed || _timer != null || _isLocal(_readBook())) return;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(refresh()),
    );
    _subscription = _events.listen((event) {
      final book = _readBook();
      if (event.bookUrl == book.bookUrl && _isAudio(book) && !_isLocal(book)) {
        unawaited(refresh());
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _generation++;
    _refreshing = null;
  }

  void _publish(TocCacheState next) {
    if (_state.sameAs(next)) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadInitial() => _request(initial: true);
  Future<void> refresh() => _request(initial: false);

  Future<void> _request({required bool initial}) {
    if (_disposed || _isLocal(_readBook())) return Future.value();
    final generation = _generation;
    return _refreshing ??= _query(initial: initial).whenComplete(() {
      if (generation == _generation) _refreshing = null;
    });
  }

  Future<void> refreshUrls() async {
    if (_disposed || _isLocal(_readBook())) return;
    final generation = _generation;
    try {
      final urls = await _chapters.listCachedChapterUrls(_readBook().bookUrl);
      if (_disposed || generation != _generation) return;
      _publish(
        TocCacheState(
          urls: urls.toSet(),
          wordCounts: _state.wordCounts,
          downloading: _state.downloading,
          failed: _state.failed,
          audio: _state.audio,
        ),
      );
    } catch (_) {
      // 查询失败保留当前状态，不影响目录展示。
    }
  }

  Future<void> _query({required bool initial}) async {
    if (_disposed) return;
    final book = _readBook();
    if (_isLocal(book)) return;
    final generation = _generation;
    bool current() => !_disposed && generation == _generation;
    final previous = initial ? TocCacheState() : _state;
    var urls = previous.urls;
    var wordCounts = previous.wordCounts;
    try {
      if (initial) {
        urls = (await _chapters.listCachedChapterUrls(book.bookUrl)).toSet();
      } else {
        wordCounts = await _chapters.listCachedChapters(book.bookUrl);
        urls = wordCounts.keys.toSet();
      }
    } catch (_) {
      // 轮询主查询失败整轮保留；初始加载允许独立查询其他状态。
      if (!initial) return;
    }
    if (!current()) return;
    var downloading = previous.downloading;
    try {
      downloading = (await _downloads.listDownloadingChapters(book.bookUrl))
          .toSet();
    } catch (_) {}
    if (!current()) return;
    var failed = previous.failed;
    try {
      failed = (await _downloads.listFailedChapters(book.bookUrl)).toSet();
    } catch (_) {}
    if (!current()) return;
    var audio = previous.audio;
    if (_isAudio(book)) {
      try {
        audio = (await _audio.audioCacheList(bookUrl: book.bookUrl)).toSet();
      } catch (_) {}
    }
    if (!current()) return;
    _publish(
      TocCacheState(
        urls: urls,
        wordCounts: wordCounts,
        downloading: downloading,
        failed: failed,
        audio: audio,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
