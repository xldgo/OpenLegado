import 'package:flutter_legado/src/features/browser/presentation/browser_screen.dart';
import 'package:flutter_legado/src/features/search/search_content_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/app/routing/route_arguments.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/audio/presentation/audio_screen.dart';
import 'package:flutter_legado/src/features/book_detail/presentation/book_info_screen.dart';
import 'package:flutter_legado/src/features/home/presentation/home_screen.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/features/privacy/privacy_gate.dart';
import 'package:flutter_legado/src/features/privacy/privacy_settings.dart';
import 'package:flutter_legado/src/features/reader_comic/presentation/reader_comic_screen.dart';
import 'package:flutter_legado/src/features/search/search_screen.dart';
import 'package:flutter_legado/src/features/video/presentation/video_screen.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_player_transition.dart';

/// 路由测试只替换隐私状态，不启动原生库、播放或业务加载。— Codex + UI
class _Privacy extends PrivacyController {
  _Privacy({this.settings = const PrivacySettings()});
  final PrivacySettings settings;
  @override
  PrivacyState build() => PrivacyState(
    loading: false,
    settings: settings,
    hasPassword: settings.enabled,
  );
}

void main() {
  const book = Book(bookUrl: 'book://1', name: '书名😀', author: '作者');

  // 使用真实ModalRoute参数构造正式目标，替换其渲染以单独验证装配而不初始化业务。
  Future<(Widget, Widget)> resolve(
    WidgetTester tester,
    String name,
    Object? arguments,
  ) async {
    final router = AppRouter();
    final key = GlobalKey<NavigatorState>();
    late (Widget, Widget) result;
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        navigatorKey: key,
        home: const SizedBox(),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) {
            final page = router.routes[name]!(context);
            result = (
              page,
              page is PrivacyBookGate ? page.builder(context) : page,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    key.currentState!.pushNamed(name, arguments: arguments);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return result;
  }

  Future<void> pumpRouter(
    WidgetTester tester,
    AppRouter router,
    GlobalKey<NavigatorState> key, {
    PrivacySettings privacy = const PrivacySettings(),
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyControllerProvider.overrideWith(
          () => _Privacy(settings: privacy),
        ),
      ],
      child: MaterialApp(
        navigatorKey: key,
        onGenerateRoute: router.generateRoute,
      ),
    ),
  );

  test('路由表独立构造且不受调用方后续修改影响', () {
    Widget buildA(BuildContext _) => const Text('甲');
    Widget buildB(BuildContext _) => const Text('乙');
    final input = <String, WidgetBuilder>{AppRoutes.home: buildA};
    final first = AppRouter(routes: input);
    input[AppRoutes.home] = buildB;
    final second = AppRouter(routes: input);
    expect(first.routes[AppRoutes.home], same(buildA));
    expect(second.routes[AppRoutes.home], same(buildB));
    expect(AppRouter().routes, contains(AppRoutes.reader));
  });

  testWidgets('注入路由实际导航保留参数及pop返回值', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const Text('首页'),
        '/probe': (context) => TextButton(
          onPressed: () => Navigator.pop(context, '已选择'),
          child: Text(ModalRoute.of(context)!.settings.arguments as String),
        ),
      },
    );
    await pumpRouter(tester, router, key);
    await tester.pumpAndSettle();
    final result = key.currentState!.pushNamed('/probe', arguments: '目标参数');
    await tester.pumpAndSettle();
    await tester.tap(find.text('目标参数'));
    await tester.pumpAndSettle();
    expect(await result, '已选择');
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('未知路径回实例首页，保留原RouteSettings', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final received = <String?, RouteSettings>{};
    final router = AppRouter(
      routes: {
        AppRoutes.home: (context) {
          final settings = ModalRoute.of(context)!.settings;
          received[settings.name] = settings;
          return const Text('首页兜底');
        },
      },
    );
    await pumpRouter(tester, router, key);
    await tester.pumpAndSettle();
    key.currentState!.pushNamed('/unknown', arguments: book);
    await tester.pumpAndSettle();
    expect(find.text('首页兜底'), findsOneWidget);
    expect(received['/unknown']!.name, '/unknown');
    expect(received['/unknown']!.arguments, same(book));
  });

  testWidgets('普通路由保留应用隐私门禁，不初始化受保护目标', (tester) async {
    var builds = 0;
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) {
          builds++;
          return const Text('受保护页面');
        },
      },
    );
    await pumpRouter(
      tester,
      router,
      GlobalKey<NavigatorState>(),
      privacy: const PrivacySettings(enabled: true, verifyOnAppStart: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('验证后进入应用'), findsOneWidget);
    expect(builds, 0);
  });

  testWidgets('管理入口保留单独身份验证门禁', (tester) async {
    var builds = 0;
    final key = GlobalKey<NavigatorState>();
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const Text('首页'),
        AppRoutes.bookGroups: (_) {
          builds++;
          return const Text('分组管理');
        },
      },
    );
    await pumpRouter(
      tester,
      router,
      key,
      privacy: const PrivacySettings(enabled: true),
    );
    await tester.pumpAndSettle();
    key.currentState!.pushNamed(AppRoutes.bookGroups);
    await tester.pumpAndSettle();
    expect(find.text('验证后管理'), findsOneWidget);
    expect(builds, 0);
  });

  testWidgets('换源弹层保持非透明类型并回传结果，朗读使用独有转场', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const Text('首页'),
        AppRoutes.changeSource: (context) => TextButton(
          onPressed: () => Navigator.pop(context, 'new://book'),
          child: const Text('选择书源'),
        ),
      },
    );
    final settings = const RouteSettings(
      name: AppRoutes.changeSource,
      arguments: book,
    );
    final popup = router.generateRoute(settings);
    expect(popup, isA<PopupRoute<dynamic>>());
    expect((popup as PopupRoute<dynamic>).opaque, isFalse);
    expect(popup.settings, same(settings));
    expect(
      router.generateRoute(
        const RouteSettings(name: AppRoutes.readAloudPlayer),
      ),
      isA<ReadAloudPlayerRoute>(),
    );
    await pumpRouter(tester, router, key);
    await tester.pumpAndSettle();
    final result = key.currentState!.pushNamed(
      AppRoutes.changeSource,
      arguments: book,
    );
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    await tester.tap(find.text('选择书源'));
    await tester.pumpAndSettle();
    expect(await result, 'new://book');
  });

  testWidgets('详情参数保留书籍身份、隐私门禁及字符串入口', (tester) async {
    final (gate, target) = await resolve(tester, AppRoutes.bookInfo, book);
    expect((gate as PrivacyBookGate).book, same(book));
    expect((target as BookInfoScreen).book, same(book));
    final (_, byUrl) = await resolve(tester, AppRoutes.bookInfo, 'book://url');
    expect((byUrl as BookInfoScreen).bookUrl, 'book://url');
  });

  testWidgets('搜索明确接收查询、源范围与分组参数', (tester) async {
    final (_, simple) = await resolve(
      tester,
      AppRoutes.search,
      const SearchRouteArgs(query: '查询'),
    );
    expect((simple as SearchScreen).initialQuery, '查询');
    final (_, selected) = await resolve(
      tester,
      AppRoutes.search,
      const SearchRouteArgs(
        query: '查询',
        sourceUrls: ['source://1', 'source://2'],
        groups: ['甲', '乙'],
      ),
    );
    expect((selected as SearchScreen).initialSourceUrls, [
      'source://1',
      'source://2',
    ]);
    expect(selected.initialGroups, ['甲', '乙']);
    final (_, missing) = await resolve(tester, AppRoutes.search, null);
    expect((missing as SearchScreen).initialQuery, isNull);
  });

  testWidgets('浏览器携带网页正文与标题，缺参仍为普通浏览页', (tester) async {
    final (_, target) = await resolve(
      tester,
      AppRoutes.browser,
      const BrowserRouteArgs(url: 'https://a', html: '<p>正文</p>', title: '标题'),
    );
    final browser = target as BrowserScreen;
    expect(browser.initialUrl, 'https://a');
    expect(browser.initialHtml, '<p>正文</p>');
    expect(browser.title, '标题');
    final (_, missing) = await resolve(tester, AppRoutes.browser, 42);
    expect((missing as BrowserScreen).initialUrl, isNull);
  });
  testWidgets('正文搜索保留书籍身份与选中文本', (tester) async {
    final (_, target) = await resolve(
      tester,
      AppRoutes.searchContent,
      const ContentSearchRouteArgs(book: book, query: '选中内容'),
    );
    final search = target as SearchContentScreen;
    expect(search.book, same(book));
    expect(search.initialQuery, '选中内容');
  });

  testWidgets('音频书保留Book，漫画接收明确地址，错误参数安全回退', (tester) async {
    final (gate, audio) = await resolve(tester, AppRoutes.audio, book);
    expect((gate as PrivacyBookGate).book, same(book));
    expect((audio as AudioScreen).book, same(book));
    final (_, missing) = await resolve(tester, AppRoutes.audio, 42);
    expect((missing as AudioScreen).book, isNull);
    final (comicGate, target) = await resolve(
      tester,
      AppRoutes.readerComic,
      'comic://1',
    );
    expect((comicGate as PrivacyBookGate).book!.bookUrl, 'comic://1');
    expect((target as ReaderComicScreen).bookUrl, 'comic://1');
  });

  testWidgets('视频恢复参数完整传递，书籍入口保留隐私包裹', (tester) async {
    final (_, target) = await resolve(
      tester,
      AppRoutes.video,
      const VideoScreenArgs(
        videoUrl: 'video://1',
        title: '视频',
        book: book,
        presetUrl: 'https://video.test',
        presetHeaders: {'Auth': 'secret'},
        presetMpdPath: 'manifest.mpd',
        initialResumeMs: 1234,
        initialChapterIndex: 2,
        initialSpeed: 1.5,
        initialPlaying: false,
      ),
    );
    final video = target as VideoScreen;
    expect(video.videoUrl, 'video://1');
    expect(video.book, same(book));
    expect(video.presetUrl, 'https://video.test');
    expect(video.presetHeaders, {'Auth': 'secret'});
    expect(video.presetMpdPath, 'manifest.mpd');
    expect(video.initialResumeMs, 1234);
    expect(video.initialChapterIndex, 2);
    expect(video.initialSpeed, 1.5);
    expect(video.initialPlaying, isFalse);
    final (gate, _) = await resolve(tester, AppRoutes.video, book);
    expect((gate as PrivacyBookGate).book, same(book));
  });

  testWidgets('目录与编辑缺少书籍参数时仍回首页', (tester) async {
    for (final name in [AppRoutes.toc, AppRoutes.editBookInfo]) {
      final (_, target) = await resolve(tester, name, null);
      expect(target, isA<HomeScreen>());
    }
  });
}
