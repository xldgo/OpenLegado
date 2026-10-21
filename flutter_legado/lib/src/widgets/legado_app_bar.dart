import '../theme/app_surface_material.dart';
import 'app_surface_backdrop.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';

import '../providers/ui_settings/ui_settings_notifier.dart';
import '../features/home/presentation/home_screen.dart';
import 'top_bar_button.dart';
import 'ui_settings_scope.dart';

/// Legado 统一顶栏
///
/// 对齐 Android [TitleBar] / 子 Activity `displayHomeAsUp` 语义：
///
/// - **主 Tab 内页**（[HomeScreen] 子树）：不显示返回（原版 Fragment 无 Up）
/// - **独立 push 子页**：左侧 M3 返回（[Symbols.arrow_back_rounded]）
/// - **禁止** Material 默认 `automaticallyImplyLeading` 误注入返回
///
/// 传入 [leading] 时完全尊重调用方（批量模式关闭钮、文件浏览上级等）。
/// [MD3 Batch 1] 视觉随 appTheme M3 化（tonal 抬升/前景 onSurface），
/// LargeTitle 折叠顶栏随各主 Tab 根页所在批次落地。
/// [UI_SYNC_REFACTOR B2] actions/leading 统一经 TopBarActionStyler 注入
/// 5 档按钮样式与 merge 胶囊（设置即时全局生效）；背景按 topBarBackgroundOpacity
/// 混入透明度；显式 [actionsStyle]/[mergeActions] 参数可覆盖全局设置。
/// 从页面内 [UiSettingsScope] 订阅顶栏设置，独立使用时沿用默认值。
class LegadoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LegadoAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.primary = true,
    this.centerTitle,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.toolbarHeight,
    this.leadingWidth,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.forceMaterialTransparency,

    /// 显式控制返回；null 时按 Tab 根 / Navigator.canPop 推断
    this.showBack,

    /// 覆盖全局顶栏按钮样式（null = 跟随主题设置）
    this.actionsStyle,

    /// 覆盖全局 merge 胶囊开关（null = 跟随主题设置）
    this.mergeActions,
  });

  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final double? scrolledUnderElevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final bool primary;
  final bool? centerTitle;
  final bool excludeHeaderSemantics;
  final double? titleSpacing;
  final double toolbarOpacity;
  final double bottomOpacity;
  final double? toolbarHeight;
  final double? leadingWidth;
  final TextStyle? toolbarTextStyle;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool? forceMaterialTransparency;
  final bool? showBack;
  final TopBarButtonStyle? actionsStyle;
  final bool? mergeActions;

  /// 是否应在 leading 区展示返回（Tab 根页 false；可 pop 子页 true）
  static bool shouldShowBack(BuildContext context, {bool? showBack}) {
    if (showBack != null) return showBack;
    if (context.findAncestorWidgetOfExactType<HomeScreen>() != null) {
      return false;
    }
    return Navigator.of(context).canPop();
  }

  Widget? _buildLeading(
    BuildContext context, {
    required TopBarButtonStyle style,
  }) {
    if (leading != null) {
      return TopBarActionStyler.styleActions(
        context,
        [leading!],
        style: style,
        merge: false,
      ).first;
    }
    if (!shouldShowBack(context, showBack: showBack)) return null;
    return TopBarActionStyler.styleActions(
      context,
      [
        IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
      style: style,
      merge: false,
    ).first;
  }

  /// 标题防截断保护：Text 标题单行 + FittedBox 自适应缩放，
  /// 窄屏/系统字体放大时完整显示标题（不出现半个字/省略号）；
  /// 空间充足时沿用主题标题字号，展开/折叠由组件选择不同字阶。
  Widget? _safeTitle(Widget? title) {
    if (title is Text) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          title.data ?? '',
          style: title.style,
          textAlign: title.textAlign,
          maxLines: 1,
        ),
      );
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final (bar, material) = _toolbar(context);
    return AppSurfaceBackdrop(material: material, child: bar);
  }

  /// 展开高度由标题本身决定，标题、页签和正文距离只由共用组件计算。— Codex + UI
  Widget buildSliver(
    BuildContext context, {
    required bool large,
    bool scrolledUnder = false,
  }) {
    final (bar, material) = _toolbar(context);
    final toolbar = bar.toolbarHeight ?? kToolbarHeight;
    final safeTop = bar.primary ? MediaQuery.paddingOf(context).top : 0.0;
    final bottomHeight = bar.bottom?.preferredSize.height ?? 0.0;
    final pinnedHeight = safeTop + toolbar + bottomHeight;
    final expandedTitle = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.34,
      child: DefaultTextStyle(
        style:
            bar.titleTextStyle ??
            Theme.of(context).textTheme.headlineMedium!.copyWith(
              color:
                  bar.foregroundColor ??
                  Theme.of(context).appBarTheme.foregroundColor ??
                  Theme.of(context).colorScheme.onSurface,
            ),
        // 两种尺寸原型由框架测量，不发布状态或等待下一帧回填高度。
        child: Semantics(
          header: !bar.excludeHeaderSemantics,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppHeaderSpacing.horizontal,
              vertical: AppHeaderSpacing.titleVertical,
            ),
            child: bar.title,
          ),
        ),
      ),
    );
    return AppSliverSurfaceBackdrop(
      material: material,
      child: SliverResizingHeader(
        minExtentPrototype: SizedBox(height: pinnedHeight),
        maxExtentPrototype: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: safeTop + toolbar),
            if (large) expandedTitle,
            SizedBox(height: bottomHeight),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final titleHeight = (height - pinnedHeight).clamp(
              0.0,
              double.infinity,
            );
            final collapsed = !large || titleHeight < 0.01;
            return FlexibleSpaceBar.createSettings(
              minExtent: pinnedHeight,
              maxExtent: height,
              currentExtent: height,
              isScrolledUnder: scrolledUnder || (large && collapsed),
              child: AppBar(
                automaticallyImplyLeading: false,
                leading: bar.leading,
                title: AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: bar.title,
                ),
                actions: bar.actions,
                flexibleSpace: large
                    ? Column(
                        children: [
                          SizedBox(height: safeTop + toolbar),
                          Expanded(
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.bottomLeft,
                                minHeight: 0,
                                maxHeight: double.infinity,
                                child: expandedTitle,
                              ),
                            ),
                          ),
                          SizedBox(height: bottomHeight),
                        ],
                      )
                    : bar.flexibleSpace,
                bottom: bar.bottom == null
                    ? null
                    : PreferredSize(
                        preferredSize: bar.bottom!.preferredSize,
                        child: SizedBox(
                          width: double.infinity,
                          child: bar.bottom,
                        ),
                      ),
                elevation: bar.elevation,
                scrolledUnderElevation: bar.scrolledUnderElevation,
                shadowColor: bar.shadowColor,
                surfaceTintColor: bar.surfaceTintColor,
                shape: bar.shape,
                backgroundColor: bar.backgroundColor,
                foregroundColor: bar.foregroundColor,
                iconTheme: bar.iconTheme,
                actionsIconTheme: bar.actionsIconTheme,
                primary: bar.primary,
                centerTitle: bar.centerTitle,
                excludeHeaderSemantics: bar.excludeHeaderSemantics,
                titleSpacing: bar.titleSpacing,
                toolbarHeight: toolbar,
                leadingWidth: bar.leadingWidth,
                toolbarTextStyle: bar.toolbarTextStyle,
                titleTextStyle: bar.titleTextStyle,
                systemOverlayStyle: bar.systemOverlayStyle,
                forceMaterialTransparency: bar.forceMaterialTransparency,
              ),
            );
          },
        ),
      ),
    );
  }

  (AppBar, AppSurfaceMaterial) _toolbar(BuildContext context) {
    final ui = UiSettingsScope.of(context, UiSettingsAspect.topBar);
    final style = actionsStyle ?? ui.topBarButtonStyle;
    final merge = mergeActions ?? ui.mergeTopBarActions;
    var bg =
        backgroundColor ??
        Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final material = AppSurfaceMaterial.topBar(color: bg, settings: ui);
    bg = material.color;
    final isLight =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.light;
    final effectiveOverlay =
        systemOverlayStyle ??
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        );

    final bar = AppBar(
      leading: _buildLeading(context, style: style),
      automaticallyImplyLeading: false,
      title: _safeTitle(title),
      actions: TopBarActionStyler.styleActions(
        context,
        actions,
        style: style,
        merge: merge,
      ),
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColor,
      surfaceTintColor:
          surfaceTintColor ??
          (material.color.a < 1 ? Colors.transparent : null),
      shape: shape,
      backgroundColor: bg,
      foregroundColor: foregroundColor,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      primary: primary,
      centerTitle: centerTitle,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: titleSpacing,
      toolbarOpacity: toolbarOpacity,
      bottomOpacity: bottomOpacity,
      toolbarHeight: toolbarHeight,
      leadingWidth: leadingWidth,
      toolbarTextStyle: toolbarTextStyle,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle: effectiveOverlay,
      forceMaterialTransparency: forceMaterialTransparency ?? false,
    );
    return (bar, material);
  }

  @override
  Size get preferredSize {
    final h = toolbarHeight ?? kToolbarHeight;
    if (bottom != null) {
      return Size.fromHeight(h + bottom!.preferredSize.height);
    }
    return Size.fromHeight(h);
  }
}

