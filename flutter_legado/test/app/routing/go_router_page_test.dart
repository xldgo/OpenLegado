import 'package:flutter_legado/src/app/routing/route_arguments.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/app/routing/app_router.dart';
import 'package:flutter_legado/src/app/routing/app_route_page.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/privacy/privacy_controller.dart';
import 'package:flutter_legado/src/widgets/reader/read_aloud_player_transition.dart';

class _Privacy extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState(loading: false);
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => value++),
    child: Text('计数$value'),
  );
}

class _QueryProbe extends StatefulWidget {
  const _QueryProbe(this.value);
  final String value;
  @override
  State<_QueryProbe> createState() => _QueryProbeState();
}

class _QueryProbeState extends State<_QueryProbe> {
  late final String initial = widget.value;
  @override
  Widget build(BuildContext context) => Text(initial);
}

void main() {
  testWidgets('同一路径更换URI参数创建新页面，避免保留旧初始化输入', (tester) async {
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const SizedBox(),
        AppRoutes.search: (context) => _QueryProbe(
          (ModalRoute.of(context)!.settings.arguments as SearchRouteArgs)
              .query!,
        ),
      },
    ).createRouter(initialLocation: '/search?q=甲');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyControllerProvider.overrideWith(_Privacy.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('甲'), findsOneWidget);
    router.go('/search?q=乙');
    await tester.pumpAndSettle();
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('甲'), findsNothing);
  });

  testWidgets('换源Page保留PopupRoute与类型结果，主题重建不替换导航栈', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const _Counter(),
        AppRoutes.changeSource: (context) => TextButton(
          onPressed: () => Navigator.pop(context, 'new-book'),
          child: const Text('选择书源'),
        ),
      },
    ).createRouter(navigatorKey: navigator);
    addTearDown(router.dispose);
    Future<void> mount(Brightness brightness) => tester.pumpWidget(
      ProviderScope(
        overrides: [privacyControllerProvider.overrideWith(_Privacy.new)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
        ),
      ),
    );
    await mount(Brightness.light);
    await tester.pumpAndSettle();
    await tester.tap(find.text('计数0'));
    await tester.pump();
    final result = router.push<String>(AppRoutes.changeSource, extra: '源');
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text('选择书源')))!;
    expect(route, isA<PopupRoute<dynamic>>());
    expect((route as ModalRoute<dynamic>).opaque, isFalse);
    expect(route.settings, isA<AppRoutePage>());
    expect(route.settings.arguments, '源');
    expect(find.text('计数1'), findsOneWidget);
    await mount(Brightness.dark);
    await tester.pumpAndSettle();
    expect(
      identical(ModalRoute.of(tester.element(find.text('选择书源'))), route),
      isTrue,
    );
    await tester.tap(find.text('选择书源'));
    await tester.pumpAndSettle();
    expect(await result, 'new-book');
    expect(find.text('计数1'), findsOneWidget);
  });
  testWidgets('Router返回遵守PopScope，未知路径仍回实例首页', (tester) async {
    var blocked = 0;
    final router = AppRouter(
      routes: {
        AppRoutes.home: (_) => const Text('首页'),
        '/blocked': (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) blocked++;
          },
          child: const Text('保护页面'),
        ),
      },
    ).createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyControllerProvider.overrideWith(_Privacy.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push<void>('/blocked');
    await tester.pumpAndSettle();
    expect(await router.routerDelegate.popRoute(), isTrue);
    expect(blocked, 1);
    expect(find.text('保护页面'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    router.push<void>('/unknown');
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(router.state.uri.path, '/unknown');
    router.push<void>('/blocked');
    await tester.pumpAndSettle();
    expect(find.text('保护页面'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/unknown');
  });
  testWidgets('朗读Page继续创建既有非不透明Route并保持Page归属', (tester) async {
    final page = AppRoutePage(
      key: const ValueKey('aloud'),
      name: AppRoutes.readAloudPlayer,
      builder: (_) => const SizedBox(),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final route = page.createRoute(tester.element(find.byType(SizedBox).first));
    expect(route, isA<ReadAloudPlayerRoute>());
    expect(route.settings, same(page));
    expect((route as ModalRoute<dynamic>).opaque, isFalse);
    route.dispose();
  });
}
