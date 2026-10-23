import '../../../../theme/app_typography.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import '../../../../domain/models/reader_settings.dart';
import '../../application/reader_state.dart';
import '../../widgets/reader_page_view.dart';
import '../../widgets/reader_page_chrome.dart';
import '../../widgets/reader_image_dominant_body.dart';
import '../../../../platform/display/display_corners.dart';
import '../../../../platform/display/display_cutout_insets.dart';
import '../../layout/reader_footer_geometry.dart';

/// 正文视口统一消费设置和实际系统边距，不负责加载或导航。— Codex + UI
class ReaderContentViewport extends StatelessWidget {
  const ReaderContentViewport({
    super.key,
    required this.state,
    required this.readingSettings,
    required this.bodyInsets,
    this.cutoutInsets,
    required this.pageViewKey,
    required this.imageDominant,
    required this.reviewCounts,
    required this.onTapUp,
    required this.onReviewTap,
    required this.onToggleControls,
    required this.onNextChapter,
    required this.onPreviousChapter,
    this.autoTurnPanel,
    this.displayCorners,
  });

  final ReaderState state;
  final ReaderSettings readingSettings;
  final EdgeInsets bodyInsets;
  final DisplayCutoutInsets? cutoutInsets;
  final DisplayCorners? displayCorners;
  final GlobalKey<ReaderPageViewState> pageViewKey;
  final bool imageDominant;
  final Map<int, int> reviewCounts;
  final GestureTapUpCallback onTapUp;
  final void Function(int, int) onReviewTap;
  final VoidCallback onToggleControls;
  final Future<void> Function() onNextChapter;
  final Future<void> Function() onPreviousChapter;
  final Widget? autoTurnPanel;

  @override
  Widget build(BuildContext context) {
    final book = state.currentBook;
    final textLayout = readingSettings.textLayout;
    final pageLayout = readingSettings.pageLayout;
    final screen = readingSettings.screen;
    final interaction = readingSettings.interaction;
    // 原生采样未就绪时保守使用安全区；明确返回零缺口后不再沿用此回退。
    final fallbackCutout = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => EdgeInsets.fromLTRB(
        bodyInsets.left,
        bodyInsets.bottom > 0 || bodyInsets.left > 0 || bodyInsets.right > 0
            ? bodyInsets.top
            : 0,
        bodyInsets.right,
        bodyInsets.bottom,
      ),
      TargetPlatform.android => bodyInsets,
      _ => EdgeInsets.zero,
    };
    final pageInsets = readerContentInsets(
      systemInsets: bodyInsets,
      cutoutInsets: cutoutInsets?.padding ?? fallbackCutout,
      hideStatusBar: screen.hideStatusBar,
      hideNavigationBar: screen.hideNavigationBar,
      avoidDisplayCutouts: screen.avoidDisplayCutouts,
    );
    final pageChrome = ReaderPageChromeConfig.fromSettings(
      pageLayout,
      hideStatusBar: screen.hideStatusBar,
      titleFontFamily: readingSettings.titleFontFamily,
    );
    final chromeInsets = readerChromeInsets(
      contentInsets: pageInsets,
      systemInsets: bodyInsets,
      extendPageTips: screen.avoidDisplayCutouts && screen.extendPageTips,
      hideStatusBar: screen.hideStatusBar,
      hideNavigationBar: screen.hideNavigationBar,
      centeredHeader:
          pageChrome.showPageHeader && pageChrome.tipHeaderMiddle != 0,
    );
    return Positioned.fill(
      child: MediaQuery.removeViewPadding(
        context: context,
        removeTop: true,
        removeLeft: true,
        removeRight: true,
        removeBottom: true,
        child: ReaderFooterGeometry(
          corners:
              displayCorners ??
              DisplayCorners.fallback(
                MediaQuery.sizeOf(context),
                bodyInsets,
                defaultTargetPlatform,
              ),
          child: ReaderBodyTypography(
            child: Stack(
              children: [
                if (!imageDominant)
                  GestureDetector(
                    onTapUp: onTapUp,
                    child: ReaderPageView(
                      onTapUp: onTapUp,
                      key: pageViewKey,
                      contentInsets: pageInsets,
                      chromeInsets: chromeInsets,
                      // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 用户反馈④：
                      // 阅读页头部补章节链接与书源名（书名在菜单顶栏）— Qoder
                      // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 书源名优先取 Book.originName
                      //（同步可靠），解析结果作兜底 — Qoder
                      // 排版使用共享不可变快照，渲染参数保持原单位。— Codex + UI
                      paragraphSpacing: textLayout.paragraphSpacing,
                      letterSpacing: textLayout.letterSpacing,
                      paragraphIndent: textLayout.paragraphIndent,
                      textFullJustify: textLayout.textFullJustify,
                      textBottomJustify: textLayout.textBottomJustify,
                      // [UI-fix v2.0.3 | 2026-08-06] 页面边距接入分页渲染 — Qoder
                      marginTop: pageLayout.bodyPadding.top,
                      marginBottom: pageLayout.bodyPadding.bottom,
                      marginLeft: pageLayout.bodyPadding.left,
                      marginRight: pageLayout.bodyPadding.right,
                      pageChrome: pageChrome,
                      // [UI-fix v2.0.3 | 2026-08-08] MoreConfig 第①批：长按选择
                      // 文本开关与滚动翻页无动画接入内容区 — Qoder
                      selectText: interaction.selectText,
                      noAnimScroll: interaction.noAnimScrollPage,
                      // [UI-fix v2.0.4 | 2026-08-08] 界面面板字重/自定义文字色与
                      // MoreConfig 第②批鼠标滚轮翻页接入内容区 — Qoder
                      textBold: textLayout.textBold,
                      // [C3 斜体 | Qoder UI] 斜体透传（参考版行内面板开关）
                      italic: textLayout.italic,
                      mouseWheelPage: interaction.mouseWheelPage,
                      // [UI-fix v2.0.5 | 2026-08-10] 双页模式档位透传（对标原版
                      // doubleHorizontalPage 0-3 档）— Reasonix
                      doubleHorizontalPage: pageLayout.doubleHorizontalPage,
                      // [UI-fix v2.0.5 | 2026-08-10] 中文分行开关透传（对标原版
                      // useZhLayout）— Reasonix
                      useZhLayout: textLayout.useZhLayout,
                      // [UI-fix v2.0.5 | 2026-08-10] 段首标点悬挂透传（对标原版
                      // hangingPunctuation）— Reasonix
                      hangingPunctuation: textLayout.hangingPunctuation,
                      reviewCounts: reviewCounts,
                      onReviewTap: onReviewTap,
                    ),
                  ),
                Padding(
                  padding: pageInsets,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageDominant)
                        ReaderImageDominantBody(
                          content: state.chapterContent,
                          book: book!,
                          imageStyle: book.readConfig?.imageStyle,
                          onToggleControls: onToggleControls,
                          hasNextChapter: state.hasNextChapter,
                          hasPrevChapter: state.hasPreviousChapter,
                          onNextChapter: onNextChapter,
                          onPrevChapter: onPreviousChapter,
                        ),
                      ?autoTurnPanel,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 正文测量和绘制共用独立基线，不继承应用界面字体。— Codex + UI
class ReaderBodyTypography extends StatelessWidget {
  const ReaderBodyTypography({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: AppTypography.lightTextTheme.bodyMedium!,
    child: child,
  );
}
