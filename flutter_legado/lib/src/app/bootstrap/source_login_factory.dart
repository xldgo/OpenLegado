import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/source_login_service.dart';
import 'application_dependencies.dart';

/// 当前登录操作固定同一凭据与配置仓储。— Codex + UI
final sourceLoginServiceProvider = Provider<SourceLoginService>((ref) {
  final config = ref.watch(configRepositoryProvider);
  return SourceLoginService(
    repository: ref.watch(sourceLoginRepositoryProvider),
    readLegacy: (url) => config.getConfig('source_login_$url'),
    clearLegacy: (url) => config.setConfig('source_login_$url', ''),
  );
});
