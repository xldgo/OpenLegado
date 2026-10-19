import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/domain/contracts/bookshelf_repository.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/app/routing/reader_route_entry.dart';
import 'package:flutter_legado/src/app/routing/app_navigation.dart';
import 'package:flutter_legado/src/app/routing/route_arguments.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/reader/application/reader_notifier.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf_repositories.dart';
import 'package:flutter_legado/src/models/models.dart';

import '../../mocks/mocks.dart';

class _Repository extends Mock implements BookshelfRepository {}

class _Reader extends ReaderNotifier {
  int opens = 0;
  void showBook(Book book) => state = state.copyWith(currentBook: book);
  @override
  ReaderState build() => const ReaderState();
  @override
  Future<void> openBook(Book book) async {
    opens++;
    state = state.copyWith(currentBook: book);
  }
}

class _Privacy extends PrivacyController {
  _Privacy(this.book, {this.locked = false});
  final Book book;
  final bool locked;
  void allow(Book book) => state = PrivacyState(
    loading: false,
    settings: const PrivacySettings(enabled: true),
    books: [book],
    unlocked: true,
  );
  @override
  PrivacyState build() => PrivacyState(
    loading: false,
    settings: PrivacySettings(enabled: locked),
    books: [book],
  );
}

void main() {
  setUpAll(registerFallbacks);
  const book = Book(bookUrl: 'https://a/书😀?x=1&y=2', name: '小说');
  test('书籍与搜索地址编码保留稳定身份、Unicode和重复源参数', () {
    final uri = Uri.parse(appRouteLocation(AppRoutes.reader, book));
    expect(uri.queryParameters['book'], book.bookUrl);
    final search = Uri.parse(
      appRouteLocation(
        AppRoutes.search,
        const SearchRouteArgs(
          query: '甲 & 😀',
          sourceUrls: ['a?b=c', 'd'],
          groups: ['甲', '乙'],
        ),
      ),
    );
    expect(search.queryParameters['q'], '甲 & 😀');
    expect(search.queryParametersAll['source'], ['a?b=c', 'd']);
    expect(search.queryParametersAll['group'], ['甲', '乙']);
  });
  testWidgets('正式路由从URI恢复书籍身份与搜索过滤，不依赖extra', (tester) async {
    final repository = _Repository();
    when(() => repository.getBook(book.bookUrl)).thenAnswer((_) async => book);
    final reader = _Reader();
    final container = ProviderContainer(
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        readerNotifierProvider.overrideWith(() => reader),
        privacyControllerProvider.overrideWith(() => _Privacy(book)),
      ],
    );
    addTearDown(container.dispose);
    SearchRouteArgs? search;
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const SizedBox(),
        AppRoutes.reader: (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as ReaderRouteArgs;
          return ReaderRouteEntry(
            bookUrl: args.bookUrl,
            builder: (_) => const Text('恢复正文'),
          );
        },
        AppRoutes.search: (context) {
          search =
              ModalRoute.of(context)!.settings.arguments as SearchRouteArgs;
          return const Text('恢复搜索');
        },
      },
    ).createRouter(initialLocation: appRouteLocation(AppRoutes.reader, book));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('恢复正文'), findsOneWidget);
    expect(reader.opens, 1);
    verify(() => repository.getBook(book.bookUrl)).called(1);
    router.go(
      appRouteLocation(
        AppRoutes.search,
        const SearchRouteArgs(
          query: '正文😀',
          sourceUrls: ['a', 'b'],
          groups: ['甲'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(search?.query, '正文😀');
    expect(search?.sourceUrls, ['a', 'b']);
    expect(search?.groups, ['甲']);
  });

  for (final private in [false, true]) {
    testWidgets('地址恢复${private ? '私密书未验证不装载正文' : '仅装载一次，主题重建不重复开书'}', (
      tester,
    ) async {
      final stored = book.copyWith(isPrivate: private);
      final repository = _Repository();
      when(() => repository.getBook(book.bookUrl))
          .thenAnswer((_) async => stored);
      final reader = _Reader();
      final container = ProviderContainer(
        overrides: [
          bookshelfRepositoryProvider.overrideWithValue(repository),
          readerNotifierProvider.overrideWith(() => reader),
          privacyControllerProvider.overrideWith(
            () => _Privacy(stored, locked: private),
          ),
        ],
      );
      addTearDown(container.dispose);
      Future<void> mount(Brightness brightness) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: ReaderRouteEntry(
              bookUrl: book.bookUrl,
              builder: (_) => const Text('正文'),
            ),
          ),
        ),
      );
      await mount(Brightness.light);
      await tester.pumpAndSettle();
      expect(reader.opens, private ? 0 : 1);
      expect(find.text('正文'), private ? findsNothing : findsOneWidget);
      if (private) expect(find.text('验证后阅读'), findsOneWidget);
      await mount(Brightness.dark);
      await tester.pumpAndSettle();
      expect(reader.opens, private ? 0 : 1);
      verify(() => repository.getBook(book.bookUrl)).called(1);
    });
  }
  testWidgets('会话书籍变更后门禁跟随实际正文，重新授权不重开旧书', (tester) async {
    final repository = _Repository();
    when(() => repository.getBook(book.bookUrl)).thenAnswer((_) async => book);
    final reader = _Reader();
    final privacy = _Privacy(book, locked: true);
    final container = ProviderContainer(
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        readerNotifierProvider.overrideWith(() => reader),
        privacyControllerProvider.overrideWith(() => privacy),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderRouteEntry(
            bookUrl: book.bookUrl,
            builder: (_) => const Text('当前正文'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前正文'), findsOneWidget);
    final private = book.copyWith(bookUrl: 'private-book', isPrivate: true);
    reader.showBook(private);
    await tester.pumpAndSettle();
    expect(find.text('当前正文'), findsNothing);
    expect(find.text('验证后阅读'), findsOneWidget);
    privacy.allow(private);
    await tester.pumpAndSettle();
    expect(find.text('当前正文'), findsOneWidget);
    expect(
      container.read(readerNotifierProvider).currentBook?.bookUrl,
      'private-book',
    );
    expect(reader.opens, 1);
  });

  testWidgets('离开后迟到的身份读取不启动阅读', (tester) async {
    final pending = Completer<Book?>();
    final repository = _Repository();
    when(() => repository.getBook(book.bookUrl))
        .thenAnswer((_) => pending.future);
    final reader = _Reader();
    final container = ProviderContainer(
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        readerNotifierProvider.overrideWith(() => reader),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReaderRouteEntry(bookUrl: book.bookUrl)),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(book);
    await tester.pump();
    expect(reader.opens, 0);
    expect(tester.takeException(), isNull);
  });
}
