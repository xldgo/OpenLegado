import '../../widgets/eye_protection_settings.dart';
import '../../providers/cover_provider.dart';
// [UI-fix v2.0.5 | 2026-08-08] 主题设置页对齐原版 pref_config_theme.xml +
// ThemeConfigFragment（24 项）：启动图标/欢迎页样式/沉浸式状态栏/沉浸式导航栏/
// 导航栏阴影/字体缩放/封面设置/主题列表/底栏皮肤/壁纸取色 ×2 +
// 白天/夜间 主色调/强调色/背景色/底栏色/背景图片/透明导航栏/保存主题。
// 颜色配置经 ThemeColorsNotifier 接入 MaterialApp ThemeData 即时生效；
// 尚未接入功能的选项禁用并说明后续开放；已生效的平台入口保持可用；
// 分组与设置行复用跨平台 SettingsGroup 和 SettingTile。
import '../../l10n/app_localization.dart';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/app_scaffold.dart';
import '../../widgets/legado_app_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../constants/pref_keys.dart';
import '../../domain/models/theme_colors_settings.dart';
import '../../providers/providers.dart';
import '../../providers/theme/system_bar_notifier.dart';
import '../../providers/theme/theme_colors_notifier.dart';
import '../../providers/theme/theme_notifier.dart';
import '../../providers/ui_settings/ui_settings_notifier.dart';
import '../../routes.dart';
import '../../services/launcher_icon_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/settings_widgets.dart';
import 'theme_actions.dart';
import 'appearance_settings_provider.dart';
import 'widgets/theme_preset_dialogs.dart';
import 'widgets/cover_rule_config_dialog.dart';
import 'widgets/theme_mode_selector.dart';
import 'widgets/builtin_palette_selector.dart';

/// 主题设置页面（对齐原版 ThemeConfigFragment）
///
/// 主题模式与全局字体缩放经 [ThemeNotifier] 全局实时生效；
/// 日间/夜间自定义颜色经 [ThemeColorsNotifier] 驱动 MaterialApp 即时生效。
class ThemeConfigScreen extends ConsumerStatefulWidget {
  const ThemeConfigScreen({super.key});

  @override
  ConsumerState<ThemeConfigScreen> createState() => _ThemeConfigScreenState();
}

class _ThemeConfigScreenState extends ConsumerState<ThemeConfigScreen> {
  SettingsService get _settings => ref.read(settingsProvider);

  bool _loading = true;

  // ===== 通用组状态（对齐原版顶部无分组项）=====
  String get _launcherIcon =>
      ref.read(appearanceSettingsRepositoryProvider).current.launcherIcon;
  int _barElevation = 0;
  bool _wallpaperColorAutoUpdate = true;

  /// 颜色选择器预设色板（对齐原版 ColorPreference cpv_dialogType="preset"）
  static const _presetColors = [
    0xFFD32F2F,
    0xFFF44336,
    0xFFE91E63,
    0xFF9C27B0,
    0xFF673AB7,
    0xFF3F51B5,
    0xFF2196F3,
    0xFF03A9F4,
    0xFF00BCD4,
    0xFF009688,
    0xFF4CAF50,
    0xFF8BC34A,
    0xFFCDDC39,
    0xFFFFEB3B,
    0xFFFFC107,
    0xFFFF9800,
    0xFFFF5722,
    0xFF795548,
    0xFF9E9E9E,
    0xFF607D8B,
    0xFF000000,
    0xFF212121,
    0xFF424242,
    0xFFFAFAFA,
    0xFFFFFFFF,
  ];

  /// 启动图标可选值（对齐原版 arrays.xml icon_names）
  static const _launcherIcons = [
    'iconMain',
    'icon1',
    'icon2',
    'icon3',
    'icon4',
    'icon5',
    'icon6',
  ];

  static const _launcherIconLabels = [
    '默认',
    '图标 1',
    '图标 2',
    '图标 3',
    '图标 4',
    '图标 5',
    '图标 6',
  ];

  /// 暂未接线的设置统一说明，禁用不改写原有偏好。
  static const _pendingFeature = '待实现';

  static String _pendingDescription(String description) =>
      '$description\n$_pendingFeature';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载持久化偏好（键名对齐原版 PreferKey）
  Future<void> _loadSettings() async {
    try {
      await ref.read(appearanceSettingsRepositoryProvider).load();
    } catch (error) {
      _toast('外观设置读取失败，请重试');
    }
    final barElevation = await _settings.getIntPref(
      PrefKeys.barElevation,
      defaultValue: 0,
    );
    final wallpaperColorAutoUpdate = await _settings.getBoolPref(
      PrefKeys.wallpaperColorAutoUpdate,
      defaultValue: true,
    );
    if (!mounted) return;
    setState(() {
      _barElevation = barElevation;
      _wallpaperColorAutoUpdate = wallpaperColorAutoUpdate;
      _loading = false;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveAppearance(Future<void> Function() save) async {
    try {
      await save();
    } on AppearanceSyncException catch (error) {
      debugPrint('外观设置已保存，主题同步失败：${error.cause}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('设置已保存，主题同步失败'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () {
              _saveAppearance(
                ref.read(themeNotifierProvider.notifier).synchronizeRuntime,
              );
            },
          ),
        ),
      );
    } catch (error) {
      debugPrint('外观设置保存失败：$error');
      _toast('保存失败，请重试');
    }
  }

