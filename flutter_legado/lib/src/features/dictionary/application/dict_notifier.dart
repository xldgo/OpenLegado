import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../../bridge/ffi.dart';
import '../../../data/defaults/dict_rule_defaults.dart';
import '../../../models/models.dart';
import '../../../providers/dictionary_provider.dart';
import 'dict_state.dart';

export 'dict_state.dart';

/// 查询和管理共用规则仓储，状态层不保存第二份配置。— Codex + UI
class DictNotifier extends Notifier<DictState> {
  @override
  DictState build() => const DictState();

  Future<void> loadRules() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rules = await ref.read(dictRuleRepositoryProvider).dictRuleList();
      state = state.copyWith(rules: rules, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: _mapError(error), isLoading: false);
    }
  }

  /// 显式导入默认按名称合并，保留自定义规则。
  Future<int> importDefaultRules() async {
    final count = await importDefaultDictRules(
      ref.read(dictRuleRepositoryProvider),
    );
    await loadRules();
    return count;
  }

  Future<bool> addRule(DictRule rule) async {
    try {
      final id = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleAdd(
            name: rule.name,
            urlRule: rule.urlRule,
            showRule: rule.showRule,
          );
      if (id <= 0) throw StateError('添加词典规则失败');
      await loadRules();
      return state.error == null;
    } catch (error) {
      state = state.copyWith(error: _mapError(error));
      return false;
    }
  }

  /// 以持久化ID删除，索引只用于取得当前界面选中的实体。
  Future<bool> deleteRule(int index) async {
    if (index < 0 || index >= state.rules.length) return false;
    final rule = state.rules[index];
    try {
      final removed = await ref
          .read(dictRuleRepositoryProvider)
          .dictRuleDelete(rule.id);
      if (!removed) throw StateError('删除词典规则失败');
      await loadRules();
      return state.error == null;
    } catch (error) {
      state = state.copyWith(error: _mapError(error));
      return false;
    }
  }

  Future<void> lookup(String word) async {
    final key = word.trim().toLowerCase();
    if (key.isEmpty) return;
    state = state.copyWith(
      queriedWord: key,
      result: null,
      isLoading: true,
      error: null,
    );
    try {
      final result = await ref.read(dictionaryServiceProvider).dictLookup(key);
      state = state.copyWith(result: result, isLoading: false);
    } catch (error) {
      state = state.copyWith(error: _mapError(error), isLoading: false);
    }
  }

  String _mapError(Object error) =>
      error is BridgeError ? error.message : error.toString();
}

final dictNotifierProvider = NotifierProvider<DictNotifier, DictState>(
  DictNotifier.new,
);
