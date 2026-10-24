import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/models/book_source.dart';
import 'package:flutter_legado/src/theme/app_theme.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

void main() {
  late MockRustApi api;
  late List<BookSource> stored;

  setUpAll(registerFallbacks);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    stored = const [
      BookSource(bookSourceUrl: 'a', bookSourceName: '甲源', customOrder: 0),
      BookSource(bookSourceUrl: 'b', bookSourceName: '乙源', customOrder: 1),
      BookSource(bookSourceUrl: 'c', bookSourceName: '丙源', customOrder: 2),
    ];
    when(() => api.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => List.of(stored));
    when(() => api.bookSourceRepository.updateBookSource(any()))
        .thenAnswer((call) async {
          final updated = call.positionalArguments.single as BookSource;
          stored = [
            for (final source in stored)
              if (source.bookSourceUrl == updated.bookSourceUrl)
                updated
              else
                source,
          ];
        });
  });

  Future<ProviderContainer> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: MaterialApp(theme: AppTheme.light, home: const SourceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SourceScreen)));
  }

  testWidgets('长按卡片进入多选，退出后点击同一卡片进入编辑', (tester) async {
    final container = await open(tester);
    expect(find.byType(Checkbox), findsNothing);

    await tester.longPress(find.text('甲源'));
    await tester.pumpAndSettle();
    expect(container.read(sourceNotifierProvider).selectedUrls, {'a'});
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.byType(SourceEditScreen), findsNothing);
    verifyNever(() => api.bookSourceRepository.updateBookSource(any()));

    await tester.tap(find.text('乙源'));
    await tester.pumpAndSettle();
    expect(container.read(sourceNotifierProvider).selectedUrls, {'a', 'b'});
    await tester.tap(find.byTooltip('退出选择模式'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('甲源'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SourceEditScreen>(find.byType(SourceEditScreen)).sourceUrl,
      'a',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手柄拖动保存顺序，不触发多选或编辑', (tester) async {
    final container = await open(tester);
    final handle = find.byType(ReorderableDragStartListener).first;
    final lastCard = find.ancestor(
      of: find.text('丙源'),
      matching: find.byType(Card),
    );
    final start = tester.getCenter(handle);
    final destination =
        tester.getBottomLeft(lastCard).dy + tester.getSize(lastCard).height / 2;
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(0, tester.getSize(handle).height));
    await tester.pump();
    await gesture.moveTo(Offset(start.dx, destination));
    await tester.pump(const Duration(milliseconds: 300));
    // 列表换位后继续发送拖动事件，再松手提交最终落点。
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await container.read(sourceNotifierProvider.notifier).loadSources();
    await tester.pumpAndSettle();
    expect(
      container
          .read(sourceNotifierProvider)
          .filteredSources
          .map((s) => s.bookSourceUrl),
      ['b', 'c', 'a'],
    );
    expect(container.read(sourceNotifierProvider).batchMode, isFalse);
    expect(find.byType(SourceEditScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('按名称排序时手柄不修改顺序，长按仍可选择', (tester) async {
    final container = await open(tester);
    container.read(sourceNotifierProvider.notifier).setSort(SourceSort.name);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(ReorderableDragStartListener).first,
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    verifyNever(() => api.bookSourceRepository.updateBookSource(any()));
    await tester.longPress(find.text('甲源'));
    await tester.pumpAndSettle();
    expect(container.read(sourceNotifierProvider).selectedUrls, {'a'});
    expect(tester.takeException(), isNull);
  });
}
