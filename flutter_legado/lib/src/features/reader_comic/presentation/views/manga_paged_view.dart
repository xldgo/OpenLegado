import 'package:flutter/widgets.dart';

import 'comic_page_zoom.dart';

/// [P4-3 E1] 单页式漫画分页器（对齐参考版 HorizontalMangaPager /
/// VerticalMangaPager 语义）
///
/// 取证：ui/book/manga/MangaReaderScreen.kt L263-268 模式分发 ——
/// L2R/R2L → 横向分页器（L941 R2L reverseLayout），T2B → 纵向分页器；
/// 末尾页之后追加章节导航页（对齐条漫 ListView 尾部导航项，防章末卡死）。
///
/// 显示索引 ↔ 逻辑页映射：
/// - 正向（L2R/T2B）：displayIndex = 逻辑页 p；
/// - 反转（R2L）：displayIndex d → 逻辑页 p = pageCount - d
///   （首页 p=0 显示在最右端，右滑翻到下一页）。
/// 章节导航页收敛到「末页」语义（页级进度按末页记录）。
class MangaPagedView extends StatefulWidget {
  const MangaPagedView({
    super.key,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.navBuilder,
    this.axis = Axis.horizontal,
    this.reversed = false,
    this.onDisplayIndexChanged,
    this.disableScale = true,
    this.onZoomChanged,
  });

  /// 分页控制器（initialPage 由调用方按逻辑页换算后创建）
  final PageController controller;

  /// 按阅读顺序排列的显示槽数（含半页，不含章节导航页）；原图映射由调用方持有。
  final int pageCount;

  /// 页面构建器：按显示槽的阅读顺序索引构建。
  final Widget Function(BuildContext context, int logicalPage) pageBuilder;

  /// 章节导航页构建器（显示在末页之后 / 首页之前）
  final Widget Function(BuildContext context) navBuilder;

  /// 滚动轴（L2R/R2L 横向，T2B 纵向）
  final Axis axis;

  /// 是否右起（R2L）：项序反转，首页在最右
  final bool reversed;

  /// 页切换回调（参数为显示索引，调用方负责换算逻辑页）
  final ValueChanged<int>? onDisplayIndexChanged;

  final bool disableScale;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<MangaPagedView> createState() => _MangaPagedViewState();

  /// 逻辑页 → 显示索引（R2L 反转；越界收敛到 [0, pageCount-1]）
  static int displayIndexOf({
    required int logicalPage,
    required int pageCount,
    required bool reversed,
  }) {
    if (pageCount <= 0) return 0;
    final p = logicalPage.clamp(0, pageCount - 1);
    return reversed ? pageCount - p : p;
  }

  /// 显示索引 → 逻辑页（R2L 反转；章节导航页收敛到末页）
  static int logicalPageOf({
    required int displayIndex,
    required int pageCount,
    required bool reversed,
  }) {
    if (pageCount <= 0) return 0;
    final p = reversed ? (pageCount - displayIndex) : displayIndex;
    return p.clamp(0, pageCount - 1);
  }
}

class _MangaPagedViewState extends State<MangaPagedView> {
  late int _active = widget.controller.initialPage;
  bool _zoomed = false;

  @override
  void didUpdateWidget(covariant MangaPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _active = widget.controller.initialPage;
    }
    if ((widget.disableScale || widget.controller != oldWidget.controller) &&
        _zoomed) {
      _zoomed = false;
      widget.onZoomChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pageCount + 1;
    final navDisplayIndex = widget.reversed ? 0 : total - 1;
    return PageView.builder(
      controller: widget.controller,
      scrollDirection: widget.axis,
      physics: _zoomed
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemCount: total,
      onPageChanged: (index) {
        setState(() {
          _active = index;
          _zoomed = false;
        });
        widget.onZoomChanged?.call(false);
        widget.onDisplayIndexChanged?.call(index);
      },
      itemBuilder: (context, displayIndex) {
        if (displayIndex == navDisplayIndex) return widget.navBuilder(context);
        final logicalPage = MangaPagedView.logicalPageOf(
          displayIndex: displayIndex,
          pageCount: widget.pageCount,
          reversed: widget.reversed,
        );
        final page = widget.pageBuilder(context, logicalPage);
        return ComicPageZoom(
          key: ValueKey((widget.axis, widget.reversed, logicalPage)),
          enabled: !widget.disableScale,
          active: displayIndex == _active,
          reversed: widget.reversed,
          horizontal: widget.axis == Axis.horizontal,
          onZoomChanged: (zoomed) {
            if (displayIndex != _active || _zoomed == zoomed) return;
            setState(() => _zoomed = zoomed);
            widget.onZoomChanged?.call(zoomed);
          },
          child: page,
        );
      },
    );
  }
}
