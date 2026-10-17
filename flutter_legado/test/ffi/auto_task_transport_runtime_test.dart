library;

@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_legado/src/bridge/ffi/ffi.dart' as bridge;
import 'package:flutter_legado/src/data/bridge/rust_runtime.dart';
import 'package:flutter_legado/src/data/repositories/rust_auto_task_repository.dart';
import 'package:flutter_legado/src/data/services/rust_auto_task_service.dart';
import 'package:flutter_legado/src/models/misc.dart';

void main() {
  if (!Platform.isWindows) {
    test('需要Windows DLL', () {}, skip: true);
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  const repository = RustAutoTaskRepository();
  const service = RustAutoTaskService();
  setUpAll(() async {
    final root = Directory(
      '.dart_tool/auto-task-transport-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    await const NativeRustRuntime().initialize();
    await bridge.dbOpen(path: '${root.absolute.path}/data.db');
  });
  const rule = AutoTaskRule(
    id: '完整任务😀',
    name: '任务',
    enable: false,
    cron: '*/30 * * * *',
    loginUrl: 'login()',
    loginUi: '[]',
    loginCheckJs: 'result',
    comment: '注释',
    script: '1+1',
    header: '{"X":"value"}',
    jsLib: 'var x=1;',
    concurrentRate: '1000',
    enabledCookieJar: false,
    customOrder: -7,
    lastRunAt: 9007199254740993,
    lastResult: 'result',
    lastError: 'error',
    lastLog: 'log',
  );
  test('十八字段经真实wire和SQLite往返，更新不改变ID', () async {
    expect(await repository.createRule(rule), rule.id);
    expect(await repository.findRuleById(rule.id), rule);
    expect(await repository.listRules(), [rule]);
    final updated = rule.copyWith(name: '改名', cron: null);
    await repository.updateRule(updated);
    expect(await repository.findRuleById(rule.id), updated);
    await repository.deleteRule(rule.id);
    expect(await repository.findRuleById(rule.id), isNull);
  });
  test('核心计算不丢登录字段，导入重复覆盖且保留本地运行记录', () async {
    expect(
      (await service.updateCronBatch(
        rules: [rule],
        ids: [rule.id],
        cron: 'new',
      )).single,
      rule.copyWith(cron: 'new'),
    );
    final bookTask = (await service.buildBookUpdateTask(
      bookUrl: 'book',
      bookName: '书',
      bookAuthor: '作者',
      name: '更新',
    )).copyWith(header: 'keep', enabledCookieJar: false);
    expect(
      await service.findBookUpdateTask(
        tasks: [bookTask],
        bookUrl: 'book',
        bookName: '书',
        bookAuthor: '作者',
      ),
      bookTask,
    );
    expect(
      await service.findBookUpdateTask(
        tasks: [],
        bookUrl: 'none',
        bookName: '书',
        bookAuthor: '作者',
      ),
      isNull,
    );
    const document =
        '[{"id":"完整任务😀","name":"first","header":"discard"},{"id":"完整任务😀","name":"last","header":"keep"},{"id":"new","name":"新"}]';
    final merged = await service.prepareImportedTasks(
      localTasks: [rule],
      importedJson: document,
    );
    expect(merged.length, 2);
    expect(merged.first.name, 'last');
    expect(merged.first.header, 'keep');
    expect(merged.first.lastRunAt, rule.lastRunAt);
    expect(merged.first.lastLog, rule.lastLog);
    expect(merged.first.customOrder, rule.customOrder);
    expect(merged.last.customOrder, rule.customOrder + 1);
    await expectLater(
      service.prepareImportedTasks(
        localTasks: [],
        importedJson: '[{"id":"missing-name"}]',
      ),
      throwsA(anything),
    );
  });
  test('真实QuickJS执行与失败结果按类型传递，坏协议报错', () async {
    final success = await service.execute(
      protocol: {
        'action': {'Custom': '1+1'},
      },
      taskId: rule.id,
    );
    expect(success.success, isTrue);
    expect(success.taskId, rule.id);
    expect(success.message, '2');
    expect(success.durationMs, greaterThanOrEqualTo(0));
    final failed = await service.execute(
      protocol: {
        'action': {'Custom': 'throw new Error("fail")'},
      },
    );
    expect(failed.success, isFalse);
    expect(failed.message, contains('fail'));
    await expectLater(service.execute(protocol: {}), throwsA(anything));
  });
}
