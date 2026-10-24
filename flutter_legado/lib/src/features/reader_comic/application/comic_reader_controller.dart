import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/contracts/book_source_repository.dart';
import '../../../domain/contracts/bookshelf_repository.dart';
import '../../../domain/contracts/reading_repository.dart';
import '../../../models/models.dart';
import '../../../utils/error_message.dart';
import 'comic_chapter_parser.dart';
import 'comic_preload_service.dart';
import 'comic_reader_state.dart';

/// 漫画开书、章节导航及持久化，不持有Ref或界面控制器。— Codex + UI
class ComicReaderController extends ChangeNotifier {
  ComicReaderController({
    required String bookUrl,
    required this._bookshelf,
    required this._reading,
    required this._sources,
    required this._preloader,
  }) : _state = ComicReaderState(bookUrl: bookUrl);

  final BookshelfRepository _bookshelf;
  final ReadingRepository _reading;
  final BookSourceRepository _sources;
  final ComicPreloadService _preloader;
  ComicReaderState _state;
  ComicReaderState get state => _state;
  int _generation = 0;
  bool _disposed = false;
  bool _preloadImages = false;
  bool _autoOffline = false;
  int _preloadNext = 0, _preloadPrevious = 0;

  void configurePreload({
    required bool images,
    required int next,
    required int previous,
    bool autoOffline = false,
  }) {
    if (_disposed) return;
    final imagesChanged = images != _preloadImages;
    final chaptersChanged =
        next != _preloadNext ||
        previous != _preloadPrevious ||
        autoOffline != _autoOffline;
    _preloadImages = images;
    _preloadNext = next;
    _preloadPrevious = previous;
    _autoOffline = autoOffline;
    if (imagesChanged) _preloader.resetImages();
    if (chaptersChanged) {
      _preloader.resetChapters();
      _preloadChapters();
    }
  }

