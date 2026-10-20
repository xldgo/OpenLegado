import 'package:material_ui/material_ui.dart';

import '../theme/app_motion.dart';

/// 搜索区域的单一动画进度，顶栏占位与内容同时消费，支持中途反向。
class AppSearchTransition extends StatefulWidget {
  const AppSearchTransition({
    super.key,
    required this.expanded,
    required this.builder,
  });
  final bool expanded;
  final Widget Function(BuildContext, double) builder;
  @override
  State<AppSearchTransition> createState() => _AppSearchTransitionState();
}

class _AppSearchTransitionState extends State<AppSearchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.expanded ? 1 : 0,
  );
  late final CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  void _sync() {
    if (AppMotion.reduced(context)) {
      _controller.value = widget.expanded ? 1 : 0;
    } else {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AppSearchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (!widget.expanded) FocusScope.of(context).unfocus();
      _sync();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) => widget.builder(context, _animation.value),
  );
}

/// 收起过程中保留输入控件，隐藏后移除；焦点、命中与无障碍随目标状态关闭。
class AppSearchReveal extends StatelessWidget {
  const AppSearchReveal({
    super.key,
    required this.progress,
    required this.expanded,
    required this.child,
  });
  final double progress;
  final bool expanded;
  final Widget child;
  @override
  Widget build(BuildContext context) => progress == 0
      ? const SizedBox.shrink()
      : ExcludeFocus(
          excluding: !expanded,
          child: ExcludeSemantics(
            excluding: !expanded,
            child: IgnorePointer(
              ignoring: !expanded,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: progress,
                  child: Opacity(opacity: progress, child: child),
                ),
              ),
            ),
          ),
        );
}
