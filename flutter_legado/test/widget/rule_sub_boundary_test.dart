import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';
import 'package:flutter_legado/src/data/repositories/mock_rule_sub_repository.dart';
import 'package:flutter_legado/src/domain/models/rule_sub_update_result.dart';
import 'package:flutter_legado/src/models/rule_sub.dart';
import 'package:flutter_legado/src/providers/rule_sub_repository_provider.dart';
import 'package:flutter_legado/src/features/rules/presentation/rule_sub_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mocks.dart';

void main() {
  Future<void> showPage(
    WidgetTester tester,
    MockRuleSubRepository repository,
    RuleSubServiceMock service,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ruleSubRepositoryProvider.overrideWithValue(repository),
          ruleSubServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: RuleSubScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('独立注入后可新增订阅、重新加载并持久化启停', (tester) async {
    final repository = MockRuleSubRepository();
    await showPage(tester, repository, RuleSubServiceMock());
    await tester.tap(find.byTooltip('新增订阅'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.enterText(field('名称'), '新增订阅名称');
    await tester.enterText(field('URL'), 'https://example.com/sub.json');
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('新增订阅名称'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final saved = (await repository.ruleSubList()).single;
    expect(saved.url, 'https://example.com/sub.json');
    expect(saved.customOrder, 1);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await repository.ruleSubList()).single.isEnabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('检查更新展示版本，应用更新展示统计且关闭加载框', (tester) async {
    final repository = MockRuleSubRepository();
    await repository.ruleSubSave(const RuleSub(name: '测试订阅', url: 'https://a'));
    final service = RuleSubServiceMock();
    when(() => service.ruleSubCheckUpdate(id: 1)).thenAnswer(
      (_) async => const RuleSubCheckResult(
        id: 1,
        url: 'https://a',
        name: '测试订阅',
        dueForUpdate: true,
        hasUpdate: true,
        remoteVersion: 'v2',
      ),
    );
    when(() => service.ruleSubApplyUpdate(id: 1)).thenAnswer(
      (_) async => const RuleSubApplyResult(
        id: 1,
        url: 'https://a',
        success: true,
        itemsAdded: 3,
        itemsUpdated: 2,
        itemsRemoved: 1,
        totalItems: 8,
      ),
    );
    await showPage(tester, repository, service);
    await tester.tap(find.byTooltip('更多选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本：v2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('更多选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用更新'));
    await tester.pumpAndSettle();
    // 等待上一条SnackBar退出，检查最新结果。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('更新完成：新增 3、更新 2、移除 1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('测试订阅'), findsOneWidget);
    verify(() => service.ruleSubCheckUpdate(id: 1)).called(1);
    verify(() => service.ruleSubApplyUpdate(id: 1)).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('更新失败展示原错误，不显示成功统计', (tester) async {
    final repository = MockRuleSubRepository();
    await repository.ruleSubSave(const RuleSub(name: '测试订阅', url: 'https://a'));
    final service = RuleSubServiceMock();
    when(() => service.ruleSubApplyUpdate(id: 1)).thenAnswer(
      (_) async => const RuleSubApplyResult(
        id: 1,
        url: 'https://a',
        success: false,
        itemsAdded: 0,
        itemsUpdated: 0,
        itemsRemoved: 0,
        totalItems: 0,
        error: '解析失败',
      ),
    );
    await showPage(tester, repository, service);
    await tester.tap(find.byTooltip('更多选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用更新'));
    await tester.pumpAndSettle();
    expect(find.text('应用更新失败：解析失败'), findsOneWidget);
    expect(find.textContaining('更新完成'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
