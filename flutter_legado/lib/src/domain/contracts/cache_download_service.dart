import '../models/cache_download_task.dart';

/// 真实批量下载能力，任务生命周期及缓存写入仍由Rust承担。— Codex + Bridge
abstract interface class CacheDownloadService {
  /// 章节范围为0-based闭区间；失败原样上抛。
  Future<int> cacheDownloadStart(
    String bookUrl,
    int startChapter,
    int endChapter,
  );
  Future<CacheDownloadTask> cacheDownloadProgress(int taskId);
  Future<bool> cacheDownloadCancel(int taskId);
  Future<List<CacheDownloadTask>> cacheDownloadList();
  Future<List<int>> listDownloadingChapters(String bookUrl);
  Future<List<int>> listFailedChapters(String bookUrl);
}
