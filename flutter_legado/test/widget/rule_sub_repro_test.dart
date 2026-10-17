import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/models/rule_sub.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_legado/src/features/rules/presentation/rule_sub_screen.dart';

import '../mocks/mocks.dart';

/// 报障复现：规则订阅页空白渲染
///
/// 真机确认：顶栏正常但 body 全白（无 Loading/Error/Empty/列表任一分支）。
void main() {
  setUpAll(registerFallbacks);

  testWidgets('规则订阅页空数据渲染空态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.ruleSubRepository.ruleSubList())
        .thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: const MaterialApp(home: RuleSubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('暂无订阅'), findsOneWidget);
  });

  testWidgets('规则订阅页有数据渲染列表', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockApi = MockRustApi();
    when(() => mockApi.ruleSubRepository.ruleSubList()).thenAnswer(
      (_) async => [
        const RuleSub(
          id: 1,
          url: 'https://example.com/sub.json',
          name: '测试订阅',
          customOrder: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([...mockApi.overrides]),
        child: const MaterialApp(home: RuleSubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('测试订阅'), findsOneWidget);
  });
}
