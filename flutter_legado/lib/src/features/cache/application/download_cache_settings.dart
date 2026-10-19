import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/pref_keys.dart';
import '../../../domain/contracts/cache_repository.dart';
import '../../../domain/contracts/database_maintenance_service.dart';
import '../../../providers/cache_provider.dart';
import '../../../providers/providers.dart' show settingsProvider;
import '../../../services/cache_service.dart';

/// 尚未接线的旧偏好只读展示，不提供无消费者的写入。— Codex + UI
typedef PendingDownloadSettings = ({
  int bitmapCacheSize,
  int imageRetainNum,
  int preDownloadNum,
  String userAgent,
});

final pendingDownloadSettingsProvider =
    FutureProvider.autoDispose<PendingDownloadSettings>((ref) async {
      final settings = ref.watch(settingsProvider);
      return (
        bitmapCacheSize: await settings.getIntPref(
          PrefKeys.bitmapCacheSize,
          defaultValue: 50,
        ),
        imageRetainNum: await settings.getIntPref(
          PrefKeys.imageRetainNum,
          defaultValue: 100,
        ),
        preDownloadNum: await settings.getIntPref(
          PrefKeys.preDownloadNum,
          defaultValue: 10,
        ),
        userAgent: await settings.getStringPref(PrefKeys.userAgent),
      );
    });

final downloadCacheActionsProvider = Provider<DownloadCacheActions>(
  (ref) => DownloadCacheActions(
    ref.watch(cacheRepositoryProvider),
    ref.watch(databaseMaintenanceServiceProvider),
  ),
);

/// 清理与维护复用已有窄接口；页面只负责确认与结果展示。— Codex + UI
final class DownloadCacheActions {
  DownloadCacheActions(this._cache, this._database);
  final CacheRepository _cache;
  final DatabaseMaintenanceService _database;

  Future<void> clearBookCache() async {
    await _cache.clearCache();
    await CacheService.clearSameTitleRemovedFlags();
  }

  Future<int> shrinkDatabase() => _database.shrinkDatabase();
}
