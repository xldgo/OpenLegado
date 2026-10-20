import 'package:material_ui/material_ui.dart';

/// 条漫布局：滚动、缩放与侧边留白，位置与事件由页面管理。— Codex + UI
class ComicWebtoonView extends StatelessWidget {
  const ComicWebtoonView({
    super.key,
    required this.controller,
    required this.pageCount,
    required this.pageBuilder,
    required this.navigationBuilder,
    required this.disableScale,
    required this.withGap,
    required this.sidePadding,
    required this.onMetricsChanged,
  });
  final ScrollController controller;
  final int pageCount;
  final Widget Function(BuildContext context, int index) pageBuilder;
  final WidgetBuilder navigationBuilder;
  final bool disableScale, withGap;
  final int sidePadding;
  final bool Function(ScrollMetricsNotification) onMetricsChanged;
  @override
  Widget build(BuildContext context) {
    final listView = ListView.builder(
      controller: controller,
      itemCount: pageCount + 1, // +1 用于底部章节导航
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        // 最后一项：章节导航
        if (index == pageCount) {
          return navigationBuilder(context);
        }
        var item = pageBuilder(context, index);
        // [P4-3 E1] 条漫（间隔）：页间 8px 间距
        //（参考版 Arrangement.spacedBy(8.dp)，实现为 4px 上 + 4px 下包裹）
        if (withGap) {
          item = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: item,
          );
        }
        return item;
      },
    );
    // [P4-3 M4 批2] 禁用漫画缩放（原版默认 true）：InteractiveViewer
    // 不渲染，仅启用时包裹缩放层
    final zoomable = !disableScale
        ? InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(0),
            child: listView,
          )
        : listView;
    final list = NotificationListener<ScrollMetricsNotification>(
      onNotification: onMetricsChanged,
      child: zoomable,
    );
    // [P4-3 M3 修4] 条漫侧边留白：每侧 padding = 视口宽 × p/100（p =
    // sidePadding 0..45）。对齐参考版 MangaReaderScreen L500/L1706：
    // fraction = 1 - p×2/100，itemWidthPx = 视口宽 × fraction ⇔ 每侧
    // 让出 p% 视口宽；仅条漫（4/5）路径生效，单页式路径参考版
    // fraction 恒 1（不加 padding）
    if (sidePadding <= 0) {
      return list;
    }
    final h = MediaQuery.sizeOf(context).width * (sidePadding / 100.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h),
      child: list,
    );
  }
}
