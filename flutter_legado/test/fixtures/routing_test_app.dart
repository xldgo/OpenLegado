import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_legado/src/app/routing/app_router.dart';

/// 测试宿主也使用真实Router；仅目标页工厂可替换，不在生产保留旧命名导航。— Codex + UI
class RoutingTestApp extends StatefulWidget {
  const RoutingTestApp({
    super.key,
    this.home,
    this.routes = const {},
    this.onGenerateRoute,
    this.navigatorKey,
    this.navigatorObservers = const [],
    this.initialRoute,
    this.builder,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales = const [Locale('en', 'US')],
    this.debugShowCheckedModeBanner = false,
    this.title = '',
    this.scrollBehavior,
    this.scaffoldMessengerKey,
    this.color,
    this.onGenerateTitle,
  });
  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final RouteFactory? onGenerateRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver> navigatorObservers;
  final String? initialRoute;
  final TransitionBuilder? builder;
  final ThemeData? theme, darkTheme;
  final ThemeMode? themeMode;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final bool debugShowCheckedModeBanner;
  final String title;
  final ScrollBehavior? scrollBehavior;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final Color? color;
  final GenerateAppTitle? onGenerateTitle;
  @override
  State<RoutingTestApp> createState() => _RoutingTestAppState();
}

class _RoutingTestAppState extends State<RoutingTestApp> {
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    final paths = {...AppRouter().routes.keys, ...widget.routes.keys, '/'};
    router = GoRouter(
      navigatorKey: widget.navigatorKey,
      initialLocation: widget.initialRoute ?? '/',
      overridePlatformDefaultLocation: true,
      observers: widget.navigatorObservers,
      routes: [
        for (final path in paths)
          GoRoute(
            path: path,
            pageBuilder: (_, state) => _FixturePage(
              key: state.pageKey,
              name: path,
              arguments: state.extra,
              owner: this,
            ),
          ),
        GoRoute(
          path: '/:unknown(.*)',
          pageBuilder: (_, state) => _FixturePage(
            key: state.pageKey,
            name: state.uri.path,
            arguments: state.extra,
            owner: this,
          ),
        ),
      ],
      errorPageBuilder: (_, state) => _FixturePage(
        key: state.pageKey,
        name: state.uri.path,
        arguments: state.extra,
        owner: this,
      ),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    builder: widget.builder,
    theme: widget.theme,
    darkTheme: widget.darkTheme,
    themeMode: widget.themeMode,
    locale: widget.locale,
    localizationsDelegates: widget.localizationsDelegates,
    supportedLocales: widget.supportedLocales,
    debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
    title: widget.title,
    scrollBehavior: widget.scrollBehavior,
    scaffoldMessengerKey: widget.scaffoldMessengerKey,
    color: widget.color,
    onGenerateTitle: widget.onGenerateTitle,
  );
}

class _FixturePage extends Page<dynamic> {
  const _FixturePage({
    required super.key,
    required super.name,
    super.arguments,
    required this.owner,
  });
  final _RoutingTestAppState owner;
  @override
  Route<dynamic> createRoute(BuildContext context) {
    final app = owner.widget;
    if (name == '/' && app.home != null) {
      return MaterialPageRoute<dynamic>(
        settings: this,
        builder: (_) => owner.widget.home!,
      );
    }
    final builder = app.routes[name];
    if (builder != null) {
      return MaterialPageRoute<dynamic>(settings: this, builder: builder);
    }
    final route = app.onGenerateRoute?.call(this);
    if (route != null && identical(route.settings, this)) return route;
    if (route is MaterialPageRoute<dynamic>) {
      return MaterialPageRoute<dynamic>(
        settings: this,
        builder: route.builder,
        maintainState: route.maintainState,
        fullscreenDialog: route.fullscreenDialog,
      );
    }
    throw StateError('测试未提供目标路由：$name');
  }
}
