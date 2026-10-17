import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/highlight_rule_repository.dart';
import '../../domain/models/highlight_rule.dart';
import '../bridge/reading_dto_mapping.dart';

/// 规则快照归数据层映射，排序和匹配仍由Rust负责。— Codex + Bridge
final class RustHighlightRuleRepository implements HighlightRuleRepository {
  const RustHighlightRuleRepository();

  @override
  Future<List<HighlightRule>> highlightRuleList() async =>
      (await bridge.highlightRuleList()).map(highlightRuleFromDto).toList();

  @override
  Future<int> highlightRuleSave(HighlightRule rule) async {
    final id = await bridge.highlightRuleSave(rule: highlightRuleToDto(rule));
    if (id <= 0) throw StateError('保存高亮规则未返回有效主键');
    return id;
  }

  @override
  Future<bool> highlightRuleDelete({required int id}) =>
      bridge.highlightRuleDelete(id: id);

  @override
  Future<List<HighlightRule>> highlightRuleFindEnabled({
    required String bookName,
    required String origin,
  }) async => (await bridge.highlightRuleFindEnabled(
    bookName: bookName,
    origin: origin,
  )).map(highlightRuleFromDto).toList();
}
