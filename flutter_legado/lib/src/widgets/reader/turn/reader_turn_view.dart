import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../../../features/reader/application/reader_state.dart';
import 'page_direction.dart';
import 'page_snapshot.dart';
import 'page_snapshot_cache.dart';
import 'page_turn_controller.dart';
import 'painters/cover_page_painter.dart';
import 'painters/simulation_curl_painter.dart';
import 'painters/slide_page_painter.dart';

/// Horizontal page-turn host: live page + snapshot CustomPaint overlay.
class ReaderTurnView extends StatefulWidget {
  const ReaderTurnView({
    super.key,
    required this.mode,
    required this.pageIndex,
    required this.pageCount,
    required this.buildPage,
    required this.onPageChanged,
    required this.onTurnChapterPrev,
    required this.onTurnChapterNext,
    required this.hasChapterPrev,
    required this.hasChapterNext,
    this.overlay,
    this.backPageColor = const Color(0xFFECECEC),
    this.chapterPrevPage,
    this.chapterNextPage,
    this.selectionActive,
    this.layoutGeneration = 0,
    this.paintRevision = 0,
  });

  final PageTurnMode mode;
  final int pageIndex;
  final int pageCount;
  final Widget Function(int index) buildPage;
  final void Function(int index) onPageChanged;
  final VoidCallback onTurnChapterPrev;
  final VoidCallback onTurnChapterNext;
  final bool hasChapterPrev;
  final bool hasChapterNext;

  /// Drawn above the live page but under the turn overlay (e.g. click zones).
  final Widget? overlay;

  /// Simulation back-of-page fill (Jingshiro bgMeanColor).
  final Color backPageColor;

  /// 相邻章边界页预览（父级预载：下一章首屏 / 上一章末屏），
  /// 用于章边界turn的动画与承接显示（[UI_SYNC_REFACTOR S6 修 | 2026-09-08]
  /// 用户反馈：章末翻页无动画直接闪现 → 章边界参与快照与画笔）— Qoder
  final Widget? chapterPrevPage;
  final Widget? chapterNextPage;

  /// 文字选区拥有指针时，原始指针监听不得启动翻页。
  final ValueListenable<bool>? selectionActive;

  /// 即使页数不变，正文重排也要使旧翻页位图失效。
  final int layoutGeneration;

  /// 评论数量等仅改变绘制的内容也需要更新翻页快照。
  final int paintRevision;

  @override
  State<ReaderTurnView> createState() => ReaderTurnViewState();
}

