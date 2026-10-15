import 'dart:async';

import 'package:flutter_legado/src/models/reader_advanced_config.dart';

import '../helpers/reader_layout_host.dart';
import '../fixtures/home_settings_storage.dart';

import 'package:flutter_legado/src/data/services/app_settings_service.dart';
import 'package:flutter_legado/src/domain/models/app_settings_snapshot.dart';
import 'package:flutter_legado/src/providers/app_settings_provider.dart';
import 'package:flutter_legado/src/providers/reader/reader_settings_provider.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/screens/reader_screen.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_panel.dart';
import 'package:flutter_legado/src/widgets/reader/reader_page_view.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_theme.dart';
import 'package:flutter_legado/src/widgets/reader/reader_content_edit_dialog.dart';

class _Reader extends ReaderNotifier {
  final ReaderState? initialState;
  _Reader([this.initialState]);

  int seekCalls = 0;
  ReaderState get value => state;

  @override
  ReaderState build() =>
      initialState ??
      const ReaderState(
        currentBook: Book(
          bookUrl: 'loc_book/menu.txt',
          name: '菜单点击测试',
          origin: BookType.localTag,
        ),
        chapters: [
          BookChapter(title: '第一章', index: 0),
          BookChapter(title: '第二章', index: 1),
          BookChapter(title: '第三章', index: 2),
        ],
        currentChapterIndex: 1,
        showControls: true,
      );

  @override
  Future<void> goToChapter(int index, {int? sourceOffset}) async {
    seekCalls++;
    state = state.copyWith(currentChapterIndex: index);
  }
}

class _Hits {
  int bodyPointers = 0;
  int bodyTaps = 0;
  int bodyDrags = 0;
  int bodyLongPresses = 0;
  int ancestorTaps = 0;
  int catalogTaps = 0;
}

class _ScreenReader extends _Reader {
  final PageTurnMode mode;
  _ScreenReader([this.mode = PageTurnMode.none]);

  @override
  ReaderState build() => super.build().copyWith(
    chapterContent: List.filled(60, '这是用于验证菜单遮挡与正文翻页的测试段落。').join('\n'),
    currentChapterPos: 1,
    pageTurnMode: mode,
  );
}

