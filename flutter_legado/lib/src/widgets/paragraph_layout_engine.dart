/// 段落布局引擎
///
/// 移植自 Kotlin TextChapterLayout.kt (1363 行) 和 HangingPunctuationRule.kt
/// 实现核心功能:
/// - 段落分页算法
/// - 中文避头尾规则
/// - 两端对齐排版
/// - 行高计算和字体度量
/// - 字符宽度缓存（移植自 TextMeasure.kt）
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'zh_layout.dart';
import 'reader/text_layout_environment.dart';
import 'reader/chapter_layout.dart';
import 'reader/line_paginator.dart';
import 'reader/text_break_rules.dart';
import 'reader/line_text_span.dart';
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

  // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂（对齐原版
  // HangingPunctuationRule.shouldHang(text, paragraphIndent)）：段首 =
  // 缩进全角空格（indentCount 个）+ 起始引号，且非 RTL（中文排版无 RTL
  // 场景，跳过检查）— Reasonix

  /// 段首可悬挂的起始引号字符
  static const Set<String> hangingChars = {'"', '“', '‘', '「', '『', '﹁', '﹃'};

  /// 判断段首是否应悬挂（缩进空格 + 起始引号）
  static bool shouldHang(String text, int indentCount) {
    if (indentCount <= 0) return false;
    var pos = 0;
    for (var i = 0; i < indentCount; i++) {
      if (pos >= text.length || text[pos] != '\u3000') return false;
      pos++;
    }
    if (pos >= text.length) return false;
    return hangingChars.contains(text[pos]);
  }
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

  // [UI-fix v2.0.5 | 2026-08-10] 自定义中文分行开关（对标原版 useZhLayout：
  // true=ZhLayout 中文避头尾断行；false=朴素按宽断行）— Reasonix
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

  /// 获取字符宽度缓存（供测试使用）
  CharWidthCache get charWidthCache => _charWidthCache;

  /// 排版整个章节内容（仅返回最后一页，保留兼容）
  ///
  /// 参考 ReadBook.kt 的三章预加载策略
  /// 移植自 TextChapterLayout.kt getTextChapter 方法
  PageInfo layoutChapter(
    String content,
    double availableWidth,
    double pageHeight,
  ) {
    final pages = paginateChapter(content, availableWidth, pageHeight);
    if (pages.isEmpty) return const PageInfo(paragraphs: [], totalHeight: 0);
    return pages.last;
  }

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
    final builder = LinePaginator(
      sourceText: content,
      environment: _environment,
      pageHeight: pageHeight,
      firstPageHeight: firstPageHeight,
      paragraphSpacing: config.paragraphSpacing,
    );
    final paragraphs = splitChapterParagraphs(content);
    for (var i = 0; i < paragraphs.length; i++) {
      builder.addParagraph(
        _layoutParagraph(
          paragraphs[i],
          availableWidth,
          review: paragraphReviews[i + 1],
        ),
        i + 1,
      );
    }
    return builder.finish();
  }

  /// 仅供未标记旧页码首次转换；普通排版不再走整段换页路径。
  int legacyPageSourceOffset(
    String content,
    double width,
    double height,
    int pageIndex, {
    double? firstPageHeight,
  }) {
    final pages = _paginateLegacy(
      content,
      width,
      height,
      firstPageHeight: firstPageHeight,
    );
    return pages.isEmpty
        ? 0
        : pages[pageIndex.clamp(0, pages.length - 1)].sourceStart;
  }

  List<PageInfo> _paginateLegacy(
    String content,
    double availableWidth,
    double pageHeight, {
    double? firstPageHeight,
  }) {
    final paragraphs = splitChapterParagraphs(content);
    if (paragraphs.isEmpty) return [];

    final pages = <PageInfo>[];
    var currentPageParagraphs = <ParagraphInfo>[];
    var currentHeight = 0.0;

    // 指定页的可用高度：首页按 firstPageHeight，其余页按 pageHeight
    double capacityFor(int pageIndex) =>
        pageIndex == 0 ? (firstPageHeight ?? pageHeight) : pageHeight;

    for (var i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i];
      final paraInfo = _layoutParagraph(para, availableWidth);
      final chapterParaIndex = i + 1; // 1-based，对齐原版段评 paraIndex

      // 段落间距（对应 Kotlin durY += textHeight * paragraphSpacing / 10f）
      double spacingHeight = currentPageParagraphs.isNotEmpty
          ? config.paragraphSpacing
          : 0.0;

      // 单段超出其起始页容量时，按行拆分到多页（当前页已有内容则
      // 段落从下一页起排，按整页容量判断）
      final startCapacity = currentPageParagraphs.isEmpty
          ? capacityFor(pages.length)
          : pageHeight;
      if (paraInfo.totalHeight > startCapacity) {
        // 先把之前累积的段落存为一页
        if (currentPageParagraphs.isNotEmpty) {
          pages.add(
            PageInfo(
              paragraphs: List.from(currentPageParagraphs),
              totalHeight: currentHeight,
              sourceText: content,
              textEnvironment: _environment,
            ),
          );
          currentPageParagraphs = [];
          currentHeight = 0.0;
        }
        // 按行拆分超长段落（首张子页若落在章首页则按首页容量）
        final subPages = _splitTallParagraph(
          paraInfo,
          pageHeight,
          firstPageCapacity: capacityFor(pages.length),
          chapterParagraphIndex: chapterParaIndex,
          sourceText: content,
        );
        pages.addAll(subPages);
        continue;
      }

      final tagged = ParagraphInfo(
        lines: paraInfo.lines,
        totalHeight: paraInfo.totalHeight,
        startIndex: paraInfo.startIndex,
        endIndex: paraInfo.endIndex,
        chapterParagraphIndex: chapterParaIndex,
        isParagraphEnd: true,
      );

      // 检查是否需要换页（对应 Kotlin prepareNextPageIfNeed）
      if (currentPageParagraphs.isNotEmpty &&
          (currentHeight + spacingHeight + tagged.totalHeight >
              capacityFor(pages.length))) {
        // 当前页已满，保存并开始新页
        pages.add(
          PageInfo(
            paragraphs: List.from(currentPageParagraphs),
            totalHeight: currentHeight,
            sourceText: content,
            textEnvironment: _environment,
          ),
        );
        currentPageParagraphs = [tagged];
        currentHeight = tagged.totalHeight;
      } else {
        currentPageParagraphs.add(tagged);
        currentHeight += spacingHeight + tagged.totalHeight;
      }
    }

    // 最后一页
    if (currentPageParagraphs.isNotEmpty) {
      pages.add(
        PageInfo(
          paragraphs: currentPageParagraphs,
          totalHeight: currentHeight,
          sourceText: content,
          textEnvironment: _environment,
        ),
      );
    }

    return pages;
  }

  /// 将超出单页高度的段落按行拆分到多页
  ///
  /// 对应 Kotlin TextChapterLayout 中单段超长时的逐行分页逻辑；
  /// [UI-fix v2.0.4 | 2026-08-08] 支持首张子页按 [firstPageCapacity]
  /// 限容（落在章首页时预留标题块高度）— Qoder
  List<PageInfo> _splitTallParagraph(
    ParagraphInfo paraInfo,
    double pageHeight, {
    double? firstPageCapacity,
    int chapterParagraphIndex = 0,
    String? sourceText,
  }) {
    final pages = <PageInfo>[];

    var lineIdx = 0;
    var subPageNo = 0;
    while (lineIdx < paraInfo.lines.length) {
      final capacity = subPageNo == 0
          ? (firstPageCapacity ?? pageHeight)
          : pageHeight;
      var endIdx = lineIdx;
      var height = 0.0;
      while (endIdx < paraInfo.lines.length) {
        final nextHeight = paraInfo.lines[endIdx].height;
        if (endIdx > lineIdx && height + nextHeight > capacity) break;
        height += nextHeight;
        endIdx++;
      }
      final pageLines = paraInfo.lines.sublist(lineIdx, endIdx);
      final isLast = endIdx >= paraInfo.lines.length;
      pages.add(
        PageInfo(
          paragraphs: [
            ParagraphInfo(
              lines: pageLines,
              totalHeight: height,
              startIndex: pageLines.isNotEmpty ? pageLines.first.startIndex : 0,
              endIndex: pageLines.isNotEmpty ? pageLines.last.endIndex : 0,
              chapterParagraphIndex: chapterParagraphIndex,
              isParagraphEnd: isLast,
            ),
          ],
          totalHeight: height,
          sourceText: sourceText,
          textEnvironment: _environment,
        ),
      );
      lineIdx = endIdx;
      subPageNo++;
    }
    return pages;
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

    // 处理首行缩进（对应 Kotlin paragraphIndent）
    // indent > 0 时，在文本前添加全角空格作为缩进
    String processableText = trimmedPara;

    if (config.indent > 0) {
      // [UI-fix v2.0.4 | 2026-08-08] 缩进改按字符数档位生成全角空格
      // （对应原版 ReadBookConfig.paragraphIndent "　".repeat(index)） — Qoder
      final indentChars = '\u3000' * config.indentCount;
      processableText = '$indentChars$trimmedPara';
    }

    // 使用 ZhLayout 中文断行引擎进行分行
    // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂：段首 = 缩进全角空格 +
    // 起始引号时，首行可用宽 + 缩进宽度（标点悬挂进缩进区，对齐原版
    // HangingPunctuationRule + ZhLayout.hangingWidth 语义）— Reasonix
    final hangingWidth =
        config.hangingPunctuation &&
            config.indent > 0 &&
            ChinesePunctuationRule.shouldHang(
              processableText,
              config.indentCount,
            )
        ? _measurePrefixWidth(processableText.substring(0, config.indentCount))
        : 0.0;
    final layoutLines = _breakLines(
      processableText,
      availableWidth,
      hangingWidth: hangingWidth,
    );
    final reviewSize = review == null
        ? null
        : _placeReviewTail(layoutLines, availableWidth, review);

    // 计算总高度（对应 Kotlin durY += textHeight * lineSpacingExtra）
    final prefixLength = processableText.length - trimmedPara.length;
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
      final virtualPrefixLength = (prefixLength - line.startIndex).clamp(
        0,
        line.endIndex - line.startIndex,
      );
      var indentWidth = 0.0;
      if (virtualPrefixLength > 0) {
        final selectableText = line.displayText.substring(virtualPrefixLength);
        if (selectableText.isEmpty) {
          indentWidth = metrics.width;
        } else {
          // 字距会影响首字左右的半个间距，不能直接用插入点作为留白宽度。
          final textMetrics = _measureLine(
            selectableText,
            spacing,
            spaceExpansion: spaceExpansion,
          );
          final firstLength = selectableText.characters.first.length;
          final originalBox = metrics
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: virtualPrefixLength,
                  extentOffset: virtualPrefixLength + firstLength,
                ),
              )
              .first;
          final textBox = textMetrics
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: firstLength),
              )
              .first;
          indentWidth = math.max(0, originalBox.left - textBox.left);
          textMetrics.dispose();
        }
      }
      lines.add(
        LineInfo(
          words: line.words,
          width: metrics.width,
          height: last && reviewSize != null
              ? math.max(
                  textTop + metrics.height,
                  reviewTop + reviewSize.height,
                )
              : metrics.height,
          startIndex:
              paragraph.startIndex +
              (line.startIndex - prefixLength).clamp(0, trimmedPara.length),
          endIndex:
              paragraph.startIndex +
              (line.endIndex - prefixLength).clamp(0, trimmedPara.length),
          virtualPrefixLength: virtualPrefixLength,
          indentWidth: indentWidth,
          hangingWidth: line.hangingWidth,
          letterSpacing: spacing,
          spaceExpansion: spaceExpansion,
          baseline: rowBaseline,
          textTop: textTop,
          trailingReview: last && review != null && reviewSize != null
              ? InlineReviewLayout(
                  element: review,
                  offset: Offset(metrics.width - line.hangingWidth, reviewTop),
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
    final painter = _measureLine(prefix, config.letterSpacing);
    final width = painter.width;
    painter.dispose();
    return width;
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
      final painter = _measureLine(text, config.letterSpacing);
      final result = painter.width;
      painter.dispose();
      return result;
    }

    for (final slot in [review.size, review.compactSize]) {
      if (measure(last.displayText) - last.hangingWidth + slot.width <=
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
      math.max(0, width - measure(last.displayText) + last.hangingWidth),
      review.compactSize.height,
    );
  }

  /// 分行算法（使用 ZhLayout 中文断行引擎）
  ///
  /// 移植自 TextChapterLayout.kt 第 940-948 行：
  /// 1. 测量每个字符宽度（整段同源测量，见 [_measureCharWidths]）
  /// 2. 使用 ZhLayout 进行中文标点感知断行（useZhLayout=true）
  ///    或朴素按宽断行（useZhLayout=false）
  /// 3. 行宽安全网：超宽行把行尾字符下移（见 [_guardLineOverflow]）
  ///
  /// [UI-fix v2.0.5 | 2026-08-10] `hangingWidth` > 0 时首行可用宽上限
  /// 增加该宽度（段首标点悬挂）— Reasonix
  List<LineInfo> _breakLines(
    String text,
    double availableWidth, {
    double hangingWidth = 0,
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
        ? _breakZhLayout(words, widths, availableWidth, hangingWidth)
        : _breakPlain(words, widths, availableWidth, hangingWidth);

    // 步骤6：行宽安全网（ZhLayout 压缩模式行宽可超限，渲染端无字形压缩
    // 能力，超宽行必须重排否则行尾被 ClipRect 裁掉）
    return _guardLineOverflow(
      text,
      widthsArray,
      lines,
      availableWidth,
      hangingWidth: hangingWidth,
    );
  }

  /// 朴素按宽断行（useZhLayout=false，不等同于 Android StaticLayout）
  List<LineInfo> _breakPlain(
    List<String> words,
    List<double> widths,
    double availableWidth,
    double hangingWidth,
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
        ),
      );
    }

    for (var i = 0; i < words.length; i++) {
      final w = widths[i];
      final limit = lineStartIdx == 0
          ? availableWidth + hangingWidth
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

  /// ZhLayout 中文避头尾断行（useZhLayout=true）
  List<LineInfo> _breakZhLayout(
    List<String> words,
    List<double> widths,
    double availableWidth,
    double hangingWidth,
  ) {
    // 中文字符参考宽度（对应 Kotlin cnCharWidthCache）
    final cnCharWidth = _measureSingleChar('我');

    // 对应 Kotlin ZhLayout(text, textPaint, visibleWidth, words, widths, indentSize)
    final layout = ZhLayout.compute(
      words: words,
      widths: widths,
      availableWidth: availableWidth,
      // [UI-fix v2.0.4 | 2026-08-08] 缩进档位接入断行引擎 — Qoder
      indentSize: config.indent > 0 ? config.indentCount : 0,
      cnCharWidth: cnCharWidth,
      // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂：首行宽度上限放宽 — Reasonix
      hangingWidth: hangingWidth,
    );

    // 根据断行结果构建 LineInfo 列表
    final lines = <LineInfo>[];
    final textHeight = config.fontSize * config.lineHeight;
    final offsets = TextClusterMap(words.join()).sourceOffsets;

    for (var lineIndex = 0; lineIndex < layout.lineCount; lineIndex++) {
      final lineStartIdx = layout.getLineStart(lineIndex);
      final lineEndIdx = layout.getLineEnd(lineIndex);

      // 提取当前行的字符
      final lineWords = words.sublist(
        lineStartIdx.clamp(0, words.length),
        lineEndIdx.clamp(0, words.length),
      );
      final lineWidth = layout.getLineWidth(lineIndex);

      // 计算原始文本中的起止索引
      final startOffset = offsets[lineStartIdx];
      final endOffset = offsets[lineEndIdx];

      lines.add(
        LineInfo(
          words: lineWords,
          width: lineWidth,
          height: textHeight,
          startIndex: startOffset,
          endIndex: endOffset,
          // 悬挂仅作用于首行
          hangingWidth: lineIndex == 0 ? hangingWidth : 0,
        ),
      );
    }

    return lines;
  }

  /// 行宽安全网：超宽行把行尾字符下移到下一行（2026-09-06 吞字根治）
  ///
  /// 背景：ZhLayout 压缩模式（cps1/2/3）按原版语义允许行宽超出可用宽
  /// （原版在绘制层压缩标点字形兜底），但 Flutter 渲染端是
  /// Text(maxLines:1, overflow: clip) 自然宽度渲染，无法压缩字形，
  /// 超宽即被 ClipRect 裁掉行尾——"正文右边吞字"的结构性根因之一，
  /// 加分页余量无法根治（大字号时压缩超宽量大于余量总量）。
  ///
  /// 处理：用与渲染同源的实测宽度（整段逐字盒宽之和）逐行校验，超宽行
  /// 从行尾回退分割点（避头尾尽力保持：下一行行首不落禁首标点、上一行
  /// 行末不落禁末标点），溢出字符并入下一行重新校验，直至全部合规。
  List<LineInfo> _guardLineOverflow(
    String text,
    List<double> widths,
    List<LineInfo> lines,
    double availableWidth, {
    double hangingWidth = 0,
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
        final painter = _measureLine(
          text.substring(start, boundaries[last]),
          config.letterSpacing,
        );
        final fits = painter.width <= limit + 0.001;
        painter.dispose();
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
      final limit = availableWidth + (guarded.isEmpty ? hangingWidth : 0);
      final fitted = fitEnd(start, end, limit);
      guarded.add(
        _buildGuardedLine(
          text,
          widths,
          start,
          fitted,
          config.fontSize * config.lineHeight,
          hangingWidth: guarded.isEmpty ? hangingWidth : 0,
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
    );
  }

  /// 使用最终绘制样式测量整行，文字缩放和字体回退参与高度与宽度。
  TextPainter _measureLine(
    String text,
    double letterSpacing, {
    double spaceExpansion = 0,
  }) {
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
    final limit = availableWidth + line.hangingWidth;
    final natural = _measureLine(line.displayText, base);
    final naturalWidth = natural.width;
    natural.dispose();
    if (naturalWidth >= limit) return (base, 0);
    final wordSpacing =
        RegExp(r' +').allMatches(line.displayText.trim()).length > 1;
    final probe = _measureLine(
      line.displayText,
      wordSpacing ? base : base + 1,
      spaceExpansion: wordSpacing ? 1 : 0,
    );
    final increment = probe.width - naturalWidth;
    probe.dispose();
    if (increment <= 0) return (base, 0);
    var high = math.min(
      (limit - naturalWidth) / increment,
      config.fontSize * 0.5,
    );
    var low = 0.0;
    for (var i = 0; i < 10; i++) {
      final candidate = i == 0 ? high : (low + high) / 2;
      final painter = _measureLine(
        line.displayText,
        wordSpacing ? base : base + candidate,
        spaceExpansion: wordSpacing ? candidate : 0,
      );
      final fits = painter.width <= limit + 0.001;
      painter.dispose();
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
  double _measureSingleChar(String char) {
    final painter = TextPainter(
      // [UI-fix v2.0.2 | 2026-08-06] 单字宽度测量同步字距/字体配置 — Qoder
      // [UI-fix v2.0.4 | 2026-08-08] 同步字重（textBold） — Qoder
      // [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 同步 DefaultTextStyle 与
      // textScaler（与 _measureCharWidths / 渲染侧同参）— Qoder
      text: TextSpan(
        text: char,
        style: _environment.baseStyle.merge(
          TextStyle(
            fontSize: config.fontSize,
            letterSpacing: config.letterSpacing,
            fontFamily: config.fontFamily,
            fontWeight: config.fontWeight,
            fontStyle: config.fontStyle,
          ),
        ),
      ),
      textDirection: _environment.direction,
      locale: _environment.locale,
      textHeightBehavior: _environment.heightBehavior,
      textScaler: _environment.textScaler,
    );
    painter.layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

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

  /// 渲染排版结果
  Widget render(PageInfo pageInfo) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomMultiChildLayout(
          delegate: _PageLayoutDelegate(pageInfo, constraints.maxWidth, config),
          children: pageInfo.paragraphs.expand((para) {
            return para.lines.asMap().entries.map((entry) {
              final lineIdx = entry.key;
              final line = entry.value;
              final isLastLine = lineIdx == para.lines.length - 1;
              final isSingleLine = para.lines.length == 1;
              // 两端对齐：非最后一行且非单行
              final shouldJustify =
                  config.justify && !isLastLine && !isSingleLine;
              return _LineWidget(
                line: line,
                config: config,
                isJustified: shouldJustify,
                availableWidth: constraints.maxWidth,
              );
            });
          }).toList(),
        );
      },
    );
  }
}

/// 页面布局代理
///
/// 对齐策略移植自 TextChapterLayout.kt：
/// - addCharsToLineFirst: 首行缩进 + 两端对齐
/// - addCharsToLineMiddle: 无缩进两端对齐（字间距分配）
/// - addCharsToLineNatural: 自然排列（最后一行/标题）
class _PageLayoutDelegate extends MultiChildLayoutDelegate {
  final PageInfo pageInfo;
  final double maxWidth;
  final ParagraphConfig config;

  _PageLayoutDelegate(this.pageInfo, this.maxWidth, this.config);

  @override
  void performLayout(Size size) {
    double currentY = 0.0;

    for (final paragraph in pageInfo.paragraphs) {
      for (var lineIdx = 0; lineIdx < paragraph.lines.length; lineIdx++) {
        final line = paragraph.lines[lineIdx];
        layoutChild(line, BoxConstraints.loose(Size(maxWidth, line.height)));

        // 对齐策略（对应 Kotlin addCharsToLineFirst/Middle/Natural）
        double xOffset = 0.0;
        final isLastLine = lineIdx == paragraph.lines.length - 1;
        final isSingleLine = paragraph.lines.length == 1;

        if (!config.justify || isLastLine || isSingleLine) {
          // 自然排列（addCharsToLineNatural）：最后一行/单行左对齐
          xOffset = 0.0;
        } else {
          // 两端对齐（addCharsToLineMiddle）：字间距分配
          xOffset = 0.0; // 起始位置不变，字间距在渲染层处理
        }

        positionChild(line, Offset(xOffset, currentY));
        currentY += line.height;
      }
      currentY += config.paragraphSpacing;
    }
  }

  @override
  bool shouldRelayout(_PageLayoutDelegate oldDelegate) => false;
}

/// 行 Widget
///
/// 两端对齐渲染移植自 TextChapterLayout.kt addCharsToLineMiddle：
/// - 有空格时：将剩余宽度分配到空格处
/// - 无空格时：将剩余宽度平均分配到每个字间隙
class _LineWidget extends StatelessWidget {
  final LineInfo line;
  final ParagraphConfig config;
  final bool isJustified;
  final double availableWidth;

  const _LineWidget({
    required this.line,
    required this.config,
    this.isJustified = false,
    this.availableWidth = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final text = line.selectableText;

    // 两端对齐：计算额外字间距
    // 对应 Kotlin: residualWidth / gapCount
    return Container(
      height: line.height,
      decoration: BoxDecoration(color: config.backgroundColor),
      padding: EdgeInsets.only(left: line.indentWidth),
      child: text.isEmpty
          ? null
          : Text(
              text,
              style: TextStyle(
                fontSize: config.fontSize,
                color: config.textColor,
                height: config.lineHeight,
                fontFamily: config.fontFamily,
                fontWeight: config.fontWeight,
                fontStyle: config.fontStyle,
                letterSpacing: line.letterSpacing ?? config.letterSpacing,
              ),
            ),
    );
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
