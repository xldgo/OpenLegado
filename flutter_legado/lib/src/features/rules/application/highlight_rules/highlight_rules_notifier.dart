import '../../../../utils/error_message.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../../providers/highlight_repository_provider.dart';
import '../../../../domain/models/highlight_rule.dart';
import 'highlight_rules_state.dart';

export 'highlight_rules_state.dart';

/// 高亮规则列表 Riverpod Notifier
///
/// 配置访问与解码由仓储完成，本层管理加载和操作状态。— Codex + UI
class HighlightRulesNotifier extends Notifier<HighlightRulesState> {
  @override
  HighlightRulesState build() => const HighlightRulesState();

  /// 加载规则列表（Rust 侧按 sortOrder 升序返回）
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rules = await ref
          .read(highlightRuleRepositoryProvider)
          .highlightRuleList();
      state = state.copyWith(rules: rules, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: errorMessage(e));
    }
  }

  /// 切换规则启用状态（保存后刷新列表）
  Future<void> toggleEnabled(HighlightRule rule, bool enabled) async {
    await _save(rule.copyWith(isEnabled: enabled));
  }

  /// 删除规则（成功后刷新列表）
  Future<void> deleteRule(HighlightRule rule) async {
    try {
      final deleted = await ref
          .read(highlightRuleRepositoryProvider)
          .highlightRuleDelete(id: rule.id);
      if (!deleted) throw StateError('删除高亮规则失败');
      ref.read(highlightRuleRevisionProvider.notifier).changed();
      await load();
    } catch (e) {
      state = state.copyWith(error: errorMessage(e));
    }
  }

  /// 保存规则（新增或编辑，成功后刷新列表）
  Future<bool> saveRule(HighlightRule rule) async {
    return _save(rule);
  }

  Future<bool> _save(HighlightRule rule) async {
    try {
      final id = await ref
          .read(highlightRuleRepositoryProvider)
          .highlightRuleSave(rule);
      if (id <= 0) throw StateError('保存高亮规则失败');
      ref.read(highlightRuleRevisionProvider.notifier).changed();
      await load();
      return state.error == null;
    } catch (e) {
      state = state.copyWith(error: errorMessage(e));
      return false;
    }
  }
}

/// 高亮规则 Notifier 全局 Provider
///
/// 使用方式：
/// ```dart
/// final state = ref.watch(highlightRulesNotifierProvider);
/// ref.read(highlightRulesNotifierProvider.notifier).load();
/// ```
final highlightRulesNotifierProvider =
    NotifierProvider<HighlightRulesNotifier, HighlightRulesState>(
      HighlightRulesNotifier.new,
    );
