import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/domain/models/http_response.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/domain/models/auto_task.dart';
import 'package:flutter_legado/src/domain/models/auto_task_execution_result.dart';
import 'package:flutter_legado/src/providers/auto_task/auto_task_dependencies.dart';
import 'package:flutter_legado/src/features/automation/presentation/auto_task_screen.dart';
import 'package:flutter_legado/src/widgets/auto_task_debug_dialog.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late AutoTaskRepositoryMock repository;
  late AutoTaskServiceMock service;
  late MockRustApi api;
  late List<AutoTaskRule> rules;
  const original = AutoTaskRule(
    id: '1',
    name: '原任务',
    comment: 'backup',
    cron: '0 0 8 * * *',
    script: 'original()',
    loginUrl: 'login',
    header: 'header',
    customOrder: 7,
    lastRunAt: 123,
    lastLog: 'log',
  );
  setUp(() {
    repository = AutoTaskRepositoryMock();
    service = AutoTaskServiceMock();
    api = MockRustApi();
    rules = [original];
    when(() => repository.listRules()).thenAnswer((_) async => rules);
  });
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: mergeTestOverrides([
          ...api.overrides,
          autoTaskRepositoryProvider.overrideWithValue(repository),
          autoTaskServiceProvider.overrideWithValue(service),
        ]),
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('书籍任务编辑只更新名称和cron，不删除原规则或丢字段', (tester) async {
    when(() => repository.updateRule(any())).thenAnswer((call) async {
      rules = [call.positionalArguments.single as AutoTaskRule];
    });
    when(
      () => service.nextDueAt(
        cron: any(named: 'cron'),
        fromMs: any(named: 'fromMs'),
      ),
    ).thenAnswer((_) async => 123);
    await pump(tester, const AutoTaskScreen(initialEditTaskId: '1'));
    expect(find.text('编辑书籍更新任务'), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '改名');
    await tester.enterText(fields.at(1), '0 1 * * *');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('编辑书籍更新任务'), findsNothing);
    final saved =
        verify(() => repository.updateRule(captureAny())).captured.single
            as AutoTaskRule;
    expect(saved, original.copyWith(name: '改名', cron: '0 1 * * *'));
    verifyNever(() => repository.deleteRule(any()));
    verifyNever(() => repository.createRule(any()));
  });
  testWidgets('删除写入失败不显示成功提示', (tester) async {
    when(() => repository.deleteRule('1')).thenThrow(StateError('不可写'));
    await pump(tester, const AutoTaskScreen());
    await tester.longPress(find.text('原任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除失败'), findsOneWidget);
    expect(find.text('已删除任务: 原任务'), findsNothing);
  });
  testWidgets('线上导入只统计实际写入成功的任务', (tester) async {
    const second = AutoTaskRule(id: '2', name: '失败任务', script: 'b()');
    final imported = jsonEncode([original.toJson(), second.toJson()]);
    rules = [];
    when(
      () => api.networkService.httpGet(
        'https://example.test/tasks',
        timeout: const Duration(seconds: 15),
      ),
    ).thenAnswer(
      (_) async => HttpTextResponse(statusCode: 200, body: imported),
    );
    when(
      () => service.prepareImportedTasks(
        localTasks: any(named: 'localTasks'),
        importedJson: imported,
      ),
    ).thenAnswer((_) async => [original, second]);
    when(() => repository.createRule(any())).thenAnswer((call) async {
      final rule = call.positionalArguments.single as AutoTaskRule;
      if (rule.id == '2') throw StateError('不可写');
      rules = [rule];
      return rule.id;
    });
    await pump(tester, const AutoTaskScreen());
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入线上任务'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/tasks',
    );
    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    expect(find.text('导入任务'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('已导入 1 个任务'), findsOneWidget);
    expect(rules.single, original);
  });
  testWidgets('调试面板通过窄服务执行并显示类型化结果与日志', (tester) async {
    when(() => repository.findRuleById('1')).thenAnswer(
      (_) async => original.copyWith(script: '{"action":"Backup","params":{}}'),
    );
    when(
      () => service.execute(
        protocol: any(named: 'protocol'),
        taskId: '1',
      ),
    ).thenAnswer(
      (_) async => const AutoTaskExecutionResult(
        success: false,
        message: '任务被拒绝',
        details: '诊断信息',
      ),
    );
    await pump(
      tester,
      Scaffold(body: AutoTaskDebugDialog(task: AutoTask.fromRule(original))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.textContaining('任务被拒绝'), findsOneWidget);
    expect(find.textContaining('诊断信息'), findsOneWidget);
    verify(
      () => service.execute(
        protocol: {'action': 'Backup', 'params': <String, dynamic>{}},
        taskId: '1',
      ),
    ).called(1);
  });
}
