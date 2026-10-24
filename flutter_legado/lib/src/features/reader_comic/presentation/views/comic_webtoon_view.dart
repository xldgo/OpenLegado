import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// 图片索引导航由当前视口处理，不猜测尚未布局图片的高度。— Codex + UI
class ComicWebtoonAnchorController {
  ValueChanged<int>? _jump;
  void jumpToPage(int index) => _jump?.call(index);
}

/// 条漫以记录图片作为滚动原点，前后两段Sliver按需布局。
/// 恢复远处图片时无需先加载前面整章，图片加载改高也不会推走原点。
class ComicWebtoonView extends StatefulWidget {
  const ComicWebtoonView({
    super.key,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.navigationBuilder,
    required this.disableScale,
    required this.withGap,
    required this.sidePadding,
    this.initialPage = 0,
    this.anchors,
    this.onVisibleRangeChanged,
  });
  final ScrollController controller;
  final int pageCount;
  final Widget Function(BuildContext context, int index) pageBuilder;
  final WidgetBuilder navigationBuilder;
  final bool disableScale, withGap;
  final int sidePadding, initialPage;
  final ComicWebtoonAnchorController? anchors;
  final void Function(int first, int last)? onVisibleRangeChanged;

  @override
  State<ComicWebtoonView> createState() => _ComicWebtoonViewState();
}

class _ComicWebtoonViewState extends State<ComicWebtoonView> {
  final _center = GlobalKey();
  final _navigation = GlobalKey();
  final _pages = <int, GlobalKey>{};
  late int _originIndex = widget.initialPage.clamp(0, widget.pageCount - 1);
  (int, int)? _visible;
  bool _reportScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleReport);
    widget.anchors?._jump = _jumpToPage;
    _scheduleReport();
  }

  @override
  void didUpdateWidget(covariant ComicWebtoonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleReport);
      widget.controller.addListener(_scheduleReport);
    }
    if (oldWidget.anchors != widget.anchors) {
      oldWidget.anchors?._jump = null;
      widget.anchors?._jump = _jumpToPage;
    }
    _scheduleReport();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleReport);
    if (widget.anchors?._jump == _jumpToPage) widget.anchors?._jump = null;
    super.dispose();
  }

  void _jumpToPage(int index) {
    final target = index.clamp(0, widget.pageCount - 1);
    if (target == _originIndex) {
      if (widget.controller.hasClients) widget.controller.jumpTo(0);
    } else {
      setState(() {
        _originIndex = target;
        _visible = null;
      });
    }
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      _reportVisiblePages();
    });
  }

  void _reportVisiblePages() {
    if (!widget.controller.hasClients) return;
    final visible = <int>[];
    for (final entry in _pages.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      // Image首帧尚未解码时可能短暂为零高，不能把后面的图片误报为阅读进度。
      if (box.size.height == 0) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox) continue;
      final bounds = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & box.size,
      );
      if (bounds.bottom > 0 &&
          bounds.top < (viewport as RenderBox).size.height) {
        visible.add(entry.key);
      }
    }
    visible.sort();
    if (visible.isEmpty) {
      final box = _navigation.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox) return;
      final bounds = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & box.size,
      );
      if (bounds.bottom <= 0 ||
          bounds.top >= (viewport as RenderBox).size.height) {
        return;
      }
    }
    // 章末导航不是漫画页；图片已全部离开视口时仍记录最后一页。
    final range = visible.isEmpty
        ? (widget.pageCount - 1, widget.pageCount - 1)
        : (visible.first, visible.last);
    if (range == _visible) return;
    _visible = range;
    widget.onVisibleRangeChanged?.call(range.$1, range.$2);
  }

  Widget _page(BuildContext context, int index) {
    Widget page = widget.pageBuilder(context, index);
    if (widget.withGap) {
      page = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: page,
      );
    }
    return SizeChangedLayoutNotifier(
      key: _pages.putIfAbsent(index, GlobalKey.new),
      child: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      // 更换原点时创建零偏移位置；绝不使用旧滚动距离换算新图片索引。
      key: ValueKey(_originIndex),
      controller: widget.controller,
      center: _center,
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverList.builder(
          itemCount: _originIndex,
          itemBuilder: (context, index) =>
              _page(context, _originIndex - index - 1),
        ),
        SliverList.builder(
          key: _center,
          itemCount: widget.pageCount - _originIndex + 1,
          itemBuilder: (context, index) {
            final page = _originIndex + index;
            return page == widget.pageCount
                ? SizeChangedLayoutNotifier(
                    key: _navigation,
                    child: widget.navigationBuilder(context),
                  )
                : _page(context, page);
          },
        ),
      ],
    );
    final zoomable = !widget.disableScale
        ? InteractiveViewer(minScale: 1, maxScale: 3, child: scrollView)
        : scrollView;
    Widget list = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleReport();
        return false;
      },
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleReport();
          return false;
        },
        child: zoomable,
      ),
    );
    if (widget.sidePadding > 0) {
      list = Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.sizeOf(context).width * widget.sidePadding / 100,
        ),
        child: list,
      );
    }
    return list;
  }
}
