import 'package:flutter_legado/src/domain/models/reader_menu_theme_settings.dart';

import '../helpers/reader_layout_host.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/reader/application/reader_state.dart';
import 'package:flutter_legado/src/widgets/paragraph_layout_engine.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_controller.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_region.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selectable_text.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_toolbar.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_theme.dart';
import 'package:flutter_legado/src/widgets/reader/turn/reader_turn_view.dart';

Future<void> _pumpReader(
  WidgetTester tester,
  ReaderSelectionController controller, {
  String source = '这是第一段正文，用于测试跨行文字选择。\n这是第二段正文。',
  ValueChanged<int>? onPageChanged,
  ValueChanged<TapUpDetails>? onTapUp,
  bool selectable = true,
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
  bool outerOverlay = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: outerOverlay ? Overlay.wrap(child: child!) : child!,
        ),
        home: Scaffold(
          body: ReaderMenuThemeHost(
            config: ReaderMenuThemeSettings(mode: outerOverlay ? 1 : 0),
            readingBackground: const Color(0xFFF5EEDB),
            builder: (_) => SizedBox(
              width: 320,
              height: 500,
              child: LayoutTestBuilder(
                builder: (context) async {
                  final pages = (await ParagraphLayoutEngine(
                    transport: RustLayoutTestTransport.instance,
                    context: context,
                    config: ParagraphConfig(
                      fontSize: 16,
                      lineHeight: 1.6,
                      indent: 32,
                      indentCount: 2,
                      paragraphSpacing: 8,
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                      baseStyle: DefaultTextStyle.of(context).style,
                    ),
                  ).paginateChapter(source, 320, 500));
                  Widget body = ReaderTurnView(
                    mode: PageTurnMode.none,
                    pageIndex: 0,
                    pageCount: 2,
                    selectionActive: controller,
                    hasChapterPrev: false,
                    hasChapterNext: false,
                    onTurnChapterPrev: () {},
                    onTurnChapterNext: () {},
                    onPageChanged: onPageChanged ?? (_) {},
                    buildPage: (index) => index == 0
                        ? ReaderTextContent(
                            pageInfo: pages.first,
                            fontSize: 16,
                            lineHeight: 1.6,
                            paragraphSpacing: 8,
                            textColor: Colors.black,
                            selectText: selectable,
                          )
                        : const SelectionContainer.disabled(child: Text('下一页')),
                  );
                  if (selectable) {
                    body = ReaderSelectionRegion(
                      controller: controller,
                      pages: [pages.first],
                      source: source,
                      onTapUp: onTapUp,
                      child: body,
                    );
                  }
                  return GestureDetector(onTapUp: onTapUp, child: body);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SelectableRegionState _region(WidgetTester tester) =>
    tester.state<SelectableRegionState>(find.byType(SelectableRegion).first);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReaderSelectionController controller;
  String? clipboard;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    controller = ReaderSelectionController();
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('长按正文产生实际选区、高亮数据及浮动菜单', (tester) async {
    await _pumpReader(tester, controller);
    final liveText = find
        .byType(ReaderLineText)
        .evaluate()
        .where((e) => (e.widget as ReaderLineText).data.startsWith('这是第一'))
        .last;
    await tester.longPress(find.byWidget(liveText.widget));
    await tester.pumpAndSettle();
    expect(controller.selection, isNotNull);
    expect(controller.selection!.text.trim(), isNotEmpty);
    expect(find.byType(ReaderSelectionToolbar), findsOneWidget);
    final selectedParagraphs = find
        .byWidgetPredicate((widget) => widget is RichText)
        .evaluate()
        .map((e) => e.renderObject as RenderParagraph)
        .where((p) => p.selections.any((s) => !s.isCollapsed));
    expect(selectedParagraphs, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全选跨行跨段从原文取值，复制不包含排版缩进', (tester) async {
    const source = '第一段正文很长，用于测试断行后仍保留原文。\n\n第二段正文。';
    await _pumpReader(tester, controller, source: source);
    _region(tester).selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    expect(controller.selection!.text, source);
    expect(controller.selection!.start, 0);
    expect(controller.selection!.end, source.length);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(clipboard, source);
    expect(controller.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缩进保留视觉留白，但不属于原生选区的文本和高亮', (tester) async {
    await _pumpReader(tester, controller);
    _region(tester).selectAll();
    await tester.pumpAndSettle();
    final paragraphs = find
        .byWidgetPredicate((widget) => widget is RichText)
        .evaluate()
        .map((e) => e.renderObject as RenderParagraph)
        .where((p) => p.selections.any((s) => !s.isCollapsed))
        .toList();
    expect(paragraphs, isNotEmpty);
    expect(
      paragraphs.every((p) => !p.text.toPlainText().startsWith('\u3000')),
      isTrue,
    );
    final first = paragraphs.first;
    final selectionBox = first
        .getBoxesForSelection(first.selections.first)
        .first;
    expect(
      first.localToGlobal(selectionBox.toRect().topLeft).dx,
      greaterThan(20),
    );
    expect(controller.selection!.start, 0);
    expect(controller.selection!.text, '这是第一段正文，用于测试跨行文字选择。\n这是第二段正文。');
  });

  testWidgets('选区期间拖动不会启动翻页，清空后恢复翻页', (tester) async {
    var turns = 0;
    await _pumpReader(tester, controller, onPageChanged: (_) => turns++);
    _region(tester).selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(240, 200), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(turns, 0);
    controller.clear();
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(240, 200), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(turns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文内部实际存在的空格仍可选择并复制', (tester) async {
    const source = '第一段  正文。\n第二段　正文。';
    await _pumpReader(tester, controller, source: source);
    _region(tester).selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    expect(controller.selection!.text, source);
    final text = find
        .byWidgetPredicate((widget) => widget is RichText)
        .evaluate()
        .map((e) => e.renderObject as RenderParagraph)
        .where((p) => p.selections.any((s) => !s.isCollapsed))
        .map((p) => p.text.toPlainText())
        .join();
    expect(text, contains('第一段  正文。'));
    expect(text, contains('第二段　正文。'));
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(clipboard, source);
  });

  testWidgets('重新排版清除旧选区，新的选区对应新正文', (tester) async {
    await _pumpReader(tester, controller);
    _region(tester).selectAll();
    await tester.pumpAndSettle();
    await _pumpReader(tester, controller, source: '重新排版后的新正文。');
    expect(controller.value, isFalse);
    _region(tester).selectAll();
    await tester.pumpAndSettle();
    expect(controller.selection!.text, '重新排版后的新正文。');
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭选择开关时不创建正文原生选区', (tester) async {
    await _pumpReader(tester, controller, selectable: false);
    expect(find.byType(SelectableRegion), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通点按打开阅读菜单，选区点按只关闭选区', (tester) async {
    var taps = 0;
    await _pumpReader(tester, controller, onTapUp: (_) => taps++);
    await tester.tapAt(const Offset(160, 180));
    await tester.pumpAndSettle();
    expect(taps, 1);
    _region(tester).selectAll();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(160, 180));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(controller.value, isFalse);
    await tester.tapAt(const Offset(160, 180));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('iOS 平台长按后点击复制执行操作并关闭选区', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pumpReader(
        tester,
        controller,
        platform: TargetPlatform.iOS,
        outerOverlay: true,
      );
      final text = find
          .byType(ReaderLineText)
          .evaluate()
          .where((e) => (e.widget as ReaderLineText).data.startsWith('这是第一'))
          .last;
      await tester.longPress(find.byWidget(text.widget));
      await tester.pumpAndSettle();
      final toolbar = tester.element(find.byType(ReaderSelectionToolbar));
      final body = tester.element(find.byType(ReaderSelectionRegion));
      expect(Theme.of(toolbar).colorScheme, isNot(Theme.of(body).colorScheme));
      expect(
        Theme.of(toolbar).colorScheme,
        Theme.of(readerMenuContextOf(body)).colorScheme,
      );
      expect(controller.selection, isNotNull);
      expect(find.byType(ReaderSelectionToolbar), findsOneWidget);
      final selectedText = controller.selection!.text;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('复制')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(clipboard, selectedText);
      expect(controller.value, isFalse);
      expect(find.byType(ReaderSelectionToolbar), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('放大系统字体后选区工具条能够滚动且不溢出', (tester) async {
    await _pumpReader(tester, controller, textScale: 2);
    _region(tester).selectAll(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    expect(find.byType(ReaderSelectionToolbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖动原生手柄可跨段扩大选区且不会翻页', (tester) async {
    var turns = 0;
    await _pumpReader(tester, controller, onPageChanged: (_) => turns++);
    final first = find
        .byType(ReaderLineText)
        .evaluate()
        .where((e) => (e.widget as ReaderLineText).data.startsWith('这是第一'))
        .last;
    await tester.longPress(find.byWidget(first.widget));
    await tester.pumpAndSettle();
    final initial = controller.selection!;
    final handle =
        tester.getTopLeft(find.byType(SelectableRegion)) +
        _region(tester).selectionEndpoints.last.point +
        const Offset(11, 11);
    final second = find
        .byWidgetPredicate((widget) => widget is RichText)
        .evaluate()
        .map((e) => e.renderObject as RenderParagraph)
        .where((p) => p.text.toPlainText().startsWith('这是第二'))
        .last;
    final targetBox = second
        .getBoxesForSelection(
          const TextSelection(baseOffset: 7, extentOffset: 8),
        )
        .first;
    final target =
        second.localToGlobal(targetBox.toRect().bottomRight) +
        const Offset(11, 11);
    await tester.dragFrom(handle, target - handle);
    await tester.pumpAndSettle();
    expect(controller.selection!.end, greaterThan(initial.end));
    expect(controller.selection!.text, contains('\n'));
    expect(turns, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('双页选区先读完左页，右页的偏移不会与左页交错', (tester) async {
    final source = List.generate(
      12,
      (i) => '第${i + 1}段正文内容，用于验证双页文字选择。',
    ).join('\n');
    late List<PageInfo> pages;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LayoutTestBuilder(
              builder: (context) async {
                pages = (await ParagraphLayoutEngine(
                  transport: RustLayoutTestTransport.instance,
                  context: context,
                  config: ParagraphConfig(
                    fontSize: 16,
                    lineHeight: 1.6,
                    paragraphSpacing: 8,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    baseStyle: DefaultTextStyle.of(context).style,
                  ),
                ).paginateChapter(source, 240, 160)).take(2).toList();
                return ReaderSelectionRegion(
                  controller: controller,
                  pages: pages,
                  source: source,
                  child: SizedBox(
                    width: 480,
                    height: 500,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final page in pages)
                          SizedBox(
                            width: 240,
                            child: ReaderTextContent(
                              pageInfo: page,
                              fontSize: 16,
                              lineHeight: 1.6,
                              paragraphSpacing: 8,
                              textColor: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rightLine = pages.last.paragraphs.first.lines.first;
    final rightText = find
        .descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is ReaderTextContent &&
                identical(widget.pageInfo, pages.last),
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ReaderLineText &&
                widget.data == rightLine.selectableText,
          ),
        )
        .first;
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: rightText,
        matching: find.byWidgetPredicate((widget) => widget is RichText),
      ),
    );
    // 短行容器现在保留完整正文宽度，长按实际字形而非行末空白。
    final firstBox = paragraph
        .getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: rightLine.selectableText.characters.first.length,
          ),
        )
        .first
        .toRect();
    await tester.longPressAt(paragraph.localToGlobal(firstBox.center));
    await tester.pumpAndSettle();
    final range = paragraph.selections.first;
    expect(controller.selection!.start, rightLine.sourceOffset(range.start));
    expect(controller.selection!.end, rightLine.sourceOffset(range.end));
    _region(tester).selectAll();
    await tester.pumpAndSettle();
    final start = pages.first.paragraphs.first.lines.first.startIndex;
    final end = pages.last.paragraphs.last.lines.last.endIndex;
    expect(controller.selection!.text, source.substring(start, end));
    expect(tester.takeException(), isNull);
  });
}