  void _preloadChapters() {
    final snapshot = _state;
    if (_disposed || snapshot.loading || snapshot.imageUrls.isEmpty) return;
    unawaited(
      _preloader.preloadAdjacent(
        bookUrl: snapshot.bookUrl,
        chapterIndex: snapshot.chapterIndex,
        chapterCount: snapshot.chapters.length,
        nextCount: _preloadNext,
        previousCount: _preloadPrevious,
        autoOffline: _autoOffline,
      ),
    );
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _publish(ComicReaderState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> open({String? bookUrl}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _preloader.reset();
    if (bookUrl != null && bookUrl != _state.bookUrl) {
      _publish(
        ComicReaderState(
          bookUrl: bookUrl,
          navigationId: _state.navigationId + 1,
        ),
      );
    } else {
      _publish(
        _state.copyWith(loading: true, clearError: true, chapterError: false),
      );
    }
    final url = _state.bookUrl;
    try {
      final book = await _bookshelf.getBook(url);
      if (!_current(generation)) return;
      if (book == null) {
        _publish(_state.copyWith(loading: false, error: '未找到书籍信息'));
        return;
      }
      _publish(_state.copyWith(book: book));
      var chapters = await _reading.getChapters(url);
      if (!_current(generation)) return;
      if (chapters.isEmpty &&
          book.origin.isNotEmpty &&
          !book.origin.startsWith(BookType.localTag) &&
          !book.origin.startsWith(BookType.webDavTag)) {
        chapters = await _reading.refreshToc(url, book.origin);
        if (!_current(generation)) return;
      }
      if (chapters.isEmpty) {
        _publish(
          _state.copyWith(chapters: chapters, loading: false, error: '暂无章节'),
        );
        return;
      }
      final index =
          book.durChapterIndex >= 0 && book.durChapterIndex < chapters.length
          ? book.durChapterIndex
          : 0;
      _publish(
        _state.copyWith(
          chapters: chapters,
          chapterIndex: index,
          initialPage: book.durChapterPos > 0 ? book.durChapterPos : 0,
          navigationId: _state.navigationId + 1,
          imageUrls: const [],
        ),
      );
      await _loadChapter(generation);
    } catch (error) {
      if (!_current(generation)) return;
      _publish(_state.copyWith(loading: false, error: errorMessage(error)));
    }
  }

  Future<void> refreshChapter() async {
    if (_disposed || _state.chapters.isEmpty) return;
    await _loadChapter(++_generation);
  }

  Future<void> _loadChapter(int generation) async {
    if (!_current(generation)) return;
    final snapshot = _state;
    final book = snapshot.book;
    if (book == null || snapshot.chapters.isEmpty) return;
    final chapter = snapshot.chapters[snapshot.chapterIndex];
    _preloader.reset();
    _publish(
      snapshot.copyWith(
        loading: true,
        clearError: true,
        chapterError: false,
        imageUrls: const [],
      ),
    );
    try {
      var source = snapshot.source;
      var headers = snapshot.imageHeaders;
      if ((headers.isEmpty || source == null) && book.origin.isNotEmpty) {
        final sources = await _sources.getBookSources();
        if (!_current(generation)) return;
        for (final candidate in sources) {
          if (candidate.bookSourceUrl == book.origin) {
            source = candidate;
            if (candidate.header?.isNotEmpty ?? false) {
              headers = parseComicImageHeaders(candidate.header!);
            }
            break;
          }
        }
      }
      final content = chapter.url.isNotEmpty
          ? await _reading.fetchChapterContent(
              snapshot.bookUrl,
              chapter.url,
              book.origin,
            )
          : await _reading.getChapterContent(
              snapshot.bookUrl,
              snapshot.chapterIndex,
            );
      if (!_current(generation)) return;
      final urls = parseComicChapterImages(content, chapter);
      final missingImages = urls.isEmpty && !chapter.isVolume;
      _publish(
        _state.copyWith(
          source: source,
          imageHeaders: headers,
          imageUrls: urls,
          loading: false,
          error: missingImages ? '正文没有图片' : null,
          clearError: !missingImages,
          chapterError: missingImages,
        ),
      );
      if (_current(generation)) _preloadChapters();
    } catch (error) {
      if (!_current(generation)) return;
      _publish(
        _state.copyWith(
          loading: false,
          chapterError: true,
          error: errorMessage(error),
        ),
      );
    }
  }

  Future<void> goToChapter(int index, {required int currentPage}) async {
    if (_disposed || index < 0 || index >= _state.chapters.length) return;
    final generation = ++_generation;
    await saveProgress(currentPage);
    if (!_current(generation)) return;
    _publish(
      _state.copyWith(
        chapterIndex: index,
        initialPage: 0,
        navigationId: _state.navigationId + 1,
        loading: true,
        imageUrls: const [],
        clearError: true,
        chapterError: false,
      ),
    );
    await _loadChapter(generation);
    if (_current(generation)) await saveProgress(0);
  }

  Future<void> saveProgress(int page) async {
    final snapshot = _state;
    if (snapshot.book == null || snapshot.chapters.isEmpty) return;
    final maximum = snapshot.imageUrls.isEmpty
        ? 0
        : snapshot.imageUrls.length - 1;
    try {
      await _reading.updateReadingProgress(
        bookUrl: snapshot.bookUrl,
        chapterIndex: snapshot.chapterIndex,
        chapterPos: page.clamp(0, maximum),
      );
    } catch (_) {
      // 保存失败沿用原静默策略，不阻断阅读。
    }
  }

  Future<bool> updateReadConfigField(String key, int? value) async {
    if (_disposed) return false;
    final url = _state.bookUrl;
    try {
      final fresh = await _bookshelf.getBook(url);
      if (fresh == null || _disposed || _state.bookUrl != url) return false;
      final config = Map<String, dynamic>.from(
        fresh.readConfig?.toJson() ?? const {},
      );
      if (value == null) {
        config.remove(key);
      } else {
        config[key] = value;
      }
      final updated = fresh.copyWith(
        readConfig: config.isEmpty ? null : ReadConfig.fromJson(config),
      );
      await _bookshelf.updateBook(updated);
      if (_disposed || _state.bookUrl != url) return false;
      _publish(_state.copyWith(book: updated));
      return true;
    } catch (_) {
      return false;
    }
  }

  void preloadImages(
    int visibleIndex, {
    required Future<void> Function(String) precacheNetwork,
  }) {
    if (_disposed || !_preloadImages || _state.loading) return;
    final snapshot = _state;
    // CBZ已有本地原件，只保留正式可见图片的读取/缓存，不把整本ZIP预展开进内存。
    if (snapshot.imageUrls.isNotEmpty &&
        snapshot.imageUrls.first.startsWith('cbz://')) {
      return;
    }
    unawaited(
      _preloader.preloadRange(
        urls: snapshot.imageUrls,
        start: 0,
        end: snapshot.imageUrls.length - 1,
        visibleIndex: visibleIndex,
        bookUrl: snapshot.bookUrl,
        book: snapshot.book,
        source: snapshot.source,
        precacheNetwork: precacheNetwork,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _preloader.dispose();
    super.dispose();
  }
}
