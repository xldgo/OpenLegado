import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';
import 'package:flutter_legado/src/widgets/reader/reader_title_layout.dart';
import 'package:flutter_legado/src/widgets/reader/paragraph_config.dart';
import 'package:flutter_legado/src/widgets/reader/text_layout_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const body = ParagraphConfig(
    fontSize: 20,
    backgroundColor: Colors.white,
    textColor: Colors.black,
    letterSpacing: 2,
  );
  const env = TextLayoutEnvironment(
    baseStyle: TextStyle(fontFamily: 'Ahem'),
    textScaler: TextScaler.linear(1.5),
    direction: TextDirection.ltr,
  );
  for (final relative in [true, false]) {
    test('标题测量冻结相对模式$relative、字重与缩放字距', () {
      final title = ReaderTitleLayout(
        text: 'ABCD',
        chrome: ReaderPageChromeConfig(
          titleSize: 12,
          titleSizeRelative: relative,
          titleFontWeight: 600,
          titleLineHeight: 1.5,
          titleMode: 1,
        ),
      );
      final measured = title.measure(body, env, 200, emptyBody: false);
      final block = measured.blocks.single;
      final style = measured.styles.single;
      expect(style.fontSize, relative ? 32 : 12);
      expect(style.fontWeight, FontWeight.w600);
      expect(
        block['letterSpacingPx'],
        closeTo((relative ? 3.2 : 1.2) * 1.5, .001),
      );
      expect(block['alignment'], 'center');
      expect(block['lineSpacingMultiplier'], 1.5);
      expect(block['emphasized'], isTrue);
    });
  }
  test('正文标题可隐藏，卷章和空章标题仍居中显示', () {
    const title = ReaderTitleLayout(
      text: '标题',
      chrome: ReaderPageChromeConfig(titleMode: 2),
    );
    expect(title.measure(body, env, 300, emptyBody: false).blocks, isEmpty);
    expect(
      title.measure(body, env, 300, emptyBody: true).blocks.single['alignment'],
      'center',
    );
    const volume = ReaderTitleLayout(
      text: '卷章',
      chrome: ReaderPageChromeConfig(titleMode: 2),
      isVolume: true,
    );
    expect(
      volume
          .measure(body, env, 300, emptyBody: false)
          .blocks
          .single['alignment'],
      'center',
    );
  });
  test('位置、标记、正则分段与副标题缩放对应上游', () {
    for (final chrome in [
      const ReaderPageChromeConfig(
        titleSegmentType: 1,
        titleSegmentPosition: 3,
        titleSubtitleScale: .8,
      ),
      const ReaderPageChromeConfig(
        titleSegmentType: 2,
        titleSegmentDelimiter: '章',
        titleSubtitleScale: .8,
      ),
      const ReaderPageChromeConfig(
        titleSegmentType: 3,
        titleSegmentDelimiter: '章',
        titleSubtitleScale: .8,
      ),
    ]) {
      final parts = ReaderTitleLayout(
        text: '第一章 测试标题',
        chrome: chrome,
      ).segments();
      expect(parts.map((p) => p.text.trim()), ['第一章', '测试标题']);
      expect(parts.map((p) => p.scale), [1, .8]);
    }
  });
  test('坏正则保持标题可读，位置切分不拆emoji和组合字形', () {
    expect(
      const ReaderTitleLayout(
        text: '第一章标题',
        chrome: ReaderPageChromeConfig(
          titleSegmentType: 3,
          titleSegmentDelimiter: '[',
        ),
      ).segments().single.text,
      '第一章标题',
    );
    expect(
      const ReaderTitleLayout(
        text: '甲😀乙',
        chrome: ReaderPageChromeConfig(
          titleSegmentType: 1,
          titleSegmentPosition: 2,
        ),
      ).segments().map((p) => p.text),
      ['甲😀', '乙'],
    );
  });
}
