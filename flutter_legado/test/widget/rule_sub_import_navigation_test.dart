import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_legado/src/features/rules/application/subscriptions/rule_sub_import_provider.dart';
import 'package:flutter_legado/src/features/rules/application/subscriptions/rule_sub_import_service.dart';
import 'package:flutter_legado/src/features/rules/presentation/rule_sub_screen.dart';
import 'package:flutter_legado/src/data/repositories/mock_rule_sub_repository.dart';
import 'package:flutter_legado/src/providers/rule_sub_repository_provider.dart';
import 'package:flutter_legado/src/models/models.dart';

class _Import extends Fake implements RuleSubImportService {
  final completer = Completer<RuleSubImportPreview>();
  int calls = 0;
  @override
  Future<RuleSubImportPreview> prepare(
    RuleSub sub, {
    List<BookSource> localBookSources = const [],
  }) {
    calls++;
    return completer.future;
  }
}

void main() {
  testWidgets('取消加载后迟到结果不打开确认页，也不弹出其他页面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MockRuleSubRepository();
    await repo.ruleSubSave(
      const RuleSub(name: '订阅', url: 'https://sub', subType: RuleSub.rssSource),
    );
    final service = _Import();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ruleSubRepositoryProvider.overrideWithValue(repo),
          ruleSubImportServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: const RuleSubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('订阅'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.calls, 1);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('后开的页面')),
      ),
    );
    await tester.pumpAndSettle();
    service.completer.complete(
      RuleSubRssSources([
        {'sourceUrl': 'a'},
      ], []),
    );
    await tester.pumpAndSettle();
    expect(find.text('后开的页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
