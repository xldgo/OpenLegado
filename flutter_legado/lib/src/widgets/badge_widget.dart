import 'package:material_ui/material_ui.dart';

/// 徽标组件 — 右上角数字徽标
class BadgeWidget extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? color;
  final bool showZero;

  const BadgeWidget({
    super.key,
    required this.child,
    this.count = 0,
    this.color,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = color ?? colorScheme.error;
    final showBadge = count > 0 || showZero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showBadge)
          Positioned(
            right: -6,
            top: -6,
            child: Badge.count(
              count: count,
              maxCount: 99,
              backgroundColor: badgeColor,
            ),
          ),
      ],
    );
  }
}
