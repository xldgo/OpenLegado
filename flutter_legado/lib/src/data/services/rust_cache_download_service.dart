import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/cache_download_service.dart';
import '../../domain/models/cache_download_task.dart';
import '../bridge/task_dto_mapping.dart';
import '../bridge/managed_rust_stream.dart';

/// 快照与变更流共享原任务服务；取消订阅不取消执行。— Codex + Bridge
class RustCacheDownloadService implements CacheDownloadService {
  const RustCacheDownloadService();
  @override
  Future<int> cacheDownloadStart(
    String bookUrl,
    int startChapter,
    int endChapter,
  ) async => (await bridge.cacheDownloadStart(
    bookUrl: bookUrl,
    startChapter: chapterIndex32(startChapter),
    endChapter: chapterIndex32(endChapter),
  )).toInt();
  @override
  Future<CacheDownloadTask> cacheDownloadProgress(int taskId) async =>
      cacheTaskFromDto(
        await bridge.cacheDownloadProgress(taskId: downloadTaskId(taskId)),
      );
  @override
  Future<bool> cacheDownloadCancel(int taskId) =>
      bridge.cacheDownloadCancel(taskId: downloadTaskId(taskId));
  @override
  Future<List<CacheDownloadTask>> cacheDownloadList() async =>
      List.unmodifiable(
        (await bridge.cacheDownloadList()).map(cacheTaskFromDto),
      );
  @override
  Stream<List<CacheDownloadTask>> watchTasks() => managedRustStream(
    (request) => bridge.cacheDownloadStream(request: request),
  ).map((values) => List.unmodifiable(values.map(cacheTaskFromDto)));
  @override
  Future<List<int>> listDownloadingChapters(String bookUrl) async =>
      List.unmodifiable(
        await bridge.cacheDownloadRunningChapters(bookUrl: bookUrl),
      );
  @override
  Future<List<int>> listFailedChapters(String bookUrl) async =>
      List.unmodifiable(
        await bridge.cacheDownloadFailedChapters(bookUrl: bookUrl),
      );
}
