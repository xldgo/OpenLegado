import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/rule_sub_repository.dart';
import '../domain/contracts/rule_sub_service.dart';
import 'providers.dart';

/// 配置访问与执行能力分别注入，复用同一应用装配。— Codex + UI
final ruleSubRepositoryProvider = Provider<RuleSubRepository>(
  (ref) => ref.watch(bookApiProvider).ruleSubRepository,
);

final ruleSubServiceProvider = Provider<RuleSubService>(
  (ref) => ref.watch(bookApiProvider).ruleSubService,
);
