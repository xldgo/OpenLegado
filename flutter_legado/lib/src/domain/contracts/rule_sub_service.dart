import '../models/rule_sub_update_result.dart';

/// 直接委托既有更新能力，不复制订阅配置状态。— Codex + Bridge
abstract interface class RuleSubService {
  Future<RuleSubCheckResult> ruleSubCheckUpdate({required int id});
  Future<RuleSubApplyResult> ruleSubApplyUpdate({required int id});
}
