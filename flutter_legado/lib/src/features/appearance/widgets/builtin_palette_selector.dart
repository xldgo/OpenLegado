import 'package:material_ui/material_ui.dart';

import '../../../theme/md3_colors.dart';

/// 内置 MD3 调色板横滑选择行（UI_MD3_PLAN.md Batch 1「内置 13 主题」区，
/// 阶段D 2.0.270 起 13 套：def「默认」为默认选中，wh 黑白等 12 套保留）
///
/// [队列⑦a A2] 形态对齐参考 ThemeColorSelector（ThemeConfigScreen.kt:1020，
/// LazyRow 横滑一行 + Arrangement.spacedBy(16.dp) :1031-1032）。
/// 每张卡片左半为亮色预览、右半为暗色预览（tonal 配对），底部显示
/// 中文主题名；选中项 2dp 主色描边 + 40dp 主色圆角底对勾。点按经
/// [ThemeNotifier] 全局实时生效并持久化 paletteId。
class BuiltinPaletteSelector extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const BuiltinPaletteSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 横滑一行（参考 LazyRow；卡间距 16 对齐 spacedBy(16.dp)）
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < Md3Palettes.all.length; i += 1) ...[
            if (i > 0) const SizedBox(width: 16),
            _PaletteCard(
              palette: Md3Palettes.all[i],
              selected: Md3Palettes.all[i].id == selectedId,
              onSelected: () => onSelected(Md3Palettes.all[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单张调色板预览卡片（64x64 方卡，形态对齐参考 ThemeColorButton
/// ThemeConfigScreen.kt:1054：size(64.dp) + RoundedCornerShape(16.dp)
/// :1089-1096；选中 2dp 主色描边 :1092-1095；选中 40dp/12dp 圆角主色底
/// 24dp 对勾 :1134-1148；12dp 下距 :1152；labelSmall 标签
/// :1154-1158）
///
/// 卡片内部保留我方左亮/右暗 surface 预览 + 色点（功能实现倾向我方；
/// 参考为 48dp 半圆 arc 单模式预览 :1102-1132）。
class _PaletteCard extends StatelessWidget {
  final Md3Palette palette;
  final bool selected;
  final VoidCallback onSelected;

  const _PaletteCard({
    required this.palette,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Color(palette.light.surface);
    final dark = Color(palette.dark.surface);
    final primary = Color(palette.light.primary);
    final secondary = Color(palette.light.secondary);
    final tertiary = Color(palette.light.tertiary);

    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      // 参考：选中 2dp 主色描边，未选中无描边（:1092-1095 else null）
                      border: selected
                          ? Border.all(color: primary, width: 2)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    // 左亮右暗：展示该套调色板的 tonal 亮暗配对
                    child: Row(
                      children: [
                        Expanded(
                          child: ColoredBox(
                            color: light,
                            child: Center(
                              child: _PaletteDots(
                                primary: primary,
                                secondary: secondary,
                                tertiary: tertiary,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: dark,
                            child: Center(
                              child: _PaletteDots(
                                primary: primary,
                                secondary: secondary,
                                tertiary: tertiary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 24,
                        color: scheme.onPrimary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              palette.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: selected ? primary : scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预览色点行（primary/secondary/tertiary 三点示意）
class _PaletteDots extends StatelessWidget {
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const _PaletteDots({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  Widget build(BuildContext context) {
    // FittedBox 兜底：[队列⑦a A2] 64px 方卡内左/右半预览区约 30px 宽，
    // 色点行 39px 需缩放下放（原 4 列网格半卡 ~37dp 时的兜底同样适用，
    // md3_acceptance_matrix_test 回归守护）
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final color in [primary, secondary, tertiary]) ...[
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
