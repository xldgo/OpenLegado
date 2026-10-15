import 'package:flutter_legado/src/data/repositories/mock_dict_rule_repository.dart';
import 'package:flutter_legado/src/data/services/mock_dictionary_service.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_legado/src/providers/association/association_notifier.dart';
import 'package:flutter_legado/src/providers/dict/dict_notifier.dart';
import 'package:flutter_legado/src/providers/dictionary_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_legado/src/services/mock_book_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  test('根装配Provider共用实例，替换根后不混读配置', () async {
    final repository = MockDictRuleRepository();
    const service = MockDictionaryService();
    final first = MockBookApi(
      dictRuleRepository: repository,
      dictionaryService: service,
    );
    final second = MockBookApi();
    final container = ProviderContainer(
      overrides: [bookApiProvider.overrideWithValue(first)],
    );
    addTearDown(container.dispose);
    expect(container.read(dictRuleRepositoryProvider), same(repository));
    expect(container.read(dictionaryServiceProvider), same(service));
    await repository.dictRuleAdd(name: '独立配置', urlRule: '', showRule: '');
    expect(
      (await first.dictRuleRepository.dictRuleList()).any(
        (rule) => rule.name == '独立配置',
      ),
      isTrue,
    );
    container.updateOverrides([bookApiProvider.overrideWithValue(second)]);
    await container.pump();
    expect(
      container.read(dictRuleRepositoryProvider),
      same(second.dictRuleRepository),
    );
    expect(
      container.read(dictionaryServiceProvider),
      same(second.dictionaryService),
    );
    expect(
      (await container.read(dictRuleRepositoryProvider).dictRuleList()).any(
        (rule) => rule.name == '独立配置',
      ),
      isFalse,
    );
  });

  test('规则主键往返及重排后编辑不改变启停和顺序', () async {
    final repository = MockDictRuleRepository();
    final id = await repository.dictRuleAdd(
      name: '自定义',
      urlRule: 'old',
      showRule: '',
    );
    await repository.dictRuleSetEnabled(id: id, enabled: false);
    final ids = (await repository.dictRuleList())
        .map((rule) => rule.id)
        .toList();
    ids.remove(id);
    ids.insert(0, id);
    await repository.dictRuleReorder(ids);
    await repository.dictRuleUpdate(
      id: id,
      name: '新名称',
      urlRule: 'new',
      showRule: 'show',
    );
    final rule = (await repository.dictRuleList()).first;
    expect(rule.id, id);
    expect(rule.enabled, isFalse);
    expect(rule.sortNumber, 0);
    expect(DictRule.fromJson(rule.toJson()), rule);
    await expectLater(
      () => repository.dictRuleUpdate(
        id: id,
        name: '海词中文',
        urlRule: '',
        showRule: '',
      ),
      throwsException,
    );
  });

  test('关联导入与查询列表、管理仓储共用同一配置且同名保留ID', () async {
    final repository = MockDictRuleRepository();
    final container = ProviderContainer(
      overrides: [
        bookApiProvider.overrideWith((_) => throw StateError('不应读取根配置')),
        dictRuleRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final existing = (await repository.dictRuleList()).first;
    final importer = container.read(associationNotifierProvider.notifier);
    final result = await importer.confirmImport(ImportType.dictRule, [
      {
        'name': existing.name,
        'urlRule': '新地址',
        'showRule': '规则',
        'enabled': false,
        'sortNumber': 8,
      },
      {
        'name': '关联新增',
        'urlRule': 'https://new',
        'showRule': '',
        'sortNumber': 9,
      },
    ]);
    expect(result.success, 2);
    expect(result.failed, 0);
    final notifier = container.read(dictNotifierProvider.notifier);
    await notifier.loadRules();
    final rules = container.read(dictNotifierProvider).rules;
    final changed = rules.singleWhere((r) => r.name == existing.name);
    expect(changed.id, existing.id);
    expect(changed.urlRule, '新地址');
    expect(changed.enabled, isFalse);
    expect(changed.sortNumber, 8);
    expect(rules.any((rule) => rule.name == '关联新增'), isTrue);
    expect(rules, await repository.dictRuleList());
  });

  group('失败保留已有状态', () {
    late DictRuleRepositoryMock repository;
    late ProviderContainer container;
    late DictNotifier notifier;
    const rule = DictRule(id: 7, name: '保留', urlRule: 'url');
    setUp(() {
      repository = DictRuleRepositoryMock();
      when(() => repository.dictRuleList()).thenAnswer((_) async => [rule]);
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不应读根配置')),
          dictRuleRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      notifier = container.read(dictNotifierProvider.notifier);
    });
    test('加载失败保留规则，重试后清除错误', () async {
      await notifier.loadRules();
      when(() => repository.dictRuleList()).thenThrow(StateError('读取失败'));
      await notifier.loadRules();
      expect(container.read(dictNotifierProvider).rules, [rule]);
      expect(container.read(dictNotifierProvider).error, contains('读取失败'));
      when(() => repository.dictRuleList()).thenAnswer((_) async => []);
      await notifier.loadRules();
      expect(container.read(dictNotifierProvider).error, isNull);
    });
    test('删除false不改列表、不重新读取', () async {
      await notifier.loadRules();
      clearInteractions(repository);
      when(() => repository.dictRuleDelete(7)).thenAnswer((_) async => false);
      expect(await notifier.deleteRule(0), isFalse);
      expect(container.read(dictNotifierProvider).rules, [rule]);
      verifyNever(() => repository.dictRuleList());
    });
    test('新增异常不乐观插入不存在的规则', () async {
      await notifier.loadRules();
      when(() => repository.dictRuleAdd(name: '新规则', urlRule: '', showRule: ''))
          .thenThrow(StateError('名称重复'));
      expect(await notifier.addRule(const DictRule(name: '新规则')), isFalse);
      expect(container.read(dictNotifierProvider).rules, [rule]);
      expect(container.read(dictNotifierProvider).error, contains('名称重复'));
    });
  });
}
