import 'package:flutter_legado/src/providers/reader/reader_settings_provider.dart';
import 'package:flutter_legado/src/domain/models/reader_status_strip_settings.dart';
import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_legado/src/widgets/reader/reader_status_strip.dart';

import '../mocks/mocks.dart';

/// 阅读器子组件 Widget 测试
///
/// 验证 Phase 2.2 拆分出的真实组件（ReaderMenuPanel /
/// ReaderStatusStrip）在 Riverpod 架构下忠实渲染，
/// 对齐重构前的界面样式（Phase 2.5 工具栏 + Phase 2.6 书签/进度跳转）。
/// [UI-fix v2.0.4 | 2026-08-08] 对齐原版 ReadMenu：目录抽屉已删除
/// （改独立目录页 TocScreen，测试组同步移除）；搜索/夜间按钮自顶栏
/// 迁至底栏悬浮按钮行，断言同步迁移 — Qoder
void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;

  const testBook = Book(
    bookUrl: 'https://book.com/1',
    name: '测试书籍',
    author: '作者',
    origin: 'https://source.com',
    durChapterIndex: 0,
  );

  final testChapters = [
    const BookChapter(title: '第一章', index: 0),
    const BookChapter(title: '第二章', index: 1),
    const BookChapter(title: '第三章', index: 2),
  ];

  setUpAll(() {
    registerFallbacks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);
  });

  /// 配置 openBook 所需的完整 mock 链
  void stubOpenBook({String content = '章节内容'}) {
    when(() => mockApi.getChapters(any()))
        .thenAnswer((_) async => testChapters);
    when(() => mockApi.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => content);
    when(
      () => mockApi.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
  }

  /// 将 Positioned 类组件包裹于 Stack（MenuPanel/StatusStrip 需要）
  Widget wrapStack(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: Stack(children: [child])),
      ),
    );
  }

  Future<void> openBookAndPump(WidgetTester tester) async {
    await container.read(readerNotifierProvider.notifier).openBook(testBook);
    await tester.pump();
  }

  group('ReaderMenuPanel 顶栏', () {
    // [UI-fix v2.0.4 | 2026-08-08] 顶栏对齐原版 ReadMenu：搜索/书签/高级
    // 设置常驻图标已迁出（书签→溢出菜单，搜索→底栏悬浮按钮），
    // 断言改为返回/溢出菜单/初始进度 — Qoder
    testWidgets('渲染返回/溢出菜单按钮与初始进度', (tester) async {
      await tester.pumpWidget(wrapStack(buildReaderMenu(onAddBookmark: () {})));
      await tester.pump();

      expect(find.byIcon(Symbols.arrow_back_rounded), findsOneWidget);
      expect(find.byType(AppMenuButton<String>), findsOneWidget);
      // 初始无书籍时进度为 0.0%
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('edge-to-edge 下顶栏内容避让 viewPadding.top', (tester) async {
      const statusBarHeight = 48.0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.only(top: statusBarHeight),
              ),
              child: Scaffold(
                body: Stack(children: [buildReaderMenu(onAddBookmark: () {})]),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getTopLeft(find.byIcon(Symbols.arrow_back_rounded)).dy,
        greaterThanOrEqualTo(statusBarHeight),
      );
    });

    testWidgets('打开书籍后显示书名', (tester) async {
      stubOpenBook();
      await tester.pumpWidget(wrapStack(buildReaderMenu(onAddBookmark: () {})));
      await tester.pump();

      await openBookAndPump(tester);

      // [UI-fix v2.0.3 | 2026-08-08] showReadTitleAddition 默认开启（对标
      // 原版）：顶栏标题为「书名 · 章名」，断言包含书名即可 — Qoder
      expect(find.textContaining('测试书籍'), findsWidgets);
    });
  });

  group('ReaderMenuPanel 章节导航与操作', () {
    testWidgets('点击搜索按钮触发回调', (tester) async {
      var searchTapped = false;
      await tester.pumpWidget(
        wrapStack(
          buildReaderMenu(
            onOpenCatalog: () {},
            onOpenSettings: () {},

            onOpenContentSearch: () => searchTapped = true,
            onReadAloud: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pump();

      expect(searchTapped, isTrue);
    });

    testWidgets('打开书籍后点击目录按钮触发回调', (tester) async {
      stubOpenBook();
      var catalogTapped = false;
      await tester.pumpWidget(
        wrapStack(
          buildReaderMenu(
            onOpenCatalog: () => catalogTapped = true,
            onOpenSettings: () {},

            onOpenContentSearch: () {},
            onReadAloud: () {},
          ),
        ),
      );
      await tester.pump();
      await openBookAndPump(tester);

      await tester.tap(find.byIcon(Symbols.format_list_bulleted_rounded));
      await tester.pump();

      expect(catalogTapped, isTrue);
    });

    testWidgets('第一章时上一章按钮禁用，下一章按钮可用', (tester) async {
      stubOpenBook();
      await tester.pumpWidget(
        wrapStack(
          buildReaderMenu(
            onOpenCatalog: () {},
            onOpenSettings: () {},

            onOpenContentSearch: () {},
            onReadAloud: () {},
          ),
        ),
      );
      await tester.pump();
      await openBookAndPump(tester);

      final prevButton = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '上一章'),
      );
      final nextButton = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '下一章'),
      );
      expect(prevButton.onPressed, isNull);
      expect(nextButton.onPressed, isNotNull);
    });

    // 既有亮度行用例改用共用插件，验证跟随系统切换为手动亮度。
    testWidgets('亮度行从跟随系统切换为手动调节', (tester) async {
      const channel = MethodChannel('github.com/aaassseee/screen_brightness');
      const eventChannel = MethodChannel(
        'github.com/aaassseee/screen_brightness/application_brightness_changed',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var changed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getApplicationScreenBrightness':
            return 0.5;
          case 'hasApplicationScreenBrightnessChanged':
            return changed;
          case 'setApplicationScreenBrightness':
            changed = true;
            return null;
          case 'resetApplicationScreenBrightness':
            changed = false;
            return null;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(eventChannel, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(eventChannel, null);
      });
      await container.read(readerSettingsRepositoryProvider).load();
      await container
          .read(readerSettingsRepositoryProvider)
          .updateBrightnessControl(mode: 1);
      await tester.pumpWidget(
        wrapStack(
          buildReaderMenu(
            onOpenCatalog: () {},
            onOpenSettings: () {},

            onOpenContentSearch: () {},
            onReadAloud: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.brightness_auto));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
    });
  });

  group('书源菜单接线', () {
    Future<void> openSourceMenu(WidgetTester tester, BookSource source) async {
      stubOpenBook();
      when(() => mockApi.bookSourceRepository.getBookSources())
          .thenAnswer((_) async => [source]);
      await container
          .read(readerNotifierProvider.notifier)
          .openBook(testBook.copyWith(originName: '测试源'));
      await tester.pumpWidget(wrapStack(buildReaderMenu()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试源'));
      await tester.pumpAndSettle();
    }

    testWidgets('缺少登录和购买配置时只显示编辑与禁用', (tester) async {
      await openSourceMenu(
        tester,
        const BookSource(
          bookSourceUrl: 'https://source.com',
          bookSourceName: '测试源',
        ),
      );
      expect(find.text('登录源'), findsNothing);
      expect(find.text('章节购买'), findsNothing);
      expect(find.text('编辑源'), findsOneWidget);
      expect(find.text('禁用源'), findsOneWidget);
    });

    testWidgets('取消购买不执行书源购买动作', (tester) async {
      await openSourceMenu(
        tester,
        const BookSource(
          bookSourceUrl: 'https://source.com',
          bookSourceName: '测试源',
          loginUrl: 'https://source.com/login',
          ruleContent: ContentRule(payAction: 'true'),
        ),
      );
      expect(find.text('登录源'), findsOneWidget);
      await tester.tap(find.text('章节购买'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      verifyNever(
        () => mockApi.chapterPayAction(
          bookUrl: any(named: 'bookUrl'),
          chapterIndex: any(named: 'chapterIndex'),
        ),
      );
    });
  });

  group('ReaderStatusStrip（Phase 2.4/2.6 状态栏）', () {
    // [PARITY C2 R4] 状态行四开关默认关闭（参考无顶状态行）：默认配置不渲染内容，
    // 电量/进度等改为「开启开关才渲染」。
    testWidgets('默认配置（全关）不渲染内容', (tester) async {
      await tester.pumpWidget(
        wrapStack(ReaderStatusStrip(settings: ReaderStatusStripSettings())),
      );
      await tester.pump();

      expect(find.byIcon(Icons.battery_std), findsNothing);
    });

    testWidgets('开启电量+进度开关时渲染电量图标与进度', (tester) async {
      const config = ReaderStatusStripSettings(
        showBattery: true,
        showProgress: true,
      );
      await tester.pumpWidget(wrapStack(ReaderStatusStrip(settings: config)));
      await tester.pump();

      expect(find.byIcon(Icons.battery_std), findsOneWidget);
      expect(find.text('0.0%'), findsOneWidget);
    });
  });
}
