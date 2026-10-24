import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../../../data/services/comic_image_decode_cache.dart';
import '../../../domain/contracts/book_image_repository.dart';
import '../../../domain/contracts/reading_repository.dart';
import '../../../models/models.dart';
import '../../../utils/comic_image_utils.dart';

typedef _ImageJob = ({int index, int generation, Future<void> Function() run});

/// 当前章图片最多两个后台任务；视口变化只重排等待项。
/// 单次领域请求不能中断，代次用于停止旧队列的后续工作。— Codex + UI
class ComicPreloadService {
  ComicPreloadService({required this._images, required this._reading});

  final BookImageRepository _images;
  final ReadingRepository _reading;
  final Set<int> _indices = {};
  final _pendingImages = Queue<_ImageJob>();
  int _workers = 0;
  Completer<void>? _idle;
  Future<void> _chapterTail = Future.value();
  int _generation = 0;
  int _chapterGeneration = 0;
  bool _disposed = false;
  bool _current(int generation) => !_disposed && generation == _generation;

  void reset() {
    resetImages();
    resetChapters();
  }

  void resetChapters() => _chapterGeneration++;

  void resetImages() {
    _generation++;
    _indices.clear();
    _pendingImages.clear();
    final idle = _idle;
    if (idle != null && !idle.isCompleted) idle.complete();
    _idle = null;
  }

  Future<void> preloadAdjacent({
    required String bookUrl,
    required int chapterIndex,
    required int chapterCount,
    required int nextCount,
    required int previousCount,
  }) {
    if (_disposed) return Future.value();
    final generation = _chapterGeneration;
    // 旧请求结束后再启动新窗口，避免配置变更堆叠章节请求。
    return _chapterTail = _chapterTail.then((_) async {
      for (final index in [
        for (
          var step = 1;
          step <= nextCount && chapterIndex + step < chapterCount;
          step++
        )
          chapterIndex + step,
        for (
          var step = 1;
          step <= previousCount && chapterIndex - step >= 0;
          step++
        )
          chapterIndex - step,
      ]) {
        if (_disposed || generation != _chapterGeneration) return;
        try {
          await _reading.getChapterContentFull(bookUrl, index);
        } catch (_) {
          // 预取失败不阻断当前阅读，也不阻断同窗口的后续章节。
        }
      }
    });
  }

  Future<void> preloadRange({
    required List<String> urls,
    required int start,
    required int end,
    int? visibleIndex,
    required String bookUrl,
    required Book? book,
    required BookSource? source,
    required Future<void> Function(String url) precacheNetwork,
  }) {
    if (_disposed || urls.isEmpty) return Future.value();
    final generation = _generation;
    final order = [
      for (
        var i = start.clamp(0, urls.length - 1);
        i <= end.clamp(0, urls.length - 1);
        i++
      )
        if (!_indices.contains(i)) i,
    ];
    if (visibleIndex != null) {
      // 参考版同距离优先向后；章节内图片始终在计划中，滚动只改变优先级。
      final anchor = visibleIndex.clamp(0, urls.length - 1);
      order.sort((a, b) {
        final distance = (a - anchor).abs().compareTo((b - anchor).abs());
        return distance != 0 ? distance : b.compareTo(a);
      });
    }
    final sourceJson = source == null ? null : jsonEncode(source.toJson());
    _pendingImages
      ..clear()
      ..addAll(
        order.map(
          (index) => (
            index: index,
            generation: generation,
            run: () => _preloadImage(
              generation: generation,
              url: urls[index],
              bookUrl: bookUrl,
              book: book,
              sourceJson: sourceJson,
              precacheNetwork: precacheNetwork,
            ),
          ),
        ),
      );
    if (_idle == null || _idle!.isCompleted) _idle = Completer<void>();
    final idle = _idle!;
    _pumpImages();
    return idle.future;
  }

  void _pumpImages() {
    while (!_disposed && _workers < 2 && _pendingImages.isNotEmpty) {
      final job = _pendingImages.removeFirst();
      if (!_current(job.generation) || !_indices.add(job.index)) {
        continue;
      }
      _workers++;
      unawaited(
        job.run().whenComplete(() {
          _workers--;
          _pumpImages();
        }),
      );
    }
    if (_workers == 0 && _pendingImages.isEmpty) {
      final idle = _idle;
      if (idle != null && !idle.isCompleted) idle.complete();
    }
  }

  Future<void> _preloadImage({
    required int generation,
    required String url,
    required String bookUrl,
    required Book? book,
    required String? sourceJson,
    required Future<void> Function(String url) precacheNetwork,
  }) async {
    try {
      if (!_current(generation)) return;
      if (sourceJson != null) {
        if (book == null) return;
        final disk = await _images.getImageCache(bookUrl, url);
        if (!_current(generation)) return;
        if (disk != null && disk.isNotEmpty && looksLikeImageBytes(disk)) {
          return;
        }
        var bytes = ComicImageDecodeCache.get(book.origin, url);
        if (bytes == null) {
          bytes = await _images.fetchImageWithDecode(url, sourceJson);
          if (!_current(generation)) return;
          if (!looksLikeImageBytes(bytes)) return;
        }
        await _images.saveImageCache(bookUrl: bookUrl, url: url, bytes: bytes);
      } else if (!isCompositeImageUrl(url)) {
        await precacheNetwork(url);
      }
    } catch (_) {
      // 同窗口不循环重试，正式图片加载及显式重试仍沿用原路径。
    }
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
