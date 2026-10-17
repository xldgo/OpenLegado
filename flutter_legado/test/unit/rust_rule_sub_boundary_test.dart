import '../fixtures/business_transport_fixtures.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import 'package:flutter_legado/src/data/bridge/business_dto_mapping.dart';
import 'package:flutter_legado/src/bridge/business_dto.dart';

import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_rule_sub_repository.dart';
import 'package:flutter_legado/src/data/services/rust_rule_sub_service.dart';
import 'package:flutter_legado/src/models/rule_sub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustRuleSubRepository();
  const service = RustRuleSubService();
  const record = {
    'id': 7,
    'url': 'https://example.com/sub.json',
    'name': '规则订阅',
    'sub_type': 'replaceRule',
    'last_update': 1700000000000,
    'version': 'v2',
    'is_enabled': false,
    'created_at': 1690000000000,
    'customOrder': 3,
    'autoUpdate': true,
    'updateInterval': 12,
    'silentUpdate': true,
  };
  const check = {
    'id': 7,
    'url': 'https://example.com/sub.json',
    'name': '规则订阅',
    'dueForUpdate': true,
    'hasUpdate': true,
    'remoteVersion': 'v3',
    'error': null,
  };
  const apply = {
    'id': 7,
    'url': 'https://example.com/sub.json',
    'success': true,
    'itemsAdded': 3,
    'itemsUpdated': 2,
    'itemsRemoved': 1,
    'totalItems': 8,
    'error': null,
  };

  setUpAll(() => registerFallbackValue(ruleSubscriptionToDto(const RuleSub())));
  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('列表保留Rust返回顺序，保存编码已有实体全部字段', () async {
    when(() => bridge.crateFfiFfiRuleSubList()).thenAnswer(
      (_) async => fixtureRuleSubscriptionDtoList(
        jsonEncode([
          record,
          {...record, 'id': 2, 'customOrder': 1},
        ]),
      ),
    );
    final subs = await repository.ruleSubList();
    expect(subs.map((sub) => sub.id), [7, 2]);
    expect(subs.first.toJson(), record);
    when(() => bridge.crateFfiFfiRuleSubSave(sub: any(named: 'sub')))
        .thenAnswer((_) async => true);
    expect(await repository.ruleSubSave(subs.first), isTrue);
    final encoded =
        verify(
              () =>
                  bridge.crateFfiFfiRuleSubSave(sub: captureAny(named: 'sub')),
            ).captured.single
            as RuleSubscriptionDto;
    expect(ruleSubscriptionFromDto(encoded).toJson(), record);
  });

  test('配置写入透传false，不伪造保存、删除、启停或排序成功', () async {
    when(() => bridge.crateFfiFfiRuleSubSave(sub: any(named: 'sub')))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRuleSubDelete(id: 7))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRuleSubSetEnabled(id: 7, enabled: false))
        .thenAnswer((_) async => false);
    when(
      () =>
          bridge.crateFfiFfiRuleSubUpdateOrder(ids: Int64List.fromList([7, 2])),
    ).thenAnswer((_) async => false);
    expect(await repository.ruleSubSave(const RuleSub()), isFalse);
    expect(await repository.ruleSubDelete(id: 7), isFalse);
    expect(await repository.ruleSubSetEnabled(id: 7, enabled: false), isFalse);
    expect(await repository.ruleSubUpdateOrder(ids: [7, 2]), isFalse);
    verify(
      () =>
          bridge.crateFfiFfiRuleSubUpdateOrder(ids: Int64List.fromList([7, 2])),
    ).called(1);
  });

  test('合法空列表不报错', () async {
    when(() => bridge.crateFfiFfiRuleSubList())
        .thenAnswer((_) async => fixtureRuleSubscriptionDtoList('[]'));
    expect(await repository.ruleSubList(), isEmpty);
  });

  test('检查和应用按ID调用，类型化结果保留版本及合并统计', () async {
    when(
      () => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7),
    ).thenAnswer((_) async => fixtureSubscriptionCheckDto(jsonEncode(check)));
    when(
      () => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7),
    ).thenAnswer((_) async => fixtureSubscriptionApplyDto(jsonEncode(apply)));
    final checked = await service.ruleSubCheckUpdate(id: 7);
    expect(checked.id, 7);
    expect(checked.url, check['url']);
    expect(checked.name, '规则订阅');
    expect(checked.dueForUpdate, isTrue);
    expect(checked.hasUpdate, isTrue);
    expect(checked.remoteVersion, 'v3');
    expect(checked.error, isNull);
    final applied = await service.ruleSubApplyUpdate(id: 7);
    expect(applied.id, 7);
    expect(applied.url, check['url']);
    expect(applied.success, isTrue);
    expect(
      [
        applied.itemsAdded,
        applied.itemsUpdated,
        applied.itemsRemoved,
        applied.totalItems,
      ],
      [3, 2, 1, 8],
    );
    expect(applied.error, isNull);
    verify(() => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7)).called(1);
    verify(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7)).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('合法失败响应保留错误，允许尚无远程版本', () async {
    when(() => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7)).thenAnswer(
      (_) async => fixtureSubscriptionCheckDto(
        jsonEncode({
          ...check,
          'hasUpdate': false,
          'remoteVersion': null,
          'error': '下载失败',
        }),
      ),
    );
    when(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7)).thenAnswer(
      (_) async => fixtureSubscriptionApplyDto(
        jsonEncode({...apply, 'success': false, 'error': '解析失败'}),
      ),
    );
    final checked = await service.ruleSubCheckUpdate(id: 7);
    expect(checked.hasUpdate, isFalse);
    expect(checked.remoteVersion, isNull);
    expect(checked.error, '下载失败');
    final applied = await service.ruleSubApplyUpdate(id: 7);
    expect(applied.success, isFalse);
    expect(applied.error, '解析失败');
  });

  test('底层异常直接传出，不吞错为空列表或成功结果', () async {
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiRuleSubList()).thenThrow(error);
    when(() => bridge.crateFfiFfiRuleSubSave(sub: any(named: 'sub')))
        .thenThrow(error);
    when(() => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7)).thenThrow(error);
    when(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7)).thenThrow(error);
    await expectLater(() => repository.ruleSubList(), throwsA(same(error)));
    await expectLater(
      () => repository.ruleSubSave(const RuleSub()),
      throwsA(same(error)),
    );
    await expectLater(
      () => service.ruleSubCheckUpdate(id: 7),
      throwsA(same(error)),
    );
    await expectLater(
      () => service.ruleSubApplyUpdate(id: 7),
      throwsA(same(error)),
    );
  });
}
