import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/replace_rule_repository.dart';
import '../domain/contracts/replace_rule_service.dart';
import 'providers.dart';

/// 配置和执行使用同一根装配的实例，测试可单独替换。— Codex + UI
final replaceRuleRepositoryProvider = Provider<ReplaceRuleRepository>(
  (ref) => ref.watch(bookApiProvider).replaceRuleRepository,
);

final replaceRuleServiceProvider = Provider<ReplaceRuleService>(
  (ref) => ref.watch(bookApiProvider).replaceRuleService,
);
