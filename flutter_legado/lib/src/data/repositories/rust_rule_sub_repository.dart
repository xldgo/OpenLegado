import '../bridge/rust_errors.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show Int64List;

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/rule_sub_repository.dart';
import '../../models/rule_sub.dart';
import '../bridge/business_dto_mapping.dart';

/// 配置编解码归数据层，正式访问直接使用既有FRB。— Codex + Bridge
final class RustRuleSubRepository implements RuleSubRepository {
  const RustRuleSubRepository();

  @override
  Future<List<RuleSub>> ruleSubList() async => (await rustFuture(
    () => bridge.ruleSubList(),
    operation: 'ruleSubList',
  )).map(ruleSubscriptionFromDto).toList();

  @override
  Future<bool> ruleSubSave(RuleSub sub) => rustFuture(
    () => bridge.ruleSubSave(sub: ruleSubscriptionToDto(sub)),
    operation: 'ruleSubSave',
  );

  @override
  Future<bool> ruleSubDelete({required int id}) => rustFuture(
    () => bridge.ruleSubDelete(id: id),
    operation: 'ruleSubDelete',
  );

  @override
  Future<bool> ruleSubSetEnabled({required int id, required bool enabled}) =>
      rustFuture(
        () => bridge.ruleSubSetEnabled(id: id, enabled: enabled),
        operation: 'ruleSubSetEnabled',
      );

  @override
  Future<bool> ruleSubUpdateOrder({required List<int> ids}) => rustFuture(
    () => bridge.ruleSubUpdateOrder(ids: Int64List.fromList(ids)),
    operation: 'ruleSubUpdateOrder',
  );
}
