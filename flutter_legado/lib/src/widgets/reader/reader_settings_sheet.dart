import '../../providers/reader/reader_config_provider.dart';
import '../../models/reader_advanced_config.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localization.dart';
import '../../providers/reader/reader_notifier.dart';
import '../../providers/ui_settings/ui_settings_notifier.dart';
import '../../providers/ui_settings/eye_protection_notifier.dart';
import '../../routes.dart';
import '../../screens/reader_config_panel.dart';
import '../app_scaffold.dart';
import '../legado_app_bar.dart';
import '../settings_widgets.dart';
import '../eye_protection_settings.dart';
import 'reader_tip_config_sheet.dart';

part 'reader_settings_sheet_font_panel.part.dart';

// 字体设置复用既有管理入口，与主文件共享配置提交方法。

/// 完整阅读设置的分组；快捷面板复用同一套控件与配置。
enum ReaderSettingsCategory {
  typography('字体与排版', '字体、字号、行距与段落样式', Icons.text_fields),
  background('背景与配色', '正文背景、阅读菜单与护眼模式', Icons.palette_outlined),
  layout('页面布局', '正文边距、章节标题、页眉与页脚', Icons.crop_free),
  interaction('翻页与操作', '翻页动画、点击区域与自动翻页', Icons.auto_stories_outlined),
  content('内容处理', '简繁转换与自动换源', Icons.article_outlined),
  screen('屏幕与工具栏', '亮度、系统栏、状态条与菜单工具栏', Icons.phone_android);

  const ReaderSettingsCategory(this.title, this.summary, this.icon);
  final String title;
  final String summary;
  final IconData icon;
}

/// 阅读中的快捷面板与独立阅读设置页。
class ReaderSettingsSheet extends ConsumerStatefulWidget {
  const ReaderSettingsSheet({super.key, this.fullPage = false, this.category});

  final bool fullPage;
  final ReaderSettingsCategory? category;

