import '../../constants/pref_keys.dart';
import '../../domain/contracts/download_settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../../domain/models/download_settings.dart';
import '../services/app_settings_service.dart';

/// 只投影已有共享设置服务，不另建缓存或写入队列。— Codex + UI
final class AppDownloadSettingsRepository
    implements DownloadSettingsRepository {
  AppDownloadSettingsRepository(this._service);
  final AppSettingsService _service;
  static const _next = (
    storage: SettingsStorageKind.preferences,
    key: PrefKeys.preDownloadNum,
  );
  static const _previous = (
    storage: SettingsStorageKind.preferences,
    key: PrefKeys.preDownloadNumPrev,
  );
  static const _addresses = {_next, _previous};

  int _count(Object? value, int fallback) =>
      value is int &&
          value >= DownloadSettings.minChapters &&
          value <= DownloadSettings.maxChapters
      ? value
      : fallback;
  DownloadSettings _decode(AppSettingsSnapshot snapshot) => DownloadSettings(
    preDownloadNum: _count(snapshot[_next], 10),
    preDownloadNumPrev: _count(snapshot[_previous], 0),
  );
  @override
  DownloadSettings get current => _decode(_service.current);
  @override
  Stream<DownloadSettings> watch() => _service.watch().map(_decode).distinct();
  @override
  Future<DownloadSettings> load() async {
    await _service.load(_addresses);
    return current;
  }

  @override
  Future<void> reload() => _service.reload(_addresses);
  @override
  Future<void> settled() => _service.settled();
  @override
  Future<void> update(
    DownloadSettings Function(DownloadSettings) transform,
  ) async {
    await load();
    final before = current;
    final after = transform(before);
    for (final value in [after.preDownloadNum, after.preDownloadNumPrev]) {
      if (value < DownloadSettings.minChapters ||
          value > DownloadSettings.maxChapters) {
        throw RangeError.range(
          value,
          DownloadSettings.minChapters,
          DownloadSettings.maxChapters,
        );
      }
    }
    await _service.update({
      if (before.preDownloadNum != after.preDownloadNum)
        _next: after.preDownloadNum,
      if (before.preDownloadNumPrev != after.preDownloadNumPrev)
        _previous: after.preDownloadNumPrev,
    });
  }
}
