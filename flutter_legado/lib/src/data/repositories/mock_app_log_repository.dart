import '../../domain/contracts/app_log_repository.dart';
import '../../domain/models/app_log_entry.dart';

/// Mock保留原内存缓冲、每级500条和导出格式。— Codex + Bridge
final class MockAppLogRepository implements AppLogRepository {
  static const _capacity = 500;
  final Map<String, List<AppLogEntry>> _logs = {};

  @override
  Future<void> appLogPush({
    required String level,
    required String message,
  }) async {
    if (message.isEmpty) return;
    final bucket = _logs.putIfAbsent(level, () => []);
    bucket.insert(
      0,
      AppLogEntry(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        level: level,
        message: message,
      ),
    );
    if (bucket.length > _capacity) bucket.removeRange(_capacity, bucket.length);
  }

  @override
  Future<List<AppLogEntry>> appLogList({required String level}) async =>
      List.of(_logs[level] ?? const []);

  @override
  Future<void> appLogClear({required String level}) async {
    _logs.remove(level);
  }

  @override
  Future<void> appLogClearAll() async {
    _logs.clear();
  }

  @override
  Future<String> appLogExport() async {
    final entries = _logs.values.expand((items) => items).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln('[${entry.timestamp}] [${entry.level}] ${entry.message}');
    }
    final text = buffer.toString();
    return text.length > 64000 ? text.substring(0, 64000) : text;
  }
}
