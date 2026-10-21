import 'package:material_ui/material_ui.dart';

import 'dynamic_search_app_bar.dart';
import 'app_search_transition.dart';
import 'legado_app_bar.dart';
import 'ui_settings_scope.dart';

/// Legado 统一页壳（对齐参考版 `AppScaffold` 语义的轻量子集）
///
/// [GLOBALCOMP B4] 参考版 `AppScaffold`（59 文件引用）是统一页壳：HazeState
/// 模糊采样 + 液态玻璃 backdrop + 背景图透明化 + edge-to-edge + snackbarHost
/// + FAB 位。本项目走「主题层统一」，其中多数语义已由既有基建承担，本壳
/// **不重复实现**，仅提供结构收敛点：
///
/// - **背景**：由 `ThemeData.scaffoldBackgroundColor` 统一供给（app_theme）。
///   设置背景图时 app.dart 将其置为透明以露出全局壁纸层（P1-8），故
///   [backgroundColor] 默认 null（跟随主题），**勿在无特殊语义处硬编码色值**。
/// - **系统栏**：`SystemBarBinder`（app.dart 单点）统一同步状态栏/导航栏；
///   顶栏透明度/毛玻璃由 `LegadoAppBar` 承担。
/// - **snackbarHost**：MaterialApp 级 ScaffoldMessenger 已提供全局宿主
///   （跨页 SnackBar 归位），等价参考版 `snackbarHost` 语义，无需页壳参数。
/// - **玻璃采样**：材质组件负责；本壳只将 [extendBody] 传给 Scaffold。
///
/// 参数面对齐参考版命名：[topBar]≈`topBar`、[bottomBar]≈`bottomBar`、
/// [floatingActionButton]≈`floatingActionButton(+Position)`、[body] 承载
/// `content`。**只收敛主流形态**（appBar+body，可带底栏/FAB/背景色，
/// 盘点占比 60/70）；`extendBodyBehindAppBar`/`drawer`/
/// `resizeToAvoidBottomInset` 等非主流参数不提供，需要时用原生 Scaffold
/// 并在统一批台账登记。
///
/// **永久排除域（裁决 2026-10-01）**：reader_screen/reader_comic_screen
/// （阅读器承重域）、video_screen（播放器条件全屏域）、book_info_screen
/// （折叠 SliverAppBar+FAB 定位承重）、
/// classic_login_dialog（对话框内嵌壳）——上述文件维持原生 Scaffold，
/// 不迁移。
///
/// 普通文字标题和动态搜索标题由NestedScrollView协调自适应可折叠顶栏；
/// 无标题、输入框式标题和专用页面保留标准顶栏。搜索动画共用同一占位进度。
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.topBar,
    this.bottomBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBody = false,
    this.collapsibleTopBar = true,
  });

  /// 普通文字顶栏接入协调滚动；专用顶栏直通Scaffold.appBar，null表示页面自行布局头部。
  /// 典型值：LegadoAppBar、DynamicSearchAppBar（均为 PreferredSizeWidget）。
  final PreferredSizeWidget? topBar;

  /// 底栏（映射 `Scaffold.bottomNavigationBar`）。典型值：NavigationBar、
  /// 自绘底栏、SafeArea 包裹的批量操作条。
  final Widget? bottomBar;

  /// 页面主体（映射 `Scaffold.body`）。
  final Widget body;

  /// 悬浮操作钮（映射 `Scaffold.floatingActionButton`）。
  final Widget? floatingActionButton;

  /// FAB 位置（映射 `Scaffold.floatingActionButtonLocation`）。
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// 页背景色；null = 跟随主题（推荐；背景图透明策略依赖此项为 null）。
  final Color? backgroundColor;

  /// 正文是否延伸到底栏后方；调用方应为滚动内容保留尾部留白。
  final bool extendBody;

  /// 普通标题页共用大顶栏；编辑器、播放器等专用布局可明确保留紧凑形态。
  final bool collapsibleTopBar;

  @override
  Widget build(BuildContext context) {
    final bar = topBar;
    // 宿主层级固定，批量工具栏/搜索栏切换时不重建正文及滚动状态。
    return AppSearchTransition(
      expanded: bar is DynamicSearchAppBar && bar.expanded,
      builder: (context, progress) => _scaffold(
        context,
        bar is DynamicSearchAppBar ? bar.atProgress(progress) : bar,
      ),
    );
  }

  Widget _scaffold(BuildContext context, PreferredSizeWidget? bar) {
    final coordinated =
        collapsibleTopBar &&
        switch (bar) {
          DynamicSearchAppBar() => true,
          LegadoAppBar(title: Text(:final data)) => data?.isNotEmpty ?? false,
          _ => false,
        };
    final large = UiSettingsScope.of(
      context,
      UiSettingsAspect.topBar,
    ).useFlexibleTopAppBar;
    // 固定避让只包括顶栏；正文间距单独参与滚动，不固定截断正文视口。— Codex + UI
    final bodyTopInset = coordinated
        ? bar!.preferredSize.height +
              (bar is LegadoAppBar && !bar.primary
                  ? 0
                  : MediaQuery.paddingOf(context).top)
        : 0.0;
    return Scaffold(
      appBar: coordinated ? null : bar,
      bottomNavigationBar: bottomBar,
      body: coordinated
          ? NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: switch (bar) {
                    DynamicSearchAppBar() => bar.buildSliver(
                      context,
                      large: large,
                      scrolledUnder: innerBoxIsScrolled,
                    ),
                    LegadoAppBar() => bar.buildSliver(
                      context,
                      large: large,
                      scrolledUnder: innerBoxIsScrolled,
                    ),
                    _ => throw StateError('可折叠顶栏类型不匹配'),
                  },
                ),
                // 正文前置留白在顶栏材质之外，向上滚动后可完全离开视口。
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppHeaderSpacing.content),
                ),
              ],
              // 吸收固定顶栏的重叠后统一预留等高空间，既有ListView无需再包一层滚动。
              // 搜索栏与页签也计入；正文前置留白独立滚走，不参与固定避让。
              body: Padding(
                padding: EdgeInsets.only(top: bodyTopInset),
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: _AppNestedScrollBody(child: body),
                ),
              ),
            )
          : body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      backgroundColor: backgroundColor,
      extendBody: extendBody,
    );
  }
}

class _AppNestedScrollBody extends InheritedWidget {
  const _AppNestedScrollBody({required super.child});

  @override
  bool updateShouldNotify(_AppNestedScrollBody oldWidget) => false;
}

/// 显式控制器列表接入页壳的内层控制器，快速滚动条与正文始终使用同一个位置。
/// 无共用页壳时沿用页面自己的控制器，不复制滚动位置或手工转发滚动事件。— Codex + UI
class AppScrollBody extends StatelessWidget {
  const AppScrollBody({
    super.key,
    required this.controller,
    required this.builder,
  });

  final ScrollController controller;
  final Widget Function(BuildContext, ScrollController) builder;

  @override
  Widget build(BuildContext context) {
    final coordinated =
        context.dependOnInheritedWidgetOfExactType<_AppNestedScrollBody>() !=
        null;
    return builder(
      context,
      coordinated ? PrimaryScrollController.of(context) : controller,
    );
  }
}
