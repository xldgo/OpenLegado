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

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('列表保留Rust返回顺序，保存编码已有实体全部字段', () async {
    when(() => bridge.crateFfiFfiRuleSubList()).thenAnswer(
      (_) async => jsonEncode([
        record,
        {...record, 'id': 2, 'customOrder': 1},
      ]),
    );
    final subs = await repository.ruleSubList();
    expect(subs.map((sub) => sub.id), [7, 2]);
    expect(subs.first.toJson(), record);
    when(() => bridge.crateFfiFfiRuleSubSave(subJson: any(named: 'subJson')))
        .thenAnswer((_) async => true);
    expect(await repository.ruleSubSave(subs.first), isTrue);
    final encoded =
        verify(
              () => bridge.crateFfiFfiRuleSubSave(
                subJson: captureAny(named: 'subJson'),
              ),
            ).captured.single
            as String;
    expect(jsonDecode(encoded), record);
  });

  test('配置写入透传false，不伪造保存、删除、启停或排序成功', () async {
    when(() => bridge.crateFfiFfiRuleSubSave(subJson: any(named: 'subJson')))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRuleSubDelete(id: 7))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRuleSubSetEnabled(id: 7, enabled: false))
        .thenAnswer((_) async => false);
    when(() => bridge.crateFfiFfiRuleSubUpdateOrder(idsJson: '[7,2]'))
        .thenAnswer((_) async => false);
    expect(await repository.ruleSubSave(const RuleSub()), isFalse);
    expect(await repository.ruleSubDelete(id: 7), isFalse);
    expect(await repository.ruleSubSetEnabled(id: 7, enabled: false), isFalse);
    expect(await repository.ruleSubUpdateOrder(ids: [7, 2]), isFalse);
    verify(() => bridge.crateFfiFfiRuleSubUpdateOrder(idsJson: '[7,2]'))
        .called(1);
  });

  test('合法空列表不报错', () async {
    when(() => bridge.crateFfiFfiRuleSubList()).thenAnswer((_) async => '[]');
    expect(await repository.ruleSubList(), isEmpty);
  });

  for (final payload in ['invalid', '{}', '[null]', '[1]']) {
    test('损坏列表不作为空列表放行：$payload', () async {
      when(() => bridge.crateFfiFfiRuleSubList())
          .thenAnswer((_) async => payload);
      await expectLater(repository.ruleSubList(), throwsFormatException);
    });
  }

  test('检查和应用按ID调用，类型化结果保留版本及合并统计', () async {
    when(() => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7))
        .thenAnswer((_) async => jsonEncode(check));
    when(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7))
        .thenAnswer((_) async => jsonEncode(apply));
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
      (_) async => jsonEncode({
        ...check,
        'hasUpdate': false,
        'remoteVersion': null,
        'error': '下载失败',
      }),
    );
    when(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7)).thenAnswer(
      (_) async => jsonEncode({...apply, 'success': false, 'error': '解析失败'}),
    );
    final checked = await service.ruleSubCheckUpdate(id: 7);
    expect(checked.hasUpdate, isFalse);
    expect(checked.remoteVersion, isNull);
    expect(checked.error, '下载失败');
    final applied = await service.ruleSubApplyUpdate(id: 7);
    expect(applied.success, isFalse);
    expect(applied.error, '解析失败');
  });

  for (final payload in ['invalid', '[]', '{}']) {
    test('更新响应拒绝坏JSON、错误根类型或缺字段：$payload', () async {
      when(() => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7))
          .thenAnswer((_) async => payload);
      when(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7))
          .thenAnswer((_) async => payload);
      await expectLater(
        service.ruleSubCheckUpdate(id: 7),
        throwsFormatException,
      );
      await expectLater(
        service.ruleSubApplyUpdate(id: 7),
        throwsFormatException,
      );
    });
  }

  test('更新响应不把字符串真假值或错误计数类型转成成功', () async {
    when(() => bridge.crateFfiFfiRuleSubCheckUpdate(id: 7))
        .thenAnswer((_) async => jsonEncode({...check, 'hasUpdate': 'true'}));
    when(() => bridge.crateFfiFfiRuleSubApplyUpdate(id: 7))
        .thenAnswer((_) async => jsonEncode({...apply, 'itemsAdded': '3'}));
    await expectLater(service.ruleSubCheckUpdate(id: 7), throwsFormatException);
    await expectLater(service.ruleSubApplyUpdate(id: 7), throwsFormatException);
  });

  test('底层异常直接传出，不吞错为空列表或成功结果', () async {
    final error = StateError('数据库不可用');
    when(() => bridge.crateFfiFfiRuleSubList()).thenThrow(error);
    when(() => bridge.crateFfiFfiRuleSubSave(subJson: any(named: 'subJson')))
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
