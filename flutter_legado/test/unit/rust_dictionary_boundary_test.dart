import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import '../fixtures/business_transport_fixtures.dart';

import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_dict_rule_repository.dart';
import 'package:flutter_legado/src/data/services/rust_dictionary_service.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustDictRuleRepository();
  const service = RustDictionaryService();
  const row = {
    'id': 7,
    'name': '词典',
    'urlRule': 'https://a/{{key}}',
    'showRule': '@js:result',
    'enabled': false,
    'sortNumber': 9,
  };
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('列表返回带ID的共享实体，顺序和既有字段不变', () async {
    when(() => bridge.crateFfiFfiDictRuleList()).thenAnswer(
      (_) async => fixtureDictionaryRuleDtoList(
        jsonEncode([
          row,
          {...row, 'id': 4, 'sortNumber': 1},
        ]),
      ),
    );
    final rules = await repository.dictRuleList();
    expect(rules.map((r) => r.id), [7, 4]);
    expect(rules.first.toJson(), row);
    expect(rules.first.copyWith(enabled: true).id, 7);
  });

  test('增改删启停按原FRB传参，false不伪造成成功', () async {
    when(
      () => bridge.crateFfiFfiDictRuleAdd(
        name: '词典',
        urlRule: 'url',
        showRule: 'show',
      ),
    ).thenAnswer((_) async => 7);
    when(
      () => bridge.crateFfiFfiDictRuleUpdate(
        id: 7,
        name: '新名',
        urlRule: 'new',
        showRule: '',
      ),
    ).thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiDictRuleDelete(id: 7))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiDictRuleSetEnabled(id: 7, enabled: false))
        .thenAnswer((_) async => false);
    expect(
      await repository.dictRuleAdd(
        name: '词典',
        urlRule: 'url',
        showRule: 'show',
      ),
      7,
    );
    expect(
      await repository.dictRuleUpdate(
        id: 7,
        name: '新名',
        urlRule: 'new',
        showRule: '',
      ),
      isFalse,
    );
    expect(await repository.dictRuleDelete(7), isFalse);
    expect(await repository.dictRuleSetEnabled(id: 7, enabled: false), isFalse);
    verify(
      () => bridge.crateFfiFfiDictRuleAdd(
        name: '词典',
        urlRule: 'url',
        showRule: 'show',
      ),
    ).called(1);
    verify(
      () => bridge.crateFfiFfiDictRuleUpdate(
        id: 7,
        name: '新名',
        urlRule: 'new',
        showRule: '',
      ),
    ).called(1);
    verify(() => bridge.crateFfiFfiDictRuleDelete(id: 7)).called(1);
    verify(() => bridge.crateFfiFfiDictRuleSetEnabled(id: 7, enabled: false))
        .called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('重排只在仓储编码ID，文本与URL导入原样委托', () async {
    when(
      () => bridge.crateFfiFfiDictRuleReorder(ids: Int64List.fromList([7, 4])),
    ).thenAnswer((_) async => 2);
    when(
      () => bridge.crateFfiFfiDictRuleImport(
        jsonOrUrl: '[{"name":"词典"}]',
        kind: 'text',
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => bridge.crateFfiFfiDictRuleImport(
        jsonOrUrl: 'https://a/rules',
        kind: 'url',
      ),
    ).thenAnswer((_) async => 3);
    expect(await repository.dictRuleReorder([7, 4]), 2);
    expect(
      await repository.dictRuleImport(
        jsonOrUrl: '[{"name":"词典"}]',
        kind: 'text',
      ),
      1,
    );
    expect(
      await repository.dictRuleImport(
        jsonOrUrl: 'https://a/rules',
        kind: 'url',
      ),
      3,
    );
    verify(
      () => bridge.crateFfiFfiDictRuleReorder(ids: Int64List.fromList([7, 4])),
    ).called(1);
    verify(
      () => bridge.crateFfiFfiDictRuleImport(
        jsonOrUrl: '[{"name":"词典"}]',
        kind: 'text',
      ),
    ).called(1);
    verify(
      () => bridge.crateFfiFfiDictRuleImport(
        jsonOrUrl: 'https://a/rules',
        kind: 'url',
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('查询保留入参及释义，未收录是合法空列表', () async {
    when(() => bridge.crateFfiFfiDictLookup(word: 'Chapter')).thenAnswer(
      (_) async => fixtureDictEntryDto(
        jsonEncode({
          'word': 'Chapter',
          'phonetic': '',
          'definitions': ['【词典】章节'],
        }),
      ),
    );
    when(() => bridge.crateFfiFfiDictLookup(word: 'zzz')).thenAnswer(
      (_) async =>
          fixtureDictEntryDto('{"word":"zzz","phonetic":"","definitions":[]}'),
    );
    expect(
      await service.dictLookup('Chapter'),
      const DictEntry(word: 'Chapter', definitions: ['【词典】章节']),
    );
    expect((await service.dictLookup('zzz')).definitions, isEmpty);
    verify(() => bridge.crateFfiFfiDictLookup(word: 'Chapter')).called(1);
  });

  test('合法空规则列表与导入0条不报错，新增无主键硬失败', () async {
    when(() => bridge.crateFfiFfiDictRuleList())
        .thenAnswer((_) async => fixtureDictionaryRuleDtoList('[]'));
    when(() => bridge.crateFfiFfiDictRuleImport(jsonOrUrl: '[]', kind: 'text'))
        .thenAnswer((_) async => 0);
    when(
      () =>
          bridge.crateFfiFfiDictRuleAdd(name: '词典', urlRule: '', showRule: ''),
    ).thenAnswer((_) async => 0);
    expect(await repository.dictRuleList(), isEmpty);
    expect(await repository.dictRuleImport(jsonOrUrl: '[]', kind: 'text'), 0);
    await expectLater(
      repository.dictRuleAdd(name: '词典', urlRule: '', showRule: ''),
      throwsStateError,
    );
  });

  test('FRB异常原样传递，不回填空结果', () async {
    final error = StateError('底层异常');
    when(() => bridge.crateFfiFfiDictLookup(word: 'a')).thenThrow(error);
    when(() => bridge.crateFfiFfiDictRuleList()).thenThrow(error);
    when(() => bridge.crateFfiFfiDictRuleReorder(ids: Int64List.fromList([7])))
        .thenThrow(error);
    await expectLater(() => service.dictLookup('a'), throwsA(same(error)));
    await expectLater(() => repository.dictRuleList(), throwsA(same(error)));
    await expectLater(
      () => repository.dictRuleReorder([7]),
      throwsA(same(error)),
    );
  });
}
