import 'dart:convert';

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
    _rules[id] = rule.copyWith(
      id: id,
      uuid:
          _rules[id]?.uuid ??
          (rule.uuid.isEmpty
              ? '00000000-0000-4000-8000-${id.toRadixString(16).padLeft(12, '0')}'
              : rule.uuid),
    );
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

  // Mock仅用于普通类型化夹具，不复刻Rust的正则或MD3归一化。
  @override
  Future<List<HighlightRule>> presets() async => const [];
  @override
  Future<List<HighlightRule>> preview(String content) async =>
      (jsonDecode(content) as List)
          .map(
            (e) => HighlightRule.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
  @override
  Future<int> importRules(List<HighlightRule> rules) async {
    for (final rule in rules) {
      final previous = _rules.values
          .where((r) => rule.uuid.isNotEmpty && r.uuid == rule.uuid)
          .firstOrNull;
      await highlightRuleSave(rule.copyWith(id: previous?.id ?? 0));
    }
    return rules.length;
  }

  @override
  Future<String> exportRules() async =>
      jsonEncode((await highlightRuleList()).map((r) => r.toJson()).toList());
  @override
  Future<List<HighlightMatch>> matchText(
    List<HighlightRule> rules,
    String text, {
    bool isTitle = false,
    String? configName,
  }) async => const [];

  List<HighlightRule> _sorted(Iterable<HighlightRule> items) =>
      items.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
