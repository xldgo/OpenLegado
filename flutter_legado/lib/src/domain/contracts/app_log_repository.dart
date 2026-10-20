import '../models/app_log_entry.dart';

/// 统一应用日志访问，不接管日志采集或备份。— Codex + Bridge
abstract interface class AppLogRepository {
  Future<void> appLogPush({required String level, required String message});
  Future<List<AppLogEntry>> appLogList({required String level});
  Future<void> appLogClear({required String level});
  Future<void> appLogClearAll();
  Future<String> appLogExport();
}
