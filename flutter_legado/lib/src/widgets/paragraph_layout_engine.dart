/// Flutter 文字测量与 Rust 纯计算排版的编排入口。
library;

import 'package:flutter/widgets.dart';

import '../services/reader_layout_service.dart';
import 'reader/chapter_layout.dart';
import 'reader/chapter_document.dart';
import 'reader/chapter_layout_adapter.dart';
import 'reader/chapter_pagination_session.dart';
import 'reader/flutter_text_shaper.dart';
import 'reader/layout_diagnostics.dart';
import 'reader/paragraph_config.dart';
import 'reader/text_layout_environment.dart';
export 'reader/chapter_layout.dart';
export 'reader/chapter_document.dart';
export 'reader/paragraph_config.dart';

class ParagraphLayoutEngine {
  final ParagraphConfig config;
  final ReaderLayoutDiagnostics? diagnostics;
  final ReaderLayoutTransport transport;
  late final TextLayoutEnvironment environment;
  late final FlutterTextShaper shaper;

  ParagraphLayoutEngine({
    required this.config,
    required BuildContext context,
    ReaderLayoutTransport? transport,
    this.diagnostics,
  }) : transport =
           transport ??
           ReaderLayoutTransportScope.maybeOf(context) ??
           const NativeReaderLayoutTransport() {
    environment =
        config.textEnvironment ??
        TextLayoutEnvironment(
          baseStyle: config.baseStyle ?? const TextStyle(),
          textScaler: config.textScaler ?? TextScaler.noScaling,
          direction: TextDirection.ltr,
        );
    shaper = FlutterTextShaper(config, environment, diagnostics);
  }
  int get measurementCount => shaper.measurementCount;

  ChapterPaginationSession startChapter(
    String content,
    double width,
    double height, {
    double? firstPageHeight,
    Map<int, InlineReview> paragraphReviews = const {},
  }) {
    final scroll = height == double.infinity;
    if (!width.isFinite ||
        width < 1 ||
        (!scroll && (!height.isFinite || height < 1))) {
      throw const ReaderLayoutBoundsException('阅读区域太小，请扩大窗口或减小页边距');
    }
    if (!scroll && shaper.height > height) {
      throw const ReaderLayoutBoundsException('阅读区域太矮，请扩大窗口或减小字号');
    }
    final inset = firstPageHeight == null ? 0.0 : height - firstPageHeight;
    if (!scroll && (inset < 0 || shaper.height + inset > height)) {
      throw const ReaderLayoutBoundsException('章节标题后空间不足，请扩大窗口或减小字号');
    }
    final paragraphs = splitChapterParagraphs(content);
    return ChapterPaginationSession(
      paragraphs: paragraphs,
      measure: (paragraph, index) =>
          shaper.measure(paragraph, index, paragraphReviews[index], width),
      bridge: ReaderLayoutSession(
        transport: transport,
        diagnostics: diagnostics,
        config: {
          'chapterIndex': 0,
          'chapterTitle': '',
          'viewportWidthPx': width.floor(),
          'viewportHeightPx': scroll ? 100000000 : height.floor(),
          'paddingLeftPx': 0,
          'paddingTopPx': 0,
          'paddingRightPx': 0,
          'paddingBottomPx': 0,
          'lineHeightPx': shaper.height,
          'lineSpacingMultiplier': config.lineHeight,
          'textBottomJustify': config.textBottomJustify && !scroll,
          'baselineOffsetPx': shaper.baseline,
          'paragraphSpacingPx': config.paragraphSpacing,
          'letterSpacingPx': shaper.spacing,
          'breakMode': config.useZhLayout ? 'chinese' : 'plain',
          'continuousScroll': scroll,
        },
      ),
      adapter: ChapterLayoutAdapter(
        source: content,
        paragraphs: paragraphs,
        environment: environment,
        reviews: paragraphReviews,
        firstPageInset: inset,
      ),
      prefixBlocks: inset > 0
          ? [
              {
                'type': 'rule',
                'colorArgb': 0,
                'widthPx': 0,
                'verticalPaddingPx': inset / 2,
              },
            ]
          : const [],
    );
  }

