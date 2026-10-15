import 'dart:convert';

import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/highlight_rule_repository.dart';
import '../../domain/models/highlight_rule.dart';
import '../bridge/rust_json_decode.dart';

/// 规则编解码归数据层，排序和匹配仍由Rust负责。— Codex + Bridge
final class RustHighlightRuleRepository implements HighlightRuleRepository {
  const RustHighlightRuleRepository();

  List<HighlightRule> _decode(String json) =>
      decodeRustJsonList(json, 'highlightRule').indexed.map((entry) {
        final (index, value) = entry;
        if (value is! Map<String, dynamic>) {
          throw FormatException('高亮规则列表第${index + 1}项必须是对象');
        }
        try {
          return HighlightRule.fromJson(value);
        } on TypeError catch (error) {
          throw FormatException('高亮规则列表第${index + 1}项字段类型无效：$error');
        }
      }).toList();

  @override
  Future<List<HighlightRule>> highlightRuleList() async =>
      _decode(await bridge.highlightRuleList());

  @override
  Future<int> highlightRuleSave(HighlightRule rule) async {
    final id = await bridge.highlightRuleSave(
      ruleJson: jsonEncode(rule.toJson()),
    );
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
  }) async => _decode(
    await bridge.highlightRuleFindEnabled(bookName: bookName, origin: origin),
  );
}
