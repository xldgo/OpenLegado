import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_legado/src/app/bootstrap/book_api_bootstrap.dart';
import 'package:flutter_legado/src/domain/models/auto_task.dart';
import 'package:flutter_legado/src/domain/models/auto_task_execution_result.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/providers/auto_task/auto_task_dependencies.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_legado/src/services/auto_task_scheduler.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const rule = AutoTaskRule(
    id: '1',
    name: '任务',
    cron: 'cron',
    script: 'js',
    loginUrl: 'login',
    header: 'header',
    customOrder: 5,
    lastRunAt: 123,
  );
  test('仓储、Provider和调用者共享完整Mock规则，按ID替换、排序与清理', () async {
    final api = MockBookApi();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final repository = container.read(autoTaskRepositoryProvider);
    expect(identical(repository, api.autoTaskRepository), isTrue);
    await repository.createRule(rule);
    await repository.createRule(rule.copyWith(name: '替换'));
    await repository.createRule(rule.copyWith(id: '2', customOrder: 1));
    expect((await repository.listRules()).map((r) => r.id), ['2', '1']);
    expect((await repository.findRuleById('1'))!.name, '替换');
    await repository.updateRule(rule.copyWith(enable: false));
    expect(await repository.findRuleById('1'), rule.copyWith(enable: false));
    await repository.deleteRule('1');
    expect(await repository.findRuleById('1'), isNull);
    await expectLater(repository.updateRule(rule), throwsStateError);
  });
  test('完整规则转展示模型再修改，不改变空脚本和可空字段', () {
    const original = AutoTaskRule(id: '1', name: '任务', script: '');
    expect(
      AutoTask.fromRule(original).copyWith(isEnabled: false).toRule(),
      original.copyWith(enable: false),
    );
  });
  test('服务窄接口可独立注入，正式装配不初始化原生库', () {
    final service = AutoTaskServiceMock();
    final repository = AutoTaskRepositoryMock();
    final container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((_) => throw StateError('不访问根接口')),
        autoTaskRepositoryProvider.overrideWithValue(repository),
        autoTaskServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(autoTaskRepositoryProvider), same(repository));
    expect(container.read(autoTaskServiceProvider), same(service));
    final api = createBookApi(useMock: false);
    expect(api.autoTaskRepository, same(api.autoTaskRepository));
    expect(api.autoTaskService, same(api.autoTaskService));
  });
  testWidgets('调度Timer按完整规则时间触发，禁用任务跳过，单任务失败不阻断整批', (tester) async {
    final repository = AutoTaskRepositoryMock();
    final service = AutoTaskServiceMock();
    final start = tester.binding.clock.now().millisecondsSinceEpoch;
    final rules = [
      rule.copyWith(cron: 'a', lastRunAt: start),
      rule.copyWith(id: '2', cron: 'b', lastRunAt: start),
      rule.copyWith(id: 'off', enable: false),
    ];
    when(() => repository.listRules()).thenAnswer((_) async => rules);
    when(
      () => service.nextDueAt(
        cron: any(named: 'cron'),
        fromMs: any(named: 'fromMs'),
      ),
    ).thenAnswer((call) async => (call.namedArguments[#fromMs] as int) + 1000);
    when(
      () => service.execute(
        protocol: any(named: 'protocol'),
        taskId: '1',
      ),
    ).thenThrow(StateError('单任务失败'));
    when(
      () => service.execute(
        protocol: any(named: 'protocol'),
        taskId: '2',
      ),
    ).thenAnswer((_) async => const AutoTaskExecutionResult(success: true));
    final scheduler = AutoTaskScheduler(
      nowMs: () => tester.binding.clock.now().millisecondsSinceEpoch,
    );
    addTearDown(() async {
      await scheduler.cancelAll();
      tester.binding.removeObserver(scheduler);
    });
    scheduler.attach(
      repository: repository,
      service: service,
      readEnabled: () async => true,
    );
    await tester.pump();
    verifyNever(
      () => service.execute(
        protocol: any(named: 'protocol'),
        taskId: any(named: 'taskId'),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    verify(
      () => service.execute(
        protocol: {'action': 'noop', 'taskId': '1'},
        taskId: '1',
      ),
    ).called(1);
    verify(
      () => service.execute(
        protocol: {'action': 'noop', 'taskId': '2'},
        taskId: '2',
      ),
    ).called(1);
    verifyNever(
      () => service.nextDueAt(
        cron: rule.cron!,
        fromMs: any(named: 'fromMs'),
      ),
    );
    clearInteractions(service);
    await scheduler.cancelAll();
    await tester.pump(const Duration(seconds: 2));
    verifyZeroInteractions(service);
  });
  testWidgets('总开关关闭不读取规则也不启动任务', (tester) async {
    final repository = AutoTaskRepositoryMock();
    final service = AutoTaskServiceMock();
    final scheduler = AutoTaskScheduler();
    addTearDown(() async {
      await scheduler.cancelAll();
      tester.binding.removeObserver(scheduler);
    });
    scheduler.attach(
      repository: repository,
      service: service,
      readEnabled: () async => false,
    );
    await tester.pump(const Duration(minutes: 10));
    verifyNever(() => repository.listRules());
    verifyZeroInteractions(service);
  });
}
