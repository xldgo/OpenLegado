import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import 'app_bottom_bar_inset.dart';
import 'app_scaffold.dart';
import 'custom_refresh_indicator.dart';

/// 页壳内的正文滚动入口，不自行创建顶栏或嵌套滚动协调器。— Codex + UI
class AppScrollView extends StatefulWidget {
  const AppScrollView({
    super.key,
    required this.slivers,
    this.controller,
    this.onRefresh,
    this.scrollTopSignal,
  });

  final List<Widget> slivers;

  /// 独立使用时的控制器；在AppScaffold中复用其协调器。
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;
  final ValueListenable<int>? scrollTopSignal;

  @override
  State<AppScrollView> createState() => _AppScrollViewState();
}

class _AppScrollViewState extends State<AppScrollView> {
  final _fallbackController = ScrollController();
  ScrollController? _scrollTopController;

  @override
  void initState() {
    super.initState();
    widget.scrollTopSignal?.addListener(_scrollToTop);
  }

  @override
  void didUpdateWidget(covariant AppScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollTopSignal != widget.scrollTopSignal) {
      oldWidget.scrollTopSignal?.removeListener(_scrollToTop);
      widget.scrollTopSignal?.addListener(_scrollToTop);
    }
  }

  void _scrollToTop() {
    final controller = _scrollTopController;
    if (controller == null || !controller.hasClients) return;
    // 外层零点才是展开标题的整体起点；内层零点只表示正文顶部，短内容时不会展开标题。
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    widget.scrollTopSignal?.removeListener(_scrollToTop);
    _scrollTopController = null;
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScrollBody(
    controller: widget.controller ?? _fallbackController,
    builder: (context, controller) {
      _scrollTopController =
          context
              .findAncestorStateOfType<NestedScrollViewState>()
              ?.outerController ??
          controller;
      final content = CustomScrollView(
        controller: controller,
        // 允许短内容下拉刷新；标题折叠范围由页壳提供，不用虚构正文高度。
        physics: widget.onRefresh == null
            ? null
            : const AlwaysScrollableScrollPhysics(),
        slivers: [...widget.slivers, const AppBottomBarSliverSpace()],
      );
      final onRefresh = widget.onRefresh;
      return onRefresh == null
          ? content
          : CustomRefreshIndicator(onRefresh: onRefresh, child: content);
    },
  );
}
