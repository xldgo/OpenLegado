import '../models/search_settings.dart';

/// 搜索只依赖类型化偏好，不识别物理键与具体存储。— Codex + UI
abstract interface class SearchSettingsRepository {
  SearchSettings get current;
  Stream<SearchSettings> watch();
  Future<SearchSettings> load();

  /// 只加载影响搜索执行的偏好，不要求展示专用偏好的平台能力。
  Future<void> loadRuntime();
  Future<void> update(SearchSettings Function(SearchSettings) transform);
  Future<void> reload();

  /// 启动搜索前重新核对执行配置，兼容尚未迁移的外部写入。
  Future<void> reloadRuntime();
  Future<void> settled();
}
