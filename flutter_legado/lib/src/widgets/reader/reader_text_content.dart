import 'package:material_ui/material_ui.dart';

import '../../l10n/app_strings.dart';
import '../../widgets/paragraph_layout_engine.dart';
import 'review_column.dart';
import 'reader_page_chrome.dart';
import 'reader_selection_toolbar.dart';
import 'reader_selection_region.dart';
import 'reader_selectable_text.dart';
import 'line_text_span.dart';

/// 段评角标点击（段落索引 1-based、评论数）
typedef ReviewTapCallback = void Function(int paragraphIndex, int count);

/// 阅读器正文排版渲染
///
/// 移植自安卓端 TextChapterLayout 的页面渲染逻辑：
/// - 首屏显示章节标题
/// - 正文使用排版引擎的分行结果渲染
/// - 支持两端对齐、首行缩进、中文避头尾
class ReaderTypographicPage extends StatelessWidget {
  final PageInfo? pageInfo;
  final int pageIndex;
  final int totalPages;
  final String? chapterTitle;

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final Color backgroundColor;
  final Color textColor;
  final (int, int)? readAloudRange;
  final Color? readAloudColor;

  /// 全局页索引（跨章节连续编号，可选）
  final int? globalPageIndex;

  /// 全局总页数（可选）
  final int? globalTotalPages;

  // [UI-fix v2.0.3 | 2026-08-06] 页面内容边距接阅读配置（对标原版
  // ReadBookConfig 四向 padding），默认保持历史硬编码值 — Qoder
  final EdgeInsets contentPadding;

  // [UI-fix v2.0.3 | 2026-08-08] 长按选择文本开关（对标原版 selectText，
  // 关闭后长按正文不再弹出选区面板）— Qoder
  final bool selectText;

  // [UI-fix v2.0.4 | 2026-08-08] 分页页渲染补齐排版参数透传：字距/字体/
  // 两端对齐/字重（此前分页模式仅测量时生效、渲染未应用导致宽度不一致；
  // 字重对标原版 textBold → TextPaint.typeface 加粗/细体）— Qoder
  final double letterSpacing;
  final String? fontFamily;
  final bool justify;
  final FontWeight? fontWeight;

  // [C3 斜体 | Qoder UI] 正文斜体（与 fontWeight 同链路透传，测量/渲染同参）
  final FontStyle? fontStyle;

  // [UI-fix v2.0.59 | 2026-08-14] 页眉/页脚提示与标题样式 — Cursor UI
  final ReaderPageChromeConfig pageChrome;
  final ReaderTipContext tipContext;

  final Map<int, int>? reviewCounts;
  final ReviewTapCallback? onReviewTap;

