import '../../features/privacy/privacy_controller.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderImage, RenderObject;

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localization.dart';
import '../../models/book.dart';
import '../../providers/audio/audio_notifier.dart';
import '../../providers/audio/read_aloud_capsule.dart';
import '../../features/reader/application/reader_notifier.dart';
import '../../routes.dart';
import '../../services/platform_bridge_service.dart';
import '../book_cover.dart';
import 'read_aloud_player_transition.dart';

/// 延后发布路由变化，避免 Navigator 构建期间修改浮层状态。
class ReadAloudCapsuleObserver extends NavigatorObserver {
  final top = ValueNotifier<Route<dynamic>?>(null);
  int _revision = 0;
  bool _disposed = false;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && revision == _revision) top.value = topRoute;
    });
  }

  void dispose() {
    _disposed = true;
    top.dispose();
  }
}

/// 全局浮层只呈现已有会话，不负责初始化播放或改变阅读进度。
class ReadAloudCapsuleHost extends ConsumerStatefulWidget {
  const ReadAloudCapsuleHost({
    super.key,
    required this.child,
    required this.observer,
  });
  final Widget child;
  final ReadAloudCapsuleObserver observer;

  @override
  ConsumerState<ReadAloudCapsuleHost> createState() =>
      _ReadAloudCapsuleHostState();
}

