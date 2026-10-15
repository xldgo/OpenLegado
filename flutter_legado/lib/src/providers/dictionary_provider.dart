import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/dict_rule_repository.dart';
import '../domain/contracts/dictionary_service.dart';
import 'providers.dart';

/// 查询与配置分别注入，消费者共享应用装配实例。— Codex + UI
final dictionaryServiceProvider = Provider<DictionaryService>(
  (ref) => ref.watch(bookApiProvider).dictionaryService,
);

final dictRuleRepositoryProvider = Provider<DictRuleRepository>(
  (ref) => ref.watch(bookApiProvider).dictRuleRepository,
);
