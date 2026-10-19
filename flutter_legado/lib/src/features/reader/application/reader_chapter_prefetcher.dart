import 'dart:async';

import '../../../data/services/chapter_content_service.dart';
import '../../../domain/models/download_settings.dart';
import '../../../models/book.dart';
import 'reader_state.dart';

typedef _Target = ({String book, String source, String chapter, int index});

/// 有界正文预取窗口；只调度当前窗口，不取消已进入FFI的请求。— Codex + UI
final class ReaderChapterPrefetcher {
  ReaderChapterPrefetcher(this._content);
  final ChapterContentService _content;
  static const _maxConcurrent = 2;
  final _running = <_Target>{};
  final _finished = <_Target>{};
  List<_Target> _pending = [];
  Set<_Target> _wanted = {};
  bool _disposed = false;

  void plan(ReaderState state, DownloadSettings settings) {
    if (_disposed) return;
    final book = state.currentBook;
    if (book == null ||
        book.origin == BookType.localTag ||
        book.bookType & BookType.local != 0) {
      stop();
      return;
    }
    final targets = <_Target>[];
    void add(int index) {
      if (index < 0 || index >= state.chapters.length) return;
      targets.add((
        book: book.bookUrl,
        source: book.origin,
        chapter: state.chapters[index].url,
        index: index,
      ));
    }

    final next = settings.preDownloadNum;
    final previous = settings.preDownloadNumPrev;
    for (
      var distance = 1;
      distance <= next || distance <= previous;
      distance++
    ) {
      if (distance <= next) add(state.currentChapterIndex + distance);
      if (distance <= previous) add(state.currentChapterIndex - distance);
    }
    _wanted = targets.toSet();
    _finished.removeWhere((target) => !_wanted.contains(target));
    _pending = targets
        .where(
          (target) => !_running.contains(target) && !_finished.contains(target),
        )
        .toList();
    _pump();
  }

  void stop() {
    pause();
    _finished.clear();
  }

  /// 同一章刷新期间暂停新请求，已完成的窗口仍可复用。
  void pause() {
    _pending = [];
    _wanted = {};
  }

  void _pump() {
    while (!_disposed &&
        _running.length < _maxConcurrent &&
        _pending.isNotEmpty) {
      final target = _pending.removeAt(0);
      _running.add(target);
      unawaited(_read(target));
    }
  }

  Future<void> _read(_Target target) async {
    try {
      // Full正文入口复用已有持久缓存，命中时不重新抓取。
      await _content.read(target.book, target.index);
      if (!_disposed && _wanted.contains(target)) _finished.add(target);
    } catch (_) {
      // 辅助请求失败不改变正文状态，也不在当前窗口内循环重试。
    } finally {
      _running.remove(target);
      _pump();
    }
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
