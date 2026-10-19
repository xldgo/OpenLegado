/// 封面缓存统计与维护；不接收漫画、正文或音频目录。— Codex + UI
abstract interface class CoverCacheRepository {
  Future<int> getSize();
  Future<void> clear();
}
