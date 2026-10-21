import 'package:flutter_legado/src/providers/ui_settings/ui_settings_notifier.dart';
import 'package:flutter_legado/src/widgets/app_surface_backdrop.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/domain/models/source_action_result.dart';
import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_menu_controls.dart';
import 'package:flutter_legado/src/l10n/app_localization.dart';

import '../fixtures/routing_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../mocks/mocks.dart';

/// 阅读器子组件 Widget 测试
///
/// 验证阅读菜单及其操作在 Riverpod 架构下忠实渲染，
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
      overrides: mergeTestOverrides([...mockApi.overrides]),
    );
    addTearDown(container.dispose);
  });

  /// 配置 openBook 所需的完整 mock 链
  void stubOpenBook({String content = '章节内容'}) {
    when(() => mockApi.readingRepository.getChapters(any()))
        .thenAnswer((_) async => testChapters);
    when(() => mockApi.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((_) async => content);
    when(
      () => mockApi.readingRepository.updateReadingProgress(
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
      child: RoutingTestApp(
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
      expect(find.byTooltip('更多'), findsOneWidget);
      // 初始无书籍时进度为 0.0%
      expect(find.byType(ReaderMenuProgressSlider), findsOneWidget);
    });

    testWidgets('菜单上下栏使用独立玻璃底色，模糊总开关不改变材质', (tester) async {
      final settings = container.read(uiSettingsProvider.notifier);
      await settings.load();
      await settings.setTopBarBlurTintOpacity(0.25);
      await settings.setBottomBarBlurTintOpacity(0.5);
      await tester.pumpWidget(wrapStack(buildReaderMenu(onAddBookmark: () {})));
      await tester.pumpAndSettle();
      List<AppSurfaceBackdrop> surfaces() => tester
          .widgetList<AppSurfaceBackdrop>(find.byType(AppSurfaceBackdrop))
          .toList();
      expect(surfaces().first.material.color.a, 0.25);
      expect(surfaces().last.material.color.a, 0.5);
      expect(find.byType(BackdropFilter), findsWidgets);
      await settings.setEnableBlur(true);
      await tester.pumpAndSettle();
      expect(surfaces().first.material.color.a, closeTo(0.25, 1e-6));
      expect(surfaces().last.material.color.a, closeTo(0.5, 1e-6));
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edge-to-edge 下顶栏内容避让 viewPadding.top', (tester) async {
      const statusBarHeight = 48.0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RoutingTestApp(
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

      final prevButton = tester.widget<ReaderMenuControlButton>(
        find.byWidgetPredicate(
          (w) => w is ReaderMenuControlButton && w.label == '上一章',
        ),
      );
      final nextButton = tester.widget<ReaderMenuControlButton>(
        find.byWidgetPredicate(
          (w) => w is ReaderMenuControlButton && w.label == '下一章',
        ),
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
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(ReaderMenuProgressSlider), findsOneWidget);
      await tester.tap(find.byIcon(Icons.brightness_auto));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(ReaderMenuProgressSlider), findsOneWidget);
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
        () => mockApi.sourceActionService.chapterPayAction(
          bookUrl: any(named: 'bookUrl'),
          chapterIndex: any(named: 'chapterIndex'),
        ),
      );
    });

    testWidgets('购买成功重读当前章，结果仍属于原书籍与章节', (tester) async {
      await openSourceMenu(
        tester,
        const BookSource(
          bookSourceUrl: 'https://source.com',
          bookSourceName: '测试源',
          ruleContent: ContentRule(payAction: 'true'),
        ),
      );
      when(
        () => mockApi.sourceActionService.chapterPayAction(
          bookUrl: testBook.bookUrl,
          chapterIndex: 0,
        ),
      ).thenAnswer(
        (_) async => const ChapterPurchaseResult(
          kind: ChapterPurchaseKind.success,
          value: 'true',
        ),
      );
      when(
        () => mockApi.readingRepository.getChapterContentFull(
          testBook.bookUrl,
          0,
        ),
      ).thenAnswer((_) async => '已购买正文');
      await tester.tap(find.text('章节购买'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(container.read(readerNotifierProvider).chapterContent, '已购买正文');
      expect(find.text('购买成功'), findsOneWidget);
      verify(
        () => mockApi.sourceActionService.chapterPayAction(
          bookUrl: testBook.bookUrl,
          chapterIndex: 0,
        ),
      ).called(1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    for (final fail in [false, true]) {
      testWidgets(fail ? '购买异常保留正文并提示失败' : '无明确购买结果保留正文且不显示成功', (tester) async {
        await openSourceMenu(
          tester,
          const BookSource(
            bookSourceUrl: 'https://source.com',
            bookSourceName: '测试源',
            ruleContent: ContentRule(payAction: 'true'),
          ),
        );
        final call = when(
          () => mockApi.sourceActionService.chapterPayAction(
            bookUrl: testBook.bookUrl,
            chapterIndex: 0,
          ),
        );
        if (fail) {
          call.thenThrow(StateError('购买被拒绝'));
        } else {
          call.thenAnswer(
            (_) async => const ChapterPurchaseResult(
              kind: ChapterPurchaseKind.none,
              value: '',
            ),
          );
        }
        await tester.tap(find.text('章节购买'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(container.read(readerNotifierProvider).chapterContent, '章节内容');
        verify(
          () => mockApi.readingRepository.getChapterContentFull(
            testBook.bookUrl,
            0,
          ),
        ).called(1);
        expect(find.text('购买成功'), findsNothing);
        if (fail) expect(find.textContaining('章节购买失败'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('章级重复标题处理', () {
    for (final fail in [false, true]) {
      testWidgets(fail ? '章级开关失败不重读正文或显示成功' : '章级去重写入成功后重读，使用当前章稳定身份', (
        tester,
      ) async {
        stubOpenBook();
        when(
          () => mockApi.readingContentService.getSameTitleRemoved(
            testBook.bookUrl,
            0,
          ),
        ).thenAnswer((_) async => true);
        final write = when(
          () => mockApi.readingContentService.toggleSameTitleRemoved(
            testBook.bookUrl,
            0,
            false,
          ),
        );
        if (fail) {
          write.thenThrow(StateError('无法写入'));
        } else {
          write.thenAnswer((_) async {});
        }
        await container
            .read(readerNotifierProvider.notifier)
            .openBook(testBook);
        await tester.pumpWidget(wrapStack(buildReaderMenu()));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('更多'));
        await tester.pumpAndSettle();
        final label = tester
            .element(find.byTooltip('更多'))
            .l10n
            .readerRemoveDuplicateTitle;
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        verify(
          () => mockApi.readingContentService.toggleSameTitleRemoved(
            testBook.bookUrl,
            0,
            false,
          ),
        ).called(1);
        verify(
          () => mockApi.readingRepository.getChapterContentFull(
            testBook.bookUrl,
            0,
          ),
        ).called(fail ? 1 : 2);
        if (fail) {
          expect(find.textContaining('设置失败'), findsOneWidget);
          expect(find.text('该章已保留原标题'), findsNothing);
        } else {
          expect(find.text('该章已保留原标题'), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
