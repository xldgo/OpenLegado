import '../../models/models.dart';

/// TXT目录规则是实体列表，不是普通偏好。— Codex + Bridge
abstract interface class TxtTocRuleRepository {
  Future<List<TxtTocRule>> getRules();
  Future<void> saveRules(List<TxtTocRule> rules);
}
