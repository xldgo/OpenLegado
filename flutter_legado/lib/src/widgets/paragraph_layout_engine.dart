/// 段落布局引擎
///
/// 参考 MD3 ReaderPaginator 与 ChineseLineBreaker 的测量、断行和分页契约。
/// 实现核心功能:
/// - 段落分页算法
/// - 中文避头尾规则
/// - 两端对齐排版
/// - 行高计算和字体度量
/// - 字符宽度缓存（移植自 TextMeasure.kt）
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'reader/chinese_line_breaker.dart';
import 'reader/text_layout_environment.dart';
import 'reader/chapter_layout.dart';
import 'reader/line_paginator.dart';
import 'reader/text_break_rules.dart';
import 'reader/line_text_span.dart';
import 'reader/chapter_pagination_session.dart';
export 'reader/chapter_layout.dart';

/// 中文标点悬挂规则
///
/// 移植自 HangingPunctuationRule.kt
class ChinesePunctuationRule {
  /// 不能出现在行首的标点
  static const Set<String> beginningPunctuation = TextBreakRules.closing;
  static const Set<String> endingPunctuation = TextBreakRules.opening;

  /// 检查字符是否为行首标点
  static bool isBeginningPunctuation(String char) =>
      beginningPunctuation.contains(char);

  /// 检查字符是否为行末标点
  static bool isEndingPunctuation(String char) =>
      endingPunctuation.contains(char);

  /// 获取合适的行首替代字符
  static String getFirstCharOnLine(String line) {
    if (line.isEmpty) return '';

    final firstChar = line[0];
    if (!isBeginningPunctuation(firstChar)) {
      return line; // 第一个字符可以放在行首
    }

    // 找到第一个非行首标点的位置
    for (int i = 0; i < line.length; i++) {
      if (!isBeginningPunctuation(line[i])) {
        return line.substring(i);
      }
    }
    return line;
  }

  /// 获取合适的行末替代字符
  static String getLastCharOnLine(String line) {
    if (line.isEmpty) return '';

    final lastChar = line[line.length - 1];
    if (!isEndingPunctuation(lastChar)) {
      return line; // 最后一个字符可以放在行末
    }

    // 找到最后一个非行末标点的位置
    for (int i = line.length - 1; i >= 0; i--) {
      if (!isEndingPunctuation(line[i])) {
        return line.substring(0, i + 1);
      }
    }
    return line;
  }

  /// 开启段首悬挂时允许移入缩进区的起始引号。
  static const Set<String> hangingChars = {
    '"',
    "'",
    '“',
    '‘',
    '「',
    '『',
    '﹁',
    '﹃',
  };
}

/// 段落样式配置
@immutable
class ParagraphConfig {
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double indent;
  final bool justify;
  final Color backgroundColor;
  final Color textColor;

  // [UI-fix v2.0.2 | 2026-08-06] 字距与字体接入排版配置（阅读配置面板
  // 字距调节/字体选择；测量与渲染同参，保证分页一致性） — Qoder
  final double letterSpacing;
  final String? fontFamily;

  // [UI-fix v2.0.4 | 2026-08-08] 界面面板对齐原版 ReadStyleDialog：
  // 缩进字符数档位（0-3，对标原版 tvTextIndent "　".repeat(index)）与
  // 文字字重（textBold 映射 FontWeight，测量与渲染同参避免分页偏差） — Qoder
  final int indentCount;
  final FontWeight? fontWeight;

  // [C3 斜体 | Qoder UI] 文字斜体（参考版行内面板「斜体」开关；与 fontWeight
  // 同样注入测量与渲染两侧，保持测量/渲染同源同参）
  final FontStyle? fontStyle;

  /// 沿用阅读设置开关名称；开启时使用中文断行器，关闭时按簇宽断行。
  final bool useZhLayout;

  // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂开关（对标原版
  // hangingPunctuation：段首引号悬挂进缩进区，默认 false 对齐原版）— Reasonix
  final bool hangingPunctuation;

  // [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 渲染同参测量：渲染侧 Text 继承
  // DefaultTextStyle（主题字体回退链）并应用 MediaQuery 文字缩放，测量侧
  // TextPainter 此前两者皆缺 → 系统字体缩放/主题字体下测量偏窄 → 行尾吞字。
  // 由分页调用点注入（引擎不依赖 context，测试可空缺=不缩放不合并）— Qoder
  final TextStyle? baseStyle;
  final TextScaler? textScaler;
  final TextLayoutEnvironment? textEnvironment;

