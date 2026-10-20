import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/read_aloud_selection_repository.dart';
import '../domain/contracts/txt_toc_rule_repository.dart';
import '../domain/contracts/source_variable_repository.dart';
import '../domain/contracts/server_access_repository.dart';
import '../data/repositories/config_read_aloud_selection_repository.dart';
import '../data/repositories/config_txt_toc_rule_repository.dart';
import '../data/repositories/config_source_variable_repository.dart';
import '../data/repositories/config_server_access_repository.dart';
import 'config_provider.dart';

/// 领域数据与普通设置分别装配，共享底层配置通道。— Codex + UI
final readAloudSelectionRepositoryProvider =
    Provider<ReadAloudSelectionRepository>(
      (ref) => ConfigReadAloudSelectionRepository(
        ref.watch(configRepositoryProvider),
      ),
    );
final txtTocRuleRepositoryProvider = Provider<TxtTocRuleRepository>(
  (ref) => ConfigTxtTocRuleRepository(ref.watch(configRepositoryProvider)),
);
final sourceVariableRepositoryProvider = Provider<SourceVariableRepository>(
  (ref) => ConfigSourceVariableRepository(ref.watch(configRepositoryProvider)),
);
final serverAccessRepositoryProvider = Provider<ServerAccessRepository>(
  (ref) => ConfigServerAccessRepository(ref.watch(configRepositoryProvider)),
);
