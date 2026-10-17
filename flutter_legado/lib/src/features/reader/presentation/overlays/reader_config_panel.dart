import '../../application/reader_settings_provider.dart';
import '../../../../domain/models/reader_text_layout_settings.dart';
import '../../../../domain/models/reader_page_layout_settings.dart';
import '../../../../domain/models/reader_screen_settings.dart';
import '../../../../domain/models/reader_auto_page_turn_settings.dart';
import '../../../../domain/models/reader_interaction_settings.dart';
import '../../../../domain/models/reader_menu_theme_settings.dart';
import '../../../../domain/models/reader_brightness_control_settings.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../../l10n/app_localization.dart';
import '../../../../providers/reading_content_provider.dart';
import '../../application/reader_notifier.dart';
import '../../../../routes.dart';
import 'reader_brightness_control.dart';
import 'reader_menu_color_dialog.dart';
import 'reader_padding_config_sheet.dart';
import 'reader_tip_config_sheet.dart';
import '../../../../widgets/settings_widgets.dart';
import '../../../../widgets/app_menu.dart';
part 'reader_config_panel_builders.part.dart';

// 构建方法保留为页面 part；配置模型、存储与共享状态独立于页面。

/// 可复用的配置区块，完整设置页按职责分别展示。
/// 原有聚合区块保留兼容，应用入口统一使用完整设置与快捷面板。
enum ReaderConfigSection {
  all,
  margins,
  statusBar,
  menu,
  more,
  typography,
  interaction,
  screen,
  content,
  toolbar,
  menuTheme,
  brightness,
  pageLayout,
}

/// 阅读器配置分组，直接消费所属仓储的共享快照。
///
/// 以底部弹出面板形式展示，支持：
/// - 自动翻页（开关 / 间隔 / 方向）
/// - 点击区域功能映射（九宫格）
/// - 段落间距调节
/// - 状态栏提示栏项配置（电量 / 时间 / 进度 / 章节名）
/// - 翻页模式选择（仿真 / 滑动 / 覆盖 / 无动画）
/// - [UI-fix v2.0.2 | 2026-08-06] 字体选择/字距调节/首行缩进/
///   简繁转换/MoreConfig（两端对齐） — Qoder
class ReaderConfigPanel extends ConsumerStatefulWidget {
  // [UI-fix v2.0.4 | 2026-08-08] 区块过滤：界面 Sheet 的「边距/信息」
  // 按钮仅展示对应区块（对标原版独立弹层）— Qoder
  final ReaderConfigSection section;

  const ReaderConfigPanel({super.key, this.section = ReaderConfigSection.all});

  /// 便捷入口：弹出配置面板
  static Future<void> show(
    BuildContext context, {
    ReaderConfigSection section = ReaderConfigSection.all,
  }) {
    return showModalBottomSheet<void>(
      showDragHandle: false,

      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        // 单区块展示时降低初始高度（内容更短）
        initialChildSize: section == ReaderConfigSection.all ? 0.75 : 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: ReaderConfigPanel(section: section),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderConfigPanel> createState() => _ReaderConfigPanelState();
}

class _ReaderConfigPanelState extends ConsumerState<ReaderConfigPanel> {
  ReaderTextLayoutSettings get _textLayout =>
      ref.read(readerSettingsRepositoryProvider).current.textLayout;

  ReaderPageLayoutSettings get _pageLayout =>
      ref.read(readerSettingsRepositoryProvider).current.pageLayout;

  ReaderScreenSettings get _screen =>
      ref.read(readerSettingsRepositoryProvider).current.screen;

  ReaderAutoPageTurnSettings get _autoPageTurn =>
      ref.read(readerSettingsRepositoryProvider).current.autoPageTurn;
  ReaderInteractionSettings get _interaction =>
      ref.read(readerSettingsRepositoryProvider).current.interaction;

  ReaderMenuThemeSettings get _menuTheme =>
      ref.read(readerSettingsRepositoryProvider).current.menuTheme;
  ReaderBrightnessControlSettings get _brightnessControl =>
      ref.read(readerSettingsRepositoryProvider).current.brightnessControl;

  Future<void> _saveMenuSetting(Future<void> Function() save) async {
    try {
      await save();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('菜单设置保存失败，请重试')));
    }
  }

