import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/domain/models/auto_task_execution_result.dart';
import 'package:flutter_legado/src/providers/auto_task/auto_task_dependencies.dart';
import 'package:flutter_legado/src/providers/auto_task/auto_task_notifier.dart';
import 'package:flutter_legado/src/providers/providers.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);
  late AutoTaskRepositoryMock repository;
  late AutoTaskServiceMock service;
  late ProviderContainer container;
  const rule = AutoTaskRule(
    id: '1',
    name: '任务',
    comment: 'backup',
    cron: '0 * * * *',
    script: 'original()',
    loginUrl: 'login',
    loginUi: '[]',
    header: 'header',
    customOrder: 8,
    lastRunAt: 123,
    lastLog: '日志',
  );
  setUp(() {
    repository = AutoTaskRepositoryMock();
    service = AutoTaskServiceMock();
    container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((_) => throw StateError('不应访问根接口')),
        autoTaskRepositoryProvider.overrideWithValue(repository),
        autoTaskServiceProvider.overrideWithValue(service),
      ],
    );
  });
  tearDown(() => container.dispose());
  AutoTaskNotifier notifier() =>
      container.read(autoTaskNotifierProvider.notifier);
  AutoTaskState state() => container.read(autoTaskNotifierProvider);
  group('AutoTask 模型', () {
    test('fromJson 解析标准 Dart 风格字段', () {
      final json = {
        'id': 't1',
        'name': 'Refresh TOC',
        'taskType': 'refreshToc',
        'cron': '0 0 3 * * *',
        'isEnabled': true,
        'lastRunAt': '2025-01-01 03:00:00',
        'lastResult': 'Success',
      };
      final task = AutoTask.fromJson(json);

      expect(task.id, equals('t1'));
      expect(task.name, equals('Refresh TOC'));
      expect(task.taskType, equals('refreshToc'));
      expect(task.cron, equals('0 0 3 * * *'));
      expect(task.isEnabled, isTrue);
      expect(task.lastRunAt, equals('2025-01-01 03:00:00'));
      expect(task.lastResult, equals('Success'));
    });

    test('fromJson 兼容服务端 enable/comment 字段', () {
      final json = {
        'id': 't2',
        'name': 'Update Sources',
        'comment': 'updateSources',
        'cron': '0 0 4 * * *',
        'enable': false,
      };
      final task = AutoTask.fromJson(json);

      expect(task.id, equals('t2'));
      expect(task.taskType, equals('updateSources'));
      expect(task.isEnabled, isFalse);
    });

    test('fromJson lastRunAt 为毫秒时间戳时格式化', () {
      final millis = DateTime(2025, 1, 15, 8, 30, 0).millisecondsSinceEpoch;
      final json = {
        'id': 't3',
        'name': 'Backup',
        'taskType': 'backup',
        'cron': '0 0 2 * * *',
        'lastRunAt': millis,
      };
      final task = AutoTask.fromJson(json);
      expect(task.lastRunAt, equals('2025-01-15 08:30:00'));
    });

    test('toJson 输出服务端兼容格式', () {
      const task = AutoTask(
        id: 't1',
        name: 'Refresh',
        taskType: 'refreshToc',
        cron: '0 0 * * *',
        isEnabled: true,
      );
      final json = task.toJson();
      expect(json['enable'], isTrue);
      expect(json['comment'], equals('refreshToc'));
      expect(json['script'], equals('refreshToc()'));
    });

    test('toJson 保留已保存 script', () {
      const savedScript =
          '({"bookUrl":"http://a.com","generatedBy":"bookUpdate"})';
      final task = AutoTask.fromJson({
        'id': 't2',
        'name': 'Book Update',
        'comment': 'refreshToc',
        'cron': '0 */6 * * *',
        'script': savedScript,
      });
      expect(task.toJson()['script'], equals(savedScript));
    });

    test('taskTypeLabel 返回中文标签', () {
      expect(
        const AutoTask(
          id: '',
          name: '',
          taskType: 'refreshToc',
          cron: '',
        ).taskTypeLabel,
        equals('刷新目录'),
      );
      expect(
        const AutoTask(
          id: '',
          name: '',
          taskType: 'updateSources',
          cron: '',
        ).taskTypeLabel,
        equals('更新书源'),
      );
      expect(
        const AutoTask(
          id: '',
          name: '',
          taskType: 'backup',
          cron: '',
        ).taskTypeLabel,
        equals('自动备份'),
      );
    });
  });

  group('窄依赖与任务状态', () {
    test('初始状态不触发存储加载', () {
      expect(state().tasks, isEmpty);
      expect(state().isLoading, isFalse);
      verifyNever(() => repository.listRules());
    });
    test('列表成功加载完整规则，失败保留最近结果并显示错误', () async {
      when(() => repository.listRules()).thenAnswer((_) async => [rule]);
      await notifier().loadTasks();
      expect(state().tasks.single.toRule(), rule);
      when(() => repository.listRules()).thenThrow(StateError('不可读'));
      await notifier().loadTasks();
      expect(state().tasks.single.id, '1');
      expect(state().error, contains('加载任务失败'));
      expect(state().isLoading, isFalse);
    });
    test('静默刷新不发布loading', () async {
      when(() => repository.listRules()).thenAnswer((_) async => []);
      var loading = false;
      container.listen(autoTaskNotifierProvider, (_, next) {
        loading |= next.isLoading;
      });
      await notifier().loadTasks(silent: true);
      expect(loading, isFalse);
    });
    test('依赖获取失败也能形成可见错误', () async {
      final unavailable = ProviderContainer(
        overrides: [
          autoTaskRepositoryProvider.overrideWith(
            (_) => throw StateError('FFI 不可用'),
          ),
        ],
      );
      addTearDown(unavailable.dispose);
      await unavailable.read(autoTaskNotifierProvider.notifier).loadTasks();
      expect(
        unavailable.read(autoTaskNotifierProvider).error,
        contains('FFI 不可用'),
      );
    });
    test('创建成功刷新，创建失败返回false', () async {
      when(() => repository.createRule(any())).thenAnswer((_) async => '1');
      when(() => repository.listRules()).thenAnswer((_) async => [rule]);
      expect(await notifier().createRule(rule), isTrue);
      expect(state().tasks.single.id, '1');
      when(() => repository.createRule(any())).thenThrow(StateError('不可写'));
      expect(await notifier().createTask(AutoTask.fromRule(rule)), isFalse);
      expect(state().error, contains('创建任务失败'));
    });
    test('完整规则模型编辑保留脚本、登录、排序和运行字段', () {
      final edited = AutoTask.fromRule(rule)
          .copyWith(name: '改名', cron: 'new', isEnabled: false)
          .toRule();
      expect(edited, rule.copyWith(name: '改名', cron: 'new', enable: false));
    });
    test('启停只更新enable，写入失败回滚', () async {
      when(() => repository.listRules()).thenAnswer((_) async => [rule]);
      when(() => repository.updateRule(any())).thenAnswer((_) async {});
      await notifier().loadTasks();
      await notifier().toggleTask('1', false);
      final saved =
          verify(() => repository.updateRule(captureAny())).captured.single
              as AutoTaskRule;
      expect(saved, rule.copyWith(enable: false));
      when(() => repository.updateRule(any())).thenThrow(StateError('失败'));
      await notifier().toggleTask('1', false);
      expect(state().tasks.single.isEnabled, isTrue);
      expect(state().error, contains('更新任务失败'));
    });
    test('更新保留ID，缺ID拒绝写入', () async {
      expect(await notifier().updateRule(const AutoTaskRule()), isFalse);
      verifyNever(() => repository.updateRule(any()));
      when(() => repository.updateRule(any())).thenAnswer((_) async {});
      when(() => repository.listRules()).thenAnswer((_) async => [rule]);
      expect(await notifier().updateRule(rule), isTrue);
      verify(() => repository.updateRule(rule)).called(1);
      verifyNever(() => repository.deleteRule(any()));
    });
    test('删除成功刷新，失败保留错误', () async {
      when(() => repository.deleteRule('1')).thenAnswer((_) async {});
      when(() => repository.listRules()).thenAnswer((_) async => []);
      expect(await notifier().deleteTask('1'), isTrue);
      when(() => repository.deleteRule('1')).thenThrow(StateError('失败'));
      expect(await notifier().deleteTask('1'), isFalse);
      expect(state().error, contains('删除任务失败'));
    });
    for (final success in [true, false]) {
      test('执行结果$success更新展示状态，保留现有协议', () async {
        when(() => repository.listRules()).thenAnswer((_) async => [rule]);
        when(
          () => service.execute(
            protocol: any(named: 'protocol'),
            taskId: '1',
          ),
        ).thenAnswer((_) async => AutoTaskExecutionResult(success: success));
        await notifier().loadTasks();
        await notifier().runNow('1');
        expect(state().tasks.single.lastResult, success ? '成功' : '失败');
        verify(
          () => service.execute(
            protocol: {'action': 'backup', 'taskId': '1'},
            taskId: '1',
          ),
        ).called(1);
      });
    }
    test('执行异常形成可见错误', () async {
      when(
        () => service.execute(
          protocol: any(named: 'protocol'),
          taskId: '1',
        ),
      ).thenThrow(StateError('执行失败'));
      await notifier().runNow('1');
      expect(state().error, contains('运行任务失败'));
    });
  });
  group('任务计算委托', () {
    test('构建与cron、脚本、许可和下次时间使用同一窄服务', () async {
      when(
        () => service.buildBookUpdateTask(
          bookUrl: 'b',
          bookName: '书',
          bookAuthor: '作者',
          name: '更新',
        ),
      ).thenAnswer((_) async => rule);
      when(
        () => service.updateCronBatch(rules: [rule], ids: ['1'], cron: 'new'),
      ).thenAnswer((_) async => [rule.copyWith(cron: 'new')]);
      when(
        () => service.prepareImportedTasks(
          localTasks: [rule],
          importedJson: 'raw',
        ),
      ).thenAnswer((_) async => [rule]);
      when(() => service.normalizeScript('@js:x')).thenAnswer((_) async => 'x');
      when(
        () => service.canRefreshBookToc(
          canUpdate: false,
          respectCanUpdate: false,
        ),
      ).thenAnswer((_) async => true);
      when(() => service.nextDueAt(cron: 'cron', fromMs: 123))
          .thenAnswer((_) async => 456);
      expect(
        await notifier().buildBookUpdateTask(
          bookUrl: 'b',
          bookName: '书',
          bookAuthor: '作者',
          name: '更新',
        ),
        rule,
      );
      expect(
        (await notifier().updateCronBatch(
          rules: [rule],
          ids: ['1'],
          cron: 'new',
        ))!.single.cron,
        'new',
      );
      expect(
        await notifier().prepareImportedTasks(
          localTasks: [rule],
          importedJson: 'raw',
        ),
        [rule],
      );
      expect(await notifier().normalizeScript('@js:x'), 'x');
      expect(
        await notifier().canRefreshBookToc(
          canUpdate: false,
          respectCanUpdate: false,
        ),
        isTrue,
      );
      expect(await notifier().nextDueAt(cron: 'cron', fromMs: 123), 456);
    });
    test('列表失败时使用最近完整规则进行匹配', () async {
      when(() => repository.listRules()).thenThrow(StateError('不可读'));
      notifier().state = state().copyWith(tasks: [AutoTask.fromRule(rule)]);
      when(
        () => service.findBookUpdateTask(
          tasks: any(named: 'tasks'),
          bookUrl: 'b',
          bookName: '书',
          bookAuthor: '作者',
        ),
      ).thenAnswer((call) async {
        expect(call.namedArguments[#tasks], [rule]);
        return rule;
      });
      expect(
        await notifier().findBookUpdateTask(
          bookUrl: 'b',
          bookName: '书',
          bookAuthor: '作者',
        ),
        rule,
      );
    });
    test('服务失败保留可选查询失败语义', () async {
      when(() => service.nextDueAt(cron: 'invalid', fromMs: 123))
          .thenThrow(StateError('失败'));
      expect(await notifier().nextDueAt(cron: 'invalid', fromMs: 123), isNull);
    });
  });
}