  const ParagraphConfig({
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 8.0,
    this.indent = 0.0,
    this.justify = true,
    // [A-4 | 2026-09-20 用户裁决] 原死默认 Colors.white/Colors.black（调用方
    // 恒以 state 派生色覆写，默认值从未被生产路径依赖）改为必填：漏传颜色
    // 直接编译错误，杜绝隐性主题回退（DARK_THEME 台账 C3 项闭环）。
    required this.backgroundColor,
    required this.textColor,
    this.letterSpacing = 0.0,
    this.fontFamily,
    this.indentCount = 2,
    this.fontWeight,
    this.fontStyle,
    this.useZhLayout = true,
    this.hangingPunctuation = false,
    this.baseStyle,
    this.textScaler,
    this.textEnvironment,
  });

  ParagraphConfig copyWith({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? indent,
    bool? justify,
    Color? backgroundColor,
    Color? textColor,
    double? letterSpacing,
    String? fontFamily,
    int? indentCount,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    bool? useZhLayout,
    bool? hangingPunctuation,
    TextStyle? baseStyle,
    TextScaler? textScaler,
    TextLayoutEnvironment? textEnvironment,
  }) {
    return ParagraphConfig(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      indent: indent ?? this.indent,
      justify: justify ?? this.justify,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      indentCount: indentCount ?? this.indentCount,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      useZhLayout: useZhLayout ?? this.useZhLayout,
      hangingPunctuation: hangingPunctuation ?? this.hangingPunctuation,
      baseStyle: baseStyle ?? this.baseStyle,
      textScaler: textScaler ?? this.textScaler,
      textEnvironment: textEnvironment ?? this.textEnvironment,
    );
  }
}

/// 每个非空逻辑行为一段；原始换行和空白继续保存在章节原文中。
List<SourceParagraph> splitChapterParagraphs(String content) {
  final result = <SourceParagraph>[];
  var start = 0;
  void append(int end) {
    final raw = content.substring(start, end);
    final text = raw.trim();
    if (text.isEmpty) return;
    final leading = raw.length - raw.trimLeft().length;
    final sourceStart = start + leading;
    result.add(SourceParagraph(text, sourceStart, sourceStart + text.length));
  }

  for (final match in RegExp(r'\r\n|\r|\n').allMatches(content)) {
    append(match.start);
    start = match.end;
  }
  append(content.length);
  return result;
}

/// 字符宽度缓存
///
/// 移植自 TextMeasure.kt 的三级缓存策略：
/// - ASCII 字符使用定长数组（128 个槽位）
/// - CJK 统一汉字（U+4E00-U+9FA5）使用通用宽度
/// - 其他 Unicode 字符使用 Map 缓存
class CharWidthCache {
  /// ASCII 字符宽度缓存（对应 Kotlin asciiWidths: FloatArray(128)）
  final List<double> _asciiWidths = List<double>.filled(128, -1.0);

  /// 其他 Unicode 字符宽度缓存（对应 Kotlin codePointWidths: SparseArray）
  final Map<int, double> _codePointWidths = {};

  /// 中文通用字符宽度（对应 Kotlin chineseCommonWidth）
  double chineseCommonWidth = 0.0;

  /// 缓存命中次数（性能统计）
  int hitCount = 0;

  /// 缓存未命中次数（性能统计）
  int missCount = 0;

  /// 查询字符宽度缓存
  ///
  /// 对应 Kotlin measureCodePoint(codePoint: Int): Float
  /// 返回 -1.0 表示未缓存
  double measureCodePoint(int codePoint) {
    if (codePoint < 128) {
      final w = _asciiWidths[codePoint];
      if (w >= 0) hitCount++;
      return w;
    }
    // 中文 Unicode 范围 U+4E00 - U+9FA5（对应 Kotlin 19968..40869）
    if (codePoint >= 19968 && codePoint <= 40869) {
      if (chineseCommonWidth > 0) {
        hitCount++;
        return chineseCommonWidth;
      }
      return -1.0;
    }
    final cached = _codePointWidths[codePoint];
    if (cached != null) {
      hitCount++;
      return cached;
    }
    return -1.0;
  }

