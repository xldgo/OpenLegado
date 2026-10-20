import 'package:flutter_legado/src/app/bootstrap/application_dependencies.dart';

import '../fixtures/app_test_api.dart';

import 'package:flutter_legado/src/data/repositories/mock_replace_rule_repository.dart';
import 'package:flutter_legado/src/data/services/mock_replace_rule_service.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/features/rules/application/replace_rules/replace_rule_notifier.dart';
import 'package:flutter_legado/src/providers/replace_rule_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('同一Mock装配共享规则CRUD和启停，保留模型字段', () async {
    final api = MockBookApi();
    final repository = api.replaceRuleRepository;
    const rule = ReplaceRule(
      name: '规则',
      pattern: '旧',
      replacement: '新',
      scopeSource: true,
      scope: '书源',
      excludeScope: '排除',
      group: '分组',
      scopeTitle: true,
      timeoutMillisecond: 500,
    );
    final added = await repository.addReplaceRule(rule);
    expect(added.id, greaterThan(0));
    expect(await api.replaceRuleRepository.getReplaceRules(), [added]);
    final updated = added.copyWith(name: '修改', scopeContent: false);
    await repository.updateReplaceRule(updated);
    expect(await repository.getEnabledReplaceRules(), [updated]);
    await repository.setReplaceRuleEnabled(added.id, false);
    expect(await repository.getEnabledReplaceRules(), isEmpty);
    expect(
      (await repository.getReplaceRules()).single,
      updated.copyWith(isEnabled: false),
    );
    await repository.deleteReplaceRule(added.id);
    expect(await repository.getReplaceRules(), isEmpty);
  });

  test('Mock执行保持旧占位结果，不实现第二套规则引擎', () async {
    const service = MockReplaceRuleService();
    expect(
      await service.applyReplaceRulesToSource('{"name":"旧"}', '源', 'url'),
      '{"name":"旧"}',
    );
    expect(
      await service.previewReplaceRule('{"pattern":"旧"}', '旧正文'),
      '[mock预览] 旧正文',
    );
  });

  test('规则仓储与执行服务分别注入同一根装配，Provider跟随实例替换', () async {
    var nextId = 10;
    final repository = MockReplaceRuleRepository(nextId: () => nextId++);
    const service = MockReplaceRuleService();
    final first = MockBookApi(
      replaceRuleRepository: repository,
      replaceRuleService: service,
    );
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: mergeTestOverrides([
        replaceRuleRepositoryProvider.overrideWithValue(
          first.replaceRuleRepository,
        ),
        replaceRuleServiceProvider.overrideWithValue(first.replaceRuleService),
      ]),
    );
    addTearDown(container.dispose);
    expect(container.read(replaceRuleRepositoryProvider), same(repository));
    expect(container.read(replaceRuleServiceProvider), same(service));
    final rule = await container
        .read(replaceRuleRepositoryProvider)
        .addReplaceRule(const ReplaceRule(name: '独立数据'));
    expect(rule.id, 10);
    expect(await first.replaceRuleRepository.getReplaceRules(), [rule]);
    container.updateOverrides(
      mergeTestOverrides([
        replaceRuleRepositoryProvider.overrideWithValue(
          second.replaceRuleRepository,
        ),
        replaceRuleServiceProvider.overrideWithValue(second.replaceRuleService),
      ]),
    );
    await container.pump();
    expect(
      container.read(replaceRuleRepositoryProvider),
      same(second.replaceRuleRepository),
    );
    expect(
      container.read(replaceRuleServiceProvider),
      same(second.replaceRuleService),
    );
    expect(
      await container.read(replaceRuleRepositoryProvider).getReplaceRules(),
      isEmpty,
    );
  });

  test('Notifier独立替换仓储可完成加载与增删改启停，不创建根BookApi', () async {
    var nextId = 1;
    final repository = MockReplaceRuleRepository(nextId: () => nextId++);
    final container = ProviderContainer(
      overrides: [replaceRuleRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(replaceRuleNotifierProvider.notifier);
    await notifier.load();
    expect(container.read(replaceRuleNotifierProvider).error, isNull);
    final added = await notifier.addRule(const ReplaceRule(name: '新增'));
    await notifier.updateRule(added.copyWith(name: '修改'));
    await notifier.setEnabled(added.id, false);
    expect((await repository.getReplaceRules()).single.name, '修改');
    expect(
      container.read(replaceRuleNotifierProvider).rules.single.isEnabled,
      isFalse,
    );
    await notifier.load();
    expect(container.read(replaceRuleNotifierProvider).rules.single.name, '修改');
    await notifier.deleteRule(added.id);
    expect(await repository.getReplaceRules(), isEmpty);
    expect(container.read(replaceRuleNotifierProvider).rules, isEmpty);
  });
}
