@Tags(['native'])
library;

import '../fixtures/app_test_api.dart';

/// 实际滚动布局的标题样式、显隐及原文锚点；标题与正文共用内容块分页。— Codex + UI

import '../helpers/native_reader_layout.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/book_chapter.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_chrome.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/reader_text_content.dart';

/// 测试专用 ReaderNotifier：build() 直接返回指定状态，不调用父类
/// build（其 Future.microtask(_loadSettings) 会把 pageTurnMode 覆写为
/// 存储值，干扰滚动模式断言）
class _FixedReaderNotifier extends ReaderNotifier {
  _FixedReaderNotifier(this.initial);

  final ReaderState initial;

  @override
  ReaderState build() => initial;
}

void main() {
  setUpNativeReaderLayout();
  const chapterTitle = '第一章 滚动标题';
  const bodyFont = 'SimSun';
  const titleFontFamily = 'KaiTi';

  /// 滚动模式状态：单章 + 短正文（排版引擎分页出 1 页，标题块常显）
  ReaderState scrollState() => ReaderState(
    chapters: const [BookChapter(title: chapterTitle, index: 0)],
    chapterContent: '滚动模式正文第一段。\n第二段文字。',
    pageTurnMode: PageTurnMode.scroll,
  );

  Widget wrap(ReaderState state, ReaderPageChromeConfig chrome) {
    return ProviderScope(
      overrides: mergeTestOverrides([
        ...MockBookApi().overrides,
        readerNotifierProvider.overrideWith(() => _FixedReaderNotifier(state)),
      ]),
      child: MaterialApp(
        builder: nativeReaderLayoutBuilder,
        home: ReaderPageView(
          paragraphSpacing: 8,
          pageChrome: chrome,
          // 关闭正文延伸状态栏：测试内 inset 恒 0，断言路径确定
          readBodyToLh: false,
        ),
      ),
    );
  }

  testWidgets('滚动标题遵守独立样式、居中和隐藏', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const chrome = ReaderPageChromeConfig(
      titleSize: 17,
      titleSizeRelative: false,
      titleFontWeight: 600,
      titleLineHeight: 1.4,
      titleMode: 1,
      titleTopSpacing: 7,
      titleBottomSpacing: 9,
    );
    await pumpNativeReaderLayout(tester, wrap(scrollState(), chrome));
    await settleNativeReaderLayout(tester);
    final title = tester
        .widget<ReaderTextContent>(find.byType(ReaderTextContent))
        .pageInfo
        .paragraphs
        .firstWhere((p) => p.isTitle);
    expect(title.lines.first.textStyle!.fontSize, 17);
    expect(title.lines.first.textStyle!.fontWeight, FontWeight.w600);
    expect(title.spacingBefore, closeTo(7, .02));
    expect(title.lines.first.indentWidth, greaterThan(0));
    await pumpNativeReaderLayout(
      tester,
      wrap(scrollState(), const ReaderPageChromeConfig(titleMode: 2)),
    );
    await settleNativeReaderLayout(tester);
    expect(
      tester
          .widget<ReaderTextContent>(find.byType(ReaderTextContent))
          .pageInfo
          .paragraphs
          .where((p) => p.isTitle),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  TextStyle currentTitleStyle(WidgetTester tester) => tester
      .widget<ReaderTextContent>(find.byType(ReaderTextContent))
      .pageInfo
      .paragraphs
      .firstWhere((p) => p.isTitle)
      .lines
      .first
      .textStyle!;

  testWidgets('滚动开章锚点0保留长标题，不自动跳过标题', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = scrollState().copyWith(
      chapters: [BookChapter(title: 'TITLE' * 120, index: 0)],
    );
    await pumpNativeReaderLayout(
      tester,
      wrap(state, const ReaderPageChromeConfig()),
    );
    await settleNativeReaderLayout(tester);
    await tester.pump(const Duration(seconds: 1));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(scroll.position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  group('A4 滚动模式标题字体（_buildScrollContent 标题块）', () {
    testWidgets('titleFontFamily 非空 → 滚动标题 fontFamily 与单源取值一致', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const chrome = ReaderPageChromeConfig(titleFontFamily: titleFontFamily);
      // 单源函数（reader_page_chrome.dart effectiveTitleFontFamily）取值
      final expected = effectiveTitleFontFamily(chrome, bodyFont);
      expect(expected, titleFontFamily);

      await pumpNativeReaderLayout(tester, wrap(scrollState(), chrome));
      await settleNativeReaderLayout(tester);

      final titleStyle = currentTitleStyle(tester);
      expect(
        titleStyle.fontFamily,
        expected,
        reason: '滚动标题 fontFamily 须与 effectiveTitleFontFamily 单源一致',
      );
    });

    testWidgets('titleFontFamily 空 → 滚动标题跟随正文字体（_fontFamily）', (tester) async {
      // 正文字体经 SharedPreferences reader_font_family 注入
      // （ReaderPageView._refreshFontFamily 异步读取后 setState 重建）
      SharedPreferences.setMockInitialValues({'reader_font_family': bodyFont});
      const chrome = ReaderPageChromeConfig();
      final expected = effectiveTitleFontFamily(chrome, bodyFont);
      // 纯函数同参断言（仿 reader_title_font_test.dart：空 titleFont 跟随正文，
      // null 正文=默认字体）
      expect(expected, bodyFont);
      expect(effectiveTitleFontFamily(chrome, null), isNull);

      await pumpNativeReaderLayout(tester, wrap(scrollState(), chrome));
      // 等待 _refreshFontFamily 异步完成（setState 重建）
      await settleNativeReaderLayout(tester);
      // 既有行为（非 A4 引入）：滚动模式 build 会走 _paginateIfNeeded，
      // 其 reader_page_view.dart:616 `Future(() => updateChapterPageCount(...))`
      // 在 SDK 内为 Timer.run（零时长 FakeTimer），创建于该帧 elapse 之后；
      // pumpAndSettle 依 hasScheduledFrame 退出时该 Timer 尚 pending。
      // 追加一次 pump 触发 elapse 使其触发，消除 "Timer still pending" 断言。
      await tester.pump(const Duration(seconds: 1));

      final titleStyle = currentTitleStyle(tester);
      expect(
        titleStyle.fontFamily,
        expected,
        reason: '空 titleFontFamily 时滚动标题应跟随正文字体',
      );
    });

    testWidgets('原内容区直接订阅字体选择，更新正文后标题同步跟随', (tester) async {
      SharedPreferences.setMockInitialValues({'reader_font_family': bodyFont});
      await pumpNativeReaderLayout(
        tester,
        wrap(scrollState(), const ReaderPageChromeConfig()),
      );
      await settleNativeReaderLayout(tester);
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderPageView)),
      );
      final view = tester.state(find.byType(ReaderPageView));
      expect(currentTitleStyle(tester).fontFamily, bodyFont);
      await container
          .read(readerSettingsRepositoryProvider)
          .update(fontFamily: 'Georgia');
      await settleNativeReaderLayout(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.state(find.byType(ReaderPageView)), same(view));
      expect(currentTitleStyle(tester).fontFamily, 'Georgia');
      expect(tester.takeException(), isNull);
    });
  });
}
