import 'package:flutter/widgets.dart';

import 'text_layout_environment.dart';
import 'reader_layout_element.dart';

/// 物理内容区不足以容纳一个完整字形或行时，提示扩大区域，禁止静默裁字。
class ReaderLayoutBoundsException implements Exception {
  final String message;
  const ReaderLayoutBoundsException(this.message);
  @override
  String toString() => message;
}

/// 段末行内操作只占布局空间，不占章节原文长度。
@immutable
class InlineReview {
  final int paragraphId;
  final int reviewKey;
  final int sourceAnchor;
  final int count;
  final Size size;
  final Size compactSize;
  final double baseline;

  const InlineReview({
    required this.paragraphId,
    required this.reviewKey,
    required this.sourceAnchor,
    required this.count,
    required this.size,
    required this.compactSize,
    required this.baseline,
  });
}

@immutable
class InlineReviewLayout {
  final InlineReview element;
  final Offset offset;
  final Size size;
  final bool compact;

  const InlineReviewLayout({
    required this.element,
    required this.offset,
    required this.size,
    this.compact = false,
  });
}

/// 行信息
@immutable
class LineInfo {
  final List<String> words;
  final double width;
  final double height;
  final int startIndex;
  final int endIndex;
  final double? baseline;
  final double textTop;
  final InlineReviewLayout? trailingReview;
  final List<ReaderGlyph> glyphs;

  /// 标题使用独立样式，颜色仍由页面即时提供。— Codex + UI
  final TextStyle? textStyle;

  /// 首行缩进的独立几何宽度，不改变正文和原文偏移。
  final double indentWidth;

  /// 最终绘制字距，分页与正文渲染共用。
  final double? letterSpacing;
  final double spaceExpansion;

  /// 跨页后仍保留原段落末行标记，避免页末续行被当成段末。
  final bool? isParagraphLastLine;

  /// 引号进入缩进区的宽度；正文起点为 indentWidth - hangingWidth。
  final double hangingWidth;

  const LineInfo({
    required this.words,
    required this.width,
    required this.height,
    required this.startIndex,
    required this.endIndex,
    this.baseline,
    this.textTop = 0,
    this.trailingReview,
    this.glyphs = const [],
    this.textStyle,
    this.hangingWidth = 0,
    this.indentWidth = 0,
    this.letterSpacing,
    this.spaceExpansion = 0,
    this.isParagraphLastLine,
  });

  String get displayText => words.join();

  String get selectableText => displayText;

  /// 将显示文本的 UTF-16 偏移转换为章节原文偏移。
  int sourceOffset(int displayOffset) =>
      startIndex + displayOffset.clamp(0, endIndex - startIndex);
}

/// 段落信息
@immutable
class ParagraphInfo {
  final bool isTitle;

  /// 跨有限页拼接滚动布局时恢复行后的自然间隔。— Codex + UI
  final double? continuationSpacingAfter;
  final List<LineInfo> lines;
  final double totalHeight;
  final int startIndex;
  final int endIndex;

  /// 章内 1-based 段落序号（对齐原版 TextLine.paragraphNum / 段评 paraIndex）
  final int chapterParagraphIndex;

  /// 是否为该段落在分页后的最后一片（段末角标只画在此）
  final bool isParagraphEnd;

  /// 分页确定的段前间距，跨页续段与页首均为零。
  final double? spacingBefore;

  const ParagraphInfo({
    required this.lines,
    this.isTitle = false,
    this.continuationSpacingAfter,
    required this.totalHeight,
    required this.startIndex,
    required this.endIndex,
    this.chapterParagraphIndex = 0,
    this.isParagraphEnd = true,
    this.spacingBefore,
  });
}

/// 页面信息
@immutable
class PageInfo {
  final List<ParagraphInfo> paragraphs;
  final double totalHeight;

  /// 所有页面引用同一章节原文，选区从原文取值而非拼接排版字符。
  final String? sourceText;
  final TextLayoutEnvironment? textEnvironment;
  final List<ReaderLayoutElement> elements;

  const PageInfo({
    required this.paragraphs,
    required this.totalHeight,
    this.sourceText,
    this.textEnvironment,
    this.elements = const [],
  });

  int get sourceStart =>
      paragraphs.where((p) => !p.isTitle).firstOrNull?.startIndex ?? 0;
  int get sourceEnd =>
      paragraphs.where((p) => !p.isTitle).lastOrNull?.endIndex ?? 0;
}

/// 原文空白间隙归到其后的正文页，超出末尾的锚点归到末页。
int pageIndexForSourceOffset(List<PageInfo> pages, int sourceOffset) {
  if (pages.isEmpty || sourceOffset <= 0) return 0;
  var low = 0;
  var high = pages.length - 1;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (pages[middle].sourceEnd <= sourceOffset) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

/// 清理显示空白后仍保留章节原文坐标的段落。
@immutable
class SourceParagraph {
  final String text;
  final int startIndex;
  final int endIndex;

  const SourceParagraph(this.text, this.startIndex, this.endIndex);
}
