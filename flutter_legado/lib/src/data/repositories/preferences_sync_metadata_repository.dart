import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/contracts/sync_metadata_repository.dart';
import '../../services/settings_write_queue.dart';

/// 保留原整数毫秒键，串行读取和保存同步结果。— connection_migration + UI
final class PreferencesSyncMetadataRepository
    implements SyncMetadataRepository {
  PreferencesSyncMetadataRepository({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _key = 'sync_last_time';
  final Future<SharedPreferences> Function() _loadPreferences;
  final _queue = SettingsWriteQueue();

  @override
  Future<DateTime?> load() async {
    DateTime? time;
    await _queue.run(() async {
      try {
        final millis = (await _loadPreferences()).getInt(_key);
        time = millis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(millis);
      } catch (_) {
        throw StateError('同步时间读取失败，请重试');
      }
    });
    return time;
  }

  @override
  Future<void> save(DateTime time) => _queue.run(() async {
    final prefs = await _loadPreferences();
    final previous = prefs.getInt(_key);
    try {
      if (!await prefs.setInt(_key, time.millisecondsSinceEpoch)) {
        throw StateError('同步时间写入被拒绝');
      }
    } catch (_) {
      var restored = false;
      try {
        restored = previous == null
            ? await prefs.remove(_key)
            : await prefs.setInt(_key, previous);
      } catch (_) {
        // 记录失败交给同步编排层处理，不重做已成功的云端操作。
      }
      throw StateError(restored ? '同步时间保存失败' : '同步时间保存失败，原记录恢复失败');
    }
  });
}
