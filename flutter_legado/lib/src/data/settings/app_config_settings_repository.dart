import '../../domain/contracts/settings_repository.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../services/app_settings_service.dart';

/// 复用设置快照与队列，只把领域值投影到原配置键。— Codex + UI
abstract class AppConfigSettingsRepository<T> implements SettingsRepository<T> {
  AppConfigSettingsRepository(this.service, Set<String> keys)
    : _addresses = {for (final key in keys) _address(key)};
  final AppSettingsService service;
  final Set<SettingsAddress> _addresses;
  static SettingsAddress _address(String key) =>
      (storage: SettingsStorageKind.rustConfig, key: key);
  T decode(Map<String, String?> values);
  Map<String, String> encode(T value);
  T _project(AppSettingsSnapshot snapshot) => decode({
    for (final address in _addresses) address.key: snapshot[address] as String?,
  });
  @override
  T get current => _project(service.current);
  @override
  Stream<T> watch() => service.watch().map(_project).distinct((a, b) {
    final left = encode(a), right = encode(b);
    return left.length == right.length &&
        left.entries.every((entry) => right[entry.key] == entry.value);
  });
  @override
  Future<T> load() async {
    await service.load(_addresses);
    return current;
  }

  @override
  Future<void> reload() => service.reload(_addresses);
  @override
  Future<void> update(T Function(T) transform) async {
    await load();
    final before = encode(current);
    final after = encode(decode(encode(transform(current))));
    await service.update({
      for (final entry in after.entries)
        if (before[entry.key] != entry.value) _address(entry.key): entry.value,
    });
  }

  @override
  Future<void> settled() => service.settled();
}
