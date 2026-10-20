/// 直链播放进度，与书籍阅读位置和普通设置分别管理。— Codex + Bridge
abstract interface class VideoProgressRepository {
  Future<int> read(String url);
  Future<void> write(String url, int positionMs);
  Future<void> clear(String url);
}
