import '../../models/models.dart';

/// 订阅领域数据访问，界面不依赖FRB。— Codex + Bridge
abstract interface class RssSourceRepository {
  /// 获取所有 RSS 源
  Future<List<RssSource>> getRssSources();

  /// 添加 RSS 源
  Future<RssSource> addRssSource(RssSource source);

  /// 更新 RSS 源
  Future<void> updateRssSource(RssSource source);

  /// 删除 RSS 源
  Future<void> deleteRssSource(String sourceUrl);

  /// 启用 RSS 源
  Future<void> enableRssSource(String sourceUrl);

  /// 禁用 RSS 源
  Future<void> disableRssSource(String sourceUrl);

  /// 导入 RSS 源
  Future<int> importRssSources(String jsonArray);

  /// 导出 RSS 源
  Future<String> exportRssSources();
}
