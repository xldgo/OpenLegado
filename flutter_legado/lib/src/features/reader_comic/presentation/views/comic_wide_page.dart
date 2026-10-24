import 'package:flutter/widgets.dart';

import '../../application/comic_page_layout.dart';

/// 复用原图，只调整显示约束；裁切在缩放内部，不创建半张图片或新缓存。— Codex + UI
class ComicWidePage extends StatelessWidget {
  const ComicWidePage({
    super.key,
    required this.child,
    this.slice = ComicPageSlice.full,
    this.rotate = false,
  });
  final Widget child;
  final ComicPageSlice slice;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    if (rotate) return RotatedBox(quarterTurns: 1, child: child);
    if (slice == ComicPageSlice.full) return child;
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: OverflowBox(
          alignment: slice == ComicPageSlice.left
              ? Alignment.centerLeft
              : Alignment.centerRight,
          minWidth: constraints.maxWidth * 2,
          maxWidth: constraints.maxWidth * 2,
          minHeight: constraints.maxHeight,
          maxHeight: constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
