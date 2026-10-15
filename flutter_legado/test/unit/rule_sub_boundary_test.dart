import 'package:flutter_legado/src/data/repositories/mock_rule_sub_repository.dart';
import 'package:flutter_legado/src/domain/models/rule_sub_update_result.dart';
import 'package:flutter_legado/src/models/rule_sub.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/providers/rule_sub/rule_sub_notifier.dart';
import 'package:flutter_legado/src/providers/rule_sub_repository_provider.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  test('Mock装配共享订阅CRUD、启停和顺序，更新服务读取同一配置', () async {
    final api = MockBookApi();
    final repository = api.ruleSubRepository;
    final service = api.ruleSubService;
    await repository.ruleSubSave(
      const RuleSub(
        name: '原名',
        url: 'https://a',
        version: 'v1',
        customOrder: 2,
        autoUpdate: true,
        updateInterval: 24,
      ),
    );
    await repository.ruleSubSave(
      const RuleSub(name: '另一项', url: 'https://b', customOrder: 1),
    );
    final original = (await repository.ruleSubList()).last;
    await repository.ruleSubSave(original.copyWith(name: '修改', version: 'v2'));
    await repository.ruleSubSetEnabled(id: original.id, enabled: false);
    await repository.ruleSubUpdateOrder(ids: [original.id, 2]);
    final reloaded = await repository.ruleSubList();
    expect(reloaded.map((sub) => sub.id), [original.id, 2]);
    expect(reloaded.map((sub) => sub.customOrder), [0, 1]);
    expect(reloaded.first.isEnabled, isFalse);
    expect(reloaded.first.autoUpdate, isTrue);
    expect(reloaded.first.updateInterval, 24);
    final checked = await service.ruleSubCheckUpdate(id: original.id);
    expect(checked.name, '修改');
    expect(checked.remoteVersion, 'v2');
    expect(checked.hasUpdate, isFalse);
    final applied = await service.ruleSubApplyUpdate(id: original.id);
    expect(applied.success, isTrue);
    expect(applied.totalItems, 0);
    expect(await repository.ruleSubDelete(id: original.id), isTrue);
    expect((await service.ruleSubCheckUpdate(id: original.id)).error, '订阅不存在');
    expect(
      (await service.ruleSubApplyUpdate(id: original.id)).success,
      isFalse,
    );
    expect(await repository.ruleSubDelete(id: original.id), isFalse);
  });

  test('仓储可独立注入，Provider跟随根装配替换且默认服务共享注入仓储', () async {
    final repository = MockRuleSubRepository();
    final first = MockBookApi(ruleSubRepository: repository);
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    expect(container.read(ruleSubRepositoryProvider), same(repository));
    expect(container.read(ruleSubServiceProvider), same(first.ruleSubService));
    await repository.ruleSubSave(const RuleSub(name: '共享配置'));
    expect(
      (await container.read(ruleSubServiceProvider).ruleSubCheckUpdate(id: 1))
          .name,
      '共享配置',
    );
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    await container.pump();
    expect(
      container.read(ruleSubRepositoryProvider),
      same(second.ruleSubRepository),
    );
    expect(container.read(ruleSubServiceProvider), same(second.ruleSubService));
    expect(
      await container.read(ruleSubRepositoryProvider).ruleSubList(),
      isEmpty,
    );
  });

  group('Notifier只依赖两个窄接口', () {
    late RuleSubRepositoryMock repository;
    late RuleSubServiceMock service;
    late ProviderContainer container;
    late RuleSubNotifier notifier;
    const sub = RuleSub(id: 7, url: 'https://a', name: '订阅', customOrder: 1);
    const second = RuleSub(
      id: 8,
      url: 'https://b',
      name: '第二项',
      customOrder: 2,
    );
    RuleSubState state() => container.read(ruleSubNotifierProvider);

    setUp(() {
      repository = RuleSubRepositoryMock();
      service = RuleSubServiceMock();
      when(() => repository.ruleSubList())
          .thenAnswer((_) async => [sub, second]);
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
          ruleSubRepositoryProvider.overrideWithValue(repository),
          ruleSubServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      notifier = container.read(ruleSubNotifierProvider.notifier);
    });

    test('加载失败保留上次结果，重试成功清除错误', () async {
      await notifier.loadSubs();
      when(() => repository.ruleSubList()).thenThrow(StateError('读取失败'));
      await notifier.loadSubs();
      expect(state().subs, [sub, second]);
      expect(state().loading, isFalse);
      expect(state().error, contains('读取失败'));
      when(() => repository.ruleSubList()).thenAnswer((_) async => [second]);
      await notifier.loadSubs();
      expect(state().subs, [second]);
      expect(state().error, isNull);
    });

    test('保存返回false保留已有列表且不重新读取', () async {
      await notifier.loadSubs();
      clearInteractions(repository);
      when(() => repository.ruleSubSave(any())).thenAnswer((_) async => false);
      await notifier.saveSub(const RuleSub(name: '新增', url: 'https://c'));
      expect(state().subs, [sub, second]);
      expect(state().error, contains('保存订阅失败'));
      verifyNever(() => repository.ruleSubList());
    });

    test('删除返回false不会在页面状态移除条目', () async {
      await notifier.loadSubs();
      when(() => repository.ruleSubDelete(id: 7))
          .thenAnswer((_) async => false);
      await notifier.deleteSub(7);
      expect(state().subs, [sub, second]);
      expect(state().error, contains('删除订阅失败'));
    });

    test('启停返回false不会改变当前开关', () async {
      await notifier.loadSubs();
      when(() => repository.ruleSubSetEnabled(id: 7, enabled: false))
          .thenAnswer((_) async => false);
      await notifier.setEnabled(7, false);
      expect(state().subs.first.isEnabled, isTrue);
      expect(state().error, contains('切换订阅状态失败'));
    });

    test('排序失败重新读取持久化顺序，并保留失败提示', () async {
      await notifier.loadSubs();
      when(() => repository.ruleSubUpdateOrder(ids: [8, 7]))
          .thenAnswer((_) async => false);
      await notifier.reorder(0, 1);
      expect(state().subs, [sub, second]);
      expect(state().error, contains('保存订阅顺序失败'));
      verify(() => repository.ruleSubUpdateOrder(ids: [8, 7])).called(1);
      verify(() => repository.ruleSubList()).called(2);
    });

    test('检查更新透传类型化结果，不重读或写入订阅', () async {
      const checked = RuleSubCheckResult(
        id: 7,
        url: 'https://a',
        name: '订阅',
        dueForUpdate: true,
        hasUpdate: true,
        remoteVersion: 'v2',
      );
      when(() => service.ruleSubCheckUpdate(id: 7))
          .thenAnswer((_) async => checked);
      expect(await notifier.checkUpdate(7), same(checked));
      verify(() => service.ruleSubCheckUpdate(id: 7)).called(1);
      verifyZeroInteractions(repository);
    });

    for (final success in [true, false]) {
      test('应用更新success=$success，仅成功后刷新配置', () async {
        final result = RuleSubApplyResult(
          id: 7,
          url: 'https://a',
          success: success,
          itemsAdded: 0,
          itemsUpdated: 2,
          itemsRemoved: 0,
          totalItems: 2,
          error: success ? null : '远程错误',
        );
        when(() => service.ruleSubApplyUpdate(id: 7))
            .thenAnswer((_) async => result);
        expect(await notifier.applyUpdate(7), same(result));
        if (success) {
          expect(state().subs, [sub, second]);
          verify(() => repository.ruleSubList()).called(1);
        } else {
          verifyZeroInteractions(repository);
        }
      });
    }

    test('更新服务异常不触发配置写入或刷新', () async {
      final error = StateError('下载失败');
      when(() => service.ruleSubApplyUpdate(id: 7)).thenThrow(error);
      await expectLater(() => notifier.applyUpdate(7), throwsA(same(error)));
      verifyZeroInteractions(repository);
    });
  });
}
