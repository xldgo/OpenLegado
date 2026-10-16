import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_auto_task_repository.dart';
import 'package:flutter_legado/src/data/services/rust_auto_task_service.dart';
import 'package:flutter_legado/src/models/misc.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustAutoTaskRepository();
  const service = RustAutoTaskService();
  const rule = AutoTaskRule(
    id: '1',
    name: '任务',
    enable: false,
    cron: 'old',
    script: 'script',
    loginUrl: 'login',
    loginUi: 'ui',
    loginCheckJs: 'check',
    comment: 'backup',
    header: 'header',
    jsLib: 'lib',
    concurrentRate: '2',
    enabledCookieJar: false,
    customOrder: 7,
    lastRunAt: 123,
    lastResult: 'result',
    lastError: 'error',
    lastLog: 'log',
  );
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('CRUD读取与写入保留完整规则，JSON由适配器编码', () async {
    when(() => bridge.crateFfiFfiAutoTaskListRules())
        .thenAnswer((_) async => jsonEncode([rule.toJson()]));
    when(() => bridge.crateFfiFfiAutoTaskFindRuleById(id: '1'))
        .thenAnswer((_) async => jsonEncode(rule.toJson()));
    when(
      () => bridge.crateFfiFfiAutoTaskCreateRule(
        ruleJson: any(named: 'ruleJson'),
      ),
    ).thenAnswer((call) async {
      expect(
        jsonDecode(call.namedArguments[#ruleJson] as String),
        rule.toJson(),
      );
      return '1';
    });
    when(
      () => bridge.crateFfiFfiAutoTaskUpdateRule(
        ruleJson: any(named: 'ruleJson'),
      ),
    ).thenAnswer((call) async {
      expect(
        jsonDecode(call.namedArguments[#ruleJson] as String),
        rule.toJson(),
      );
    });
    when(() => bridge.crateFfiFfiAutoTaskDeleteRule(id: '1'))
        .thenAnswer((_) async {});
    expect(await repository.listRules(), [rule]);
    expect(await repository.findRuleById('1'), rule);
    expect(await repository.createRule(rule), '1');
    await repository.updateRule(rule);
    await repository.deleteRule('1');
    verify(() => bridge.crateFfiFfiAutoTaskDeleteRule(id: '1')).called(1);
  });
  for (final payload in ['{}', '[{}]', '[1]']) {
    test('错误规则列表不当空列表：$payload', () async {
      when(() => bridge.crateFfiFfiAutoTaskListRules())
          .thenAnswer((_) async => payload);
      await expectLater(repository.listRules(), throwsFormatException);
    });
  }
  test('查询未命中为null，CRUD异常向上传递', () async {
    when(() => bridge.crateFfiFfiAutoTaskFindRuleById(id: 'none'))
        .thenAnswer((_) async => 'null');
    expect(await repository.findRuleById('none'), isNull);
    final error = StateError('数据库不可写');
    when(
      () => bridge.crateFfiFfiAutoTaskCreateRule(
        ruleJson: any(named: 'ruleJson'),
      ),
    ).thenThrow(error);
    when(
      () => bridge.crateFfiFfiAutoTaskUpdateRule(
        ruleJson: any(named: 'ruleJson'),
      ),
    ).thenThrow(error);
    when(() => bridge.crateFfiFfiAutoTaskDeleteRule(id: '1')).thenThrow(error);
    await expectLater(() => repository.createRule(rule), throwsA(same(error)));
    await expectLater(() => repository.updateRule(rule), throwsA(same(error)));
    await expectLater(() => repository.deleteRule('1'), throwsA(same(error)));
  });
  test('构建结果的Rust纯计算字段正确归一化', () async {
    when(
      () => bridge.crateFfiFfiAutoTaskBuildBookUpdate(
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
        name: '更新',
      ),
    ).thenAnswer(
      (_) async => '{"id":"book_update:id","name":"更新","script":"action","custom_order":9,"last_run_at":456,"last_log":"log"}',
    );
    final result = await service.buildBookUpdateTask(
      bookUrl: 'b',
      bookName: '书',
      bookAuthor: '作者',
      name: '更新',
    );
    expect(result.id, 'book_update:id');
    expect(result.customOrder, 9);
    expect(result.lastRunAt, 456);
    expect(result.lastLog, 'log');
  });
  test('批量cron传入正确core字段，返回仍保留登录和运行数据', () async {
    when(
      () => bridge.crateFfiFfiAutoTaskUpdateCronBatch(
        rulesJson: any(named: 'rulesJson'),
        idsJson: '["1"]',
        cron: 'new',
      ),
    ).thenAnswer((call) async {
      final input =
          (jsonDecode(call.namedArguments[#rulesJson] as String) as List).single
              as Map<String, dynamic>;
      expect(input['custom_order'], 7);
      expect(input['last_run_at'], 123);
      expect(input['last_log'], 'log');
      return jsonEncode([
        {...input, 'cron': 'new'},
      ]);
    });
    final result = await service.updateCronBatch(
      rules: [rule],
      ids: ['1'],
      cron: 'new',
    );
    expect(result.single, rule.copyWith(cron: 'new'));
  });
  test('导入准备传入本地真实排序/运行记录，保留原始导入文本', () async {
    const imported = '[{"id":"1","name":"导入","script":"new"}]';
    when(
      () => bridge.crateFfiFfiAutoTaskPrepareImported(
        localTasksJson: any(named: 'localTasksJson'),
        importedJson: imported,
      ),
    ).thenAnswer((call) async {
      final local =
          (jsonDecode(
                call.namedArguments[#localTasksJson] as String,
              ) as List).single
              as Map;
      expect(local['last_run_at'], 123);
      expect(local['custom_order'], 7);
      return jsonEncode([rule.copyWith(name: '导入', script: 'new').toJson()]);
    });
    final result = await service.prepareImportedTasks(
      localTasks: [rule],
      importedJson: imported,
    );
    expect(result.single, rule.copyWith(name: '导入', script: 'new'));
  });
  test('书籍任务查找使用完整脚本并合回数据库专属字段', () async {
    when(
      () => bridge.crateFfiFfiAutoTaskFindBookUpdate(
        tasksJson: any(named: 'tasksJson'),
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
      ),
    ).thenAnswer((call) async {
      final task =
          (jsonDecode(call.namedArguments[#tasksJson] as String) as List).single
              as Map;
      expect(task['script'], 'script');
      return jsonEncode(task);
    });
    expect(
      await service.findBookUpdateTask(
        tasks: [rule],
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
      ),
      rule,
    );
  });
  for (final taskId in <String?>[null, '1']) {
    test('执行入口按taskId=$taskId分派并返回类型化结果', () async {
      const protocol = {'action': 'Backup', 'params': <String, String>{}};
      const raw =
          '{"task_id":"1","success":false,"message":"失败","duration_ms":34,"details":"日志"}';
      if (taskId == null) {
        when(
          () => bridge.crateFfiFfiAutoTaskExecute(
            protocolJson: jsonEncode(protocol),
          ),
        ).thenAnswer((_) async => raw);
      } else {
        when(
          () => bridge.crateFfiFfiAutoTaskExecuteWithId(
            protocolJson: jsonEncode(protocol),
            taskId: '1',
          ),
        ).thenAnswer((_) async => raw);
      }
      final result = await service.execute(protocol: protocol, taskId: taskId);
      expect(result.taskId, '1');
      expect(result.success, isFalse);
      expect(result.message, '失败');
      expect(result.durationMs, 34);
      expect(result.details, '日志');
    });
  }
  test('执行坏响应不伪造成功，真实异常不吞掉', () async {
    when(() => bridge.crateFfiFfiAutoTaskExecute(protocolJson: '{}'))
        .thenAnswer((_) async => '{}');
    await expectLater(service.execute(protocol: {}), throwsFormatException);
    when(() => bridge.crateFfiFfiAutoTaskExecute(protocolJson: '{}'))
        .thenThrow(StateError('执行器失败'));
    await expectLater(service.execute(protocol: {}), throwsStateError);
  });
  test('脚本、刷新许可与调度时间保留原始参数及-1含义', () async {
    when(() => bridge.crateFfiFfiAutoTaskNormalizeScript(script: '@js:x'))
        .thenAnswer((_) async => 'x');
    when(
      () => bridge.crateFfiFfiAutoTaskCanRefreshToc(
        canUpdate: false,
        respectCanUpdate: true,
      ),
    ).thenAnswer((_) async => false);
    when(
      () => bridge.crateFfiFfiAutoTaskNextDueAt(cron: 'invalid', fromMs: 123),
    ).thenAnswer((_) async => -1);
    expect(await service.normalizeScript('@js:x'), 'x');
    expect(
      await service.canRefreshBookToc(canUpdate: false, respectCanUpdate: true),
      isFalse,
    );
    expect(await service.nextDueAt(cron: 'invalid', fromMs: 123), -1);
  });
}
