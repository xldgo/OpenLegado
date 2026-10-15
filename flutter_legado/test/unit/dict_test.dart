import 'package:flutter_legado/src/data/repositories/mock_dict_rule_repository.dart';
import 'package:flutter_legado/src/models/models.dart';
import 'package:flutter_legado/src/providers/dict/dict_notifier.dart';
import 'package:flutter_legado/src/providers/dictionary_provider.dart';
import 'package:flutter_legado/src/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DictRule.buildUrl保留现有占位符替换', () {
    const rule = DictRule(
      name: '有道',
      urlRule: 'https://dict.youdao.com/w/{{key}}',
    );
    expect(rule.buildUrl('chapter'), 'https://dict.youdao.com/w/chapter');
  });

  group('DictNotifier独立注入', () {
    late MockDictRuleRepository repository;
    late DictionaryServiceMock service;
    late ProviderContainer container;
    DictState state() => container.read(dictNotifierProvider);
    DictNotifier notifier() => container.read(dictNotifierProvider.notifier);

    setUp(() {
      repository = MockDictRuleRepository();
      service = DictionaryServiceMock();
      container = ProviderContainer(
        overrides: [
          bookApiProvider.overrideWith((_) => throw StateError('不应创建根接口')),
          dictRuleRepositoryProvider.overrideWithValue(repository),
          dictionaryServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
    });

    test('初始状态为空', () {
      expect(state().rules, isEmpty);
      expect(state().queriedWord, isNull);
      expect(state().result, isNull);
      expect(state().isLoading, isFalse);
    });

    test('读取同一仓储默认规则，保留主键及排序', () async {
      await notifier().loadRules();
      expect(state().rules, await repository.dictRuleList());
      expect(state().rules.first.name, '海词中文');
      expect(state().rules.first.id, greaterThan(0));
      expect(state().error, isNull);
    });

    test('管理仓储修改后重新加载，查询列表同步启停和名称', () async {
      final id = await repository.dictRuleAdd(
        name: '自定义',
        urlRule: 'https://a',
        showRule: '',
      );
      await repository.dictRuleSetEnabled(id: id, enabled: false);
      await notifier().loadRules();
      final saved = state().rules.singleWhere((rule) => rule.id == id);
      expect(saved.name, '自定义');
      expect(saved.enabled, isFalse);
    });

    test('新增与删除直接写入同一仓储，不维护另一份配置', () async {
      expect(
        await notifier().addRule(
          const DictRule(name: '新规则', urlRule: 'https://new'),
        ),
        isTrue,
      );
      final index = state().rules.indexWhere((rule) => rule.name == '新规则');
      final id = state().rules[index].id;
      expect(id, greaterThan(0));
      expect(await notifier().deleteRule(index), isTrue);
      expect(
        (await repository.dictRuleList()).any((rule) => rule.id == id),
        isFalse,
      );
    });

    test('导入默认按名称覆盖并保留自定义规则，主键不变', () async {
      final defaults = await repository.dictRuleList();
      final original = defaults.singleWhere((rule) => rule.name == '海词中文');
      await repository.dictRuleUpdate(
        id: original.id,
        name: original.name,
        urlRule: '自定义地址',
        showRule: '',
      );
      await repository.dictRuleAdd(
        name: '自定义保留',
        urlRule: 'https://a',
        showRule: '',
      );
      expect(await notifier().importDefaultRules(), 5);
      expect(state().rules, hasLength(6));
      final restored = state().rules.singleWhere((rule) => rule.name == '海词中文');
      expect(restored.id, original.id);
      expect(restored.urlRule, isNot('自定义地址'));
      expect(state().rules.any((rule) => rule.name == '自定义保留'), isTrue);
    });

    test('查询保留现有trim和大小写归一化，类型化结果原样返回', () async {
      const entry = DictEntry(
        word: 'chapter',
        phonetic: '/tʃæptə/',
        definitions: ['章节'],
      );
      when(() => service.dictLookup('chapter')).thenAnswer((_) async => entry);
      await notifier().lookup(' Chapter ');
      expect(state().queriedWord, 'chapter');
      expect(state().result, same(entry));
      expect(state().isLoading, isFalse);
      verify(() => service.dictLookup('chapter')).called(1);
    });

    test('未收录返回空释义而不是错误', () async {
      when(() => service.dictLookup('zzz'))
          .thenAnswer((_) async => const DictEntry(word: 'zzz'));
      await notifier().lookup('zzz');
      expect(state().result!.definitions, isEmpty);
      expect(state().error, isNull);
    });

    test('查询异常记录错误并结束加载，空词不调用服务', () async {
      when(() => service.dictLookup('chapter')).thenThrow(StateError('查询失败'));
      await notifier().lookup('chapter');
      expect(state().result, isNull);
      expect(state().error, contains('查询失败'));
      expect(state().isLoading, isFalse);
      clearInteractions(service);
      await notifier().lookup('   ');
      verifyZeroInteractions(service);
    });
  });
}
