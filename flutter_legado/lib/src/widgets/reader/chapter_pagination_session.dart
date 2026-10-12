import 'chapter_layout.dart';
import 'line_paginator.dart';

/// 测量留在 Flutter UI 线程，每批处理有限段落并在段落之间让出执行权。
/// 取消后不再调用测量器；单次平台字形测量本身不能中途打断。
class ChapterPaginationSession {
  final List<SourceParagraph> paragraphs;
  final LinePaginator paginator;
  final ParagraphInfo Function(SourceParagraph paragraph, int index) measure;
  int _index = 0;
  bool complete = false;
  bool cancelled = false;

  ChapterPaginationSession({
    required this.paragraphs,
    required this.paginator,
    required this.measure,
  });

  List<PageInfo> get pages => List.unmodifiable(paginator.completedPages);
  int get measuredParagraphs => _index;
  void cancel() => cancelled = true;

  void advance({
    int maxParagraphs = 8,
    Duration budget = const Duration(milliseconds: 8),
  }) {
    if (cancelled || complete) return;
    final watch = Stopwatch()..start();
    var count = 0;
    while (!cancelled && _index < paragraphs.length && count < maxParagraphs) {
      paginator.addParagraph(
        measure(paragraphs[_index], _index + 1),
        _index + 1,
      );
      _index++;
      count++;
      if (watch.elapsed >= budget) break;
    }
    if (!cancelled && _index == paragraphs.length) {
      paginator.finish();
      complete = true;
    }
  }
}

/// 只缓存完整布局；上限保持三章窗口，不缓存旧 Widget 或 TextPainter。
class ChapterLayoutCache {
  final int capacity;
  final Map<Object, List<PageInfo>> _entries = {};
  int hits = 0;
  ChapterLayoutCache({this.capacity = 3});

  List<PageInfo>? get(Object key) {
    final value = _entries.remove(key);
    if (value != null) {
      _entries[key] = value;
      hits++;
    }
    return value;
  }

  void put(Object key, List<PageInfo> pages) {
    _entries.remove(key);
    _entries[key] = List.unmodifiable(pages);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
  int get length => _entries.length;
}
