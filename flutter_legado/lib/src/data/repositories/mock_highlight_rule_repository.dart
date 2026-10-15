import '../../domain/contracts/highlight_rule_repository.dart';
import '../../domain/models/highlight_rule.dart';

/// 规则配置复用装配的ID分配器，无独立执行引擎。— Codex + Bridge
final class MockHighlightRuleRepository implements HighlightRuleRepository {
  MockHighlightRuleRepository({required this._nextId});

  final int Function() _nextId;
  final Map<int, HighlightRule> _rules = {};

  @override
  Future<List<HighlightRule>> highlightRuleList() async =>
      _sorted(_rules.values);

  @override
  Future<int> highlightRuleSave(HighlightRule rule) async {
    final id = rule.id > 0 ? rule.id : _nextId();
    _rules[id] = rule.copyWith(id: id);
    return id;
  }

  @override
  Future<bool> highlightRuleDelete({required int id}) async =>
      _rules.remove(id) != null;

  @override
  Future<List<HighlightRule>> highlightRuleFindEnabled({
    required String bookName,
    required String origin,
  }) async => _sorted(
    _rules.values.where((rule) {
      if (!rule.isEnabled) return false;
      final scope = rule.scope;
      return scope == null ||
          scope.isEmpty ||
          (bookName.isNotEmpty && scope.contains(bookName)) ||
          (origin.isNotEmpty && scope.contains(origin));
    }),
  );

  List<HighlightRule> _sorted(Iterable<HighlightRule> items) =>
      items.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
