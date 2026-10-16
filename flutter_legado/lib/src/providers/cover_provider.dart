import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/cover_search_service.dart';
import '../domain/contracts/cover_rule_repository.dart';
import 'providers.dart';

/// 封面查询与规则配置各有独立入口，共享应用装配。— Codex + UI
final coverSearchServiceProvider = Provider<CoverSearchService>(
  (ref) => ref.watch(bookApiProvider).coverSearchService,
);
final coverRuleRepositoryProvider = Provider<CoverRuleRepository>(
  (ref) => ref.watch(bookApiProvider).coverRuleRepository,
);
