import 'dart:convert';

import '../../domain/contracts/config_repository.dart';
import '../../domain/contracts/txt_toc_rule_repository.dart';
import '../../models/models.dart';

/// 保留原目录规则JSON与配置键，编解码在数据层完成。— Codex + Bridge
class ConfigTxtTocRuleRepository implements TxtTocRuleRepository {
  const ConfigTxtTocRuleRepository(this.config);
  final ConfigRepository config;
  @override
  Future<List<TxtTocRule>> getRules() async {
    final raw = await config.getConfig('txt_toc_rules');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(TxtTocRule.fromJson)
        .toList();
  }

  @override
  Future<void> saveRules(List<TxtTocRule> rules) => config.setConfig(
    'txt_toc_rules',
    jsonEncode(rules.map((r) => r.toJson()).toList()),
  );
}
