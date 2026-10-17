import 'package:flutter_legado/src/widgets/reader/reader_selectable_text.dart';

import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';

void main() {
  setUpNativeReaderLayout();
  for (final quote in ['"', "'", '“', '「']) {
    for (final indent in [1, 2, 3]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('引号悬挂只移动引号，正文保留 $indent 字缩进：$quote，缩放 $scale', (
          tester,
        ) async {
          Future<(LineInfo, double)> position(
            String source,
            bool hanging,
          ) async {
            late PageInfo page;
            await pumpNativeReaderLayout(
              tester,
              MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: LayoutTestBuilder(
                      builder: (context) async {
                        page = (await ParagraphLayoutEngine(
                          transport: nativeReaderLayout,
                          context: context,
                          config: ParagraphConfig(
                            fontSize: 16,
                            lineHeight: 1.6,
                            indent: indent * 16,
                            indentCount: indent,
                            justify: false,
                            hangingPunctuation: hanging,
                            textEnvironment: TextLayoutEnvironment.of(context),
                            backgroundColor: Colors.white,
                            textColor: Colors.black,
                          ),
                        ).paginateChapter(source, 300, 500)).first;
                        return SizedBox(
                          width: 300,
                          child: ReaderTextContent(
                            pageInfo: page,
                            fontSize: 16,
                            lineHeight: 1.6,
                            paragraphSpacing: 0,
                            textColor: Colors.black,
                            selectText: false,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await settleNativeReaderLayout(tester);
            final line = page.paragraphs.first.lines.first;
            final rich = find.byWidgetPredicate(
              (w) =>
                  w is ReaderSelectableText &&
                  w.text.toPlainText() == line.selectableText,
            );
            final render = tester.renderObject<RenderParagraph>(rich);
            final start = source.startsWith(quote) ? quote.length : 0;
            final box = render
                .getBoxesForSelection(
                  TextSelection(baseOffset: start, extentOffset: start + 1),
                )
                .first;
            final origin = tester.getTopLeft(find.byType(ReaderTextContent));
            final x = render.localToGlobal(box.toRect().topLeft).dx - origin.dx;
            expect(render.didExceedMaxLines, isFalse);
            expect(tester.takeException(), isNull);
            return (line, x);
          }

          final plain = await position('正文保留首行缩进。', false);
          final quoted = await position('$quote正文保留首行缩进。', true);
          expect(quoted.$2, closeTo(plain.$2, 0.01));
          expect(quoted.$2, greaterThan(0));
        });
      }
    }
  }
}