  // ===== [UI_SYNC_REFACTOR B2] 顶栏与布局开关 =====

  String _topBarStyleLabel(TopBarButtonStyle s) => switch (s) {
    TopBarButtonStyle.plain => '平面',
    TopBarButtonStyle.tonal => 'Tonal（默认）',
    TopBarButtonStyle.outlined => '描边',
    TopBarButtonStyle.glass => '玻璃',
    TopBarButtonStyle.liquidGlass => '液态玻璃',
  };

  Future<void> _showTopBarOpacityDialog() async {
    var value = ref.read(uiSettingsProvider).topBarOpacity.toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.l10n.themeTopBarOpacity),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${value.round()}%',
                onChanged: (v) => setDialogState(() => value = v),
              ),
              Text('当前 ${value.round()}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _saveAppearance(
        () => ref
            .read(uiSettingsProvider.notifier)
            .setTopBarOpacity(value.round()),
      );
    }
  }

  String _labelModeLabel(BottomBarLabelMode m) => switch (m) {
    BottomBarLabelMode.auto => '仅选中显示（默认）',
    BottomBarLabelMode.labeled => '全部常显',
    BottomBarLabelMode.unlabeled => '纯图标',
  };

  Future<void> _showBottomBarOpacityDialog() async {
    var value = ref.read(uiSettingsProvider).bottomBarOpacity.toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.l10n.themeBottomBarOpacity),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${value.round()}%',
                onChanged: (v) => setDialogState(() => value = v),
              ),
              Text('当前 ${value.round()}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _saveAppearance(
        () => ref
            .read(uiSettingsProvider.notifier)
            .setBottomBarOpacity(value.round()),
      );
    }
  }

  String _tabletLabel(TabletInterfaceMode m) => switch (m) {
    TabletInterfaceMode.auto => '自动（宽屏 ≥600dp）',
    TabletInterfaceMode.always => '始终启用侧栏',
    TabletInterfaceMode.landscape => '仅横屏启用',
    TabletInterfaceMode.off => '不启用',
  };

  static const _themeStyleOptions = <String, String>{
    'none': '关闭（内置色板）',
    'tonalSpot': 'Tonal Spot（默认）',
    'neutral': 'Neutral',
    'vibrant': 'Vibrant',
    'expressive': 'Expressive',
    'fidelity': 'Fidelity',
    'content': 'Content',
    'rainbow': 'Rainbow',
    'fruitSalad': 'Fruit Salad',
    'monochrome': 'Monochrome',
  };

  static const _contrastOptions = <String, String>{
    '0.0': 'Default（默认）',
    '0.5': 'Medium（中）',
    '1.0': 'High（高）',
  };

  static const _coverBackgroundOptions = <String, String>{
    'on': '模糊显示（默认）',
    'off': '显示封面（不模糊）',
    'off_for_default': '隐藏（仅默认封面档）',
  };

  Future<void> _showCardRadiusDialog() async {
    final uiNow = ref.read(uiSettingsProvider);
    var override = uiNow.overrideBaseCardCornerRadius;
    var radius = uiNow.baseCardCornerRadius.toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(ctx.l10n.themeBaseCardCornerRadius),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingSwitchRow(
                title: '覆写主题圆角',
                value: override,
                onChanged: (v) => setDialogState(() => override = v),
              ),
              Slider(
                value: radius,
                min: 4,
                max: 28,
                divisions: 12,
                label: '${radius.round()}dp',
                onChanged: (v) => setDialogState(() => radius = v),
              ),
              Text('当前 ${radius.round()}dp（随主题重建生效）'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _saveAppearance(
        () => ref
            .read(uiSettingsProvider.notifier)
            .setCardRadius(override: override, radius: radius.round()),
      );
    }
  }

  Future<void> _showBlurRadiusDialog({
    required String title,
    required int currentRadius,
    required int currentAlpha,
    required Future<void> Function(int radius, int alpha) onSave,
  }) async {
    var radius = currentRadius.toDouble();
    var alpha = currentAlpha.toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('模糊半径 ${radius.round()}dp'),
              Slider(
                value: radius,
                min: 0,
                max: 48,
                divisions: 12,
                onChanged: (v) => setDialogState(() => radius = v),
              ),
              Text('底色透明度 ${alpha.round()}/255'),
              Slider(
                value: alpha,
                min: 0,
                max: 255,
                divisions: 51,
                onChanged: (v) => setDialogState(() => alpha = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _saveAppearance(() => onSave(radius.round(), alpha.round()));
    }
  }

  Future<void> _showTopBarBlurDialog() async {
    final uiNow = ref.read(uiSettingsProvider);
    final notifier = ref.read(uiSettingsProvider.notifier);
    await _showBlurRadiusDialog(
      title: '顶栏模糊',
      currentRadius: uiNow.topBarBlurRadius,
      currentAlpha: uiNow.topBarBlurAlpha,
      onSave: (radius, alpha) =>
          notifier.setTopBarBlur(radius: radius, alpha: alpha),
    );
  }

  Future<void> _showBottomBarBlurDialog() async {
    final uiNow = ref.read(uiSettingsProvider);
    final notifier = ref.read(uiSettingsProvider.notifier);
    await _showBlurRadiusDialog(
      title: '悬浮底栏模糊',
      currentRadius: uiNow.bottomBarBlurRadius,
      currentAlpha: uiNow.bottomBarBlurAlpha,
      onSave: (radius, alpha) =>
          notifier.setBottomBarBlur(radius: radius, alpha: alpha),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    ref.watch(appearanceSettingsProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final colors = ref.watch(themeColorsProvider);
    final ui = ref.watch(uiSettingsProvider);
    final systemBars = ref.watch(systemBarProvider);

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      // [队列⑦c A3] 页标题对齐参考 R.string.theme_setting=外观
      topBar: LegadoAppBar(title: Text(context.l10n.appearance)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SettingsBody(
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 32),
                children: [
                  // === [2.0.269 用户裁决] 外观预览卡已移除（C6 批 b03c2ba444 低优
                  // 增强建议产物，无独立用户授权记录；与配色轮同类，严格红线） ===
                  // === [2.0.268 用户裁决] 配色轮卡已移除（B3-C1 A2 系误判证据
                  // 产物，kazusa 源码无此能力，严格红线）；长按预设主色调选择
                  // 器本体（_showColorPicker，色卡行在用）保留不动 ===
                  // === [队列⑦c A3] IA 对齐参考版 ThemeConfigScreen.kt ===
                  // 分组 1「主题模式」（参考 R.string.theme=主题模式：主题模式
                  // 选择器 + 13 内置色卡同行）。[队列⑦c A3] 恢复页内主题模式
                  // 选择器——此前 2026-08-13 裁决"主题模式仅放「我的」枢纽"，
                  // 本次按参考 IA 指令恢复页内展示；复用既有 ThemeMode 状态与
                  // ThemeNotifier.setThemeMode，非新增功能。
                  // 原「主题导出/导入」独立分区并入下方通用组（对齐参考主题管理
                  // 同簇）；[B3-C1 A3] 导出/导入能力保留不动。
                  SettingsGroup(
                    title: context.l10n.themeMode,
                    children: [
                      // 参考 ThemeModeSelector（:974-1012）material 引擎分支：
                      // 跟随系统 / 浅色 / 深色（flow_sys/light_mode/dark_mode）
                      ThemeModeSelector(
                        selected: themeState.themeMode,
                        onChanged: (mode) => _saveAppearance(
                          () => themeNotifier.setThemeMode(mode),
                        ),
                      ),
                      // 13 套内置 MD3 preset 选择器（UI_MD3_PLAN.md Batch 1，
                      // [队列⑦a A2] 13 色卡横滑一行形态；paletteId 持久化，
                      // 与自定义主题并存——第九节并存模型）
                      BuiltinPaletteSelector(
                        selectedId: themeState.paletteId,
                        onSelected: (id) => _saveAppearance(
                          () => themeNotifier.setPaletteId(id),
                        ),
                      ),
                    ],
                  ),
                  // === 分组 2「主题引擎」（我方 MD3 参数化：paletteStyle +
                  // 对比度；参考版无对应分组——参考"主题风格"=compose 引擎
                  // 开关，属参考独有，仅登记不实现）。[队列⑦c A3] AMOLED 纯黑
                  // 移出本组，改入通用组首位（对齐参考 纯黑深色模式 首位） ===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: '主题引擎',
                    children: [
                      SettingMenuRow<String>(
                        title: '配色风格',
                        value: ui.themeStyle,
                        options: _themeStyleOptions,
                        onChanged: (value) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setThemeStyle(value),
                        ),
                      ),
                      if (ui.themeStyle != 'none')
                        SettingMenuRow<String>(
                          title: '对比度',
                          value: ui.themeContrastLevel,
                          options: _contrastOptions,
                          onChanged: (value) => _saveAppearance(
                            () => ref
                                .read(uiSettingsProvider.notifier)
                                .setThemeContrastLevel(value),
                          ),
                        ),
                    ],
                  ),

                  // === 分组 3 通用（卡片内标题与其他设置页统一；
                  // 参考顺序 纯黑→切换图标→字体大小→主题管理→背景图片；
                  // 参考独有 字体设置/自定义颜色/compose 引擎/预见性返回手势
                  // 仅登记不实现） ===
                  // [队列⑦c A3] 通用组排序：纯黑深色模式（自主题引擎移入，
                  // 对齐参考 纯黑 首位）→ 切换图标 → 字体大小 → 主题管理
                  // （原主题列表改名）→ 导出/导入主题（原顶部分区并入）→ 其余
                  // 我方项保持原有相对顺序
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: '通用',
                    children: [
                      // 纯黑深色模式（参考 pure_black=纯黑深色模式；原"AMOLED
                      // 纯黑"，标题对齐参考，副标题保留）
                      SettingSwitchRow(
                        title: context.l10n.themePureBlack,
                        subtitle: '暗色模式背景纯黑（省电护屏）',
                        value: ui.themeAmoled,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setThemeAmoled(v),
                        ),
                      ),
                      // 切换图标（参考 change_icon=切换图标，摘要
                      // change_icon_summary=切换软件显示在桌面的图标；
                      // Android/iOS 支持，Windows 等桌面端整项隐藏）
                      if (LauncherIconService.isSupported)
                        SettingMenuRow<String>(
                          title: context.l10n.themeChangeIcon,
                          subtitle: context.l10n.themeChangeIconSummary,
                          value: _launcherIcon,
                          options: {
                            for (var i = 0; i < _launcherIcons.length; i++)
                              _launcherIcons[i]: _launcherIconLabels[i],
                          },
                          valuePreview: _launcherIconPreview(
                            _launcherIcon,
                            size: 32,
                          ),
                          optionBuilder: (value, label) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _launcherIconPreview(value),
                              const SizedBox(width: 12),
                              Text(label),
                            ],
                          ),
                          onChanged: _setLauncherIcon,
                        ),
                      // 字体大小（参考 font_scale=字体大小；摘要半角冒号对齐
                      // font_scale_summary「当前字体大小: %.1f」，见 theme_state）
                      SettingTile(
                        title: context.l10n.fontSize,
                        subtitle: themeState.fontScaleLabel,
                        onTap: () => _showFontScalePicker(
                          context,
                          themeState,
                          themeNotifier,
                        ),
                      ),
                      // 主题管理（参考 theme_pack=主题管理；原"主题列表"改名，
                      // 副标题保留；参考完整主题包管理屏属参考独有，仅登记）
                      SettingTile(
                        title: context.l10n.themeManagement,
                        subtitle: context.l10n.themeManagementDescription,
                        onTap: _showThemeListDialog,
                      ),
                      // 导出/导入主题（[B3-C1 A3] 复用 ThemeColorsNotifier +
                      // ThemeNotifier，全部经主题槽位，无硬编码色值）
                      SettingTile(
                        icon: Symbols.ios_share_rounded,
                        title: '导出主题',
                        subtitle: '将当前配色导出为 JSON 文件',
                        onTap: _exportTheme,
                      ),
                      SettingTile(
                        icon: Symbols.download_rounded,
                        title: context.l10n.themeImportTheme,
                        subtitle: '导入主题 JSON 文件并应用',
                        onTap: _importTheme,
                      ),
                      SettingTile(
                        title: context.l10n.themeWelcomeStyle,
                        subtitle: '设定显示时间，更改背景图片，是否显示文字等',
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.welcomeConfig);
                        },
                      ),
                      SettingSwitchRow(
                        title: context.l10n.themeImmersionStatusBar,
                        subtitle: context.l10n.themeStatusBarImmersion,
                        value: systemBars.transparentStatusBar,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(systemBarProvider.notifier)
                              .setTransparentStatusBar(v),
                        ),
                      ),
                      SettingSwitchRow(
                        title: context.l10n.themeImmNavigationBar,
                        subtitle:
                            context.l10n.themeImmersiveNavigationDescription,
                        value: systemBars.immNavigationBar,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(systemBarProvider.notifier)
                              .setImmNavigationBar(v),
                        ),
                      ),
                      SettingTile(
                        title: context.l10n.themeBarElevation,
                        subtitle: _pendingDescription(
                          '当前阴影大小（elevation）：$_barElevation',
                        ),
                        enabled: false,
                      ),
                      SettingTile(
                        title: context.l10n.themeCoverConfig,
                        subtitle: context.l10n.themeCoverConfigSummary,
                        onTap: _showCoverConfigDialog,
                      ),
                      SettingTile(
                        title: '底栏图集',
                        subtitle: '导入 zip 自定义底栏图标',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.bottomBarSkin,
                        ),
                      ),
                      SettingSwitchRow(
                        title: '跟随壁纸配色',
                        subtitle: '使用系统壁纸色板生成日间和夜间主题（Android 12+/iOS）',
                        value: ui.wallpaperColorFollow,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setWallpaperColorFollow(v),
                        ),
                      ),
                      if (ui.wallpaperColorFollow)
                        SettingSwitchRow(
                          title: '壁纸变化时自动更新',
                          subtitle: _pendingDescription('系统壁纸变化后自动应用新色板'),
                          value: _wallpaperColorAutoUpdate,
                        ),
                    ],
                  ),

                  // === 分组 4「主界面」（参考 R.string.main_activity=主界面；
                  // [队列⑦c A3] 合并原"顶栏与布局"+"底栏与导航"两组为参考的单
                  // 主界面组，设置经 uiSettings 即时全局生效；参考 首页与导航/
                  // 显示状态栏/启用滑动时动画 属参考独有，仅登记不实现） ===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: context.l10n.advancedMainScreen,
                    children: [
                      SettingMenuRow<TopBarButtonStyle>(
                        title: context.l10n.themeTopBarButtonStyle,
                        value: ui.topBarButtonStyle,
                        options: {
                          for (final value in TopBarButtonStyle.values)
                            value: _topBarStyleLabel(value),
                        },
                        onChanged: (value) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setTopBarButtonStyle(value),
                        ),
                      ),
                      SettingSwitchRow(
                        title: context.l10n.themeMergeTopBarActions,
                        subtitle: '顶栏按钮收进胶囊容器',
                        value: ui.mergeTopBarActions,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setMergeTopBarActions(v),
                        ),
                      ),
                      SettingSwitchRow(
                        title: '大顶栏形态',
                        subtitle: '书架/我的等根页使用可折叠大标题',
                        value: ui.useFlexibleTopAppBar,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setUseFlexibleTopAppBar(v),
                        ),
                      ),
                      SettingTile(
                        title: context.l10n.themeTopBarOpacity,
                        subtitle: '当前 ${ui.topBarOpacity}%',
                        onTap: _showTopBarOpacityDialog,
                      ),
                      SettingSwitchRow(
                        title: '显示底栏',
                        subtitle: '隐藏后仅侧栏/手势切页',
                        value: ui.showBottomView,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setShowBottomView(v),
                        ),
                      ),
                      SettingSwitchRow(
                        title: context.l10n.themeFloatingBottomBar,
                        subtitle: '64dp 胶囊悬浮形态（ Experimental）',
                        value: ui.useFloatingBottomBar,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setUseFloatingBottomBar(v),
                        ),
                      ),
                      SettingMenuRow<BottomBarLabelMode>(
                        title: '底栏文字',
                        value: ui.labelVisibilityMode,
                        options: {
                          for (final value in BottomBarLabelMode.values)
                            value: _labelModeLabel(value),
                        },
                        onChanged: (value) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setLabelVisibilityMode(value),
                        ),
                      ),
                      SettingTile(
                        title: context.l10n.themeBottomBarOpacity,
                        subtitle: '当前 ${ui.bottomBarOpacity}%',
                        onTap: _showBottomBarOpacityDialog,
                      ),
                      // 大屏导航形态（参考 main_activity 组 tabletInterface=平板界面；
                      // 四档 自动/始终/仅横屏/关闭）
                      SettingMenuRow<TabletInterfaceMode>(
                        title: '大屏导航形态',
                        value: ui.tabletInterface,
                        options: {
                          for (final value in TabletInterfaceMode.values)
                            value: _tabletLabel(value),
                        },
                        onChanged: (value) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setTabletInterface(value),
                        ),
                      ),
                    ],
                  ),

                  // === 分组 5「书籍详情页」（参考 R.string.book_info_page=
                  // 书籍详情页；原"详情与圆角"的封面三行；卡片圆角/分隔线移入
                  // 下方"容器设置"组） ===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: context.l10n.themeBookInfoPage,
                    children: [
                      // 参考 book_info_follow_cover_color=界面颜色跟随封面取色，
                      // 摘要 book_info_follow_cover_color_s=仅在显示背景封面时生效
                      SettingSwitchRow(
                        title: context.l10n.themeBookInfoFollowCoverColor,
                        subtitle:
                            context.l10n.themeBookInfoFollowCoverColorSummary,
                        value: ui.bookInfoFollowCoverColor,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setBookInfoFollowCoverColor(v),
                        ),
                      ),
                      // 参考 book_info_network_cover_background=网络封面背景设置
                      SettingMenuRow<String>(
                        title: context.l10n.themeBookInfoNetworkCoverBackground,
                        value: ui.bookInfoNetworkCoverBackground,
                        options: _coverBackgroundOptions,
                        onChanged: (value) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setBookInfoCoverBackground(
                                isDefaultCover: false,
                                value: value,
                              ),
                        ),
                      ),
                      // 参考 book_info_default_cover_background=默认封面背景设置
                      SettingMenuRow<String>(
                        title: context.l10n.themeBookInfoDefaultCoverBackground,
                        value: ui.bookInfoDefaultCoverBackground,
                        options: _coverBackgroundOptions,
                        onChanged: (value) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setBookInfoCoverBackground(
                                isDefaultCover: true,
                                value: value,
                              ),
                        ),
                      ),
                    ],
                  ),

                  // === 分组 8「容器设置」（参考 R.string
                  // .theme_manage_section_container=容器设置；原"详情与圆角"的
                  // 卡片圆角/分隔线两行；参考 容器背景图/容器背景不透明度/
                  // 关闭设置分组圆角/覆盖卡片边框/边框粗细/日夜卡片边框颜色/
                  // 分割线粗细/长度/颜色 等子项属参考独有，仅登记不实现） ===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: context.l10n.themeContainerSettings,
                    children: [
                      // 参考 base_card_corner_radius=卡片圆角（0-40 滑杆）；我方为
                      // 单对话框（覆写开关 + 4-28），参考 覆盖卡片圆角 双行开关
                      // 结构属参考独有，仅登记
                      SettingTile(
                        title: context.l10n.themeBaseCardCornerRadius,
                        subtitle: ui.overrideBaseCardCornerRadius
                            ? '覆写中：${ui.baseCardCornerRadius}dp'
                            : '跟随主题（20dp）',
                        onTap: _showCardRadiusDialog,
                      ),
                      // 参考 show_divider_line=显示分隔线
                      SettingSwitchRow(
                        title: context.l10n.readerShowDivider,
                        subtitle: '分组列表行底部显示短分隔线',
                        value: ui.enableItemDivider,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setEnableItemDivider(v),
                        ),
                      ),
                    ],
                  ),

                  // === 分组 7「模糊效果」（参考 R.string.blur_effects=模糊效果；
                  // [队列⑦c A3] 原"毛玻璃"改组名对齐参考；我方 启用毛玻璃 +
                  // 顶栏/悬浮底栏模糊参数，参考 启用控件模糊/启用渐变模糊 开关
                  // 结构属参考独有，仅登记；默认关——低端机掉帧保护） ===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: context.l10n.themeBlurEffects,
                    children: [
                      SettingSwitchRow(
                        title: '启用毛玻璃',
                        subtitle: '低端设备开启可能掉帧',
                        value: ui.enableBlur,
                        onChanged: (v) => _saveAppearance(
                          () => ref
                              .read(uiSettingsProvider.notifier)
                              .setEnableBlur(v),
                        ),
                      ),
                      if (ui.enableBlur) ...[
                        SettingTile(
                          title: '顶栏模糊',
                          subtitle:
                              '半径 ${ui.topBarBlurRadius}dp · 底色 ${ui.topBarBlurAlpha}/255',
                          onTap: _showTopBarBlurDialog,
                        ),
                        SettingTile(
                          title: '悬浮底栏模糊',
                          subtitle:
                              '半径 ${ui.bottomBarBlurRadius}dp · 底色 ${ui.bottomBarBlurAlpha}/255',
                          onTap: _showBottomBarBlurDialog,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),
                  const EyeProtectionSettingsGroup(),

                  // === 自定义主题·白天（对齐原版 day category，themeConfigList
                  // 功能完整保留——UI_MD3_PLAN.md 第九节） ===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: '自定义主题 · 白天',
                    children: [
                      _colorTile(
                        ThemeColorRole.primary,
                        context.l10n.themePrimary,
                        colors,
                      ),
                      _colorTile(
                        ThemeColorRole.accent,
                        context.l10n.themeAccent,
                        colors,
                      ),
                      _colorTile(
                        ThemeColorRole.background,
                        context.l10n.bgColor,
                        colors,
                        isBackground: true,
                      ),
                      _colorTile(
                        ThemeColorRole.bottomBackground,
                        context.l10n.themeNavbarColor,
                        colors,
                      ),
                      SettingTile(
                        icon: Symbols.wallpaper_rounded,
                        title: context.l10n.themeBackgroundImage,
                        subtitle: colors.bgImage.isEmpty
                            ? '未设置'
                            : colors.bgImage,
                        onTap: () => _showBgImageDialog(PrefKeys.bgImage),
                      ),
                      SettingSwitchRow(
                        title: '透明导航栏',
                        subtitle: _pendingDescription('仅 Android 生效'),
                        value: systemBars.transparentNavBar,
                      ),
                      SettingTile(
                        icon: Symbols.save_rounded,
                        title: '保存白天主题',
                        subtitle: '将当前白天颜色保存到主题列表',
                        onTap: () => _saveTheme(isNight: false),
                      ),
                    ],
                  ),

                  // === 自定义主题·夜间（对齐原版 night category）===
                  const SizedBox(height: 16),
                  SettingsGroup(
                    title: '自定义主题 · 夜间',
                    children: [
                      _colorTile(
                        ThemeColorRole.primaryNight,
                        context.l10n.themePrimary,
                        colors,
                        isNight: true,
                      ),
                      _colorTile(
                        ThemeColorRole.accentNight,
                        context.l10n.themeAccent,
                        colors,
                        isNight: true,
                      ),
                      _colorTile(
                        ThemeColorRole.backgroundNight,
                        context.l10n.bgColor,
                        colors,
                        isNight: true,
                        isBackground: true,
                      ),
                      _colorTile(
                        ThemeColorRole.bottomBackgroundNight,
                        context.l10n.themeNavbarColor,
                        colors,
                        isNight: true,
                      ),
                      SettingTile(
                        icon: Symbols.wallpaper_rounded,
                        title: context.l10n.themeBackgroundImage,
                        subtitle: colors.bgImageNight.isEmpty
                            ? '未设置'
                            : colors.bgImageNight,
                        onTap: () => _showBgImageDialog(PrefKeys.bgImageN),
                      ),
                      SettingSwitchRow(
                        title: '透明导航栏',
                        subtitle: _pendingDescription('仅 Android 生效'),
                        value: systemBars.transparentNavBarNight,
                      ),
                      SettingTile(
                        icon: Symbols.save_rounded,
                        title: '保存夜间主题',
                        subtitle: '将当前夜间颜色保存到主题列表',
                        onTap: () => _saveTheme(isNight: true),
                      ),
                    ],
                  ),
                  const SettingsSectionFooter('背景图片将作为全局窗口壁纸显示（分组列表卡片保持不透明底）'),
                ],
              ),
            ),
    );
  }

  /// 颜色配置行（值为空时显示"默认"，否则显示色块）
  Widget _colorTile(
    ThemeColorRole role,
    String title,
    ThemeColorsSettings colors, {
    bool isNight = false,
    bool isBackground = false,
  }) {
    final value = colors.color(role);
    return SettingTile(
      icon: Symbols.palette_rounded,
      title: title,
      showChevron: false,
      value: value == null ? '默认' : null,
      trailing: value == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Color(value),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
      onTap: () => _showColorPicker(
        role,
        title,
        isNight: isNight,
        isBackground: isBackground,
      ),
    );
  }

  /// 预设色板选择器（对齐原版 ColorPreference preset 对话框 + 背景明暗校验）
  Future<void> _showColorPicker(
    ThemeColorRole role,
    String title, {
    required bool isNight,
    required bool isBackground,
  }) async {
    final selected = await showDialog<(int?,)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _presetColors)
                InkWell(
                  onTap: () => Navigator.pop(ctx, (c,)),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          // 对齐原版长按恢复默认：清除自定义值
          TextButton(
            onPressed: () => Navigator.pop(ctx, (null,)),
            child: Text(ctx.l10n.themeRestoreDefault),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
        ],
      ),
    );
    // [UI-fix v2.0.5 | 2026-08-08] 异步对话框返回后统一补 mounted 防护，
    // 避免页面已销毁时继续使用 ref/setState — Qoder
    if (selected == null || !mounted) return;
    // 对齐原版 onColorSelected 背景明暗校验（白天背景过暗/夜间背景过亮拒绝）
    final color = selected.$1;
    if (isBackground && color != null) {
      final isLight =
          ThemeData.estimateBrightnessForColor(Color(color)) ==
          Brightness.light;
      if (!isNight && !isLight) {
        _toast('白天背景不能太暗');
        return;
      }
      if (isNight && isLight) {
        _toast('夜间背景不能太亮');
        return;
      }
    }
    await _saveAppearance(
      () => ref.read(themeColorsProvider.notifier).setColor(role, color),
    );
  }

  /// 预览复用现有原生图标图片，保持选项与实际图标对应。
  Widget _launcherIconPreview(String icon, {double size = 36}) {
    final name = _launcherIcons.contains(icon) ? icon : 'iconMain';
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/images/launcher_$name.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }

  /// 沿用现有 Android/iOS 切换与结果提示。
  Future<void> _setLauncherIcon(String selected) async {
    if (!mounted) return;
    try {
      await ref
          .read(appearanceSettingsRepositoryProvider)
          .update((current) => current.copyWith(launcherIcon: selected));
    } catch (error) {
      _toast('图标设置保存失败，请重试');
      return;
    }
    if (!mounted) return;
    // 下发原生侧实际切换（Android setComponentEnabledSetting /
    // iOS setAlternateIconName）；失败时提示真实原因，不阻断偏好保存
    final result = await LauncherIconService.setIcon(selected);
    if (!mounted) return;
    if (result.ok) {
      if (LauncherIconService.isIos) {
        _toast('图标已切换，重启应用后生效');
      }
    } else {
      // 展示原生侧真实错误（如 iOS"本次启动已切换过一次"、Android API<26），
      // 不再笼统提示"当前平台或系统版本不支持"
      _toast(result.message ?? '当前平台或系统版本不支持更换图标');
    }
  }

  /// 未接线偏好只展示已保存值；封面规则查询入口保持可用。
  Future<void> _showCoverConfigDialog() async {
    final onlyWifi = await _settings.getBoolPref(
      PrefKeys.loadCoverOnlyWifi,
      defaultValue: false,
    );
    final useDefault = await _settings.getBoolPref(
      PrefKeys.useDefaultCover,
      defaultValue: false,
    );
    final showName = await _settings.getBoolPref(
      PrefKeys.coverShowName,
      defaultValue: true,
    );
    final showAuthor = await _settings.getBoolPref(
      PrefKeys.coverShowAuthor,
      defaultValue: true,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.themeCoverConfig),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (title, value) in [
                ('仅 Wifi 加载封面', onlyWifi),
                ('优先使用默认封面', useDefault),
                ('默认封面显示书名', showName),
                ('默认封面显示作者', showAuthor),
              ])
                SettingSwitchRow(
                  contentPadding: EdgeInsets.zero,
                  title: title,
                  subtitle: _pendingFeature,
                  value: value,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ctx.l10n.themeCoverRule),
                subtitle: const Text('配置搜索 URL 与提取规则，可按书名测试'),
                onTap: _showCoverRuleConfigDialog,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.close),
          ),
        ],
      ),
    );
  }

  /// 封面规则配置对话框（契约 §2.4 F4；对齐原版 CoverRuleConfigDialog）
  Future<void> _showCoverRuleConfigDialog() async {
    final repository = ref.read(coverRuleRepositoryProvider);
    final search = ref.read(coverSearchServiceProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => CoverRuleConfigDialog(
        loadRule: repository.getCoverRule,
        saveRule: repository.saveCoverRule,
        deleteRule: repository.deleteCoverRule,
        onSearch: search.searchCoverRules,
      ),
    );
  }

  ThemeActions get _themeActions => ref.read(themeActionsProvider);

  Future<void> _showThemeListDialog() async {
    try {
      final actions = _themeActions;
      final presets = await actions.readPresets();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ThemePresetListDialog(
          presets: presets,
          onDelete: actions.removePresetAt,
          onApply: (preset) async {
            await actions.applyPreset(preset);
            _toast('已应用主题「${preset.name}」');
          },
          onError: (_) => _showThemePresetError(),
        ),
      );
    } catch (error) {
      _toast('主题操作失败：$error');
    }
  }

  Future<void> _showThemePresetError() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('操作失败'),
      content: const Text('主题操作失败，请重试'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.confirm),
        ),
      ],
    ),
  );

  Future<void> _saveTheme({required bool isNight}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => ThemePresetNameDialog(isNight: isNight),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await _themeActions.savePreset(name, isNight: isNight);
      _toast('已保存主题「$name」');
    } catch (error) {
      _toast('保存失败：$error');
    }
  }

  Future<void> _exportTheme() async {
    try {
      if (await _themeActions.exportTheme()) _toast('主题已导出');
    } catch (error) {
      _toast('导出失败：$error');
    }
  }

  Future<void> _importTheme() async {
    try {
      final document = await _themeActions.readThemeFile();
      if (document == null || !mounted) return;
      await _themeActions.applyDocument(document);
      _toast('主题已导入');
    } on FormatException {
      _toast('导入失败：主题文件格式不正确');
    } catch (error) {
      _toast('导入失败：$error');
    }
  }

  /// 背景图片选择/删除（对齐原版 backgroundImage；经 ThemeColorsNotifier
  /// 驱动 MaterialApp 全局壁纸即时生效）
  Future<void> _showBgImageDialog(String key) async {
    final isNight = key == PrefKeys.bgImageN;
    final colors = ref.read(themeColorsProvider);
    final current = isNight ? colors.bgImageNight : colors.bgImage;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l10n.themeBackgroundImage),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'select'),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(ctx.l10n.themeSelectImage),
            ),
          ),
          if (current.isNotEmpty)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(ctx.l10n.delete),
              ),
            ),
        ],
      ),
    );
    // 异步对话框/文件选择器返回后先检查页面生命周期，再更新偏好。
    if (!mounted) return;
    if (action != 'select' && action != 'delete') return;
    try {
      final path = action == 'delete'
          ? ''
          : await ref.read(themeFileServiceProvider).selectBackgroundImage();
      if (path == null || !mounted) return;
      final notifier = ref.read(themeColorsProvider.notifier);
      if (isNight) {
        await notifier.setBgImage(night: path);
      } else {
        await notifier.setBgImage(day: path);
      }
    } catch (error) {
      _toast('背景图片操作失败：$error');
    }
  }

  /// 全局字体缩放选择（对齐原版 ThemeConfigFragment fontScale NumberPickerDialog）
  ///
  /// 原版取值 8~16（0.8x~1.6x），「默认」按钮重置为 0（跟随系统）。
  void _showFontScalePicker(
    BuildContext context,
    ThemeState themeState,
    ThemeNotifier notifier,
  ) {
    // 跟随系统时默认展示 1.0x
    var current = themeState.fontScaleRaw.toDouble();
    if (current < 8 || current > 16) current = 10;
    var saving = false;
    String? failure;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> save(int raw) async {
            if (saving) return;
            setDialogState(() {
              saving = true;
              failure = null;
            });
            try {
              await notifier.setFontScale(raw);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (error) {
              debugPrint('字体缩放保存失败：$error');
              if (ctx.mounted) {
                setDialogState(() {
                  saving = false;
                  failure = '保存失败，请重试';
                });
              }
            }
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: const Text('字体缩放'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '当前字体大小: ${(current / 10).toStringAsFixed(1)}',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: current,
                    min: 8,
                    max: 16,
                    divisions: 8,
                    label: (current / 10).toStringAsFixed(1),
                    onChanged: saving
                        ? null
                        : (v) => setDialogState(() => current = v),
                  ),
                  if (failure != null)
                    Text(
                      failure!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => save(0),
                  child: Text(ctx.l10n.themeSystem),
                ),
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: Text(ctx.l10n.cancel),
                ),
                FilledButton(
                  onPressed: saving ? null : () => save(current.round()),
                  child: Text(ctx.l10n.confirm),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
