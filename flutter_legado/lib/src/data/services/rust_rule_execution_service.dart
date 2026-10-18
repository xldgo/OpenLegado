import '../bridge/rust_errors.dart';
import '../../domain/models/rule_parse_result.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/rule_execution_service.dart';

/// 平台脚本拦截由装配点注入，适配器不依赖页面或平台单例。— Codex + Bridge
class RustRuleExecutionService implements RuleExecutionService {
  RustRuleExecutionService({required this._interceptResult});

  final Future<String> Function(String) _interceptResult;

  @override
  Future<RuleParseResult> parseRule(
    String content,
    String rule,
    String ruleType,
  ) async {
    final value = await rustFuture(
      () => bridge.parseRule(content: content, rule: rule, ruleType: ruleType),
      operation: 'parseRule',
    );
    return RuleParseResult(
      results: List.unmodifiable(value.results),
      count: value.count.toInt(),
    );
  }

  @override
  Future<String> evalJs(String script) async => _interceptResult(
    await rustFuture(() => bridge.jsEval(script: script), operation: 'jsEval'),
  );

  @override
  Future<String> getJsEngineVersion() async {
    try {
      return await rustFuture(
        () => bridge.jsEval(
          script:
              'typeof QuickJS !== "undefined" ? QuickJS.version : "quickjs-ng"',
        ),
        operation: 'jsEval',
      );
    } catch (_) {
      return 'unknown';
    }
  }
}
