import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/automation_dto.dart';
import 'package:flutter_legado/src/data/bridge/auto_task_dto_mapping.dart';
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
  setUpAll(() => registerFallbackValue(autoTaskToDto(rule)));
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('CRUD直接传输完整十八字段且不丢登录和运行状态', () async {
    final dto = autoTaskToDto(rule);
    when(() => bridge.crateFfiFfiAutoTaskListRules())
        .thenAnswer((_) async => [dto]);
    when(() => bridge.crateFfiFfiAutoTaskFindRuleById(id: '1'))
        .thenAnswer((_) async => dto);
    when(() => bridge.crateFfiFfiAutoTaskCreateRule(rule: any(named: 'rule')))
        .thenAnswer((call) async {
          expect(
            autoTaskFromDto(call.namedArguments[#rule] as AutoTaskRuleDto),
            rule,
          );
          return '1';
        });
    when(() => bridge.crateFfiFfiAutoTaskUpdateRule(rule: any(named: 'rule')))
        .thenAnswer((call) async {
          expect(
            autoTaskFromDto(call.namedArguments[#rule] as AutoTaskRuleDto),
            rule,
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
  test('Option未命中为空，原生失败仍向上传递', () async {
    when(() => bridge.crateFfiFfiAutoTaskFindRuleById(id: 'none'))
        .thenAnswer((_) async => null);
    expect(await repository.findRuleById('none'), isNull);
    final error = StateError('数据库不可写');
    when(() => bridge.crateFfiFfiAutoTaskCreateRule(rule: any(named: 'rule')))
        .thenThrow(error);
    await expectLater(() => repository.createRule(rule), throwsA(same(error)));
  });
  test('构建结果直接映射，批量cron传输完整实体与ID列表', () async {
    when(
      () => bridge.crateFfiFfiAutoTaskBuildBookUpdate(
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
        name: '更新',
      ),
    ).thenAnswer((_) async => autoTaskToDto(rule));
    expect(
      await service.buildBookUpdateTask(
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
        name: '更新',
      ),
      rule,
    );
    when(
      () => bridge.crateFfiFfiAutoTaskUpdateCronBatch(
        rules: any(named: 'rules'),
        ids: ['1'],
        cron: 'new',
      ),
    ).thenAnswer((call) async {
      expect(
        (call.namedArguments[#rules] as List<AutoTaskRuleDto>).map(
          autoTaskFromDto,
        ),
        [rule],
      );
      return [autoTaskToDto(rule.copyWith(cron: 'new'))];
    });
    expect(
      (await service.updateCronBatch(
        rules: [rule],
        ids: ['1'],
        cron: 'new',
      )).single,
      rule.copyWith(cron: 'new'),
    );
  });
  test('导入文本不改写，本地规则与结果直接传输', () async {
    const document = '[{"id":"1","name":"导入","script":"x"}]';
    when(
      () => bridge.crateFfiFfiAutoTaskPrepareImported(
        localTasks: any(named: 'localTasks'),
        importedJson: document,
      ),
    ).thenAnswer((call) async {
      expect(
        autoTaskFromDto(
          (call.namedArguments[#localTasks] as List<AutoTaskRuleDto>).single,
        ),
        rule,
      );
      return [autoTaskToDto(rule.copyWith(name: '导入'))];
    });
    expect(
      (await service.prepareImportedTasks(
        localTasks: [rule],
        importedJson: document,
      )).single,
      rule.copyWith(name: '导入'),
    );
  });
  test('书籍任务完整实体及未命中Option保留', () async {
    when(
      () => bridge.crateFfiFfiAutoTaskFindBookUpdate(
        tasks: any(named: 'tasks'),
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
      ),
    ).thenAnswer((_) async => autoTaskToDto(rule));
    expect(
      await service.findBookUpdateTask(
        tasks: [rule],
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
      ),
      rule,
    );
    when(
      () => bridge.crateFfiFfiAutoTaskFindBookUpdate(
        tasks: any(named: 'tasks'),
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
      ),
    ).thenAnswer((_) async => null);
    expect(
      await service.findBookUpdateTask(
        tasks: [rule],
        bookUrl: 'b',
        bookName: '书',
        bookAuthor: '作者',
      ),
      isNull,
    );
  });
  for (final taskId in <String?>[null, '1']) {
    test('执行协议保留JSON，结果taskId=$taskId直接映射', () async {
      const protocol = {'action': 'Backup', 'params': <String, String>{}};
      final result = TaskResultDto(
        taskId: '1',
        success: false,
        message: '失败',
        durationMs: BigInt.from(9007199254740993),
        details: '日志',
      );
      if (taskId == null) {
        when(
          () => bridge.crateFfiFfiAutoTaskExecute(
            protocolJson: jsonEncode(protocol),
          ),
        ).thenAnswer((_) async => result);
      } else {
        when(
          () => bridge.crateFfiFfiAutoTaskExecuteWithId(
            protocolJson: jsonEncode(protocol),
            taskId: taskId,
          ),
        ).thenAnswer((_) async => result);
      }
      final actual = await service.execute(protocol: protocol, taskId: taskId);
      expect(actual.success, isFalse);
      expect(actual.taskId, '1');
      expect(actual.message, '失败');
      expect(actual.durationMs, 9007199254740993);
      expect(actual.details, '日志');
    });
  }
  test('失败不吞掉，显式i32范围校验不截断', () async {
    when(() => bridge.crateFfiFfiAutoTaskExecute(protocolJson: '{}'))
        .thenThrow(StateError('执行器失败'));
    await expectLater(service.execute(protocol: {}), throwsStateError);
    expect(
      () => autoTaskToDto(rule.copyWith(customOrder: 2147483648)),
      throwsRangeError,
    );
  });
  test('脚本、刷新许可与调度时间保留标量含义', () async {
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