  /// 写入字符宽度缓存
  void putCodePoint(int codePoint, double width) {
    if (codePoint < 128) {
      _asciiWidths[codePoint] = width;
    } else {
      _codePointWidths[codePoint] = width;
    }
  }

  /// 清除所有缓存（对应 Kotlin invalidate()）
  void invalidate() {
    _asciiWidths.fillRange(0, 128, -1.0);
    _codePointWidths.clear();
    chineseCommonWidth = 0.0;
    hitCount = 0;
    missCount = 0;
  }

  /// 缓存大小（已缓存的非 ASCII 字符数量）
  int get size => _codePointWidths.length;
}

/// 段落布局引擎
///
/// 核心排版逻辑，负责将文本分段、分行、分页
class ParagraphLayoutEngine {
  final ParagraphConfig config;
  final BuildContext context;
  late final TextLayoutEnvironment _environment =
      config.textEnvironment ??
      TextLayoutEnvironment(
        baseStyle: config.baseStyle ?? const TextStyle(),
        textScaler: config.textScaler ?? TextScaler.noScaling,
        direction: TextDirection.ltr,
      );

  /// 字符宽度缓存（移植自 TextMeasure.kt 三级缓存）
  final CharWidthCache _charWidthCache = CharWidthCache();

  ParagraphLayoutEngine({required this.config, required this.context});
  int measurementCount = 0;
  final Map<(String, double, double), double> _widthCache = {};

  ChapterPaginationSession startChapter(
    String content,
    double width,
    double height, {
    double? firstPageHeight,
    Map<int, InlineReview> paragraphReviews = const {},
  }) => ChapterPaginationSession(
    paragraphs: splitChapterParagraphs(content),
    paginator: LinePaginator(
      sourceText: content,
      environment: _environment,
      pageHeight: height,
      firstPageHeight: firstPageHeight,
      paragraphSpacing: config.paragraphSpacing,
    ),
    measure: (paragraph, index) =>
        _layoutParagraph(paragraph, width, review: paragraphReviews[index]),
  );

  double _lineWidth(String text, double spacing, {double spaceExpansion = 0}) {
    final key = (text, spacing, spaceExpansion);
    final cached = _widthCache[key];
    if (cached != null) return cached;
    final painter = _measureLine(text, spacing, spaceExpansion: spaceExpansion);
    final width = painter.width;
    painter.dispose();
    if (_widthCache.length >= 512) _widthCache.remove(_widthCache.keys.first);
    _widthCache[key] = width;
    return width;
  }

  /// 获取字符宽度缓存（供测试使用）
  CharWidthCache get charWidthCache => _charWidthCache;

  /// 将整章内容排版并分页，返回所有页面
  ///
  /// 最终行按顺序填入页面；普通段落可以跨页，尾页继续容纳后续段落。
  /// 段距与真实段末由分页结果保存，绘制层不重新决定分页。
  ///
  /// [UI-fix v2.0.4 | 2026-08-08] 新增 [firstPageHeight]：首页可用高度
  /// （渲染侧首页预留章节标题块，容量小于后续页；不传则与
  /// pageHeight 一致），修复满页正文首页底部 RenderFlex 溢出 — Qoder
  List<PageInfo> paginateChapter(
    String content,
    double availableWidth,
    double pageHeight, {
    double? firstPageHeight,
    Map<int, InlineReview> paragraphReviews = const {},
  }) {
    final session = startChapter(
      content,
      availableWidth,
      pageHeight,
      firstPageHeight: firstPageHeight,
      paragraphReviews: paragraphReviews,
    );
    while (!session.complete) {
      session.advance();
    }
    return session.pages;
  }

