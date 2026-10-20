import '../../models/misc.dart';

/// 自动任务规则的唯一读写入口。— Codex + Bridge
abstract interface class AutoTaskRepository {
  Future<List<AutoTaskRule>> listRules();
  Future<String> createRule(AutoTaskRule rule);
  Future<void> updateRule(AutoTaskRule rule);
  Future<void> deleteRule(String id);
  Future<AutoTaskRule?> findRuleById(String id);
}
