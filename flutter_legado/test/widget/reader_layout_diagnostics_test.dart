import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/layout_diagnostics.dart';

void main() {
  setUpNativeReaderLayout();
  testWidgets('注入测量采样不改变断点、分页及原文位置', (tester) async {
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: LayoutTestBuilder(
          builder: (context) async {
            const config = ParagraphConfig(
              fontSize: 18,
              lineHeight: 1.6,
              paragraphSpacing: 8,
              indent: 36,
              useZhLayout: true,
              backgroundColor: Colors.white,
              textColor: Colors.black,
            );
            const source = '“Hello 😀！”他问道。\n中文、组合字符 e\u0301 和长英文 newspaper。';
            final diagnostics = ReaderLayoutDiagnostics();
            final baseline = ParagraphLayoutEngine(
              transport: nativeReaderLayout,
              config: config,
              context: context,
            );
            final measured = ParagraphLayoutEngine(
              transport: nativeReaderLayout,
              config: config,
              context: context,
              diagnostics: diagnostics,
            );
            List<Object> geometry(List<PageInfo> pages) => [
              for (final page in pages)
                [
                  page.totalHeight,
                  for (final paragraph in page.paragraphs)
                    [
                      for (final line in paragraph.lines)
                        [
                          line.displayText,
                          line.startIndex,
                          line.endIndex,
                          line.width,
                          line.height,
                        ],
                    ],
                ],
            ];
            expect(
              geometry((await measured.paginateChapter(source, 160, 120))),
              geometry((await baseline.paginateChapter(source, 160, 120))),
            );
            expect(diagnostics.measurementCalls, measured.measurementCount);
            expect(diagnostics.measurementCalls, greaterThan(0));
            return const SizedBox();
          },
        ),
      ),
    );
    await settleNativeReaderLayout(tester);
  });
}
