/// Rust批量缓存下载任务的只读快照，不在Dart维护第二份任务状态。— Codex + Bridge
class CacheDownloadTask {
  const CacheDownloadTask({
    required this.taskId,
    required this.bookUrl,
    required this.status,
    required this.total,
    required this.completed,
    required this.failed,
  });

  final int taskId;
  final String bookUrl;
  final String status;
  final int total;
  final int completed;
  final int failed;

  bool get isRunning => status == 'running';
}
