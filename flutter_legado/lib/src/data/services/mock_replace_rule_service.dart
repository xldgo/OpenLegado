import '../../domain/contracts/replace_rule_service.dart';

/// Mock保留原文与固定预览占位，不实现真实替换引擎。— Codex + Bridge
final class MockReplaceRuleService implements ReplaceRuleService {
  const MockReplaceRuleService();

  @override
  Future<String> applyReplaceRulesToSource(
    String sourceJson,
    String sourceName,
    String sourceUrl,
  ) async => sourceJson;

  @override
  Future<String> previewReplaceRule(
    String ruleJson,
    String sampleContent,
  ) async => '[mock预览] $sampleContent';
}
