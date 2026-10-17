import '../../domain/models/rule_parse_result.dart';
import '../../domain/contracts/rule_execution_service.dart';

/// 保留原占位行为，不在Dart复制规则解析器或JS引擎。— Codex + Bridge
class MockRuleExecutionService implements RuleExecutionService {
  const MockRuleExecutionService();

  @override
  Future<RuleParseResult> parseRule(
    String content,
    String rule,
    String ruleType,
  ) async => RuleParseResult(results: List.unmodifiable([content]), count: 1);

  @override
  Future<String> evalJs(String script) async => 'undefined';

  @override
  Future<String> getJsEngineVersion() async => 'mock-quickjs';
}
