import 'package:characters/characters.dart';

import '../domain/models/read_aloud_content.dart';

/// 朗读单元保留章节原文的 UTF-16 起点，不使用裁剪后文本累加偏移。
List<ReadAloudUnit> splitReadAloudParagraphs(String content) =>
    splitReadAloudContent(content);

/// 空白间隙从后一个单元开始；有效正文位置保留段内起点。
({int paragraph, int offset}) readAloudStartAt(
  List<ReadAloudUnit> paragraphs,
  int chapterOffset,
) {
  if (paragraphs.isEmpty) return (paragraph: 0, offset: 0);
  for (var index = 0; index < paragraphs.length; index++) {
    final paragraph = paragraphs[index];
    final end = paragraph.start + paragraph.text.length;
    if (chapterOffset < end || index == paragraphs.length - 1) {
      final requested = (chapterOffset - paragraph.start).clamp(
        0,
        paragraph.text.length - 1,
      );
      // 原文坐标使用 UTF-16；朗读必须从完整字形簇开始，包含组合音标和 ZWJ 表情。
      var offset = 0;
      for (final cluster in paragraph.text.characters) {
        final next = offset + cluster.length;
        if (next > requested) break;
        offset = next;
      }
      return (paragraph: index, offset: offset);
    }
  }
  return (paragraph: 0, offset: 0);
}
