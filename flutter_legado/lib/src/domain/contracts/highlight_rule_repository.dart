import '../models/highlight_rule.dart';

/// 规则配置仓储，不在Dart执行自动高亮规则。— Codex + Bridge
abstract interface class HighlightRuleRepository {
  Future<List<HighlightRule>> highlightRuleList();
  Future<int> highlightRuleSave(HighlightRule rule);
  Future<bool> highlightRuleDelete({required int id});
  Future<List<HighlightRule>> highlightRuleFindEnabled({
    required String bookName,
    required String origin,
  });
}
