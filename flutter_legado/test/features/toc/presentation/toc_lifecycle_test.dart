import '../../../fixtures/routing_test_app.dart';
import '../../../fixtures/app_test_api.dart';
import '../../../mocks/mocks.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/toc/presentation/toc_screen.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/utils/app_route_observer.dart';

void main() {
  setUpAll(registerFallbacks);
  testWidgets('目录离开后暂停轮询，返回后恢复，销毁后停止', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    const book = Book(bookUrl: 'b', name: '测试', author: '作者', origin: 'source');
    when(() => api.bookshelfRepository.getBook('b'))
        .thenAnswer((_) async => book);
    when(() => api.readingRepository.getChapters('b'))
        .thenAnswer((_) async => [const BookChapter(index: 0, title: '第一章')]);
    when(() => api.chapterCacheRepository.listCachedChapterUrls('b'))
        .thenAnswer((_) async => []);
    var polls = 0;
    when(() => api.chapterCacheRepository.listCachedChapters('b'))
        .thenAnswer((_) async {
          polls++;
          return {};
        });
    when(() => api.cacheDownloadService.listDownloadingChapters('b'))
        .thenAnswer((_) async => []);
    when(() => api.cacheDownloadService.listFailedChapters('b'))
        .thenAnswer((_) async => []);
    when(() => api.highlightRepository.highlightListByBook(bookUrl: 'b'))
        .thenAnswer((_) async => []);
    when(() => api.bookmarkRepository.getBookmarksByBook('测试', '作者'))
        .thenAnswer((_) async => []);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: RoutingTestApp(
          navigatorKey: navigator,
          navigatorObservers: [appRouteObserver],
          home: const TocScreen(book: book),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(polls, 1);
    navigator.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('另一页'))),
    );
    await tester.pumpAndSettle();
    final before = polls;
    await tester.pump(const Duration(seconds: 3));
    expect(polls, before);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(polls, before + 1);
    await tester.pumpWidget(const SizedBox.shrink());
    final disposed = polls;
    await tester.pump(const Duration(seconds: 2));
    expect(polls, disposed);
    expect(tester.takeException(), isNull);
  });
  testWidgets('真实目录页过滤和倒序后返回章节实体索引', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = MockRustApi();
    const book = Book(
      bookUrl: 'b',
      name: '测试',
      author: '作者',
      origin: BookType.localTag,
    );
    when(() => api.bookshelfRepository.getBook('b'))
        .thenAnswer((_) async => book);
    when(() => api.readingRepository.getChapters('b')).thenAnswer(
      (_) async => [
        const BookChapter(index: 5, title: '卷一', isVolume: true),
        const BookChapter(index: 12, title: 'Chapter One'),
        const BookChapter(index: 18, title: 'Chapter Two'),
      ],
    );
    when(() => api.highlightRepository.highlightListByBook(bookUrl: 'b'))
        .thenAnswer((_) async => []);
    when(() => api.bookmarkRepository.getBookmarksByBook('测试', '作者'))
        .thenAnswer((_) async => []);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...api.overrides]),
        child: RoutingTestApp(
          navigatorKey: navigator,
          navigatorObservers: [appRouteObserver],
          home: const Scaffold(body: Text('入口')),
        ),
      ),
    );
    final result = navigator.currentState!.push<int>(
      MaterialPageRoute(builder: (_) => const TocScreen(book: book)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('倒序目录'));
    await tester.pumpAndSettle();
    final titles = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList();
    expect(titles, ['Chapter Two', 'Chapter One']);
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' ONE ');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Chapter Two'), findsNothing);
    expect(find.text('Chapter One'), findsOneWidget);
    await tester.tap(find.text('Chapter One'));
    await tester.pumpAndSettle();
    expect(await result, 12);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