  Future<List<PageInfo>> paginateChapter(
    String content,
    double width,
    double height, {
    double? firstPageHeight,
    Map<int, InlineReview> paragraphReviews = const {},
  }) async {
    final session = startChapter(
      content,
      width,
      height,
      firstPageHeight: firstPageHeight,
      paragraphReviews: paragraphReviews,
    );
    try {
      while (!session.complete) {
        await session.advance();
      }
      return session.pages;
    } finally {
      session.cancel();
    }
  }
}

// ===== 跨章节连续分页 =====

/// 章节分页信息
///
/// 记录单个章节的索引及其分页数量，用于跨章节全局页索引映射。
@immutable
class ChapterPageInfo {
  /// 章节索引（对应目录中的位置）
  final int chapterIndex;

  /// 该章节的总页数
  final int pageCount;

  const ChapterPageInfo({required this.chapterIndex, required this.pageCount});

  @override
  String toString() =>
      'ChapterPageInfo(chapter: $chapterIndex, pages: $pageCount)';
}

/// 跨章节连续分页器
///
/// 实现全局页索引与 (章节索引, 章内页索引) 的双向映射。
/// 采用链表式存储（非内容拼接），内存高效：
/// - 仅存储每章的页数元数据，不持有章节正文
/// - 支持动态增删章节（预加载/卸载）
/// - 二分查找定位章节，O(log n) 复杂度
class CrossChapterPaginator {
  /// 按章节索引排序的分页信息列表
  final List<ChapterPageInfo> _chapters = [];

  /// 前缀和缓存：_prefixSums[i] = 前 i 章的总页数
  /// _prefixSums[0] = 0, _prefixSums[n] = totalPages
  List<int> _prefixSums = [0];

  /// 缓存是否过期
  bool _dirty = true;

  /// 获取已注册的章节数量
  int get chapterCount => _chapters.length;

  /// 总页数（所有章节页数之和）
  int totalPages() {
    _rebuildPrefixSumsIfNeeded();
    return _prefixSums.isEmpty ? 0 : _prefixSums.last;
  }

