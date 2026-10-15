import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/screens/rss_source_manage_screen.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final rss in [false, true]) {
    testWidgets('${rss ? '订阅源管理' : '书源管理'}默认隐藏、搜索筛选及清除恢复', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = MockRustApi();
      when(() => api.bookSourceRepository.getBookSources()).thenAnswer(
        (_) async => [
          const BookSource(bookSourceUrl: 'a', bookSourceName: '甲源'),
          const BookSource(bookSourceUrl: 'b', bookSourceName: '乙源'),
        ],
      );
      when(() => api.rssSourceRepository.getRssSources()).thenAnswer(
        (_) async => [
          const RssSource(sourceUrl: 'a', sourceName: '甲源'),
          const RssSource(sourceUrl: 'b', sourceName: '乙源'),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookApiProvider.overrideWithValue(api)],
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
