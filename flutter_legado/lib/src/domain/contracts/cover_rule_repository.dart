import '../models/cover_rule.dart';

/// 读取、保存与恢复默认封面规则。— Codex + Bridge
abstract interface class CoverRuleRepository {
  Future<CoverRule> getCoverRule();
  Future<bool> saveCoverRule(CoverRule rule);
  Future<bool> deleteCoverRule();
}
