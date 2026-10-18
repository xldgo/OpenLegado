import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_typography.dart';
import 'app_sheet_theme.dart';
import 'md3_colors.dart';

/// 应用主题定义（Material Design 3 Expressive）
///
/// 集中管理按调色板装配的 light/dark ThemeData（UI_MD3_PLAN.md Batch 0）：
/// - 13 套内置 MD3 tonal 调色板（[Md3Palettes]，默认 def「默认」，
///   阶段D 2.0.270 对齐 kazusa 源码色值；WH 黑白等 12 套保留可切换）
///   + 用户自定义 4 色（themeConfigList 功能完整保留，
///   自定义已应用颜色优先于内置 palette role）
/// - Expressive 大圆角经 component theme 显式落地：卡片 20 / 控件 12 /
///   弹窗与底板 28（M3 shape scale 无单一 preset，见计划第七节映射）
/// - Tonal Surface 层次：surfaceContainerLow/Medium/High + 低 elevation
/// - 组件跟随 M3 默认规格（开关/复选框/滑块等不再覆写为 iOS 绿）
///
/// 使用方式：MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark)
class AppTheme {
  AppTheme._();

  /// 未覆写时的卡片 / 分组圆角；用户设置由调用方显式传入。
  static const double defaultCardRadius = 20.0;

  /// 圆角：输入框 / 菜单 / 小控件
  static const double _controlRadius = 12.0;

