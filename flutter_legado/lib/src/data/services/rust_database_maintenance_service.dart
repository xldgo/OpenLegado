import '../bridge/rust_errors.dart';
import '../../bridge/ffi/ffi.dart' as bridge;
import '../../domain/contracts/database_maintenance_service.dart';

/// 数据库维护直接委托既有FRB，不重新解释返回0的含义。— Codex + Bridge
final class RustDatabaseMaintenanceService
    implements DatabaseMaintenanceService {
  const RustDatabaseMaintenanceService();

  @override
  Future<int> shrinkDatabase() async => (await rustFuture(
    () => bridge.cacheShrinkDatabase(),
    operation: 'cacheShrinkDatabase',
  )).toInt();
}
