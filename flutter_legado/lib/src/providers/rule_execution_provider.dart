import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/rule_execution_service.dart';
import 'providers.dart';

/// 脚本执行使用装配好的同一平台拦截链。— Codex + UI
final ruleExecutionServiceProvider = Provider<RuleExecutionService>(
  (ref) => ref.watch(bookApiProvider).ruleExecutionService,
);