  const ReaderTypographicPage({
    super.key,
    required this.pageInfo,
    required this.pageIndex,
    required this.totalPages,
    required this.chapterTitle,
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.backgroundColor,
    required this.textColor,
    this.readAloudRange,
    this.readAloudColor,
    this.globalPageIndex,
    this.globalTotalPages,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 24,
    ),
    this.pageChrome = const ReaderPageChromeConfig(),
    this.tipContext = const ReaderTipContext(pageIndex: 0, totalPages: 1),
    this.selectText = true,
    this.letterSpacing = 0.0,
    this.fontFamily,
    this.justify = true,
    this.fontWeight,
    this.fontStyle,
    this.reviewCounts,
    this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    // 分页结果尚未就绪时显示加载状态
    final info = pageInfo;
    if (info == null) {
      return Center(
        child: Text(
          AppStrings.noContent,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final chrome = pageChrome;
    final showHeader = chrome.showPageHeader && chrome.hasHeaderTips;
    final showFooter = chrome.showPageFooter && chrome.hasFooterTips;
    final showTitle =
        pageIndex == 0 &&
        chapterTitle != null &&
        chrome.titleMode.clamp(0, 2) != 2;
    final titleAlign = switch (chrome.titleMode.clamp(0, 2)) {
      1 => TextAlign.center,
      _ => TextAlign.start,
    };

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            SelectionContainer.disabled(
              child: ReaderPageTipBar(
                padding: EdgeInsets.fromLTRB(
                  chrome.headerPaddingLeft,
                  chrome.headerPaddingTop,
                  chrome.headerPaddingRight,
                  chrome.headerPaddingBottom,
                ),
                leftTip: chrome.tipHeaderLeft,
                middleTip: chrome.tipHeaderMiddle,
                rightTip: chrome.tipHeaderRight,
                tipContext: tipContext,
                textColor: textColor,
                showDivider: chrome.showHeaderLine,
                dividerOnTop: false,
              ),
            ),
          Expanded(
            child: Padding(
              padding: contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTitle)
                    SelectionContainer.disabled(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: chrome.titleTopSpacing.toDouble(),
                          bottom: chrome.titleBottomSpacing.toDouble(),
                        ),
                        child: Align(
                          alignment: titleAlign == TextAlign.center
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Text(
                            chapterTitle!,
                            textAlign: titleAlign,
                            style: TextStyle(
                              fontSize: fontSize + chrome.titleSize,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              // [C3 标题字体] 与测量侧同参（effectiveTitleFontFamily
                              // 单源）；同时修复既有偏差：空=跟随正文字体，标题
                              // 随自定义正文自定义字体生效 — full-stack-engineer
                              fontFamily: effectiveTitleFontFamily(
                                chrome,
                                fontFamily,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ReaderTextContent(
                      pageInfo: info,
                      fontSize: fontSize,
                      lineHeight: lineHeight,
                      paragraphSpacing: paragraphSpacing,
                      textColor: textColor,
                      readAloudRange: readAloudRange,
                      readAloudColor: readAloudColor,
                      selectText: selectText,
                      letterSpacing: letterSpacing,
                      fontFamily: fontFamily,
                      justify: justify,
                      fontWeight: fontWeight,
                      fontStyle: fontStyle,
                      reviewCounts: reviewCounts,
                      onReviewTap: onReviewTap,
                    ),
                  ),
                  if (!showFooter)
                    SelectionContainer.disabled(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            _buildPageIndicator(),
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showFooter)
            SelectionContainer.disabled(
              child: ReaderPageTipBar(
                padding: EdgeInsets.fromLTRB(
                  chrome.footerPaddingLeft,
                  chrome.footerPaddingTop,
                  chrome.footerPaddingRight,
                  chrome.footerPaddingBottom,
                ),
                leftTip: chrome.tipFooterLeft,
                middleTip: chrome.tipFooterMiddle,
                rightTip: chrome.tipFooterRight,
                tipContext: tipContext,
                textColor: textColor,
                showDivider: chrome.showFooterLine,
                dividerOnTop: true,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建页码指示文本
  ///
  /// 格式："章内页/章总页" 或 "章内页/章总页 · 全局页/全局总页"
  String _buildPageIndicator() {
    final localIndicator = '${pageIndex + 1}/$totalPages';
    final gIndex = globalPageIndex;
    final gTotal = globalTotalPages;
    if (gIndex != null && gTotal != null && gTotal > 0) {
      return '$localIndicator · ${gIndex + 1}/$gTotal';
    }
    return localIndicator;
  }
}

/// 单页排版内容（逐行渲染，支持两端对齐）
///
/// 移植自 TextChapterLayout.kt 的 addCharsToLineFirst/Middle/Natural
class ReaderTextContent extends StatelessWidget {
  final PageInfo pageInfo;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final Color textColor;
  final (int, int)? readAloudRange;
  final Color? readAloudColor;

  // [UI-fix v2.0.2 | 2026-08-06] 字距调节与字体选择接入渲染
  // （对标原版 ReadBookConfig.letterSpacing/textFont） — Qoder
  final double letterSpacing;
  final String? fontFamily;

  /// 两端对齐开关（对标 MoreConfig textFullJustify）
  final bool justify;

  // [UI-fix v2.0.3 | 2026-08-08] 长按选择文本开关（对标原版 selectText，
  // 关闭后长按不弹选区面板，对标 ReadView.textSelectAble 事件语义）— Qoder
  final bool selectText;

  // [UI-fix v2.0.4 | 2026-08-08] 文字字重（对标原版 textBold：中/粗/细，
  // null=正常字重）— Qoder
  final FontWeight? fontWeight;

  // [C3 斜体 | Qoder UI] 正文斜体（与 fontWeight 同链路透传，测量/渲染同参）
  final FontStyle? fontStyle;

  /// 段评摘要：段落索引 → 评论数（P2-9 ruleReview）
  final Map<int, int>? reviewCounts;

  /// 段评角标点击
  final ReviewTapCallback? onReviewTap;

  const ReaderTextContent({
    super.key,
    required this.pageInfo,
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.textColor,
    this.readAloudRange,
    this.readAloudColor,
    this.letterSpacing = 0.0,
    this.fontFamily,
    this.justify = true,
    this.selectText = true,
    this.fontWeight,
    this.fontStyle,
    this.reviewCounts,
    this.onReviewTap,
  });

  @override
  Widget build(BuildContext context) {
    // [UI_SYNC_REFACTOR S4 修 | 2026-09-06] 两端对齐的可用宽改用实际布局
    // 约束——此前硬编码屏宽-40，自定义页面边距（contentPadding ≠ 20×2）
    // 时对齐目标宽与渲染约束错位，拉伸后行宽超约束被裁（行尾吞字）— Qoder
    return LayoutBuilder(
      builder: (context, constraints) {
        final widgets = <Widget>[];
        final availableWidth = constraints.maxWidth;
        // 当前页的实际文字共同测量字体回退，避免每行按不同字体单独取高亮高度。
        final selectionGeometry = selectText && pageInfo.sourceText != null
            ? ReaderSelectionGeometry.forText(
                context,
                pageInfo.paragraphs
                    .expand((p) => p.lines)
                    .map((line) => line.selectableText)
                    .join(),
                TextStyle(
                  fontSize: fontSize,
                  height: lineHeight,
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                  fontStyle: fontStyle,
                ),
              )
            : null;

        for (var paraIdx = 0; paraIdx < pageInfo.paragraphs.length; paraIdx++) {
          final para = pageInfo.paragraphs[paraIdx];

          // 段落间距（非第一段时添加）
          final gap =
              para.spacingBefore ?? (paraIdx > 0 ? paragraphSpacing : 0);
          if (gap > 0) {
            widgets.add(SizedBox(height: gap));
          }

          // 逐行渲染
          final lineWidgets = <Widget>[];
          for (var lineIdx = 0; lineIdx < para.lines.length; lineIdx++) {
            final line = para.lines[lineIdx];
            final text = line.selectableText;
            final environment = pageInfo.textEnvironment;
            final textStyle = (environment?.baseStyle ?? const TextStyle())
                .merge(
                  TextStyle(
                    fontSize: fontSize,
                    height: lineHeight,
                    color:
                        readAloudRange != null &&
                            para.startIndex < readAloudRange!.$2 &&
                            para.endIndex > readAloudRange!.$1
                        ? readAloudColor ?? textColor
                        : textColor,
                    fontFamily: fontFamily,
                    fontWeight: fontWeight,
                    fontStyle: fontStyle,
                    letterSpacing: line.letterSpacing ?? letterSpacing,
                  ),
                );
            // 缩进用布局留白绘制，原生选区只能接触章节中的实际文字。
            final lineText = Padding(
              padding: EdgeInsets.only(
                left: line.indentWidth - line.hangingWidth,
              ),
              child: text.isEmpty
                  ? const SizedBox.shrink()
                  : selectText && pageInfo.sourceText != null
                  ? ReaderLineText(
                      text,
                      style: textStyle,
                      selectionGeometry: selectionGeometry,
                      environment: environment,
                      spaceExpansion: line.spaceExpansion,
                      glyphs: line.glyphs,
                    )
                  : ReaderSelectableText(
                      text: readerLineSpan(
                        text,
                        textStyle,
                        line.spaceExpansion,
                      ),
                      glyphs: line.glyphs,
                      glyphStyle: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      textDirection: environment?.direction,
                      locale: environment?.locale,
                      textScaler:
                          environment?.textScaler ??
                          MediaQuery.textScalerOf(context),
                      textHeightBehavior: environment?.heightBehavior,
                    ),
            );
            final review = line.trailingReview;
            final count = review == null
                ? 0
                : (reviewCounts?[review.element.reviewKey] ??
                      review.element.count);
            lineWidgets.add(
              SizedBox(
                width: availableWidth,
                height: line.height,
                // 正文和段评使用布局给定的同一行坐标，不改变正文宽度。
                child: review != null
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: line.textTop,
                            width: review.offset.dx,
                            child: lineText,
                          ),
                          if (count > 0 && review.size.width > 0)
                            Positioned(
                              left: review.offset.dx,
                              top: review.offset.dy,
                              width: review.size.width,
                              height: review.size.height,
                              child: SelectionContainer.disabled(
                                child: ReviewColumnBadge(
                                  count: count,
                                  layoutSize: review.size,
                                  compact: review.compact,
                                  onTap: onReviewTap == null
                                      ? null
                                      : () => onReviewTap!(
                                          review.element.reviewKey,
                                          count,
                                        ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : lineText,
              ),
            );
          }

          // [UI-fix v2.0.1 | 2026-08-06] 段落级长按入口：弹出选区操作面板
          // （对齐原版 ReadView.onLongPress → showTextActionMenu；P0-1 审计修复）
          // [UI-fix v2.0.3 | 2026-08-08] selectText 关闭时移除长按入口 — Qoder
          final source = pageInfo.sourceText;
          final paraText = source != null
              ? source.substring(para.startIndex, para.endIndex)
              : para.lines.map((l) => l.selectableText).join();
          final paragraphBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lineWidgets,
          );
          // 原生选区覆盖正文；段评角标与翻页快照不参与显示偏移计算。
          Widget paragraphContent = paragraphBody;
          if (selectText &&
              source == null &&
              ReaderSelectionScope.maybeOf(context) == null &&
              paraText.trim().isNotEmpty) {
            paragraphContent = GestureDetector(
              onLongPressStart: (details) {
                ReaderSelectionToolbar.show(
                  context,
                  anchor: details.globalPosition,
                  text: paraText,
                  chapterPos: para.startIndex,
                );
              },
              child: paragraphContent,
            );
          }
          widgets.add(paragraphContent);
        }

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        );
        final selectableBody = selectText && pageInfo.sourceText != null
            ? ReaderSelectionTextGroup(child: body)
            : body;
        if (selectText &&
            pageInfo.sourceText != null &&
            ReaderSelectionScope.maybeOf(context) == null) {
          return ReaderSelectionRegion(
            pages: [pageInfo],
            source: pageInfo.sourceText!,
            child: selectableBody,
          );
        }
        return selectableBody;
      },
    );
  }
}
