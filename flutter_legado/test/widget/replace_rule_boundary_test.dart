import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import 'dart:convert';

import 'package:flutter_legado/src/data/repositories/mock_replace_rule_repository.dart';
import 'package:flutter_legado/src/domain/contracts/replace_rule_service.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/providers/replace_rule_repository_provider.dart';
import 'package:flutter_legado/src/screens/replace_rule_edit_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _Service extends Mock implements ReplaceRuleService {}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('编辑器只依赖规则仓储和服务，预览后保存并返回', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var nextId = 1;
    final repository = MockReplaceRuleRepository(nextId: () => nextId++);
    final rule = await repository.addReplaceRule(
      const ReplaceRule(
        name: '原规则',
        pattern: '旧',
        replacement: '新',
        isRegex: false,
      ),
    );
    final service = _Service();
    when(() => service.previewReplaceRule(any(), any()))
        .thenAnswer((_) async => '⚠️ 执行超时');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          replaceRuleRepositoryProvider.overrideWithValue(repository),
          replaceRuleServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    ReplaceRuleEditScreen.open(context, rule: rule),
                child: const Text('打开规则'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, '打开规则'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_field('规则名称')).controller!.text, '原规则');
    await tester.enterText(_field('规则名称'), '修改规则');
    await tester.enterText(_field('预览输入'), '旧正文');
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<TextField>(_field('预览输出')).controller!.text,
      '⚠️ 执行超时',
    );
    final invocation = verify(
      () => service.previewReplaceRule(captureAny(), captureAny()),
    );
    expect(invocation.captured.last, '旧正文');
    expect(
      (jsonDecode(invocation.captured.first as String)
          as Map<String, dynamic>)['name'],
      '修改规则',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('打开规则'), findsOneWidget);
    expect((await repository.getReplaceRules()).single.name, '修改规则');
    expect((await repository.getReplaceRules()).single.id, rule.id);
    expect(tester.takeException(), isNull);
  });
}
