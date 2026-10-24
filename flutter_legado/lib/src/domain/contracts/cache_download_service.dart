import '../models/cache_download_task.dart';

/// 真实批量下载能力，任务生命周期及缓存写入仍由Rust承担。— Codex + Bridge
abstract interface class CacheDownloadService {
  /// 章节范围为0-based闭区间；失败原样上抛。
  Future<int> cacheDownloadStart(
    String bookUrl,
    int startChapter,
    int endChapter,
  );

  /// 自动完整缓存窗口；退订仅取消该窗口，不复用或停止手动任务。
  Stream<int> prefetchMangaChapters({
    required String bookUrl,
    required int currentChapter,
    required int nextCount,
    required int previousCount,
  });
  Future<CacheDownloadTask> cacheDownloadProgress(int taskId);
  Future<bool> cacheDownloadCancel(int taskId);
  Future<List<CacheDownloadTask>> cacheDownloadList();

  /// 初始快照及后续变化；退订不取消后台下载。
  Stream<List<CacheDownloadTask>> watchTasks();
  Future<List<int>> listDownloadingChapters(String bookUrl);
  Future<List<int>> listFailedChapters(String bookUrl);
}
