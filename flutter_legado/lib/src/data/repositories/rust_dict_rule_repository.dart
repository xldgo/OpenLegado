import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/dict_rule_repository.dart';
import '../../models/misc.dart' show DictRule;
import '../bridge/rust_json_decode.dart';

/// 复用现有FRB与空表默认规则，响应解码集中在数据层。— Codex + Bridge
final class RustDictRuleRepository implements DictRuleRepository {
  const RustDictRuleRepository();

  @override
  Future<List<DictRule>> dictRuleList() async =>
      decodeRustJsonList(
        await bridge.dictRuleList(),
        'dictRuleList',
      ).indexed.map((entry) {
        final (index, value) = entry;
        if (value is! Map<String, dynamic>) {
          throw FormatException('词典规则第${index + 1}项必须是对象');
        }
        if (value['id'] is! int ||
            value['name'] is! String ||
            value['urlRule'] is! String ||
            value['showRule'] is! String ||
            value['enabled'] is! bool ||
            value['sortNumber'] is! int) {
          throw FormatException('词典规则第${index + 1}项字段类型无效');
        }
        return DictRule.fromJson(value);
      }).toList();

  @override
  Future<int> dictRuleAdd({
    required String name,
    required String urlRule,
    required String showRule,
  }) async {
    final id = await bridge.dictRuleAdd(
      name: name,
      urlRule: urlRule,
      showRule: showRule,
    );
    if (id <= 0) throw StateError('新增词典规则未返回有效主键');
    return id;
  }

  @override
  Future<bool> dictRuleUpdate({
    required int id,
    required String name,
    required String urlRule,
    required String showRule,
  }) => bridge.dictRuleUpdate(
    id: id,
    name: name,
    urlRule: urlRule,
    showRule: showRule,
  );

  @override
  Future<bool> dictRuleDelete(int id) => bridge.dictRuleDelete(id: id);

  @override
  Future<bool> dictRuleSetEnabled({required int id, required bool enabled}) =>
      bridge.dictRuleSetEnabled(id: id, enabled: enabled);

  @override
  Future<int> dictRuleReorder(List<int> ids) =>
      bridge.dictRuleReorder(idsJson: jsonEncode(ids));

  @override
  Future<int> dictRuleImport({
    required String jsonOrUrl,
    required String kind,
  }) => bridge.dictRuleImport(jsonOrUrl: jsonOrUrl, kind: kind);
}
