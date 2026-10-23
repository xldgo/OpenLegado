import '../../../domain/models/reader_page_layout_settings.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import '../layout/text_layout_environment.dart';
import '../layout/reader_footer_geometry.dart';
import 'reader_battery_icon.dart';

import 'dart:math' as math;

/// 阅读页避让系统状态栏的顶部 inset（对标原版 TitleBar fitStatusBar /
/// WindowInsetsCompat.Type.systemBars）。
///
/// 沉浸式 edge-to-edge（`setDecorFitsSystemWindows(false)`）下
/// [MediaQuery.padding] 的 top 可能为 0，须用 [MediaQuery.viewPadding]，
/// 否则顶栏标题/页眉会与电量、时间重叠。
double readerSystemStatusBarInset(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).top;

/// 系统栏占位与缺口独立；重叠边距取最大值，菜单临时显隐不参与。— Codex + UI
EdgeInsets readerContentInsets({
  required EdgeInsets systemInsets,
  required EdgeInsets cutoutInsets,
  required bool hideStatusBar,
  required bool hideNavigationBar,
  required bool avoidDisplayCutouts,
}) {
  final cutout = avoidDisplayCutouts ? cutoutInsets : EdgeInsets.zero;
  return EdgeInsets.fromLTRB(
    cutout.left,
    math.max(hideStatusBar ? 0 : systemInsets.top, cutout.top),
    cutout.right,
    math.max(hideNavigationBar ? 0 : systemInsets.bottom, cutout.bottom),
  );
}

/// 只释放提示的垂直缺口占位；横向缺口及可见系统栏继续避让。— Codex + UI
EdgeInsets readerChromeInsets({
  required EdgeInsets contentInsets,
  required EdgeInsets systemInsets,
  required bool extendPageTips,
  required bool hideStatusBar,
  required bool hideNavigationBar,
  required bool centeredHeader,
}) => !extendPageTips
    ? contentInsets
    : EdgeInsets.fromLTRB(
        contentInsets.left,
        centeredHeader
            ? contentInsets.top
            : (hideStatusBar ? 0 : systemInsets.top),
        contentInsets.right,
        hideNavigationBar ? 0 : systemInsets.bottom,
      );

/// 正文安全区相对提示区域的内缩差值，不重复添加完整安全区。
EdgeInsets readerChromeExpansion(EdgeInsets content, EdgeInsets chrome) =>
    EdgeInsets.only(
      top: math.max(0, content.top - chrome.top),
      bottom: math.max(0, content.bottom - chrome.bottom),
    );

/// 安全区和提示条重叠部分只占一次空间，测量与绘制使用同一结果。
({double headerInsideBody, double footerInsideBody, EdgeInsets bodyPadding})
readerPageEdgeSpace({
  required EdgeInsets expansion,
  required double headerHeight,
  required double footerHeight,
}) {
  final headerOverlap = math.min(expansion.top, headerHeight);
  final footerOverlap = math.min(expansion.bottom, footerHeight);
  return (
    headerInsideBody: headerHeight - headerOverlap,
    footerInsideBody: footerHeight - footerOverlap,
    bodyPadding: EdgeInsets.only(
      top: expansion.top - headerOverlap,
      bottom: expansion.bottom - footerOverlap,
    ),
  );
}

/// 独立使用阅读页时按配置处理状态栏；宿主已计算尺寸时直接使用宿主结果。
double readerContentStatusBarInset(
  BuildContext context, {
  required bool hideStatusBar,
}) => hideStatusBar ? 0 : readerSystemStatusBarInset(context);

/// 标题字体生效家族（空=跟随正文字体，对齐原版 ReadBookConfig.titleFont）。
///
/// 标题内容块测量使用此函数；最终样式随布局结果传给渲染，不再独立扣首页高度。
///
/// [bodyFontFamily] 为正文字体家族（可为 null=默认字体）。
String? effectiveTitleFontFamily(
  ReaderPageChromeConfig chrome,
  String? bodyFontFamily,
) =>
    chrome.titleFontFamily.isNotEmpty ? chrome.titleFontFamily : bodyFontFamily;

/// 阅读页页眉/页脚与标题样式（对标原版 ReadBookConfig + ReadTipConfig）
class ReaderPageChromeConfig {
  final int headerMode;
  final int footerMode;
  final bool hideStatusBar;

