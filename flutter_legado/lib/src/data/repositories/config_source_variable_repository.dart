import '../../domain/contracts/config_repository.dart';
import '../../domain/contracts/source_variable_repository.dart';

/// 使用原源变量通道，既有RSS键回退仅在数据层保留。— Codex + Bridge
class ConfigSourceVariableRepository implements SourceVariableRepository {
  const ConfigSourceVariableRepository(this.config);
  final ConfigRepository config;
  @override
  Future<String?> read(String sourceUrl) async {
    final value = await config.getConfig('sourceVariable_$sourceUrl');
    return value == null || value.isEmpty
        ? config.getConfig('rssSourceVariable_$sourceUrl')
        : value;
  }

  @override
  Future<void> write(String sourceUrl, String value) async {
    if (value.isEmpty) {
      await config.deleteConfig('sourceVariable_$sourceUrl');
    } else {
      await config.setConfig('sourceVariable_$sourceUrl', value);
    }
    // 沿用原页面的尽力清理，不让历史键清理失败掩盖本次保存结果。
    try {
      await config.deleteConfig('rssSourceVariable_$sourceUrl');
    } catch (_) {}
  }
}