  static Future<void> showPage(
    BuildContext context, {
    ReaderSettingsCategory? category,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReaderSettingsSheet(fullPage: true, category: category),
      ),
    );
  }

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: MediaQuery.sizeOf(context).height < 500 ? 0.95 : 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: const ReaderSettingsSheet(),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderSettingsSheet> createState() =>
      _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends ConsumerState<ReaderSettingsSheet> {
  /// 翻页动画标签（顺序对齐原版 page_anim 数组）
  Map<PageTurnMode, String> get _flipLabels => {
    PageTurnMode.cover: context.l10n.coverMode,
    PageTurnMode.slide: context.l10n.readerSlide,
    PageTurnMode.simulate: context.l10n.readerSimulation,
    PageTurnMode.scroll: context.l10n.readerScroll,
    PageTurnMode.none: context.l10n.noneMode,
  };

  /// 自定义配色对话框可选色板（自绘色块网格，不引入 pub 依赖）
  static const List<Color> _palette = [
    Color(0xFFFFFFFF),
    Color(0xFFF5F5DC),
    Color(0xFFE8E0C8),
    Color(0xFFCCEBCC),
    Color(0xFFD4A574),
    Color(0xFFC8E6C9),
    Color(0xFFB3E5FC),
    Color(0xFFFFF9C4),
    Color(0xFFFFCCBC),
    Color(0xFFE1BEE7),
    Color(0xFF90A4AE),
    Color(0xFF616161),
    Color(0xFF37474F),
    Color(0xFF263238),
    Color(0xFF1A1A1A),
    Color(0xFF000000),
  ];

  /// 持久化和即时更新统一交给共享配置入口。
  void _commitAdv(ReaderAdvancedConfig cfg) {
    ref.read(readerAdvConfigProvider.notifier).update(cfg);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerNotifierProvider);
    final notifier = ref.read(readerNotifierProvider.notifier);
    final adv = ref.watch(readerAdvConfigProvider);

    if (widget.fullPage) {
      return AppScaffold(
        topBar: LegadoAppBar(
          title: Text(widget.category?.title ?? context.l10n.readingInterface),
          showBack: true,
        ),
        body: adv == null
            ? const Center(child: CircularProgressIndicator())
            : SettingsBody(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _buildPage(state, notifier, adv),
                ),
              ),
      );
    }

    if (adv == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFontSizeGroup(state, notifier),
            const SizedBox(height: 12),
            _buildBackgroundGroup(state, notifier, adv),
            const SizedBox(height: 12),
            _buildFlipGroup(state, notifier),
            const SizedBox(height: 12),
            _configPanel(adv, ReaderConfigSection.brightness),
            const SizedBox(height: 12),
            SettingsGroup(
              showDividers: false,
              margin: EdgeInsets.zero,
              children: [
                SettingTile(
                  icon: Icons.tune,
                  title: '全部阅读设置',
                  onTap: () {
                    // 先关闭快捷面板，避免在完整设置页下方残留弹层。
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const ReaderSettingsSheet(fullPage: true),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _configPanel(ReaderAdvancedConfig adv, ReaderConfigSection section) =>
      ReaderConfigPanel(
        config: adv.copy(),
        onChanged: _commitAdv,
        section: section,
      );

  Widget _buildPage(
    ReaderState state,
    ReaderNotifier notifier,
    ReaderAdvancedConfig adv,
  ) {
    final category = widget.category;
    if (category == null) {
      return Column(
        children: [
          SettingsGroup(
            showDividers: false,
            margin: EdgeInsets.zero,
            children: [
              for (final item in ReaderSettingsCategory.values)
                SettingTile(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.summary,
                  onTap: () =>
                      ReaderSettingsSheet.showPage(context, category: item),
                ),
            ],
          ),
        ],
      );
    }

    final children = switch (category) {
      ReaderSettingsCategory.typography => <Widget>[
        ReaderFontPanel(
          config: adv.copy(),
          onChanged: _commitAdv,
          fontSizeControl: _buildFontSizeControl(state, notifier),
          lineHeightControl: _ReaderSliderSetting(
            title: context.l10n.lineHeight,
            displayValue: '${state.lineHeight.toStringAsFixed(2)} 倍',
            value: state.lineHeight,
            min: 1,
            max: 3,
            divisions: 40,
            onChanged: notifier.updateLineHeight,
          ),
        ),
        _configPanel(adv, ReaderConfigSection.typography),
      ],
      ReaderSettingsCategory.background => <Widget>[
        _buildBackgroundGroup(state, notifier, adv),
        _configPanel(adv, ReaderConfigSection.menuTheme),
        const EyeProtectionSettingsGroup(),
      ],
      ReaderSettingsCategory.interaction => <Widget>[
        _buildFlipGroup(state, notifier),
        _configPanel(adv, ReaderConfigSection.interaction),
      ],
      ReaderSettingsCategory.layout => <Widget>[
        _configPanel(adv, ReaderConfigSection.pageLayout),
        ReaderTipConfigSheet(
          config: adv.copy(),
          onChanged: _commitAdv,
          embedded: true,
          showStatusBar: false,
          titleFont: ReaderFontPanel(
            config: adv.copy(),
            onChanged: _commitAdv,
            titleOnly: true,
            embedded: true,
          ),
        ),
      ],
      ReaderSettingsCategory.screen => <Widget>[
        _configPanel(adv, ReaderConfigSection.screen),
      ],
      ReaderSettingsCategory.content => <Widget>[
        _configPanel(adv, ReaderConfigSection.content),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }

  Widget _buildFlipGroup(ReaderState state, ReaderNotifier notifier) =>
      SettingsGroup(
        showDividers: false,
        children: [
          SettingMenuRow<PageTurnMode>(
            title: context.l10n.readerPageAnimation,
            icon: Icons.auto_stories_outlined,
            value: state.pageTurnMode,
            options: _flipLabels,
            onChanged: notifier.updatePageTurnMode,
          ),
        ],
      );

  /// 快捷面板和字体分组共用字号步进控件。
  Widget _buildFontSizeGroup(ReaderState state, ReaderNotifier notifier) =>
      SettingsGroup(
        showDividers: false,
        children: [_buildFontSizeControl(state, notifier)],
      );

  Widget _buildFontSizeControl(ReaderState state, ReaderNotifier notifier) =>
      SettingStepperRow(
        title: context.l10n.readerFontSize,
        value: state.fontSize,
        min: 12,
        max: 32,
        onChanged: notifier.updateFontSize,
      );

  /// 背景分组：标题 + 长按自定义提示 + 月亮夜间切换 + 预设 chips
  Widget _buildBackgroundGroup(
    ReaderState state,
    ReaderNotifier notifier,
    ReaderAdvancedConfig adv,
  ) {
    final eyeProtection = ref.watch(eyeProtectionProvider);
    return SettingsGroup(
      showDividers: false,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.readerBackground,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '选择预设或自定义配色',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.eyeProtection,
                    icon: const Icon(Icons.visibility_outlined),
                    selectedIcon: const Icon(Icons.visibility_rounded),
                    isSelected: eyeProtection.enabled,
                    color: eyeProtection.enabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onPressed: () => ref
                        .read(eyeProtectionProvider.notifier)
                        .update(enabled: !eyeProtection.enabled)
                        .catchError((Object error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.loginSaveFailed),
                              ),
                            );
                          }
                        }),
                    onLongPress: () => EyeProtectionSettingsGroup.show(context),
                  ),
                  IconButton(
                    tooltip: state.isDarkBackground ? '日间背景' : '夜间背景',
                    icon: const Icon(Icons.dark_mode_rounded),
                    onPressed: () => notifier.updateBackgroundColor(
                      state.isDarkBackground
                          ? ReaderBackground.white
                          : ReaderBackground.dark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    // 自定义 chip：网格图标，点按弹自定义配色
                    GestureDetector(
                      onTap: () =>
                          _showCustomColorDialog(context, adv, notifier, state),
                      child: Container(
                        width: 64,
                        height: 56,
                        margin: const EdgeInsets.only(right: 10),
                        alignment: Alignment.center,
                        decoration: _bgChipDecoration(selected: false),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 22,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (var i = 0; i < ReaderBackground.presets.length; i++)
                      _bgPresetChip(state, notifier, i),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _bgChipDecoration({required bool selected}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: Border.all(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        width: 2,
      ),
    );
  }

  /// 预设背景 chip（颜色预览卡：chip 底色即背景色，对齐参考版；
  /// 选中加主色描边 + 底部对勾）
  Widget _bgPresetChip(ReaderState state, ReaderNotifier notifier, int index) {
    final color = resolveReaderBackground(
      themeBrightness: Theme.of(context).brightness,
      themeAmoled: ref.watch(uiSettingsProvider.select((ui) => ui.themeAmoled)),
      storedBgIndex: index,
    );
    final label = ReaderBackground.labels[index];
    final isSelected = state.backgroundColor == color;
    final onColor = color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white70;
    return GestureDetector(
      onLongPress: () => _showCustomColorDialog(context, null, notifier, state),
      onTap: () =>
          notifier.updateBackgroundColor(ReaderBackground.presets[index]),
      child: Container(
        width: 64,
        height: 56,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: onColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 14,
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ===== 自定义配色对话框（长按背景 chip 弹出，自绘色板不引入依赖） =====

  void _showCustomColorDialog(
    BuildContext context,
    ReaderAdvancedConfig? adv,
    ReaderNotifier notifier,
    ReaderState state,
  ) {
    final effectiveAdv =
        adv ?? ref.read(readerAdvConfigProvider) ?? ReaderAdvancedConfig();
    var textColorValue = effectiveAdv.customTextColor;
    var bgColorValue = state.backgroundColor.toARGB32();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('自定义配色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogContext.l10n.readerTextColor,
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 「自动」= 跟随背景明暗自适应（customTextColor 置 0）
                    _autoTextChip(dialogContext, textColorValue == 0, () {
                      setDialogState(() => textColorValue = 0);
                      final cfg = effectiveAdv.copy()..customTextColor = 0;
                      _commitAdv(cfg);
                    }),
                    for (final c in _palette)
                      _colorBlock(
                        dialogContext,
                        c,
                        textColorValue == c.toARGB32(),
                        () {
                          setDialogState(() => textColorValue = c.toARGB32());
                          final cfg = effectiveAdv.copy()
                            ..customTextColor = c.toARGB32();
                          _commitAdv(cfg);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  dialogContext.l10n.readerBackgroundColor,
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _palette)
                      _colorBlock(
                        dialogContext,
                        c,
                        bgColorValue == c.toARGB32(),
                        () {
                          setDialogState(() => bgColorValue = c.toARGB32());
                          // 自定义背景经 notifier 持久化并即时应用
                          unawaited(notifier.updateCustomBackgroundColor(c));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.l10n.readerDone),
            ),
          ],
        ),
      ),
    );
  }

  /// 「自动」文字色选项块
  Widget _autoTextChip(
    BuildContext context,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 52,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          context.l10n.readerAuto,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }

  /// 色板色块
  Widget _colorBlock(
    BuildContext context,
    Color color,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 16,
                color: color.computeLuminance() > 0.5
                    ? Colors.black54
                    : Colors.white70,
              )
            : null,
      ),
    );
  }
}
