import 'package:material_ui/material_ui.dart';

/// 正文延伸到底栏后方时，由主页宿主提供实际遮挡高度。— Codex + UI
///
/// 留白用于滚动内容尾部，不能包在整个视口外；独立路由默认没有主页底栏。
class AppBottomBarInset extends InheritedWidget {
  const AppBottomBarInset({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBottomBarInset>()?.bottom ??
      0;

  static EdgeInsets padding(BuildContext context, EdgeInsets original) =>
      original.copyWith(bottom: original.bottom + of(context));

  @override
  bool updateShouldNotify(AppBottomBarInset oldWidget) =>
      bottom != oldWidget.bottom;
}

/// 保持Sliver尾部节点稳定，模式切换只改变高度。
class AppBottomBarSliverSpace extends StatelessWidget {
  const AppBottomBarSliverSpace({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: AppBottomBarInset.of(context)),
  );
}
