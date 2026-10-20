import '../../domain/contracts/replace_rule_repository.dart';
import '../../models/misc.dart' show ReplaceRule;

/// 使用同一装配实例的内存规则，供Mock开发与依赖替换。— Codex + Bridge
final class MockReplaceRuleRepository implements ReplaceRuleRepository {
  MockReplaceRuleRepository({required this._nextId});

  final int Function() _nextId;
  final List<ReplaceRule> _replaceRules = [];

  @override
  Future<List<ReplaceRule>> getReplaceRules() async => List.from(_replaceRules);

  @override
  Future<List<ReplaceRule>> getEnabledReplaceRules() async =>
      _replaceRules.where((r) => r.isEnabled).toList();

  @override
  Future<ReplaceRule> addReplaceRule(ReplaceRule rule) async {
    final r = rule.copyWith(id: _nextId());
    _replaceRules.add(r);
    return r;
  }

  @override
  Future<void> updateReplaceRule(ReplaceRule rule) async {
    final idx = _replaceRules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) _replaceRules[idx] = rule;
  }

  @override
  Future<void> deleteReplaceRule(int id) async {
    _replaceRules.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> setReplaceRuleEnabled(int id, bool enabled) async {
    final idx = _replaceRules.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _replaceRules[idx] = _replaceRules[idx].copyWith(isEnabled: enabled);
    }
  }
}
