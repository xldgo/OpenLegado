import 'package:flutter/widgets.dart';

import '../../application/comic_page_layout.dart';

/// 双图等宽共享外层缩放，左右排列不受应用语言方向影响。— Codex + UI
class ComicPageSpreadView extends StatelessWidget {
  const ComicPageSpreadView({
    super.key,
    required this.spread,
    required this.reversed,
    required this.pageBuilder,
  });
  final ComicPageSpread spread;
  final bool reversed;
  final Widget Function(ComicPageSlot slot) pageBuilder;

  @override
  Widget build(BuildContext context) {
    final second = spread.second;
    if (second == null) return pageBuilder(spread.first);
    final slots = reversed ? [second, spread.first] : [spread.first, second];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.ltr,
      children: [for (final slot in slots) Expanded(child: pageBuilder(slot))],
    );
  }
}
