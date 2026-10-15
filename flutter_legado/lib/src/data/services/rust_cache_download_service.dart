import '../../bridge/rust_lib.dart' as bridge;
import '../../domain/contracts/cache_download_service.dart';
import '../../domain/models/cache_download_task.dart';
import '../bridge/rust_json_decode.dart';

/// 直接访问Rust任务表，在数据边界完成严格响应解码。— Codex + Bridge
class RustCacheDownloadService implements CacheDownloadService {
  const RustCacheDownloadService();

  @override
  Future<int> cacheDownloadStart(
    String bookUrl,
    int startChapter,
    int endChapter,
  ) async {
    final raw = await bridge.cacheDownloadStart(
      bookUrl: bookUrl,
      startChapter: startChapter,
      endChapter: endChapter,
    );
    final id = int.tryParse(raw.trim());
    if (id == null) throw FormatException('缓存任务启动失败：$raw');
    return id;
  }

  @override
  Future<CacheDownloadTask> cacheDownloadProgress(int taskId) async =>
      _decodeTask(
        decodeRustJsonMap(
          await bridge.cacheDownloadProgress(taskId: taskId),
          'cacheDownloadProgress',
        ),
        'cacheDownloadProgress',
      );

  @override
  Future<bool> cacheDownloadCancel(int taskId) =>
      bridge.cacheDownloadCancel(taskId: taskId);

  @override
  Future<List<CacheDownloadTask>> cacheDownloadList() async =>
      List.unmodifiable(
        decodeRustJsonList(
          await bridge.cacheDownloadList(),
          'cacheDownloadList',
        ).map((item) => _decodeTask(item, 'cacheDownloadList')),
      );

  @override
  Future<List<int>> listDownloadingChapters(String bookUrl) async =>
      _decodeIndexes(
        await bridge.cacheDownloadRunningChapters(bookUrl: bookUrl),
        'listDownloadingChapters',
      );

  @override
  Future<List<int>> listFailedChapters(String bookUrl) async => _decodeIndexes(
    await bridge.cacheDownloadFailedChapters(bookUrl: bookUrl),
    'listFailedChapters',
  );

  static CacheDownloadTask _decodeTask(Object? item, String method) {
    if (item case {
      'taskId': final int taskId,
      'bookUrl': final String bookUrl,
      'status': final String status,
      'total': final int total,
      'completed': final int completed,
      'failed': final int failed,
    }) {
      return CacheDownloadTask(
        taskId: taskId,
        bookUrl: bookUrl,
        status: status,
        total: total,
        completed: completed,
        failed: failed,
      );
    }
    throw FormatException(
      '$method：任务须包含taskId、bookUrl、status、total、completed、failed，类型必须匹配',
    );
  }

  static List<int> _decodeIndexes(String json, String method) =>
      List.unmodifiable(
        decodeRustJsonList(json, method).map((item) {
          if (item is! int) throw FormatException('$method：章节索引必须是整数');
          return item;
        }),
      );
}
