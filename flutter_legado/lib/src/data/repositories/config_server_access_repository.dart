import '../../domain/contracts/config_repository.dart';
import '../../domain/contracts/server_access_repository.dart';

/// 沿用当前令牌存储，不在本批改变介质或加密方式。— Codex + Bridge
class ConfigServerAccessRepository implements ServerAccessRepository {
  const ConfigServerAccessRepository(this.config);
  final ConfigRepository config;
  @override
  Future<String?> getToken() => config.getConfig('jsSourceApiToken');
  @override
  Future<void> setToken(String token) => token.isEmpty
      ? config.deleteConfig('jsSourceApiToken')
      : config.setConfig('jsSourceApiToken', token);
}
