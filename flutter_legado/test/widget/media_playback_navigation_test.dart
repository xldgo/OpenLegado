import 'package:flutter_legado/src/app/routing/app_navigation.dart';

import '../fixtures/routing_test_app.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_legado/src/features/read_aloud/media_playback_navigation.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/services/media_session_models.dart';

void main() {
  const target = MediaPlaybackTarget(
    mediaId: 'book',
    sessionToken: 1,
    chapterIndex: 0,
  );
  testWidgets('已有播放页重复点击只返回原实例，不重新创建或压栈', (tester) async {
    final key = GlobalKey<NavigatorState>();
    var builds = 0;
    final observer = MediaPlaybackNavigation(
      resolve: (_) => const MediaPlaybackDestination(
        AppRoutes.audio,
        book: Book(bookUrl: 'book'),
      ),
    );
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      RoutingTestApp(
        navigatorKey: key,
        navigatorObservers: [observer],
        home: const Text('首页'),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) {
            builds++;
            return const Scaffold(body: Text('播放页面'));
          },
        ),
      ),
    );
    observer.open(target);
    await tester.pumpAndSettle();
    expect(builds, 1);
    observer.open(target);
    observer.open(target);
    await tester.pumpAndSettle();
    expect(builds, 1);
    expect(find.text('播放页面'), findsOneWidget);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
  });
  testWidgets('欢迎页退出才打开播放页，失效请求不导航', (tester) async {
    final key = GlobalKey<NavigatorState>();
    var valid = true;
    final observer = MediaPlaybackNavigation(
      resolve: (_) => valid
          ? const MediaPlaybackDestination(AppRoutes.readAloudPlayer)
          : null,
    );
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      RoutingTestApp(
        navigatorKey: key,
        navigatorObservers: [observer],
        initialRoute: AppRoutes.welcome,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text(settings.name ?? 'home')),
        ),
      ),
    );
    observer.open(target);
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.welcome), findsOneWidget);
    GoRouter.of(key.currentState!.context).replaceAppRoute('/home');
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.readAloudPlayer), findsOneWidget);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    valid = false;
    observer.open(target);
    await tester.pumpAndSettle();
    expect(find.text('/home'), findsOneWidget);
  });
}
