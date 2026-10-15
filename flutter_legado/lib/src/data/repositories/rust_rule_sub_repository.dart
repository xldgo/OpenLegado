import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rule_sub_repository.dart';
import '../../models/rule_sub.dart';
import '../bridge/rust_json_decode.dart';

/// 配置编解码归数据层，正式访问直接使用既有FRB。— Codex + Bridge
final class RustRuleSubRepository implements RuleSubRepository {
  const RustRuleSubRepository();

  @override
  Future<List<RuleSub>> ruleSubList() async =>
      decodeRustJsonList(await bridge.ruleSubList(), 'ruleSubList').indexed.map(
        (entry) {
          final (index, value) = entry;
          if (value is! Map<String, dynamic>) {
            throw FormatException('ruleSubList：第${index + 1}项必须是对象');
          }
          return RuleSub.fromJson(value);
        },
      ).toList();

  @override
  Future<bool> ruleSubSave(RuleSub sub) =>
      bridge.ruleSubSave(subJson: jsonEncode(sub.toJson()));

  @override
  Future<bool> ruleSubDelete({required int id}) => bridge.ruleSubDelete(id: id);

  @override
  Future<bool> ruleSubSetEnabled({required int id, required bool enabled}) =>
      bridge.ruleSubSetEnabled(id: id, enabled: enabled);

  @override
  Future<bool> ruleSubUpdateOrder({required List<int> ids}) =>
      bridge.ruleSubUpdateOrder(idsJson: jsonEncode(ids));
}
