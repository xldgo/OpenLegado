import '../helpers/reader_layout_host.dart';
// [P2-30 | 未入架书退出阅读缺「放入书架」提示] 退出判定 widget 测试
//
// 对齐原版 ReadBookActivity.finish() 三路语义（参考版 closeReadBook 同款）：
// 1. 已入架（DB 记录存在且未打 notShelf 位）→ 直接退出（进度落库，无弹窗）；
// 2. 未入架 + 「返回时提示放入书架」开关（PrefKeys.showAddToShelfAlert，
//    既有设置项，默认开）关闭 → 静默退出并清理未入架书的临时落库记录
//    （deleteBook，书不残留）；
// 3. 未入架 + 开关开启（默认）→ 弹「放入书架」对话框：
//    确认 → addBook（清 notShelf 位，upsert 不级联删章节目录）→ 进度落库 → 退出；
//    取消 → deleteBook 清理临时记录 → 退出（书不残留）。
//
// 修前行为：ReaderScreen 的 PopScope 只 saveProgress + pop——未入架书退出时
// 无任何提示，临时落库的 notShelf 记录残留（用例 1 修前红）。
//
// 在架判定数据源：DB 记录（api.getBook + BookOpenUtils.isInBookshelf 判
// notShelf 位）——路由带入的内存 Book 是瘦壳，不可作为在架依据。

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/reader/reader_notifier.dart';
import 'package:flutter_legado/src/providers/theme/system_bar_controller.dart';
import 'package:flutter_legado/src/screens/reader_screen.dart';
import 'package:flutter_legado/src/routes.dart';
import 'package:flutter_legado/src/utils/app_route_observer.dart';

import '../mocks/mocks.dart';

/// 会话内存书（openBook 传入；未入架书会话内存书带 notShelf 位）
const _sessionBook = Book(
  bookUrl: 'https://book.com/shelf-exit',
  name: '未入架书',
  author: '作者',
  origin: 'https://source-a.com',
  originName: '源A',
  bookType: BookType.notShelf,
);

/// DB 记录：未入架（临时落库，notShelf 位已置）
const _notShelfDbBook = Book(
  bookUrl: 'https://book.com/shelf-exit',
  name: '未入架书',
  bookType: BookType.notShelf,
);

/// DB 记录：已入架（notShelf 位未置）
const _shelfDbBook = Book(
  bookUrl: 'https://book.com/shelf-exit',
  name: '未入架书',
  bookType: 0,
);

const _chapters = [
  BookChapter(url: 'https://book.com/shelf-exit/c1', title: '第一章', index: 0),
  BookChapter(url: 'https://book.com/shelf-exit/c2', title: '第二章', index: 1),
];

