import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../privacy/privacy_gate.dart';
import '../../privacy/privacy_controller.dart';
import '../../audio/application/audio_notifier.dart';

import '../presentation/read_aloud_player_screen.dart';

/// 起点在宿主中保留布局；收回时重新测量，适应横竖屏与窗口大小变化。
class ReadAloudCapsuleAnchor {
  const ReadAloudCapsuleAnchor({
    required this.bounds,
    required this.coverBounds,
    required this.color,
    required this.rotation,
    this.image,
  });

  final Rect? Function() bounds;
  final Rect? Function() coverBounds;
  final Color color;
  final double rotation;

  /// 已显示的封面图像克隆，由承载动画的路由释放。
  final ui.Image? image;
}

/// 封面测量与顶栏拖拽只服务界面动画，不进入播放状态。
class ReadAloudPlayerTransition extends InheritedWidget {
  const ReadAloudPlayerTransition({
    super.key,
    required super.child,
    required this.route,
  });
  final ReadAloudPlayerRoute route;

  static ReadAloudPlayerRoute? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReadAloudPlayerTransition>()
      ?.route;

  @override
  bool updateShouldNotify(ReadAloudPlayerTransition oldWidget) =>
      route != oldWidget.route;
}

/// 从胶囊外形扩展到全屏；封面独立移动，正文不随容器缩放。
class ReadAloudPlayerRoute extends PageRoute<String> {
  ReadAloudPlayerRoute({required super.settings, this.anchor});
  final ReadAloudCapsuleAnchor? anchor;
  ui.Image? get coverImage => anchor?.image;
  final coverKey = GlobalKey();
  final coverInFlight = ValueNotifier(true);
  final capsuleOpacity = ValueNotifier(0.0);
  Rect? _panelStart;
  Rect? _coverStart;
  Rect? _coverEnd;
  double _gestureVelocity = 0;
  bool _dragging = false;
  bool _returning = false;

  bool get _reduceMotion =>
      navigator != null && MediaQuery.disableAnimationsOf(navigator!.context);