class ReaderTurnViewState extends State<ReaderTurnView>
    with TickerProviderStateMixin {
  final PageTurnController _controller = PageTurnController();
  bool _selectionOwnsPointer = false;
  int? _activePointer;
  int _turnGeneration = 0;

  // 页码提交后父组件尚未重建时，后续输入也必须从已提交页继续。
  int? _pendingPageIndex;
  int get _pageIndex => _pendingPageIndex ?? widget.pageIndex;

  void _onSelectionChanged() {
    if (widget.selectionActive?.value != true) return;
    _selectionOwnsPointer = true;
    _turnGeneration++;
    _controller.resetGesture();
    if (_overlayVisible && mounted) setState(() => _overlayVisible = false);
  }

  final PageSnapshotCache _cache = PageSnapshotCache();
  final GlobalKey _prevBoundaryKey = GlobalKey();
  final GlobalKey _curBoundaryKey = GlobalKey();
  final GlobalKey _nextBoundaryKey = GlobalKey();
  final GlobalKey _chapPrevBoundaryKey = GlobalKey();
  final GlobalKey _chapNextBoundaryKey = GlobalKey();

  /// 章边界页快照（父级预载页抓取）
  ui.Image? _chapPrevImg;
  ui.Image? _chapNextImg;

  /// 章边界 turn 进行中/承接中（遮罩保留至父级章节落地）
  bool _chapterTurning = false;
  PageTurnDirection _chapterTurnDir = PageTurnDirection.none;

  bool _overlayVisible = false;
  int _warmGeneration = 0;

  /// Gesture may cross chapter; bitmap exists only for in-chapter neighbors.
  bool get _gestureHasPrev => _pageIndex > 0 || widget.hasChapterPrev;
  bool get _gestureHasNext =>
      _pageIndex < widget.pageCount - 1 || widget.hasChapterNext;

  bool get _captureHasPrev => _pageIndex > 0;
  bool get _captureHasNext => _pageIndex < widget.pageCount - 1;

  /// 有效邻页快照：章内邻页优先，章边界回退到预载的相邻章页
  ui.Image? get _effPrev {
    if (_captureHasPrev) return _cache.display?.prev;
    if (widget.hasChapterPrev && widget.chapterPrevPage != null) {
      return _chapPrevImg;
    }
    return null;
  }

  ui.Image? get _effNext {
    if (_captureHasNext) return _cache.display?.next;
    if (widget.hasChapterNext && widget.chapterNextPage != null) {
      return _chapNextImg;
    }
    return null;
  }

  PageTurnSettleStyle get _settleStyle {
    switch (widget.mode) {
      case PageTurnMode.cover:
      case PageTurnMode.slide:
        return PageTurnSettleStyle.horizontal;
      case PageTurnMode.simulate:
      case PageTurnMode.none:
      case PageTurnMode.scroll:
        return PageTurnSettleStyle.simulation;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerTick);
    widget.selectionActive?.addListener(_onSelectionChanged);
    _scheduleWarmSnapshots();
  }

  @override
  void didUpdateWidget(covariant ReaderTurnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionActive != widget.selectionActive) {
      oldWidget.selectionActive?.removeListener(_onSelectionChanged);
      widget.selectionActive?.addListener(_onSelectionChanged);
    }
    final pageChanged = oldWidget.pageIndex != widget.pageIndex;
    final acceptedPendingPage = _pendingPageIndex == widget.pageIndex;
    if (oldWidget.layoutGeneration != widget.layoutGeneration ||
        oldWidget.mode != widget.mode ||
        oldWidget.pageCount > widget.pageCount ||
        (pageChanged && !acceptedPendingPage)) {
      _turnGeneration++;
      _activePointer = null;
      _pendingPageIndex = null;
      _controller.resetGesture();
      _cache.invalidate();
      _warmGeneration++;
      _overlayVisible = false;
    }
    if (pageChanged || acceptedPendingPage) _pendingPageIndex = null;
    final chapterLanded =
        oldWidget.layoutGeneration != widget.layoutGeneration ||
        oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.pageCount != widget.pageCount ||
        oldWidget.chapterPrevPage != widget.chapterPrevPage ||
        oldWidget.chapterNextPage != widget.chapterNextPage;
    if (chapterLanded && _chapterTurning) {
      // 父级章节已落地：退出承接态、收起遮罩
      setState(() {
        _chapterTurning = false;
        _chapterTurnDir = PageTurnDirection.none;
        _overlayVisible = false;
      });
      _scheduleWarmSnapshots();
      return;
    }
    // [UI_SYNC_REFACTOR S6 修 | 2026-09-08] 相邻章预览变更即作废其位图
    //（防旧章残留位图被当作"下一章"滑入 → 用户可见"闪现正文内容"），
    // 并立即重新抓取新预览 — Qoder
    if (oldWidget.chapterNextPage != widget.chapterNextPage) {
      _chapNextImg?.dispose();
      _chapNextImg = null;
    }
    if (oldWidget.chapterPrevPage != widget.chapterPrevPage) {
      _chapPrevImg?.dispose();
      _chapPrevImg = null;
    }
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.pageCount != widget.pageCount ||
        oldWidget.mode != widget.mode ||
        oldWidget.paintRevision != widget.paintRevision ||
        oldWidget.layoutGeneration != widget.layoutGeneration ||
        oldWidget.backPageColor != widget.backPageColor ||
        oldWidget.chapterNextPage != widget.chapterNextPage ||
        oldWidget.chapterPrevPage != widget.chapterPrevPage) {
      _scheduleWarmSnapshots();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerTick);
    widget.selectionActive?.removeListener(_onSelectionChanged);
    _controller.dispose();
    _cache.invalidate();
    _chapPrevImg?.dispose();
    _chapNextImg?.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  void _scheduleWarmSnapshots() {
    if (widget.mode == PageTurnMode.none ||
        widget.mode == PageTurnMode.scroll) {
      return;
    }
    if (widget.pageCount <= 0) return;
    final gen = ++_warmGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || gen != _warmGeneration) return;
      // 此时本帧已绘制完成，可以抓取；再等待 endOfFrame 会多等一帧甚至停滞。
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final ok = await _cache.refresh(
        prevKey: _prevBoundaryKey,
        curKey: _curBoundaryKey,
        nextKey: _nextBoundaryKey,
        pixelRatio: dpr,
        hasPrev: _captureHasPrev,
        hasNext: _captureHasNext,
      );
      if (!mounted || gen != _warmGeneration) return;
      if (ok) {
        // 先更新画布，不能等相邻章抓取结束才替换已释放的旧图片引用。
        setState(() => _enableDragOverlayIfReady());
      }
      await _captureChapterBoundaries(dpr, gen);
      if (mounted && ok && gen == _warmGeneration) {
        setState(() => _enableDragOverlayIfReady());
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _enableDragOverlayIfReady() {
    if (_overlayVisible ||
        _activePointer == null ||
        !_controller.isDragging ||
        _chapterTurning ||
        _selectionOwnsPointer ||
        widget.selectionActive?.value == true ||
        widget.mode == PageTurnMode.none ||
        widget.mode == PageTurnMode.scroll) {
      return;
    }
    final direction = _controller.direction;
    if (_cache.hasCur &&
        ((direction == PageTurnDirection.prev && _effPrev != null) ||
            (direction == PageTurnDirection.next && _effNext != null))) {
      _overlayVisible = true;
    }
  }

  Future<bool> _ensureCacheReady() async {
    if (_cache.hasCur) return true;
    final gen = _warmGeneration;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return false;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final ok = await _cache.refresh(
      prevKey: _prevBoundaryKey,
      curKey: _curBoundaryKey,
      nextKey: _nextBoundaryKey,
      pixelRatio: dpr,
      hasPrev: _captureHasPrev,
      hasNext: _captureHasNext,
    );
    if (!mounted || gen != _warmGeneration) return false;
    await _captureChapterBoundaries(dpr, gen);
    return ok && gen == _warmGeneration;
  }

  /// 抓取相邻章预载页快照（章边界动画与承接用）
  Future<void> _captureChapterBoundaries(double dpr, int generation) async {
    if (widget.chapterPrevPage != null) {
      final img = await captureBoundary(_chapPrevBoundaryKey, pixelRatio: dpr);
      if (img != null && (!mounted || generation != _warmGeneration)) {
        img.dispose();
        return;
      }
      if (img != null) {
        _chapPrevImg?.dispose();
        _chapPrevImg = img;
      }
    }
    if (widget.chapterNextPage != null) {
      final img = await captureBoundary(_chapNextBoundaryKey, pixelRatio: dpr);
      if (img != null && (!mounted || generation != _warmGeneration)) {
        img.dispose();
        return;
      }
      if (img != null) {
        _chapNextImg?.dispose();
        _chapNextImg = img;
      }
    }
  }

  /// Programmatic turn used by tap zones / volume keys / auto-read.
  Future<void> turnByAnim(PageTurnDirection dir) async {
    if (widget.selectionActive?.value == true) return;
    if (dir == PageTurnDirection.none) return;
    if (_chapterTurning) return;
    final generation = ++_turnGeneration;
    _controller.finishSettle();
    if (_chapterTurning) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;

    if (widget.mode == PageTurnMode.none) {
      _applyCompleted(dir);
      return;
    }

    // 章边界：有预载相邻章快照则照常动画；缺失才瞬时填充
    if (dir == PageTurnDirection.prev && !_captureHasPrev) {
      if (_chapPrevImg == null) {
        _applyCompleted(dir);
        return;
      }
    }
    if (dir == PageTurnDirection.next && !_captureHasNext) {
      if (_chapNextImg == null) {
        _applyCompleted(dir);
        return;
      }
    }

    final ready = await _ensureCacheReady();
    if (!mounted || generation != _turnGeneration) return;
    if (!ready || !_cache.hasCur) {
      _applyCompleted(dir);
      return;
    }

    setState(() => _overlayVisible = true);

    await _controller.turnByAnim(
      dir,
      vsync: this,
      viewWidth: size.width,
      viewHeight: size.height,
      hasPrev: _gestureHasPrev,
      hasNext: _gestureHasNext,
      onCompleted: _applyCompleted,
      settleStyle: _settleStyle,
    );
    if (mounted && generation == _turnGeneration && !_chapterTurning) {
      setState(() => _overlayVisible = false);
      _scheduleWarmSnapshots();
    }
  }

  void _applyCompleted(PageTurnDirection dir) {
    if (_chapterTurning) return;
    if (dir == PageTurnDirection.prev) {
      if (_pageIndex > 0) {
        _commitPage(_pageIndex - 1);
      } else if (widget.hasChapterPrev) {
        // 章边界：进入承接态（遮罩保留至父级章节落地，防闪现）
        setState(() {
          _chapterTurning = true;
          _chapterTurnDir = dir;
          _overlayVisible = false;
        });
        widget.onTurnChapterPrev();
      }
    } else if (dir == PageTurnDirection.next) {
      if (_pageIndex < widget.pageCount - 1) {
        _commitPage(_pageIndex + 1);
      } else if (widget.hasChapterNext) {
        setState(() {
          _chapterTurning = true;
          _chapterTurnDir = dir;
          _overlayVisible = false;
        });
        widget.onTurnChapterNext();
      }
    }
  }

  void _commitPage(int index) {
    setState(() {
      _pendingPageIndex = index;
      _overlayVisible = false;
    });
    // 旧快照属于提交前的页，下一次拖动不得继续绘制它。
    _cache.invalidate();
    _scheduleWarmSnapshots();
    widget.onPageChanged(index);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_activePointer != null || _chapterTurning) return;
    _selectionOwnsPointer = widget.selectionActive?.value ?? false;
    if (_selectionOwnsPointer) return;
    _activePointer = e.pointer;
    _turnGeneration++;
    final size = context.size;
    _controller.onPointerDown(
      e.localPosition,
      viewWidth: size?.width,
      viewHeight: size?.height,
    );
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer || _chapterTurning) return;
    if (_selectionOwnsPointer || widget.selectionActive?.value == true) return;
    final size = context.size;
    if (size == null) return;
    final slop =
        MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;

    final locked = _controller.onPointerMove(
      e.localPosition,
      hasPrev: _gestureHasPrev,
      hasNext: _gestureHasNext,
      slop: slop,
      viewWidth: size.width,
      viewHeight: size.height,
    );

    // 方向锁定后仍检查快照，慢划途中就绪的图片也能恢复跟手动画。
    if (locked) setState(() => _enableDragOverlayIfReady());

    // Jingshiro SimulationPageDelegate.onTouch MOVE mid-band Y pin.
    if (widget.mode == PageTurnMode.simulate &&
        _controller.direction != PageTurnDirection.none) {
      final h = size.height;
      final startY = _controller.startY;
      final dir = _controller.direction;
      if ((startY > h / 3 && startY < h * 2 / 3) ||
          dir == PageTurnDirection.prev) {
        _controller.touchY = h;
      }
      if (startY > h / 3 && startY < h / 2 && dir == PageTurnDirection.next) {
        _controller.touchY = 1;
      }
    }
  }

  Future<void> _onPointerUp(PointerUpEvent e) async {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_chapterTurning ||
        _selectionOwnsPointer ||
        widget.selectionActive?.value == true) {
      _controller.resetGesture();
      return;
    }
    await _finishGesture();
  }

  Future<void> _onPointerCancel(PointerCancelEvent e) async {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_chapterTurning || _selectionOwnsPointer) {
      _controller.resetGesture();
      return;
    }
    _controller.isCancel = true;
    await _finishGesture();
  }

  Future<void> _finishGesture() async {
    final generation = _turnGeneration;
    final size = context.size;
    if (size == null) return;

    final dir = _controller.direction;
    final cancel = _controller.isCancel;

    if (widget.mode == PageTurnMode.none) {
      if (dir != PageTurnDirection.none && !cancel) {
        _applyCompleted(dir);
      }
      _controller.resetGesture();
      return;
    }

    // No overlay (cache miss or chapter edge): instant fill when not cancelled.
    if (!_overlayVisible && dir != PageTurnDirection.none) {
      if (!cancel) {
        _applyCompleted(dir);
      }
      _controller.resetGesture();
      _scheduleWarmSnapshots();
      return;
    }

    if (dir == PageTurnDirection.none) {
      setState(() => _overlayVisible = false);
      _controller.resetGesture();
      return;
    }

    await _controller.onPointerUp(
      vsync: this,
      viewWidth: size.width,
      viewHeight: size.height,
      onCompleted: _applyCompleted,
      settleStyle: _settleStyle,
    );
    // 中断动画的等待也会结束，旧收尾不能隐藏新一轮的翻页画布。
    if (mounted && generation == _turnGeneration && !_chapterTurning) {
      setState(() => _overlayVisible = false);
      _scheduleWarmSnapshots();
    }
  }

  CustomPainter? _buildPainter(Size size) {
    final c = _controller;
    final snap = _cache.display;
    final running = c.isDragging || c.isSettling;
    switch (widget.mode) {
      case PageTurnMode.slide:
        return SlidePagePainter(
          cur: snap?.cur,
          prev: _effPrev,
          next: _effNext,
          direction: c.direction,
          touchX: c.touchX,
          startX: c.startX,
          viewSize: size,
          isRunning: running,
        );
      case PageTurnMode.cover:
        return CoverPagePainter(
          cur: snap?.cur,
          prev: _effPrev,
          next: _effNext,
          direction: c.direction,
          touchX: c.touchX,
          startX: c.startX,
          viewSize: size,
          isRunning: running,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
      case PageTurnMode.simulate:
        return SimulationCurlPainter(
          cur: snap?.cur,
          prev: _effPrev,
          next: _effNext,
          direction: c.direction,
          touchX: c.touchX,
          touchY: c.touchY,
          cornerX: c.cornerX,
          cornerY: c.cornerY,
          viewSize: size,
          isRunning: running,
          backPageColor: widget.backPageColor,
        );
      case PageTurnMode.none:
      case PageTurnMode.scroll:
        return null;
    }
  }

  Widget _boundaryPage(GlobalKey key, int? index) {
    if (index == null || index < 0 || index >= widget.pageCount) {
      return const SizedBox.shrink();
    }
    // Opaque page (bg + content) so Cover/Slide bitmaps fully occlude underlay —
    // Jingshiro screenshots the full page view, not transparent text alone.
    return RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: widget.backPageColor,
        child: SizedBox.expand(child: widget.buildPage(index)),
      ),
    );
  }

  Widget _boundaryWidget(GlobalKey key, Widget child) {
    return RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: widget.backPageColor,
        child: SizedBox.expand(child: child),
      ),
    );
  }

  Widget _livePage(int pageIndex) {
    return ColoredBox(
      color: widget.backPageColor,
      child: KeyedSubtree(
        key: ValueKey('live-$pageIndex'),
        child: widget.buildPage(pageIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = _pageIndex;
    final prevIndex = pageIndex > 0 ? pageIndex - 1 : null;
    final nextIndex = pageIndex < widget.pageCount - 1 ? pageIndex + 1 : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final painter = _overlayVisible ? _buildPainter(size) : null;
        // Jingshiro ReadView: live curPage stays under the horizontal canvas.
        final keepLiveUnderlay =
            widget.mode == PageTurnMode.cover ||
            widget.mode == PageTurnMode.slide;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (e) => _onPointerUp(e),
          onPointerCancel: (e) => _onPointerCancel(e),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Slight opacity so RepaintBoundary.toImage still paints.
              Opacity(
                opacity: 0.01,
                child: IgnorePointer(
                  child: SelectionContainer.disabled(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _boundaryPage(_prevBoundaryKey, prevIndex),
                        _boundaryPage(_curBoundaryKey, pageIndex),
                        _boundaryPage(_nextBoundaryKey, nextIndex),
                        if (widget.chapterPrevPage != null)
                          _boundaryWidget(
                            _chapPrevBoundaryKey,
                            widget.chapterPrevPage!,
                          ),
                        if (widget.chapterNextPage != null)
                          _boundaryWidget(
                            _chapNextBoundaryKey,
                            widget.chapterNextPage!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_chapterTurning)
                // 承接态：直接显示相邻章预载页（新章落地前无闪现）
                ColoredBox(
                  color: widget.backPageColor,
                  child: _chapterTurnDir == PageTurnDirection.next
                      ? (widget.chapterNextPage ?? const SizedBox.shrink())
                      : (widget.chapterPrevPage ?? const SizedBox.shrink()),
                )
              else if (!_overlayVisible || keepLiveUnderlay)
                _livePage(pageIndex)
              else
                ColoredBox(color: widget.backPageColor),
              if (widget.overlay != null) widget.overlay!,
              if (painter != null)
                CustomPaint(
                  size: size,
                  painter: painter,
                  child: const SizedBox.expand(),
                ),
            ],
          ),
        );
      },
    );
  }
}