/// 根页直接使用CustomScrollView时的顶栏入口，与AppScaffold共用同一实现。
/// 展开范围由标题真实高度决定，折叠后只保留工具行及页签。
class LegadoTabRootHeaderSliver extends StatefulWidget {
  final Widget title;
  final List<Widget>? actions;
  final bool large;
  final double? titleSpacing;

  /// 顶栏 bottomContent（对齐参考仓 DynamicTopAppBar 搜索行；pinned 常驻）
  final PreferredSizeWidget? bottom;

  /// 覆盖全局顶栏按钮样式（null = 跟随主题设置 topBarButtonStyle）。
  /// 未指定时沿用共用按钮样式与合并设置。
  final TopBarButtonStyle? actionsStyle;

  /// 工具栏 leading（返回钮等）。null = 无 leading（Tab 根页默认）。
  /// push 子页传返回 IconButton（对齐 [LegadoAppBar] 子页语义；
  /// [台账 4-1 ① | 2.0.274] TXT 目录规则页复用本 sliver 需保留返回入口）。
  final Widget? leading;

  const LegadoTabRootHeaderSliver({
    super.key,
    required this.title,
    this.actions,
    required this.large,
    this.titleSpacing,
    this.bottom,
    this.actionsStyle,
    this.leading,
  });

