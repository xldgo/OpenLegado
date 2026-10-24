import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/domain/models/highlight_rule.dart';
import 'package:flutter_legado/src/features/reader/highlight/reader_highlight_style.dart';
import 'package:flutter_legado/src/features/reader/layout/chapter_layout.dart';
import 'package:flutter_legado/src/features/reader/layout/flutter_text_shaper.dart';
import 'package:flutter_legado/src/features/reader/layout/paragraph_config.dart';
import 'package:flutter_legado/src/features/reader/layout/reader_layout_element.dart';
import 'package:flutter_legado/src/features/reader/layout/text_layout_environment.dart';
import 'package:flutter_legado/src/features/reader/selection/reader_selectable_text.dart';

void main() {
  testWidgets('混合字号按同一字体测量绘制，缩放只应用一次且选区仍为原文', (tester) async {
    const source = '甲😀BC乙';
    const config = ParagraphConfig(
      fontSize: 16,
      backgroundColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF000000),
    );
    const environment = TextLayoutEnvironment(
      baseStyle: TextStyle(fontFamily: 'Ahem'),
      textScaler: TextScaler.linear(1.5),
      direction: TextDirection.ltr,
    );
    final shaper = FlutterTextShaper(config, environment, null);
    final block = shaper.measure(
      SourceParagraph(source, 0, source.length),
      0,
      null,
      500,
      highlights: [
        const HighlightMatch(
          start: 1,
          end: 5,
          style: {
            'fontSizeOffset': 8,
            'textColor': 0xFFFF0000,
            'letterSpacingBefore': 4,
            'letterSpacingAfter': 6,
          },
        ),
      ],
    );
    final items = (block['items'] as List).cast<Map<String, Object?>>();
    expect(items.map((item) => item['value']).join(), source);
    final first = items.first, styled = items[1];
    expect(
      (styled['lineHeightPx'] as double),
      greaterThan(first['lineHeightPx'] as double),
    );
    final style = styled['style'] as Map<String, dynamic>;
    final painter = TextPainter(
      text: TextSpan(
        text: styled['value'] as String,
        style: readerGlyphTextStyle(shaper.style, style),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final boxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: (styled['value'] as String).length,
      ),
    );
    expect(
      boxes.fold(0.0, (sum, box) => sum + box.right - box.left),
      closeTo(styled['widthPx'] as double, .01),
    );
    painter.dispose();
    final glyphs = <ReaderGlyph>[];
    var x = 0.0;
    final baseline = items
        .map((i) => i['baselineOffsetPx'] as double)
        .reduce((a, b) => a > b ? a : b);
    for (final item in items) {
      final width = item['widthPx'] as double;
      final height = item['lineHeightPx'] as double;
      final top = baseline - (item['baselineOffsetPx'] as double);
      final element = ReaderLayoutElement(
        ReaderElementKind.text,
        Rect.fromLTWH(x, top, width, height),
        {
          'value': item['value'],
          'style': item['style'],
          'chapterPosition': item['chapterPosition'],
          'baselinePx': baseline,
        },
      );
      glyphs.add(ReaderGlyph(element, 0, Offset.zero));
      x += width;
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ReaderSelectableText(
            text: const TextSpan(text: source),
            glyphs: glyphs,
            glyphStyle: shaper.style,
            textScaler: environment.textScaler,
          ),
        ),
      ),
    );
    final render = tester.renderObject<RenderParagraph>(
      find.byType(ReaderSelectableText),
    );
    expect(render.text.toPlainText(), source);
    for (final glyph in glyphs) {
      expect(
        render
            .getPositionForOffset(
              Offset(glyph.bounds.center.dx, glyph.bounds.center.dy),
            )
            .offset,
        inInclusiveRange(glyph.start, glyph.end),
      );
    }
    expect(tester.takeException(), isNull);
  });

  test('未指定高亮字色时绘制跟随正文颜色，不依赖旧布局中的配色', () {
    final result = readerGlyphTextStyle(
      const TextStyle(color: Color(0xFFEEEEEE)),
      {'inheritColor': true, 'colorArgb': 0xFF000000, 'fontSizePx': 24},
    );
    expect(result.color, const Color(0xFFEEEEEE));
  });
}
