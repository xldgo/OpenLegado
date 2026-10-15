import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/app_log_repository.dart';
import '../../domain/models/app_log_entry.dart';
import '../bridge/rust_json_decode.dart';

/// 沿用Rust日志缓冲与导出，传输JSON仅在仓储解码。— Codex + Bridge
final class RustAppLogRepository implements AppLogRepository {
  const RustAppLogRepository();

  @override
  Future<void> appLogPush({required String level, required String message}) =>
      bridge.appLogPush(level: level, message: message);

  @override
  Future<List<AppLogEntry>> appLogList({required String level}) async =>
      decodeRustJsonList(
        await bridge.appLogList(level: level),
        'appLogList',
      ).indexed.map((entry) {
        final (index, value) = entry;
        if (value is! Map<String, dynamic> ||
            value['timestamp'] is! int ||
            value['level'] is! String ||
            value['message'] is! String) {
          throw FormatException('日志列表第${index + 1}项结构或字段类型无效');
        }
        return AppLogEntry.fromJson(value);
      }).toList();

  @override
  Future<void> appLogClear({required String level}) =>
      bridge.appLogClear(level: level);

  @override
  Future<void> appLogClearAll() => bridge.appLogClearAll();

  @override
  Future<String> appLogExport() => bridge.appLogExport();
}
