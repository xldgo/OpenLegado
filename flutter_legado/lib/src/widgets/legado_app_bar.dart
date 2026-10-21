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

  /// 普通页壳与可折叠页壳共用按钮、配色和系统栏配置。— Codex + UI
  Widget buildSliver(
    BuildContext context, {
    required bool large,
    bool scrolledUnder = false,
    double? expandedHeight,
  }) {
    final (bar, material) = _toolbar(context);
    final create = large ? SliverAppBar.large : SliverAppBar.new;
    final toolbar = bar.toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bar.bottom?.preferredSize.height ?? 0;
    final expanded = expandedHeight ?? toolbar + 56 + bottomHeight;
    return SliverLayoutBuilder(
      builder: (context, constraints) => AppSliverSurfaceBackdrop(
        material: material,
        child: create(
          pinned: true,
          // NestedScrollView将后续位移交给内层，外层不再产生overlapsContent。
          // 使用协调器的真实滚动状态，保证折叠标题显现，而非依赖外层继续滚动。
          // 刚好折叠到边界（包括空列表）也必须显示标题，不能等下一次超出位移。
          forceElevated:
              scrolledUnder ||
              (large &&
                  constraints.scrollOffset >=
                      expanded - toolbar - bottomHeight),
          // 工具行与标题行各占56dp；不沿用large默认152dp的额外空白。
          expandedHeight: large ? expanded : null,
          collapsedHeight: large
              ? toolbar +
                    bottomHeight +
                    (bar.primary ? MediaQuery.paddingOf(context).top : 0)
              : null,
          automaticallyImplyLeading: false,
          leading: bar.leading,
          title: bar.title,
          actions: bar.actions,
          flexibleSpace: bar.flexibleSpace,
          bottom: bar.bottom,
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
/// 展开增加56dp标题带，折叠后只保留工具行及页签；开关关闭时使用紧凑栏。
class LegadoTabRootHeaderSliver extends StatefulWidget {
  final Widget title;
  final List<Widget>? actions;
  final bool large;
  final double? titleSpacing;

  /// 顶栏 bottomContent（对齐参考仓 DynamicTopAppBar 搜索行；pinned 常驻）
  final PreferredSizeWidget? bottom;

  /// 可选展开高度，不含状态栏、包含bottom；默认工具行+56dp标题带+bottom。
  final double? expandedHeight;

  /// 覆盖全局顶栏按钮样式（null = 跟随主题设置 topBarButtonStyle）。
  /// [parity C3 B5] 书架头部按参考锁定裸图标（plain），不经全局档位。
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
    this.expandedHeight,
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
    ).buildSliver(
      context,
      large: widget.large && ui.useFlexibleTopAppBar,
      expandedHeight: widget.expandedHeight,
    );
  }
}

/// 静态标题根页的可折叠 LargeTitle 装配（NestedScrollView）
///
/// body 保持原滚动结构不变（内层 ListView/CustomScrollView 均可），
/// 头部为 SliverAppBar.large。用于「我的」等无复杂顶栏状态的根页。
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
