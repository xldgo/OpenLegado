import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/change_source/source_switch_dependencies.dart';
import 'package:flutter_legado/src/features/reader/widgets/change_chapter_source_sheet.dart';

import '../mocks/mocks.dart';

void main() {
  testWidgets('单章换源用类型化候选查询目标目录，不执行整书换源', (tester) async {
    final api = MockRustApi();
    final service = SourceSwitchServiceMock();
    when(() => service.searchSource('书', '作者')).thenAnswer(
      (_) async => [
        const SourceMatch(
          sourceUrl: 's',
          sourceName: '候选源',
          bookUrl: 'page',
          score: 90,
        ),
        const SourceMatch(sourceUrl: 's', bookUrl: ''),
      ],
    );
    when(() => api.readingRepository.refreshToc('page', 's')).thenAnswer(
      (_) async => [const BookChapter(index: 2, url: 'chapter', title: '替代章节')],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          sourceSwitchServiceProvider.overrideWithValue(service),
        ]),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showChangeChapterSourceSheet(
                  context,
                  bookUrl: 'stable',
                  bookName: '书',
                  author: '作者',
                  chapterIndex: 2,
                  chapterTitle: '原章节',
                ),
                child: const Text('换本章'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('换本章'));
    await tester.pumpAndSettle();
    expect(find.text('候选源'), findsOneWidget);
    expect(find.text('s'), findsNothing);
    await tester.tap(find.text('候选源'));
    await tester.pumpAndSettle();
    expect(find.text('替代章节'), findsOneWidget);
    verify(() => service.searchSource('书', '作者')).called(1);
    verify(() => api.readingRepository.refreshToc('page', 's')).called(1);
    verifyNoMoreInteractions(service);
    expect(tester.takeException(), isNull);
  });
}
