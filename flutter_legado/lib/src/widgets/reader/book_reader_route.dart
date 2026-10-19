import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/privacy/privacy_controller.dart';
import '../../features/reader/application/reader_notifier.dart';
import '../book_cover.dart';

/// 封面展开的导航层：正文固定全屏布局，图片只持有已解码资源的独立引用。
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

  bool get _reduced =>
      navigator != null && MediaQuery.disableAnimationsOf(navigator!.context);

  @override
  Duration get transitionDuration => _reduced
      ? Duration.zero
      : Duration(milliseconds: _start == null ? 160 : 360);

  @override
  Duration get reverseTransitionDuration => _reduced
      ? Duration.zero
      : Duration(milliseconds: _start == null ? 160 : 280);

  // 来源页面不再叠加默认导航的横移、缩放或封面 Hero 飞行。
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  bool didPop(T? result) {
    final destination = origin?.bounds();
    final popped = super.didPop(result);
    if (popped) {
      _returning = true;
      _returnBounds = destination;
      if (destination != null) {
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
      final privateBook = privacy.find(book?.bookUrl ?? '') ?? book;
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
          child: child,
          builder: (context, child) {
            final size = constraints.biggest;
            final full = Offset.zero & size;
            final reduced = MediaQuery.disableAnimationsOf(context);
            final source = _inOverlay(
              _returning ? _returnBounds : _start,
              size,
            );
            final morph =
                !reduced &&
                !protected &&
                source != null &&
                book?.bookUrl == origin?.bookUrl;
            final progress = reduced || protected ? 1.0 : animation.value;
            final expanded = Curves.easeInOutCubic.transform(progress);
            final bounds = morph ? Rect.lerp(source, full, expanded)! : full;
            final radius = morph
                ? BorderRadius.lerp(
                    origin!.borderRadius,
                    BorderRadius.zero,
                    expanded,
                  )!
                : BorderRadius.zero;
            final contentOpacity = morph
                ? const Interval(
                    0.20,
                    0.85,
                    curve: Curves.easeOut,
                  ).transform(progress)
                : progress;
            final coverOpacity = morph
                ? 1 - const Interval(0.12, 0.60).transform(progress)
                : 0.0;
            final complete = animation.status == AnimationStatus.completed;
            // 裁剪、透明度与输入层始终保留，完成时不卸载重建 ReaderScreen。
            return Stack(
              key: const ValueKey('book-reader-transition'),
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: bounds,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: protected
                          ? Theme.of(context).scaffoldBackgroundColor
                          : visual.background,
                      borderRadius: radius,
                      boxShadow: [
                        if (morph && !complete)
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.18 * (1 - expanded),
                            ),
                            blurRadius: 20,
                          ),
                      ],
                    ),
                  ),
                ),
                ClipPath(
                  key: const ValueKey('book-reader-reveal'),
                  clipBehavior: complete || !morph ? Clip.none : Clip.antiAlias,
                  clipper: _BookRevealClipper(bounds, radius),
                  child: IgnorePointer(
                    ignoring: !complete,
                    child: Opacity(opacity: contentOpacity, child: child),
                  ),
                ),
                if (coverOpacity > 0 && _image != null)
                  Positioned.fromRect(
                    rect: bounds,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: coverOpacity,
                          child: ClipRRect(
                            borderRadius: radius,
                            child: RawImage(image: _image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
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

class _BookRevealClipper extends CustomClipper<Path> {
  const _BookRevealClipper(this.bounds, this.radius);
  final Rect bounds;
  final BorderRadius radius;

  @override
  Path getClip(Size size) => Path()..addRRect(radius.toRRect(bounds));

  @override
  bool shouldReclip(_BookRevealClipper oldClipper) =>
      bounds != oldClipper.bounds || radius != oldClipper.radius;
}