  final double headerPaddingTop;
  final double headerPaddingBottom;
  final double headerPaddingLeft;
  final double headerPaddingRight;
  final double footerPaddingTop;
  final double footerPaddingBottom;
  final double footerPaddingLeft;
  final double footerPaddingRight;
  final bool showHeaderLine;
  final bool showFooterLine;

  final int tipHeaderLeft;
  final int tipHeaderMiddle;
  final int tipHeaderRight;
  final int tipFooterLeft;
  final int tipFooterMiddle;
  final int tipFooterRight;

  final int titleMode;
  final int titleSize;
  final bool titleSizeRelative;
  final int titleFontWeight;
  final double titleLineHeight;
  final int titleSegmentType;
  final int titleSegmentPosition;
  final String titleSegmentDelimiter;
  final double titleSubtitleScale;
  final double titleSegmentSpacing;
  final int titleTopSpacing;
  final int titleBottomSpacing;

  /// 标题字体（空=跟随正文字体，对齐原版 ReadBookConfig.titleFont）
  final String titleFontFamily;

  const ReaderPageChromeConfig({
    this.headerMode = 0,
    this.footerMode = 0,
    this.hideStatusBar = false,
    this.headerPaddingTop = 0,
    this.headerPaddingBottom = 0,
    this.headerPaddingLeft = 16,
    this.headerPaddingRight = 16,
    this.footerPaddingTop = 6,
    this.footerPaddingBottom = 6,
    this.footerPaddingLeft = 16,
    this.footerPaddingRight = 16,
    this.showHeaderLine = false,
    this.showFooterLine = true,
    this.tipHeaderLeft = 2,
    this.tipHeaderMiddle = 0,
    this.tipHeaderRight = 3,
    // [C2 R5] 底栏左侧默认显示书名（tip 7），对齐参考
    this.tipFooterLeft = 7,
    this.tipFooterMiddle = 0,
    this.tipFooterRight = 6,
    this.titleMode = 0,
    this.titleSize = 4,
    this.titleSizeRelative = true,
    this.titleFontWeight = 500,
    this.titleLineHeight = 1.2,
    this.titleSegmentType = 0,
    this.titleSegmentPosition = 4,
    this.titleSegmentDelimiter = '',
    this.titleSubtitleScale = 1,
    this.titleSegmentSpacing = 1.2,
    this.titleTopSpacing = 0,
    this.titleBottomSpacing = 0,
    this.titleFontFamily = '',
  });

  factory ReaderPageChromeConfig.fromSettings(
    ReaderPageLayoutSettings c, {
    bool hideStatusBar = false,
    String titleFontFamily = '',
  }) {
    return ReaderPageChromeConfig(
      headerMode: c.header.mode,
      footerMode: c.footer.mode,
      hideStatusBar: hideStatusBar,
      headerPaddingTop: c.header.padding.top,
      headerPaddingBottom: c.header.padding.bottom,
      headerPaddingLeft: c.header.padding.left,
      headerPaddingRight: c.header.padding.right,
      footerPaddingTop: c.footer.padding.top,
      footerPaddingBottom: c.footer.padding.bottom,
      footerPaddingLeft: c.footer.padding.left,
      footerPaddingRight: c.footer.padding.right,
      showHeaderLine: c.header.showLine,
      showFooterLine: c.footer.showLine,
      tipHeaderLeft: c.header.leftTip,
      tipHeaderMiddle: c.header.middleTip,
      tipHeaderRight: c.header.rightTip,
      tipFooterLeft: c.footer.leftTip,
      tipFooterMiddle: c.footer.middleTip,
      tipFooterRight: c.footer.rightTip,
      titleMode: c.title.mode,
      titleSize: c.title.size,
      titleSizeRelative: c.title.sizeRelative,
      titleFontWeight: c.title.fontWeight,
      titleLineHeight: c.title.lineHeight,
      titleSegmentType: c.title.segmentType,
      titleSegmentPosition: c.title.segmentPosition,
      titleSegmentDelimiter: c.title.segmentDelimiter,
      titleSubtitleScale: c.title.subtitleScale,
      titleSegmentSpacing: c.title.segmentSpacing,
      titleTopSpacing: c.title.topSpacing,
      titleBottomSpacing: c.title.bottomSpacing,
      titleFontFamily: titleFontFamily,
    );
  }

