import '../bridge/rust_errors.dart';
import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/cache_download_service.dart';
import '../../domain/models/cache_download_task.dart';
import '../bridge/task_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

/// 手动任务观察不取消执行；自动完整缓存订阅只取消自己的窗口。— Codex + Bridge
class RustCacheDownloadService implements CacheDownloadService {
  const RustCacheDownloadService();
  @override
  Future<int> cacheDownloadStart(
    String bookUrl,
    int startChapter,
    int endChapter,
  ) async => (await rustFuture(
    () => bridge.cacheDownloadStart(
      bookUrl: bookUrl,
      startChapter: chapterIndex32(startChapter),
      endChapter: chapterIndex32(endChapter),
    ),
    operation: 'cacheDownloadStart',
  )).toInt();
  @override
  Stream<int> prefetchMangaChapters({
    required String bookUrl,
    required int currentChapter,
    required int nextCount,
    required int previousCount,
  }) => managedRustStream(
    (request) => rustStream(
      () => bridge.mangaCachePrefetch(
        bookUrl: bookUrl,
        currentChapter: chapterIndex32(currentChapter),
        nextCount: chapterIndex32(nextCount),
        previousCount: chapterIndex32(previousCount),
        request: request,
      ),
      operation: 'mangaCachePrefetch',
    ),
  );
  @override
  Future<CacheDownloadTask> cacheDownloadProgress(int taskId) async =>
      cacheTaskFromDto(
        await rustFuture(
          () => bridge.cacheDownloadProgress(taskId: downloadTaskId(taskId)),
          operation: 'cacheDownloadProgress',
        ),
      );
  @override
  Future<bool> cacheDownloadCancel(int taskId) => rustFuture(
    () => bridge.cacheDownloadCancel(taskId: downloadTaskId(taskId)),
    operation: 'cacheDownloadCancel',
  );
  @override
  Future<List<CacheDownloadTask>> cacheDownloadList() async =>
      List.unmodifiable(
        (await rustFuture(
          () => bridge.cacheDownloadList(),
          operation: 'cacheDownloadList',
        )).map(cacheTaskFromDto),
      );
  @override
  Stream<List<CacheDownloadTask>> watchTasks() => managedRustStream(
    (request) => rustStream(
      () => bridge.cacheDownloadStream(request: request),
      operation: 'cacheDownloadStream',
    ),
  ).map((values) => List.unmodifiable(values.map(cacheTaskFromDto)));
  @override
  Future<List<int>> listDownloadingChapters(String bookUrl) async =>
      List.unmodifiable(
        await rustFuture(
          () => bridge.cacheDownloadRunningChapters(bookUrl: bookUrl),
          operation: 'cacheDownloadRunningChapters',
        ),
      );
  @override
  Future<List<int>> listFailedChapters(String bookUrl) async =>
      List.unmodifiable(
        await rustFuture(
          () => bridge.cacheDownloadFailedChapters(bookUrl: bookUrl),
          operation: 'cacheDownloadFailedChapters',
        ),
      );
}
