/// 预览和书源作用域替换，正式实现交给既有Rust引擎。— Codex + Bridge
abstract interface class ReplaceRuleService {
  /// 书源导入时应用「书源作用域」替换规则（契约 §2.8 `applyReplaceRulesToSource`）
  ///
  /// [书源作用域 | 2026-09-13] 对整源 [sourceJson] 应用
  /// `isEnabled && scopeSource && pattern 非空` 且 scope/excludeScope
  /// 按 [sourceName]/[sourceUrl]（忽略大小写）匹配的规则；
  /// 未命中返回原文；任何规则级/DB 错误均原样返回输入 JSON（不上抛），
  /// 保证导入流程不中断。
  Future<String> applyReplaceRulesToSource(
    String sourceJson,
    String sourceName,
    String sourceUrl,
  );

  /// 替换规则编辑器预览：对单条规则在示例文本上执行真实替换管线（契约 §2.8 `previewReplaceRule`）
  ///
  /// [替换规则预览 | 2026-09-13] [ruleJson] 为单条 ReplaceRule 模型 JSON
  /// （camelCase 字段，即 `ReplaceRule.toJson()` 产物）；在 [sampleContent]
  /// 上执行真实替换管线（正则 / 字面量 / `@js:` QuickJS 执行 + 逐规则超时）。
  /// 成功=返回替换后文本；规则级错误（非法正则 / `@js:` JS 异常 / 执行超时）
  /// =返回 `⚠️ ` 前缀错误文本（可直接展示于预览区，不上抛）；
  /// 非法输入（JSON 解析失败）MAY Err。
  Future<String> previewReplaceRule(String ruleJson, String sampleContent);
}
