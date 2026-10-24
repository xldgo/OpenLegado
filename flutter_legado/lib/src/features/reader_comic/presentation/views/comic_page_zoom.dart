import 'package:flutter/widgets.dart';

/// 分页图片缩放保持在当前页内，换页或关闭缩放后复位。— Codex + UI
class ComicPageZoom extends StatefulWidget {
  const ComicPageZoom({
    super.key,
    required this.enabled,
    required this.active,
    required this.reversed,
    required this.horizontal,
    required this.onZoomChanged,
    required this.child,
  });
  final bool enabled, active, reversed, horizontal;
  final ValueChanged<bool> onZoomChanged;
  final Widget child;

  @override
  State<ComicPageZoom> createState() => _ComicPageZoomState();
}

class _ComicPageZoomState extends State<ComicPageZoom>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_animate);
  Matrix4Tween? _tween;
  bool _zoomed = false;
  Offset _doubleTap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant ComicPageZoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.enabled || !widget.active) && _zoomed) {
      _animation.stop();
      _transform.value = Matrix4.identity();
    }
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.001;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _animate() {
    final tween = _tween;
    if (tween != null) {
      _transform.value = tween.transform(
        Curves.easeOut.transform(_animation.value),
      );
    }
  }

  void _toggleZoom(Size size) {
    // 对齐参考版默认Automatic：横向阅读从对应起始侧放大，纵向跟随点击位置。
    final focal = Offset(
      widget.horizontal ? (widget.reversed ? size.width : 0) : _doubleTap.dx,
      _doubleTap.dy,
    );
    final target = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..setTranslationRaw(-focal.dx * 1.5, -focal.dy * 1.5, 0)
            ..scaleByDouble(2.5, 2.5, 1, 1));
    _tween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onDoubleTapDown: (details) => _doubleTap = details.localPosition,
        onDoubleTap: () => _toggleZoom(constraints.biggest),
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 3,
          panEnabled: _zoomed,
          onInteractionStart: (_) => _animation.stop(),
          child: widget.child,
        ),
      ),
    );
  }
}
