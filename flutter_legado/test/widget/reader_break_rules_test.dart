import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/zh_layout.dart';
import 'package:flutter_legado/src/widgets/reader/text_break_rules.dart';
import 'package:flutter_legado/src/widgets/reader/line_text_span.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

void main() {
  test('中文初次断行和后续回退共享完整的避头尾集合', () {
    expect(
      identical(ZhLayout.postPanc, ChinesePunctuationRule.beginningPunctuation),
      isTrue,
    );
    expect(
      identical(ZhLayout.prePanc, ChinesePunctuationRule.endingPunctuation),
      isTrue,
    );
    for (final punctuation in ['”', '’', '）', '：', '；', '。']) {
      expect(TextBreakRules.forbidden('甲', punctuation), isTrue);
    }
  });
  for (final zh in [true, false]) {
    testWidgets('英文保留单词边界，超长单词完整分簇，中文连续标点不越界，中文断行$zh', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final engine = ParagraphLayoutEngine(
                context: context,
                config: ParagraphConfig(
                  fontSize: 10,
                  lineHeight: 1,
                  justify: false,
                  useZhLayout: zh,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
              );
              for (final source in [
                'alpha beta gamma delta',
                'alpha Supercalifragilisticexpialidocious omega',
                '甲乙“丙丁”；戊己庚辛。甲😀乙e\u0301丙丁',
              ]) {
                final lines = engine
                    .paginateChapter(source, 70, 1000)
                    .expand((p) => p.paragraphs)
                    .expand((p) => p.lines)
                    .toList();
                expect(lines.map((l) => l.selectableText).join(), source);
                for (var i = 0; i < lines.length; i++) {
                  expect(lines[i].width, lessThanOrEqualTo(70.001));
                  if (i > 0) {
                    expect(
                      TextBreakRules.forbidden(
                        lines[i - 1].words.last,
                        lines[i].words.first,
                      ),
                      isFalse,
                    );
                  }
                }
                if (source == 'alpha beta gamma delta') {
                  for (var i = 1; i < lines.length; i++) {
                    expect(
                      TextBreakRules.insideWord(
                        lines[i - 1].words.last,
                        lines[i].words.first,
                      ),
                      isFalse,
                    );
                  }
                }
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });
  }
  testWidgets('英文多空格仅扩展空格，最终跨度测绘和原文一致', (tester) async {
    const source = 'one two three four five six seven eight nine ten';
    late PageInfo page;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              page = ParagraphLayoutEngine(
                context: context,
                config: ParagraphConfig(
                  fontSize: 10,
                  lineHeight: 1,
                  letterSpacing: 0,
                  justify: true,
                  textEnvironment: TextLayoutEnvironment.of(context),
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
              ).paginateChapter(source, 180, 1000).first;
              return SizedBox(
                width: 180,
                child: ReaderTextContent(
                  pageInfo: page,
                  fontSize: 10,
                  lineHeight: 1,
                  paragraphSpacing: 8,
                  textColor: Colors.black,
                  selectText: false,
                ),
              );
            },
          ),
        ),
      ),
    );
    final expanded = page.paragraphs
        .expand((p) => p.lines)
        .where((l) => l.spaceExpansion > 0);
    expect(expanded, isNotEmpty);
    for (final line in expanded) {
      expect(line.letterSpacing, 0);
      final span = readerLineSpan(
        line.selectableText,
        const TextStyle(fontSize: 10, letterSpacing: 0),
        line.spaceExpansion,
      );
      expect(span.toPlainText(), line.selectableText);
      for (final child in span.children!.cast<TextSpan>()) {
        if (child.style != null) expect(child.text!.trim(), isEmpty);
      }
    }
    for (final element in find.byType(RichText).evaluate()) {
      expect(
        (element.renderObject as RenderParagraph).didExceedMaxLines,
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
