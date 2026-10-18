import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/highlight_rule_repository.dart';
import '../../domain/models/highlight_rule.dart';
import '../bridge/reading_dto_mapping.dart';

/// 规则快照归数据层映射，排序和匹配仍由Rust负责。— Codex + Bridge
final class RustHighlightRuleRepository implements HighlightRuleRepository {
  const RustHighlightRuleRepository();

  @override
  Future<List<HighlightRule>> highlightRuleList() async => (await rustFuture(
    () => bridge.highlightRuleList(),
    operation: 'highlightRuleList',
  )).map(highlightRuleFromDto).toList();

  @override
  Future<int> highlightRuleSave(HighlightRule rule) async {
    final id = await rustFuture(
      () => bridge.highlightRuleSave(rule: highlightRuleToDto(rule)),
      operation: 'highlightRuleSave',
    );
    if (id <= 0) throw StateError('保存高亮规则未返回有效主键');
    return id;
  }

  @override
  Future<bool> highlightRuleDelete({required int id}) => rustFuture(
    () => bridge.highlightRuleDelete(id: id),
    operation: 'highlightRuleDelete',
  );

  @override
  Future<List<HighlightRule>> highlightRuleFindEnabled({
    required String bookName,
    required String origin,
  }) async => (await rustFuture(
    () => bridge.highlightRuleFindEnabled(bookName: bookName, origin: origin),
    operation: 'highlightRuleFindEnabled',
  )).map(highlightRuleFromDto).toList();
}
