import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/reader/application/reader_settings_provider.dart';
import 'package:flutter_legado/src/providers/reading_content_provider.dart';
import 'package:flutter_legado/src/features/reader/presentation/overlays/reader_config_panel.dart';

import '../fixtures/reader_settings_repository.dart';
import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late MockRustApi api;
  late ReadingContentServiceMock content;
  late ProviderContainer container;
  var reads = 0;
  var converted = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = MockRustApi();
    content = ReadingContentServiceMock();
    reads = 0;
    converted = false;
    when(() => api.readingRepository.getChapters('book')).thenAnswer(
      (_) async => const [BookChapter(bookUrl: 'book', index: 0, title: '第一章')],
    );
    when(() => api.readingRepository.getChapterContentFull('book', 0))
        .thenAnswer((_) async {
          reads++;
          return converted ? '轉換後正文' : '原正文';
        });
    when(() => content.getChineseConvertType()).thenAnswer((_) async => 0);
    when(
      () => api.readingRepository.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: mergeTestOverrides([
        ...api.overrides,
        readingContentServiceProvider.overrideWithValue(content),
        readerSettingsRepositoryProvider.overrideWithValue(
          createTestReaderSettingsRepository(),
        ),
      ]),
    );
    addTearDown(container.dispose);
  });
  Future<void> open(WidgetTester tester) async {
    await container
        .read(readerNotifierProvider.notifier)
        .openBook(const Book(bookUrl: 'book', name: '书', origin: 'source'));
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ReaderConfigPanel(section: ReaderConfigSection.content),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('繁简设置成功后更新选中项并重读正文，仅调用窄服务', (tester) async {
    when(() => content.setChineseConvertType(2)).thenAnswer((_) async {
      converted = true;
    });
    await open(tester);
    expect(reads, 1);
    tester
        .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
        .onSelectionChanged!({2});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .selected,
      {2},
    );
    expect(container.read(readerNotifierProvider).chapterContent, '轉換後正文');
    expect(reads, 2);
    verify(() => content.setChineseConvertType(2)).called(1);
    verifyNever(() => api.readingContentService.setChineseConvertType(any()));
    expect(tester.takeException(), isNull);
  });
  testWidgets('繁简写入失败保留旧选择与正文，不触发重读', (tester) async {
    when(() => content.setChineseConvertType(2)).thenThrow(StateError('无法保存'));
    await open(tester);
    tester
        .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
        .onSelectionChanged!({2});
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .selected,
      {0},
    );
    expect(container.read(readerNotifierProvider).chapterContent, '原正文');
    expect(reads, 1);
    expect(find.textContaining('简繁转换设置失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
