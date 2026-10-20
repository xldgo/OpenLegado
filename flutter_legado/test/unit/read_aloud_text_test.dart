import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/utils/read_aloud_text.dart';

void main() {
  test('混合换行和缩进保留原文坐标，重复正文也能定位', () {
    const content = '  首段。\r\n\n  重复段\r重复段\u2028末段\u2029';
    final paragraphs = splitReadAloudParagraphs(content);
    expect(paragraphs.map((p) => p.text), ['首段。', '重复段', '重复段', '末段']);
    for (final paragraph in paragraphs) {
      expect(
        content.substring(
          paragraph.start,
          paragraph.start + paragraph.text.length,
        ),
        paragraph.text,
      );
    }
    final duplicate = content.lastIndexOf('重复段');
    expect(readAloudStartAt(paragraphs, duplicate + 1), (
      paragraph: 2,
      offset: 1,
    ));
  });

  test('选区在段中时不退回段首，空白间隙从后段开始', () {
    const content = '第一段。\r\n\n  第二段内容。';
    final paragraphs = splitReadAloudParagraphs(content);
    expect(readAloudStartAt(paragraphs, content.indexOf('内容')), (
      paragraph: 1,
      offset: 3,
    ));
    expect(readAloudStartAt(paragraphs, content.indexOf('\r')), (
      paragraph: 1,
      offset: 0,
    ));
    expect(readAloudStartAt(paragraphs, -1), (paragraph: 0, offset: 0));
    expect(splitReadAloudParagraphs(' \r\n\u2028'), isEmpty);
  });

  test('UTF-16 代理对不能被起点截断', () {
    const content = '前文😀后文';
    final paragraphs = splitReadAloudParagraphs(content);
    final start = readAloudStartAt(paragraphs, 3);
    expect(start, (paragraph: 0, offset: 2));
    expect(paragraphs[start.paragraph].text.substring(start.offset), '😀后文');
  });

  for (final cluster in ['e\u0301', '👨‍👩‍👧‍👦', '🇨🇳', '👍🏽', '𠮷']) {
    test('原文定位不拆开字形簇 $cluster，章末仍从完整字符开始', () {
      final text = '  前$cluster后\r\n\n 末$cluster';
      final units = splitReadAloudParagraphs(text);
      final start = text.indexOf(cluster);
      for (var i = 0; i < cluster.length; i++) {
        expect(readAloudStartAt(units, start + i), (paragraph: 0, offset: 1));
      }
      expect(readAloudStartAt(units, text.length), (paragraph: 1, offset: 1));
      expect(readAloudStartAt(units, text.length + 10), (
        paragraph: 1,
        offset: 1,
      ));
      expect(readAloudStartAt(units, -10), (paragraph: 0, offset: 0));
    });
  }
}
