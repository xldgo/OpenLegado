import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// 场景切换只让新内容淡入，不并存两个带滚动/焦点控制器的页面。— Codex + UI
class AppSceneTransition extends StatefulWidget {
  const AppSceneTransition({
    super.key,
    required this.scene,
    required this.child,
  });
  final Object scene;
  final Widget child;
  @override
  State<AppSceneTransition> createState() => _AppSceneTransitionState();
}

class _AppSceneTransitionState extends State<AppSceneTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AppSceneTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene) {
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: KeyedSubtree(key: ValueKey(widget.scene), child: widget.child),
  );
}

/// 小型动作组过渡；退场项立刻停止接收点击、焦点和读屏。— Codex + UI
class AppActionTransition extends StatelessWidget {
  const AppActionTransition({
    super.key,
    required this.identity,
    required this.child,
  });
  final Object identity;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final key = ValueKey(identity);
    Widget shield(Widget content) => ExcludeFocus(
      child: ExcludeSemantics(
        child: IgnorePointer(child: TickerMode(enabled: false, child: content)),
      ),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [for (final old in previous) shield(old), ?current],
      ),
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

/// 稳定子树的显隐，按目标状态关闭命中与语义；用于行尾选择标记。— Codex + UI
class AppSelectionReveal extends StatelessWidget {
  const AppSelectionReveal({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: visible ? 1 : 0),
          duration: AppMotion.duration(
            context,
            const Duration(milliseconds: 180),
          ),
          curve: Curves.easeOutCubic,
          child: child,
          builder: (_, value, child) => ClipRect(
            child: Align(
              widthFactor: value,
              alignment: AlignmentDirectional.centerEnd,
              child: Opacity(opacity: value, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}
