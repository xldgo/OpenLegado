import '../../domain/contracts/database_maintenance_service.dart';

/// 保留旧Mock短延迟与固定10MB释放量，不执行真实VACUUM。— Codex + Bridge
final class MockDatabaseMaintenanceService
    implements DatabaseMaintenanceService {
  const MockDatabaseMaintenanceService();

  @override
  Future<int> shrinkDatabase() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 10 * 1024 * 1024;
  }
}
