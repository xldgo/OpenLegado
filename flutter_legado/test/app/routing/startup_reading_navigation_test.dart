import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/app/routing/app_navigation.dart';
import 'package:flutter_legado/src/app/routing/startup_reading_navigation.dart';
import 'package:flutter_legado/src/models/book.dart';
import 'package:flutter_legado/src/widgets/crash_log_dialog.dart';

import '../../fixtures/routing_test_app.dart';

void main() {
  const book = Book(bookUrl: 'last', name: '上次阅读', durChapterTime: 1);
  testWidgets('请求先于主页入栈：主页入栈后恢复一次，不重复打开', (tester) async {
    final opened = <Book>[];
    final navigation = StartupReadingNavigation(
      open: (book, current) async {
        if (current()) opened.add(book);
      },
      onError: (e, s) => fail('$e'),
    );
    addTearDown(navigation.dispose);
    // 冷启动「默认进入阅读」在 Router 首帧前就发起请求（见 app.dart
    // initState），此时还没有任何路由入栈。
    navigation.request(book);
    await tester.pumpWidget(
      RoutingTestApp(navigatorObservers: [navigation], home: const Text('主页')),
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
  testWidgets('外部入口先到达时，迟到的恢复请求不覆盖它', (tester) async {
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

  for (final outcome in ['无入口', '外部入口', '失败', '卸载']) {
    testWidgets('初始入口判定未完成时不恢复，$outcome后正确收尾', (tester) async {
      final ready = Completer<void>();
      final opened = <Book>[];
      final errors = <Object>[];
      final navigation = StartupReadingNavigation(
        open: (book, current) async {
          if (current()) opened.add(book);
        },
        onError: (error, _) => errors.add(error),
      );
      addTearDown(navigation.dispose);
      navigation.waitForInitialActions(ready.future);
      navigation.request(book);
      await tester.pumpWidget(
        RoutingTestApp(
          navigatorObservers: [navigation],
          home: const Text('主页'),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      if (outcome == '外部入口') navigation.preferExternalAction();
      if (outcome == '卸载') navigation.dispose();
      if (outcome == '失败') {
        ready.completeError(StateError('初始入口失败'));
      } else {
        ready.complete();
      }
      await tester.pumpAndSettle();
      expect(opened, outcome == '无入口' ? [book] : isEmpty);
      expect(errors, outcome == '失败' ? hasLength(1) : isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final duringPreparation in [false, true]) {
    testWidgets('崩溃提示${duringPreparation ? '打断准备' : '先于请求'}，关闭后仅恢复一次', (
      tester,
    ) async {
      final ready = Completer<void>();
      final opened = <Book>[];
      var attempts = 0;
      final navigation = StartupReadingNavigation(
        open: (book, current) async {
          attempts++;
          if (duringPreparation && attempts == 1) await ready.future;
          if (current()) opened.add(book);
        },
        onError: (error, _) => fail('$error'),
      );
      addTearDown(navigation.dispose);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        RoutingTestApp(
          navigatorKey: key,
          navigatorObservers: [navigation],
          home: const Text('主页'),
        ),
      );
      if (duringPreparation) {
        navigation.request(book);
        await tester.pump();
        expect(attempts, 1);
      }
      unawaited(CrashLogDialog.show(key.currentContext!, '测试崩溃记录'));
      await tester.pumpAndSettle();
      if (duringPreparation) {
        ready.complete();
      } else {
        navigation.request(book);
      }
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(opened, [book]);
      expect(attempts, duringPreparation ? 2 : 1);
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
