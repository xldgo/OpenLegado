/// 全局数据库缓存访问，不负责下载调度或媒体文件。— Codex + Bridge
abstract interface class CacheRepository {
  Future<int> getCacheSize();
  Future<int> getCacheBookCount();
  Future<int> getCacheChapterCount();

  /// 清除章节缓存和通用KV缓存；拒绝或异常时抛出错误。
  Future<void> clearCache();

  /// 按毫秒截止时间清理旧章节，复位受影响书籍的章级标记。
  Future<void> clearCacheBefore(int beforeTimestampMs);
}
