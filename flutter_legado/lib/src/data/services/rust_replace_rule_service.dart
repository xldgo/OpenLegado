import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/replace_rule_service.dart';

/// 仅委托既有Rust执行，不在Dart重写替换管线。— Codex + Bridge
final class RustReplaceRuleService implements ReplaceRuleService {
  const RustReplaceRuleService();

  /// 书源导入时应用「书源作用域」替换规则（契约 §2.8 `applyReplaceRulesToSource`）
  ///
  /// [书源作用域 | 2026-09-13] 透传 FFI：对整源 JSON 应用
  /// `isEnabled && scopeSource && pattern 非空` 且 scope/excludeScope
  /// 按源名称/源 URL（忽略大小写）匹配的规则；未命中返回原文；
  /// 任何规则级/DB 错误均原样返回输入 JSON（不上抛 FFI），保证导入不中断。
  @override
  Future<String> applyReplaceRulesToSource(
    String sourceJson,
    String sourceName,
    String sourceUrl,
  ) => rustFuture(
    () => bridge.applyReplaceRulesToSource(
      sourceJson: sourceJson,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
    ),
    operation: 'applyReplaceRulesToSource',
  );

  /// 替换规则编辑器预览：对单条规则在示例文本上执行真实替换管线（契约 §2.8 `previewReplaceRule`）
  ///
  /// [替换规则预览 | 2026-09-13] 透传 FFI：成功=返回替换后文本；
  /// 规则级错误（非法正则 / `@js:` JS 异常 / 执行超时）=返回 `⚠️ ` 前缀
  /// 错误文本（不上抛 FFI）；非法输入（JSON 解析失败）MAY Err。
  @override
  Future<String> previewReplaceRule(String ruleJson, String sampleContent) =>
      rustFuture(
        () => bridge.replaceRulePreview(
          ruleJson: ruleJson,
          sample: sampleContent,
        ),
        operation: 'replaceRulePreview',
      );
}