  /// 排版单个段落
  ///
  /// 移植自 TextChapterLayout.kt setTypeText：
  /// - 首行缩进（对应 Kotlin paragraphIndent + indentCharWidth）
  /// - 行高计算（对应 Kotlin textHeight * lineSpacingExtra）
  ParagraphInfo _layoutParagraph(
    SourceParagraph paragraph,
    double availableWidth, {
    InlineReview? review,
  }) {
    final trimmedPara = paragraph.text;
    if (trimmedPara.isEmpty) {
      return const ParagraphInfo(
        lines: [],
        totalHeight: 0,
        startIndex: 0,
        endIndex: 0,
      );
    }

    // 按 MD3 的 firstLineWidth / indentWidth 契约把缩进作为几何输入。
    // 正文只含原文，悬挂最多让出起始引号自身的宽度。
    final firstIndent = config.indent > 0 && config.indentCount > 0
        ? _measurePrefixWidth('\u3000' * config.indentCount)
        : 0.0;
    final firstCluster = trimmedPara.characters.first;
    final hangingWidth =
        config.hangingPunctuation &&
            firstIndent > 0 &&
            _environment.direction == TextDirection.ltr &&
            ChinesePunctuationRule.hangingChars.contains(firstCluster)
        ? math.min(firstIndent, _measurePrefixWidth(firstCluster))
        : 0.0;
    if (availableWidth - firstIndent + hangingWidth <= 0) {
      throw const ReaderLayoutBoundsException('阅读区域太窄，请扩大窗口或减小字号');
    }
    final layoutLines = _breakLines(
      trimmedPara,
      availableWidth,
      firstLineIndent: firstIndent,
      hangingWidth: hangingWidth,
    );
    final reviewSize = review == null
        ? null
        : _placeReviewTail(layoutLines, availableWidth, review);

    // 计算总高度（对应 Kotlin durY += textHeight * lineSpacingExtra）
    final lines = <LineInfo>[];
    for (var i = 0; i < layoutLines.length; i++) {
      final line = layoutLines[i];
      final last = i == layoutLines.length - 1;
      final (spacing, spaceExpansion) = _justifiedSpacing(
        line,
        availableWidth,
        !last,
      );
      final metrics = _measureLine(
        line.displayText,
        spacing,
        spaceExpansion: spaceExpansion,
      );
      final textLeft = line.indentWidth - line.hangingWidth;
      if (metrics.width + textLeft > availableWidth + 0.001) {
        metrics.dispose();
        throw const ReaderLayoutBoundsException('阅读区域太窄，请扩大窗口或减小字号');
      }
      final textBaseline = metrics.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      final rowBaseline = last && review != null
          ? math.max(textBaseline, review.baseline)
          : textBaseline;
      final textTop = rowBaseline - textBaseline;
      final reviewTop = last && review != null
          ? rowBaseline - review.baseline
          : 0.0;
      lines.add(
        LineInfo(
          words: line.words,
          width: metrics.width + textLeft,
          height: last && reviewSize != null
              ? math.max(
                  textTop + metrics.height,
                  reviewTop + reviewSize.height,
                )
              : metrics.height,
          startIndex: paragraph.startIndex + line.startIndex,
          endIndex: paragraph.startIndex + line.endIndex,
          indentWidth: line.indentWidth,
          hangingWidth: line.hangingWidth,
          letterSpacing: spacing,
          spaceExpansion: spaceExpansion,
          baseline: rowBaseline,
          textTop: textTop,
          trailingReview: last && review != null && reviewSize != null
              ? InlineReviewLayout(
                  element: review,
                  offset: Offset(textLeft + metrics.width, reviewTop),
                  size: reviewSize,
                  compact: reviewSize != review.size,
                )
              : null,
          isParagraphLastLine: last,
        ),
      );
      metrics.dispose();
    }
    final totalHeight = lines.fold<double>(
      0,
      (height, line) => height + line.height,
    );

    return ParagraphInfo(
      lines: lines,
      totalHeight: totalHeight,
      startIndex: paragraph.startIndex,
      endIndex: paragraph.endIndex,
    );
  }

  double _measurePrefixWidth(String prefix) {
    return _lineWidth(prefix, config.letterSpacing);
  }

