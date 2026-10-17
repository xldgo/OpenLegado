import 'package:material_ui/material_ui.dart';

import '../../../../models/book_chapter.dart';

/// 卷标题不可点击，不参与普通章节的缓存状态。— Codex + UI
class TocVolumeTile extends StatelessWidget {
  const TocVolumeTile({super.key, required this.chapter});
  final BookChapter chapter;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        chapter.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
      ),
    );
  }
}
