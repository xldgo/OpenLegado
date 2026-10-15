import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/contracts/cache_repository.dart';
import '../domain/contracts/database_maintenance_service.dart';
import '../services/cache_service.dart';
import 'providers.dart';

/// 两种设置入口复用应用装配，可独立替换。— Codex + UI
final cacheRepositoryProvider = Provider<CacheRepository>(
  (ref) => ref.watch(bookApiProvider).cacheRepository,
);

final databaseMaintenanceServiceProvider = Provider<DatabaseMaintenanceService>(
  (ref) => ref.watch(bookApiProvider).databaseMaintenanceService,
);

final cacheServiceProvider = Provider<CacheService>(
  (ref) => CacheService(ref.watch(cacheRepositoryProvider)),
);