  /// 全局页索引 → 所属章节索引
  ///
  /// 使用二分查找在前缀和数组中定位。
  /// 返回 -1 表示无效索引（空列表或越界）。
  int chapterForPage(int globalIndex) {
    if (_chapters.isEmpty || globalIndex < 0) return -1;
    _rebuildPrefixSumsIfNeeded();
    final total = _prefixSums.last;
    if (globalIndex >= total) return -1;

    // 二分查找：找到最后一个 prefixSum <= globalIndex 的位置
    var lo = 0;
    var hi = _chapters.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_prefixSums[mid] <= globalIndex) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return _chapters[lo].chapterIndex;
  }

  /// 全局页索引 → 章内页索引
  ///
  /// 返回 -1 表示无效索引。
  int pageInChapter(int globalIndex) {
    if (_chapters.isEmpty || globalIndex < 0) return -1;
    _rebuildPrefixSumsIfNeeded();
    final total = _prefixSums.last;
    if (globalIndex >= total) return -1;

    final chapterSlot = _findChapterSlot(globalIndex);
    if (chapterSlot < 0) return -1;
    return globalIndex - _prefixSums[chapterSlot];
  }

  /// 章节索引 → 该章第一页的全局页索引
  ///
  /// 返回 -1 表示章节未注册。
  int globalIndexForChapterStart(int chapterIndex) {
    final slot = _findSlotByChapterIndex(chapterIndex);
    if (slot < 0) return -1;
    _rebuildPrefixSumsIfNeeded();
    return _prefixSums[slot];
  }

  /// 章节索引 → 该章最后一页的全局页索引
  ///
  /// 返回 -1 表示章节未注册或页数为 0。
  int globalIndexForChapterEnd(int chapterIndex) {
    final slot = _findSlotByChapterIndex(chapterIndex);
    if (slot < 0) return -1;
    _rebuildPrefixSumsIfNeeded();
    final pageCount = _chapters[slot].pageCount;
    if (pageCount <= 0) return -1;
    return _prefixSums[slot] + pageCount - 1;
  }

  /// 获取指定章节的页数
  ///
  /// 返回 0 表示章节未注册。
  int pageCountForChapter(int chapterIndex) {
    final slot = _findSlotByChapterIndex(chapterIndex);
    if (slot < 0) return 0;
    return _chapters[slot].pageCount;
  }

  /// 添加或更新章节分页信息
  ///
  /// 如果章节已存在则更新页数，否则按章节索引排序插入。
  void addChapter(int chapterIndex, int pageCount) {
    final existingSlot = _findSlotByChapterIndex(chapterIndex);
    if (existingSlot >= 0) {
      // 更新已有章节的页数
      _chapters[existingSlot] = ChapterPageInfo(
        chapterIndex: chapterIndex,
        pageCount: pageCount,
      );
    } else {
      // 按章节索引排序插入
      var insertPos = _chapters.length;
      for (var i = 0; i < _chapters.length; i++) {
        if (_chapters[i].chapterIndex > chapterIndex) {
          insertPos = i;
          break;
        }
      }
      _chapters.insert(
        insertPos,
        ChapterPageInfo(chapterIndex: chapterIndex, pageCount: pageCount),
      );
    }
    _dirty = true;
  }

  /// 移除章节
  ///
  /// 移除后全局页索引自动调整。
  void removeChapter(int chapterIndex) {
    final slot = _findSlotByChapterIndex(chapterIndex);
    if (slot >= 0) {
      _chapters.removeAt(slot);
      _dirty = true;
    }
  }

  /// 清空所有章节
  void clear() {
    _chapters.clear();
    _prefixSums = [0];
    _dirty = false;
  }

  /// 判断全局页索引是否有效
  bool isValidGlobalIndex(int globalIndex) {
    if (globalIndex < 0) return false;
    _rebuildPrefixSumsIfNeeded();
    return _prefixSums.isNotEmpty && globalIndex < _prefixSums.last;
  }

  /// 获取全局页索引对应的完整映射信息
  ///
  /// 返回 null 表示无效索引。
  ({int chapterIndex, int pageIndex})? resolve(int globalIndex) {
    final chapter = chapterForPage(globalIndex);
    if (chapter < 0) return null;
    final page = pageInChapter(globalIndex);
    if (page < 0) return null;
    return (chapterIndex: chapter, pageIndex: page);
  }

  // ===== 内部方法 =====

  /// 重建前缀和缓存
  void _rebuildPrefixSumsIfNeeded() {
    if (!_dirty) return;
    _prefixSums = List<int>.filled(_chapters.length + 1, 0);
    for (var i = 0; i < _chapters.length; i++) {
      _prefixSums[i + 1] = _prefixSums[i] + _chapters[i].pageCount;
    }
    _dirty = false;
  }

  /// 根据全局页索引查找所属章节在 _chapters 列表中的槽位
  int _findChapterSlot(int globalIndex) {
    _rebuildPrefixSumsIfNeeded();
    var lo = 0;
    var hi = _chapters.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_prefixSums[mid] <= globalIndex) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// 根据章节索引查找在 _chapters 列表中的槽位
  ///
  /// 使用二分查找（列表按 chapterIndex 排序）。
  int _findSlotByChapterIndex(int chapterIndex) {
    var lo = 0;
    var hi = _chapters.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final midIndex = _chapters[mid].chapterIndex;
      if (midIndex == chapterIndex) return mid;
      if (midIndex < chapterIndex) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }
}
