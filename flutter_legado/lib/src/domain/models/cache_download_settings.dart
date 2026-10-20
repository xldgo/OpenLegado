/// 显式离线下载并发，与正文预下载数量及搜索线程数分开。— Codex + UI
final class CacheDownloadSettings {
  const CacheDownloadSettings({this.threadCount = defaultThreadCount});
  static const defaultThreadCount = 8;
  static const minThreadCount = 1;
  static const maxThreadCount = 8;
  final int threadCount;
  CacheDownloadSettings copyWith({int? threadCount}) =>
      CacheDownloadSettings(threadCount: threadCount ?? this.threadCount);
}