  /// 普通表单输入框统一使用四角 12dp 圆角。
  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(_controlRadius),
  );

  /// 圆角：弹窗 / 底部抽屉（M3 extraLarge 28）
  static const double _extraLargeRadius = 28.0;

  /// 亮色主题（默认调色板 def「默认」，阶段D 2.0.270 对齐 kazusa
  /// 「默认」源码色值；原 WH 回退路径语义保留——未知 paletteId 仍由
  /// Md3Palettes.byId 回退，未设自定义色时全量使用内置 palette role）
  static ThemeData get light =>
      palette(brightness: Brightness.light, palette: Md3Palettes.def);

  /// 暗色主题（默认调色板 def「默认」，暗色锚定 kazusa「黑白」套）
  static ThemeData get dark =>
      palette(brightness: Brightness.dark, palette: Md3Palettes.def);

  /// 亮色主题（支持用户自定义颜色，null 项回退内置默认 def）
  static ThemeData lightCustom({
    Color? primary,
    Color? accent,
    Color? background,
    Color? bottomBackground,
    double cardRadius = defaultCardRadius,
  }) {
    return palette(
      brightness: Brightness.light,
      palette: Md3Palettes.def,
      primary: primary,
      accent: accent,
      background: background,
      bottomBackground: bottomBackground,
      cardRadius: cardRadius,
    );
  }

  /// 暗色主题（支持用户自定义颜色，null 项回退内置默认 def）
  static ThemeData darkCustom({
    Color? primary,
    Color? accent,
    Color? background,
    Color? bottomBackground,
    double cardRadius = defaultCardRadius,
  }) {
    return palette(
      brightness: Brightness.dark,
      palette: Md3Palettes.def,
      primary: primary,
      accent: accent,
      background: background,
      bottomBackground: bottomBackground,
      cardRadius: cardRadius,
    );
  }

  // [UI-fix v2.0.5 | 2026-08-08] 自定义主题颜色支持：对齐原版
  // ThemeConfigFragment 日间/夜间 主色调/强调色/背景色/底部操作栏颜色，
  // 映射：colorPrimary→AppBar 背景（colorBackground 在未设置 primary 时
  // 同时作为 AppBar 背景回退）、colorAccent→全局 Tint+ColorScheme、
  // colorBackground→Scaffold 背景、colorBottomBackground→底部 TabBar 背景；
  // 进入自定义分支后 AppBar 前景一律按 _onColor(appBarBg) 动态计算，
  // 保证深色背景下标题可辨 — Qoder

  /// 按调色板装配主题（UI_MD3_PLAN.md Batch 0：paletteId + themeMode）
  ///
  /// 优先级规则（第九节）：自定义已应用的 4 色 > 内置 palette 对应 role；
  /// 四参数全为 null 时直接使用内置 palette scheme。
  static ThemeData palette({
    required Brightness brightness,
    required Md3Palette palette,
    bool amoledDark = false,
    Color? primary,
    Color? accent,
    Color? background,
    Color? bottomBackground,
    double cardRadius = defaultCardRadius,
  }) {
    var scheme = brightness == Brightness.light
        ? md3LightScheme(palette)
        : md3DarkScheme(palette);

    // 默认深色主题的页面底色已变暗，容器层次同步收敛，避免混用旧亮灰色。
    if (brightness == Brightness.dark && palette.id == 'def') {
      scheme = scheme.copyWith(
        surfaceContainerLowest: const Color(0xFF0B0F12),
        surfaceContainer: const Color(0xFF24282C),
        surfaceContainerHigh: const Color(0xFF2B2F34),
        surfaceContainerHighest: const Color(0xFF34383D),
        surfaceBright: const Color(0xFF393D42),
      );
    }

    // 纯黑模式统一应用于内置色板和参数化配色，自定义颜色仍按原有优先级覆盖。
    if (brightness == Brightness.dark && amoledDark) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF0A0A0A),
        surfaceContainerHigh: const Color(0xFF121212),
      );
    }

    if (primary == null &&
        accent == null &&
        background == null &&
        bottomBackground == null) {
      return _buildTheme(
        brightness: brightness,
        cardRadius: cardRadius,
        colorScheme: scheme,
        scaffoldBackground: scheme.surface,
        appBarBackground: scheme.surface,
        appBarForeground: scheme.onSurface,
        separator: scheme.outlineVariant,
        cardColor: brightness == Brightness.light
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainerLow,
        tabBarBg: scheme.surfaceContainer,
      );
    }

    // 自定义颜色覆盖 palette role：强调色 → primary/secondary/surfaceTint，
    // 背景色 → surface；主色调→AppBar 背景（未设时回退背景色）
    final tint = accent;
    if (tint != null) {
      scheme = scheme.copyWith(
        primary: tint,
        secondary: tint,
        onPrimary: _onColor(tint),
        surfaceTint: tint,
      );
    }
    if (background != null) {
      scheme = scheme.copyWith(surface: background);
    }
    final appBarBg = primary ?? background ?? scheme.surface;
    return _buildTheme(
      brightness: brightness,
      cardRadius: cardRadius,
      colorScheme: scheme,
      scaffoldBackground: background ?? scheme.surface,
      appBarBackground: appBarBg,
      // 前景一律按实际 AppBar 背景明暗动态计算（仅设背景色时同样生效，
      // 避免深色背景配固定深浅文字导致不可辨）
      appBarForeground: _onColor(appBarBg),
      separator: scheme.outlineVariant,
      cardColor: brightness == Brightness.light
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      tabBarBg: bottomBackground ?? scheme.surfaceContainer,
    );
  }

  /// 通过同一装配入口生成局部主题，避免组件继续引用旧配色中的显式颜色。
  static ThemeData withColorScheme(ThemeData base, ColorScheme scheme) {
    final themed = _buildTheme(
      brightness: scheme.brightness,
      cardRadius: defaultCardRadius,
      colorScheme: scheme,
      scaffoldBackground: scheme.surface,
      appBarBackground: scheme.surfaceContainerHigh,
      appBarForeground: scheme.onSurface,
      separator: scheme.outlineVariant,
      cardColor: scheme.surfaceContainerLow,
      tabBarBg: scheme.surfaceContainer,
    );
    return themed.copyWith(
      platform: base.platform,
      pageTransitionsTheme: base.pageTransitionsTheme,
      typography: base.typography,
      splashFactory: base.splashFactory,
      cupertinoOverrideTheme: base.cupertinoOverrideTheme,
      // 局部换色继承应用已解析的卡片形状，不再读取全局设置。
      cardTheme: themed.cardTheme.copyWith(shape: base.cardTheme.shape),
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      visualDensity: base.visualDensity,
      materialTapTargetSize: base.materialTapTargetSize,
      extensions: base.extensions.values,
    );
  }

  /// 根据背景明暗计算前景对比色（对齐原版 ColorUtils.isColorLight 逻辑）
  static Color _onColor(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.light
      ? Colors.black87
      : Colors.white;

  /// 构建 ThemeData 通用方法（MD3 Expressive 视觉层）
  static ThemeData _buildTheme({
    required Brightness brightness,
    required double cardRadius,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color appBarBackground,
    required Color appBarForeground,
    required Color separator,
    required Color cardColor,
    required Color tabBarBg,
  }) {
    final bool isLight = brightness == Brightness.light;
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerLow),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(4),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
      alignment: AlignmentDirectional.bottomStart,
    );

    return ThemeData(
      extensions: const [AppSheetTheme()],
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: AppTypography.lightTextTheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: separator,
      splashFactory: InkSparkle.splashFactory,

      // AppBar 主题 —— 标准 M3：surface 底 + onSurface 前景，滚动时 tonal 抬升
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: AppTypography.lightTextTheme.titleLarge?.copyWith(
          color: appBarForeground,
        ),
        toolbarTextStyle: AppTypography.lightTextTheme.bodyLarge?.copyWith(
          color: appBarForeground,
        ),
        // 浅色导航栏 → 深色状态栏图标；暗色导航栏 → 浅色状态栏图标
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          statusBarColor: Colors.transparent,
        ),
      ),

      // 底部导航栏主题 —— M3 NavigationBar（pill 指示器）
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 80,
        backgroundColor: tabBarBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // 卡片主题 —— tonal 分组容器（亮面用最低层容器，暗面抬一层）
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // 普通表单统一使用圆角填充和描边，聚焦与错误状态只改变边线。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        // 错误与禁用态由组件根据 border 的形状解析，兼容显式无边框输入。
        hintStyle: AppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: AppTypography.lightTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // ListTile 主题 —— M3 规格（图标 onSurfaceVariant）
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),

      // 分割线主题 —— M3 outlineVariant 1px
      dividerTheme: DividerThemeData(color: separator, thickness: 1, space: 1),

      // FloatingActionButton 主题
      // [LAYOUT_MOTION_AUDIT L1] 前景走 primary（HapeLee container=primaryContainer,
      // content=primary，非 M3 默认 onPrimaryContainer）
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.primary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Dialog 主题 —— Expressive extraLarge 大圆角
      // [LAYOUT_MOTION_AUDIT L1] 容器走 surfaceContainer（原 High 错一层）
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_extraLargeRadius),
        ),
      ),

      // BottomSheet 主题 —— Expressive 顶部大圆角
      // [LAYOUT_MOTION_AUDIT L1] 背景走 surfaceContainer + 抓手 onSurfaceVariant
      //（原 Low 错一层且 showDragHandle=false 关掉抓手）
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant,
      ),

      // TabBar 主题 —— M3 主色指示器
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTypography.lightTextTheme.titleSmall,
        unselectedLabelStyle: AppTypography.lightTextTheme.titleSmall,
        // 对齐依赖 isScrollable，由各 TabBar 或组件默认值决定。
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        largeSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),

      // Snackbar 主题 —— M3 inverseSurface 反色
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),

      // Tooltip 主题
      // [LAYOUT_MOTION_AUDIT L1] PlainTooltip 走 surfaceContainerLow/onSurface
      //（原 inverseSurface 为 Flutter 单方追加，原生无依据）
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 12),
      ),

      // 保留复选框形状，配色与交互状态由组件按当前 ColorScheme 解析。
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // 使用新版滑块默认配色，按用户设置取消圆形按压状态层。
      sliderTheme: SliderThemeData(
        // material_ui 1.6 仍默认旧 M3 外观，在统一主题入口启用新版。
        // ignore: deprecated_member_use
        year2023: false,
        overlayShape: SliderComponentShape.noOverlay,
      ),

      // SearchBar 主题 —— 容器 surfaceContainerLow（HapeLee M3 分支）
      // [LAYOUT_MOTION_AUDIT L1] 新增
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(
          colorScheme.surfaceContainerLow,
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        hintStyle: WidgetStateProperty.all(
          AppTypography.lightTextTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),

      menuTheme: MenuThemeData(style: menuStyle),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTypography.lightTextTheme.bodyMedium,
          ),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        ),
      ),
    );
  }
}
