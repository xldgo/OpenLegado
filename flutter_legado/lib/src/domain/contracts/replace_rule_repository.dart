import '../../models/misc.dart' show ReplaceRule;

/// 替换规则配置访问，不管理页面与执行状态。— Codex + Bridge
abstract interface class ReplaceRuleRepository {
  /// 获取所有替换规则
  Future<List<ReplaceRule>> getReplaceRules();

  /// 获取启用的替换规则
  Future<List<ReplaceRule>> getEnabledReplaceRules();

  /// 添加替换规则
  Future<ReplaceRule> addReplaceRule(ReplaceRule rule);

  /// 更新替换规则
  Future<void> updateReplaceRule(ReplaceRule rule);

  /// 删除替换规则
  Future<void> deleteReplaceRule(int id);

  /// 启用/禁用替换规则
  Future<void> setReplaceRuleEnabled(int id, bool enabled);
}
