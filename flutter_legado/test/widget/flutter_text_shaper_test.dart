import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/chapter_layout.dart';
import 'package:flutter_legado/src/widgets/reader/flutter_text_shaper.dart';
import 'package:flutter_legado/src/widgets/reader/layout_diagnostics.dart';
import 'package:flutter_legado/src/widgets/reader/paragraph_config.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('测量输入保留字形簇、UTF-16偏移和显式零字距，方向$direction', (tester) async {
      late FlutterTextShaper shaper;
      late TextLayoutEnvironment environment;
      late Map<String, Object?> measured;
      const text = '甲😀乙e\u0301正文';
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('zh'),
          delegates: const [GlobalWidgetsLocalizations.delegate],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Directionality(
              textDirection: direction,
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 16, letterSpacing: 7),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                ),
                child: Builder(
                  builder: (context) {
                    environment = TextLayoutEnvironment.of(context);
                    shaper = FlutterTextShaper(
                      const ParagraphConfig(
                        fontSize: 16,
                        letterSpacing: 0,
                        backgroundColor: Color(0xFFFFFFFF),
                        textColor: Color(0xFF000000),
                      ),
                      environment,
                      null,
                    );
                    measured = shaper.measure(
                      const SourceParagraph(text, 11, 11 + text.length),
                      0,
                      null,
                      500,
                    );
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(environment.direction, direction);
      expect(environment.locale, const Locale('zh'));
      expect(environment.textScaler.scale(16), 24);
      expect(environment.heightBehavior!.applyHeightToFirstAscent, isFalse);
      expect(shaper.style.letterSpacing, 0);
      expect(shaper.spacing, 0);
      final paragraph = measured['value']! as Map<String, Object?>;
      expect(paragraph['chapterPosition'], 11);
      expect(paragraph['text'], text);
      expect(paragraph['clusters'], ['甲', '😀', '乙', 'e\u0301', '正', '文']);
      final map = TextClusterMap(text);
      expect(map.sourceOffsets, [0, 1, 3, 4, 6, 7, 8]);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: environment.baseStyle.merge(
            const TextStyle(fontSize: 16, height: 1.6, letterSpacing: 0),
          ),
        ),
        textDirection: direction,
        locale: environment.locale,
        textScaler: environment.textScaler,
        textHeightBehavior: environment.heightBehavior,
      )..layout(maxWidth: 500);
      try {
        final widths = paragraph['clusterWidthsPx']! as List<double>;
        for (var i = 0; i < widths.length; i++) {
          final boxes = painter.getBoxesForSelection(
            TextSelection(
              baseOffset: map.sourceOffsets[i],
              extentOffset: map.sourceOffsets[i + 1],
            ),
          );
          expect(
            widths[i],
            closeTo(
              boxes.fold(0.0, (sum, box) => sum + box.right - box.left),
              .01,
            ),
          );
        }
        expect(shaper.height, closeTo(painter.height, .01));
        expect(
          shaper.baseline,
          closeTo(
            painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
            .01,
          ),
        );
      } finally {
        painter.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('诊断采样不改变测量载荷，统计覆盖全部文字测量', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            const config = ParagraphConfig(
              fontSize: 18,
              lineHeight: 1.6,
              indent: 36,
              backgroundColor: Color(0xFFFFFFFF),
              textColor: Color(0xFF000000),
            );
            final environment = TextLayoutEnvironment.of(context);
            final diagnostics = ReaderLayoutDiagnostics();
            final baseline = FlutterTextShaper(config, environment, null);
            final sampled = FlutterTextShaper(config, environment, diagnostics);
            const paragraphs = [
              '“Hello 😀！”他问道。',
              '中文、组合字符 e\u0301 和长英文 newspaper。',
            ];
            for (final text in paragraphs) {
              final paragraph = SourceParagraph(text, 0, text.length);
              expect(
                sampled.measure(paragraph, 0, null, 160),
                baseline.measure(paragraph, 0, null, 160),
              );
            }
            expect(sampled.metrics, baseline.metrics);
            expect(diagnostics.measurementCalls, sampled.measurementCount);
            expect(diagnostics.measurementCalls, greaterThan(0));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
