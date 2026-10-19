import '../fixtures/routing_test_app.dart';
import '../fixtures/app_test_api.dart';

// [08 元信息区对齐 | 台账 0922 修订] 书籍详情页元信息区元素集回归守卫：
// 对标参考 io.legato.kazusa 08 屏（docs/parity_shots/ref_20260914/08_book_info.png
// + ref_dark_20260920/08_book_info.xml + 参考源 BookInfoScreen.kt/HighlightTagRow.kt）：
// - 无独立「目录：」行（目录入口仅保留四按钮「查看目录」卡）
// - 无独立「分组：」行（分组信息收编入 chips 行条件 chip；无分组不显「未分组」）
// - 无「🏷️ 标签行」（参考 08 无此行；kind 信息即 chips 行逐项，
//   原标签行的点击搜索/长按 JS 回调手势迁至 kind chip，功能不丢）
// - chips 行无章数 chip（章数由「共 N 章」行承载）
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/widgets/app_menu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/domain/models/source_action_result.dart';
import 'package:flutter_legado/src/features/bookshelf/bookshelf.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/features/book_detail/presentation/book_info_screen.dart';

import '../mocks/mocks.dart';

/// 记录 push 的路由名（kind chip 点击 → 搜索页断言用）
class _PushedRouteObserver extends NavigatorObserver {
  final List<String> pushed;
  _PushedRouteObserver(this.pushed);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name ?? '');
  }
}

