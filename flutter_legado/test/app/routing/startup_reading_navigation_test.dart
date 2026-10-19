import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/app/routing/app_navigation.dart';
import 'package:flutter_legado/src/app/routing/startup_reading_navigation.dart';
import 'package:flutter_legado/src/app/routing/route_names.dart';
import 'package:flutter_legado/src/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter_legado/src/providers/welcome_settings_provider.dart';
import 'package:flutter_legado/src/domain/contracts/welcome_settings_repository.dart';
import 'package:flutter_legado/src/domain/models/welcome_settings.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/routing_test_app.dart';
import '../../fixtures/app_test_api.dart';

class _Welcome extends Mock implements WelcomeSettingsRepository {}

void main() {
  const book = Book(bookUrl: 'last', name: '上次阅读', durChapterTime: 1);
  testWidgets('真实欢迎页退出后恢复一次，无需等待主页关闭', (tester) async {
    final opened = <Book>[];
    final navigation = StartupReadingNavigation(
      open: (book, current) async {
        if (current()) opened.add(book);
      },
      onError: (e, s) => fail('$e'),
    );
    addTearDown(navigation.dispose);
    final settings = _Welcome();
    const value = WelcomeSettings(showTime: 0, defaultToRead: true);
    when(() => settings.load()).thenAnswer((_) async => value);
    when(() => settings.current).thenReturn(value);
    final api = MockBookApi();
    for (final old in await api.bookshelfRepository.getBooks()) {
      await api.bookshelfRepository.deleteBook(old.bookUrl);
    }
    await api.bookshelfRepository.addBook(book);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...api.overrides,
          welcomeSettingsRepositoryProvider.overrideWithValue(settings),
          startupReadingNavigationProvider.overrideWithValue(navigation),
        ],
        child: RoutingTestApp(
          initialRoute: AppRoutes.welcome,
          navigatorObservers: [navigation],
          routes: {
            AppRoutes.welcome: (_) => const WelcomeScreen(),
            AppRoutes.home: (_) => const Text('主页'),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('主页'), findsOneWidget);
    expect(opened, [book]);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
  });
  for (final cancel in ['外部动作', '应用卸载', '其它页面']) {
    testWidgets('准备期间$cancel取消旧恢复任务', (tester) async {
      final ready = Completer<void>();
      final opened = <Book>[];
      var preparing = false;
      final navigation = StartupReadingNavigation(
        open: (book, current) async {
          preparing = true;
          await ready.future;
          if (current()) opened.add(book);
        },
        onError: (e, s) => fail('$e'),
      );
      addTearDown(navigation.dispose);
      late GoRouter router;
      await tester.pumpWidget(
        RoutingTestApp(
          navigatorObservers: [navigation],
          home: Builder(
            builder: (context) {
              router = GoRouter.of(context);
              return const Text('主页');
            },
          ),
          routes: {'/other': (_) => const Text('外部目的地')},
        ),
      );
      navigation.request(book);
      await tester.pump();
      expect(preparing, isTrue);
      if (cancel == '外部动作') navigation.preferExternalAction();
      if (cancel == '应用卸载') navigation.dispose();
      if (cancel == '其它页面') {
        router.pushAppRoute('/other');
        await tester.pumpAndSettle();
      }
      ready.complete();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
    });
  }
  testWidgets('外部入口先到达时，欢迎页之后的恢复请求不覆盖它', (tester) async {
    var opened = 0;
    final navigation = StartupReadingNavigation(
      open: (_, _) async {
        opened++;
      },
      onError: (e, s) => fail('$e'),
    );
    addTearDown(navigation.dispose);
    navigation.preferExternalAction();
    await tester.pumpWidget(
      RoutingTestApp(navigatorObservers: [navigation], home: const Text('主页')),
    );
    navigation.request(book);
    await tester.pumpAndSettle();
    expect(opened, 0);
  });
}
