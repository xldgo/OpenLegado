import '../fixtures/app_test_api.dart';
import '../fixtures/bookmark_export_fixture.dart';

import 'package:flutter_legado/src/features/bookmarks/bookmark_export.dart';

import '../mocks/reading_fixture.dart';
import '../mocks/bookshelf_fixture.dart';

import 'package:flutter_legado/src/domain/contracts/bookmark_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/features/bookmarks/bookmarks.dart';
import 'package:flutter_legado/src/features/toc/presentation/toc_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bookmarks extends Mock implements BookmarkRepository {}

class _RootBookmarks extends _Bookmarks {
  @override
  Future<List<Bookmark>> getBookmarksByBook(String name, String author) =>
      throw StateError('书签必须读取注入的窄接口');
}

const _book = Book(
  bookUrl: 'local://book',
  name: '同名书',
  author: '作者甲',
  origin: BookType.localTag,
);
const _bookmark = Bookmark(
  id: 42,
  bookName: '同名书',
  bookAuthor: '作者甲',
  chapterIndex: 0,
  chapterPos: 102,
  chapterName: '精准书签章节',
  bookText: '选区原文',
  content: '备注',
);

/// 目录其他数据走根对象；书签误用根 Repository 时直接报错。— Codex + UI
class _TocApi extends MockBookApi {
  late final _fixtureReading = TestReadingRepository(
    delegate: super.readingRepository,
    getChapters: _readingGetChapters,
  );
  @override
  TestReadingRepository get readingRepository => _fixtureReading;

  late final _fixtureShelf = TestBookshelfRepository(
    delegate: super.bookshelfRepository,
    getBook: _fixtureGetBook,
  );
  @override
  TestBookshelfRepository get bookshelfRepository => _fixtureShelf;

  _TocApi() : super(bookmarkRepository: _RootBookmarks());

  Future<Book?> _fixtureGetBook(String bookUrl) async => _book;

  Future<List<BookChapter>> _readingGetChapters(String bookUrl) async => [
    const BookChapter(url: 'local://chapter', title: '正文章节', index: 0),
  ];
}

