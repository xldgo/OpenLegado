import '../app/bootstrap/application_dependencies.dart'
    show cacheRepositoryProvider;
export '../app/bootstrap/application_dependencies.dart'
    show cacheRepositoryProvider, databaseMaintenanceServiceProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache_service.dart';

/// 两种设置入口复用应用装配，可独立替换。— Codex + UI

final cacheServiceProvider = Provider<CacheService>(
  (ref) => CacheService(ref.watch(cacheRepositoryProvider)),
);
