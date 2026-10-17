import 'package:flutter_legado/src/widgets/reader/reader_selectable_text.dart';

import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

/// Text.rich 会在文本跨度外包主题跨度，探针沿继承链读取首字的生效样式。
TextStyle _firstTextStyle(
  TextSpan span, [
  TextStyle inherited = const TextStyle(),
]) {
  final style = inherited.merge(span.style);
  if (span.text?.isNotEmpty == true) return style;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) return _firstTextStyle(child, style);
  }
  return style;
}

Future<List<PageInfo>> _layout(
  WidgetTester tester,
  String source, {
  double width = 240,
  double pageHeight = 200,
  double scale = 1,
  int indent = 2,
  bool render = false,
  bool hangingPunctuation = false,
}) async {
  late List<PageInfo> pages;
  await pumpNativeReaderLayout(
    tester,
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: LayoutTestBuilder(
            builder: (context) async {
              pages = (await ParagraphLayoutEngine(
                transport: nativeReaderLayout,
                context: context,
                config: ParagraphConfig(
                  fontSize: 16,
                  lineHeight: 1.6,
                  paragraphSpacing: 8,
                  indent: indent * 16,
                  indentCount: indent,
                  hangingPunctuation: hangingPunctuation,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                  baseStyle: DefaultTextStyle.of(context).style,
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ).paginateChapter(source, width, pageHeight));
              return !render
                  ? const SizedBox()
                  : SizedBox(
                      width: width,
                      child: ReaderTextContent(
                        pageInfo: pages.first,
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
  await settleNativeReaderLayout(tester);
  return pages;
}

void main() {
  setUpNativeReaderLayout();
  test('分段保留混合换行、空白与重复段落的真实原文偏移', () async {
    const source = '\r\n　首段  \r\n\n重复段。\r重复段。\n\n';
    final paragraphs = splitChapterParagraphs(source);
    expect(paragraphs.map((p) => p.text), ['首段', '重复段。', '重复段。']);
    expect(paragraphs[0].startIndex, source.indexOf('首段'));
    expect(paragraphs[2].startIndex, source.lastIndexOf('重复段。'));
    for (final paragraph in paragraphs) {
      expect(
        source.substring(paragraph.startIndex, paragraph.endIndex),
        paragraph.text,
      );
    }
  });

  testWidgets('缩进仅用于显示，第二段偏移从原文计算', (tester) async {
    const source = '第一段。\n第二段内容。';
    final pages = await _layout(tester, source);
    final paragraphs = pages.expand((p) => p.paragraphs).toList();
    final first = paragraphs.first.lines.first;
    expect(first.displayText, '第一段。');
    expect(first.indentWidth, greaterThan(0));
    expect(first.sourceOffset(0), 0);
    expect(first.sourceOffset(2), 2);
    expect(first.sourceOffset(3), 3);
    expect(paragraphs[1].startIndex, source.indexOf('第二段'));
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final hanging in [false, true]) {
      testWidgets('缩进留白保持首字位置：缩放 $scale，标点悬挂 $hanging', (tester) async {
        final pages = await _layout(
          tester,
          '“这是一段足够长的正文，用于验证字距和缩放变化后缩进的实际位置。',
          width: 240,
          pageHeight: 500,
          scale: scale,
          hangingPunctuation: hanging,
          render: true,
        );
        final line = pages.first.paragraphs.first.lines.first;
        final richText = find
            .byWidgetPredicate(
              (w) =>
                  w is ReaderSelectableText &&
                  w.text.toPlainText() == line.selectableText,
            )
            .first;
        final paragraph = tester.renderObject<RenderParagraph>(richText);
        final original = TextPainter(
          text: TextSpan(
            text: line.displayText,
            style: _firstTextStyle(paragraph.text as TextSpan),
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
          maxLines: 1,
        )..layout();
        final originalBox = original
            .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: 1))
            .first;
        final renderedBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .first;
        final contentOrigin = tester.getTopLeft(find.byType(ReaderTextContent));
        expect(
          paragraph.localToGlobal(renderedBox.toRect().topLeft).dx -
              contentOrigin.dx,
          closeTo(
            originalBox.left + line.indentWidth - line.hangingWidth,
            0.01,
          ),
        );
        original.dispose();
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('混合单换行和空行不再将后续段落裁成不可见文本', (tester) async {
    final pages = await _layout(tester, '第一段。\n第二段。\n\n第三段。', render: true);
    expect(pages.expand((p) => p.paragraphs).length, 3);
    for (final element in find.byType(RichText).evaluate()) {
      expect(
        (element.renderObject as RenderParagraph).didExceedMaxLines,
        isFalse,
      );
    }
  });

  testWidgets('放大字体后采用实测行高并重新按容量分页', (tester) async {
    final pages = await _layout(
      tester,
      List.filled(10, '正文内容。').join('\n'),
      scale: 2,
      render: true,
    );
    final firstLine = pages.first.paragraphs.first.lines.first;
    expect(firstLine.height, greaterThan(16 * 1.6));
    for (final element in find.byType(RichText).evaluate()) {
      final paragraph = element.renderObject as RenderParagraph;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      );
      for (final box in boxes) {
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(box.bottom - box.top),
        );
      }
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(pages.every((page) => page.totalHeight <= 200), isTrue);
  });

  testWidgets('跨页续段保留全局范围且不拆开 Emoji 与组合字符', (tester) async {
    const source = '首段。\n正文👩‍👩‍👧‍👦甲e\u0301乙𠀀丙🙂丁正文👩‍👩‍👧‍👦末尾。';
    final pages = await _layout(tester, source, width: 90, pageHeight: 60);
    final boundaries = <int>{0};
    var position = 0;
    for (final character in source.characters) {
      position += character.length;
      boundaries.add(position);
    }
    expect(pages.length, greaterThan(1));
    for (final line
        in pages.expand((p) => p.paragraphs).expand((p) => p.lines)) {
      expect(boundaries.contains(line.startIndex), isTrue);
      expect(boundaries.contains(line.endIndex), isTrue);
      expect(
        source.substring(line.startIndex, line.endIndex),
        line.displayText,
      );
    }
    expect(pages.every((p) => identical(p.sourceText, source)), isTrue);
  });

  testWidgets('缩放后的两端对齐仍使用最终绘制宽度', (tester) async {
    final pages = await _layout(
      tester,
      '这是一段足够长的正文内容用于验证中文两端对齐和系统字体缩放。',
      width: 260,
      pageHeight: 500,
      scale: 1.5,
      render: true,
    );
    for (final line in pages.first.paragraphs.first.lines) {
      expect(line.width, lessThanOrEqualTo(260.01));
      expect(line.letterSpacing, isNotNull);
    }
    for (final element in find.byType(RichText).evaluate()) {
      expect(
        (element.renderObject as RenderParagraph).didExceedMaxLines,
        isFalse,
      );
    }
  });
}
