import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/app_log_repository.dart';
import '../../domain/models/app_log_entry.dart';
import '../bridge/business_dto_mapping.dart';

/// 沿用Rust日志缓冲与导出，列表直接使用类型化条目。— Codex + Bridge
final class RustAppLogRepository implements AppLogRepository {
  const RustAppLogRepository();

  @override
  Future<void> appLogPush({required String level, required String message}) =>
      rustFuture(
        () => bridge.appLogPush(level: level, message: message),
        operation: 'appLogPush',
      );

  @override
  Future<List<AppLogEntry>> appLogList({required String level}) async =>
      (await rustFuture(
        () => bridge.appLogList(level: level),
        operation: 'appLogList',
      )).map(appLogFromDto).toList();

  @override
  Future<void> appLogClear({required String level}) => rustFuture(
    () => bridge.appLogClear(level: level),
    operation: 'appLogClear',
  );

  @override
  Future<void> appLogClearAll() =>
      rustFuture(() => bridge.appLogClearAll(), operation: 'appLogClearAll');

  @override
  Future<String> appLogExport() =>
      rustFuture(() => bridge.appLogExport(), operation: 'appLogExport');
}
