import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/replace_rule_repository.dart';
import '../../models/misc.dart' show ReplaceRule;
import '../bridge/rust_json_decode.dart';

/// 配置访问直接复用FRB；保留现有字段映射和返回顺序。— Codex + Bridge
final class RustReplaceRuleRepository implements ReplaceRuleRepository {
  const RustReplaceRuleRepository();

  /// 获取所有替换规则
  @override
  Future<List<ReplaceRule>> getReplaceRules() async {
    final json = await bridge.replaceRuleList();
    return _decodeRules(json, 'getReplaceRules');
  }

  /// 获取启用的替换规则
  @override
  Future<List<ReplaceRule>> getEnabledReplaceRules() async {
    final json = await bridge.replaceRuleEnabled();
    return _decodeRules(json, 'getEnabledReplaceRules');
  }

  /// 添加替换规则
  ///
  /// [A3 写链路补齐 | 2026-09-11] FFI 加法式扩参后，分组/作用范围
  /// （标题·正文·书源作用域）/排除范围/超时随对象全字段落库
  /// （缺省语义由 Rust 侧兜底：group=null、scopeTitle=false、
  /// scopeContent=true、scopeSource=false、excludeScope=null、
  /// timeoutMillisecond=3000）。
  @override
  Future<ReplaceRule> addReplaceRule(ReplaceRule rule) async {
    final id = await bridge.replaceRuleAdd(
      name: rule.name,
      pattern: rule.pattern,
      replacement: rule.replacement,
      isRegex: rule.isRegex,
      scope: rule.scope ?? '',
      group: rule.group,
      scopeTitle: rule.scopeTitle,
      scopeContent: rule.scopeContent,
      excludeScope: rule.excludeScope,
      timeoutMillisecond: rule.timeoutMillisecond,
      // [书源作用域 | 2026-09-13] 全字段透传；Rust 侧 None→false（对齐原版默认 0）
      scopeSource: rule.scopeSource,
    );
    return rule.copyWith(id: id);
  }

  /// 更新替换规则
  ///
  /// 保留现有FRB可接受的字段；scope与sortOrder尚不能经此入口更新。
  /// 调用方约定传「完整对象」（读自 API 后 copyWith），故 group/
  /// excludeScope 为 null 即表示「该规则无此字段」，统一以空串透传
  /// → Rust 侧按「清除该字段」处理（与 Mock 仓储整对象替换语义一致；
  /// Rust 侧 None=保留既有值，当前装配显式传入清空值）。
  ///
  /// [书源作用域 | 2026-09-13] 新增 scopeSource 全字段透传；
  /// Rust 侧 None=保留既有值，Some(b)=覆盖。
  @override
  Future<void> updateReplaceRule(ReplaceRule rule) => bridge.replaceRuleUpdate(
    ruleId: rule.id,
    name: rule.name,
    pattern: rule.pattern,
    replacement: rule.replacement,
    isRegex: rule.isRegex,
    isEnabled: rule.isEnabled,
    group: rule.group ?? '',
    scopeTitle: rule.scopeTitle,
    scopeContent: rule.scopeContent,
    excludeScope: rule.excludeScope ?? '',
    timeoutMillisecond: rule.timeoutMillisecond,
    // [书源作用域 | 2026-09-13] 全字段透传；Rust 侧 None=保留既有值
    scopeSource: rule.scopeSource,
  );

  /// 删除替换规则
  @override
  Future<void> deleteReplaceRule(int id) =>
      bridge.replaceRuleDelete(ruleId: id);

  /// 启用/禁用替换规则
  @override
  Future<void> setReplaceRuleEnabled(int id, bool enabled) =>
      bridge.replaceRuleSetEnabled(ruleId: id, enabled: enabled);
}

List<ReplaceRule> _decodeRules(String raw, String operation) =>
    decodeRustJsonList(raw, operation).indexed.map((entry) {
      final (index, value) = entry;
      if (value is! Map<String, dynamic>) {
        throw FormatException('$operation：第${index + 1}项必须是对象');
      }
      try {
        return ReplaceRule.fromJson(value);
      } catch (error) {
        throw FormatException('$operation：第${index + 1}项字段无效（$error）');
      }
    }).toList();
