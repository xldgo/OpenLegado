import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../widgets/app_scaffold.dart';
import '../../../widgets/legado_app_bar.dart';

import '../../../providers/welcome_settings_provider.dart';
import '../../../domain/contracts/welcome_settings_repository.dart';
import '../../../widgets/app_progress_indicator.dart';
import '../../../widgets/settings_widgets.dart';

/// 欢迎页样式配置（对齐原版 WelcomeConfigFragment + pref_config_welcome.xml）
///
/// 分组：显示时长 / 自定义欢迎 / 白天 / 夜间。视觉用 iOS 分组列表（apple-ui-designer）。
class WelcomeConfigScreen extends ConsumerStatefulWidget {
  const WelcomeConfigScreen({super.key});

  @override
  ConsumerState<WelcomeConfigScreen> createState() =>
      _WelcomeConfigScreenState();
}

class _WelcomeConfigScreenState extends ConsumerState<WelcomeConfigScreen> {
  int? _showTimePreview;

  Future<void> _save(
    Future<void> Function(WelcomeSettingsRepository) save,
  ) async {
    try {
      await save(ref.read(welcomeSettingsRepositoryProvider));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  Future<void> _pickImage({required bool dark}) async {
    final settings = ref.read(welcomeSettingsRepositoryProvider).current;
    final current = dark ? settings.imageNight : settings.imageDay;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.photo_rounded),
              title: const Text('选择图片'),
              onTap: () => Navigator.pop(ctx, 'select'),
            ),
            if (current.isNotEmpty)
              ListTile(
                leading: const Icon(Symbols.delete_rounded),
                title: const Text('删除'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ListTile(
              leading: const Icon(Symbols.close_rounded),
              title: const Text('取消'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'select') {
      final result = await FilePicker.pickFile(
        type: FileType.image,
        dialogTitle: '选择欢迎页背景',
        compressionQuality: Platform.isAndroid ? 30 : 0,
      );
      final path = result?.path;
      if (path == null || !mounted) return;
      await _save(
        (repository) => repository.update(
          imageDay: dark ? null : path,
          imageNight: dark ? path : null,
        ),
      );
    } else if (action == 'delete') {
      await _save(
        (repository) => repository.update(
          imageDay: dark ? null : '',
          imageNight: dark ? '' : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(welcomeSettingsProvider);
    final settings =
        loaded.value ?? ref.read(welcomeSettingsRepositoryProvider).current;
    final showTime = _showTimePreview ?? settings.showTime;

    // [GLOBALCOMP B4] 页壳统一：AppScaffold（行为等价直通 Scaffold）
    return AppScaffold(
      topBar: LegadoAppBar(title: const Text('欢迎页样式')),
      body: loaded.isLoading
          // [STAGE-UI-P43UNIFY2 B4] .adaptive() → 标准环（参考版无 adaptive 用法）
          ? const Center(child: AppCircularProgressIndicator())
          : loaded.hasError
          ? Center(
              child: TextButton(
                onPressed: () => ref.invalidate(welcomeSettingsProvider),
                child: const Text('设置读取失败，点击重试'),
              ),
            )
          : SettingsBody(
              child: ListView(
                children: [
                  const SettingsSectionHeader('显示时长'),
                  SettingsGroup(
                    flat: true, // [LAYOUT_MOTION_AUDIT L2] 设置拆扁平
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '启动闪屏停留 $showTime 毫秒',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            Text(
                              '$showTime',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      Slider(
                        value: showTime.toDouble(),
                        min: 0,
                        max: 800,
                        divisions: 80,
                        label: '$showTime',
                        onChanged: (v) {
                          setState(() => _showTimePreview = v.round());
                        },
                        onChangeEnd: (v) {
                          final ms = v.round().clamp(0, 800);
                          setState(() => _showTimePreview = null);
                          _save(
                            (repository) => repository.update(showTime: ms),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          '设为 0 则跳过闪屏直接进入主页',
                          // [MD3 全量清点] Colors.grey → onSurfaceVariant token
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SettingsSectionHeader('自定义'),
                  SettingsGroup(
                    flat: true, // [LAYOUT_MOTION_AUDIT L2] 设置拆扁平
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('自定义欢迎页'),
                        subtitle: const Text('启用后可设置日/夜背景图'),
                        value: settings.customWelcome,
                        onChanged: (v) {
                          _save(
                            (repository) => repository.update(customWelcome: v),
                          );
                        },
                      ),
                    ],
                  ),
                  const SettingsSectionHeader('白天'),
                  SettingsGroup(
                    flat: true, // [LAYOUT_MOTION_AUDIT L2] 设置拆扁平
                    children: [
                      SettingTile(
                        icon: Symbols.wallpaper_rounded,
                        title: '背景图片',
                        subtitle: settings.imageDay.isEmpty
                            ? '选择图片'
                            : settings.imageDay,
                        onTap: () => _pickImage(dark: false),
                      ),
                      SwitchListTile.adaptive(
                        title: const Text('显示文字'),
                        subtitle: const Text('阅读 / 享受美好时光 / 品读万千故事'),
                        value: settings.showText,
                        onChanged: (v) {
                          _save((repository) => repository.update(showText: v));
                        },
                      ),
                      SwitchListTile.adaptive(
                        title: const Text('显示图标'),
                        subtitle: const Text('默认书本图标'),
                        value: settings.showIcon,
                        onChanged: (v) {
                          _save((repository) => repository.update(showIcon: v));
                        },
                      ),
                    ],
                  ),
                  const SettingsSectionHeader('夜间'),
                  SettingsGroup(
                    flat: true, // [LAYOUT_MOTION_AUDIT L2] 设置拆扁平
                    children: [
                      SettingTile(
                        icon: Symbols.wallpaper_rounded,
                        title: '背景图片',
                        subtitle: settings.imageNight.isEmpty
                            ? '选择图片'
                            : settings.imageNight,
                        onTap: () => _pickImage(dark: true),
                      ),
                      SwitchListTile.adaptive(
                        title: const Text('显示文字'),
                        subtitle: const Text('阅读 / 享受美好时光 / 品读万千故事'),
                        value: settings.showTextDark,
                        onChanged: (v) {
                          _save(
                            (repository) => repository.update(showTextDark: v),
                          );
                        },
                      ),
                      SwitchListTile.adaptive(
                        title: const Text('显示图标'),
                        subtitle: const Text('默认书本图标'),
                        value: settings.showIconDark,
                        onChanged: (v) {
                          _save(
                            (repository) => repository.update(showIconDark: v),
                          );
                        },
                      ),
                    ],
                  ),
                  const SettingsSectionFooter(
                    '闪屏结构对齐原版 WelcomeActivity；背景图仅在开启「自定义欢迎页」时生效。',
                  ),
                ],
              ),
            ),
    );
  }
}
