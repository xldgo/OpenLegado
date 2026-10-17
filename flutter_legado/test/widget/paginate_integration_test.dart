library;

/// 排版引擎分页集成测试
///
/// 验证 ParagraphLayoutEngine.paginateChapter 的核心分页逻辑：
/// - 短内容单页
/// - 长内容多页
/// - 超长段落跨页拆分
/// - 设置变化导致重新分页

import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';

void main() {
  setUpNativeReaderLayout();
  group('paginateChapter - 屏级分页测试', () {
    late ParagraphLayoutEngine engine;

    setUp(() {
      // 使用测试用 BuildContext（TextPainter 不需要真实 context）
      engine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        config: const ParagraphConfig(
          fontSize: 16.0,
          lineHeight: 1.5,
          paragraphSpacing: 8.0,
          indent: 32.0,
          justify: true,
          // [A-4] 颜色必填：显式传原默认值（白底/黑字，分页用例与颜色无关）
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );
    });

    test('空内容返回空列表', () async {
      final pages = (await engine.paginateChapter('', 300.0, 600.0));
      expect(pages, isEmpty);
    });

    test('纯空白内容返回空列表', () async {
      final pages = (await engine.paginateChapter('   \n\n   ', 300.0, 600.0));
      expect(pages, isEmpty);
    });

    test('短内容只产生一页', () async {
      const content = '这是一个短段落。';
      final pages = (await engine.paginateChapter(content, 300.0, 600.0));
      expect(pages.length, equals(1));
      expect(pages[0].paragraphs, isNotEmpty);
    });

    test('多段落短内容仍为一页', () async {
      const content = '第一段\n\n第二段\n\n第三段';
      final pages = (await engine.paginateChapter(content, 300.0, 600.0));
      expect(pages.length, equals(1));
      expect(pages[0].paragraphs.length, equals(3));
    });

    test('长内容产生多页', () async {
      // 生成足够长的内容（每段约 100 字，10 段）
      final content = List.generate(
        10,
        (i) => '这是第${i + 1}个段落，包含足够多的文字来测试分页功能。' * 5,
      ).join('\n\n');
      final pages = (await engine.paginateChapter(content, 300.0, 400.0));
      expect(pages.length, greaterThan(1), reason: '长内容应该分成多页');
    });

    test('每页高度不超过页面限制', () async {
      final content = List.generate(
        20,
        (i) => '段落$i：${'测试文字' * 30}',
      ).join('\n\n');
      const pageHeight = 300.0;
      final pages = (await engine.paginateChapter(content, 300.0, pageHeight));

      for (var i = 0; i < pages.length; i++) {
        // 允许少量溢出（段落间距 + 浮点误差）
        expect(
          pages[i].totalHeight,
          lessThanOrEqualTo(pageHeight + 50),
          reason: '第 $i 页高度超出限制: ${pages[i].totalHeight}',
        );
      }
    });

    test('超长单段落正确跨页拆分', () async {
      // 单段超长（无换行符）
      final content = '字' * 2000;
      final pages = (await engine.paginateChapter(content, 300.0, 400.0));
      expect(pages.length, greaterThan(1), reason: '超长段落应拆分到多页');
    });

    test('页面宽度影响每行字数和总页数', () async {
      final content = '这是一段用于测试不同宽度下分页行为的文本内容，应该在不同宽度下产生不同的页数结果。' * 10;
      final narrowPages = (await engine.paginateChapter(content, 150.0, 600.0));
      final widePages = (await engine.paginateChapter(content, 400.0, 600.0));
      // 窄宽度应该产生更多页
      expect(narrowPages.length, greaterThanOrEqualTo(widePages.length));
    });

    test('双页模式栏宽分页：栏宽减半页数相应增多且行宽不越界', () async {
      // [UI-fix v2.0.5 | 2026-08-10] 对齐原版 doubleHorizontalPage 双页语义：
      // 每栏可用宽 =（屏宽 - 左右边距 - 16 栏间隙）/ 2 — Reasonix
      const marginL = 20.0, marginR = 20.0;
      const fullWidth = 800.0;
      final content = List.generate(
        12,
        (i) => '段落$i：${'双页模式分页测试内容文字。' * 8}',
      ).join('\n\n');
      final widePages = (await engine.paginateChapter(
        content,
        fullWidth,
        500.0,
      ));
      final columnWidth = (fullWidth - marginL - marginR - 16) / 2;
      final doublePages = (await engine.paginateChapter(
        content,
        columnWidth,
        500.0,
      ));
      // 栏宽分页页数应不少于全宽分页页数（通常接近 2 倍）
      expect(doublePages.length, greaterThanOrEqualTo(widePages.length));
      // 栏宽分页每行宽度不超栏宽（与渲染侧分页宽严格一致）
      for (final page in doublePages) {
        for (final para in page.paragraphs) {
          for (final line in para.lines) {
            expect(
              line.width,
              lessThanOrEqualTo(columnWidth + 1),
              reason: '双页栏宽下行宽越界: ${line.width}',
            );
          }
        }
      }
    });

    test('useZhLayout 开关：关闭后朴素断行行数不多于避头尾断行且行宽不越界', () async {
      // [UI-fix v2.0.5 | 2026-08-10] 对齐原版 useZhLayout：true=中文避头尾
      // 断行（行首禁标点、提前换行）；false=朴素按宽断行 — Reasonix
      final content = '测试段落，包含中文标点符号，用于验证分行开关行为差异。' * 6;
      const width = 140.0, height = 600.0;
      final zhEngine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        config: const ParagraphConfig(
          fontSize: 16.0,
          lineHeight: 1.5,
          useZhLayout: true,
          // [A-4] 颜色必填：显式传原默认值（白底/黑字，分页用例与颜色无关）
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );
      final plainEngine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        config: const ParagraphConfig(
          fontSize: 16.0,
          lineHeight: 1.5,
          useZhLayout: false,
          // [A-4] 颜色必填：显式传原默认值（白底/黑字，分页用例与颜色无关）
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );
      final zhPages = (await zhEngine.paginateChapter(content, width, height));
      final plainPages = (await plainEngine.paginateChapter(
        content,
        width,
        height,
      ));
      // 朴素断行无避头尾提前换行，行数/页数不多于避头尾模式
      final zhLines = zhPages.fold<int>(
        0,
        (sum, p) =>
            sum + p.paragraphs.fold<int>(0, (s, pa) => s + pa.lines.length),
      );
      final plainLines = plainPages.fold<int>(
        0,
        (sum, p) =>
            sum + p.paragraphs.fold<int>(0, (s, pa) => s + pa.lines.length),
      );
      expect(plainLines, lessThanOrEqualTo(zhLines));
      // 朴素断行行宽不越界
      for (final page in plainPages) {
        for (final para in page.paragraphs) {
          for (final line in para.lines) {
            expect(
              line.width,
              lessThanOrEqualTo(width + 1),
              reason: '朴素断行行宽越界: ${line.width}',
            );
          }
        }
      }
    });

    test('段首悬挂只让出引号宽度并保留独立缩进', () async {
      final hangEngine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        config: const ParagraphConfig(
          fontSize: 16.0,
          lineHeight: 1.5,
          indent: 32.0,
          indentCount: 2,
          useZhLayout: true,
          hangingPunctuation: true,
          // [A-4] 颜色必填：显式传原默认值（白底/黑字，分页用例与颜色无关）
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );
      final content = '　　“这是一个带起始引号的段首，用于验证悬挂标点的分页行为表现。’\n\n第二段普通内容。';
      final pages = (await hangEngine.paginateChapter(content, 300.0, 600.0));
      expect(pages, isNotEmpty);
      final firstPara = pages.first.paragraphs.first;
      expect(firstPara.lines, isNotEmpty);
      // 段首行（缩进+引号）应标记悬挂宽度
      expect(firstPara.lines.first.indentWidth, greaterThan(0));
      // 悬挂行总宽不超 可用宽 + 悬挂宽
      expect(
        firstPara.lines.first.width,
        lessThanOrEqualTo(300.0 + firstPara.lines.first.hangingWidth + 1),
        reason: '悬挂行宽越界: ${firstPara.lines.first.width}',
      );
      // 关闭悬挂开关时无悬挂标记
      final noHangEngine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        config: const ParagraphConfig(
          fontSize: 16.0,
          lineHeight: 1.5,
          indent: 32.0,
          indentCount: 2,
          hangingPunctuation: false,
          // [A-4] 颜色必填：显式传原默认值（白底/黑字，分页用例与颜色无关）
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );
      final noHangPages = (await noHangEngine.paginateChapter(
        content,
        300.0,
        600.0,
      ));
      final noHangFirstLine = noHangPages.first.paragraphs.first.lines.first;
      expect(noHangFirstLine.hangingWidth, equals(0));
    });

    test('页面高度影响总页数', () async {
      final content = List.generate(
        10,
        (i) => '段落$i：${'内容' * 50}',
      ).join('\n\n');
      final shortPages = (await engine.paginateChapter(content, 300.0, 200.0));
      final tallPages = (await engine.paginateChapter(content, 300.0, 800.0));
      // 矮页面应该产生更多页
      expect(shortPages.length, greaterThan(tallPages.length));
    });

    test('字号增大导致页数增加', () async {
      final content = '测试字号对分页的影响，这段文字需要足够长才能看出差异。' * 20;

      final smallFontEngine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        // [A-4] 颜色必填：显式传原默认值（白底/黑字）
        config: const ParagraphConfig(
          fontSize: 12.0,
          lineHeight: 1.5,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );
      final largeFontEngine = ParagraphLayoutEngine(
        transport: nativeReaderLayout,
        // [A-4] 颜色必填：显式传原默认值（白底/黑字）
        config: const ParagraphConfig(
          fontSize: 24.0,
          lineHeight: 1.5,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        ),
        context: _FakeBuildContext(),
      );

      final smallPages = (await smallFontEngine.paginateChapter(
        content,
        300.0,
        600.0,
      ));
      final largePages = (await largeFontEngine.paginateChapter(
        content,
        300.0,
        600.0,
      ));
      expect(largePages.length, greaterThanOrEqualTo(smallPages.length));
    });

    test('分页结果包含有效的行信息', () async {
      const content = '第一段落内容\n\n第二段落内容';
      final pages = (await engine.paginateChapter(content, 300.0, 600.0));

      expect(pages, isNotEmpty);
      for (final page in pages) {
        for (final para in page.paragraphs) {
          for (final line in para.lines) {
            expect(line.words, isNotEmpty, reason: '行应包含字符');
            expect(line.height, greaterThan(0), reason: '行高应大于0');
            expect(line.width, greaterThan(0), reason: '行宽应大于0');
          }
        }
      }
    });
  });
}

/// 测试用 FakeBuildContext（TextPainter 不需要真实 context）
class _FakeBuildContext extends Fake implements BuildContext {}
