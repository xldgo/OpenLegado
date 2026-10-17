import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/app_log_repository.dart';
import '../../domain/models/app_log_entry.dart';
import '../bridge/business_dto_mapping.dart';

/// 沿用Rust日志缓冲与导出，列表直接使用类型化条目。— Codex + Bridge
final class RustAppLogRepository implements AppLogRepository {
  const RustAppLogRepository();

  @override
  Future<void> appLogPush({required String level, required String message}) =>
      bridge.appLogPush(level: level, message: message);

  @override
  Future<List<AppLogEntry>> appLogList({required String level}) async =>
      (await bridge.appLogList(level: level)).map(appLogFromDto).toList();

  @override
  Future<void> appLogClear({required String level}) =>
      bridge.appLogClear(level: level);

  @override
  Future<void> appLogClearAll() => bridge.appLogClearAll();

  @override
  Future<String> appLogExport() => bridge.appLogExport();
}
