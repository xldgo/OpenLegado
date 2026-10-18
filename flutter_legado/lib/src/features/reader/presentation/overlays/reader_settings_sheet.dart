import '../../../../app/routing/route_names.dart';
import '../../application/reader_settings_provider.dart';
import '../../../../domain/models/reader_theme_mode.dart';
import '../../../../domain/models/reader_style.dart';
import '../../../../domain/models/reader_text_layout_settings.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../../l10n/app_localization.dart';
import '../../application/reader_notifier.dart';
import '../../../../providers/ui_settings/ui_settings_notifier.dart';
import '../../../../providers/ui_settings/eye_protection_notifier.dart';

import 'reader_config_panel.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/legado_app_bar.dart';
import '../../../../widgets/settings_widgets.dart';
import '../../../../widgets/eye_protection_settings.dart';
import 'reader_tip_config_sheet.dart';

part 'reader_settings_sheet_font_panel.part.dart';

// 字体设置复用既有管理入口，正文排版直接访问共享阅读设置。

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('阅读设置读取失败，请重试')));
    }
  }

  Future<void> _savePageTurnMode(PageTurnMode mode) async {
    try {
      await ref.read(readerNotifierProvider.notifier).updatePageTurnMode(mode);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('翻页模式保存失败，请重试')));
      }
    }
  }

  Future<void> _saveTypography(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('阅读排版保存失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerNotifierProvider);
    final notifier = ref.read(readerNotifierProvider.notifier);
    ref.watch(readerSettingsProvider);

    if (widget.fullPage) {
      return AppScaffold(
        topBar: LegadoAppBar(
          title: Text(widget.category?.title ?? context.l10n.readingInterface),
          showBack: true,
        ),
        body: SettingsBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _buildPage(state, notifier),
          ),
        ),
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
            _buildBackgroundGroup(state, notifier),
            const SizedBox(height: 12),
            _buildFlipGroup(state, notifier),
            const SizedBox(height: 12),
            _configPanel(ReaderConfigSection.brightness),
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

  Widget _configPanel(ReaderConfigSection section) =>
      ReaderConfigPanel(section: section);

  Widget _buildPage(ReaderState state, ReaderNotifier notifier) {
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
          fontSizeControl: _buildFontSizeControl(state, notifier),
          lineHeightControl: _ReaderSliderSetting(
            title: context.l10n.lineHeight,
            displayValue: '${state.lineHeight.toStringAsFixed(2)} 倍',
            value: state.lineHeight,
            min: 1,
            max: 3,
            divisions: 40,
            onChanged: (value) =>
                _saveTypography(() => notifier.updateLineHeight(value)),
          ),
        ),
        _configPanel(ReaderConfigSection.typography),
      ],
      ReaderSettingsCategory.background => <Widget>[
        _buildBackgroundGroup(state, notifier),
        _configPanel(ReaderConfigSection.menuTheme),
        const EyeProtectionSettingsGroup(),
      ],
      ReaderSettingsCategory.interaction => <Widget>[
        _buildFlipGroup(state, notifier),
        _configPanel(ReaderConfigSection.interaction),
      ],
      ReaderSettingsCategory.layout => <Widget>[
        _configPanel(ReaderConfigSection.pageLayout),
        ReaderTipConfigSheet(
          embedded: true,
          showStatusBar: false,
          titleFont: ReaderFontPanel(titleOnly: true, embedded: true),
        ),
      ],
      ReaderSettingsCategory.screen => <Widget>[
        _configPanel(ReaderConfigSection.screen),
      ],
      ReaderSettingsCategory.content => <Widget>[
        _configPanel(ReaderConfigSection.content),
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
            onChanged: _savePageTurnMode,
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
        onChanged: (value) =>
            _saveTypography(() => notifier.updateFontSize(value)),
      );

  /// 每个模板展示当前模式的配色；切换模式后恢复同一模板另一侧的颜色。
  Widget _buildBackgroundGroup(ReaderState state, ReaderNotifier notifier) {
    final eyeProtection = ref.watch(eyeProtectionProvider);
    ref.watch(readerStylesProvider);
    final styles = ref.read(readerStyleRepositoryProvider).current;
    ref.watch(readerThemeModeProvider);
    final themeMode = ref.read(readerThemeSessionProvider).mode;
    return SettingsGroup(
      showDividers: false,
      children: [
        SettingMenuRow<ReaderThemeMode>(
          title: '阅读模式',
          value: themeMode,
          options: const {
            ReaderThemeMode.followApp: '跟随应用',
            ReaderThemeMode.day: '日间',
            ReaderThemeMode.night: '夜间',
          },
          onChanged: (mode) =>
              _saveColors(() => notifier.updateReaderThemeMode(mode)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.readerBackground,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '日夜配色分别保存，长按模板自定义',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.eyeProtection,
                icon: const Icon(Icons.visibility_outlined),
                selectedIcon: const Icon(Icons.visibility_rounded),
                isSelected: eyeProtection.enabled,
                onPressed: () => ref
                    .read(eyeProtectionProvider.notifier)
                    .update(enabled: !eyeProtection.enabled)
                    .catchError((Object error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.loginSaveFailed)),
                        );
                      }
                    }),
                onLongPress: () => EyeProtectionSettingsGroup.show(context),
              ),
              IconButton(
                tooltip: state.isNightMode ? '切换日间' : '切换夜间',
                icon: Icon(
                  state.isNightMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                onPressed: () => _saveColors(
                  () => notifier.updateReaderThemeMode(
                    state.isNightMode
                        ? ReaderThemeMode.day
                        : ReaderThemeMode.night,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                for (final style in styles.styles)
                  _styleChip(
                    state,
                    notifier,
                    style,
                    style.id == styles.selectedId,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _saveColors(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('阅读配色保存失败，请重试')));
      }
      return false;
    }
  }

  /// 模板预览同时使用当前模式的背景和文字色，不用全局主题推断配色。
  Widget _styleChip(
    ReaderState state,
    ReaderNotifier notifier,
    ReaderStyle style,
    bool selected,
  ) {
    final colors = style.colors(state.isNightMode);
    final resolved = colors.resolve(
      isNight: state.isNightMode,
      amoled: ref.read(uiSettingsProvider).themeAmoled,
    );
    final background = Color(resolved.background);
    final foreground = Color(resolved.text);
    return Semantics(
      button: true,
      selected: selected,
      label: '${style.name}，${state.isNightMode ? '夜间' : '日间'}配色',
      child: GestureDetector(
        key: ValueKey('reader-style-${style.id}'),
        onTap: () => _saveColors(() => notifier.selectReaderStyle(style.id)),
        onLongPress: () async {
          if (await _saveColors(() => notifier.selectReaderStyle(style.id)) &&
              mounted) {
            _showCustomColorDialog(
              context,
              notifier,
              ref.read(readerNotifierProvider),
            );
          }
        },
        child: Container(
          width: 76,
          height: 64,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                style.name,
                style: TextStyle(color: foreground, fontSize: 12),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 14,
                child: selected
                    ? Icon(Icons.check_rounded, size: 14, color: foreground)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomColorDialog(
    BuildContext context,
    ReaderNotifier notifier,
    ReaderState state,
  ) {
    final colors = ref
        .read(readerStyleRepositoryProvider)
        .current
        .selected
        .colors(state.isNightMode);
    var textColorValue = colors.text ?? 0;
    var bgColorValue = state.backgroundColor.toARGB32();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> saveText(Color? color) async {
            if (await _saveColors(
                  () => notifier.updateCustomTextColor(color),
                ) &&
                dialogContext.mounted) {
              setDialogState(() => textColorValue = color?.toARGB32() ?? 0);
            }
          }

          Future<void> saveBackground(Color color) async {
            if (await _saveColors(
                  () => notifier.updateCustomBackgroundColor(color),
                ) &&
                dialogContext.mounted) {
              setDialogState(() => bgColorValue = color.toARGB32());
            }
          }

          return AlertDialog(
            title: Text('自定义${state.isNightMode ? '夜间' : '日间'}配色'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dialogContext.l10n.readerTextColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _autoTextChip(
                        dialogContext,
                        textColorValue == 0,
                        () => saveText(null),
                      ),
                      for (final color in _palette)
                        _colorBlock(
                          dialogContext,
                          color,
                          textColorValue == color.toARGB32(),
                          () => saveText(color),
                          key: ValueKey(
                            'reader-text-color-${color.toARGB32()}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(dialogContext.l10n.readerBackgroundColor),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in _palette)
                        _colorBlock(
                          dialogContext,
                          color,
                          bgColorValue == color.toARGB32(),
                          () => saveBackground(color),
                          key: ValueKey(
                            'reader-background-color-${color.toARGB32()}',
                          ),
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
          );
        },
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
    VoidCallback onTap, {
    Key? key,
  }) {
    return InkWell(
      key: key,
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
