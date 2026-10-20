import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/privacy/privacy_controller.dart';
import '../../features/reader/application/reader_notifier.dart';
import '../book_cover.dart';

typedef _BookTransitionFrame = ({
  Rect bounds,
  BorderRadius radius,
  double coverAspect,
  double opening,
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

  bool get _hasCover => _start != null && _image != null;

  bool get _reduced =>
      navigator != null && MediaQuery.disableAnimationsOf(navigator!.context);

  @override
  Duration get transitionDuration => _reduced
      ? Duration.zero
      : _hasCover
      ? const Duration(milliseconds: 480)
      : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reduced
      ? Duration.zero
      : _hasCover
      ? const Duration(milliseconds: 400)
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
            // 翻盖与放大共用完整进度，避免先展开再翻开；返回也同步合上缩回。
            final retreat = _returnProgress > 0
                ? Curves.easeInOutCubic.transform(
                    (1 - progress / _returnProgress).clamp(0.0, 1.0),
                  )
                : 1.0;
            final returning = _returning ? _returnFrame : null;
            final motion = returning != null
                ? returning.opening * (1 - retreat)
                : Curves.easeInOutCubic.transform(progress);
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
                      0.5,
                      1,
                      curve: Curves.easeInOutCubic,
                    ).transform(motion),
                  )!;
            final placement = morph
                ? returning != null
                      ? Rect.lerp(returning.bounds, source, retreat)!
                      : Rect.lerp(source, full, motion)!
                : full;
            final bounds = Rect.fromLTWH(
              placement.left,
              placement.top,
              placement.width,
              morph ? placement.width * pageAspect : size.height,
            );
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
                          motion,
                        )!
                : BorderRadius.zero;
            final radius = screenRadius / scale;
            if (morph) {
              _lastFrame = (
                bounds: bounds,
                radius: screenRadius,
                coverAspect: coverAspect,
                opening: motion,
              );
            }
            final coverOpacity = morph
                ? 1 - const Interval(0.88, 1).transform(progress)
                : 0.0;
            final complete = animation.status == AnimationStatus.completed;
            final paper = protected
                ? Theme.of(context).scaffoldBackgroundColor
                : visual.background;
            // 固定正文布局与元素身份；裁剪只处理纸面比例/圆角，整体缩放由矩阵完成。
            return Transform(
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
                                alpha: 0.18 * (1 - motion),
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
                        opacity: protected || matchesTarget || complete ? 1 : 0,
                        child: child,
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
                                  Colors.black.withValues(
                                    alpha: 0.16 * math.sin(math.pi * motion),
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.65],
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
                              key: const ValueKey('book-reader-cover-hinge'),
                              alignment: Alignment.centerLeft,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, -0.6 / size.longestSide)
                                ..rotateY(-math.pi * motion),
                              // 共用纸面外阴影和书脊渐变，不再叠加旋转封面的模糊阴影。
                              child: ClipRRect(
                                borderRadius: radius,
                                child: motion <= 0.5
                                    ? RawImage(image: _image, fit: BoxFit.cover)
                                    // 翻过侧面后展示纸张背面，不反向绘制封面文字。
                                    : ColoredBox(
                                        key: const ValueKey(
                                          'book-reader-cover-back',
                                        ),
                                        color: paper,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
