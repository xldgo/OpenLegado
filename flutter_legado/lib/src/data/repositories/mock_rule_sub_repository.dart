import '../../domain/contracts/rule_sub_repository.dart';
import '../../models/rule_sub.dart';

/// Mock配置使用同一装配实例的内存，不由更新服务复制。— Codex + Bridge
final class MockRuleSubRepository implements RuleSubRepository {
  final List<RuleSub> _subs = [];
  int _nextId = 1;

  @override
  Future<List<RuleSub>> ruleSubList() async =>
      List<RuleSub>.of(_subs)
        ..sort((a, b) => a.customOrder.compareTo(b.customOrder));

  @override
  Future<bool> ruleSubSave(RuleSub sub) async {
    final index = _subs.indexWhere((value) => value.id == sub.id);
    if (sub.id > 0 && index >= 0) {
      _subs[index] = sub;
    } else {
      _subs.add(sub.copyWith(id: _nextId++));
    }
    return true;
  }

  @override
  Future<bool> ruleSubDelete({required int id}) async {
    final before = _subs.length;
    _subs.removeWhere((sub) => sub.id == id);
    return _subs.length < before;
  }

  @override
  Future<bool> ruleSubSetEnabled({
    required int id,
    required bool enabled,
  }) async {
    final index = _subs.indexWhere((sub) => sub.id == id);
    if (index < 0) return false;
    _subs[index] = _subs[index].copyWith(isEnabled: enabled);
    return true;
  }

  @override
  Future<bool> ruleSubUpdateOrder({required List<int> ids}) async {
    for (final (order, id) in ids.indexed) {
      final index = _subs.indexWhere((sub) => sub.id == id);
      if (index >= 0) _subs[index] = _subs[index].copyWith(customOrder: order);
    }
    return true;
  }
}