  /// 只回退末行的合法断点，使正文尾部和角标作为同一行落位。
  Size _placeReviewTail(
    List<LineInfo> lines,
    double width,
    InlineReview review,
  ) {
    final last = lines.last;
    final map = TextClusterMap(last.displayText);
    double measure(String text) {
      return _lineWidth(text, config.letterSpacing);
    }

    for (final slot in [review.size, review.compactSize]) {
      if (measure(last.displayText) +
              last.indentWidth -
              last.hangingWidth +
              slot.width <=
          width + 0.001) {
        return slot;
      }
      for (var cut = map.clusters.length - 1; cut > 0; cut--) {
        final before = map.clusters[cut - 1];
        final after = map.clusters[cut];
        if (TextBreakRules.forbidden(before, after) ||
            TextBreakRules.insideWord(before, after)) {
          continue;
        }
        final offset = map.sourceOffsets[cut];
        final suffix = last.displayText.substring(offset);
        if (measure(suffix) + slot.width > width + 0.001) continue;
        lines.removeLast();
        lines.add(
          LineInfo(
            words: map.clusters.sublist(0, cut),
            width: 0,
            height: 0,
            startIndex: last.startIndex,
            endIndex: last.startIndex + offset,
            hangingWidth: last.hangingWidth,
            indentWidth: last.indentWidth,
          ),
        );
        lines.add(
          LineInfo(
            words: map.clusters.sublist(cut),
            width: 0,
            height: 0,
            startIndex: last.startIndex + offset,
            endIndex: last.endIndex,
          ),
        );
        return slot;
      }
    }
    // 单词连同紧凑角标也超宽时，才允许按字形簇拆开超长尾部。
    for (var cut = map.clusters.length - 1; cut > 0; cut--) {
      if (TextBreakRules.forbidden(map.clusters[cut - 1], map.clusters[cut])) {
        continue;
      }
      final offset = map.sourceOffsets[cut];
      final tailWidth = measure(last.displayText.substring(offset));
      if (tailWidth >= width) continue;
      lines.removeLast();
      lines.add(
        LineInfo(
          words: map.clusters.sublist(0, cut),
          width: 0,
          height: 0,
          startIndex: last.startIndex,
          endIndex: last.startIndex + offset,
          hangingWidth: last.hangingWidth,
          indentWidth: last.indentWidth,
        ),
      );
      lines.add(
        LineInfo(
          words: map.clusters.sublist(cut),
          width: 0,
          height: 0,
          startIndex: last.startIndex + offset,
          endIndex: last.endIndex,
        ),
      );
      return Size(
        math.min(review.compactSize.width, width - tailWidth),
        review.compactSize.height,
      );
    }
    // 极窄窗口保留正文，不制造独立角标行；图标缩到实际剩余空间。
    // 若文字自身已占满，明确省去无法容纳的操作，后续扩大窗口可恢复。
    return Size(
      math.max(
        0,
        width -
            last.indentWidth -
            measure(last.displayText) +
            last.hangingWidth,
      ),
      review.compactSize.height,
    );
  }

  /// 分行算法：平台簇宽进入独立中文断行器，最终行再核对真实塑形宽度。
  ///
  /// 移植自 TextChapterLayout.kt 第 940-948 行：
  /// 1. 测量每个字符宽度（整段同源测量，见 [_measureCharWidths]）
  /// 2. 使用 ChineseLineBreaker 进行中文标点感知断行（useZhLayout=true）
  ///    或朴素按宽断行（useZhLayout=false）
  /// 3. 行宽安全网：超宽行把行尾字符下移（见 [_guardLineOverflow]）
  ///
  /// [UI-fix v2.0.5 | 2026-08-10] `hangingWidth` > 0 时首行可用宽上限
  /// 增加该宽度（段首标点悬挂）— Reasonix
  List<LineInfo> _breakLines(
    String text,
    double availableWidth, {
    double hangingWidth = 0,
    double firstLineIndent = 0,
  }) {
    if (text.isEmpty) return [];

    // 测量每个字符的宽度（对应 Kotlin textPaint.getTextWidthsCompat）
    final widthsArray = _measureCharWidths(text, availableWidth);

    // 步骤2：拆分为字符列表 + 宽度列表（对应 Kotlin measureTextSplit）
    final words = text.characters.toList();
    var offset = 0;
    final widths = words.map((word) {
      final width = widthsArray
          .sublist(offset, offset + word.length)
          .fold<double>(0, (sum, value) => sum + value);
      offset += word.length;
      return width;
    }).toList();

    if (words.isEmpty) return [];

    // [UI-fix v2.0.5 | 2026-08-10] useZhLayout=false：朴素按宽断行
    //（无中文避头尾，仅按宽度与字形簇断行）— Reasonix
    final lines = config.useZhLayout
        ? _breakChinese(
            words,
            widths,
            availableWidth,
            hangingWidth,
            firstLineIndent,
          )
        : _breakPlain(
            words,
            widths,
            availableWidth,
            hangingWidth,
            firstLineIndent,
          );

    // 上游允许少量标点超宽；本项目不压缩字形，必须按整行塑形重新核对。
    return _guardLineOverflow(
      text,
      widthsArray,
      lines,
      availableWidth,
      hangingWidth: hangingWidth,
      firstLineIndent: firstLineIndent,
    );
  }

