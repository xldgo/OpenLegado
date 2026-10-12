import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/services/reader_layout_service.dart';

import '../helpers/reader_layout_host.dart';

import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';

/// 斜体贯通测试（差异清单 C3 双基准补齐项）
///
/// 校验两点：① ParagraphConfig 携带并复制 fontStyle（测量侧同参）；
/// ② 正文渲染控件把 fontStyle 落到 TextStyle（渲染侧同参）。
void main() {
  test('ParagraphConfig 携带并 copyWith 保留 fontStyle（测量侧同参）', () {
    // [A-4] 颜色必填：显式传原默认值（白底/黑字，本用例只验证 fontStyle）
    const cfg = ParagraphConfig(
      fontStyle: FontStyle.italic,
      backgroundColor: Colors.white,
      textColor: Colors.black,
    );
    expect(cfg.fontStyle, FontStyle.italic);
    expect(cfg.copyWith().fontStyle, FontStyle.italic);
    expect(
      cfg.copyWith(fontStyle: FontStyle.normal).fontStyle,
      FontStyle.normal,
    );
  });

  testWidgets('正文段落渲染把 fontStyle 落到 TextStyle（渲染侧同参）', (tester) async {
    await tester.pumpWidget(
      ReaderLayoutTransportScope(
        transport: RustLayoutTestTransport.instance,
        child: MaterialApp(
          home: Scaffold(
            body: LayoutTestBuilder(
              builder: (context) async {
                final pages = await ParagraphLayoutEngine(
                  context: context,
                  config: ParagraphConfig(
                    fontSize: 18,
                    lineHeight: 1.6,
                    paragraphSpacing: 8,
                    textColor: Colors.black,
                    backgroundColor: Colors.white,
                    fontStyle: FontStyle.italic,
                    textEnvironment: TextLayoutEnvironment.of(context),
                  ),
                ).paginateChapter('第一段正文。\n第二段正文。', 320, 580);
                return ReaderTextContent(
                  pageInfo: pages.first,
                  fontSize: 18,
                  lineHeight: 1.6,
                  paragraphSpacing: 8,
                  textColor: Colors.black,
                  fontStyle: FontStyle.italic,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraphs = tester
        .renderObjectList<RenderParagraph>(
          find.byWidgetPredicate((widget) => widget is RichText),
        )
        .toList();
    expect(paragraphs, isNotEmpty, reason: '应渲染出正文段落');
    final styles = paragraphs.map((p) => p.text.style?.fontStyle).toList();
    expect(
      styles.every((s) => s == FontStyle.italic),
      isTrue,
      reason: '正文实际渲染样式应携带 fontStyle: italic，实际=$styles',
    );
  });
}
