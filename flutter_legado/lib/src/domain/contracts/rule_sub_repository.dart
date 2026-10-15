import '../../models/rule_sub.dart';

/// 规则订阅配置访问，更新执行由独立服务承担。— Codex + Bridge
abstract interface class RuleSubRepository {
  Future<List<RuleSub>> ruleSubList();
  Future<bool> ruleSubSave(RuleSub sub);
  Future<bool> ruleSubDelete({required int id});
  Future<bool> ruleSubSetEnabled({required int id, required bool enabled});
  Future<bool> ruleSubUpdateOrder({required List<int> ids});
}