  String get layoutKey =>
      '${headerMode}_${footerMode}_${hideStatusBar}_'
      '${headerPaddingTop}_${headerPaddingBottom}_${headerPaddingLeft}_${headerPaddingRight}_'
      '${footerPaddingTop}_${footerPaddingBottom}_${footerPaddingLeft}_${footerPaddingRight}_'
      '${showHeaderLine}_${showFooterLine}_'
      '${tipHeaderLeft}_${tipHeaderMiddle}_${tipHeaderRight}_'
      '${tipFooterLeft}_${tipFooterMiddle}_${tipFooterRight}_'
      '${titleMode}_${titleSize}_${titleSizeRelative}_${titleFontWeight}_${titleLineHeight}_${titleTopSpacing}_$titleBottomSpacing'
      '_${titleSegmentType}_${titleSegmentPosition}_${titleSegmentDelimiter}_${titleSubtitleScale}_${titleSegmentSpacing}_$titleFontFamily';

  bool get showPageHeader {
    switch (headerMode.clamp(0, 2)) {
      case 1:
        return true;
      case 2:
        return false;
      default:
        return hideStatusBar;
    }
  }

  bool get showPageFooter => footerMode != 1;

  bool get hasHeaderTips =>
      tipHeaderLeft != 0 || tipHeaderMiddle != 0 || tipHeaderRight != 0;

  bool get hasFooterTips =>
      tipFooterLeft != 0 || tipFooterMiddle != 0 || tipFooterRight != 0;
}

class ReaderTipContext {
  final String bookName;
  final String chapterTitle;
  final int pageIndex;
  final int totalPages;
  final int? globalPageIndex;
  final int? globalTotalPages;
  final double readProgress;
  final int chapterIndex;
  final int chapterCount;
  final ValueListenable<int?>? battery;

  const ReaderTipContext({
    this.bookName = '',
    this.chapterTitle = '',
    required this.pageIndex,
    required this.totalPages,
    this.globalPageIndex,
    this.globalTotalPages,
    this.readProgress = 0,
    this.chapterIndex = 0,
    this.chapterCount = 0,
    this.battery,
  });

  int? get batteryLevel {
    final level = battery?.value;
    return level != null && level >= 0 && level <= 100 ? level : null;
  }

  String get batteryText => batteryLevel == null ? '—' : '$batteryLevel%';

  String get time {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String get pageText => '${pageIndex + 1}';
  String get totalPagesText => '$totalPages';
  String get readProgressText => '${(readProgress * 100).toStringAsFixed(1)}%';
  String get chapterText => chapterCount > 0 ? '${chapterIndex + 1}' : '';
  String get totalChaptersText => chapterCount > 0 ? '$chapterCount' : '';
}

String readerLegacyTipText(int tip, ReaderTipContext ctx) {
  switch (tip) {
    case 7:
      return ctx.bookName;
    case 1:
      return ctx.chapterTitle;
    case 2:
      return ctx.time;
    case 3:
      return '';
    case 10:
      return ctx.batteryText;
    case 4:
      return '${ctx.pageText}/${ctx.totalPagesText}';
    case 5:
      return ctx.readProgressText;
    case 11:
      if (ctx.chapterCount <= 0) return '';
      return '${ctx.chapterText}/${ctx.totalChaptersText}';
    case 6:
      return '${ctx.pageText}/${ctx.totalPagesText}  ${ctx.readProgressText}';
    case 8:
      return ctx.time;
    case 9:
      return '${ctx.time} ${ctx.batteryText}';
    default:
      return '';
  }
}

bool readerTipShowsBatteryIcon(int tip) => tip == 3;

class ReaderPageTipBar extends StatelessWidget {
  final bool avoidDisplayCorners;
  final bool avoidTopCorners;
  final int footerColumn, footerColumns;
  final EdgeInsets padding;
  final int leftTip;
  final int middleTip;
  final int rightTip;
  final ReaderTipContext tipContext;
  final Color textColor;
  final bool showDivider;
  final bool dividerOnTop;

  const ReaderPageTipBar({
    super.key,
    required this.padding,
    required this.leftTip,
    required this.middleTip,
    required this.rightTip,
    required this.tipContext,
    required this.textColor,
    this.showDivider = false,
    this.dividerOnTop = false,
    this.avoidDisplayCorners = false,
    this.avoidTopCorners = false,
    this.footerColumn = 0,
    this.footerColumns = 1,
  });

