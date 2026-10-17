import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

void main() {
  setUpNativeReaderLayout();
  test('中文断行返回字形簇索引，不把 UTF-16 长度混入索引', () async {
    const text = '甲😀乙e\u0301丙👨‍👩‍👧‍👦丁';
    final mapping = TextClusterMap(text);
    expect(mapping.sourceOffsets[2], 3);
    expect(mapping.clusterIndex(3), 2);
    expect(() => mapping.clusterIndex(2), throwsArgumentError);
  });

  testWidgets('显式零字距、方向、Locale 与文字高度行为测绘一致', (tester) async {
    late PageInfo page;
    late TextLayoutEnvironment environment;
    const source = '甲😀乙e\u0301正文测试';
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: const TextStyle(fontSize: 16, letterSpacing: 7),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
            ),
            child: LayoutTestBuilder(
              builder: (context) async {
                environment = TextLayoutEnvironment.of(context);
                page = (await ParagraphLayoutEngine(
                  transport: nativeReaderLayout,
                  context: context,
                  config: ParagraphConfig(
                    fontSize: 16,
                    letterSpacing: 0,
                    justify: false,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    textEnvironment: environment,
                  ),
                ).paginateChapter(source, 140, 400)).first;
                return SizedBox(
                  width: 140,
                  child: ReaderTextContent(
                    pageInfo: page,
                    fontSize: 16,
                    lineHeight: 1.6,
                    paragraphSpacing: 8,
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
    for (final line in page.paragraphs.expand((p) => p.lines)) {
      final painter = TextPainter(
        text: TextSpan(
          text: line.displayText,
          style: environment.baseStyle.merge(
            const TextStyle(fontSize: 16, height: 1.6, letterSpacing: 0),
          ),
        ),
        textDirection: environment.direction,
        locale: environment.locale,
        textScaler: environment.textScaler,
        textHeightBehavior: environment.heightBehavior,
        maxLines: 1,
      )..layout();
      expect(line.width, closeTo(painter.width, .01));
      expect(line.height, closeTo(painter.height, .01));
      painter.dispose();
    }
    expect(tester.takeException(), isNull);
  });
}
