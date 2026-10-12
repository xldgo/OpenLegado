import 'chapter_layout.dart';

/// 每个非空逻辑行为一段；原始换行和空白继续保存在章节原文中。
List<SourceParagraph> splitChapterParagraphs(String content) {
  final result = <SourceParagraph>[];
  var start = 0;
  void append(int end) {
    final raw = content.substring(start, end);
    final text = raw.trim();
    if (text.isEmpty) return;
    final leading = raw.length - raw.trimLeft().length;
    final sourceStart = start + leading;
    result.add(SourceParagraph(text, sourceStart, sourceStart + text.length));
  }

  for (final match in RegExp(r'\r\n|\r|\n').allMatches(content)) {
    append(match.start);
    start = match.end;
  }
  append(content.length);
  return result;
}