  @override
  State<LegadoTabRootHeaderSliver> createState() =>
      _LegadoTabRootHeaderSliverState();
}

class _LegadoTabRootHeaderSliverState extends State<LegadoTabRootHeaderSliver> {
  @override
  Widget build(BuildContext context) {
    final ui = UiSettingsScope.of(context, UiSettingsAspect.topBar);
    // 书架与普通页使用同一套展开高度、固定工具栏和按钮布局。— Codex + UI
    return LegadoAppBar(
      showBack: false,
      leading: widget.leading,
      title: widget.title,
      actions: widget.actions,
      bottom: widget.bottom,
      titleSpacing: widget.titleSpacing,
      actionsStyle: widget.actionsStyle,
    ).buildSliver(context, large: widget.large && ui.useFlexibleTopAppBar);
  }
}

/// 静态标题根页的可折叠 LargeTitle 装配（NestedScrollView）
///
/// body 保持原滚动结构不变（内层 ListView/CustomScrollView 均可），
/// 头部复用自适应标题栏。用于无复杂顶栏状态的根页。
class LegadoLargeTitleScroll extends StatefulWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget body;

  const LegadoLargeTitleScroll({
    super.key,
    required this.title,
    this.actions,
    required this.body,
  });

  @override
  State<LegadoLargeTitleScroll> createState() => _LegadoLargeTitleScrollState();
}

class _LegadoLargeTitleScrollState extends State<LegadoLargeTitleScroll> {
  @override
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (context, innerBoxIsScrolled) => [
      LegadoTabRootHeaderSliver(
        title: widget.title,
        actions: widget.actions,
        large: true,
      ),
    ],
    body: widget.body,
  );
}

/// 页眉附近的公共间距，页面不再单独叠加列表顶部留白。— Codex + UI
abstract final class AppHeaderSpacing {
  static const double horizontal = 16;
  static const double titleVertical = 8;
  static const double content = 8;
}
