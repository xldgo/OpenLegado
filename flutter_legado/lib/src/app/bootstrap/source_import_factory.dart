import '../../data/services/source_import_service.dart';
import '../../platform/source_import_file_reader.dart';
import '../../services/book_api.dart';

/// 为一次导入绑定同一根实例，不触发初始化或额外缓存。— Codex + UI
SourceImportService createSourceImportService(BookApi api) {
  return SourceImportService(
    repository: api.bookSourceRepository,
    fetchText: api.networkService.httpGet,
    readFile: readSourceImportFile,
    applyReplaceRules: api.replaceRuleService.applyReplaceRulesToSource,
  );
}
