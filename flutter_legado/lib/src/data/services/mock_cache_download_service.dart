import '../../domain/contracts/cache_download_service.dart';
import '../../domain/models/cache_download_task.dart';

/// 保留原Mock占位语义，不运行下载线程。— Codex + Bridge
class MockCacheDownloadService implements CacheDownloadService {
  const MockCacheDownloadService();

  @override
  Future<int> cacheDownloadStart(
    String bookUrl,
    int startChapter,
    int endChapter,
  ) async => 1;
  @override
  Future<CacheDownloadTask> cacheDownloadProgress(int taskId) async =>
      CacheDownloadTask(
        taskId: taskId,
        bookUrl: '',
        status: 'completed',
        total: 0,
        completed: 0,
        failed: 0,
      );
  @override
  Future<bool> cacheDownloadCancel(int taskId) async => true;
  @override
  Future<List<CacheDownloadTask>> cacheDownloadList() async => const [];
  @override
  Stream<List<CacheDownloadTask>> watchTasks() => Stream.value(const []);
  @override
  Future<List<int>> listDownloadingChapters(String bookUrl) async => const [];
  @override
  Future<List<int>> listFailedChapters(String bookUrl) async => const [];
}