  /// 朴素按宽断行（useZhLayout=false，不等同于 Android StaticLayout）
  List<LineInfo> _breakPlain(
    List<String> words,
    List<double> widths,
    double availableWidth,
    double hangingWidth,
    double firstLineIndent,
  ) {
    final plainLines = <LineInfo>[];
    final textHeight = config.fontSize * config.lineHeight;
    final offsets = TextClusterMap(words.join()).sourceOffsets;
    var lineStartIdx = 0;
    var lineWidth = 0.0;
    void flushLine(int endIdx) {
      final lineWords = words.sublist(lineStartIdx, endIdx);
      final startOffset = offsets[lineStartIdx];
      final endOffset = offsets[endIdx];
      plainLines.add(
        LineInfo(
          words: lineWords,
          width: lineWidth,
          height: textHeight,
          startIndex: startOffset,
          endIndex: endOffset,
          // 悬挂仅作用于首行（行起点索引 0）
          hangingWidth: lineStartIdx == 0 ? hangingWidth : 0,
          indentWidth: lineStartIdx == 0 ? firstLineIndent : 0,
        ),
      );
    }

    for (var i = 0; i < words.length; i++) {
      final w = widths[i];
      final limit = lineStartIdx == 0
          ? availableWidth - firstLineIndent + hangingWidth
          : availableWidth;
      if (i > lineStartIdx && lineWidth + w > limit) {
        flushLine(i);
        lineStartIdx = i;
        lineWidth = 0.0;
      }
      lineWidth += w;
    }
    if (lineStartIdx < words.length) {
      flushLine(words.length);
    }
    return plainLines;
  }

  /// MD3 ChineseLineBreaker 的纯断行核心，输入 Flutter 已测量的簇宽。
  List<LineInfo> _breakChinese(
    List<String> words,
    List<double> widths,
    double availableWidth,
    double hangingWidth,
    double firstLineIndent,
  ) {
    // 中文字符参考宽度（对应 Kotlin cnCharWidthCache）
    final cnCharWidth = _measureSingleChar('我');

    final layout = ChineseLineBreaker(
      clusters: words,
      widths: widths,
      width: availableWidth,
      firstLineWidth: availableWidth - firstLineIndent + hangingWidth,
      ideographWidth: cnCharWidth,
    );

    // 根据断行结果构建 LineInfo 列表
    final lines = <LineInfo>[];
    final textHeight = config.fontSize * config.lineHeight;

    for (var lineIndex = 0; lineIndex < layout.lineWidths.length; lineIndex++) {
      final lineStartIdx = layout.clusterStarts[lineIndex];
      final lineEndIdx = layout.clusterStarts[lineIndex + 1];

      // 提取当前行的字符
      final lineWords = words.sublist(
        lineStartIdx.clamp(0, words.length),
        lineEndIdx.clamp(0, words.length),
      );
      final lineWidth = layout.lineWidths[lineIndex];

      // 计算原始文本中的起止索引
      final startOffset = layout.sourceStarts[lineIndex];
      final endOffset = layout.sourceStarts[lineIndex + 1];

      lines.add(
        LineInfo(
          words: lineWords,
          width: lineWidth,
          height: textHeight,
          startIndex: startOffset,
          endIndex: endOffset,
          // 悬挂仅作用于首行
          hangingWidth: lineIndex == 0 ? hangingWidth : 0,
          indentWidth: lineIndex == 0 ? firstLineIndent : 0,
        ),
      );
    }

    return lines;
  }

