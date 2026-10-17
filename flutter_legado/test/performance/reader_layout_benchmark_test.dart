import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/native_reader_layout.dart';

import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';

/// 固定文本用于同环境诊断，不把调试模式耗时作为发布性能结论。
void main() {
  setUpNativeReaderLayout();
  testWidgets('固定文本记录首个完整页面、整章时间与测量次数', (tester) async {
    final source = List.generate(
      120,
      (i) => '这是排版性能固定样本的第${i + 1}段正文。' * 3,
    ).join('\n');
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: LayoutTestBuilder(
          builder: (context) async {
            for (var round = 0; round < 4; round++) {
              final engine = ParagraphLayoutEngine(
                transport: nativeReaderLayout,
                context: context,
                config: const ParagraphConfig(
                  fontSize: 18,
                  lineHeight: 1.6,
                  paragraphSpacing: 8,
                  indent: 36,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
              );
              final watch = Stopwatch()..start();
              final session = engine.startChapter(
                source,
                320,
                580,
                firstPageHeight: 530,
              );
              int? firstPage;
              while (!session.complete) {
                await session.advance(maxParagraphs: 8);
                if (session.pages.isNotEmpty) {
                  firstPage ??= watch.elapsedMicroseconds;
                }
              }
              watch.stop();
              final shown = session.pages
                  .expand((p) => p.paragraphs)
                  .expand((p) => p.lines)
                  .map((l) => l.selectableText)
                  .join();
              expect(shown, source.replaceAll('\n', ''));
              if (round > 0) {
                // 输出结构化原始诊断值，便于保留真实测量口径。
                debugPrint(
                  jsonEncode({
                    'kind': 'optimized-debug',
                    'round': round,
                    'utf16': source.length,
                    'firstPageUs': firstPage,
                    'chapterUs': watch.elapsedMicroseconds,
                    'measurements': engine.measurementCount,
                    'pages': session.pages.length,
                  }),
                );
              }
            }
            return const SizedBox();
          },
        ),
      ),
    );
    await settleNativeReaderLayout(tester);
  });
}
