import '../theme/app_surface_material.dart';

import 'package:material_ui/material_ui.dart';

import 'app_menu.dart';

import '../providers/ui_settings/ui_settings_notifier.dart';

/// [UI_SYNC_REFACTOR B2] 顶栏按钮体系（对齐参考仓 TopBarButton/GlassDefaults）
///
/// - 5 档样式：plain 40dp/图标24；tonal/outlined/glass/liquidGlass 36dp/图标20；
///   outlined 加 1dp outlineVariant 描边；glass/liquidGlass 为实色玻璃回退
///   （共享按钮材质底色；液态玻璃光学效果另行实现）；
/// - tonal 在浅色与深色模式均使用透明常态底色、onSurfaceVariant 前景，
///   圆形点击反馈由 IconButton 绘制。激活/选中态由调用方用主题色区分。
/// - 外层点击区域为 48dp，内层保持各档位的视觉尺寸。
/// - [TopBarActionStyler] 可包装任意既有 action（IconButton/AppMenuButton），
///   使全站顶栏按钮零逐页改动获得新样式；
/// - merge 模式：actions 并入 Stadium 胶囊容器 + 1dp 分隔线
///   （onSurfaceVariant α0.15，对齐参考仓 mergeTopBarActions）。
class TopBarActionStyler extends StatelessWidget {
  final TopBarButtonStyle style;
  final bool merge;
  final List<Widget>? actions;

  const TopBarActionStyler({
    super.key,
    required this.style,
    required this.merge,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: styleActions(context, actions, style: style, merge: merge),
    );
  }

  /// 将任意 action 列表按样式档位包装（LegadoAppBar 统一入口）
  static List<Widget> styleActions(
    BuildContext context,
    List<Widget>? actions, {
    required TopBarButtonStyle style,
    required bool merge,
  }) {
    final list = actions;
    if (list == null || list.isEmpty) return const [];
    if (!merge) {
      return [for (final a in list) _ActionSlot(style: style, child: a)];
    }
    // merge 模式：并入胶囊容器，槽位间 1dp 分隔线
    final cs = Theme.of(context).colorScheme;
    final slots = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      if (i > 0) {
        slots.add(
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: cs.onSurfaceVariant.withValues(alpha: 0.15),
          ),
        );
      }
      slots.add(_ActionSlot(style: style, merge: true, child: list[i]));
    }
    return [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: _mergeDecoration(context, style),
        child: Row(mainAxisSize: MainAxisSize.min, children: slots),
      ),
    ];
  }

  static BoxDecoration _mergeDecoration(
    BuildContext context,
    TopBarButtonStyle style,
  ) {
    final cs = Theme.of(context).colorScheme;
    switch (style) {
      case TopBarButtonStyle.plain:
        return const BoxDecoration();
      case TopBarButtonStyle.outlined:
        return BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        );
      case TopBarButtonStyle.glass:
      case TopBarButtonStyle.liquidGlass:
        return BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          color: AppSurfaceMaterial.buttonColor(cs.surfaceContainerHighest),
        );
      case TopBarButtonStyle.tonal:
        // 合并模式保留胶囊布局，常态底色与独立按钮统一为透明。
        return BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
        );
    }
  }
}

class _ActionSlot extends StatelessWidget {
  final TopBarButtonStyle style;

  /// merge 模式下槽位不带独立底色/描边（由胶囊容器统一承担）
  final bool merge;
  final Widget child;

  const _ActionSlot({
    required this.style,
    this.merge = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 文字按钮保留自身尺寸，不压进图标槽位。
    if (child is! IconButton && child is! AppMenuButton) return child;
    if (child is AppMenuButton && (child as AppMenuButton).child != null) {
      return child;
    }
    if (style == TopBarButtonStyle.plain) {
      // 保持 40dp 的视觉尺寸，点击区域由按钮扩展至 48dp。
      return SizedBox(
        width: 48,
        height: 48,
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              fixedSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
            ),
          ),
          child: child,
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, border) = switch (style) {
      // 普通图标按钮常态透明，激活态由调用方以主题色覆盖。
      TopBarButtonStyle.tonal => (
        merge ? null : Colors.transparent,
        cs.onSurfaceVariant,
        null,
      ),
      TopBarButtonStyle.outlined => (
        null,
        cs.onSurfaceVariant,
        merge ? null : Border.all(color: cs.outlineVariant),
      ),
      TopBarButtonStyle.glass || TopBarButtonStyle.liquidGlass => (
        merge
            ? null
            : AppSurfaceMaterial.buttonColor(cs.surfaceContainerHighest),
        cs.onSurface,
        null,
      ),
      TopBarButtonStyle.plain => (null, null, null), // 不可达
    };
    final deco = BoxDecoration(
      color: bg,
      border: border,
      shape: merge ? BoxShape.rectangle : BoxShape.circle,
    );
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(width: 36, height: 36, decoration: deco),
          ),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                iconSize: 20,
                foregroundColor: fg,
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                fixedSize: const Size(36, 36),
                minimumSize: const Size(36, 36),
                maximumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
            ),
            child: IconTheme(
              data: IconThemeData(size: 20, color: fg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 显式单按钮（调用方按档位直接构造；一般经 [TopBarActionStyler] 自动包装）
class TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final TopBarButtonStyle style;

  const TopBarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.style,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = style == TopBarButtonStyle.plain ? 40.0 : 36.0;
    final iconSize = style == TopBarButtonStyle.plain ? 24.0 : 20.0;
    final cs = Theme.of(context).colorScheme;
    // 普通图标按钮常态透明，点击反馈由 IconButton 保留。
    final bg = switch (style) {
      TopBarButtonStyle.tonal => Colors.transparent,
      TopBarButtonStyle.glass || TopBarButtonStyle.liquidGlass =>
        AppSurfaceMaterial.buttonColor(cs.surfaceContainerHighest),
      _ => Colors.transparent,
    };
    final fg = switch (style) {
      TopBarButtonStyle.tonal => cs.onSurfaceVariant,
      TopBarButtonStyle.outlined => cs.onSurfaceVariant,
      _ => cs.onSurface,
    };
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: style == TopBarButtonStyle.outlined
                    ? Border.all(color: cs.outlineVariant)
                    : null,
              ),
            ),
          ),
          IconButton(
            tooltip: tooltip,
            icon: Icon(icon, size: iconSize),
            color: fg,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              fixedSize: Size(size, size),
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
            ),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
