import 'package:material_ui/material_ui.dart';

import '../../../domain/models/appearance_settings.dart';
import '../../../l10n/app_localization.dart';
import '../../../theme/md3_colors.dart';
import '../../../theme/platform_dynamic_colors.dart';

/// 配色横滑行：动态取色置首，预览遵循参考版圆形三色布局。— Codex + UI
class BuiltinPaletteSelector extends StatelessWidget {
  const BuiltinPaletteSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dynamicColors =
        PlatformDynamicColors.of(context, brightness) ??
        (brightness == Brightness.light
            ? md3LightScheme(Md3Palettes.gr)
            : md3DarkScheme(Md3Palettes.gr));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // 为两端色卡及水波纹留出空间，避开设置分组的圆角裁剪区。
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PaletteCard(
            label: context.l10n.themeDynamicColor,
            colors: dynamicColors,
            selected: selectedId == AppearanceSettings.dynamicPaletteId,
            onSelected: () => onSelected(AppearanceSettings.dynamicPaletteId),
          ),
          for (final palette in Md3Palettes.all) ...[
            const SizedBox(width: 16),
            _PaletteCard(
              label: palette.label,
              colors: brightness == Brightness.light
                  ? md3LightScheme(palette)
                  : md3DarkScheme(palette),
              selected: palette.id == selectedId,
              onSelected: () => onSelected(palette.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final ColorScheme colors;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: SizedBox(
        width: 64,
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 64,
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: colors.surfaceContainer,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: selected
                        ? BorderSide(color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                  // Card 在前景绘制轮廓，子内容不会盖住选中边框。
                  borderOnForeground: true,
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 48,
                        child: ClipOval(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ColoredBox(color: colors.secondary),
                              ),
                              Expanded(
                                child: ColoredBox(color: colors.tertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: selected ? 40 : 24,
                        height: selected ? 40 : 24,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check,
                                size: 24,
                                color: colors.onPrimary,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