Future<(_Reader, _Hits)> _pumpMenu(
  WidgetTester tester, {
  ReaderState? initialState,
  RouteFactory? onGenerateRoute,
  AppSettingsService? settingsService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final hits = _Hits();
  final container = ProviderContainer(
    overrides: [
      readerNotifierProvider.overrideWith(() => _Reader(initialState)),
      bookApiProvider.overrideWithValue(MockBookApi()),
      if (settingsService != null)
        appSettingsServiceProvider.overrideWithValue(settingsService),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: readerLayoutTestBuilder,
        onGenerateRoute: onGenerateRoute,
        home: Scaffold(
          // 同时覆盖祖先点击识别和翻页组件使用的原始指针事件。
          body: GestureDetector(
            onTapUp: (_) => hits.ancestorTaps++,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => hits.bodyPointers++,
                    onPointerMove: (_) => hits.bodyPointers++,
                    onPointerUp: (_) => hits.bodyPointers++,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => hits.bodyTaps++,
                      onPanUpdate: (_) => hits.bodyDrags++,
                      onLongPress: () => hits.bodyLongPresses++,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) => ReaderMenuThemeHost(
                    config: ReaderAdvancedConfig(readBarStyle: 1),
                    readingBackground: const Color(0xFFF5EEDB),
                    builder: (_) => ReaderMenuTheme(
                      builder: (context) => ReaderMenuPanel(
                        visible: ref.watch(readerNotifierProvider).showControls,
                        onBack: () {},
                        onAddBookmark: () {},
                        onOpenCatalog: () => hits.catalogTaps++,
                        onOpenSettings: () {},
                        onOpenAdvancedConfig: () {},
                        onOpenContentSearch: () {},
                        onReadAloud: () {},
                        onToggleAutoPage: () {},
                        onOpenReplaceRules: () {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container.read(readerNotifierProvider.notifier) as _Reader, hits);
}

void _expectNoBodyEvents(_Hits hits) {
  expect(hits.bodyPointers, 0);
  expect(hits.bodyDrags, 0);
  _expectNoBodyActions(hits);
}

void _expectNoBodyActions(_Hits hits) {
  expect(hits.bodyTaps, 0);
  expect(hits.bodyLongPresses, 0);
  expect(hits.ancestorTaps, 0);
}

Future<ProviderContainer> _pumpReader(
  WidgetTester tester, {
  PageTurnMode mode = PageTurnMode.none,
  AppSettingsService? settingsService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      readerNotifierProvider.overrideWith(() => _ScreenReader(mode)),
      bookApiProvider.overrideWithValue(MockBookApi()),
      if (settingsService != null)
        appSettingsServiceProvider.overrideWithValue(settingsService),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        builder: readerLayoutTestBuilder,
        home: ReaderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // 菜单手势从章内第二页开始，避免配置重排将旧初始页码归零。
  if (mode != PageTurnMode.scroll) {
    tester.state<ReaderPageViewState>(find.byType(ReaderPageView)).goToPage(1);
    await tester.pumpAndSettle();
  }
  return container;
}

void main() {
  testWidgets('正文按同源八项排版设置接参，恢复重读刷新且高级保存不覆盖', (tester) async {
    final storage = HomeSettingsStorage();
    storage.values.addAll({
      'reader_paragraph_spacing': 9.0,
      'reader_letter_spacing': 0.2,
      'reader_paragraph_indent': 3,
      'reader_text_full_justify': false,
      'reader_text_bold': 2,
      'reader_italic': true,
      'reader_use_zh_layout': true,
      'reader_hanging_punctuation': true,
    });
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(() => unawaited(service.dispose()));
    final container = await _pumpReader(tester, settingsService: service);
    final repository = container.read(readerSettingsRepositoryProvider);
    await repository.load();
    await tester.pumpAndSettle();
    ReaderPageView view() =>
        tester.widget<ReaderPageView>(find.byType(ReaderPageView));
    expect(view().paragraphSpacing, 9);
    expect(view().letterSpacing, 0.2);
    expect(view().paragraphIndent, 3);
    expect(view().textFullJustify, isFalse);
    expect(view().textBold, 2);
    expect(view().italic, isTrue);
    expect(view().useZhLayout, isTrue);
    expect(view().hangingPunctuation, isTrue);
    await repository.updateTextLayout(letterSpacing: 0, textBold: 1);
    await tester.pumpAndSettle();
    expect(view().letterSpacing, 0);
    expect(view().textBold, 1);
    storage.values['reader_paragraph_indent'] = 1;
    await repository.reload();
    await tester.pumpAndSettle();
    expect(view().paragraphIndent, 1);
    final advanced = await repository.loadAdvanced();
    advanced.autoPageTurnInterval = 30;
    await container.read(readerAdvConfigProvider.notifier).commit(advanced);
    await tester.pumpAndSettle();
    expect(view().letterSpacing, 0);
    expect(view().textBold, 1);
    expect(view().paragraphIndent, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正文边距、双页和页壳从同源页面设置接参，修改及恢复重读同步', (tester) async {
    final storage = HomeSettingsStorage();
    storage.values.addAll({
      'reader_page_margin_top': 30.0,
      'reader_page_margin_bottom': 31.0,
      'reader_page_margin_left': 21.0,
      'reader_page_margin_right': 22.0,
      'reader_title_mode': 1,
      'reader_title_size': 3,
      'reader_title_top_spacing': 5,
      'reader_title_bottom_spacing': 6,
      'reader_header_mode': 1,
      'reader_header_padding_top': 4.0,
      'reader_header_show_line': true,
      'reader_header_tip_left': 7,
      'reader_footer_mode': 2,
      'reader_footer_padding_bottom': 8.0,
      'reader_footer_show_line': false,
      'reader_footer_tip_right': 5,
      'reader_double_horizontal_page': 2,
    });
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(() => unawaited(service.dispose()));
    final container = await _pumpReader(tester, settingsService: service);
    final repository = container.read(readerSettingsRepositoryProvider);
    await repository.load();
    await tester.pumpAndSettle();
    ReaderPageView view() =>
        tester.widget<ReaderPageView>(find.byType(ReaderPageView));
    expect(view().marginTop, 30);
    expect(view().marginBottom, 31);
    expect(view().marginLeft, 21);
    expect(view().marginRight, 22);
    expect(view().doubleHorizontalPage, 2);
    expect(view().pageChrome.titleSize, 3);
    expect(view().pageChrome.titleMode, 1);
    expect(view().pageChrome.headerMode, 1);
    expect(view().pageChrome.headerPaddingTop, 4);
    expect(view().pageChrome.showHeaderLine, isTrue);
    expect(view().pageChrome.tipHeaderLeft, 7);
    expect(view().pageChrome.footerPaddingBottom, 8);
    expect(view().pageChrome.showFooterLine, isFalse);
    expect(view().pageChrome.tipFooterRight, 5);
    await repository.updatePageLayout(left: 23);
    await repository.updateTitle(size: 4);
    await tester.pumpAndSettle();
    expect(view().marginLeft, 23);
    expect(view().pageChrome.titleSize, 4);
    storage.values['reader_header_tip_left'] = 2;
    await repository.reload();
    await tester.pumpAndSettle();
    expect(view().pageChrome.tipHeaderLeft, 2);
    final advanced = await repository.loadAdvanced();
    advanced.hideStatusBar = true;
    await container.read(readerAdvConfigProvider.notifier).commit(advanced);
    await tester.pumpAndSettle();
    expect(view().pageChrome.hideStatusBar, isTrue);
    expect(view().pageChrome.titleSize, 4);
    expect(view().marginLeft, 23);
    expect(tester.takeException(), isNull);
    // 系统栏变化后排版会安排下一轮回写，卸载并推进事件时钟完成回调。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('编辑内容继承阅读菜单主题，关闭动画与再次编辑不访问已释放控制器', (tester) async {
    final (reader, hits) = await _pumpMenu(
      tester,
      initialState: const ReaderState(
        currentBook: Book(
          bookUrl: 'loc_book/menu.txt',
          origin: BookType.localTag,
        ),
        chapters: [BookChapter(title: '第一章', index: 0)],
        chapterContent: '原章节正文',
        showControls: true,
      ),
    );
    final menuTheme = Theme.of(tester.element(find.byType(ReaderMenuPanel)));
    final appTheme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(menuTheme.colorScheme, isNot(appTheme.colorScheme));
    for (final systemBack in [false, true]) {
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑内容'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderContentEditDialog), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(AlertDialog))).colorScheme,
        menuTheme.colorScheme,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '原章节正文',
      );
      await tester.enterText(find.byType(TextField), '未保存的修改');
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('取消'));
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderContentEditDialog), findsNothing);
      expect(reader.value.chapterContent, '原章节正文');
      expect(tester.takeException(), isNull);
    }
    _expectNoBodyEvents(hits);
  });

  testWidgets('更多弹出菜单打开时，第一次正文点击只关闭弹出菜单', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsOneWidget);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  testWidgets('关闭更多菜单的拖动不会同时关闭阅读菜单或翻页', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 300), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);

    await tester.dragFrom(const Offset(400, 300), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    expect(hits.bodyDrags, greaterThan(0));
  });

  testWidgets('系统返回只关闭更多菜单，下一次正文点击仍可收起阅读菜单', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    expect(reader.value.showControls, isTrue);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  testWidgets('外部关闭阅读菜单后重新打开，不残留弹出菜单的输入拦截', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    reader.hideControls();
    await tester.pumpAndSettle();
    reader.toggleControls();
    await tester.pumpAndSettle();
    expect(find.text('添加书签'), findsNothing);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  for (final x in [8.0, 400.0, 792.0]) {
    testWidgets('菜单外正文 x=$x 点击只收起菜单，不触发正文点击', (tester) async {
      final (reader, hits) = await _pumpMenu(tester);
      await tester.tapAt(Offset(x, 300));
      await tester.pump();
      expect(reader.value.showControls, isFalse);
      expect(reader.value.currentChapterIndex, 1);
      _expectNoBodyActions(hits);
    });
  }

  testWidgets('顶栏书名和底栏留白消费点击，不关闭菜单或触发正文', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.text('菜单点击测试'));
    await tester.tapAt(Offset(2, tester.getCenter(find.byType(Slider)).dy));
    await tester.pump();
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);
  });

  testWidgets('菜单按钮和进度滑条仍能操作，拖动不传给正文翻页', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    await tester.tap(find.text('目录'));
    await tester.drag(find.byType(Slider), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(hits.catalogTaps, 1);
    expect(reader.seekCalls, greaterThan(0));
    expect(reader.value.showControls, isTrue);
    _expectNoBodyEvents(hits);
  });

  for (final direction in [
    const Offset(-300, 0),
    const Offset(300, 0),
    const Offset(0, -180),
    const Offset(0, 180),
  ]) {
    testWidgets('菜单外滑动 $direction 收起菜单，同时传给正文', (tester) async {
      final (reader, hits) = await _pumpMenu(tester);
      await tester.dragFrom(const Offset(400, 300), direction);
      await tester.pumpAndSettle();
      expect(reader.value.showControls, isFalse);
      expect(hits.bodyPointers, greaterThan(0));
      expect(hits.bodyDrags, greaterThan(0));
      _expectNoBodyActions(hits);
    });
  }

  testWidgets('菜单外按下即收起，长按不会选中正文', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    expect(reader.value.showControls, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump();
    _expectNoBodyActions(hits);
  });

  testWidgets('菜单淡出时仍阻断点击，消失后恢复正文点击', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    reader.hideControls();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(792, 300));
    _expectNoBodyEvents(hits);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(792, 300));
    expect(hits.bodyPointers, greaterThan(0));
    expect(hits.bodyTaps, 1);
  });

  testWidgets('菜单刚打开且淡入尚未开始时，正文区域也只关闭菜单', (tester) async {
    final (reader, hits) = await _pumpMenu(tester);
    reader.hideControls();
    await tester.pumpAndSettle();
    reader.toggleControls();
    await tester.pump();
    await tester.tapAt(const Offset(792, 300));
    await tester.pump();
    expect(reader.value.showControls, isFalse);
    _expectNoBodyActions(hits);
  });

  for (final x in [8.0, 400.0, 792.0]) {
    testWidgets('真实阅读器菜单外 x=$x 点击不翻页，关闭后恢复右侧翻页', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          readerNotifierProvider.overrideWith(_ScreenReader.new),
          bookApiProvider.overrideWithValue(MockBookApi()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            builder: readerLayoutTestBuilder,
            home: ReaderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pages = tester.state<ReaderPageViewState>(
        find.byType(ReaderPageView),
      );
      expect(pages.pageCount, greaterThan(2));
      final before = container.read(readerNotifierProvider).currentChapterPos;
      await tester.tapAt(Offset(x, 300));
      await tester.pump();
      expect(container.read(readerNotifierProvider).showControls, isFalse);
      expect(container.read(readerNotifierProvider).currentChapterPos, before);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(792, 300));
      await tester.pumpAndSettle();
      expect(
        container.read(readerNotifierProvider).currentChapterPos,
        before + 1,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final dx in [-300.0, 300.0]) {
    testWidgets('真实阅读器菜单外横滑 $dx 收起菜单并完成翻页', (tester) async {
      final container = await _pumpReader(tester);
      final before = container.read(readerNotifierProvider).currentChapterPos;
      await tester.dragFrom(const Offset(400, 300), Offset(dx, 0));
      await tester.pumpAndSettle();
      expect(container.read(readerNotifierProvider).showControls, isFalse);
      expect(
        container.read(readerNotifierProvider).currentChapterPos,
        before + (dx < 0 ? 1 : -1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('菜单完全淡出后，同一个按住的指针仍可继续翻页', (tester) async {
    final container = await _pumpReader(tester);
    final before = container.read(readerNotifierProvider).currentChapterPos;
    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      container.read(readerNotifierProvider).currentChapterPos,
      before + 1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单淡出后才松手的点击不会误触正文翻页', (tester) async {
    final container = await _pumpReader(tester);
    final before = container.read(readerNotifierProvider).currentChapterPos;
    final gesture = await tester.startGesture(const Offset(792, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    expect(container.read(readerNotifierProvider).currentChapterPos, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动阅读上下滑均关闭菜单并继续滚动正文', (tester) async {
    final container = await _pumpReader(tester, mode: PageTurnMode.scroll);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ReaderPageView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final before = scrollable.position.pixels;
    await tester.dragFrom(const Offset(400, 360), const Offset(0, -180));
    await tester.pumpAndSettle();
    final afterUp = scrollable.position.pixels;
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    expect(afterUp, greaterThan(before));
    container.read(readerNotifierProvider.notifier).toggleControls();
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 240), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(container.read(readerNotifierProvider).showControls, isFalse);
    expect(scrollable.position.pixels, lessThan(afterUp));
    expect(tester.takeException(), isNull);
  });

  const onlineBook = Book(
    bookUrl: 'https://source.test/book/1',
    name: '菜单点击测试',
    origin: 'https://source.test',
  );
  ReaderState linkState(BookChapter chapter, {Book book = onlineBook}) =>
      ReaderState(currentBook: book, chapters: [chapter], showControls: true);

  for (final (chapter, expectedUrl) in [
    (
      const BookChapter(title: '章节网页', url: 'https://source.test/1.html?q=1'),
      'https://source.test/1.html?q=1',
    ),
    (
      const BookChapter(
        title: '章节网页',
        url: '../1.html',
        baseUrl: 'https://source.test/book/toc.html',
      ),
      'https://source.test/1.html',
    ),
    (
      const BookChapter(
        title: '章节网页',
        url: '//source.test/1.html',
        baseUrl: 'http://source.test/toc.html',
      ),
      'http://source.test/1.html',
    ),
  ]) {
    testWidgets('点击章节名打开当前章节网页：$expectedUrl', (tester) async {
      RouteSettings? opened;
      final (reader, hits) = await _pumpMenu(
        tester,
        initialState: linkState(chapter),
        onGenerateRoute: (settings) {
          opened = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('章节浏览页')),
          );
        },
      );
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(opened?.name, AppRoutes.browser);
      expect(opened?.arguments, {'url': expectedUrl, 'title': '章节链接'});
      expect(find.text('章节浏览页'), findsOneWidget);
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
      Navigator.of(tester.element(find.text('章节浏览页'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('章节网页'), findsOneWidget);
      expect(reader.value.currentChapterIndex, 0);
    });
  }

  testWidgets('无网页地址、本地书及卷标题的章节名保持普通文字', (tester) async {
    final cases = [
      linkState(const BookChapter(title: '章节网页')),
      linkState(const BookChapter(title: '章节网页', url: 'chapter.html')),
      linkState(const BookChapter(title: '章节网页', url: 'https:/missing-host')),
      linkState(const BookChapter(title: '章节网页', url: 'http://[')),
      linkState(const BookChapter(title: '章节网页', url: 'file:///book.txt')),
      linkState(const BookChapter(title: '章节网页', url: 'javascript:alert(1)')),
      linkState(
        const BookChapter(
          title: '章节网页',
          url: 'https://source.test/1.html',
          isVolume: true,
        ),
      ),
      linkState(
        const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
        book: const Book(bookUrl: 'local.txt', origin: BookType.localTag),
      ),
    ];
    for (final state in cases) {
      var opens = 0;
      final (reader, hits) = await _pumpMenu(
        tester,
        initialState: state,
        onGenerateRoute: (_) {
          opens++;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('不应打开')),
          );
        },
      );
      expect(find.byTooltip('打开章节网页'), findsNothing);
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(
        opens,
        0,
        reason: '${state.currentBook?.origin} ${state.currentChapter?.url}',
      );
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
    }
  });

  for (final failed in [false, true]) {
    testWidgets('章节链接沿用系统浏览器偏好，打开${failed ? '失败有提示' : '成功'}', (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (failed) throw PlatformException(code: '打开失败');
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      var routes = 0;
      final (reader, hits) = await _pumpMenu(
        tester,
        initialState: linkState(
          const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
        ),
        onGenerateRoute: (_) {
          routes++;
          return MaterialPageRoute<void>(builder: (_) => const SizedBox());
        },
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderMenuPanel)),
      );
      await container
          .read(readerSettingsRepositoryProvider)
          .update(chapterInSystemBrowser: true);
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      expect(calls.single.arguments['url'], 'https://source.test/1.html');
      expect(calls.single.arguments['useWebView'], isFalse);
      expect(routes, 0);
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
      if (failed) {
        expect(find.text('无法打开链接：https://source.test/1.html'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final failed in [false, true]) {
    testWidgets('长按选择系统浏览器${failed ? '保存失败提示但仍打开，重试可保存' : '保存成功且后续点击沿用'}', (
      tester,
    ) async {
      final storage = HomeSettingsStorage();
      final service = AppSettingsService(
        storages: {SettingsStorageKind.preferences: storage},
      );
      addTearDown(() => unawaited(service.dispose()));
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final (reader, hits) = await _pumpMenu(
        tester,
        settingsService: service,
        initialState: linkState(
          const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderMenuPanel)),
      );
      final repository = container.read(readerSettingsRepositoryProvider);
      await repository.load();
      storage.writeFailure = failed;
      await tester.longPress(find.text('章节网页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('系统浏览器打开'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.arguments['url'], 'https://source.test/1.html');
      expect(repository.current.chapterInSystemBrowser, !failed);
      if (failed) {
        expect(find.text('打开方式保存失败，本次仍按所选方式打开'), findsOneWidget);
        expect(
          storage.values.containsKey('reader_chapter_in_system_browser'),
          isFalse,
        );
        storage.writeFailure = false;
        await tester.longPress(find.text('章节网页'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('系统浏览器打开'));
        await tester.pumpAndSettle();
        calls.clear();
      }
      expect(storage.values['reader_chapter_in_system_browser'], isTrue);
      await tester.tap(find.text('章节网页'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(failed ? 1 : 2));
      expect(
        storage.writes.map((entry) => entry.$1),
        everyElement('reader_chapter_in_system_browser'),
      );
      expect(reader.value.showControls, isTrue);
      _expectNoBodyEvents(hits);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('长按选择内置浏览器保存偏好，后续点击沿用', (tester) async {
    final storage = HomeSettingsStorage();
    storage.values['reader_chapter_in_system_browser'] = true;
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(() => unawaited(service.dispose()));
    var routes = 0;
    await _pumpMenu(
      tester,
      settingsService: service,
      initialState: linkState(
        const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
      ),
      onGenerateRoute: (settings) {
        expect(settings.name, AppRoutes.browser);
        routes++;
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('内置浏览器测试')),
        );
      },
    );
    await tester.longPress(find.text('章节网页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('内置浏览器打开'));
    await tester.pumpAndSettle();
    expect(routes, 1);
    expect(storage.values['reader_chapter_in_system_browser'], isFalse);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('章节网页'));
    await tester.pumpAndSettle();
    expect(routes, 2);
    expect(storage.writes, [('reader_chapter_in_system_browser', false)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('复制章节链接不修改打开偏好', (tester) async {
    final clipboardWrites = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardWrites.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final storage = HomeSettingsStorage();
    storage.values['reader_chapter_in_system_browser'] = true;
    final service = AppSettingsService(
      storages: {SettingsStorageKind.preferences: storage},
    );
    addTearDown(() => unawaited(service.dispose()));
    await _pumpMenu(
      tester,
      settingsService: service,
      initialState: linkState(
        const BookChapter(title: '章节网页', url: 'https://source.test/1.html'),
      ),
    );
    await tester.longPress(find.text('章节网页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    expect(clipboardWrites, [
      {'text': 'https://source.test/1.html'},
    ]);
    expect(find.text('章节链接已复制'), findsOneWidget);
    expect(storage.writes, isEmpty);
    expect(storage.values['reader_chapter_in_system_browser'], isTrue);
    expect(tester.takeException(), isNull);
  });
}
