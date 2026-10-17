import 'dart:convert';
import 'dart:typed_data';

import '../../../data/services/comic_image_decode_cache.dart';
import '../../../domain/contracts/book_image_repository.dart';
import '../../../domain/contracts/local_book_service.dart';
import '../../../domain/contracts/reading_repository.dart';
import '../../../models/models.dart';
import '../../../utils/comic_image_utils.dart';

/// 管理本次阅读的预载窗口，复用正式加载的仓储及缓存。— Codex + UI
class ComicPreloadService {
  ComicPreloadService({
    required this._images,
    required this._localBooks,
    required this._reading,
  });

  final BookImageRepository _images;
  final LocalBookService _localBooks;
  final ReadingRepository _reading;
  final Set<int> _indices = {};
  int _generation = 0;
  bool _disposed = false;

  void reset() {
    _generation++;
    _indices.clear();
  }

  Future<void> preloadAdjacent({
    required String bookUrl,
    required int chapterIndex,
    required int chapterCount,
  }) async {
    if (_disposed) return;
    final generation = _generation;
    for (final index in [
      if (chapterIndex + 1 < chapterCount) chapterIndex + 1,
      if (chapterIndex > 0) chapterIndex - 1,
    ]) {
      try {
        await _reading.getChapterContentFull(bookUrl, index);
      } catch (_) {
        // 预载失败不阻断当前阅读，正式进入章节时再试。
      }
      if (_disposed || generation != _generation) return;
    }
  }

  Future<void> preloadRange({
    required List<String> urls,
    required int start,
    required int end,
    required String bookUrl,
    required Book? book,
    required BookSource? source,
    required Future<void> Function(String url) precacheNetwork,
  }) async {
    if (_disposed || urls.isEmpty) return;
    final jobs = <Future<void>>[];
    for (
      var i = start.clamp(0, urls.length - 1);
      i <= end.clamp(0, urls.length - 1);
      i++
    ) {
      if (!_indices.add(i)) continue;
      jobs.add(
        _preloadImage(
          url: urls[i],
          bookUrl: bookUrl,
          book: book,
          source: source,
          precacheNetwork: precacheNetwork,
        ),
      );
    }
    await Future.wait(jobs);
  }

  Future<void> _preloadImage({
    required String url,
    required String bookUrl,
    required Book? book,
    required BookSource? source,
    required Future<void> Function(String url) precacheNetwork,
  }) async {
    try {
      if (url.startsWith('cbz://')) {
        if (book == null) return;
        await ComicImageDecodeCache.preloadCbz(
          localBooks: _localBooks,
          path: book.bookUrl,
          cacheKey: bookUrl,
          entry: url,
        );
      } else if (source != null) {
        if (book == null) return;
        final disk = await _images.getImageCache(bookUrl, url);
        if (disk != null && disk.isNotEmpty && looksLikeImageBytes(disk)) {
          ComicImageDecodeCache.put(
            book.origin,
            url,
            disk is Uint8List ? disk : Uint8List.fromList(disk),
          );
          return;
        }
        await ComicImageDecodeCache.preload(
          images: _images,
          url: url,
          sourceJson: jsonEncode(source.toJson()),
          bookSourceUrl: book.origin,
        );
        final bytes = ComicImageDecodeCache.get(book.origin, url);
        if (bytes != null) {
          await _images.saveImageCache(
            bookUrl: bookUrl,
            url: url,
            bytes: bytes,
          );
        }
      } else if (!isCompositeImageUrl(url)) {
        await precacheNetwork(url);
      }
    } catch (_) {
      // 图片预载及磁盘回写失败保持静默，正式渲染仍可重试。
    }
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
