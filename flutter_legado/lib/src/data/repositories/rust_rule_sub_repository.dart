import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rule_sub_repository.dart';
import '../../models/rule_sub.dart';
import '../bridge/business_dto_mapping.dart';

/// 配置编解码归数据层，正式访问直接使用既有FRB。— Codex + Bridge
final class RustRuleSubRepository implements RuleSubRepository {
  const RustRuleSubRepository();

  @override
  Future<List<RuleSub>> ruleSubList() async =>
      (await bridge.ruleSubList()).map(ruleSubscriptionFromDto).toList();

  @override
  Future<bool> ruleSubSave(RuleSub sub) =>
      bridge.ruleSubSave(sub: ruleSubscriptionToDto(sub));

  @override
  Future<bool> ruleSubDelete({required int id}) => bridge.ruleSubDelete(id: id);

  @override
  Future<bool> ruleSubSetEnabled({required int id, required bool enabled}) =>
      bridge.ruleSubSetEnabled(id: id, enabled: enabled);

  @override
  Future<bool> ruleSubUpdateOrder({required List<int> ids}) =>
      bridge.ruleSubUpdateOrder(ids: Int64List.fromList(ids));
}