  static const _tipStyle = TextStyle(fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final battery = tipContext.battery;
    if (battery == null ||
        ![leftTip, middleTip, rightTip].any(const {3, 8, 9, 10}.contains)) {
      return _buildContents(context);
    }
    // 只监听提示子树；正文和相邻章预览无需重建或重新分页。— Codex + UI
    return ValueListenableBuilder<int?>(
      valueListenable: battery,
      builder: (context, _, _) => _buildContents(context),
    );
  }

  Widget _buildContents(BuildContext context) {
    // 同行重复提示只渲染首项，布局仍保留三个对齐槽位。— Codex + UI
    final seen = <int>{};
    final tips = [
      for (final tip in [leftTip, middleTip, rightTip])
        tip == 0 || seen.add(tip) ? tip : 0,
    ];
    final color = textColor.withValues(alpha: 0.55);
    final lineHeight = ReaderPageLayoutMetrics.measureTipBarHeight(
      context: context,
      padding: EdgeInsets.zero,
    );
    final extra = avoidDisplayCorners || avoidTopCorners
        ? ReaderFooterGeometry.maybeOf(context)?.extraInsets(
                padding: padding,
                lineHeight: lineHeight,
                column: footerColumn,
                columns: footerColumns,
                header: avoidTopCorners,
              ) ??
              EdgeInsets.zero
        : EdgeInsets.zero;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: textColor.withValues(alpha: 0.12),
    );

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDivider && dividerOnTop) divider,
          SizedBox(
            height: lineHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final limit = math.max(0.0, constraints.maxWidth / 3 - 1);
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: math.min(extra.left, limit),
                        ),
                        child: _slot(tips[0], color, Alignment.centerLeft),
                      ),
                    ),
                    Expanded(child: _slot(tips[1], color, Alignment.center)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: math.min(extra.right, limit),
                        ),
                        child: _slot(tips[2], color, Alignment.centerRight),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (showDivider && !dividerOnTop) divider,
        ],
      ),
    );
  }

  Widget _slot(int tip, Color color, Alignment alignment) {
    if (tip == 0) return const SizedBox.shrink();
    if (tip == 8) {
      return Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tipContext.time, style: _tipStyle.copyWith(color: color)),
              const SizedBox(width: 6),
              ReaderBatteryIcon(level: tipContext.batteryLevel, color: color),
            ],
          ),
        ),
      );
    }
    if (readerTipShowsBatteryIcon(tip)) {
      return Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ReaderBatteryIcon(
            level: tipContext.batteryLevel,
            color: color,
          ),
        ),
      );
    }
    final text = readerLegacyTipText(tip, tipContext);
    if (text.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _tipStyle.copyWith(color: color),
      ),
    );
  }
}

class ReaderPageLayoutMetrics {
  static const _tipStyle = TextStyle(fontSize: 12);

  static double measureTipBarHeight({
    required EdgeInsets padding,
    required BuildContext context,
  }) {
    final environment = TextLayoutEnvironment.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: '汉0',
        style: environment.baseStyle
            .merge(_tipStyle)
            .copyWith(
              fontWeight: MediaQuery.boldTextOf(context)
                  ? FontWeight.bold
                  : environment.baseStyle.fontWeight,
            ),
      ),
      textDirection: environment.direction,
      textScaler: environment.textScaler,
      locale: environment.locale,
      textHeightBehavior: environment.heightBehavior,
    )..layout();
    final line = math.max(14.0, painter.height);
    painter.dispose();
    return padding.top + padding.bottom + line;
  }

  static double headerBlockHeight(
    BuildContext context,
    ReaderPageChromeConfig chrome,
  ) {
    if (!chrome.showPageHeader || !chrome.hasHeaderTips) return 0;
    return measureTipBarHeight(
          context: context,
          padding: EdgeInsets.fromLTRB(
            chrome.headerPaddingLeft,
            chrome.headerPaddingTop,
            chrome.headerPaddingRight,
            chrome.headerPaddingBottom,
          ),
        ) +
        (chrome.showHeaderLine ? 1 : 0);
  }

  static double footerBlockHeight(
    BuildContext context,
    ReaderPageChromeConfig chrome,
  ) {
    if (chrome.showPageFooter && chrome.hasFooterTips) {
      return measureTipBarHeight(
            context: context,
            padding: EdgeInsets.fromLTRB(
              chrome.footerPaddingLeft,
              chrome.footerPaddingTop,
              chrome.footerPaddingRight,
              chrome.footerPaddingBottom,
            ),
          ) +
          (chrome.showFooterLine ? 1 : 0);
    }
    return 0;
  }
}
