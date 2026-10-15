import '../models/restore_ignore_config.dart';

/// 恢复忽略策略独立于普通偏好，读取与保存失败交给调用方。— connection_migration + UI
abstract interface class RestoreIgnoreRepository {
  Future<RestoreIgnoreConfig> load();
  Future<void> save(RestoreIgnoreConfig config);
}