void main() {
  late _Bookmarks repository;

  setUpAll(() => registerFallbackValue(const Bookmark()));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Bookmarks();
  });

  testWidgets('书签页只注入窄接口即可加载与删除，不创建 TestApi', (tester) async {
    when(() => repository.getAllBookmarks())
        .thenAnswer((_) async => [_bookmark]);
    when(() => repository.deleteBookmark(42)).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookmarkRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: BookmarkScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('精准书签章节'), findsOneWidget);
    expect(find.text('选区原文'), findsOneWidget);
    await tester.longPress(find.text('精准书签章节'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '删除书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    verify(() => repository.deleteBookmark(42)).called(1);
    expect(find.text('精准书签章节'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录标题搜索交叉淡入且不改变顶栏高度，收起释放焦点', (tester) async {
    when(() => repository.getBookmarksByBook('同名书', '作者甲'))
        .thenAnswer((_) async => [_bookmark]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ..._TocApi().overrides,
          bookmarkRepositoryProvider.overrideWithValue(repository),
        ]),
        child: const MaterialApp(home: TocScreen(book: _book)),
      ),
    );
    await tester.pumpAndSettle();
    final bar = find.byType(AppBar);
    final height = tester.getSize(bar).height;
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    expect(tester.getSize(bar).height, height);
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getSize(bar).height, height);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pump();
    expect(tester.getSize(bar).height, height);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('目录书签按双键查询并通过同一窄接口删除', (tester) async {
    when(() => repository.getBookmarksByBook('同名书', '作者甲'))
        .thenAnswer((_) async => [_bookmark]);
    when(() => repository.deleteBookmark(42)).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ..._TocApi().overrides,
          bookmarkRepositoryProvider.overrideWithValue(repository),
        ]),
        child: const MaterialApp(home: TocScreen(book: _book)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '书签'));
    await tester.pumpAndSettle();
    expect(find.text('精准书签章节'), findsOneWidget);
    verify(() => repository.getBookmarksByBook('同名书', '作者甲')).called(1);
    await tester.longPress(find.text('精准书签章节'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '删除书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    verify(() => repository.deleteBookmark(42)).called(1);
    expect(find.text('精准书签章节'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final fromToc in [false, true]) {
    testWidgets('${fromToc ? '目录' : '书签页'}备注编辑预填，保存并清空只变更 content', (
      tester,
    ) async {
      when(() => repository.getAllBookmarks())
          .thenAnswer((_) async => [_bookmark]);
      when(() => repository.getBookmarksByBook('同名书', '作者甲'))
          .thenAnswer((_) async => [_bookmark]);
      when(() => repository.updateBookmark(any())).thenAnswer((_) async {});
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([
            ..._TocApi().overrides,
            bookmarkRepositoryProvider.overrideWithValue(repository),
          ]),
          child: MaterialApp(
            home: fromToc
                ? const TocScreen(book: _book)
                : const BookmarkScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (fromToc) {
        await tester.tap(find.widgetWithText(Tab, '书签'));
        await tester.pumpAndSettle();
      }
      for (final note in ['新备注', '']) {
        await tester.longPress(find.text('精准书签章节'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MenuItemButton, '编辑备注'));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('bookmark-note'));
        expect(
          tester.widget<TextField>(input).controller!.text,
          note.isEmpty ? '新备注' : '备注',
        );
        await tester.enterText(input, note);
        await tester.tap(find.byTooltip('保存'));
        await tester.pumpAndSettle();
        verify(
          () => repository.updateBookmark(_bookmark.copyWith(content: note)),
        ).called(1);
        expect(find.byKey(const ValueKey('bookmark-note')), findsNothing);
        if (note.isNotEmpty) expect(find.text('备注: 新备注'), findsOneWidget);
      }
      verifyNever(() => repository.addBookmark(any()));
      verifyNever(() => repository.deleteBookmark(any()));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('目录导出重新从窄接口查询，空结果不调用文件插件', (tester) async {
    var queries = 0;
    when(() => repository.getBookmarksByBook('同名书', '作者甲'))
        .thenAnswer((_) async => ++queries == 1 ? [_bookmark] : []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ..._TocApi().overrides,
          bookmarkRepositoryProvider.overrideWithValue(repository),
        ]),
        child: const MaterialApp(home: TocScreen(book: _book)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出 Markdown'));
    await tester.pumpAndSettle();
    verify(() => repository.getBookmarksByBook('同名书', '作者甲')).called(2);
    expect(find.text('暂无书签可导出'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('目录导出按取消、成功和保存失败分别提示', (tester) async {
    when(() => repository.getBookmarksByBook('同名书', '作者甲'))
        .thenAnswer((_) async => [_bookmark]);
    for (final outcome in ['取消', '成功', '失败']) {
      final exporter = RecordingBookmarkExporter();
      final saver = RecordingBookmarkSaver()
        ..result = outcome == '成功' ? '/saved/bookmark.md' : null
        ..error = outcome == '失败' ? StateError('磁盘写入失败') : null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: mergeTestOverrides([
            ..._TocApi().overrides,
            bookmarkRepositoryProvider.overrideWithValue(repository),
            bookmarkExportProvider.overrideWithValue(
              BookmarkExport(exporter: exporter, saver: saver),
            ),
          ]),
          child: const MaterialApp(home: TocScreen(book: _book)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, '书签'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导出 Markdown'));
      await tester.pumpAndSettle();
      expect(saver.calls, 1);
      if (outcome == '成功') {
        expect(find.text('导出成功: /saved/bookmark.md'), findsOneWidget);
      } else if (outcome == '失败') {
        expect(find.textContaining('导出失败:'), findsOneWidget);
        expect(find.textContaining('磁盘写入失败'), findsOneWidget);
      } else {
        expect(find.textContaining('导出成功:'), findsNothing);
        expect(find.textContaining('导出失败:'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
