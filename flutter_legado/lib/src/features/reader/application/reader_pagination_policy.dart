import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../domain/models/page_turn_mode.dart';
import '../../../widgets/reader/chapter_layout.dart';
import '../../../widgets/reader/paragraph_config.dart';

/// Widget注入测量值；策略只计算几何、缓存身份和调度，不持context/Ref。— Codex + UI
abstract final class ReaderPaginationPolicy {
  static Size contentSize(Size viewport, EdgeInsets insets) => Size(
    viewport.width - insets.horizontal,
    viewport.height - insets.vertical,
  );

  static bool doublePage(int mode, Size content, PageTurnMode turnMode) =>
      turnMode != PageTurnMode.scroll &&
      switch (mode) {
        1 => true,
        2 => content.width > content.height,
        3 => content.width > content.height || content.width >= 700,
        _ => false,
      };

  static ({double width, double height}) bounds({
    required Size content,
    required EdgeInsets margins,
    required bool doublePage,
    required double headerHeight,
    required double footerHeight,
  }) => (
    width: doublePage
        ? math.min(
            content.width / 2 - margins.left - 8,
            content.width / 2 - margins.right - 8,
          )
        : content.width - margins.horizontal,
    height:
        content.height -
        headerHeight -
        footerHeight -
        margins.top -
        margins.bottom,
  );

  static Object _paragraphGeometry(ParagraphConfig config) => (
    config.fontSize,
    config.lineHeight,
    config.paragraphSpacing,
    config.indent,
    config.indentCount,
    config.letterSpacing,
    config.fontFamily,
    config.fontWeight,
    config.fontStyle,
    config.justify,
    config.useZhLayout,
    config.hangingPunctuation,
    config.textEnvironment?.geometryKey,
  );

  /// 只用于会话内完整布局缓存，不包含配色或段评正数计数。
  static Object chapterCacheKey({
    required String? bookUrl,
    required int chapter,
    required String content,
    required ParagraphConfig config,
    required double width,
    required double height,
    required double firstHeight,
    required int fontRevision,
    required String reviews,
  }) => (
    bookUrl,
    chapter,
    content,
    width,
    height,
    firstHeight,
    _paragraphGeometry(config),
    fontRevision,
    reviews,
  );

  /// 同时需要两侧时按距离选择；等距优先下一章，保持原串行预排规则。
  static int? adjacentChapter({
    required int pageCount,
    required int currentPage,
    required bool doublePage,
    required bool hasBook,
    required bool preloading,
    required bool hasPreviousChapter,
    required bool hasNextChapter,
    required bool previousReady,
    required bool nextReady,
    bool eager = false,
  }) {
    if (pageCount == 0 || !hasBook || preloading) return null;
    final screen = doublePage ? currentPage ~/ 2 : currentPage;
    final screens = doublePage ? (pageCount + 1) ~/ 2 : pageCount;
    final next =
        (eager || screen >= screens - 2) && hasNextChapter && !nextReady;
    final previous =
        (eager || screen <= 1) && hasPreviousChapter && !previousReady;
    if (previous && (!next || screen < screens - 1 - screen)) return -1;
    return next ? 1 : null;
  }

  static String _insetKey(EdgeInsets value) =>
      '${value.top}_${value.bottom}_${value.left}_${value.right}';
}

/// 屏幕尺寸单独记录，保留无效视口只更新尺寸、恢复后重新核对的原行为。
final class ReaderPaginationSignature {
  ReaderPaginationSignature({
    required String? bookUrl,
    required int chapter,
    required String content,
    required ParagraphConfig config,
    required int fontRevision,
    required bool boldText,
    required int textBold,
    required EdgeInsets margins,
    required EdgeInsets insets,
    required String chromeKey,
    required bool doublePage,
    required bool scroll,
    required String reviews,
  }) : _key = (
         bookUrl,
         chapter,
         content,
         ReaderPaginationPolicy._paragraphGeometry(config),
         config.textScaler,
         fontRevision,
         boldText,
         textBold,
         ReaderPaginationPolicy._insetKey(margins),
         ReaderPaginationPolicy._insetKey(insets),
         chromeKey,
         doublePage,
         scroll,
         reviews,
       );
  final Object _key;
  @override
  bool operator ==(Object other) =>
      other is ReaderPaginationSignature && _key == other._key;
  @override
  int get hashCode => _key.hashCode;
}

/// 目标页由布局派生；原文锚点、末页请求和显式页号保持原有优先级。
final class ReaderPaginationTarget {
  const ReaderPaginationTarget({
    required this.requestedPage,
    this.sourceAnchor,
  });
  final int requestedPage;
  final int? sourceAnchor;
  bool get lastPage => requestedPage == -1;

  bool ready(List<PageInfo> pages, {required bool complete}) =>
      pages.isNotEmpty &&
      (complete ||
          (!lastPage &&
              (sourceAnchor != null
                  ? pages.last.sourceEnd > sourceAnchor!
                  : requestedPage < pages.length)));

  bool waiting(List<PageInfo> pages, {required bool complete}) =>
      !complete && !ready(pages, complete: complete);

  int resolve(List<PageInfo> pages) {
    if (pages.isEmpty) return 0;
    if (lastPage) return pages.length - 1;
    final anchor = sourceAnchor;
    return anchor != null
        ? pageIndexForSourceOffset(pages, anchor)
        : requestedPage.clamp(0, pages.length - 1);
  }
}

/// 同章同书且同代次的结果才能发布；不替代底层会话自己的取消协议。
final class ReaderPaginationTask {
  const ReaderPaginationTask({
    required this.bookUrl,
    required this.chapter,
    required this.generation,
  });
  final String? bookUrl;
  final int chapter;
  final int generation;

  bool matches({
    required String? bookUrl,
    required int chapter,
    required int generation,
  }) =>
      this.bookUrl == bookUrl &&
      this.chapter == chapter &&
      this.generation == generation;
}
