import 'package:flutter/widgets.dart';

import '../../../platform/display/display_corners.dart';

/// 圆角数据与静态页面区域不跟随翻页变换，预览页复用同一份窗口几何。— Codex + UI
class ReaderFooterGeometry extends InheritedWidget {
  const ReaderFooterGeometry({
    super.key,
    required this.corners,
    this.bounds,
    required super.child,
  });
  final DisplayCorners corners;
  final Rect? bounds;

  static ReaderFooterGeometry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderFooterGeometry>();

  EdgeInsets extraInsets({
    required EdgeInsets padding,
    required double lineHeight,
    int column = 0,
    int columns = 1,
    bool header = false,
  }) {
    final region = bounds ?? Offset.zero & corners.size;
    final width = region.width / columns;
    final left = region.left + column * width;
    final textBand = header
        // 平台未提供上角轮廓，复用已有圆角的镜像作保守横向内收。
        ? Rect.fromLTRB(
            left + padding.left,
            corners.size.height - region.top - padding.top - lineHeight,
            left + width - padding.right,
            corners.size.height - region.top - padding.top,
          )
        : Rect.fromLTRB(
            left + padding.left,
            region.bottom - padding.bottom - lineHeight,
            left + width - padding.right,
            region.bottom - padding.bottom,
          );
    return corners.extraInsets(textBand);
  }

  @override
  bool updateShouldNotify(ReaderFooterGeometry oldWidget) =>
      corners != oldWidget.corners || bounds != oldWidget.bounds;
}
