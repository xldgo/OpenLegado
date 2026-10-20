import '../../domain/contracts/cover_rule_repository.dart';
import '../../domain/models/cover_rule.dart';

/// 共用单份规则；删除用户配置后恢复既有Mock默认值。— Codex + Bridge
final class MockCoverRuleRepository implements CoverRuleRepository {
  static const _default = CoverRule(
    searchUrl: 'https://mock.cover.example/search?q={{key}}',
    coverRule: r'$.cover',
  );
  CoverRule _rule = _default;
  @override
  Future<CoverRule> getCoverRule() async => _rule;
  @override
  Future<bool> saveCoverRule(CoverRule rule) async {
    _rule = rule;
    return true;
  }

  @override
  Future<bool> deleteCoverRule() async {
    _rule = _default;
    return true;
  }
}
