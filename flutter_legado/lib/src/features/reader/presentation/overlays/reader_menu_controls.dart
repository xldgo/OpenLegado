import 'package:flutter/cupertino.dart' as sdk;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../theme/app_motion.dart';
import '../../../../theme/app_glass_theme.dart';
import '../../../../theme/app_surface_material.dart';

/// 阅读器统一适配库的主题，第三方类型不进入业务回调。— Codex + UI
class ReaderMenuControlTheme extends StatelessWidget {
  const ReaderMenuControlTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassTheme(
      data: GlassThemeData.of(context).copyWith(brightness: theme.brightness),
      child: sdk.CupertinoTheme(
        data: sdk.CupertinoThemeData(
          brightness: theme.brightness,
          primaryColor: theme.colorScheme.primary,
        ),
        child: child,
      ),
    );
  }
}

/// 共用表面内使用透明玻璃按钮，只有独立返回按钮绘制自身背景。
class ReaderMenuControlButton extends StatelessWidget {
  const ReaderMenuControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.showLabel = false,
    this.standalone = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool showLabel;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurface;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: foreground),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ],
    );
    final reduced = AppMotion.reduced(context);
    return Tooltip(
      message: label,
      child: GlassButton.custom(
        label: label,
        enabled: onPressed != null,
        onTap: onPressed ?? () {},
        width: showLabel ? double.infinity : 48,
        height: showLabel ? 64 : 48,
        shape: LiquidRoundedSuperellipse(borderRadius: showLabel ? 20 : 24),
        style: standalone
            ? GlassButtonStyle.filled
            : GlassButtonStyle.transparent,
        useOwnLayer: standalone,
        quality: AppGlassScope.availableOf(context)
            ? null
            : GlassQuality.minimal,
        settings: standalone
            ? AppGlassStyle.resolve(
                AppSurfaceMaterial.button(
                  color: theme.colorScheme.surfaceContainerHigh,
                ),
              )
            : null,
        stretch: reduced ? 0 : 0.12,
        interactionScale: reduced ? 1 : null,
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}

/// 滑条只传递范围与数值；章节跳转和排版定位仍由页面负责。
class ReaderMenuProgressSlider extends StatelessWidget {
  const ReaderMenuProgressSlider({
    super.key,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.label,
    required this.color,
  });

  final double value;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: GlassSlider(
      value: value,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      label: label,
      activeColor: color,
      inactiveColor: color.withValues(alpha: 0.2),
      thumbColor: Theme.of(context).colorScheme.onSurface,
      quality: AppGlassScope.availableOf(context) ? null : GlassQuality.minimal,
    ),
  );
}
