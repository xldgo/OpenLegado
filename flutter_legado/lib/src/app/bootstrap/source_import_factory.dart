import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/source_import_service.dart';
import '../../platform/source_import_file_reader.dart';
import 'application_dependencies.dart';

/// 每次操作使用同一份已装配的领域依赖。— Codex + UI
final sourceImportServiceProvider = Provider<SourceImportService>(
  (ref) => SourceImportService(
    repository: ref.watch(bookSourceRepositoryProvider),
    fetchText: ref.watch(networkServiceProvider).httpGet,
    readFile: readSourceImportFile,
    applyReplaceRules: ref
        .watch(replaceRuleServiceProvider)
        .applyReplaceRulesToSource,
  ),
);
