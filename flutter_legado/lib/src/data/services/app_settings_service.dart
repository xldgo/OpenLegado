import '../../domain/contracts/settings_storage.dart';
import '../../domain/models/app_settings_snapshot.dart';
import '../settings/app_settings_store.dart';

/// 协调存储 IO；领域默认值与类型解释由各功能 Repository 提供。— Codex + UI
final class AppSettingsService {
  AppSettingsService({
    required Map<SettingsStorageKind, SettingsStorage> storages,
  }) : _storages = Map.unmodifiable(storages);

  final Map<SettingsStorageKind, SettingsStorage> _storages;
  final _store = AppSettingsStore();
  final _loaded = <SettingsAddress>{};
  Future<void> _tail = Future.value();
  bool _disposed = false;
  Future<void>? _disposal;

  AppSettingsSnapshot get current => _store.current;
  Stream<AppSettingsSnapshot> watch() => _store.watch();

  SettingsStorage _storage(SettingsAddress address) =>
      _storages[address.storage] ??
      (throw StateError('未配置设置存储：${address.storage.name}'));

  void _checkActive() {
    if (_disposed) throw StateError('设置服务已经释放');
  }

  Future<void> load(Set<SettingsAddress> addresses) {
    _checkActive();
    final requested = Set<SettingsAddress>.of(addresses);
    return _enqueue(() => _read(requested.difference(_loaded)));
  }

  Future<void> _read(Set<SettingsAddress> addresses) async {
    if (addresses.isEmpty) return;
    final entries = await Future.wait(
      addresses.map(
        (address) async =>
            MapEntry(address, await _storage(address).read(address.key)),
      ),
    );
    _loaded.addAll(addresses);
    _store.hydrate(Map.fromEntries(entries));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> update(Map<SettingsAddress, Object?> values) {
    _checkActive();
    if (values.isEmpty) return Future.value();
    final mutation = _store.stage(values);
    return _enqueue(() async {
      try {
        await _read(mutation.values.keys.toSet().difference(_loaded));
        for (final entry in mutation.values.entries) {
          await _storage(entry.key).write(entry.key.key, entry.value);
          _store.markPersisted(mutation, entry.key);
        }
      } finally {
        _store.finish(mutation);
      }
    });
  }

  /// 外部恢复或尚未迁移的原生写入后显式重读；与当前写队列有序执行。
  Future<void> reload(Set<SettingsAddress> addresses) {
    _checkActive();
    final requested = Set<SettingsAddress>.of(addresses);
    return _enqueue(() => _read(requested));
  }

  /// 只等待调用时已经入队的操作；失败已反映为回退，原调用方仍收到异常。
  Future<void> settled() => _tail;

  Future<void> dispose() {
    if (_disposal case final disposal?) return disposal;
    _disposed = true;
    return _disposal = _tail.then((_) => _store.dispose());
  }
}