void main() {
  late MockRustApi mockApi;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbacks();
    // 固定方法通道实现，测试不打开宿主系统分享面板。
    final original = SharePlatform.instance;
    SharePlatform.instance = MethodChannelShare();
    addTearDown(() => SharePlatform.instance = original);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockRustApi();
    container = ProviderContainer(
      overrides: mergeTestOverrides([...mockApi.overrides]),
    );
    addTearDown(container.dispose);
  });

  Widget wrap(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: RoutingTestApp(home: child),
    );
  }

  /// 预载书架分组（分组 chip 读取 bookshelfNotifierProvider.groups）
  Future<void> loadGroups(List<BookGroup> groups) async {
    when(() => mockApi.bookshelfRepository.getBooks())
        .thenAnswer((_) async => const []);
    when(() => mockApi.bookGroupRepository.getBookGroups())
        .thenAnswer((_) async => groups);
    await container.read(bookshelfNotifierProvider.notifier).refresh();
  }

  void stubBook(Book book, [List<BookChapter> chapters = const []]) {
    when(() => mockApi.bookshelfRepository.getBook(any()))
        .thenAnswer((_) async => book);
    when(() => mockApi.readingRepository.getChapters(any()))
        .thenAnswer((_) async => chapters);
    when(() => mockApi.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => const []);
    when(
      () => mockApi.sourceActionService.sourceCallBackBtn(
        event: any(named: 'event'),
        bookUrl: any(named: 'bookUrl'),
        result: any(named: 'result'),
        bookType: any(named: 'bookType'),
      ),
    ).thenAnswer(
      (_) async => SourceCallbackResult(invoked: false, jsTrue: false),
    );
  }

  group('book_info_meta_rows', () {
    testWidgets('书籍分享经新接口传递原 URL 和 JSON', (tester) async {
      const book = Book(
        bookUrl: 'https://src.com/book/share',
        name: '分享书籍',
        author: '作者',
      );
      stubBook(book);
      await loadGroups(const []);
      final calls = <MethodCall>[];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(wrap(const BookInfoScreen(book: book)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('分享'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'share');
      expect(
        (calls.single.arguments as Map)['text'],
        '${book.bookUrl}#${jsonEncode(book.toJson())}',
      );
    });

    for (final handled in [false, true]) {
      testWidgets(handled ? '回调接管后不重复默认分享、复制和清缓存' : '回调未接管时继续默认分享、复制和清缓存', (
        tester,
      ) async {
        const book = Book(
          bookUrl: 'https://source.test/book',
          name: '书',
          tocUrl: 'https://source.test/toc',
        );
        stubBook(book);
        await loadGroups(const []);
        final events = <String>[];
        final shares = <MethodCall>[];
        final copies = <String>[];
        when(
          () => mockApi.sourceActionService.sourceCallBackBtn(
            event: any(named: 'event'),
            bookUrl: book.bookUrl,
            result: any(named: 'result'),
            bookType: 0,
          ),
        ).thenAnswer((call) async {
          events.add(call.namedArguments[#event] as String);
          return SourceCallbackResult(invoked: handled, jsTrue: handled);
        });
        when(() => mockApi.chapterCacheRepository.clearBookCache(book.bookUrl))
            .thenAnswer((_) async => 5);
        const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          shareChannel,
          (call) async {
            shares.add(call);
            return 'dev.fluttercommunity.plus/share/unavailable';
          },
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copies.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            shareChannel,
            null,
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        await tester.pumpWidget(wrap(const BookInfoScreen(book: book)));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('分享'));
        await tester.pumpAndSettle();
        final menu = tester.widget<AppMenuButton<String>>(
          find.byType(AppMenuButton<String>).first,
        );
        for (final action in ['copyBookUrl', 'copyTocUrl', 'clearCache']) {
          menu.onSelected!(action);
          await tester.pumpAndSettle();
          if (action != 'clearCache') {
            // 等前一个复制提示消失，避免遮住后续清缓存结果。
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
          }
        }
        expect(events, [
          'clickShareBook',
          'clickCopyBookUrl',
          'clickCopyTocUrl',
          'clickClearCache',
        ]);
        expect(shares, hasLength(handled ? 0 : 1));
        expect(copies, handled ? isEmpty : equals([book.bookUrl, book.tocUrl]));
        if (handled) {
          verifyNever(
            () => mockApi.chapterCacheRepository.clearBookCache(book.bookUrl),
          );
          expect(find.textContaining('已清除'), findsNothing);
        } else {
          verify(
            () => mockApi.chapterCacheRepository.clearBookCache(book.bookUrl),
          ).called(1);
          expect(find.text('已清除 5 条章节缓存'), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('无独立「目录：」/「分组：」行、无「🏷️ 标签行」，'
        'kind 信息以 chips 行呈现，章数由「共 N 章」行承载', (tester) async {
      final book = Book(
        bookUrl: 'https://src.com/book/meta',
        name: '元信息书',
        author: '作者',
        kind: '奇幻,武侠',
        wordCount: '142.20万字',
        totalChapterNum: 711,
      );
      stubBook(book, [
        BookChapter(bookUrl: book.bookUrl, index: 0, title: '引子 穿越的唐家三少'),
      ]);
      await loadGroups(const []);

      await tester.pumpWidget(wrap(BookInfoScreen(book: book)));
      await tester.pumpAndSettle();

      // 去噪三行：独立目录行/分组行/🏷️ 标签行均不渲染
      expect(find.textContaining('目录：'), findsNothing);
      expect(find.textContaining('分组：'), findsNothing);
      expect(find.textContaining('🏷️'), findsNothing);
      // 目录入口保留于四按钮「查看目录」卡
      expect(find.text('查看目录'), findsOneWidget);
      // kind 信息仍在（chips 行逐项），字数 chip 同在
      expect(find.text('奇幻'), findsOneWidget);
      expect(find.text('武侠'), findsOneWidget);
      expect(find.text('142.20万字'), findsOneWidget);
      // 章数只出现在「共 N 章」行，chips 行无「711章」项
      expect(find.textContaining('共 711 章'), findsOneWidget);
      expect(find.text('711章'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // 注：BookInfoScreen 仅在 initState 加载（无 didUpdateWidget 重载），
    // 同树位 re-pump 会复用 State/_loadedBook，故有/无分组分两个独立
    // testWidgets（各起全新 State）
    testWidgets('分组 chip：有分组时显示裸分组名（无「分组：」前缀、'
        '无「未分组」兜底）', (tester) async {
      final groupedBook = Book(
        bookUrl: 'https://src.com/book/g1',
        name: '分组书',
        author: '作者',
        kind: '轻小说',
        group: 1, // 位掩码命中 groupId=1
      );
      stubBook(groupedBook, const []);
      await loadGroups(const [
        BookGroup(groupId: 1, groupName: '武侠', order: 0),
      ]);

      await tester.pumpWidget(wrap(BookInfoScreen(book: groupedBook)));
      await tester.pumpAndSettle();

      // 有分组：chips 行出现分组 chip（裸分组名，对齐参考 values-zh-rCN
      // group_s=%s——不带「分组：」前缀）
      expect(find.text('武侠'), findsOneWidget);
      expect(find.textContaining('分组：'), findsNothing);
      expect(find.textContaining('未分组'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('分组 chip：无分组时不显示（不显「未分组」，kind chip 不丢）', (tester) async {
      final ungroupedBook = Book(
        bookUrl: 'https://src.com/book/g2',
        name: '无分组书',
        author: '作者',
        kind: '轻小说',
        group: 0, // 位掩码 0 不命中任何分组
      );
      stubBook(ungroupedBook, const []);
      // 书架里确有分组（武侠），证明不显示是书籍无分组而非分组列表为空
      await loadGroups(const [
        BookGroup(groupId: 1, groupName: '武侠', order: 0),
      ]);

      await tester.pumpWidget(wrap(BookInfoScreen(book: ungroupedBook)));
      await tester.pumpAndSettle();

      expect(find.text('武侠'), findsNothing);
      expect(find.textContaining('未分组'), findsNothing);
      expect(find.textContaining('分组：'), findsNothing);
      // kind 信息不丢：chips 行仍有 kind chip
      expect(find.text('轻小说'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chips 行无章数 chip（kind/字数各一 chip）', (tester) async {
      final book = Book(
        bookUrl: 'https://src.com/book/chips',
        name: 'chips书',
        author: '作者',
        kind: '轻小说,已完结',
        wordCount: '120万字',
        totalChapterNum: 51,
      );
      stubBook(book, const []);
      await loadGroups(const []);

      await tester.pumpWidget(wrap(BookInfoScreen(book: book)));
      await tester.pumpAndSettle();

      // kind 逐项成 chip（参考 kindLabels itemsIndexed 形态，
      // 「已完结」等状态词亦为普通 chip，无特殊解析）
      expect(find.text('轻小说'), findsOneWidget);
      expect(find.text('已完结'), findsOneWidget);
      expect(find.text('120万字'), findsOneWidget);
      // 章数项不在 chips 行（「51章」精确文本不出现；
      // 「共 51 章」为 ③ 三行块承载）
      expect(find.text('51章'), findsNothing);
      expect(find.textContaining('共 51 章'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kind chip 点击进搜索页（原 🏷️ 行逐 tag 搜索入口迁移）', (tester) async {
      final pushed = <String>[];
      final observer = _PushedRouteObserver(pushed);
      final routes = Map<String, WidgetBuilder>.from(AppRouter().routes)
        ..remove('/');
      routes[AppRoutes.search] = (_) =>
          const Scaffold(key: Key('search-stub'), body: Text('搜索页'));
      final book = Book(
        bookUrl: 'https://src.com/book/kindtap',
        name: '点tag书',
        author: '作者',
        kind: '奇幻,武侠',
      );
      stubBook(book, const []);
      await loadGroups(const []);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RoutingTestApp(
            home: BookInfoScreen(book: book),
            routes: routes,
            navigatorObservers: [observer],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击 kind chip → push 搜索页（_openSearch：event=clickBookLabel）
      await tester.tap(find.text('奇幻'));
      await tester.pumpAndSettle();
      expect(pushed, contains(AppRoutes.search));
      expect(find.byKey(const Key('search-stub')), findsOneWidget);

      // 返回详情页（同 Navigator pop；re-pump 会复用 NavigatorState，
      // 已 push 的搜索页仍在栈顶，故用 pop 恢复 chip 行可见）
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search-stub')), findsNothing);

      // 长按 kind chip → JS 回调（event=longClickBookLabel，
      // 原 🏷️ 行长按入口迁移，功能不丢）
      await tester.longPress(find.text('武侠'));
      await tester.pumpAndSettle();
      verify(
        () => mockApi.sourceActionService.sourceCallBackBtn(
          event: 'longClickBookLabel',
          bookUrl: book.bookUrl,
          result: '武侠',
          bookType: 0,
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    });
  });
}
