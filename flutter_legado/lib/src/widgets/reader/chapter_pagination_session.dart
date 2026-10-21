import 'dart:async';
import 'dart:collection';

import '../../services/reader_layout_service.dart';
import 'chapter_layout.dart';
import 'chapter_layout_adapter.dart';
import 'reader_layout_element.dart';

/// 平台测量分批让出 UI 线程；纯计算异步执行，取消后拒绝迟到结果。
class ChapterPaginationSession {
  final List<SourceParagraph> paragraphs;
  final Map<String, Object?> Function(SourceParagraph, int) measure;
  final ReaderLayoutSession bridge;
  final ChapterLayoutAdapter adapter;
  final List<Map<String, Object?>> prefixBlocks;
  final List<PageInfo> _pages = [];
  late final List<PageInfo> _pageView = UnmodifiableListView(_pages);
  int _index = 0;
  int _prefixIndex = 0;
  bool _advancing = false;
  bool complete = false;
  bool cancelled = false;
  ChapterPaginationSession({
    required this.paragraphs,
    required this.measure,
    required this.bridge,
    required this.adapter,
    this.prefixBlocks = const [],
  });

  /// 只追加会话数据的只读视图，避免每批输出再次复制全部页面引用。
  List<PageInfo> get pages => _pageView;
  int get measuredParagraphs => _index;
  void cancel() {
    if (cancelled || complete) return;
    cancelled = true;
    unawaited(bridge.cancel().catchError((Object _) {}));
  }

  Future<void> advance({
    int maxParagraphs = 8,
    Duration budget = const Duration(milliseconds: 8),
  }) async {
    if (cancelled || complete) return;
    if (_advancing) throw StateError('不能并发推进同一个阅读布局会话');
    if (maxParagraphs < 1 || maxParagraphs > 31) {
      throw ArgumentError('每批段落数应在 1–31 之间');
    }
    _advancing = true;
    try {
      final watch = Stopwatch()..start();
      final blocks = <Map<String, Object?>>[];
      while (_prefixIndex < prefixBlocks.length && blocks.length < 32) {
        blocks.add(prefixBlocks[_prefixIndex++]);
      }
      var count = 0;
      while (!cancelled &&
          _index < paragraphs.length &&
          blocks.length < 32 &&
          count < maxParagraphs) {
        blocks.add(measure(paragraphs[_index], _index + 1));
        _index++;
        count++;
        if (watch.elapsed >= budget) break;
      }
      if (cancelled) return;
      if (blocks.isNotEmpty) {
        final reply = await bridge.push(blocks);
        if (cancelled) return;
        _pages.addAll(reply.pages.map(adapter.convert));
      }
      if (_index == paragraphs.length && _prefixIndex == prefixBlocks.length) {
        final reply = await bridge.finish();
        if (cancelled) return;
        _pages.addAll(reply.pages.map(adapter.convert));
        complete = true;
      }
    } on ReaderLayoutCancelled {
      if (!cancelled) rethrow;
    } catch (_) {
      cancel();
      rethrow;
    } finally {
      _advancing = false;
    }
  }
}

/// 只缓存完整布局；三章窗口与估算字节预算共同约束，不缓存 Widget 或 TextPainter。
class ChapterLayoutCache {
  final int capacity;
  final int byteBudget;
  final Map<Object, ({List<PageInfo> pages, int bytes})> _entries = {};
  int retainedBytes = 0;
  int hits = 0;
  ChapterLayoutCache({this.capacity = 3, this.byteBudget = 16 * 1024 * 1024}) {
    if (capacity < 1 || byteBudget < 1) {
      throw ArgumentError('阅读布局缓存容量和预算必须为正数');
    }
  }

  List<PageInfo>? get(Object key) {
    final value = _entries.remove(key);
    if (value != null) {
      _entries[key] = value;
      hits++;
    }
    return value?.pages;
  }

  void put(Object key, List<PageInfo> pages) {
    final previous = _entries.remove(key);
    retainedBytes -= previous?.bytes ?? 0;
    final bytes = estimateBytes(pages);
    // 超大章节仍可阅读，但不让它挤掉全部相邻章节缓存。
    if (bytes > byteBudget) return;
    _entries[key] = (pages: List.unmodifiable(pages), bytes: bytes);
    retainedBytes += bytes;
    while (_entries.length > capacity || retainedBytes > byteBudget) {
      retainedBytes -= _entries.remove(_entries.keys.first)!.bytes;
    }
  }

  void clear() {
    _entries.clear();
    retainedBytes = 0;
  }

  int get length => _entries.length;

  /// 计算缓存容量预算；共享原文、批次缓冲按对象身份只计一次，不宣称为实测内存。
  static int estimateBytes(List<PageInfo> pages) {
    final shared = HashSet<Object>.identity();
    var result = pages.length * 8 + 64;
    for (final page in pages) {
      final source = page.sourceText;
      if (source != null && shared.add(source)) {
        result += source.length * 2 + 32;
      }
      result += 128 + page.paragraphs.length * 64;
      final elements = page.elements;
      if (elements is ReaderLayoutElementList) {
        result += elements.data.estimatedBytes;
        if (shared.add(elements.data.columns)) {
          result += elements.data.columns.estimatedBytes;
        }
      } else {
        result += elements.length * 128;
      }
      for (final paragraph in page.paragraphs) {
        result += paragraph.lines.length * 192;
        for (final line in paragraph.lines) {
          result += line.glyphs.length * 4;
          final style = line.textStyle;
          if (style != null && shared.add(style)) result += 256;
        }
      }
    }
    return result;
  }
}