  /// 按渲染同源的整行塑形校验宽度，避免把独立簇宽之和当成最终行宽。
  /// 超宽时回退合法簇边界，溢出文字进入下一行，不使用裁剪掩盖问题。
  List<LineInfo> _guardLineOverflow(
    String text,
    List<double> widths,
    List<LineInfo> lines,
    double availableWidth, {
    double hangingWidth = 0,
    double firstLineIndent = 0,
  }) {
    if (lines.isEmpty) return lines;
    final clusterMap = TextClusterMap(text);
    final boundaries = clusterMap.sourceOffsets;
    final guarded = <LineInfo>[];
    var carried = -1;
    int fitEnd(int start, int end, double limit) {
      final first = clusterMap.clusterIndex(start);
      var last = clusterMap.clusterIndex(end);
      while (last > first + 1) {
        final fits =
            _lineWidth(
              text.substring(start, boundaries[last]),
              config.letterSpacing,
            ) <=
            limit + 0.001;
        if (fits) break;
        last--;
      }
      if (last < clusterMap.clusters.length &&
          TextBreakRules.insideWord(
            clusterMap.clusters[last - 1],
            clusterMap.clusters[last],
          )) {
        var wordStart = last;
        while (wordStart > first &&
            TextBreakRules.insideWord(
              clusterMap.clusters[wordStart - 1],
              clusterMap.clusters[wordStart],
            )) {
          wordStart--;
        }
        if (wordStart > first) last = wordStart;
      }
      while (last > first + 1 &&
          last < clusterMap.clusters.length &&
          TextBreakRules.forbidden(
            clusterMap.clusters[last - 1],
            clusterMap.clusters[last],
          )) {
        last--;
      }
      return boundaries[last];
    }

    for (var i = 0; i < lines.length; i++) {
      final start = carried >= 0 ? carried : lines[i].startIndex;
      final end = lines[i].endIndex;
      if (start >= end) continue;
      final limit =
          availableWidth +
          (guarded.isEmpty ? hangingWidth - firstLineIndent : 0);
      final fitted = fitEnd(start, end, limit);
      guarded.add(
        _buildGuardedLine(
          text,
          widths,
          start,
          fitted,
          config.fontSize * config.lineHeight,
          hangingWidth: guarded.isEmpty ? hangingWidth : 0,
          indentWidth: guarded.isEmpty ? firstLineIndent : 0,
        ),
      );
      carried = fitted < end ? fitted : -1;
    }
    while (carried >= 0 && carried < text.length) {
      final fitted = fitEnd(carried, text.length, availableWidth);
      guarded.add(
        _buildGuardedLine(
          text,
          widths,
          carried,
          fitted,
          config.fontSize * config.lineHeight,
        ),
      );
      carried = fitted < text.length ? fitted : -1;
    }
    return guarded;
  }

  /// 按文本偏移区间构建行信息（安全网重排后的行，宽度用实测盒宽之和）
  LineInfo _buildGuardedLine(
    String text,
    List<double> widths,
    int start,
    int end,
    double textHeight, {
    double hangingWidth = 0,
    double indentWidth = 0,
  }) {
    final lineWords = text.substring(start, end).characters.toList();
    var w = 0.0;
    for (var i = start; i < end; i++) {
      w += widths[i];
    }
    return LineInfo(
      words: lineWords,
      width: w,
      height: textHeight,
      startIndex: start,
      endIndex: end,
      hangingWidth: hangingWidth,
      indentWidth: indentWidth,
    );
  }

  /// 使用最终绘制样式测量整行，文字缩放和字体回退参与高度与宽度。
  TextPainter _measureLine(
    String text,
    double letterSpacing, {
    double spaceExpansion = 0,
  }) {
    measurementCount++;
    final painter = TextPainter(
      text: readerLineSpan(
        text,
        _environment.baseStyle.merge(
          TextStyle(
            fontSize: config.fontSize,
            height: config.lineHeight,
            color: config.textColor,
            fontFamily: config.fontFamily,
            fontWeight: config.fontWeight,
            fontStyle: config.fontStyle,
            letterSpacing: letterSpacing,
          ),
        ),
        spaceExpansion,
      ),
      textDirection: _environment.direction,
      locale: _environment.locale,
      textHeightBehavior: _environment.heightBehavior,
      textScaler: _environment.textScaler,
      maxLines: 1,
    )..layout();
    return painter;
  }

