import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/reader_menu_theme_settings.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/bookmarks/bookmarks.dart';
import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_toolbar.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_actions.dart';
import 'package:flutter_legado/src/widgets/reader/reader_selection_menu_config.dart';
import 'package:flutter_legado/src/widgets/reader/reader_menu_theme.dart';

class _Reader extends ReaderNotifier {
  @override
  ReaderState build() => const ReaderState(
    currentBook: Book(bookUrl: 'test://book', name: '测试小说', author: '测试作者'),
    chapters: [BookChapter(url: 'test://chapter', title: '测试章节', index: 0)],
    chapterContent: '前缀实际选区后缀',
  );
}

class _Bookmarks extends Mock implements BookmarkRepository {}

Future<void> _showToolbar(
  WidgetTester tester,
  MockBookApi api, {
  BookmarkRepository? bookmarks,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: mergeTestOverrides([
        ...api.overrides,
        readerNotifierProvider.overrideWith(_Reader.new),
        if (bookmarks != null)
          bookmarkRepositoryProvider.overrideWithValue(bookmarks),
      ]),
      child: MaterialApp(
        builder: (_, child) => Overlay.wrap(child: child!),
        home: Scaffold(
          body: ReaderMenuThemeHost(
            config: const ReaderMenuThemeSettings(mode: 1),
            readingBackground: const Color(0xFFF5EEDB),
            builder: (context) => TextButton(
              onPressed: () => ReaderSelectionToolbar.show(
                context,
                anchor: const Offset(200, 200),
                text: '实际选区',
                chapterPos: 102,
              ),
              child: const Text('打开选区'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开选区'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(const Bookmark()));
  setUp(
    () => SharedPreferences.setMockInitialValues({
      ReaderSelectionMenuConfig.storageKey: ReaderSelectionMenuConfig(
        expanded: true,
      ).encode(),
    }),
  );
  testWidgets('书签保存精准选区的原文和全局起始偏移', (tester) async {
    final api = MockBookApi();
    final bookmarks = _Bookmarks();
    when(() => bookmarks.addBookmark(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.single as Bookmark,
    );
    await _showToolbar(tester, api, bookmarks: bookmarks);
    final menuTheme = Theme.of(
      tester.element(find.byType(ReaderSelectionToolbar)),
    );
    expect(
      menuTheme.colorScheme,
      isNot(Theme.of(tester.element(find.text('打开选区'))).colorScheme),
    );
    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();
    verifyNever(() => bookmarks.addBookmark(any()));
    expect(find.byType(ReaderSelectionToolbar), findsNothing);
    expect(find.byType(BookmarkNoteSheet), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(BookmarkNoteSheet))).colorScheme,
      menuTheme.colorScheme,
    );
    final note = find.byKey(const ValueKey('bookmark-note'));
    expect(tester.widget<TextField>(note).controller!.text, '');
    await tester.enterText(note, '选区备注');
    await tester.tap(find.byKey(const ValueKey('bookmark-note-save')));
    await tester.pumpAndSettle();
    final saved =
        verify(() => bookmarks.addBookmark(captureAny())).captured.single
            as Bookmark;
    expect(saved.chapterPos, 102);
    expect(saved.bookText, '实际选区');
    expect(saved.content, '选区备注');
    expect(saved.bookName, '测试小说');
    expect(saved.bookAuthor, '测试作者');
    expect(await api.bookmarkRepository.getAllBookmarks(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选区新增取消不写入，直接保存时原文和空备注分离', (tester) async {
    final api = MockBookApi();
    final bookmarks = _Bookmarks();
    when(() => bookmarks.addBookmark(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.single as Bookmark,
    );
    await _showToolbar(tester, api, bookmarks: bookmarks);
    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    verifyNever(() => bookmarks.addBookmark(any()));
    expect(find.byType(BookmarkNoteSheet), findsNothing);

    await tester.tap(find.text('打开选区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bookmark-note-save')));
    await tester.pumpAndSettle();
    final saved =
        verify(() => bookmarks.addBookmark(captureAny())).captured.single
            as Bookmark;
    expect(saved.bookText, '实际选区');
    expect(saved.content, '');
    expect(saved.chapterPos, 102);
    expect(tester.takeException(), isNull);
  });

  testWidgets('高亮使用打开笔记时的选区，焦点变化不会改成整段', (tester) async {
    final api = MockBookApi();
    await _showToolbar(tester, api);
    final menuTheme = Theme.of(
      tester.element(find.byType(ReaderSelectionToolbar)),
    );
    await tester.tap(find.text('高亮'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('高亮'))).colorScheme,
      menuTheme.colorScheme,
    );
    await tester.pumpAndSettle();
    final color = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == kHighlightColors.first,
    );
    await tester.tap(color.first);
    await tester.pumpAndSettle();
    // 高亮对话框已关闭浮窗，保存仍使用进入动作时的原文快照。
    expect(find.byType(ReaderSelectionToolbar), findsNothing);
    await tester.enterText(find.byType(TextField), '选区笔记');
    await tester.tap(find.text('保存高亮'));
    await tester.pumpAndSettle();
    final saved = (await api.highlightRepository.highlightListAll()).single;
    expect(saved.chapterPos, 102);
    expect(saved.chapterPosEnd, 106);
    expect(saved.bookText, '实际选区');
    expect(saved.note, '选区笔记');
    expect(saved.layoutTitleLength, 0);
    expect(tester.takeException(), isNull);
  });
}
