import '../../data/services/source_login_service.dart';
import '../../services/book_api.dart';

/// 原配置键的兼容装配；一次操作固定同一根与凭据存储。— Codex + UI
SourceLoginService createSourceLoginService(BookApi api) => SourceLoginService(
  repository: api.sourceLoginRepository,
  readLegacy: (url) => api.configRepository.getConfig('source_login_$url'),
  clearLegacy: (url) => api.configRepository.setConfig('source_login_$url', ''),
);
