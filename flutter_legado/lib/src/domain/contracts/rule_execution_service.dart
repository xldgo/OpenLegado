/// 规则和脚本执行能力；不承载书源存储或页面状态。— Codex + Bridge
abstract interface class RuleExecutionService {
  Future<String> parseRule(String content, String rule, String ruleType);
  Future<String> evalJs(String script);
  Future<String> getJsEngineVersion();
}
