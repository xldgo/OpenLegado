import '../../models/models.dart';

/// 订阅领域数据访问，界面不依赖FRB。— Codex + Bridge
abstract interface class RssStarRepository {
  /// 获取所有 RSS 收藏
  Future<List<RssStar>> getRssStars();

  /// 添加 RSS 收藏
  Future<RssStar> addRssStar(RssStar star);

  /// 删除 RSS 收藏
  Future<void> deleteRssStar(String link);

  /// 判断是否已收藏
  Future<bool> isStarred(String link);
}