class _ReadAloudCapsuleHostState extends ConsumerState<ReadAloudCapsuleHost> {
  final _capsule = GlobalKey<_FloatingCapsuleState>();
  bool _opening = false;
  ReadAloudPlayerRoute? _playerRoute;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await ref.read(readAloudCapsuleProvider.notifier).load();
    } catch (error) {
      debugPrint('朗读胶囊偏好读取失败：$error');
    }
  }

  Future<void> _openPlayer() async {
    if (_opening) return;
    final navigator = PlatformBridgeService.navigatorKey.currentState;
    final capsule = _capsule.currentState;
    if (navigator == null || capsule == null) return;
    final notifier = ref.read(audioNotifierProvider.notifier);
    final book = notifier.currentBook;
    final route = ReadAloudPlayerRoute(
      settings: const RouteSettings(name: AppRoutes.readAloudPlayer),
      anchor: ReadAloudCapsuleAnchor(
        bounds: () => _capsule.currentState?.panelBounds,
        coverBounds: () => _capsule.currentState?.coverBounds,
        rotation: capsule.coverRotation,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        image: capsule.captureCoverImage(),
      ),
    );
    setState(() {
      _opening = true;
      _playerRoute = route;
    });
    try {
      final result = await navigator.push(route);
      // push 在反向动画开始时返回；保留路由监听直到封面交接结束。
      await route.completed;
      if (!mounted) return;
      if (result == 'classic') {
        ref.read(readAloudCapsuleProvider.notifier).showClassic(true);
        if (book != null &&
            (widget.observer.top.value?.settings.name != AppRoutes.reader ||
                ref.read(readerNotifierProvider).currentBook?.bookUrl !=
                    book.bookUrl)) {
          unawaited(navigator.pushNamed(AppRoutes.reader, arguments: book));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _playerRoute = null;
        });
      }
    }
  }

  Future<void> _savePosition(Offset position) async {
    try {
      await ref
          .read(readAloudCapsuleProvider.notifier)
          .setPosition(position.dx, position.dy);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.readAloudSaveFailed('$error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioNotifierProvider);
    final privacy = ref.watch(privacyControllerProvider);
    final settings = ref.watch(readAloudCapsuleProvider);
    final notifier = ref.read(audioNotifierProvider.notifier);
    final readerDisplay = ref.watch(
      readerNotifierProvider.select(
        (value) => (
          bookUrl: value.currentBook?.bookUrl,
          menuVisible: value.showControls,
        ),
      ),
    );
    ref.listen(audioNotifierProvider, (previous, next) {
      if (next.state != PlayerState.idle &&
          (previous?.state == PlayerState.idle ||
              previous?.bookUrl != next.bookUrl)) {
        ref.read(readAloudCapsuleProvider.notifier).showClassic(false);
      }
    });
    return ValueListenableBuilder<double>(
      valueListenable:
          _playerRoute?.capsuleOpacity ?? const AlwaysStoppedAnimation(1.0),
      builder: (context, handoffOpacity, _) => ValueListenableBuilder(
        valueListenable: widget.observer.top,
        builder: (context, route, _) {
          final name = route?.settings.name;
          final privateBook = notifier.currentBook;
          final hidden =
              privacy.loading ||
              (privateBook != null && privacy.locked(privateBook)) ||
              (_opening && handoffOpacity == 0) ||
              audio.state == PlayerState.idle ||
              audio.isStreamMode ||
              route == null ||
              route is PopupRoute ||
              name == AppRoutes.welcome ||
              name == AppRoutes.welcomeConfig ||
              (name == AppRoutes.readAloudPlayer && handoffOpacity == 0) ||
              name == AppRoutes.readAloudSettings ||
              name == AppRoutes.readAloudConfig ||
              (name == AppRoutes.reader &&
                  (!readerDisplay.menuVisible ||
                      (settings.classicExpanded &&
                          readerDisplay.bookUrl == audio.bookUrl)));
          // 胶囊在 Navigator 外；按钮提示需要自己的 Overlay 祖先。
          return Overlay.wrap(
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                if (!privacy.loading &&
                    (privateBook == null || !privacy.locked(privateBook)))
                  _FloatingCapsule(
                    key: _capsule,
                    audio: audio,
                    notifier: notifier,
                    book: notifier.currentBook,
                    settings: settings,
                    hidden: hidden,
                    inFlight: _opening,
                    handoffOpacity: handoffOpacity,
                    onOpenPlayer: _openPlayer,
                    onPositionChanged: _savePosition,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FloatingCapsule extends StatefulWidget {
  const _FloatingCapsule({
    super.key,
    required this.audio,
    required this.notifier,
    required this.book,
    required this.settings,
    required this.hidden,
    required this.inFlight,
    required this.handoffOpacity,
    required this.onOpenPlayer,
    required this.onPositionChanged,
  });
  final AudioState audio;
  final AudioNotifier notifier;
  final Book? book;
  final ReadAloudCapsuleState settings;
  final bool hidden;
  final bool inFlight;
  final double handoffOpacity;
  final VoidCallback onOpenPlayer;
  final ValueChanged<Offset> onPositionChanged;

  @override
  State<_FloatingCapsule> createState() => _FloatingCapsuleState();
}

class _FloatingCapsuleState extends State<_FloatingCapsule>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _panelKey = GlobalKey();
  final _coverKey = GlobalKey();
  final _coverImageKey = GlobalKey();
  late final _expansion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  late final _movement = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final _edgeRetraction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late Tween<Offset> _position = Tween(
    begin: Offset(widget.settings.x, widget.settings.y),
    end: Offset(widget.settings.x, widget.settings.y),
  );
  Timer? _collapseTimer;
  Offset? _dragPosition;
  bool _expanded = false;
  bool _foreground = true;
  bool _reducedMotion = false;
  bool _busy = false;
  bool _pointerHeld = false;
  bool _edgeHidden = false;
  double _edgeDirection = 1;

  Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  Rect? get panelBounds => _bounds(_panelKey);
  Rect? get coverBounds => _bounds(_coverKey);
  double get coverRotation => _rotation.value * math.pi * 2;

  ui.Image? captureCoverImage() {
    final root = _coverImageKey.currentContext?.findRenderObject();
    ui.Image? image;
    void visit(RenderObject node) {
      if (image != null) return;
      // 图片层先于淡出的占位层，优先复用已解析的实际封面。
      if (node is RenderImage && node.image != null) {
        image = node.image;
        return;
      }
      node.visitChildren(visit);
    }

    if (root != null) visit(root);
    return image?.clone();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_FloatingCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = Offset(widget.settings.x, widget.settings.y);
    if (_dragPosition == null && target != _position.end) {
      _setEdgeHidden(false);
      _moveTo(target);
    }
    _sync(
      resetTimer:
          oldWidget.hidden != widget.hidden ||
          oldWidget.inFlight != widget.inFlight ||
          oldWidget.settings.x != widget.settings.x ||
          oldWidget.settings.y != widget.settings.y ||
          oldWidget.settings.autoCollapse != widget.settings.autoCollapse,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync({bool resetTimer = true}) {
    if (!widget.hidden &&
        !widget.inFlight &&
        _foreground &&
        widget.audio.isPlaying &&
        !_reducedMotion) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else {
      _rotation.stop();
    }
    if (resetTimer) _resetTimer();
  }

  void _resetTimer() {
    _collapseTimer?.cancel();
    final atEdge = _position.end!.dx == 0 || _position.end!.dx == 1;
    if (widget.hidden ||
        widget.inFlight ||
        !_foreground ||
        _pointerHeld ||
        _dragPosition != null) {
      return;
    }
    if (!_expanded) {
      // 已收起时直接贴边半隐藏，不再等待展开态的闲置计时。
      _setEdgeHidden(atEdge);
      return;
    }
    if (widget.settings.autoCollapse) {
      _collapseTimer = Timer(const Duration(seconds: 3), () => _expand(false));
    }
  }

  void _setEdgeHidden(bool value) {
    if (_edgeHidden == value) return;
    _edgeHidden = value;
    if (value) _edgeDirection = _position.end!.dx == 0 ? -1 : 1;
    _edgeRetraction.animateTo(
      value ? 1 : 0,
      duration: _reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
    );
  }

  void _expand(bool value) {
    _expanded = value;
    if (value) _setEdgeHidden(false);
    _expansion.animateTo(
      value ? 1 : 0,
      duration: _reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubicEmphasized,
    );
    _resetTimer();
  }

  void _coverTap() {
    if (!_expanded || _expansion.value < 1) {
      _expand(true);
    } else {
      widget.onOpenPlayer();
    }
  }

  void _moveTo(Offset target, {Offset? from}) {
    _position = Tween(
      begin: from ?? _position.evaluate(_movement),
      end: target,
    );
    if (_reducedMotion) {
      _movement.value = 1;
    } else {
      _movement.forward(from: 0);
    }
  }

  Future<void> _togglePause() async {
    if (_busy || widget.audio.isLoading) return;
    if (widget.audio.isPlaying) {
      widget.notifier.pause();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.notifier.resumeOrPlay();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.readAloudControlFailed('$error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _collapseTimer?.cancel();
    _expansion.dispose();
    _rotation.dispose();
    _movement.dispose();
    _edgeRetraction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? Colors.black : Colors.white;
    final foreground = dark ? Colors.white : Colors.black;
    final strings = context.l10n;
    final image = BookCover(
      coverUrl: widget.book?.customCoverUrl ?? widget.book?.coverUrl,
      sourceOrigin: widget.book?.origin,
      // 使用播放器所需的解码尺寸，形变途中不切换低清与高清图像。
      width: 220,
      height: 308,
      borderRadius: 0,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final minY = media.padding.top + 84;
        final maxY = math.max(
          minY,
          constraints.maxHeight -
              math.max(media.viewPadding.bottom, media.viewInsets.bottom) -
              108,
        );
        final minX = math.min(28.0, constraints.maxWidth / 2);
        final maxX = math.max(minX, constraints.maxWidth - minX);
        return IgnorePointer(
          ignoring: widget.hidden || widget.inFlight,
          child: AnimatedOpacity(
            opacity: widget.hidden ? 0 : widget.handoffOpacity,
            duration: widget.inFlight || _reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            child: ListenableBuilder(
              listenable: widget.notifier,
              builder: (context, _) => AnimatedBuilder(
                animation: Listenable.merge([
                  _expansion,
                  _rotation,
                  _movement,
                  _edgeRetraction,
                ]),
                child: image,
                builder: (context, cover) {
                  final expansion = _expansion.value;
                  final width = 48 + 112 * expansion;
                  final height = 48 + 8 * expansion;
                  final position =
                      _dragPosition ?? _position.evaluate(_movement);
                  final side = math.min(
                    width / 2 + 4,
                    constraints.maxWidth / 2,
                  );
                  final centerX =
                      (minX + position.dx * (maxX - minX)).clamp(
                        side,
                        math.max(side, constraints.maxWidth - side),
                      ) +
                      _edgeDirection *
                          (48 / 2 + 4) *
                          _edgeRetraction.value *
                          (1 - expansion);
                  final centerY = minY + position.dy * (maxY - minY);
                  final count = widget.notifier.currentParagraphs.length;
                  final progress = count > 1
                      ? widget.notifier.currentParagraphIndex / (count - 1)
                      : 0.0;
                  return Stack(
                    children: [
                      Positioned(
                        left: centerX - width / 2,
                        top: centerY - height / 2,
                        width: width,
                        height: height,
                        child: Listener(
                          onPointerDown: (_) {
                            _pointerHeld = true;
                            _setEdgeHidden(false);
                            _resetTimer();
                          },
                          onPointerUp: (_) {
                            _pointerHeld = false;
                            _resetTimer();
                          },
                          onPointerCancel: (_) {
                            _pointerHeld = false;
                            _resetTimer();
                          },
                          child: GestureDetector(
                            onPanStart: (_) {
                              _movement.stop();
                              setState(
                                () => _dragPosition = _position.evaluate(
                                  _movement,
                                ),
                              );
                              _resetTimer();
                            },
                            onPanUpdate: (details) => setState(() {
                              final previous = _dragPosition!;
                              _dragPosition = Offset(
                                (previous.dx +
                                        details.delta.dx /
                                            math.max(1, maxX - minX))
                                    .clamp(0, 1),
                                (previous.dy +
                                        details.delta.dy /
                                            math.max(1, maxY - minY))
                                    .clamp(0, 1),
                              );
                            }),
                            onPanEnd: (_) {
                              final from = _dragPosition!;
                              final target = Offset(
                                from.dx < 0.15
                                    ? 0
                                    : from.dx > 0.85
                                    ? 1
                                    : from.dx,
                                from.dy,
                              );
                              setState(() => _dragPosition = null);
                              _moveTo(target, from: from);
                              widget.onPositionChanged(target);
                              if (target.dx == 0 || target.dx == 1) {
                                _expand(false);
                              }
                              _resetTimer();
                            },
                            onPanCancel: () {
                              setState(() => _dragPosition = null);
                              _resetTimer();
                            },
                            child: Material(
                              key: _panelKey,
                              color: background,
                              elevation: expansion * 8,
                              borderRadius: BorderRadius.circular(height / 2),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  8 * expansion,
                                  4 * expansion,
                                  4 * expansion,
                                  4 * expansion,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      key: _coverKey,
                                      width: 48 - 8 * expansion,
                                      height: 48 - 8 * expansion,
                                      child: Semantics(
                                        button: true,
                                        label:
                                            '${widget.audio.bookName} · ${strings.readAloudPlayer}',
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: _coverTap,
                                          child: ClipOval(
                                            child: Transform.rotate(
                                              angle: coverRotation,
                                              child: RepaintBoundary(
                                                key: _coverImageKey,
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8 * expansion),
                                    SizedBox(
                                      width: 100 * expansion,
                                      height: 48,
                                      child: ClipRect(
                                        child: OverflowBox(
                                          alignment: Alignment.centerLeft,
                                          minWidth: 100,
                                          maxWidth: 100,
                                          minHeight: 48,
                                          maxHeight: 48,
                                          child: Opacity(
                                            opacity: expansion,
                                            child: IgnorePointer(
                                              ignoring: expansion < 0.99,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    tooltip:
                                                        widget.audio.isPlaying
                                                        ? strings.pause
                                                        : strings.play,
                                                    color: foreground,
                                                    icon: Icon(
                                                      widget.audio.isPlaying
                                                          ? Icons.pause
                                                          : Icons.play_arrow,
                                                    ),
                                                    onPressed:
                                                        _busy ||
                                                            widget
                                                                .audio
                                                                .isLoading
                                                        ? null
                                                        : _togglePause,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  SizedBox(
                                                    width: 48,
                                                    height: 48,
                                                    child: Stack(
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        SizedBox(
                                                          width: 40,
                                                          height: 40,
                                                          child: CircularProgressIndicator(
                                                            value: progress
                                                                .clamp(0, 1),
                                                            strokeWidth: 2,
                                                            color: foreground
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            backgroundColor:
                                                                foreground
                                                                    .withValues(
                                                                      alpha:
                                                                          0.15,
                                                                    ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip: strings
                                                              .readAloudStop,
                                                          color: foreground,
                                                          icon: const Icon(
                                                            Icons.close,
                                                          ),
                                                          onPressed: widget
                                                              .notifier
                                                              .stop,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