  @override
  bool get opaque => false;
  @override
  bool get barrierDismissible => false;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 350);
  @override
  Duration get reverseTransitionDuration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 280);

  @override
  AnimationController createAnimationController() {
    final animation = super.createAnimationController();
    animation.addStatusListener((status) {
      coverInFlight.value = status != AnimationStatus.completed;
      if (status == AnimationStatus.completed) _returning = false;
    });
    animation.addListener(() {
      // 在路由移除前完成封面交接，避免两层之间出现空白帧。
      final end = (animation.value / 0.035).clamp(0.0, 1.0);
      capsuleOpacity.value = _returning && anchor != null && !_reduceMotion
          ? 1 - Curves.easeInOut.transform(end)
          : 0;
    });
    return animation;
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    if (_reduceMotion) return null;
    if (!forward) {
      return _CapsuleReturnSimulation(controller!.value, _gestureVelocity);
    }
    return SpringSimulation(
      SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 1),
      controller!.value,
      forward ? 1 : 0,
      _gestureVelocity,
      snapToEnd: true,
      // 小于约一个逻辑像素时收尾，避免几乎静止的长尾。
      tolerance: const Tolerance(distance: 0.001, velocity: 0.02),
    );
  }

  Rect? _measureCover() {
    final box = coverKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    final screen = Offset.zero & MediaQuery.sizeOf(navigator!.context);
    // 目录与正文页关闭时不使用横向滑出屏幕的封面锚点。
    return screen.contains(bounds.center) ? bounds : null;
  }

  @override
  bool didPop(String? result) {
    // 菜单的 LocalHistoryEntry 先关闭菜单，不启动播放器收回。
    if (willHandlePopInternally) return super.didPop(result);
    _returning = result != 'classic';
    _panelStart = anchor?.bounds();
    _coverStart = anchor?.coverBounds();
    _coverEnd = _measureCover();
    return super.didPop(result);
  }

  void dragStart(DragStartDetails details) {
    if (!isCurrent ||
        _reduceMotion ||
        animation!.status != AnimationStatus.completed) {
      return;
    }
    _dragging = true;
    _returning = true;
    _coverEnd = _measureCover();
    _panelStart = anchor?.bounds();
    _coverStart = anchor?.coverBounds();
    controller!.stop();
    // 停在完整展开位置时仍显示页面封面，实际位移后再由动画状态交接。
  }

  double get _dragRange =>
      math.max(120, MediaQuery.sizeOf(navigator!.context).height * 0.45);

  void dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    controller!.value = (controller!.value - details.delta.dy / _dragRange)
        .clamp(0, 1);
  }

  void dragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _gestureVelocity = -details.velocity.pixelsPerSecond.dy / _dragRange;
    if (controller!.value < 0.65 || details.velocity.pixelsPerSecond.dy > 650) {
      navigator!.pop();
    } else {
      controller!.animateWith(createSimulation(forward: true)!);
    }
    _gestureVelocity = 0;
  }

  void dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    controller!.animateWith(createSimulation(forward: true)!);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ReadAloudPlayerTransition(
    route: this,
    child: Consumer(
      builder: (context, ref, _) {
        ref.watch(audioNotifierProvider);
        return PrivacyBookGate(
          book: ref.read(audioNotifierProvider.notifier).currentBook,
          builder: (_) => const ReadAloudPlayerScreen(),
        );
      },
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => Consumer(
    builder: (context, ref, _) {
      final privacy = ref.watch(privacyControllerProvider);
      ref.watch(audioNotifierProvider);
      final book = ref.read(audioNotifierProvider.notifier).currentBook;
      if (privacy.loading || (book != null && privacy.locked(book))) {
        return child;
      }
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final progress = animation.value.clamp(0.0, 1.0);
          final complete = animation.status == AnimationStatus.completed;
          final reduced = MediaQuery.disableAnimationsOf(context);
          if (reduced || anchor == null) {
            // 无可靠起点时简化为淡入，不猜测封面位置。
            return FadeTransition(opacity: animation, child: child);
          }
          final size = MediaQuery.sizeOf(context);
          final screen = Offset.zero & size;
          _panelStart ??= anchor?.bounds();
          _coverStart ??= anchor?.coverBounds();
          if (!_dragging && animation.status != AnimationStatus.reverse) {
            _coverEnd = _measureCover();
          }
          final source = _panelStart;
          if (source == null) {
            return FadeTransition(opacity: animation, child: child);
          }
          final panel = Rect.lerp(source, screen, progress)!;
          final radius = lerpDouble(source.height / 2, 0, progress)!;
          final playerColor = Theme.of(context).scaffoldBackgroundColor;
          final color = Color.lerp(anchor!.color, playerColor, progress)!;
          final coverSource = _coverStart;
          final target = _coverEnd;
          final movingCover =
              coverSource != null && coverImage != null && !complete;
          final cover = target == null
              ? coverSource
              : Rect.lerp(coverSource, target, progress);
          final flightOpacity = 1 - capsuleOpacity.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: panel,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
              ClipPath(
                clipper: _PlayerPanelClipper(panel, radius),
                child: IgnorePointer(
                  ignoring: !complete && !_dragging,
                  child: Opacity(
                    opacity: ((progress - 0.25) / 0.75).clamp(0, 1),
                    child: child,
                  ),
                ),
              ),
              if (movingCover && cover != null)
                Positioned.fromRect(
                  rect: cover,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity:
                          (target == null ? 1 - progress : 1) * flightOpacity,
                      child: Transform.rotate(
                        angle: anchor!.rotation * (1 - progress),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            lerpDouble(coverSource.height / 2, 16, progress)!,
                          ),
                          child: RepaintBoundary(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: 220,
                                height: 308,
                                child: RawImage(
                                  image: coverImage,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );

  @override
  void dispose() {
    anchor?.image?.dispose();
    capsuleOpacity.dispose();
    coverInFlight.dispose();
    super.dispose();
  }
}

class _PlayerPanelClipper extends CustomClipper<Path> {
  const _PlayerPanelClipper(this.bounds, this.radius);
  final Rect bounds;
  final double radius;
  @override
  Path getClip(Size size) =>
      Path()
        ..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius)));
  @override
  bool shouldReclip(_PlayerPanelClipper oldClipper) =>
      bounds != oldClipper.bounds || radius != oldClipper.radius;
}

/// 返回在有限时间内结束，延续下滑速度，末尾速度归零。
class _CapsuleReturnSimulation extends Simulation {
  _CapsuleReturnSimulation(this.begin, double initialVelocity)
    : duration = 0.28 * begin.clamp(0.5, 1.0) {
    velocity = initialVelocity.clamp(-3 * begin / duration, 0.0);
  }

  final double begin;
  final double duration;
  late final double velocity;

  double _progress(double time) => (time / duration).clamp(0.0, 1.0);

  @override
  double x(double time) {
    final t = _progress(time);
    return begin * (2 * t * t * t - 3 * t * t + 1) +
        velocity * duration * (t * t * t - 2 * t * t + t);
  }

  @override
  double dx(double time) {
    final t = _progress(time);
    return begin * (6 * t * t - 6 * t) / duration +
        velocity * (3 * t * t - 4 * t + 1);
  }

  @override
  bool isDone(double time) => time >= duration;
}
