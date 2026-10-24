import '../fixtures/app_test_api.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/features/rss/presentation/rss_source_manage_screen.dart';
import 'package:flutter_legado/src/widgets/ui_settings_scope.dart';
import 'package:flutter_legado/src/domain/models/ui_settings.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 360.0, 480.0]) {
    testWidgets('书源大标题在合并按钮和窄屏$width下可读且随列表折叠', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = MockRustApi();
      when(() => api.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => List.generate(
          60,
          (index) => BookSource(
            bookSourceUrl: 'source-$index',
            bookSourceName: '书源$index',
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([...api.overrides]),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UiSettingsScope(
                        settings: UiSettings(mergeTopBarActions: true),
                        child: SourceScreen(),
                      ),
                    ),
                  ),
                  child: const Text('管理书源'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('管理书源'));
      await tester.pumpAndSettle();
      final titles = find.text('书源管理');
      expect(titles, findsWidgets);
      final typography = Theme.of(tester.element(find.byType(SourceScreen)))
          .textTheme;
      expect(
        titles.evaluate().map(
          (element) => DefaultTextStyle.of(element).style.fontSize,
        ),
        containsAll([
          typography.headlineMedium!.fontSize,
          typography.titleLarge!.fontSize,
        ]),
      );
      for (final element in titles.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          ),
          isNotEmpty,
        );
      }
      final nested = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      expect(nested.outerController.offset, 0);
      // 搜索行只改变自身高度，展开标题在动画前中后都不能位移。— Codex + UI
      final expandedTitle = find
          .descendant(of: find.byType(AppBar), matching: find.text('书源管理'))
          .first;
      final titleBeforeSearch = tester.getRect(expandedTitle);
      final headerBeforeSearch = tester.getSize(find.byType(AppBar)).height;
      await tester.tap(find.byTooltip('展开搜索'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(expandedTitle), titleBeforeSearch);
      await tester.pumpAndSettle();
      expect(tester.getRect(expandedTitle), titleBeforeSearch);
      expect(
        tester.getSize(find.byType(AppBar)).height,
        closeTo(headerBeforeSearch + 64, 0.01),
      );
      await tester.tap(find.byTooltip('收起搜索'));
      await tester.pumpAndSettle();
      expect(tester.getRect(expandedTitle), titleBeforeSearch);
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(nested.outerController.offset, greaterThan(0));
      expect(nested.innerController.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }
  for (final rss in [false, true]) {
    testWidgets('${rss ? '订阅源管理' : '书源管理'}默认隐藏、搜索筛选及清除恢复', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = MockRustApi();
      when(() => api.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => [
          const BookSource(bookSourceUrl: 'a', bookSourceName: '甲源'),
          const BookSource(
            bookSourceUrl: 'b',
            bookSourceName: '乙源',
            enabled: false,
          ),
        ],
      );
      when(() => api.rssSourceRepository.getRssSources()).thenAnswer(
        (_) async => [
          const RssSource(sourceUrl: 'a', sourceName: '甲源'),
          const RssSource(sourceUrl: 'b', sourceName: '乙源', enabled: false),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([...api.overrides]),
          child: MaterialApp(
            home: rss ? const RssSourceManageScreen() : const SourceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('甲源'), findsOneWidget);
      expect(find.text('乙源'), findsOneWidget);
      await tester.tap(find.byTooltip('展开搜索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '甲源');
      await tester.pumpAndSettle();
      expect(find.text('乙源'), findsNothing);
      await tester.tap(find.byTooltip('收起搜索'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('展开搜索'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '甲源',
      );
      await tester.tap(find.byTooltip('清除搜索关键词'));
      await tester.pumpAndSettle();
      expect(find.text('乙源'), findsOneWidget);
      // 两个领域使用不同筛选值，共用菜单仍须调用各自的筛选与清除逻辑。
      await tester.tap(find.byTooltip('分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, '已禁用'));
      await tester.pumpAndSettle();
      expect(find.text('甲源'), findsNothing);
      expect(find.text('乙源'), findsOneWidget);
      await tester.tap(find.byTooltip('分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, '已禁用'));
      await tester.pumpAndSettle();
      expect(find.text('甲源'), findsOneWidget);
      if (!rss) {
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(SourceScreen)),
        );
        scope.read(sourceNotifierProvider.notifier).toggleSelection('a');
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.byTooltip('收起搜索'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(scope.read(sourceNotifierProvider).batchMode, isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
