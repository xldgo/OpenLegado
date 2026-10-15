import 'package:material_ui/material_ui.dart';

/// 封面页只展示当前单元与下一单元，不创建或改变播放会话。— Codex + UI
class ReadAloudPlayerText extends StatelessWidget {
  const ReadAloudPlayerText({super.key, required this.current, this.next});
  final String current;
  final String? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      key: ValueKey((current, next)),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          current,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 8),
          Text(
            next!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.fastOutSlowIn,
      switchOutCurve: Curves.fastOutSlowIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          // 退出文字不再可点击或被读屏重复朗读。
          for (final child in previous)
            ExcludeSemantics(child: IgnorePointer(child: child)),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: Offset(0, child.key == content.key ? 1 / 3 : -1 / 3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: content,
    );
  }
}

/// 播放状态驱动形态动画；动画不参与控制实际播放。— Codex + UI
class ReadAloudPlayPauseButton extends StatefulWidget {
  const ReadAloudPlayPauseButton({
    super.key,
    required this.playing,
    required this.tooltip,
    this.onPressed,
  });
  final bool playing;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<ReadAloudPlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<ReadAloudPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.playing ? 1 : 0,
  );

  void _update() {
    final target = widget.playing ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = target;
    } else {
      _animation.animateTo(target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant ReadAloudPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _update();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton.filled(
    iconSize: 36,
    tooltip: widget.tooltip,
    onPressed: widget.onPressed,
    icon: AnimatedIcon(icon: AnimatedIcons.play_pause, progress: _animation),
  );
}

/// 控制栏保留原来的挂载状态，隐藏期间不接受点击与读屏访问。— Codex + UI
class ReadAloudControlsVisibility extends StatelessWidget {
  const ReadAloudControlsVisibility({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget frame(double factor, Widget child) => IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: ClipRect(
          child: Align(
            heightFactor: factor,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: factor,
              child: FractionalTranslation(
                translation: Offset(0, (1 - factor) * 0.2),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    final target = visible ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) return frame(target, child);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: Duration(milliseconds: visible ? 320 : 240),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, factor, child) => frame(factor, child!),
    );
  }
}
