import '../../domain/contracts/read_record_settings_repository.dart';
import '../../domain/models/read_record_settings.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 保留原偏好编码，委托同一共享设置服务。— Codex + UI
final class AppReadRecordSettingsRepository
    implements ReadRecordSettingsRepository {
  AppReadRecordSettingsRepository(this._service);
  final AppSettingsService _service;
  bool _loaded = false;
  Future<ReadRecordSettings>? _loading;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.preferences, key: key);
  static final _addresses = {
    _address('enableReadRecord'),
    _address('readRecordSort'),
    _address('readRecordDisplayMode'),
  };

  T _read<T>(AppSettingsSnapshot snapshot, String key, T fallback) {
    final value = snapshot[_address(key)];
    return value is T ? value : fallback;
  }

  ReadRecordSettings _decode(AppSettingsSnapshot snapshot) =>
      ReadRecordSettings(
        enableRecord: _read(snapshot, 'enableReadRecord', true),
        sortMode: switch (_read(snapshot, 'readRecordSort', 0)) {
          1 => ReadRecordSortMode.readTime,
          2 => ReadRecordSortMode.lastRead,
          _ => ReadRecordSortMode.name,
        },
        displayMode:
            ReadRecordDisplayMode.values
                .where(
                  (value) =>
                      value.name ==
                      _read(snapshot, 'readRecordDisplayMode', ''),
                )
                .firstOrNull ??
            ReadRecordDisplayMode.aggregate,
      );
  @override
  ReadRecordSettings get current => _decode(_service.current);
  @override
  Stream<ReadRecordSettings> watch() =>
      _service.watch().map(_decode).distinct();
  @override
  Future<ReadRecordSettings> load() {
    if (_loaded) return Future.value(current);
    return _loading ??= _service
        .load(_addresses)
        .then((_) {
          _loaded = true;
          return current;
        })
        .whenComplete(() => _loading = null);
  }

  @override
  Future<void> reload() async {
    await _service.reload(_addresses);
    _loaded = true;
  }

  @override
  Future<void> update({
    bool? enableRecord,
    ReadRecordSortMode? sortMode,
    ReadRecordDisplayMode? displayMode,
  }) => _service.update({
    _address('enableReadRecord'): ?(enableRecord),
    _address('readRecordSort'): ?(sortMode?.index),
    _address('readRecordDisplayMode'): ?(displayMode?.name),
  });
}
