import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../bridge/ffi.dart';
import '../../models/models.dart';
import '../../domain/contracts/txt_toc_rule_repository.dart';
import '../domain_config_provider.dart';
import 'txt_toc_rules_state.dart';

export 'txt_toc_rules_state.dart';

/// 对齐 Android `LocalConfig.needUpTxtTocRule` 的版本号
const kTxtTocRuleVersionKey = 'txtTocRuleVersion';
const kTxtTocRuleVersion = 1;

/// 默认 TXT 目录规则（对齐 `app/src/main/assets/defaultData/txtTocRule.json`）
const kDefaultTxtTocRulesAsset = 'assets/default_data/txtTocRule.json';

/// 对齐 Android `DefaultData.importDefaultTocRules`：删除默认 id(<0) 后灌入原版规则。
///
/// [replaceAll] 为 true 时整表覆盖（首启从错误内置默认迁移时用）。
Future<int> syncDefaultTxtTocRules(
  TxtTocRuleRepository repository, {
  String? jsonOverride,
  bool replaceAll = false,
}) async {
  final text =
      jsonOverride ?? await rootBundle.loadString(kDefaultTxtTocRulesAsset);
  final list = jsonDecode(text) as List<dynamic>;
  final defaults = list
      .whereType<Map<String, dynamic>>()
      .map(TxtTocRule.fromJson)
      .toList();

  List<TxtTocRule> merged;
  if (replaceAll) {
    merged = defaults;
  } else {
    final existing = (await repository.getRules())
        .where((rule) => rule.id >= 0)
        .toList();
    merged = [...defaults, ...existing];
  }
  await repository.saveRules(merged);
  return defaults.length;
}

/// TXT 目录规则 Riverpod Notifier
///
/// 规则列表由领域仓储持久化，不在状态层解释配置键。
/// 首启/「导入默认」对齐 Android DefaultData.txtTocRules。
class TxtTocRulesNotifier extends Notifier<TxtTocRulesState> {
  @override
  TxtTocRulesState build() => const TxtTocRulesState();

  /// 加载规则列表；首启写入原版默认规则
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repository = ref.read(txtTocRuleRepositoryProvider);
      await _ensureDefaultTxtTocRules(repository);
      final rules = await repository.getRules();
      state = state.copyWith(rules: rules, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: _mapError(e), isLoading: false);
    }
  }

  Future<void> _ensureDefaultTxtTocRules(
    TxtTocRuleRepository repository,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(kTxtTocRuleVersionKey) ?? 0;
    if (version >= kTxtTocRuleVersion) return;
    // 版本 0→1：覆盖错误内置默认（id 1/2/3），对齐原版 assets
    await syncDefaultTxtTocRules(repository, replaceAll: true);
    await prefs.setInt(kTxtTocRuleVersionKey, kTxtTocRuleVersion);
  }

  /// 菜单「导入默认」：覆盖默认规则（保留用户自定义 id>=0）
  Future<int> importDefaultRules() async {
    final repository = ref.read(txtTocRuleRepositoryProvider);
    final n = await syncDefaultTxtTocRules(repository);
    final rules = await repository.getRules();
    state = state.copyWith(rules: rules, error: null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kTxtTocRuleVersionKey, kTxtTocRuleVersion);
    return n;
  }

  Future<void> addRule(TxtTocRule rule) async {
    final nextId = state.rules.fold<int>(0, (m, r) => r.id > m ? r.id : m) + 1;
    final added = rule.copyWith(id: nextId, serialNumber: state.rules.length);
    final rules = [...state.rules, added];
    state = state.copyWith(rules: rules);
    await _persist(rules);
  }

  Future<void> updateRule(TxtTocRule rule) async {
    final idx = state.rules.indexWhere((r) => r.id == rule.id);
    if (idx < 0) return;
    final rules = [...state.rules];
    rules[idx] = rule;
    state = state.copyWith(rules: rules);
    await _persist(rules);
  }

  Future<void> deleteRule(int id) async {
    final rules = state.rules.where((r) => r.id != id).toList();
    state = state.copyWith(rules: rules);
    await _persist(rules);
  }

  Future<void> setEnabled(int id, bool enable) async {
    final idx = state.rules.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final rules = [...state.rules];
    rules[idx] = rules[idx].copyWith(enable: enable);
    state = state.copyWith(rules: rules);
    await _persist(rules);
  }

  Future<void> _persist(List<TxtTocRule> rules) async {
    try {
      await ref.read(txtTocRuleRepositoryProvider).saveRules(rules);
    } catch (e) {
      state = state.copyWith(error: _mapError(e));
    }
  }

  String _mapError(Object e) {
    if (e is BridgeError) return e.message;
    return e.toString();
  }
}

final txtTocRulesNotifierProvider =
    NotifierProvider<TxtTocRulesNotifier, TxtTocRulesState>(
      TxtTocRulesNotifier.new,
    );
