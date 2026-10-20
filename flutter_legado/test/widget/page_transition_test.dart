// 沿用现有转场用例，检查应用主题默认值、导航完成与返回行为。
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_legado/src/theme/app_theme.dart';

void main() {
  test('明暗主题使用各平台默认转场', () {
    final defaults = ThemeData().pageTransitionsTheme;
    expect(AppTheme.light.pageTransitionsTheme, defaults);
    expect(AppTheme.dark.pageTransitionsTheme, defaults);
  });

  Future<MaterialPageRoute<String>> pumpTwoPages(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: Text('底页A'))),
      ),
    );
    final route = MaterialPageRoute<String>(
      builder: (_) => const Scaffold(body: Center(child: Text('进页B'))),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).push(route);
    await tester.pump();
    await tester.pump(route.transitionDuration ~/ 2);
    return route;
  }

  testWidgets('进页沿用默认时长并播放动画', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final route = await pumpTwoPages(tester);
      final builder =
          ThemeData().pageTransitionsTheme.builders[TargetPlatform.android]!;
      expect(route.transitionDuration, builder.transitionDuration);
      expect(route.animation!.value, greaterThan(0));
      expect(route.animation!.value, lessThan(1));
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('转场结束后显示新页面，旧页面仍保留在栈中', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpTwoPages(tester);
      await tester.pumpAndSettle();
      expect(find.text('进页B'), findsOneWidget);
      expect(find.text('底页A'), findsNothing);
      expect(find.text('底页A', skipOffstage: false), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('返回动画恢复底页并传回结果', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final route = await pumpTwoPages(tester);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop('已完成');
      await tester.pump();
      await tester.pump(route.reverseTransitionDuration ~/ 2);
      expect(route.animation!.value, greaterThan(0));
      expect(route.animation!.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('底页A'), findsOneWidget);
      expect(find.text('进页B'), findsNothing);
      expect(await route.popped, '已完成');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
