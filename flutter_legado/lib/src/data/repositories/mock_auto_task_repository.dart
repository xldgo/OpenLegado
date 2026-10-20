import '../../domain/contracts/auto_task_repository.dart';
import '../../models/misc.dart';

/// Mock规则由一个仓储持有，不在页面复制另一份持久化事实。— Codex + Bridge
final class MockAutoTaskRepository implements AutoTaskRepository {
  MockAutoTaskRepository({required this._allocateId});
  final String Function() _allocateId;
  final Map<String, AutoTaskRule> _rules = {};
  @override
  Future<List<AutoTaskRule>> listRules() async =>
      _rules.values.toList()
        ..sort((a, b) => a.customOrder.compareTo(b.customOrder));
  @override
  Future<String> createRule(AutoTaskRule rule) async {
    final id = rule.id.isEmpty ? _allocateId() : rule.id;
    _rules[id] = rule.copyWith(id: id);
    return id;
  }

  @override
  Future<void> updateRule(AutoTaskRule rule) async {
    if (!_rules.containsKey(rule.id)) throw StateError('任务不存在：${rule.id}');
    _rules[rule.id] = rule;
  }

  @override
  Future<void> deleteRule(String id) async {
    _rules.remove(id);
  }

  @override
  Future<AutoTaskRule?> findRuleById(String id) async => _rules[id];
}
