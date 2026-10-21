import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/privacy/privacy_controller.dart';
import '../../features/reader/application/reader_notifier.dart';
import '../../providers/book_open_motion_provider.dart';
import '../book_cover.dart';

typedef _BookTransitionFrame = ({
  Rect bounds,
  BorderRadius radius,
  double coverAspect,
  double opening,
  double reveal,
});

/// 纸面与封面整体缩放位移，封面沿书脊翻开；正文始终按最终视口排版。
/// 沿用 PageRoute 的返回、退出门禁与不透明路由生命周期。— Codex + UI
class BookReaderRoute<T> extends MaterialPageRoute<T> {
  BookReaderRoute({required super.builder, required RouteSettings settings})
    : origin = settings.arguments is BookCoverOrigin
          ? settings.arguments as BookCoverOrigin
          : null,
      super(settings: settings, allowSnapshotting: false) {
    _start = origin?.bounds();
    if (_start != null) _image = origin?.image()?.clone();
  }

  final BookCoverOrigin? origin;
  Rect? _start;
  Rect? _returnBounds;
  ui.Image? _image;
  bool _returning = false;
  _BookTransitionFrame? _lastFrame;
  _BookTransitionFrame? _returnFrame;
  double _returnProgress = 1;
  final _contentKey = GlobalKey();
  BookOpenMotion? _motion;

  bool get _hasCover => _start != null && _image != null;

  bool get _reduced =>
      navigator != null && MediaQuery.disableAnimationsOf(navigator!.context);

  @override
  Duration get transitionDuration => _reduced
      ? Duration.zero
      : _hasCover
      ? const Duration(milliseconds: 420)
      : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reduced
      ? Duration.zero
      : _hasCover
      ? const Duration(milliseconds: 350)
      : super.reverseTransitionDuration;

  // 来源页面不再叠加默认导航的横移、缩放或封面 Hero 飞行。
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      !_hasCover && super.canTransitionFrom(previousRoute);

  @override
  bool didPop(T? result) {
    final destination = origin?.bounds();
    final frame = _lastFrame;
    final progress = animation?.value ?? 1;
    final refreshImage = animation?.status == AnimationStatus.completed;
    final popped = super.didPop(result);
    if (popped) {
      _returning = true;
      _returnBounds = destination;
      _returnFrame = frame;
      _returnProgress = progress;
      if (destination != null && refreshImage) {
        final fresh = origin?.image()?.clone();
        if (fresh != null) {
          _image?.dispose();
          _image = fresh;
        }
      }
    }
    return popped;
  }