void main() {
  setUpAll(registerFallbacks);

  setUp(() {
    SharedPreferences.setMockInitialValues({'enableReadRecord': false});
  });

  /// 阅读主链路桩（目录/正文/源/配置/进度落库）
  MockRustApi stubReaderApi() {
    final api = MockRustApi();
    when(() => api.readingRepository.getChapters(any()))
        .thenAnswer((_) async => _chapters);
    when(() => api.readingRepository.getChapterContentFull(any(), any()))
        .thenAnswer((i) async => 'CH${i.positionalArguments[1]}');
    when(() => api.readingRepository.getChapterContent(any(), any()))
        .thenAnswer((_) async => '');
    when(() => api.bookSourceRepository.getBookSources())
        .thenAnswer((_) async => const []);
    when(() => api.configRepository.getConfig(any()))
        .thenAnswer((_) async => '');
    when(
      () => api.readingRepository.updateReadingProgress(
        bookUrl: any(named: 'bookUrl'),
        chapterIndex: any(named: 'chapterIndex'),
        chapterPos: any(named: 'chapterPos'),
      ),
    ).thenAnswer((_) async {});
    return api;
  }

  /// 启动 App（首页按钮 push 真实 ReaderScreen，使 PopScope 可被触发）
  Future<ProviderContainer> pumpReader(
    WidgetTester tester,
    MockRustApi api, {
    SystemBarController? systemBars,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookApiProvider.overrideWithValue(api),
          if (systemBars != null)
            systemBarControllerProvider.overrideWithValue(systemBars),
        ],
        child: MaterialApp(
          navigatorObservers: [systemBarRouteObserver],
          builder: readerLayoutTestBuilder,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<Route<dynamic>>(
                      builder: (_) => const ReaderScreen(),
                    ),
                  ),
                  child: const Text('进入阅读'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入阅读'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    final notifier = container.read(readerNotifierProvider.notifier);
    await notifier.openBook(_sessionBook);
    await tester.pumpAndSettle();
    return container;
  }

  /// 触发退出（等价系统返回/阅读顶栏返回按钮）：
  /// Navigator.maybePop → canPop=false 的 PopScope 拦截（didPop=false）
  /// → 退出判定函数。裸 Navigator.pop() 不受 canPop 拦截（应用内无此
  /// 调用点），不用于模拟用户返回。
  Future<void> popReader(WidgetTester tester) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.maybePop();
    await tester.pumpAndSettle();
  }

  group('P2-30 未入架书退出阅读「放入书架」提示', () {
    testWidgets('未入架书退出：默认弹「放入书架」对话框（标题/正文/取消/确认齐备，修前红）', (tester) async {
      final api = stubReaderApi();
      final applied = <String>[];
      final systemBars = SystemBarController(
        applyApplication: (_) async => applied.add('应用'),
        applyReader: (_) async => applied.add('阅读'),
      );
      addTearDown(systemBars.dispose);
      systemBars.updateApplication((
        transparentStatusBar: false,
        immNavigationBar: false,
        appBarColor: Colors.white,
        navigationBarColor: Colors.white,
      ));
      // 在架判定数据源：DB 记录带 notShelf 位 → 未入架
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => _notShelfDbBook);
      final container = await pumpReader(tester, api, systemBars: systemBars);
      addTearDown(container.dispose);

      await popReader(tester);

      expect(
        find.text('放入书架'),
        findsOneWidget,
        reason: '未入架书退出必须弹「放入书架」提示（修前：静默退出无弹窗）',
      );
      expect(
        find.text('是否将《${_sessionBook.name}》放入书架？'),
        findsOneWidget,
        reason: '对话框正文对齐参考版 AppAlertDialog（是否将《书名》放入书架？）',
      );
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
      // 弹窗阻断退出：阅读器路由仍在
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(applied.last, '阅读', reason: '退出确认弹窗不交还阅读页面的系统栏归属');
    });

    testWidgets('未入架书退出 + 确认：清 notShelf 位入架 + 进度落库 + 退出', (tester) async {
      final api = stubReaderApi();
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => _notShelfDbBook);
      when(() => api.bookshelfRepository.addBook(any()))
          .thenAnswer((_) async => _sessionBook);
      // 确认路径会读 bookshelfNotifier（首次 build 触发列表/分组加载桩）
      when(() => api.bookshelfRepository.getBooks())
          .thenAnswer((_) async => const []);
      when(() => api.bookGroupRepository.getBookGroups())
          .thenAnswer((_) async => const []);
      final container = await pumpReader(tester, api);
      addTearDown(container.dispose);
      // 开读后设一个可区分的章内位置（openBook 自身会落一次 pos=0，
      // 退出判定须再落一次当前位置 5 才能证明「退出前进度落库」）
      container.read(readerNotifierProvider.notifier).updatePosition(5);
      await tester.pump();

      await popReader(tester);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // 入架：addBook 被调用且 notShelf 位已清（upsert 不级联删章节目录）
      final captured = verify(
        () => api.bookshelfRepository.addBook(captureAny()),
      ).captured;
      expect(captured, hasLength(1), reason: '确认必须调用 addBook 入架一次');
      final added = captured.single as Book;
      expect(
        added.bookType & BookType.notShelf,
        0,
        reason: '入架书 bookType 不得残留 notShelf 位',
      );
      expect(added.bookUrl, _sessionBook.bookUrl);
      // 进度落库（退出前 saveProgress 落当前章内位置 5，区别于开读的 0）
      final posWrites = verify(
        () => api.readingRepository.updateReadingProgress(
          bookUrl: any(named: 'bookUrl'),
          chapterIndex: any(named: 'chapterIndex'),
          chapterPos: captureAny(named: 'chapterPos'),
        ),
      ).captured;
      expect(
        posWrites.last,
        5,
        reason: '退出落库的最后一次 updateReadingProgress 应为章内位置 5',
      );
      // 入架成功不删除记录
      verifyNever(() => api.bookshelfRepository.deleteBook(any()));
      // 已退出：阅读器路由已 pop
      expect(find.byType(ReaderScreen), findsNothing);
    });

    testWidgets('未入架书退出 + 取消：清理临时落库记录（书不残留）+ 退出', (tester) async {
      final api = stubReaderApi();
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => _notShelfDbBook);
      final container = await pumpReader(tester, api);
      addTearDown(container.dispose);

      await popReader(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 取消 → 未入架书不残留：deleteBook 清理本次会话的临时记录
      verify(() => api.bookshelfRepository.deleteBook(_sessionBook.bookUrl))
          .called(1);
      // 未确认入架
      verifyNever(() => api.bookshelfRepository.addBook(any()));
      // 已退出
      expect(find.byType(ReaderScreen), findsNothing);
    });

    testWidgets('已入架书退出：直接退出（无弹窗、无删除、进度落库）', (tester) async {
      final api = stubReaderApi();
      final applied = <String>[];
      final systemBars = SystemBarController(
        applyApplication: (bars) async =>
            applied.add(bars.appBarColor == Colors.black ? '应用夜间' : '应用日间'),
        applyReader: (_) async => applied.add('阅读'),
      );
      addTearDown(systemBars.dispose);
      systemBars.updateApplication((
        transparentStatusBar: false,
        immNavigationBar: false,
        appBarColor: Colors.white,
        navigationBarColor: Colors.white,
      ));
      // DB 记录无 notShelf 位 → 已入架
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => _shelfDbBook);
      final container = await pumpReader(tester, api, systemBars: systemBars);
      addTearDown(container.dispose);
      container.read(readerNotifierProvider.notifier).updatePosition(5);
      await tester.pump();

      systemBars.updateApplication((
        transparentStatusBar: true,
        immNavigationBar: true,
        appBarColor: Colors.black,
        navigationBarColor: Colors.black,
      ));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final sheet = AppRoutes.generateRoute(
        const RouteSettings(name: AppRoutes.changeSource),
      );
      // 验证真实换源 Sheet 的路由类型，不构建需要另行初始化的换源业务。
      systemBarRouteObserver.didPush(sheet, null);
      await tester.pump();
      expect(applied.last, '阅读');
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('独立页面')),
        ),
      );
      await tester.pumpAndSettle();
      expect(applied.last, '应用夜间');
      navigator.pop();
      await tester.pumpAndSettle();
      expect(applied.last, '阅读');

      systemBarRouteObserver.didPop(sheet, null);

      await popReader(tester);

      // 无弹窗（现状不变：已入架书直接退出）
      expect(find.text('放入书架'), findsNothing);
      expect(find.byType(ReaderScreen), findsNothing);
      expect(applied.last, '应用夜间', reason: '阅读器退出恢复最新应用设置');
      // 不动书架数据
      verifyNever(() => api.bookshelfRepository.addBook(any()));
      verifyNever(() => api.bookshelfRepository.deleteBook(any()));
      // 进度仍落库（退出写当前章内位置 5，区别于开读的 0）
      final posWrites = verify(
        () => api.readingRepository.updateReadingProgress(
          bookUrl: any(named: 'bookUrl'),
          chapterIndex: any(named: 'chapterIndex'),
          chapterPos: captureAny(named: 'chapterPos'),
        ),
      ).captured;
      expect(posWrites.last, 5, reason: '已入架书退出仍须落库当前进度（现状不变）');
    });

    testWidgets('未入架书退出 + 「返回时提示放入书架」开关关闭：静默退出且清理（无弹窗）', (tester) async {
      SharedPreferences.setMockInitialValues({
        'enableReadRecord': false,
        'showAddToShelfAlert': false,
      });
      final api = stubReaderApi();
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => _notShelfDbBook);
      final container = await pumpReader(tester, api);
      addTearDown(container.dispose);

      await popReader(tester);

      // 开关关 → 无弹窗
      expect(find.text('放入书架'), findsNothing);
      // 静默退出且未入架书不残留
      verify(() => api.bookshelfRepository.deleteBook(_sessionBook.bookUrl))
          .called(1);
      verifyNever(() => api.bookshelfRepository.addBook(any()));
      expect(find.byType(ReaderScreen), findsNothing);
    });

    testWidgets('未入架书退出 + 确认入架失败：可见失败提示且不退出', (tester) async {
      final api = stubReaderApi();
      when(() => api.bookshelfRepository.getBook(any()))
          .thenAnswer((_) async => _notShelfDbBook);
      // 入架写库失败（addBook 抛异常 → bookshelfNotifier.addBook 返回 false）
      when(() => api.bookshelfRepository.addBook(any()))
          .thenThrow(StateError('db write failed'));
      final container = await pumpReader(tester, api);
      addTearDown(container.dispose);

      await popReader(tester);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // 失败提示可见
      expect(find.textContaining('加入书架失败'), findsOneWidget);
      // 不退出、不删除（留给用户重试或再次退出）
      expect(find.byType(ReaderScreen), findsOneWidget);
      verifyNever(() => api.bookshelfRepository.deleteBook(any()));
    });
  });
}