  /// 根据实际文字引擎的字距增量求对齐值，避免字体缩放后再次超宽。
  (double, double) _justifiedSpacing(
    LineInfo line,
    double availableWidth,
    bool eligible,
  ) {
    final base = config.letterSpacing;
    if (!config.justify || !eligible || line.words.length <= 1) {
      return (base, 0);
    }
    final limit = availableWidth - line.indentWidth + line.hangingWidth;
    final naturalWidth = _lineWidth(line.displayText, base);
    if (naturalWidth >= limit) return (base, 0);
    final wordSpacing =
        RegExp(r' +').allMatches(line.displayText.trim()).length > 1;
    final increment =
        _lineWidth(
          line.displayText,
          wordSpacing ? base : base + 1,
          spaceExpansion: wordSpacing ? 1 : 0,
        ) -
        naturalWidth;
    if (increment <= 0) return (base, 0);
    var high = math.min(
      (limit - naturalWidth) / increment,
      config.fontSize * 0.5,
    );
    var low = 0.0;
    for (var i = 0; i < 10; i++) {
      final candidate = i == 0 ? high : (low + high) / 2;
      final fits =
          _lineWidth(
            line.displayText,
            wordSpacing ? base : base + candidate,
            spaceExpansion: wordSpacing ? candidate : 0,
          ) <=
          limit + 0.001;
      if (fits) {
        low = candidate;
        if (i == 0) break;
      } else {
        high = candidate;
      }
    }
    return (wordSpacing ? base : base + low, wordSpacing ? low : 0);
  }

  /// 测量每个字符的宽度（整段同源测量，无逐字缓存）
  ///
  /// [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 重写测量路径——旧路径逐字符
  /// 单独建 TextPainter 测宽（三级缓存按码点复用）：单字测量游离于多字符
  /// 塑形上下文之外，与 Text widget 整行渲染存在不可消除的系统差，累计
  /// 偏差导致行尾吞字（8dp/5% 余量只缓解不根治）。新路径：整段一次
  /// TextPainter.layout + getBoxesForSelection 提取每字实际盒宽——测量与
  /// 渲染同一文字引擎、同一塑形上下文；并合并 DefaultTextStyle（主题
  /// 字体回退链）与 textScaler（系统文字缩放），与渲染侧 Text 完全同参。
  List<double> _measureCharWidths(String text, double maxWidth) {
    measurementCount++;
    final widths = List<double>.filled(text.length, 0.0);
    if (text.isEmpty) return widths;

    // 与渲染侧 Text 同参：DefaultTextStyle（主题字体/回退链）打底，
    // 渲染 override（字号/字距/字体/字重）覆盖其上
    final style = _environment.baseStyle.merge(
      TextStyle(
        fontSize: config.fontSize,
        letterSpacing: config.letterSpacing,
        fontFamily: config.fontFamily,
        fontWeight: config.fontWeight,
        fontStyle: config.fontStyle,
      ),
    );

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: _environment.direction,
      locale: _environment.locale,
      textHeightBehavior: _environment.heightBehavior,
      textScaler: _environment.textScaler,
    );
    painter.layout(maxWidth: maxWidth);

    var start = 0;
    for (final character in text.characters) {
      final end = start + character.length;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      widths[start] = boxes.fold<double>(
        0,
        (width, box) => width + box.right - box.left,
      );
      start = end;
    }
    painter.dispose();
    return widths;
  }

  /// 测量单个字符宽度（用于中文字符参考宽度）
  ///
  /// 对应 Kotlin paint.measureText("一")
  double _measureSingleChar(String char) =>
      _lineWidth(char, config.letterSpacing);

  /// 计算两端对齐的额外字间距
  ///
  /// 移植自 TextChapterLayout.kt addCharsToLineMiddle：
  /// - residualWidth = visibleWidth - desiredWidth
  /// - 有空格时：d = residualWidth / spaceSize
  /// - 无空格时：d = residualWidth / gapCount
  static double computeJustifySpacing({
    required double availableWidth,
    required double lineWidth,
    required int charCount,
    int spaceCount = 0,
  }) {
    if (lineWidth >= availableWidth || charCount <= 1) return 0.0;
    final residualWidth = availableWidth - lineWidth;
    if (spaceCount > 1) {
      // 有空格时分配到空格处（对应 Kotlin spaceSize > 1 分支）
      return residualWidth / spaceCount;
    }
    // 无空格时平均分配到每个字间隙（对应 Kotlin gapCount = words.lastIndex）
    final gapCount = charCount - 1;
    return gapCount > 0 ? residualWidth / gapCount : 0.0;
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
