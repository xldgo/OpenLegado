import '../../models/reader_advanced_config.dart';

/// 阅读配置的持久化边界，沿用既有字段、默认值与迁移规则。
abstract interface class ReaderConfigRepository {
  Future<ReaderAdvancedConfig> load();
  Future<void> save(ReaderAdvancedConfig config);
}