  Rect? _inOverlay(Rect? global, Size size) {
    final overlay = navigator?.overlay?.context.findRenderObject();
    if (global == null || overlay is! RenderBox || !overlay.hasSize) {
      return null;
    }
    final rect = Rect.fromPoints(
      overlay.globalToLocal(global.topLeft),
      overlay.globalToLocal(global.bottomRight),
    );
    return rect.isFinite && !rect.isEmpty && (Offset.zero & size).overlaps(rect)
        ? rect
        : null;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 来源消失而更换外层转场时，保留同一正文元素及其会话。
    final content = KeyedSubtree(key: _contentKey, child: child);
    if (MediaQuery.disableAnimationsOf(context)) return content;
    if (!_hasCover || (_returning && _returnBounds == null)) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        content,
      );
    }
    return _buildCoverTransition(animation, content);
  }

  Widget _buildCoverTransition(
    Animation<double> animation,
    Widget content,
  ) => Consumer(
    builder: (context, ref, _) {
      // 每次开书固定一种轨迹，设置变化不改动正在返回的同一路由。
      final motionStyle = _motion ??= ref.read(bookOpenMotionProvider);
      final privacy = ref.watch(privacyControllerProvider);
      final visual = ref.watch(
        readerNotifierProvider.select(
          (state) =>
              (book: state.currentBook, background: state.backgroundColor),
        ),
      );
      final book = visual.book;
      final matchesTarget = book?.bookUrl == origin?.bookUrl;
      // 等待会话切书时按目标书判定封面隐私，不能读取上一本文字作为动画内容。
      final privateBook =
          privacy.find(origin?.bookUrl ?? '') ?? (matchesTarget ? book : null);
      final protected =
          privacy.loading ||
          privacy.error != null ||
          (privacy.settings.enabled &&
              privacy.settings.verifyOnAppStart &&
              !privacy.startVerified) ||
          (privateBook != null && privacy.locked(privateBook));
      return LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: animation,
          child: content,
          builder: (context, child) {
            final size = constraints.biggest;
            final full = Offset.zero & size;
            final reduced = MediaQuery.disableAnimationsOf(context);
            final source = _inOverlay(
              _returning ? _returnBounds : _start,
              size,
            );
            final morph =
                !reduced && !protected && _image != null && source != null;
            final progress = reduced || protected ? 1.0 : animation.value;
            // 三条轨道重叠推进，均直接读取时间进度，避免叠加缓动造成末段拖滞。
            final retreat = _returnProgress > 0
                ? Curves.easeInOutCubic.transform(
                    (1 - progress / _returnProgress).clamp(0.0, 1.0),
                  )
                : 1.0;
            final returning = _returning ? _returnFrame : null;
            final motion = returning != null
                ? returning.opening * (1 - retreat)
                : const Interval(
                    0.08,
                    0.96,
                    curve: Curves.easeInOutCubic,
                  ).transform(progress);
            final travel = Curves.easeInOutCubic.transform(progress);
            final reveal = returning != null
                ? returning.reveal * (1 - retreat)
                : const Interval(
                    0.32,
                    0.88,
                    curve: Curves.easeOutCubic,
                  ).transform(progress);
            final coverAspect = morph
                ? returning != null
                      ? ui.lerpDouble(
                          returning.coverAspect,
                          source.height / source.width,
                          retreat,
                        )!
                      : _start!.height / _start!.width
                : size.height / size.width;
            // 正面封盖与纸面同高，翻过侧面后再扩展为屏幕比例；返回时反向收拢。
            // 高度直接使用原始时间进度，避免对整体缩放的缓动结果再次缓动。
            final pageAspect = returning != null
                ? coverAspect +
                      (returning.bounds.height / returning.bounds.width -
                              returning.coverAspect) *
                          (returning.opening > 0.5
                              ? ((motion - 0.5) / (returning.opening - 0.5))
                                    .clamp(0.0, 1.0)
                              : 0)
                : ui.lerpDouble(
                    coverAspect,
                    size.height / size.width,
                    const Interval(
                      0.52,
                      1,
                      curve: Curves.easeInOutCubic,
                    ).transform(progress),
                  )!;
            final Rect bounds;
            if (!morph) {
              bounds = full;
            } else if (returning != null) {
              final placement = Rect.lerp(returning.bounds, source, retreat)!;
              bounds = Rect.fromLTWH(
                placement.left,
                placement.top,
                placement.width,
                placement.width * pageAspect,
              );
            } else if (motionStyle == BookOpenMotion.top) {
              final width = ui.lerpDouble(source.width, size.width, travel)!;
              bounds = Rect.fromLTWH(
                ui.lerpDouble(source.left, (size.width - width) / 2, travel)!,
                ui.lerpDouble(source.top, 0, travel)!,
                width,
                width * pageAspect,
              );
            } else {
              // 上移贝塞尔控制点，增强向上拱起感；控制点不是轨迹最高点。
              final peakY = math.min(source.top, size.height * 0.20);
              final control = Offset(full.center.dx, peakY);
              final center =
                  source.center * ((1 - travel) * (1 - travel)) +
                  control * (2 * (1 - travel) * travel) +
                  full.center * (travel * travel);
              final width = ui.lerpDouble(source.width, size.width, travel)!;
              bounds = Rect.fromCenter(
                center: center,
                width: width,
                height: width * pageAspect,
              );
            }
            // 文字按最终尺寸布局，再与封面共用绘制变换，不靠扩大裁剪窗口模拟缩放。
            final scale = bounds.width / size.width;
            final paperBounds = Rect.fromLTWH(
              0,
              0,
              size.width,
              bounds.height / scale,
            );
            // 封面只在来源比例下裁切一次，翻开中不再跟随屏幕比例重新裁切。
            final coverBounds = Rect.fromLTWH(
              0,
              0,
              size.width,
              size.width * coverAspect,
            );
            final screenRadius = morph
                ? returning != null
                      ? BorderRadius.lerp(
                          returning.radius,
                          origin!.borderRadius,
                          retreat,
                        )!
                      : BorderRadius.lerp(
                          origin!.borderRadius,
                          BorderRadius.zero,
                          travel,
                        )!
                : BorderRadius.zero;
            final radius = screenRadius / scale;
            if (morph) {
              _lastFrame = (
                bounds: bounds,
                radius: screenRadius,
                coverAspect: coverAspect,
                opening: motion,
                reveal: reveal,
              );
            }
            final coverOpacity = morph
                ? 1 - const Interval(0.72, 1).transform(motion)
                : 0.0;
            final complete = animation.status == AnimationStatus.completed;
            final paper = protected
                ? Theme.of(context).scaffoldBackgroundColor
                : visual.background;
            // 阅读配色独立于应用主题；按纸面亮度连续调节，不分两套深浅动画。
            final darkness = 1 - paper.computeLuminance();
            final crease = Color.lerp(Colors.black, Colors.white, darkness)!;
            final lining = Color.lerp(paper, crease, 0.045)!;
            final shadowAlpha = ui.lerpDouble(0.12, 0.24, darkness)!;
            // 固定正文布局与元素身份；裁剪只处理纸面比例/圆角，整体缩放由矩阵完成。
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  // 同色背景压暗来源列表，避免逐项修改书架或为其截图。
                  child: ColoredBox(
                    key: const ValueKey('book-reader-backdrop'),
                    color: paper.withValues(
                      alpha: morph
                          ? 0.9 *
                                const Interval(
                                  0,
                                  0.3,
                                  curve: Curves.easeOut,
                                ).transform(progress)
                          : 0,
                    ),
                  ),
                ),
                Transform(
                  key: const ValueKey('book-reader-surface-transform'),
                  transform: Matrix4.identity()
                    ..setEntry(0, 0, scale)
                    ..setEntry(1, 1, scale)
                    ..setTranslationRaw(bounds.left, bounds.top, 0),
                  child: Stack(
                    key: const ValueKey('book-reader-transition'),
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fromRect(
                        rect: paperBounds,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: paper,
                            borderRadius: radius,
                            boxShadow: [
                              if (morph && !complete)
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: shadowAlpha * (1 - motion),
                                  ),
                                  blurRadius: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      ClipRRect(
                        key: const ValueKey('book-reader-reveal'),
                        clipBehavior: complete || !morph
                            ? Clip.none
                            : Clip.antiAlias,
                        clipper: _BookRevealClipper(paperBounds, radius),
                        child: IgnorePointer(
                          ignoring: !complete,
                          // 只切换可见性，不对整屏正文做渐变透明合成；门禁内容仍及时显示。
                          child: Opacity(
                            opacity: protected || matchesTarget || complete
                                ? 1
                                : 0,
                            child: Transform.translate(
                              offset: Offset(0, morph ? 4 * (1 - reveal) : 0),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      if (morph && !complete && reveal < 1)
                        Positioned.fromRect(
                          rect: paperBounds,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: radius,
                              // 淡出同色遮罩显示正文，不为全屏文字创建渐变透明合成层。
                              child: ColoredBox(
                                key: const ValueKey('book-reader-content-veil'),
                                color: paper.withValues(alpha: 1 - reveal),
                              ),
                            ),
                          ),
                        ),
                      if (morph && motion > 0 && motion < 1)
                        Positioned.fromRect(
                          rect: paperBounds,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: radius,
                              child: DecoratedBox(
                                key: const ValueKey('book-reader-page-shadow'),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      crease.withValues(
                                        alpha:
                                            0.12 * math.sin(math.pi * motion),
                                      ),
                                      Colors.black.withValues(
                                        alpha:
                                            ui.lerpDouble(
                                              0.16,
                                              0.08,
                                              darkness,
                                            )! *
                                            math.sin(math.pi * motion),
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, 0.015, 0.65],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (coverOpacity > 0 && _image != null)
                        Positioned.fromRect(
                          rect: coverBounds,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Opacity(
                                opacity: coverOpacity,
                                child: Transform(
                                  key: const ValueKey(
                                    'book-reader-cover-hinge',
                                  ),
                                  alignment: Alignment.centerLeft,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, -0.6 / size.longestSide)
                                    ..rotateY(-math.pi * motion),
                                  // 共用纸面外阴影和书脊渐变，不再叠加旋转封面的模糊阴影。
                                  child: ClipRRect(
                                    borderRadius: radius,
                                    child: motion <= 0.5
                                        ? RawImage(
                                            image: _image,
                                            fit: BoxFit.cover,
                                          )
                                        // 翻过侧面后展示纸张背面，不反向绘制封面文字。
                                        : DecoratedBox(
                                            key: const ValueKey(
                                              'book-reader-cover-back',
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color.lerp(
                                                    lining,
                                                    crease,
                                                    0.04,
                                                  )!,
                                                  lining,
                                                ],
                                                stops: const [0, 0.3],
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
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

class _BookRevealClipper extends CustomClipper<RRect> {
  const _BookRevealClipper(this.bounds, this.radius);
  final Rect bounds;
  final BorderRadius radius;

  @override
  RRect getClip(Size size) => radius.toRRect(bounds);

  @override
  bool shouldReclip(_BookRevealClipper oldClipper) =>
      bounds != oldClipper.bounds || radius != oldClipper.radius;
}
