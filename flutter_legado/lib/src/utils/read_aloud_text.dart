/// 朗读单元保留章节原文的 UTF-16 起点，不使用裁剪后文本累加偏移。
typedef ReadAloudParagraph = ({int start, String text});

List<ReadAloudParagraph> splitReadAloudParagraphs(String content) {
  final result = <ReadAloudParagraph>[];
  var start = 0;
  void emit(int end) {
    final segment = content.substring(start, end);
    final text = segment.trim();
    if (text.isNotEmpty) {
      result.add((start: start + segment.indexOf(text), text: text));
    }
  }

  for (final separator in RegExp(
    r'\r\n|[\r\n\u2028\u2029]',
  ).allMatches(content)) {
    emit(separator.start);
    start = separator.end;
  }
  emit(content.length);
  return result;
}

/// 空白间隙从后一个单元开始；有效正文位置保留段内起点。
({int paragraph, int offset}) readAloudStartAt(
  List<ReadAloudParagraph> paragraphs,
  int chapterOffset,
) {
  if (paragraphs.isEmpty) return (paragraph: 0, offset: 0);
  for (var index = 0; index < paragraphs.length; index++) {
    final paragraph = paragraphs[index];
    final end = paragraph.start + paragraph.text.length;
    if (chapterOffset < end || index == paragraphs.length - 1) {
      var offset = (chapterOffset - paragraph.start).clamp(
        0,
        paragraph.text.length - 1,
      );
      // 来源是 UTF-16；防止外部旧坐标落在代理对中间产生非法文本。
      if (offset > 0 &&
          paragraph.text.codeUnitAt(offset) >= 0xdc00 &&
          paragraph.text.codeUnitAt(offset) <= 0xdfff &&
          paragraph.text.codeUnitAt(offset - 1) >= 0xd800 &&
          paragraph.text.codeUnitAt(offset - 1) <= 0xdbff) {
        offset--;
      }
      return (paragraph: index, offset: offset);
    }
  }
  return (paragraph: 0, offset: 0);
}
