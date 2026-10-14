import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localization.dart';

/// 主题模式三选分段控件（跟随系统 / 浅色 / 深色）。
///
/// [队列⑦c A3] 对齐参考 ThemeModeSelector（ThemeConfigScreen.kt:974-1012，
/// 3 个相连 ToggleButton，material 引擎分支文案 跟随系统/浅色/深色，
/// flow_sys/light_mode/dark_mode）。此前 2026-08-13 裁决"主题模式仅放
/// 「我的」枢纽"，本次 A3 任务指令"IA 对齐参考版"予以覆盖，恢复页内选择器；
/// 复用既有 ThemeState.themeMode 与 ThemeNotifier.setThemeMode（经
/// 共享外观仓储持久化），非新增功能。
class ThemeModeSelector extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (final mode in ThemeMode.values)
            Expanded(
              child: _ModeSegment(
                label: switch (mode) {
                  ThemeMode.system => context.l10n.themeSystem,
                  ThemeMode.light => context.l10n.themeLight,
                  ThemeMode.dark => context.l10n.themeDark,
                },
                selected: mode == selected,
                onTap: () => onChanged(mode),
                selectedBg: scheme.primary,
                selectedFg: scheme.onPrimary,
                normalBg: scheme.surfaceContainerHighest,
                normalFg: scheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

/// 主题模式选择器单段（相连三段，圆角矩形 + 选中主色底，对齐参考 3 相连
/// ToggleButton 形态）
class _ModeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg;
  final Color selectedFg;
  final Color normalBg;
  final Color normalFg;

  const _ModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedBg,
    required this.selectedFg,
    required this.normalBg,
    required this.normalFg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? selectedBg : normalBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? selectedFg : normalFg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
