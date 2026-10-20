import 'package:flutter/services.dart' show rootBundle;

import '../../domain/contracts/dict_rule_repository.dart';

/// 显式恢复默认规则使用同一导入入口，不写第二份配置。— Codex + Bridge
const defaultDictRulesAsset = 'assets/default_data/dictRules.json';

Future<int> importDefaultDictRules(DictRuleRepository repository) async =>
    repository.dictRuleImport(
      jsonOrUrl: await rootBundle.loadString(defaultDictRulesAsset),
      kind: 'text',
    );
