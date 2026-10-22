@Tags(['native'])
library;

import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/features/reader/layout/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_page_chrome.dart';
import 'package:flutter_legado/src/features/reader/layout/reader_title_layout.dart';
import 'package:flutter_legado/src/features/reader/widgets/reader_text_content.dart';

/// 标题和正文共用Rust分页结果，真实渲染与页面容量不能溢出。— Codex + UI
const _defaultChrome = ReaderPageChromeConfig();

void main() {
  setUpNativeReaderLayout();
  const fontSize = 22.0;
  const lineHeight = 1.8;
  const paragraphSpacing = 12.0;
  const marginTop = 24.0;
  const marginBottom = 24.0;
  const marginLeft = 20.0;
  const marginRight = 20.0;
  const chapterTitle = '第一章 满页正文分页高度回归';

  double measureHeaderBlock(BuildContext context) =>
      ReaderPageLayoutMetrics.headerBlockHeight(context, _defaultChrome);

  double measureFooterBlock(BuildContext context) =>
      ReaderPageLayoutMetrics.footerBlockHeight(context, _defaultChrome);

  /// 生成足以铺满多页的正文
  String buildLongContent() => List.generate(
    60,
    (i) =>
        '这是第${i + 1}段正文内容，用于验证满页分页时不会超出渲染容器高度，'
        '模拟真实小说正文的段落密度与长度，避免测量与渲染两侧高度不一致。',
  ).join('\n');

  /// 按生产链路分页并渲染指定页，返回分页结果
  Future<List<PageInfo>> pumpPage(WidgetTester tester, int pageIndex) async {
    late List<PageInfo> pages;
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: Scaffold(
          body: LayoutTestBuilder(
            builder: (context) async {
              final size = MediaQuery.of(context).size;
              final availableWidth = size.width - marginLeft - marginRight;
              final headerBlock = measureHeaderBlock(context);
              final footerBlock = measureFooterBlock(context);
              final availableHeight =
                  size.height -
                  headerBlock -
                  footerBlock -
                  marginTop -
                  marginBottom;
              final engine = ParagraphLayoutEngine(
                transport: nativeReaderLayout,
                config: const ParagraphConfig(
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  paragraphSpacing: paragraphSpacing,
                  // [A-4] 颜色必填：与下方 ReaderTypographicPage 同参（白底黑字）
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
                context: context,
              );
              pages = (await engine.paginateChapter(
                buildLongContent(),
                availableWidth,
                availableHeight,
                title: const ReaderTitleLayout(
                  text: chapterTitle,
                  chrome: _defaultChrome,
                ),
              ));
              final safeIndex = pageIndex.clamp(0, pages.length - 1);
              return ReaderTypographicPage(
                pageInfo: pages[safeIndex],
                pageIndex: safeIndex,
                totalPages: pages.length,

                fontSize: fontSize,
                lineHeight: lineHeight,
                paragraphSpacing: paragraphSpacing,
                backgroundColor: Colors.white,
                textColor: Colors.black,
                contentPadding: const EdgeInsets.only(
                  left: marginLeft,
                  right: marginRight,
                  top: marginTop,
                  bottom: marginBottom,
                ),
              );
            },
          ),
        ),
      ),
    );
    return pages;
  }

  testWidgets('首页（含章节标题块）满页正文渲染无 RenderFlex 溢出', (tester) async {
    final pages = await pumpPage(tester, 0);
    // 分页应产生多页（正文足够长），且首页渲染不抛溢出异常
    expect(pages.length, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('非首页满页正文渲染无 RenderFlex 溢出', (tester) async {
    await pumpPage(tester, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('标题与正文共同分页，每页不超过内容区高度', (tester) async {
    late List<PageInfo> pages;
    late double availableHeight;
    await pumpNativeReaderLayout(
      tester,
      MaterialApp(
        home: LayoutTestBuilder(
          builder: (context) async {
            final size = MediaQuery.of(context).size;
            final availableWidth = size.width - marginLeft - marginRight;
            final headerBlock = measureHeaderBlock(context);
            final footerBlock = measureFooterBlock(context);
            availableHeight =
                size.height -
                headerBlock -
                footerBlock -
                marginTop -
                marginBottom;
            final engine = ParagraphLayoutEngine(
              transport: nativeReaderLayout,
              config: const ParagraphConfig(
                fontSize: fontSize,
                lineHeight: lineHeight,
                paragraphSpacing: paragraphSpacing,
                // [A-4] 颜色必填：与下方 ReaderTypographicPage 同参（白底黑字）
                backgroundColor: Colors.white,
                textColor: Colors.black,
              ),
              context: context,
            );
            pages = (await engine.paginateChapter(
              buildLongContent(),
              availableWidth,
              availableHeight,
              title: const ReaderTitleLayout(
                text: chapterTitle,
                chrome: _defaultChrome,
              ),
            ));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(pages, isNotEmpty);
    for (var i = 0; i < pages.length; i++) {
      final capacity = availableHeight;
      expect(
        pages[i].totalHeight,
        lessThanOrEqualTo(capacity),
        reason:
            '第 ${i + 1} 页排版高度 ${pages[i].totalHeight} '
            '超过页容量 $capacity（标题已计入分页结果）',
      );
    }
  });
}