  /// 当前阅读字体显示名（与 FontScreen 持久化键 reader_font_family 同步）
  String? get _fontLabel => ref
      .read(readerSettingsRepositoryProvider)
      .current
      .fontFamily
      ?.replaceFirst('Custom_', '');

  /// 简繁转换类型（0=不转换 1=繁转简 2=简转繁，对标原版 chineseConvertType）
  int _convertType = 0;

  /// 未手动切换时，编辑当前应用明暗模式对应的菜单颜色。
  bool? _menuColorNight;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReaderSettings());
    unawaited(_loadConvertType());
  }

  Future<void> _loadReaderSettings() async {
    try {
      await ref.read(readerSettingsRepositoryProvider).load();
    } catch (error) {
      debugPrint('阅读字体选择读取失败：$error');
    }
  }

  Future<void> _loadConvertType() async {
    try {
      final type = await ref
          .read(readingContentServiceProvider)
          .getChineseConvertType();
      if (!mounted) return;
      setState(() => _convertType = type.clamp(0, 2));
    } catch (_) {
      // FFI 不可用时保持不转换
    }
  }

  Future<void> _saveTextLayout(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('阅读排版保存失败，请重试')));
      }
    }
  }

  Future<void> _savePageLayout(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('页面布局保存失败，请重试')));
      }
    }
  }

  Future<void> _saveScreen(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('屏幕设置保存失败，请重试')));
      }
    }
  }

  Future<void> _saveOperation(Future<void> Function() update) async {
    try {
      await update();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('翻页与操作设置保存失败，请重试')));
      }
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

  @override
  Widget build(BuildContext context) {
    ref.watch(readerSettingsProvider);
    // [UI-fix v2.0.4 | 2026-08-08] 区块过滤模式：仅渲染指定区块 — Qoder
    final List<Widget> children;
    switch (widget.section) {
      case ReaderConfigSection.typography:
        children = [
          SettingsGroup(
            showDividers: false,
            children: [_buildTypographyOptions()],
          ),
        ];
        break;
      case ReaderConfigSection.interaction:
        children = [
          SettingsGroup(showDividers: false, children: [_buildAutoPageTurn()]),
          const SizedBox(height: 12),
          SettingsGroup(showDividers: false, children: [_buildTapZones()]),
          const SizedBox(height: 12),
          SettingsGroup(
            showDividers: false,
            children: [_buildInteractionOptions()],
          ),
        ];
        break;
      case ReaderConfigSection.screen:
        children = [
          SettingsGroup(
            showDividers: false,
            title: '屏幕与亮度',
            children: [
              _buildBrightnessControl(),
              _buildScreenOptions(showTitle: false),
            ],
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            showDividers: false,
            title: '系统栏与安全区',
            children: [_buildSystemBarOptions(showTitle: false)],
          ),
          const SizedBox(height: 12),
          const ReaderTipConfigSheet(
            section: ReaderTipSection.statusBar,
            embedded: true,
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            showDividers: false,
            title: '菜单工具栏',
            children: [_buildToolbarOptions(showTitle: false)],
          ),
        ];
        break;
      case ReaderConfigSection.pageLayout:
        children = [
          SettingsGroup(
            showDividers: false,
            title: '正文区域',
            children: [
              _buildDoublePageOptions(),
              const ReaderPaddingConfigSheet(
                embedded: true,
                region: PaddingRegion.body,
              ),
            ],
          ),
        ];
        break;
      case ReaderConfigSection.content:
        children = [
          SettingsGroup(
            showDividers: false,
            children: [_buildContentOptions()],
          ),
        ];
        break;
      case ReaderConfigSection.toolbar:
        children = [
          SettingsGroup(
            showDividers: false,
            title: '菜单工具栏',
            children: [_buildToolbarOptions(showTitle: false)],
          ),
        ];
        break;
      case ReaderConfigSection.menuTheme:
        children = [
          SettingsGroup(
            title: context.l10n.readerMenuTheme,
            showDividers: false,
            children: _buildMenuThemeOptions(),
          ),
        ];
        break;
      case ReaderConfigSection.brightness:
        children = [
          SettingsGroup(
            showDividers: false,
            children: [_buildBrightnessControl()],
          ),
        ];
        break;
      case ReaderConfigSection.margins:
        children = [const ReaderPaddingConfigSheet()];
        break;
      case ReaderConfigSection.statusBar:
        children = [const ReaderTipConfigSheet()];
        break;
      case ReaderConfigSection.menu:
        // [UI_SYNC_REFACTOR S5 修] 阅读界面弹层「菜单」页 — Qoder
        children = [
          SettingsGroup(showDividers: false, children: [_buildAutoPageTurn()]),
          const SizedBox(height: 12),
          SettingsGroup(showDividers: false, children: [_buildTapZones()]),
          const SizedBox(height: 12),
          SettingsGroup(
            showDividers: false,
            children: [_buildBrightnessControl()],
          ),
        ];
        break;
      case ReaderConfigSection.more:
        // [UI_SYNC_REFACTOR S5 修] 阅读界面弹层「更多」页（排版与
        // 更多配置 + 页面边距入口）— Qoder
        children = [
          SettingsGroup(showDividers: false, children: [_buildTypography()]),
          const SizedBox(height: 12),
          SettingsGroup(
            showDividers: false,
            children: [_buildParagraphSpacing()],
          ),
          const SizedBox(height: 12),
          SettingsGroup(showDividers: false, children: [_buildMoreConfig()]),
          const SizedBox(height: 12),
          SettingsGroup(
            showDividers: false,
            children: [
              SettingTile(
                icon: Icons.crop_free,
                title: '页面边距',
                subtitle: '页眉 / 正文 / 页脚四向边距',
                onTap: () => ReaderPaddingConfigSheet.show(context),
              ),
            ],
          ),
        ];
        break;
      case ReaderConfigSection.all:
        children = [
          Text('高级阅读设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp，使用 SettingsGroup）
          SettingsGroup(showDividers: false, children: [_buildFlipMode()]),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp）
          SettingsGroup(showDividers: false, children: [_buildAutoPageTurn()]),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp）
          SettingsGroup(showDividers: false, children: [_buildTapZones()]),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp）
          SettingsGroup(
            showDividers: false,
            children: [_buildParagraphSpacing()],
          ),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp）
          SettingsGroup(showDividers: false, children: [_buildTypography()]),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 跳转行两人一组进 Card 分组（圆角 16dp）
          SettingsGroup(
            showDividers: false,
            children: [
              Column(
                children: [
                  SettingTile(
                    icon: Icons.crop_free,
                    title: '页面边距',
                    subtitle: '页眉 / 正文 / 页脚四向边距',
                    onTap: () => ReaderPaddingConfigSheet.show(context),
                  ),
                  SettingTile(
                    icon: Icons.info_outline,
                    title: '阅读提示信息',
                    subtitle: '页眉页脚提示项与标题样式',
                    onTap: () => ReaderTipConfigSheet.show(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp）
          SettingsGroup(showDividers: false, children: [_buildMoreConfig()]),
          const SizedBox(height: 12),
          // [LAYOUT_PLAN P1] 配置分组走 Card 分组（圆角 16dp）
          SettingsGroup(
            showDividers: false,
            children: [_buildBrightnessControl()],
          ),
        ];
        break;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: widget.section.index >= ReaderConfigSection.typography.index
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [UI_SYNC_REFACTOR S5 修] 把手仅独立弹层（all）展示，
            // 嵌入阅读界面弹层页签时不重复显示 — Qoder
            if (widget.section == ReaderConfigSection.all) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
