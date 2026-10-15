import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/highlight_repository.dart';
import '../domain/contracts/highlight_rule_repository.dart';
import 'providers.dart';

/// 复用应用装配的仓储，消费者可分别注入。— Codex + UI
final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => ref.watch(bookApiProvider).highlightRepository,
);

final highlightRuleRepositoryProvider = Provider<HighlightRuleRepository>(
  (ref) => ref.watch(bookApiProvider).highlightRuleRepository,
);
