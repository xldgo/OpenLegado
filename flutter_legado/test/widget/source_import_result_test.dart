import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_legado/src/app/bootstrap/source_import_factory.dart';
import 'package:flutter_legado/src/data/services/source_import_service.dart';
import 'package:flutter_legado/src/domain/models/import_result.dart';
import 'package:flutter_legado/src/domain/models/source_preview.dart';
import 'package:flutter_legado/src/features/book_sources/book_sources.dart';
import 'package:flutter_legado/src/features/book_sources/widgets/source_import_result.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../fixtures/app_test_api.dart';
import '../mocks/mocks.dart';

class _ImportService extends Mock implements SourceImportService {}

void main() {
  setUpAll(registerFallbacks);
  late MockRustApi api;
  late _ImportService service;
  late ProviderContainer container;
  ImportResult? received;
  var returned = false;

  setUp(() {
    api = MockRustApi();
    service = _ImportService();
    received = null;
    returned = false;
    when(() => api.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        sourceImportServiceProvider.overrideWithValue(service),
      ]),
    );
    addTearDown(container.dispose);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  received = await SourceImportConfirmScreen.open(
                    context,
                    sources: const [
                      SourcePreview(
                        raw: {'bookSourceUrl': 'a', 'bookSourceName': '候选A'},
                        bookSourceUrl: 'a',
                        bookSourceName: '候选A',
                      ),
                      SourcePreview(
                        raw: {'bookSourceUrl': 'b', 'bookSourceName': '候选B'},
                        bookSourceUrl: 'b',
                        bookSourceName: '候选B',
                      ),
                    ],
                    localSources: const [],
                  );
                  returned = true;
                  if (!context.mounted || received == null) return;
                  await showSourceImportResult(
                    context,
                    received!,
                    onRefresh: () async {
                      final notifier = container.read(
                        sourceNotifierProvider.notifier,
                      );
                      await notifier.loadSources();
                      return container.read(sourceNotifierProvider).error;
                    },
                  );
                },
                child: const Text('打开确认页'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开确认页'));
    await tester.pumpAndSettle();
  }

  testWidgets('全部失败和全部跳过都留页保留勾选，取消返回null', (tester) async {
    when(() => service.importFromJson(any())).thenAnswer(
      (_) async => const ImportResult(
        total: 2,
        success: 0,
        failed: 2,
        skipped: 0,
        errors: ['源规则无效夹具'],
      ),
    );
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('源规则无效夹具'), findsOneWidget);
    expect(returned, isFalse);
    expect(container.read(sourceNotifierProvider).lastImportResult?.failed, 2);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((w) => w.value == true),
      isTrue,
    );

    when(() => service.importFromJson(any())).thenAnswer(
      (_) async => const ImportResult(
        total: 2,
        success: 0,
        failed: 0,
        skipped: 2,
        errors: ['必填字段缺失夹具'],
      ),
    );
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.text('必填字段缺失夹具'), findsOneWidget);
    expect(returned, isFalse);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(received, isNull);
  });

  testWidgets('写入成功但刷新失败保留计数，重新加载只读列表不再导入', (tester) async {
    when(() => service.importFromJson(any())).thenAnswer(
      (_) async => const ImportResult(
        total: 2,
        success: 2,
        failed: 0,
        skipped: 0,
        errors: [],
      ),
    );
    when(() => api.bookSourceRepository.getBookSources())
        .thenThrow(StateError('刷新失败夹具'));
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceImportConfirmScreen), findsNothing);
    expect(received?.success, 2);
    expect(received?.errors, isEmpty);
    expect(received?.refreshError, contains('刷新失败夹具'));
    expect(
      container.read(sourceNotifierProvider).lastImportResult,
      same(received),
    );
    expect(find.textContaining('成功 2'), findsOneWidget);
    expect(find.textContaining('列表刷新失败'), findsOneWidget);

    when(() => api.bookSourceRepository.getBookSources()).thenAnswer(
      (_) async => [
        const BookSource(bookSourceUrl: 'saved', bookSourceName: '已写入源'),
      ],
    );
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(
      container.read(sourceNotifierProvider).sources.single.bookSourceName,
      '已写入源',
    );
    expect(container.read(sourceNotifierProvider).error, isNull);
    expect(find.textContaining('列表刷新失败'), findsNothing);
    expect(find.textContaining('成功 2'), findsOneWidget);
    verify(() => service.importFromJson(any())).called(1);
  });
}
