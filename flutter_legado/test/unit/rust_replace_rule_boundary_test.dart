import '../fixtures/business_transport_fixtures.dart';

import 'dart:convert';

import 'package:flutter_legado/src/bridge/frb_generated.dart';
import 'package:flutter_legado/src/data/repositories/rust_replace_rule_repository.dart';
import 'package:flutter_legado/src/data/services/rust_replace_rule_service.dart';
import 'package:flutter_legado/src/models/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Bridge extends Mock implements RustLibApi {}

void main() {
  late _Bridge bridge;
  const repository = RustReplaceRuleRepository();
  const service = RustReplaceRuleService();

  setUp(() {
    bridge = _Bridge();
    RustLib.initMock(api: bridge);
  });
  tearDown(RustLib.dispose);

  test('全部与启用规则分别读取，保留Rust顺序及模型字段', () async {
    const first = ReplaceRule(id: 2, name: '后排序', order: 8, scopeSource: true);
    const second = ReplaceRule(id: 1, name: '先排序', order: 1, isEnabled: false);
    when(() => bridge.crateFfiFfiReplaceRuleList()).thenAnswer(
      (_) async => fixtureReplaceRuleDtoList(
        jsonEncode([first.toJson(), second.toJson()]),
      ),
    );
    when(() => bridge.crateFfiFfiReplaceRuleEnabled()).thenAnswer(
      (_) async => fixtureReplaceRuleDtoList(jsonEncode([first.toJson()])),
    );
    expect(await repository.getReplaceRules(), [first, second]);
    expect(await repository.getEnabledReplaceRules(), [first]);
    verify(() => bridge.crateFfiFfiReplaceRuleList()).called(1);
    verify(() => bridge.crateFfiFfiReplaceRuleEnabled()).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('添加传递现有FRB支持的字段并返回分配ID的原实体', () async {
    const rule = ReplaceRule(
      name: '标题替换',
      pattern: '@js:result',
      replacement: '新值',
      group: '分组',
      scope: '书名',
      isRegex: false,
      scopeTitle: true,
      scopeContent: false,
      scopeSource: true,
      excludeScope: '排除',
      timeoutMillisecond: 80,
    );
    when(
      () => bridge.crateFfiFfiReplaceRuleAdd(
        name: rule.name,
        pattern: rule.pattern,
        replacement: rule.replacement,
        isRegex: false,
        scope: '书名',
        group: '分组',
        scopeTitle: true,
        scopeContent: false,
        excludeScope: '排除',
        timeoutMillisecond: 80,
        scopeSource: true,
      ),
    ).thenAnswer((_) async => 42);
    expect(await repository.addReplaceRule(rule), rule.copyWith(id: 42));
    verify(
      () => bridge.crateFfiFfiReplaceRuleAdd(
        name: rule.name,
        pattern: rule.pattern,
        replacement: rule.replacement,
        isRegex: false,
        scope: '书名',
        group: '分组',
        scopeTitle: true,
        scopeContent: false,
        excludeScope: '排除',
        timeoutMillisecond: 80,
        scopeSource: true,
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('更新保留既有字段映射，空group与excludeScope明确传空串', () async {
    const rule = ReplaceRule(
      id: 9,
      name: '修改',
      pattern: '旧',
      replacement: '新',
      isRegex: false,
      isEnabled: false,
      scopeTitle: true,
      scopeContent: false,
      scopeSource: true,
      timeoutMillisecond: 200,
    );
    when(
      () => bridge.crateFfiFfiReplaceRuleUpdate(
        ruleId: 9,
        name: '修改',
        pattern: '旧',
        replacement: '新',
        isRegex: false,
        isEnabled: false,
        group: '',
        scopeTitle: true,
        scopeContent: false,
        excludeScope: '',
        timeoutMillisecond: 200,
        scopeSource: true,
      ),
    ).thenAnswer((_) async {});
    await repository.updateReplaceRule(rule);
    verify(
      () => bridge.crateFfiFfiReplaceRuleUpdate(
        ruleId: 9,
        name: '修改',
        pattern: '旧',
        replacement: '新',
        isRegex: false,
        isEnabled: false,
        group: '',
        scopeTitle: true,
        scopeContent: false,
        excludeScope: '',
        timeoutMillisecond: 200,
        scopeSource: true,
      ),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('删除和启停传递规则ID，不另写列表或配置', () async {
    when(() => bridge.crateFfiFfiReplaceRuleDelete(ruleId: 3))
        .thenAnswer((_) async {});
    when(
      () => bridge.crateFfiFfiReplaceRuleSetEnabled(ruleId: 3, enabled: false),
    ).thenAnswer((_) async {});
    await repository.setReplaceRuleEnabled(3, false);
    await repository.deleteReplaceRule(3);
    verify(() => bridge.crateFfiFfiReplaceRuleDelete(ruleId: 3)).called(1);
    verify(
      () => bridge.crateFfiFfiReplaceRuleSetEnabled(ruleId: 3, enabled: false),
    ).called(1);
    verifyNoMoreInteractions(bridge);
  });

  test('合法空列表正常返回，查询与写入异常原样传播', () async {
    when(() => bridge.crateFfiFfiReplaceRuleList())
        .thenAnswer((_) async => fixtureReplaceRuleDtoList('[]'));
    expect(await repository.getReplaceRules(), isEmpty);
    final error = StateError('数据库失败');
    when(() => bridge.crateFfiFfiReplaceRuleEnabled()).thenThrow(error);
    when(() => bridge.crateFfiFfiReplaceRuleDelete(ruleId: 2)).thenThrow(error);
    await expectLater(
      repository.getEnabledReplaceRules(),
      throwsA(same(error)),
    );
    await expectLater(
      () => repository.deleteReplaceRule(2),
      throwsA(same(error)),
    );
  });

  test('书源作用域参数及原文/替换后结果原样传递', () async {
    const input = '{"bookSourceName":"旧源"}';
    for (final output in [input, '{"bookSourceName":"新源"}']) {
      when(
        () => bridge.crateFfiFfiApplyReplaceRulesToSource(
          sourceJson: input,
          sourceName: '源名称',
          sourceUrl: 'https://source.test',
        ),
      ).thenAnswer((_) async => output);
      expect(
        await service.applyReplaceRulesToSource(
          input,
          '源名称',
          'https://source.test',
        ),
        output,
      );
    }
    verify(
      () => bridge.crateFfiFfiApplyReplaceRulesToSource(
        sourceJson: input,
        sourceName: '源名称',
        sourceUrl: 'https://source.test',
      ),
    ).called(2);
    verifyNoMoreInteractions(bridge);
  });

  test('服务不吞掉桥接异常，由现有调用方处理预览错误和导入回退', () async {
    final error = StateError('桥接失败');
    when(
      () => bridge.crateFfiFfiReplaceRulePreview(ruleJson: 'bad', sample: '样本'),
    ).thenThrow(error);
    when(
      () => bridge.crateFfiFfiApplyReplaceRulesToSource(
        sourceJson: '{}',
        sourceName: '源',
        sourceUrl: 'url',
      ),
    ).thenThrow(error);
    await expectLater(
      () => service.previewReplaceRule('bad', '样本'),
      throwsA(same(error)),
    );
    await expectLater(
      () => service.applyReplaceRulesToSource('{}', '源', 'url'),
      throwsA(same(error)),
    );
  });
}
